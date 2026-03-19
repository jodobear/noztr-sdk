const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Inspect one shared multi-relay runtime plan, select one typed next pool step explicitly, then
// drive the pool back to an all-ready state without hidden background runtime.
test "recipe: relay pool inspects runtime and selects one typed next step" {
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
}
