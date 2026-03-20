const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: subscription turn client closes one bounded transcript turn explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.SubscriptionTurnClientStorage{};
    var client = noztr_sdk.client.SubscriptionTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(&storage, request_output[0..], specs[0..]);

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    const intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(intake.complete);

    const result = try client.completeTurn(&storage, request_output[0..], &request);
    try std.testing.expectEqual(.eose, result.completion);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", result.close.request_json);
}
