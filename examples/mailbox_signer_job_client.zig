const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Command-ready signer-backed mailbox authoring: the caller explicitly establishes one signer
// session, handles relay auth if needed, walks the remote signer through mailbox wrap authoring,
// then receives one bounded delivery plan for explicit publish work.
test "recipe: mailbox signer job client prepares signer-backed mailbox delivery explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    const author_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const author_pubkey = try common.derivePublicKey(&author_secret);
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var storage = noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClientStorage{};
    var client = try noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client, &storage, "secret", arena.allocator());

    var recipient_relay_list_json_storage: [2048]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_json_storage[0..],
        &recipient_secret,
        &.{ "wss://relay.recipient", "wss://relay.shared" },
        100,
    );
    var sender_relay_list_json_storage: [2048]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_json_storage[0..],
        &author_secret,
        &.{ "wss://relay.shared", "wss://relay.sender" },
        101,
    );

    const request = noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerDirectMessageRequest{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_hint = "wss://relay.shared",
        .recipient_relay_list_event_json = recipient_relay_list_json,
        .sender_relay_list_event_json = sender_relay_list_json,
        .content = "hello signer mailbox",
        .created_at = 500,
        .seal_nonce = [_]u8{0x33} ** 32,
        .wrap_nonce = [_]u8{0x44} ** 32,
    };

    var auth_storage = noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var noop_delivery_storage = noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage{};

    const pubkey_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(pubkey_ready == .get_public_key);

    var signer_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    try std.testing.expectEqual(
        .got_public_key,
        try acceptProgress(
            &client,
            &storage,
            try textResponse(signer_response_json[0..], "signer-2", std.fmt.bytesToHex(author_pubkey, .lower)[0..]),
            auth_message_output[0..],
            &noop_delivery_storage,
            &request,
            arena.allocator(),
        ),
    );

    const encrypt_rumor_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(encrypt_rumor_ready == .encrypt_rumor);
    try std.testing.expectEqual(
        .encrypted_rumor,
        try acceptProgress(
            &client,
            &storage,
            try textResponse(signer_response_json[0..], "signer-3", "seal-payload"),
            auth_message_output[0..],
            &noop_delivery_storage,
            &request,
            arena.allocator(),
        ),
    );

    const sign_seal_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(sign_seal_ready == .sign_seal);

    var signed_seal_json_storage: [noztr.limits.event_json_max]u8 = undefined;
    const signed_seal_json = try buildSignedEventJson(
        signed_seal_json_storage[0..],
        &author_secret,
        13,
        501,
        "seal-payload",
        &.{},
    );
    try std.testing.expectEqual(
        .signed_seal,
        try acceptProgress(
            &client,
            &storage,
            try textResponse(signer_response_json[0..], "signer-4", signed_seal_json),
            auth_message_output[0..],
            &noop_delivery_storage,
            &request,
            arena.allocator(),
        ),
    );

    const encrypt_seal_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(encrypt_seal_ready == .encrypt_seal);
    try std.testing.expectEqual(
        .encrypted_seal,
        try acceptProgress(
            &client,
            &storage,
            try textResponse(signer_response_json[0..], "signer-5", "wrap-payload"),
            auth_message_output[0..],
            &noop_delivery_storage,
            &request,
            arena.allocator(),
        ),
    );

    const sign_wrap_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(sign_wrap_ready == .sign_wrap);

    const recipient_pubkey_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    var wrap_tag_items = [_][]const u8{ "p", recipient_pubkey_hex[0..] };
    const wrap_tags = [_]noztr.nip01_event.EventTag{.{ .items = wrap_tag_items[0..] }};
    var signed_wrap_json_storage: [noztr.limits.event_json_max]u8 = undefined;
    const signed_wrap_json = try buildSignedEventJson(
        signed_wrap_json_storage[0..],
        &author_secret,
        1059,
        502,
        "wrap-payload",
        wrap_tags[0..],
    );

    var final_wrap_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var delivery_storage = noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage{};
    const final_result = try client.acceptDirectMessageResponseJson(
        &storage,
        try textResponse(signer_response_json[0..], "signer-6", signed_wrap_json),
        final_wrap_json_output[0..],
        &delivery_storage,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(final_result == .ready);
    try std.testing.expectEqualStrings("wrap-payload", final_result.ready.wrap_event.content);
    try std.testing.expectEqual(@as(u8, 3), final_result.ready.delivery.relay_count);
    try std.testing.expectEqualStrings("wss://relay.shared", final_result.ready.delivery.nextStep().?.relay_url);
}

fn establishSignerSession(
    client: *noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClient,
    storage: *noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClientStorage,
    secret_text: []const u8,
    scratch: std.mem.Allocator,
) !void {
    client.markCurrentRelayConnected();

    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try client.beginConnect(storage, request_scratch.allocator(), &.{});

    var response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    try client.acceptConnectResponseJson(
        try serializeResponseJson(response_storage[0..], .{
            .id = "signer-1",
            .result = .{ .text = secret_text },
        }),
        scratch,
    );
}

fn acceptProgress(
    client: *noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClient,
    storage: *noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClientStorage,
    response_json: []const u8,
    scratch_output: []u8,
    delivery_storage: *noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage,
    request: *const noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerDirectMessageRequest,
    scratch: std.mem.Allocator,
) !noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerDirectMessageProgress {
    const result = try client.acceptDirectMessageResponseJson(
        storage,
        response_json,
        scratch_output,
        delivery_storage,
        request,
        scratch,
    );
    try std.testing.expect(result == .progressed);
    return result.progressed;
}

fn buildRelayListEventJson(
    output: []u8,
    secret_key: *const [32]u8,
    relays: []const []const u8,
    created_at: u64,
) ![]const u8 {
    const pubkey = try common.derivePublicKey(secret_key);
    var tags_storage: [8]noztr.nip01_event.EventTag = undefined;
    var built_tag_storage: [8]noztr.nip17_private_messages.TagBuilder = undefined;
    for (relays, 0..) |relay, i| {
        tags_storage[i] = try noztr.nip17_private_messages.nip17_build_relay_tag(&built_tag_storage[i], relay);
    }
    var event = common.simpleEvent(
        noztr.nip17_private_messages.dm_relays_kind,
        pubkey,
        created_at,
        "",
        tags_storage[0..relays.len],
    );
    try common.signEvent(secret_key, &event);
    return common.serializeEventJson(output, &event);
}

fn buildSignedEventJson(
    output: []u8,
    secret_key: *const [32]u8,
    kind: u32,
    created_at: u64,
    content: []const u8,
    tags: []const noztr.nip01_event.EventTag,
) ![]const u8 {
    var event = common.simpleEvent(kind, try common.derivePublicKey(secret_key), created_at, content, tags);
    try common.signEvent(secret_key, &event);
    return common.serializeEventJson(output, &event);
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) ![]const u8 {
    return serializeResponseJson(output, .{
        .id = id,
        .result = .{ .text = text },
    });
}

fn serializeResponseJson(
    output: []u8,
    response: noztr.nip46_remote_signing.Response,
) ![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(output, .{ .response = response });
}
