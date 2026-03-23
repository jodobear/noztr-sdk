const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Prepare explicit mailbox replay work that either authenticates one relay or starts one bounded
// mailbox replay turn, then close that replay with one explicit checkpoint result.
test "recipe: mailbox replay job client authenticates then replays mailbox intake explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var client_storage = noztr_sdk.client.dm.mailbox.replay_job.Storage{};
    var client = noztr_sdk.client.dm.mailbox.replay_job.Client.init(.{
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
    try client.markRelayConnected(0);
    try client.noteRelayAuthChallenge(0, "challenge-1");

    var sender_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
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
            .content = "mailbox replay job recipe payload",
            .created_at = 41,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };

    var auth_storage = noztr_sdk.client.dm.mailbox.replay_job.AuthStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        checkpoint_store,
        "mailbox-feed",
        replay_specs[0..],
        90,
    );
    try std.testing.expect(first_ready == .authenticate);
    _ = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        checkpoint_store,
        "mailbox-feed",
        replay_specs[0..],
        91,
    );
    try std.testing.expect(second_ready == .replay);

    const wrap_event = try noztr.nip01_event.event_parse_json(
        outbound.wrap_event_json,
        arena.allocator(),
    );
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-feed", .event = wrap_event } },
    );
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const event_intake = try client.acceptReplayMessageJson(
        &second_ready.replay,
        event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(event_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox replay job recipe payload",
        event_intake.envelope.?.direct_message.message.content,
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    _ = try client.acceptReplayMessageJson(
        &second_ready.replay,
        eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );

    const result = try client.completeReplayJob(request_output[0..], &second_ready.replay);
    try std.testing.expect(result == .replayed);
    try std.testing.expectEqual(@as(u32, 8), result.replayed.checkpoint_candidate.cursor.offset);
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
