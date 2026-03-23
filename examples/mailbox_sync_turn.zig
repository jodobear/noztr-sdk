const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Promote one pending mailbox delivery into one explicit publish step, and fall back to one
// bounded receive step when no delivery is pending.
test "recipe: mailbox sync turn surfaces publish and receive work explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var sender_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonTwo(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        40,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try sender_session.advanceRelay());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = noztr_sdk.workflows.dm.mailbox.MailboxOutboundBuffer{};
    var delivery_storage = noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage{};
    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.two",
        41,
        &recipient_secret,
    );
    const delivery = try sender_session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two",
            .content = "sync turn payload",
            .created_at = 42,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var sender_sync_storage = noztr_sdk.workflows.dm.mailbox.MailboxSyncTurnStorage{};
    const publish_turn = try sender_session.beginSyncTurn(.{
        .pending_delivery = &delivery,
        .storage = &sender_sync_storage.workflow,
    });
    try std.testing.expect(publish_turn == .publish);
    try std.testing.expectEqualStrings("wss://relay.two", publish_turn.publish.relay_url);

    var recipient_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&recipient_secret);
    _ = try recipient_session.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try recipient_session.markCurrentRelayConnected();

    var recipient_sync_storage = noztr_sdk.workflows.dm.mailbox.MailboxSyncTurnStorage{};
    const receive_turn = try recipient_session.beginSyncTurn(.{
        .storage = &recipient_sync_storage.workflow,
    });
    try std.testing.expect(receive_turn == .receive);
    try std.testing.expectEqualStrings("wss://relay.two", receive_turn.receive.relay_url);

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const result = try recipient_session.acceptSyncEnvelopeJson(
        &receive_turn,
        delivery.wrap_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(result == .received);
    try std.testing.expectEqualStrings(
        "sync turn payload",
        result.received.envelope.direct_message.message.content,
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

fn buildRelayListEventJsonTwo(
    output: []u8,
    relay_one: []const u8,
    relay_two: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try common.derivePublicKey(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_one } },
        .{ .items = &.{ "relay", relay_two } },
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
            "\"tags\":[[\"relay\",\"{s}\"],[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_one,
            relay_two,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
