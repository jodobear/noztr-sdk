const std = @import("std");
const auth_replay_turn = @import("auth_replay_turn_client.zig");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const replay_turn = @import("relay_replay_turn_client.zig");
const store = @import("../store/mod.zig");

pub const ReplayJobClientError = auth_replay_turn.AuthReplayTurnClientError;

pub const ReplayJobClientConfig = struct {
    auth_replay_turn: auth_replay_turn.AuthReplayTurnClientConfig = .{},
};

pub const ReplayJobClientStorage = struct {
    auth_replay_turn: auth_replay_turn.AuthReplayTurnClientStorage = .{},
};

pub const ReplayJobAuthEventStorage = auth_replay_turn.AuthReplayEventStorage;
pub const PreparedReplayJobAuthEvent = auth_replay_turn.PreparedAuthReplayEvent;
pub const ReplayJobRequest = replay_turn.ReplayTurnRequest;
pub const ReplayJobIntake = replay_turn.ReplayTurnIntake;

pub const ReplayJobReady = union(enum) {
    authenticate: PreparedReplayJobAuthEvent,
    replay: ReplayJobRequest,
};

pub const ReplayJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    replayed: replay_turn.ReplayTurnResult,
};

pub const ReplayJobClient = struct {
    config: ReplayJobClientConfig,
    auth_replay_turn: auth_replay_turn.AuthReplayTurnClient,

    pub fn init(
        config: ReplayJobClientConfig,
        storage: *ReplayJobClientStorage,
    ) ReplayJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .auth_replay_turn = auth_replay_turn.AuthReplayTurnClient.attach(
                config.auth_replay_turn,
                &storage.auth_replay_turn,
            ),
        };
    }

    pub fn attach(
        config: ReplayJobClientConfig,
        storage: *ReplayJobClientStorage,
    ) ReplayJobClient {
        return .{
            .config = config,
            .auth_replay_turn = auth_replay_turn.AuthReplayTurnClient.attach(
                config.auth_replay_turn,
                &storage.auth_replay_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *ReplayJobClient,
        relay_url_text: []const u8,
    ) ReplayJobClientError!runtime.RelayDescriptor {
        return self.auth_replay_turn.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *ReplayJobClient,
        relay_index: u8,
    ) ReplayJobClientError!void {
        return self.auth_replay_turn.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *ReplayJobClient,
        relay_index: u8,
    ) ReplayJobClientError!void {
        return self.auth_replay_turn.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *ReplayJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) ReplayJobClientError!void {
        return self.auth_replay_turn.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const ReplayJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.auth_replay_turn.inspectRelayRuntime(storage);
    }

    pub fn prepareJob(
        self: *const ReplayJobClient,
        storage: *ReplayJobClientStorage,
        auth_storage: *ReplayJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        checkpoint_store: store.ClientCheckpointStore,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
        created_at: u64,
    ) ReplayJobClientError!ReplayJobReady {
        var auth_plan_storage = runtime.RelayPoolAuthStorage{};
        var replay_plan_storage = runtime.RelayPoolReplayStorage{};
        const next = try self.auth_replay_turn.nextStep(
            &auth_plan_storage,
            checkpoint_store,
            specs,
            &replay_plan_storage,
        ) orelse return error.NoReadyRelay;

        return switch (next) {
            .authenticate => .{
                .authenticate = try self.auth_replay_turn.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &next.authenticate,
                    secret_key,
                    created_at,
                ),
            },
            .replay => .{
                .replay = try self.auth_replay_turn.beginReplayTurn(
                    &storage.auth_replay_turn,
                    checkpoint_store,
                    request_output,
                    subscription_id,
                    specs,
                ),
            },
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *ReplayJobClient,
        prepared: *const PreparedReplayJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) ReplayJobClientError!ReplayJobResult {
        const result = try self.auth_replay_turn.acceptPreparedAuthEvent(
            prepared,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = result.authenticated };
    }

    pub fn acceptReplayMessageJson(
        self: *const ReplayJobClient,
        storage: *ReplayJobClientStorage,
        request: *const ReplayJobRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) ReplayJobClientError!ReplayJobIntake {
        return self.auth_replay_turn.acceptReplayMessageJson(
            &storage.auth_replay_turn,
            request,
            relay_message_json,
            scratch,
        );
    }

    pub fn completeReplayJob(
        self: *const ReplayJobClient,
        storage: *ReplayJobClientStorage,
        output: []u8,
        request: *const ReplayJobRequest,
    ) ReplayJobClientError!ReplayJobResult {
        const result = try self.auth_replay_turn.completeReplayTurn(
            &storage.auth_replay_turn,
            output,
            request,
        );
        return .{ .replayed = result.replayed };
    }

    pub fn saveJobResult(
        self: *const ReplayJobClient,
        archive: store.RelayCheckpointArchive,
        result: *const replay_turn.ReplayTurnResult,
    ) ReplayJobClientError!void {
        return self.auth_replay_turn.saveTurnResult(archive, result);
    }
};

test "replay job client exposes caller-owned config and storage" {
    var storage = ReplayJobClientStorage{};
    var client = ReplayJobClient.init(.{}, &storage);

    try std.testing.expectEqual(
        @as(u8, 0),
        client.auth_replay_turn.replay_turn.replay_exchange.replay.relay_pool.relayCount(),
    );
}

test "replay job client drives auth-gated replay work and checkpoint save through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = ReplayJobClientStorage{};
    var client = ReplayJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    const secret_key = [_]u8{0x81} ** 32;
    var auth_storage = ReplayJobAuthEventStorage{};
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
    try std.testing.expectEqual(relay.relay_index, second_ready.replay.replay.relay.relay_index);

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "replay job event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    _ = try client.acceptReplayMessageJson(
        &storage,
        &second_ready.replay,
        event_json,
        arena.allocator(),
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
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
    try std.testing.expectEqual(@as(u32, 8), result.replayed.checkpoint_candidate.cursor.offset);

    try client.saveJobResult(checkpoint_archive, &result.replayed);
    const restored = try checkpoint_archive.loadRelayCheckpoint("tooling", relay.relay_url);
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 8), restored.?.cursor.offset);
}

test "replay job client rejects incomplete replay after auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = ReplayJobClientStorage{};
    var client = ReplayJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    const secret_key = [_]u8{0x82} ** 32;
    var auth_storage = ReplayJobAuthEventStorage{};
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
    _ = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);

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

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "partial replay job event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    _ = try client.acceptReplayMessageJson(
        &storage,
        &second_ready.replay,
        event_json,
        arena.allocator(),
    );

    try std.testing.expectError(
        error.IncompleteTranscript,
        client.completeReplayJob(&storage, request_output[0..], &second_ready.replay),
    );
}

test "replay job client rejects stale auth posture explicitly" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = ReplayJobClientStorage{};
    var client = ReplayJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    const secret_key = [_]u8{0x83} ** 32;
    var auth_storage = ReplayJobAuthEventStorage{};
    var auth_event_json_output: [@import("noztr").limits.event_json_max]u8 = undefined;
    var auth_message_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
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
    try std.testing.expect(ready == .authenticate);

    try client.noteRelayDisconnected(relay.relay_index);
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-2");
    try std.testing.expectError(
        error.StaleAuthStep,
        client.acceptPreparedAuthEvent(&ready.authenticate, 95, 60),
    );
}
