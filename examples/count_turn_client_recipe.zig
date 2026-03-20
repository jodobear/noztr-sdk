const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: count turn client closes one bounded count turn explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.CountTurnClientStorage{};
    var client = noztr_sdk.client.CountTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);

    var reply_output: [128]u8 = undefined;
    const count_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 42 } },
    );
    const result = try client.acceptCountMessageJson(&request, count_json, arena.allocator());

    try std.testing.expectEqual(@as(u64, 42), result.count);
    try std.testing.expectEqualStrings("wss://relay.one", result.request.relay.relay_url);
}
