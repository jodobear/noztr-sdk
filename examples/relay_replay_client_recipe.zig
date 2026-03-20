const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay replay client composes one replay req from checkpoint-backed query state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = noztr_sdk.client.RelayReplayClientStorage{};
    var client = noztr_sdk.client.RelayReplayClient.init(.{}, &storage);
    _ = try client.addRelay("wss://relay.one");
    const second = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(0);
    try client.markRelayConnected(second.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", "wss://relay.one", .{ .offset = 7 });

    const authors = [_]noztr_sdk.store.EventPubkeyHex{
        try noztr_sdk.store.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{
                .authors = authors[0..],
                .kinds = (&[_]u32{1})[0..],
                .since = 10,
                .limit = 16,
            },
        },
    };
    var replay_storage = noztr_sdk.runtime.RelayPoolReplayStorage{};
    const replay_plan = try client.inspectReplay(
        checkpoint_store,
        replay_specs[0..],
        &replay_storage,
    );
    const replay_step = replay_plan.nextStep().?;

    var request_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted = try client.composeTargetedReplayRequest(
        request_buffer[0..],
        &replay_step,
        "replay-feed",
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted.relay.relay_url);
    try std.testing.expectEqualStrings("tooling", targeted.checkpoint_scope);

    const parsed = try noztr.nip01_message.client_message_parse_json(
        targeted.request_json,
        arena.allocator(),
    );
    try std.testing.expect(parsed == .req);
    try std.testing.expectEqualStrings("replay-feed", parsed.req.subscription_id);
    try std.testing.expectEqual(@as(u16, 1), parsed.req.filters[0].authors_count);
    try std.testing.expectEqual(@as(u32, 7), targeted.query.cursor.?.offset);
}
