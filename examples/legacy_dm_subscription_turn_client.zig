const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Start one live legacy DM subscription turn explicitly, then decrypt kind-4 transcript events
// without inventing a polling loop.
test "recipe: legacy dm subscription turn client classifies live events through dm intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x31} ** 32;
    const recipient_secret = [_]u8{0x42} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    const sender = noztr_sdk.workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    var outbound = noztr_sdk.workflows.dm.legacy.LegacyDmOutboundStorage{};
    const prepared = try sender.buildDirectMessageEvent(&outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy live recipe",
        .created_at = 71,
        .iv = [_]u8{0x44} ** noztr.limits.nip04_iv_bytes,
    });

    var storage = noztr_sdk.client.dm.legacy.subscription_turn.Storage{};
    var client = noztr_sdk.client.dm.legacy.subscription_turn.Client.init(.{
        .owner_private_key = recipient_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-live", .event = prepared.event } },
    );
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const intake = try client.acceptSubscriptionMessageJson(
        &request,
        event_json,
        plaintext_output[0..],
        arena.allocator(),
    );

    try std.testing.expect(intake.message != null);
    try std.testing.expectEqualStrings("legacy live recipe", intake.message.?.plaintext);
}
