const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Compose one CLI-facing archive client over the shared store and runtime floors: ingest local
// event JSON, query it through one bounded page, persist named and per-relay checkpoints
// explicitly, inspect relay runtime, then derive one bounded replay step without hidden runtime.
test "recipe: cli archive client composes shared store and runtime floors" {
    var memory_store = noztr_sdk.store.MemoryClientStore{};
    var client_storage = noztr_sdk.client.CliArchiveClientStorage{};
    var client = noztr_sdk.client.CliArchiveClient.init(
        .{ .relay_checkpoint_scope = "tooling" },
        memory_store.asClientStore(),
        &client_storage,
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

    const first = try client.addRelay("wss://relay.one");
    const second = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(first.relay_index);
    try client.markRelayConnected(second.relay_index);
    try client.saveRelayCheckpoint("wss://relay.two", .{ .offset = 9 });

    var runtime_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.ready_count);
    try std.testing.expect(runtime_plan.nextStep() == null);

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = noztr_sdk.runtime.RelayPoolReplayStorage{};
    const replay_plan = try client.inspectReplay(replay_specs[0..], &replay_storage);
    try std.testing.expectEqual(@as(u16, 2), replay_plan.replay_count);
    const replay_step = replay_plan.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.runtime.RelayPoolReplayAction.replay,
        replay_step.entry.action,
    );
    try std.testing.expectEqualStrings("tooling", replay_step.entry.checkpoint_scope);
    try std.testing.expect(replay_step.entry.query.cursor == null);
    try std.testing.expectEqual(@as(u32, 9), replay_plan.entry(1).?.query.cursor.?.offset);
}
