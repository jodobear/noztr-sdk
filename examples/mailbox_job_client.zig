const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Drive mailbox auth, publish, and receive work through one command-ready job surface while
// keeping transport and polling explicit.
test "recipe: mailbox job client prepares auth and receive work explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_secret = [_]u8{0x33} ** 32;
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var client_storage = noztr_sdk.client.dm.mailbox.job.MailboxJobClientStorage{};
    var client = noztr_sdk.client.dm.mailbox.job.MailboxJobClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &client_storage);

    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try client.markCurrentRelayConnected();
    try client.noteCurrentRelayAuthChallenge("challenge-1");

    var auth_storage = noztr_sdk.client.dm.mailbox.job.MailboxJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const auth_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        null,
        90,
    );
    try std.testing.expect(auth_ready == .authenticate);
    const auth_result = try client.acceptPreparedAuthEvent(&auth_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    var sender_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        41,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = noztr_sdk.workflows.dm.mailbox.MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "job client payload",
            .created_at = 91,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    const receive_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        null,
        90,
    );
    try std.testing.expect(receive_ready == .receive);

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const receive_result = try client.acceptReceiveEnvelopeJson(
        &receive_ready.receive,
        outbound.wrap_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(receive_result == .received);
    try std.testing.expectEqualStrings(
        "job client payload",
        receive_result.received.envelope.direct_message.message.content,
    );
}

fn buildRelayListEventJson(
    output: []u8,
    relay_text: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try common.derivePublicKey(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_text } },
    };
    var event = common.simpleEvent(
        noztr.nip17_private_messages.dm_relays_kind,
        relay_list_author_pubkey,
        created_at,
        "",
        tags[0..],
    );
    try common.signEvent(signer_secret_key, &event);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":10050," ++
            "\"tags\":[[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_text,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
