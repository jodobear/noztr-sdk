const std = @import("std");
const relay_replay_turn = @import("relay_replay_turn_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const AuthReplayTurnClientError =
    relay_replay_turn.RelayReplayTurnClientError ||
    relay_auth_client.RelayAuthClientError;

pub const AuthReplayTurnClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: relay_replay_turn.RelayReplayTurnClientConfig = .{},
};

pub const AuthReplayTurnClientStorage = struct {
    replay_turn: relay_replay_turn.RelayReplayTurnClientStorage = .{},
};

pub const AuthReplayEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthReplayEvent = relay_auth_client.PreparedRelayAuthEvent;

pub const AuthReplayTurnStep = union(enum) {
    authenticate: runtime.RelayPoolAuthStep,
    replay: runtime.RelayPoolReplayStep,
};

pub const AuthReplayTurnResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    replayed: relay_replay_turn.ReplayTurnResult,
};

pub const AuthReplayTurnClient = struct {
    config: AuthReplayTurnClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    replay_turn: relay_replay_turn.RelayReplayTurnClient,

    pub fn init(
        config: AuthReplayTurnClientConfig,
        storage: *AuthReplayTurnClientStorage,
    ) AuthReplayTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .replay_turn = relay_replay_turn.RelayReplayTurnClient.attach(
                config.replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn attach(
        config: AuthReplayTurnClientConfig,
        storage: *AuthReplayTurnClientStorage,
    ) AuthReplayTurnClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .replay_turn = relay_replay_turn.RelayReplayTurnClient.attach(
                config.replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *AuthReplayTurnClient,
        relay_url_text: []const u8,
    ) AuthReplayTurnClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "replay_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *AuthReplayTurnClient,
        relay_index: u8,
    ) AuthReplayTurnClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *AuthReplayTurnClient,
        relay_index: u8,
    ) AuthReplayTurnClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *AuthReplayTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) AuthReplayTurnClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "replay_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const AuthReplayTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "replay_turn", storage);
    }

    pub fn inspectAuth(
        self: *const AuthReplayTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.replay_turn.replay_exchange.replay.relay_pool.inspectAuth(storage);
    }

    pub fn inspectReplay(
        self: *const AuthReplayTurnClient,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) AuthReplayTurnClientError!runtime.RelayPoolReplayPlan {
        return self.replay_turn.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn nextStep(
        self: *const AuthReplayTurnClient,
        auth_storage: *runtime.RelayPoolAuthStorage,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        replay_storage: *runtime.RelayPoolReplayStorage,
    ) AuthReplayTurnClientError!?AuthReplayTurnStep {
        const auth_plan = self.inspectAuth(auth_storage);
        if (auth_plan.nextStep()) |step| {
            return .{ .authenticate = step };
        }

        const replay_plan = try self.inspectReplay(checkpoint_store, specs, replay_storage);
        if (replay_plan.nextStep()) |step| {
            return .{ .replay = step };
        }

        return null;
    }

    pub fn prepareAuthEvent(
        self: *const AuthReplayTurnClient,
        auth_storage: *AuthReplayEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) AuthReplayTurnClientError!PreparedAuthReplayEvent {
        const target = try self.selectAuthTarget(step);
        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.local_operator,
            auth_storage,
            event_json_output,
            auth_message_output,
            secret_key,
            created_at,
            target.relay.relay_url,
            target.challenge,
        );
        return .{
            .relay = target.relay,
            .challenge = auth_storage.challengeText(),
            .event = payload.event,
            .event_json = payload.event_json,
            .auth_message_json = payload.auth_message_json,
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *AuthReplayTurnClient,
        prepared: *const PreparedAuthReplayEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) AuthReplayTurnClientError!AuthReplayTurnResult {
        try self.requireCurrentAuth(prepared.relay, prepared.challenge);
        try self.replay_turn.replay_exchange.replay.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = prepared.relay };
    }

    pub fn beginReplayTurn(
        self: *const AuthReplayTurnClient,
        storage: *AuthReplayTurnClientStorage,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) AuthReplayTurnClientError!relay_replay_turn.ReplayTurnRequest {
        return self.replay_turn.beginTurn(
            &storage.replay_turn,
            checkpoint_store,
            output,
            subscription_id,
            specs,
        );
    }

    pub fn acceptReplayMessageJson(
        self: *const AuthReplayTurnClient,
        storage: *AuthReplayTurnClientStorage,
        request: *const relay_replay_turn.ReplayTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) AuthReplayTurnClientError!relay_replay_turn.ReplayTurnIntake {
        return self.replay_turn.acceptReplayMessageJson(
            &storage.replay_turn,
            request,
            relay_message_json,
            scratch,
        );
    }

    pub fn completeReplayTurn(
        self: *const AuthReplayTurnClient,
        storage: *AuthReplayTurnClientStorage,
        output: []u8,
        request: *const relay_replay_turn.ReplayTurnRequest,
    ) AuthReplayTurnClientError!AuthReplayTurnResult {
        const replayed = try self.replay_turn.completeTurn(&storage.replay_turn, output, request);
        return .{ .replayed = replayed };
    }

    pub fn saveTurnResult(
        self: *const AuthReplayTurnClient,
        archive: store.RelayCheckpointArchive,
        result: *const relay_replay_turn.ReplayTurnResult,
    ) AuthReplayTurnClientError!void {
        return self.replay_turn.saveTurnResult(archive, result);
    }

    fn selectAuthTarget(
        self: *const AuthReplayTurnClient,
        step: *const runtime.RelayPoolAuthStep,
    ) AuthReplayTurnClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(
            &self.replay_turn.replay_exchange.replay.relay_pool,
            plan,
            step,
        );
    }

    fn requireCurrentAuth(
        self: *const AuthReplayTurnClient,
        descriptor: runtime.RelayDescriptor,
        challenge: []const u8,
    ) AuthReplayTurnClientError!void {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.requireCurrentAuth(plan, descriptor, challenge);
    }
};

test "auth replay turn client exposes caller-owned config and storage" {
    var storage = AuthReplayTurnClientStorage{};
    var client = AuthReplayTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(
        @as(u8, 0),
        client.replay_turn.replay_exchange.replay.relay_pool.relayCount(),
    );
}

test "auth replay turn client authenticates then resumes one bounded replay turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = AuthReplayTurnClientStorage{};
    var client = AuthReplayTurnClient.init(.{}, &storage);
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

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var replay_plan_storage = runtime.RelayPoolReplayStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        checkpoint_store,
        replay_specs[0..],
        &replay_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x52} ** 32;
    var auth_event_storage = AuthReplayEventStorage{};
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

    const replay_step = (try client.nextStep(
        &auth_plan_storage,
        checkpoint_store,
        replay_specs[0..],
        &replay_plan_storage,
    )).?.replay;
    try std.testing.expectEqual(relay.relay_index, replay_step.entry.descriptor.relay_index);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginReplayTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "hello auth replay turn",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    const event_intake = try client.acceptReplayMessageJson(
        &storage,
        &request,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(event_intake.replay.message == .event);
    try std.testing.expect(event_intake.checkpoint_candidate == null);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    const eose_intake = try client.acceptReplayMessageJson(
        &storage,
        &request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(eose_intake.replay.message == .eose);
    try std.testing.expect(eose_intake.checkpoint_candidate != null);

    const result = try client.completeReplayTurn(&storage, request_output[0..], &request);
    try std.testing.expect(result == .replayed);
    try std.testing.expectEqual(@as(u32, 8), result.replayed.checkpoint_candidate.cursor.offset);

    try client.saveTurnResult(checkpoint_archive, &result.replayed);
    const restored = try checkpoint_archive.loadRelayCheckpoint("tooling", relay.relay_url);
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 8), restored.?.cursor.offset);
}

test "auth replay turn client rejects incomplete replay after auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = AuthReplayTurnClientStorage{};
    var client = AuthReplayTurnClient.init(.{}, &storage);
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

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var replay_plan_storage = runtime.RelayPoolReplayStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        checkpoint_store,
        replay_specs[0..],
        &replay_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x53} ** 32;
    var auth_event_storage = AuthReplayEventStorage{};
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
    _ = try client.acceptPreparedAuthEvent(&prepared_auth, 95, 60);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginReplayTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "partial auth replay turn",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    _ = try client.acceptReplayMessageJson(
        &storage,
        &request,
        event_json,
        arena.allocator(),
    );

    try std.testing.expectError(
        error.IncompleteTranscript,
        client.completeReplayTurn(&storage, request_output[0..], &request),
    );
}

test "auth replay turn client rejects stale auth posture" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = AuthReplayTurnClientStorage{};
    var client = AuthReplayTurnClient.init(.{}, &storage);
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

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var replay_plan_storage = runtime.RelayPoolReplayStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        checkpoint_store,
        replay_specs[0..],
        &replay_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x54} ** 32;
    var auth_event_storage = AuthReplayEventStorage{};
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

    try client.noteRelayDisconnected(relay.relay_index);
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-2");
    try std.testing.expectError(
        error.StaleAuthStep,
        client.acceptPreparedAuthEvent(&prepared_auth, 95, 60),
    );
}
