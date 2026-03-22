const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: auth replay turn client authenticates then resumes one bounded replay turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = noztr_sdk.client.relay.auth_replay_turn.AuthReplayTurnClientStorage{};
    var client = noztr_sdk.client.relay.auth_replay_turn.AuthReplayTurnClient.init(.{}, &storage);
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

    var auth_plan_storage = noztr_sdk.runtime.RelayPoolAuthStorage{};
    var replay_plan_storage = noztr_sdk.runtime.RelayPoolReplayStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        checkpoint_store,
        replay_specs[0..],
        &replay_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x55} ** 32;
    var auth_event_storage = noztr_sdk.client.relay.auth_replay_turn.AuthReplayEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        90,
    );
    const auth_result = try client.acceptPreparedAuthEvent(&prepared_auth, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginReplayTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    const intake = try client.acceptReplayMessageJson(
        &storage,
        &request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(intake.checkpoint_candidate != null);

    const result = try client.completeReplayTurn(&storage, request_output[0..], &request);
    try std.testing.expect(result == .replayed);
    try std.testing.expectEqual(@as(u32, 7), result.replayed.checkpoint_candidate.cursor.offset);
}
