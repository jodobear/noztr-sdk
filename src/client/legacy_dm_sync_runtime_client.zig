const std = @import("std");
const noztr = @import("noztr");
const legacy_dm_replay_job = @import("legacy_dm_replay_job_client.zig");
const legacy_dm_replay_turn = @import("legacy_dm_replay_turn_client.zig");
const legacy_dm_subscription_job = @import("legacy_dm_subscription_job_client.zig");
const local_operator = @import("local_operator_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const LegacyDmSyncRuntimeClientError =
    legacy_dm_replay_job.LegacyDmReplayJobClientError ||
    legacy_dm_subscription_job.LegacyDmSubscriptionJobClientError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleAuthStep,
        RelayNotReady,
    };

pub const LegacyDmSyncRuntimeClientConfig = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: legacy_dm_replay_job.LegacyDmReplayJobClientConfig = undefined,
    subscription_turn: legacy_dm_subscription_job.LegacyDmSubscriptionJobClientConfig = undefined,
};

pub const LegacyDmSyncRuntimeClientStorage = struct {
    replay_job: legacy_dm_replay_job.LegacyDmReplayJobClientStorage = .{},
    subscription_job: legacy_dm_subscription_job.LegacyDmSubscriptionJobClientStorage = .{},
    replay_phase_complete: bool = false,
    live_subscription_active: bool = false,
    live_subscription_request: legacy_dm_subscription_job.LegacyDmSubscriptionJobRequest = undefined,
};

pub const LegacyDmSyncRuntimePlanStorage = struct {
    auth: runtime.RelayPoolAuthStorage = .{},
    replay: runtime.RelayPoolReplayStorage = .{},
    subscription: runtime.RelayPoolSubscriptionStorage = .{},
};

pub const LegacyDmSyncRuntimeStep = union(enum) {
    authenticate: runtime.RelayPoolAuthStep,
    replay: runtime.RelayPoolReplayStep,
    subscribe: runtime.RelayPoolSubscriptionStep,
    receive: legacy_dm_subscription_job.LegacyDmSubscriptionJobRequest,
    idle,
};

pub const LegacyDmSyncRuntimePlan = struct {
    authenticate_count: u8 = 0,
    replay_count: u16 = 0,
    subscribe_count: u16 = 0,
    receive_count: u8 = 0,
    replay_phase_complete: bool = false,
    next_step: LegacyDmSyncRuntimeStep = .idle,

    pub fn nextStep(self: *const LegacyDmSyncRuntimePlan) LegacyDmSyncRuntimeStep {
        return self.next_step;
    }
};

pub const LegacyDmSyncRuntimeAuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedLegacyDmSyncRuntimeAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const LegacyDmSyncRuntimeReplayRequest = legacy_dm_replay_job.LegacyDmReplayJobRequest;
pub const LegacyDmSyncRuntimeReplayIntake = legacy_dm_replay_job.LegacyDmReplayJobIntake;
pub const LegacyDmSyncRuntimeSubscriptionRequest =
    legacy_dm_subscription_job.LegacyDmSubscriptionJobRequest;
pub const LegacyDmSyncRuntimeSubscriptionIntake =
    legacy_dm_subscription_job.LegacyDmSubscriptionJobIntake;

pub const LegacyDmSyncRuntimeClient = struct {
    config: LegacyDmSyncRuntimeClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    replay_job: legacy_dm_replay_job.LegacyDmReplayJobClient,
    subscription_job: legacy_dm_subscription_job.LegacyDmSubscriptionJobClient,
    storage: *LegacyDmSyncRuntimeClientStorage,

    pub fn init(
        config: LegacyDmSyncRuntimeClientConfig,
        storage: *LegacyDmSyncRuntimeClientStorage,
    ) LegacyDmSyncRuntimeClient {
        storage.* = .{};
        const normalized = normalizeConfig(config);
        return .{
            .config = normalized,
            .local_operator = local_operator.LocalOperatorClient.init(normalized.local_operator),
            .replay_job = legacy_dm_replay_job.LegacyDmReplayJobClient.init(
                normalized.replay_turn,
                &storage.replay_job,
            ),
            .subscription_job = legacy_dm_subscription_job.LegacyDmSubscriptionJobClient.init(
                normalized.subscription_turn,
                &storage.subscription_job,
            ),
            .storage = storage,
        };
    }

    pub fn attach(
        config: LegacyDmSyncRuntimeClientConfig,
        storage: *LegacyDmSyncRuntimeClientStorage,
    ) LegacyDmSyncRuntimeClient {
        const normalized = normalizeConfig(config);
        return .{
            .config = normalized,
            .local_operator = local_operator.LocalOperatorClient.init(normalized.local_operator),
            .replay_job = legacy_dm_replay_job.LegacyDmReplayJobClient.attach(
                normalized.replay_turn,
                &storage.replay_job,
            ),
            .subscription_job = legacy_dm_subscription_job.LegacyDmSubscriptionJobClient.attach(
                normalized.subscription_turn,
                &storage.subscription_job,
            ),
            .storage = storage,
        };
    }

    pub fn addRelay(
        self: *LegacyDmSyncRuntimeClient,
        relay_url_text: []const u8,
    ) LegacyDmSyncRuntimeClientError!runtime.RelayDescriptor {
        const replay_relay = try self.replay_job.addRelay(relay_url_text);
        const subscription_relay = try self.subscription_job.addRelay(relay_url_text);
        std.debug.assert(std.mem.eql(u8, replay_relay.relay_url, subscription_relay.relay_url));
        return replay_relay;
    }

    pub fn markRelayConnected(
        self: *LegacyDmSyncRuntimeClient,
        relay_index: u8,
    ) LegacyDmSyncRuntimeClientError!void {
        try self.replay_job.markRelayConnected(relay_index);
        try self.subscription_job.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LegacyDmSyncRuntimeClient,
        relay_index: u8,
    ) LegacyDmSyncRuntimeClientError!void {
        try self.replay_job.noteRelayDisconnected(relay_index);
        try self.subscription_job.noteRelayDisconnected(relay_index);
        self.storage.live_subscription_active = false;
    }

    pub fn noteRelayAuthChallenge(
        self: *LegacyDmSyncRuntimeClient,
        relay_index: u8,
        challenge: []const u8,
    ) LegacyDmSyncRuntimeClientError!void {
        try self.replay_job.noteRelayAuthChallenge(relay_index, challenge);
        try self.subscription_job.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn replayPhaseComplete(self: *const LegacyDmSyncRuntimeClient) bool {
        return self.storage.replay_phase_complete;
    }

    pub fn liveSubscriptionActive(self: *const LegacyDmSyncRuntimeClient) bool {
        return self.storage.live_subscription_active;
    }

    pub fn inspectRelayRuntime(
        self: *const LegacyDmSyncRuntimeClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.replay_job.inspectRelayRuntime(storage);
    }

    pub fn inspectRuntime(
        self: *const LegacyDmSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *LegacyDmSyncRuntimePlanStorage,
    ) LegacyDmSyncRuntimeClientError!LegacyDmSyncRuntimePlan {
        const auth_plan = self.replay_job.replay_turn.inspectAuth(&storage.auth);
        const replay_plan = try self.replay_job.replay_turn.inspectReplay(
            checkpoint_store,
            replay_specs,
            &storage.replay,
        );
        const subscription_plan = try self.subscription_job.subscription_turn.inspectSubscriptions(
            subscription_specs,
            &storage.subscription,
        );

        var plan: LegacyDmSyncRuntimePlan = .{
            .authenticate_count = auth_plan.authenticate_count,
            .replay_count = if (self.storage.replay_phase_complete) 0 else replay_plan.replay_count,
            .subscribe_count = subscription_plan.subscribe_count,
            .receive_count = if (self.storage.live_subscription_active) 1 else 0,
            .replay_phase_complete = self.storage.replay_phase_complete,
        };

        if (auth_plan.nextStep()) |step| {
            plan.next_step = .{ .authenticate = step };
            return plan;
        }
        if (self.storage.live_subscription_active) {
            plan.next_step = .{ .receive = self.storage.live_subscription_request };
            return plan;
        }
        if (!self.storage.replay_phase_complete) {
            if (replay_plan.nextStep()) |step| {
                plan.next_step = .{ .replay = step };
                return plan;
            }
        }
        if (subscription_plan.nextStep()) |step| {
            plan.next_step = .{ .subscribe = step };
            return plan;
        }
        plan.next_step = .idle;
        return plan;
    }

    pub fn markReplayCatchupComplete(self: *LegacyDmSyncRuntimeClient) void {
        self.storage.replay_phase_complete = true;
    }

    pub fn resetReplayCatchup(self: *LegacyDmSyncRuntimeClient) void {
        self.storage.replay_phase_complete = false;
    }

    pub fn prepareAuthEvent(
        self: *LegacyDmSyncRuntimeClient,
        auth_storage: *LegacyDmSyncRuntimeAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) LegacyDmSyncRuntimeClientError!PreparedLegacyDmSyncRuntimeAuthEvent {
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

    pub fn acceptPreparedAuthEvent(
        self: *LegacyDmSyncRuntimeClient,
        prepared: *const PreparedLegacyDmSyncRuntimeAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) LegacyDmSyncRuntimeClientError!runtime.RelayDescriptor {
        const replay_descriptor = try self.replay_job.replay_turn.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        const subscription_descriptor = try self.subscription_job.subscription_turn.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        std.debug.assert(std.mem.eql(u8, replay_descriptor.relay_url, subscription_descriptor.relay_url));
        return replay_descriptor;
    }

    pub fn beginReplayTurn(
        self: *LegacyDmSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) LegacyDmSyncRuntimeClientError!LegacyDmSyncRuntimeReplayRequest {
        return self.replay_job.replay_turn.beginTurn(
            checkpoint_store,
            output,
            subscription_id,
            specs,
        );
    }

    pub fn acceptReplayMessageJson(
        self: *LegacyDmSyncRuntimeClient,
        request: *const LegacyDmSyncRuntimeReplayRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) LegacyDmSyncRuntimeClientError!LegacyDmSyncRuntimeReplayIntake {
        return self.replay_job.acceptReplayMessageJson(
            request,
            relay_message_json,
            plaintext_output,
            scratch,
        );
    }

    pub fn completeReplayTurn(
        self: *LegacyDmSyncRuntimeClient,
        output: []u8,
        request: *const LegacyDmSyncRuntimeReplayRequest,
    ) LegacyDmSyncRuntimeClientError!legacy_dm_replay_job.LegacyDmReplayJobResult {
        return self.replay_job.completeReplayJob(output, request);
    }

    pub fn saveReplayTurnResult(
        self: *LegacyDmSyncRuntimeClient,
        archive: store.RelayCheckpointArchive,
        result: *const legacy_dm_replay_turn.LegacyDmReplayTurnResult,
    ) LegacyDmSyncRuntimeClientError!void {
        return self.replay_job.saveJobResult(archive, result);
    }

    pub fn beginSubscriptionTurn(
        self: *LegacyDmSyncRuntimeClient,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) LegacyDmSyncRuntimeClientError!LegacyDmSyncRuntimeSubscriptionRequest {
        const request = try self.subscription_job.subscription_turn.beginTurn(output, specs);
        self.storage.live_subscription_request = request;
        self.storage.live_subscription_active = true;
        return request;
    }

    pub fn acceptSubscriptionMessageJson(
        self: *LegacyDmSyncRuntimeClient,
        request: *const LegacyDmSyncRuntimeSubscriptionRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) LegacyDmSyncRuntimeClientError!LegacyDmSyncRuntimeSubscriptionIntake {
        return self.subscription_job.acceptSubscriptionMessageJson(
            request,
            relay_message_json,
            plaintext_output,
            scratch,
        );
    }

    pub fn completeSubscriptionTurn(
        self: *LegacyDmSyncRuntimeClient,
        output: []u8,
        request: *const LegacyDmSyncRuntimeSubscriptionRequest,
    ) LegacyDmSyncRuntimeClientError!legacy_dm_subscription_job.LegacyDmSubscriptionJobResult {
        const result = try self.subscription_job.completeSubscriptionJob(output, request);
        if (sameSubscriptionRequest(&self.storage.live_subscription_request, request)) {
            self.storage.live_subscription_active = false;
        }
        return result;
    }

    fn selectAuthTarget(
        self: *const LegacyDmSyncRuntimeClient,
        step: *const runtime.RelayPoolAuthStep,
    ) LegacyDmSyncRuntimeClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.replay_job.replay_turn.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(
            &self.replay_job.replay_turn.replay_turn.replay_exchange.replay.relay_pool,
            plan,
            step,
        );
    }
};

fn normalizeConfig(config: LegacyDmSyncRuntimeClientConfig) LegacyDmSyncRuntimeClientConfig {
    var updated = config;
    updated.replay_turn = .{
        .owner_private_key = config.owner_private_key,
        .local_operator = config.local_operator,
        .replay_turn = .{
            .owner_private_key = config.owner_private_key,
            .replay_turn = config.replay_turn.replay_turn.replay_turn,
        },
    };
    updated.subscription_turn = .{
        .owner_private_key = config.owner_private_key,
        .local_operator = config.local_operator,
        .subscription_turn = .{
            .owner_private_key = config.owner_private_key,
            .subscription_turn = config.subscription_turn.subscription_turn.subscription_turn,
        },
    };
    return updated;
}

fn sameSubscriptionRequest(
    left: *const LegacyDmSyncRuntimeSubscriptionRequest,
    right: *const LegacyDmSyncRuntimeSubscriptionRequest,
) bool {
    return left.subscription.relay.relay_index == right.subscription.relay.relay_index and
        std.mem.eql(u8, left.subscription.relay.relay_url, right.subscription.relay.relay_url) and
        std.mem.eql(u8, left.subscription.subscription_id, right.subscription.subscription_id);
}
