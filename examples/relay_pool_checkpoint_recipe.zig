const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Export one shared relay-pool checkpoint set, persist the per-relay cursors through the shared
// checkpoint seam, then restore a fresh shared pool from that bounded checkpoint set explicitly.
test "recipe: relay pool checkpoints compose with shared checkpoint storage" {
    var pool_storage = noztr_sdk.runtime.RelayPoolStorage{};
    var pool = noztr_sdk.runtime.RelayPool.init(&pool_storage);
    _ = try pool.addRelay("wss://relay.one");
    _ = try pool.addRelay("wss://relay.two");

    const cursors = [_]noztr_sdk.store.EventCursor{
        .{ .offset = 7 },
        .{ .offset = 9 },
    };
    var checkpoint_storage = noztr_sdk.runtime.RelayPoolCheckpointStorage{};
    const checkpoints = try pool.exportCheckpoints(cursors[0..], &checkpoint_storage);
    const export_step = checkpoints.nextExportStep().?;
    try std.testing.expectEqual(
        noztr_sdk.runtime.RelayPoolCheckpointAction.export_checkpoint,
        export_step.action,
    );
    try std.testing.expectEqualStrings("wss://relay.one", export_step.record.relayUrl());

    var store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.RelayCheckpointArchive.init(store.asClientStore());
    var index: u8 = 0;
    while (index < checkpoints.relay_count) : (index += 1) {
        const record = checkpoints.entry(index).?;
        try archive.saveRelayCheckpoint("relay-pool", record.relayUrl(), record.cursor);
    }

    var restored_checkpoint_storage = noztr_sdk.runtime.RelayPoolCheckpointStorage{};
    inline for (.{ "wss://relay.one", "wss://relay.two" }, 0..) |relay_url_text, relay_index| {
        const restored = (try archive.loadRelayCheckpoint("relay-pool", relay_url_text)).?;
        restored_checkpoint_storage.records[relay_index] = .{
            .relay_url_len = @intCast(relay_url_text.len),
            .cursor = restored.cursor,
        };
        @memcpy(
            restored_checkpoint_storage.records[relay_index].relay_url[0..relay_url_text.len],
            relay_url_text,
        );
    }
    const restored_checkpoints = noztr_sdk.runtime.RelayPoolCheckpointSet{
        .records = restored_checkpoint_storage.records[0..2],
        .relay_count = 2,
    };
    const restore_step = restored_checkpoints.nextRestoreStep().?;
    try std.testing.expectEqual(
        noztr_sdk.runtime.RelayPoolCheckpointAction.restore_checkpoint,
        restore_step.action,
    );
    try std.testing.expectEqualStrings("wss://relay.one", restore_step.record.relayUrl());

    var restored_pool_storage = noztr_sdk.runtime.RelayPoolStorage{};
    var restored_pool = noztr_sdk.runtime.RelayPool.init(&restored_pool_storage);
    try restored_pool.restoreCheckpoints(&restored_checkpoints);

    var plan_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const restored_plan = restored_pool.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), restored_plan.connect_count);
    try std.testing.expectEqualStrings("wss://relay.one", restored_pool.descriptor(0).?.relay_url);
    try std.testing.expectEqualStrings("wss://relay.two", restored_pool.descriptor(1).?.relay_url);
}
