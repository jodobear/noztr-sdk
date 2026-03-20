const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay query client composes one req count and close payload over ready relays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.RelayQueryClientStorage{};
    var client = noztr_sdk.client.RelayQueryClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    const gated = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(ready.relay_index);
    try client.markRelayConnected(gated.relay_index);
    try client.noteRelayAuthChallenge(gated.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );

    const subscription_specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{
            .subscription_id = "feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var subscription_storage = noztr_sdk.runtime.RelayPoolSubscriptionStorage{};
    const subscription_plan = try client.inspectSubscriptions(
        subscription_specs[0..],
        &subscription_storage,
    );
    try std.testing.expectEqual(@as(u16, 1), subscription_plan.subscribe_count);

    const count_specs = [_]noztr_sdk.runtime.RelayCountSpec{
        .{
            .subscription_id = "count-feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var count_storage = noztr_sdk.runtime.RelayPoolCountStorage{};
    const count_plan = try client.inspectCounts(count_specs[0..], &count_storage);
    try std.testing.expectEqual(@as(u16, 1), count_plan.count_count);

    var request_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const subscription_step = subscription_plan.nextStep().?;
    const targeted_req = try client.composeTargetedSubscriptionRequest(
        request_buffer[0..],
        &subscription_step,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_req.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted_req.request_json, "[\"REQ\","));

    const count_step = count_plan.nextStep().?;
    const targeted_count = try client.composeTargetedCountRequest(
        request_buffer[0..],
        &count_step,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_count.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted_count.request_json, "[\"COUNT\","));

    const target = try client.selectSubscriptionTarget(&subscription_step);
    const targeted_close = try client.composeTargetedCloseRequest(
        request_buffer[0..],
        &target,
        "feed",
    );
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", targeted_close.request_json);
}
