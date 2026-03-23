const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Start one live mailbox subscription turn explicitly, classify wrapped transcript events through
// mailbox intake, then close the turn explicitly.
test "recipe: mailbox subscription turn client accepts live transcript events and closes explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var client_storage = noztr_sdk.client.dm.mailbox.subscription_turn.Storage{};
    var client = noztr_sdk.client.dm.mailbox.subscription_turn.Client.init(.{
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
            .content = "mailbox subscription recipe payload",
            .created_at = 41,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);

    const wrap_event = try noztr.nip01_event.event_parse_json(outbound.wrap_event_json, arena.allocator());
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-feed", .event = wrap_event } },
    );

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const event_intake = try client.acceptSubscriptionMessageJson(
        &request,
        event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(event_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox subscription recipe payload",
        event_intake.envelope.?.direct_message.message.content,
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &request,
        eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );

    const result = try client.completeTurn(request_output[0..], &request);
    try std.testing.expectEqual(@as(u32, 1), result.event_count);
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
