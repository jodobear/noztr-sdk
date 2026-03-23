const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Inspect one shared multi-relay runtime plan, select one typed next pool step explicitly, then
// derive one bounded shared subscription plan over the ready relays without hidden background
// runtime.
test "recipe: relay pool inspects runtime and derives one bounded subscription step" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.runtime.RelayPoolStorage{};
    var pool = noztr_sdk.runtime.RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");

    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    var plan_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const plan = pool.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
    const step = plan.nextStep().?;
    try std.testing.expectEqual(noztr_sdk.runtime.RelayPoolAction.authenticate, step.entry.action);
    try std.testing.expectEqualStrings("wss://relay.one", step.entry.descriptor.relay_url);

    try pool.noteRelayDisconnected(first.relay_index);
    try pool.markRelayConnected(first.relay_index);
    try pool.markRelayConnected(second.relay_index);

    const ready_plan = pool.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), ready_plan.ready_count);
    try std.testing.expect(ready_plan.nextEntry() == null);
    try std.testing.expect(ready_plan.nextStep() == null);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{
            .subscription_id = "feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var subscription_storage = noztr_sdk.runtime.RelayPoolSubscriptionStorage{};
    const subscription_plan = try pool.inspectSubscriptions(specs[0..], &subscription_storage);
    try std.testing.expectEqual(@as(u8, 2), subscription_plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), subscription_plan.spec_count);
    try std.testing.expectEqual(@as(u16, 2), subscription_plan.subscribe_count);
    const subscription_step = subscription_plan.nextStep().?;
    try std.testing.expectEqualStrings("feed", subscription_step.entry.subscription_id);
    try std.testing.expectEqual(
        noztr_sdk.runtime.RelayPoolSubscriptionAction.subscribe,
        subscription_step.entry.action,
    );
    try std.testing.expectEqualStrings("wss://relay.one", subscription_step.entry.descriptor.relay_url);
}
