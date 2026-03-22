const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Compose one neutral local-state client over the shared store, relay-registry, checkpoint, and
// relay-runtime seams: archive local events, persist named and per-relay checkpoints, remember one
// relay set explicitly, restore it into the shared runtime, then derive one bounded replay plan.
test "recipe: local state client composes archive registry checkpoint and replay seams" {
    var client_store = noztr_sdk.store.MemoryClientStore{};
    var relay_info_store = noztr_sdk.store.MemoryRelayInfoStore{};
    var storage = noztr_sdk.client.local.state.LocalStateClientStorage{};
    var client = noztr_sdk.client.local.state.LocalStateClient.init(
        .{ .relay_checkpoint_scope = "workspace" },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const first_json =
        \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":10,"kind":1,"tags":[],"content":"first","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
    ;
    const second_json =
        \\{"id":"2222222222222222222222222222222222222222222222222222222222222222","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":20,"kind":1,"tags":[],"content":"second","sig":"44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"}
    ;
    try client.ingestEventJson(first_json, arena.allocator());
    try client.ingestEventJson(second_json, arena.allocator());

    const authors = [_]noztr_sdk.store.EventPubkeyHex{
        try noztr_sdk.store.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
    try client.queryEvents(&.{
        .authors = authors[0..],
        .limit = 1,
    }, &page);
    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expect(page.next_cursor != null);

    try client.saveCheckpoint("recent", page.next_cursor.?);
    const query_checkpoint = try client.loadCheckpoint("recent");
    try std.testing.expect(query_checkpoint != null);
    try std.testing.expectEqual(@as(u32, 1), query_checkpoint.?.cursor.offset);

    _ = try client.rememberRelay("wss://relay.one");
    _ = try client.rememberRelay("wss://relay.two");
    try client.saveRelayCheckpoint("wss://relay.two", .{ .offset = 9 });

    var relay_page_storage: [2]noztr_sdk.store.RelayInfoRecord = undefined;
    var relay_page = noztr_sdk.store.RelayInfoResultPage.init(relay_page_storage[0..]);
    var checkpoint_storage = noztr_sdk.runtime.RelayPoolCheckpointStorage{};
    _ = try client.restoreRememberedRelays(&relay_page, &checkpoint_storage);

    try client.markRelayConnected(0);
    try client.markRelayConnected(1);

    var runtime_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.ready_count);

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "workspace",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = noztr_sdk.runtime.RelayPoolReplayStorage{};
    const replay_plan = try client.inspectReplay(replay_specs[0..], &replay_storage);
    try std.testing.expectEqual(@as(u16, 2), replay_plan.replay_count);
    const replay_step = replay_plan.nextStep().?;
    try std.testing.expectEqualStrings("wss://relay.one", replay_step.entry.descriptor.relay_url);
    try std.testing.expect(replay_step.entry.query.cursor == null);
    try std.testing.expectEqual(@as(u32, 9), replay_plan.entry(1).?.query.cursor.?.offset);
}
