const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay replay turn client closes one replay turn and persists one checkpoint target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = noztr_sdk.client.RelayReplayTurnClientStorage{};
    var client = noztr_sdk.client.RelayReplayTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const turn_request = try client.beginTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const secret_key = [_]u8{0x79} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 27,
        .tags = &.{},
        .content = "replay turn recipe",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    const event_intake = try client.acceptReplayMessageJson(
        &storage,
        &turn_request,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(event_intake.replay.message == .event);
    try std.testing.expect(event_intake.checkpoint_candidate == null);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    const eose_intake = try client.acceptReplayMessageJson(
        &storage,
        &turn_request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(eose_intake.replay.message == .eose);
    try std.testing.expect(eose_intake.checkpoint_candidate != null);

    const turn_result = try client.completeTurn(&storage, request_output[0..], &turn_request);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"replay-feed\"]", turn_result.close.request_json);

    try client.saveTurnResult(checkpoint_archive, &turn_result);
    const restored = try checkpoint_archive.loadRelayCheckpoint("tooling", relay.relay_url);
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 8), restored.?.cursor.offset);
}
