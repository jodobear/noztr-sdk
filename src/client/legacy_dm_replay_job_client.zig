const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const legacy_dm_replay_turn = @import("legacy_dm_replay_turn_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const LegacyDmReplayJobClientError =
    legacy_dm_replay_turn.LegacyDmReplayTurnClientError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoReadyRelay,
        StaleAuthStep,
        RelayNotReady,
    };

pub const LegacyDmReplayJobClientConfig = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: legacy_dm_replay_turn.LegacyDmReplayTurnClientConfig = undefined,
};

pub const LegacyDmReplayJobClientStorage = struct {
    replay_turn: legacy_dm_replay_turn.LegacyDmReplayTurnClientStorage = .{},
};

pub const LegacyDmReplayJobAuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedLegacyDmReplayJobAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const LegacyDmReplayJobRequest = legacy_dm_replay_turn.LegacyDmReplayTurnRequest;
pub const LegacyDmReplayJobIntake = legacy_dm_replay_turn.LegacyDmReplayTurnIntake;

pub const LegacyDmReplayJobReady = union(enum) {
    authenticate: PreparedLegacyDmReplayJobAuthEvent,
    replay: LegacyDmReplayJobRequest,
};

pub const LegacyDmReplayJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    replayed: legacy_dm_replay_turn.LegacyDmReplayTurnResult,
};

pub const LegacyDmReplayJobClient = struct {
    config: LegacyDmReplayJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    replay_turn: legacy_dm_replay_turn.LegacyDmReplayTurnClient,

    pub fn init(
        config: LegacyDmReplayJobClientConfig,
        storage: *LegacyDmReplayJobClientStorage,
    ) LegacyDmReplayJobClient {
        storage.* = .{};
        return .{
            .config = configWithReplayTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .replay_turn = legacy_dm_replay_turn.LegacyDmReplayTurnClient.init(
                configWithReplayTurn(config).replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn attach(
        config: LegacyDmReplayJobClientConfig,
        storage: *LegacyDmReplayJobClientStorage,
    ) LegacyDmReplayJobClient {
        return .{
            .config = configWithReplayTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .replay_turn = legacy_dm_replay_turn.LegacyDmReplayTurnClient.attach(
                configWithReplayTurn(config).replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *LegacyDmReplayJobClient,
        relay_url_text: []const u8,
    ) LegacyDmReplayJobClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "replay_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *LegacyDmReplayJobClient,
        relay_index: u8,
    ) LegacyDmReplayJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LegacyDmReplayJobClient,
        relay_index: u8,
    ) LegacyDmReplayJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *LegacyDmReplayJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) LegacyDmReplayJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "replay_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const LegacyDmReplayJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "replay_turn", storage);
    }

    pub fn prepareJob(
        self: *LegacyDmReplayJobClient,
        auth_storage: *LegacyDmReplayJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        checkpoint_store: store.ClientCheckpointStore,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
        created_at: u64,
    ) LegacyDmReplayJobClientError!LegacyDmReplayJobReady {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const auth_plan = self.replay_turn.inspectAuth(&auth_storage_buf);
        if (auth_plan.nextStep()) |step| {
            return .{
                .authenticate = try self.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &step,
                    created_at,
                ),
            };
        }

        var replay_storage_buf = runtime.RelayPoolReplayStorage{};
        const replay_plan = try self.replay_turn.inspectReplay(
            checkpoint_store,
            specs,
            &replay_storage_buf,
        );
        _ = replay_plan.nextStep() orelse return error.NoReadyRelay;
        return .{
            .replay = try self.replay_turn.beginTurn(
                checkpoint_store,
                request_output,
                subscription_id,
                specs,
            ),
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *LegacyDmReplayJobClient,
        prepared: *const PreparedLegacyDmReplayJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) LegacyDmReplayJobClientError!LegacyDmReplayJobResult {
        const descriptor = try self.replay_turn.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = descriptor };
    }

    pub fn acceptReplayMessageJson(
        self: *LegacyDmReplayJobClient,
        request: *const LegacyDmReplayJobRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) LegacyDmReplayJobClientError!LegacyDmReplayJobIntake {
        return self.replay_turn.acceptReplayMessageJson(
            request,
            relay_message_json,
            plaintext_output,
            scratch,
        );
    }

    pub fn completeReplayJob(
        self: *LegacyDmReplayJobClient,
        output: []u8,
        request: *const LegacyDmReplayJobRequest,
    ) LegacyDmReplayJobClientError!LegacyDmReplayJobResult {
        return .{ .replayed = try self.replay_turn.completeTurn(output, request) };
    }

    pub fn saveJobResult(
        self: *LegacyDmReplayJobClient,
        archive: store.RelayCheckpointArchive,
        result: *const legacy_dm_replay_turn.LegacyDmReplayTurnResult,
    ) LegacyDmReplayJobClientError!void {
        return self.replay_turn.saveTurnResult(archive, result);
    }

    fn prepareAuthEvent(
        self: *LegacyDmReplayJobClient,
        auth_storage: *LegacyDmReplayJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) LegacyDmReplayJobClientError!PreparedLegacyDmReplayJobAuthEvent {
        const target = try self.selectAuthTarget(step);
        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.local_operator,
            auth_storage,
            event_json_output,
            auth_message_output,
            &self.config.owner_private_key,
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

    fn selectAuthTarget(
        self: *const LegacyDmReplayJobClient,
        step: *const runtime.RelayPoolAuthStep,
    ) LegacyDmReplayJobClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const plan = self.replay_turn.inspectAuth(&auth_storage_buf);
        return relay_auth_support.selectAuthTarget(
            &self.replay_turn.replay_turn.replay_exchange.replay.relay_pool,
            plan,
            step,
        );
    }
};

fn configWithReplayTurn(config: LegacyDmReplayJobClientConfig) LegacyDmReplayJobClientConfig {
    var updated = config;
    updated.replay_turn = .{
        .owner_private_key = config.owner_private_key,
        .replay_turn = config.replay_turn.replay_turn,
    };
    return updated;
}
