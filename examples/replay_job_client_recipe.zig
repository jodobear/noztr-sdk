const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: replay job client authenticates when needed then returns one command-ready replay request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = noztr_sdk.client.relay.replay_job.ReplayJobClientStorage{};
    var client = noztr_sdk.client.relay.replay_job.ReplayJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    const secret_key = [_]u8{0x33} ** 32;
    var auth_storage = noztr_sdk.client.relay.replay_job.ReplayJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        checkpoint_store,
        "replay-feed",
        replay_specs[0..],
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        checkpoint_store,
        "replay-feed",
        replay_specs[0..],
        90,
    );
    try std.testing.expect(second_ready == .replay);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    const intake = try client.acceptReplayMessageJson(
        &storage,
        &second_ready.replay,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(intake.checkpoint_candidate != null);

    const result = try client.completeReplayJob(
        &storage,
        request_output[0..],
        &second_ready.replay,
    );
    try std.testing.expect(result == .replayed);
    try std.testing.expectEqual(@as(u32, 7), result.replayed.checkpoint_candidate.cursor.offset);
}
