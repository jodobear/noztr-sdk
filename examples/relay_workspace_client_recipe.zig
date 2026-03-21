const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Remember one explicit relay set, restore it into the shared relay runtime, inspect runtime
// posture, and derive one bounded replay plan over the remembered workspace state.
test "recipe: relay workspace client composes remembered relay state with runtime and replay inspection" {
    var client_store = noztr_sdk.store.MemoryClientStore{};
    var relay_info_store = noztr_sdk.store.MemoryRelayInfoStore{};
    var storage = noztr_sdk.client.RelayWorkspaceClientStorage{};
    var client = noztr_sdk.client.RelayWorkspaceClient.init(
        .{ .cli_archive = .{ .relay_checkpoint_scope = "tooling" } },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage,
    );

    _ = try client.rememberRelay("wss://relay.one");
    _ = try client.rememberRelay("wss://relay.two");
    try client.saveRelayCheckpoint("wss://relay.two", .{ .offset = 9 });

    var page_storage: [2]noztr_sdk.store.RelayInfoRecord = undefined;
    var page = noztr_sdk.store.RelayInfoResultPage.init(page_storage[0..]);
    var checkpoint_storage = noztr_sdk.runtime.RelayPoolCheckpointStorage{};
    _ = try client.restoreRememberedRelays(&page, &checkpoint_storage);

    try client.markRelayConnected(0);
    try client.markRelayConnected(1);

    var runtime_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.ready_count);

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = noztr_sdk.runtime.RelayPoolReplayStorage{};
    const replay_plan = try client.inspectReplay(replay_specs[0..], &replay_storage);
    try std.testing.expectEqual(@as(u16, 2), replay_plan.replay_count);
    try std.testing.expectEqual(@as(u32, 9), replay_plan.entry(1).?.query.cursor.?.offset);
}
