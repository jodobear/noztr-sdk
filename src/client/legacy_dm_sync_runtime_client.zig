const std = @import("std");
const noztr = @import("noztr");
const dm_sync_runtime_support = @import("dm_sync_runtime_support.zig");
const legacy_dm_replay_job = @import("legacy_dm_replay_job_client.zig");
const legacy_dm_replay_turn = @import("legacy_dm_replay_turn_client.zig");
const legacy_dm_subscription_job = @import("legacy_dm_subscription_job_client.zig");
const local_operator = @import("local_operator_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const sync_runtime_support = @import("sync_runtime_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const workflows = @import("../workflows/mod.zig");

pub const ClientError =
    legacy_dm_replay_job.Error ||
    legacy_dm_subscription_job.Error ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleAuthStep,
        RelayNotReady,
        RuntimeNotEmpty,
    };

pub const Config = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: legacy_dm_replay_job.Config = undefined,
    subscription_turn: legacy_dm_subscription_job.Config = undefined,
};

pub const Storage = struct {
    replay_job: legacy_dm_replay_job.Storage = .{},
    subscription_job: legacy_dm_subscription_job.Storage = .{},
    replay_phase_complete: bool = false,
    live_subscription_active: bool = false,
    live_subscription_request: legacy_dm_subscription_job.Request = undefined,
};

pub const PlanStorage = dm_sync_runtime_support.PlanStorage;

pub const ResumeStorage = struct {
    relay_members: runtime.RelayPoolMemberStorage = .{},
};

pub const ResumeState = struct {
    relay_count: u8 = 0,
    replay_phase_complete: bool = false,
    _storage: *const ResumeStorage,

    pub fn relayUrl(self: *const ResumeState, index: u8) ?[]const u8 {
        if (index >= self.relay_count) return null;
        return self._storage.relay_members.records[index].relayUrl();
    }
};

pub const Step =
    dm_sync_runtime_support.Step(legacy_dm_subscription_job.Request);
pub const Plan =
    dm_sync_runtime_support.Plan(legacy_dm_subscription_job.Request);
pub const PolicyStorage = dm_sync_runtime_support.PolicyStorage;
pub const PolicyStep =
    dm_sync_runtime_support.PolicyStep(legacy_dm_subscription_job.Request);
pub const PolicyPlan =
    dm_sync_runtime_support.PolicyPlan(legacy_dm_subscription_job.Request);
pub const OrchestrationStorage = dm_sync_runtime_support.OrchestrationStorage;
pub const OrchestrationStep =
    dm_sync_runtime_support.OrchestrationStep(legacy_dm_subscription_job.Request);
pub const OrchestrationPlan =
    dm_sync_runtime_support.OrchestrationPlan(legacy_dm_subscription_job.Request);
pub const CadenceRequest = dm_sync_runtime_support.CadenceRequest;
pub const CadenceStorage = dm_sync_runtime_support.CadenceStorage;
pub const CadenceWaitReason = dm_sync_runtime_support.CadenceWaitReason;
pub const CadenceWait = dm_sync_runtime_support.CadenceWait;
pub const CadenceStep =
    dm_sync_runtime_support.CadenceStep(legacy_dm_subscription_job.Request);
pub const CadencePlan =
    dm_sync_runtime_support.CadencePlan(legacy_dm_subscription_job.Request);

pub const AuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const ReplayRequest = legacy_dm_replay_job.Request;
pub const ReplayIntake = legacy_dm_replay_job.Intake;
pub const SubscriptionRequest =
    legacy_dm_subscription_job.Request;
pub const SubscriptionIntake =
    legacy_dm_subscription_job.Intake;

pub const Client = struct {
    config: Config,
    local_operator: local_operator.LocalOperatorClient,
    replay_job: legacy_dm_replay_job.Client,
    subscription_job: legacy_dm_subscription_job.Client,
    storage: *Storage,

    pub fn init(
        config: Config,
        storage: *Storage,
    ) Client {
        storage.* = .{};
        const normalized = normalizeConfig(config);
        return .{
            .config = normalized,
            .local_operator = local_operator.LocalOperatorClient.init(normalized.local_operator),
            .replay_job = legacy_dm_replay_job.Client.init(
                normalized.replay_turn,
                &storage.replay_job,
            ),
            .subscription_job = legacy_dm_subscription_job.Client.init(
                normalized.subscription_turn,
                &storage.subscription_job,
            ),
            .storage = storage,
        };
    }

    pub fn attach(
        config: Config,
        storage: *Storage,
    ) Client {
        const normalized = normalizeConfig(config);
        return .{
            .config = normalized,
            .local_operator = local_operator.LocalOperatorClient.init(normalized.local_operator),
            .replay_job = legacy_dm_replay_job.Client.attach(
                normalized.replay_turn,
                &storage.replay_job,
            ),
            .subscription_job = legacy_dm_subscription_job.Client.attach(
                normalized.subscription_turn,
                &storage.subscription_job,
            ),
            .storage = storage,
        };
    }

    pub fn addRelay(
        self: *Client,
        relay_url_text: []const u8,
    ) ClientError!runtime.RelayDescriptor {
        return sync_runtime_support.addRelay(self, relay_url_text);
    }

    pub fn relayCount(self: *const Client) u8 {
        return self.replay_job.replay_turn.replay_turn.replay_exchange.replay.relay_pool.relayCount();
    }

    pub fn markRelayConnected(
        self: *Client,
        relay_index: u8,
    ) ClientError!void {
        return sync_runtime_support.markRelayConnected(self, relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *Client,
        relay_index: u8,
    ) ClientError!void {
        return sync_runtime_support.noteRelayDisconnected(self, relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *Client,
        relay_index: u8,
        challenge: []const u8,
    ) ClientError!void {
        return sync_runtime_support.noteRelayAuthChallenge(self, relay_index, challenge);
    }

    pub fn replayPhaseComplete(self: *const Client) bool {
        return self.storage.replay_phase_complete;
    }

    pub fn exportResumeState(
        self: *const Client,
        storage: *ResumeStorage,
    ) ClientError!ResumeState {
        const members = self.replay_job.replay_turn.replay_turn.replay_exchange.replay.relay_pool.exportMembers(
            &storage.relay_members,
        ) catch unreachable;
        return .{
            .relay_count = members.relay_count,
            .replay_phase_complete = self.storage.replay_phase_complete,
            ._storage = storage,
        };
    }

    pub fn restoreResumeState(
        self: *Client,
        state: *const ResumeState,
    ) ClientError!void {
        if (self.relayCount() != 0 or self.storage.replay_phase_complete or self.storage.live_subscription_active) {
            return error.RuntimeNotEmpty;
        }

        const members = runtime.RelayPoolMemberSet{
            .records = state._storage.relay_members.records[0..state.relay_count],
            .relay_count = state.relay_count,
        };
        try restoreReplayTurnMembers(
            &self.replay_job.replay_turn,
            &members,
        );
        try restoreSubscriptionTurnMembers(
            &self.subscription_job,
            &members,
        );
        self.storage.replay_phase_complete = state.replay_phase_complete;
        self.storage.live_subscription_active = false;
    }

    pub fn liveSubscriptionActive(self: *const Client) bool {
        return self.storage.live_subscription_active;
    }

    pub fn inspectRelayRuntime(
        self: *const Client,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return sync_runtime_support.inspectRelayRuntime(self, storage);
    }

    pub fn inspectRuntime(
        self: *const Client,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *PlanStorage,
    ) ClientError!Plan {
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

        return dm_sync_runtime_support.buildPlan(
            legacy_dm_subscription_job.Request,
            auth_plan,
            replay_plan,
            subscription_plan,
            self.storage.replay_phase_complete,
            self.storage.live_subscription_active,
            self.storage.live_subscription_request,
        );
    }

    pub fn inspectPolicy(
        self: *const Client,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *PolicyStorage,
    ) ClientError!PolicyPlan {
        const relay_runtime = self.inspectRelayRuntime(&storage.relay_runtime);
        const runtime_plan = try self.inspectRuntime(
            checkpoint_store,
            replay_specs,
            subscription_specs,
            &storage.runtime,
        );

        return dm_sync_runtime_support.classifyPolicy(
            legacy_dm_subscription_job.Request,
            self.relayCount(),
            relay_runtime,
            runtime_plan,
            self.storage.live_subscription_active,
        );
    }

    pub fn inspectOrchestration(
        self: *const Client,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *OrchestrationStorage,
    ) ClientError!OrchestrationPlan {
        const policy_plan = try self.inspectPolicy(
            checkpoint_store,
            replay_specs,
            subscription_specs,
            &storage.policy,
        );
        return dm_sync_runtime_support.buildOrchestration(
            legacy_dm_subscription_job.Request,
            policy_plan,
        );
    }

    pub fn inspectCadence(
        self: *const Client,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        request: CadenceRequest,
        storage: *CadenceStorage,
    ) ClientError!CadencePlan {
        const orchestration = try self.inspectOrchestration(
            checkpoint_store,
            replay_specs,
            subscription_specs,
            &storage.orchestration,
        );
        return dm_sync_runtime_support.buildCadence(
            legacy_dm_subscription_job.Request,
            orchestration,
            request,
        );
    }

    pub fn markReplayCatchupComplete(self: *Client) void {
        self.storage.replay_phase_complete = true;
    }

    pub fn resetReplayCatchup(self: *Client) void {
        self.storage.replay_phase_complete = false;
    }

    pub fn prepareAuthEvent(
        self: *Client,
        auth_storage: *AuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) ClientError!PreparedAuthEvent {
        return sync_runtime_support.prepareAuthEvent(
            self,
            auth_storage,
            event_json_output,
            auth_message_output,
            step,
            &self.config.owner_private_key,
            created_at,
        );
    }

    pub fn acceptPreparedAuthEvent(
        self: *Client,
        prepared: *const PreparedAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) ClientError!runtime.RelayDescriptor {
        return sync_runtime_support.acceptPreparedAuthEvent(
            self,
            prepared,
            now_unix_seconds,
            window_seconds,
        );
    }

    pub fn beginReplayTurn(
        self: *Client,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) ClientError!ReplayRequest {
        return self.replay_job.replay_turn.beginTurn(
            checkpoint_store,
            output,
            subscription_id,
            specs,
        );
    }

    pub fn acceptReplayMessageJson(
        self: *Client,
        request: *const ReplayRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) ClientError!ReplayIntake {
        return self.replay_job.acceptReplayMessageJson(
            request,
            relay_message_json,
            plaintext_output,
            scratch,
        );
    }

    pub fn completeReplayTurn(
        self: *Client,
        output: []u8,
        request: *const ReplayRequest,
    ) ClientError!legacy_dm_replay_job.Result {
        return self.replay_job.completeReplayJob(output, request);
    }

    pub fn saveReplayTurnResult(
        self: *Client,
        archive: store.RelayCheckpointArchive,
        result: *const legacy_dm_replay_turn.Result,
    ) ClientError!void {
        return self.replay_job.saveJobResult(archive, result);
    }

    pub fn beginSubscriptionTurn(
        self: *Client,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) ClientError!SubscriptionRequest {
        const request = try self.subscription_job.subscription_turn.beginTurn(output, specs);
        self.storage.live_subscription_request = request;
        self.storage.live_subscription_active = true;
        return request;
    }

    pub fn acceptSubscriptionMessageJson(
        self: *Client,
        request: *const SubscriptionRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) ClientError!SubscriptionIntake {
        return self.subscription_job.acceptSubscriptionMessageJson(
            request,
            relay_message_json,
            plaintext_output,
            scratch,
        );
    }

    pub fn completeSubscriptionTurn(
        self: *Client,
        output: []u8,
        request: *const SubscriptionRequest,
    ) ClientError!legacy_dm_subscription_job.Result {
        const result = try self.subscription_job.completeSubscriptionJob(output, request);
        if (sameSubscriptionRequest(&self.storage.live_subscription_request, request)) {
            self.storage.live_subscription_active = false;
        }
        return result;
    }
};

fn normalizeConfig(config: Config) Config {
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
    left: *const SubscriptionRequest,
    right: *const SubscriptionRequest,
) bool {
    return left.subscription.relay.relay_index == right.subscription.relay.relay_index and
        std.mem.eql(u8, left.subscription.relay.relay_url, right.subscription.relay.relay_url) and
        std.mem.eql(u8, left.subscription.subscription_id, right.subscription.subscription_id);
}

fn restoreReplayTurnMembers(
    replay_turn: *legacy_dm_replay_turn.Client,
    members: *const runtime.RelayPoolMemberSet,
) ClientError!void {
    replay_turn.replay_turn.replay_exchange.replay.relay_pool.restoreMembers(members) catch |err| {
        return switch (err) {
            error.PoolNotEmpty => error.RuntimeNotEmpty,
            else => unreachable,
        };
    };
}

fn restoreSubscriptionTurnMembers(
    subscription_turn: *legacy_dm_subscription_job.Client,
    members: *const runtime.RelayPoolMemberSet,
) ClientError!void {
    subscription_turn.subscription_turn.subscription_turn.relay_exchange.relay_pool.restoreMembers(
        members,
    ) catch |err| {
        return switch (err) {
            error.PoolNotEmpty => error.RuntimeNotEmpty,
            else => unreachable,
        };
    };
}

test "legacy dm sync runtime client exposes caller-owned config and storage" {
    var storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
    try std.testing.expect(!client.replayPhaseComplete());
    try std.testing.expect(!client.liveSubscriptionActive());
}

test "legacy dm sync runtime client exports durable resume state and restores reconnect posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const owner_secret = [_]u8{0x33} ** 32;
    var client_storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = owner_secret,
    }, &client_storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    client.markReplayCatchupComplete();

    var resume_storage = ResumeStorage{};
    const resume_state = try client.exportResumeState(&resume_storage);
    try std.testing.expectEqual(@as(u8, 1), resume_state.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", resume_state.relayUrl(0).?);
    try std.testing.expect(resume_state.replay_phase_complete);

    var restored_storage = Storage{};
    var restored = Client.init(.{
        .owner_private_key = owner_secret,
    }, &restored_storage);
    try restored.restoreResumeState(&resume_state);

    try std.testing.expectEqual(@as(u8, 1), restored.relayCount());
    try std.testing.expect(restored.replayPhaseComplete());
    try std.testing.expect(!restored.liveSubscriptionActive());

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var runtime_storage = PlanStorage{};
    const plan = try restored.inspectRuntime(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(plan.nextStep() == .idle);

    var relay_runtime_storage = runtime.RelayPoolPlanStorage{};
    const relay_runtime = restored.inspectRelayRuntime(&relay_runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), relay_runtime.relay_count);
    try std.testing.expect(relay_runtime.nextStep().?.entry.action == .connect);

    var policy_storage = PolicyStorage{};
    const policy = try restored.inspectPolicy(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expectEqual(@as(u8, 1), policy.reconnect_count);
    try std.testing.expect(policy.nextStep() == .reconnect);
    try std.testing.expect(policy.nextStep().reconnect.entry.action == .connect);
}

test "legacy dm sync runtime client rejects restoring resume state into a non-empty runtime" {
    const owner_secret = [_]u8{0x33} ** 32;

    var source_storage = Storage{};
    var source = Client.init(.{
        .owner_private_key = owner_secret,
    }, &source_storage);
    _ = try source.addRelay("wss://relay.one");

    var resume_storage = ResumeStorage{};
    const resume_state = try source.exportResumeState(&resume_storage);

    var target_storage = Storage{};
    var target = Client.init(.{
        .owner_private_key = owner_secret,
    }, &target_storage);
    _ = try target.addRelay("wss://relay.two");

    try std.testing.expectError(
        error.RuntimeNotEmpty,
        target.restoreResumeState(&resume_state),
    );
}

test "legacy dm sync runtime client plans authenticate replay subscribe and receive explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage_buf = Storage{};
    var client = Client.init(.{
        .owner_private_key = recipient_secret,
    }, &storage_buf);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("legacy-dm", relay.relay_url, .{ .offset = 7 });

    const sender = workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    var replay_outbound = workflows.dm.legacy.LegacyDmOutboundStorage{};
    const replay_prepared = try sender.buildDirectMessageEvent(&replay_outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy dm sync runtime replay payload",
        .created_at = 41,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });

    var live_outbound = workflows.dm.legacy.LegacyDmOutboundStorage{};
    const live_prepared = try sender.buildDirectMessageEvent(&live_outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy dm sync runtime live payload",
        .created_at = 42,
        .iv = [_]u8{0x66} ** noztr.limits.nip04_iv_bytes,
    });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "legacy-dm",
            .query = .{ .limit = 16 },
        },
    };
    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var runtime_storage = PlanStorage{};
    var policy_storage = PolicyStorage{};
    const auth_plan = try client.inspectRuntime(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(auth_plan.nextStep() == .authenticate);
    const auth_policy = try client.inspectPolicy(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expect(auth_policy.nextStep() == .authenticate);

    var auth_storage = AuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &auth_plan.nextStep().authenticate,
        90,
    );
    _ = try client.acceptPreparedAuthEvent(&prepared_auth, 95, 60);

    const replay_plan = try client.inspectRuntime(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(replay_plan.nextStep() == .replay);
    const replay_policy = try client.inspectPolicy(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expect(replay_policy.nextStep() == .replay_resume);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_request = try client.beginReplayTurn(
        checkpoint_store,
        request_output[0..],
        "legacy-replay",
        replay_specs[0..],
    );

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-replay", .event = replay_prepared.event } },
    );
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const replay_intake = try client.acceptReplayMessageJson(
        &replay_request,
        replay_event_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    try std.testing.expect(replay_intake.message != null);
    try std.testing.expectEqualStrings(
        "legacy dm sync runtime replay payload",
        replay_intake.message.?.plaintext,
    );

    const replay_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "legacy-replay" } },
    );
    _ = try client.acceptReplayMessageJson(
        &replay_request,
        replay_eose_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    const replay_result = try client.completeReplayTurn(request_output[0..], &replay_request);
    try std.testing.expect(replay_result == .replayed);
    try client.saveReplayTurnResult(checkpoint_archive, &replay_result.replayed);
    client.markReplayCatchupComplete();

    const subscribe_plan = try client.inspectRuntime(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(subscribe_plan.nextStep() == .subscribe);
    const subscribe_policy = try client.inspectPolicy(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expect(subscribe_policy.nextStep() == .subscribe_resume);

    const live_request = try client.beginSubscriptionTurn(
        request_output[0..],
        subscription_specs[0..],
    );
    const receive_plan = try client.inspectRuntime(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(receive_plan.nextStep() == .receive);
    try std.testing.expect(sameSubscriptionRequest(
        &receive_plan.nextStep().receive,
        &live_request,
    ));
    const receive_policy = try client.inspectPolicy(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expect(receive_policy.nextStep() == .receive);
    try std.testing.expect(sameSubscriptionRequest(
        &receive_policy.nextStep().receive,
        &live_request,
    ));

    const live_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-feed", .event = live_prepared.event } },
    );
    const live_intake = try client.acceptSubscriptionMessageJson(
        &live_request,
        live_event_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    try std.testing.expect(live_intake.message != null);
    try std.testing.expectEqualStrings(
        "legacy dm sync runtime live payload",
        live_intake.message.?.plaintext,
    );

    const live_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "legacy-feed" } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &live_request,
        live_eose_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    const live_result = try client.completeSubscriptionTurn(request_output[0..], &live_request);
    try std.testing.expect(live_result == .subscribed);
    try std.testing.expect(!client.liveSubscriptionActive());
}

test "legacy dm sync runtime client returns idle when catchup is complete and no live specs remain" {
    var client_storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = [_]u8{0x33} ** 32,
    }, &client_storage);
    client.markReplayCatchupComplete();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    var runtime_storage = PlanStorage{};
    const plan = try client.inspectRuntime(
        checkpoint_store,
        &.{},
        &.{},
        &runtime_storage,
    );
    try std.testing.expect(plan.nextStep() == .idle);
}

test "legacy dm sync runtime client exposes broader dm orchestration phases" {
    var client_storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = [_]u8{0x33} ** 32,
    }, &client_storage);

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    var orchestration_storage = OrchestrationStorage{};

    const empty = try client.inspectOrchestration(
        checkpoint_store,
        &.{},
        &.{},
        &orchestration_storage,
    );
    try std.testing.expect(empty.needs_relay_configuration);
    try std.testing.expect(empty.nextStep() == .configure_relays);
}

test "legacy dm sync runtime client cadence can reopen replay catchup before live resubscribe" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const owner_secret = [_]u8{0x33} ** 32;
    var client_storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = owner_secret,
    }, &client_storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    client.markReplayCatchupComplete();

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "legacy-dm",
            .query = .{ .limit = 8 },
        },
    };
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var cadence_storage = CadenceStorage{};
    const cadence = try client.inspectCadence(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        .{
            .now_unix_seconds = 90,
            .replay_refresh_not_before_unix_seconds = 80,
        },
        &cadence_storage,
    );
    try std.testing.expect(cadence.replay_refresh_due);
    try std.testing.expect(cadence.nextStep() == .reopen_replay_catchup);

    client.resetReplayCatchup();
    var orchestration_storage = OrchestrationStorage{};
    const orchestration = try client.inspectOrchestration(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(orchestration.nextStep() == .replay_resume);
}

test "legacy dm sync runtime client long-lived policy falls back to reconnect after disconnect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const owner_secret = [_]u8{0x33} ** 32;
    var storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = owner_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    client.markReplayCatchupComplete();

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const live_request = try client.beginSubscriptionTurn(
        request_output[0..],
        subscription_specs[0..],
    );

    var policy_storage = PolicyStorage{};
    const receive_policy = try client.inspectPolicy(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expect(receive_policy.nextStep() == .receive);
    try std.testing.expect(sameSubscriptionRequest(
        &receive_policy.nextStep().receive,
        &live_request,
    ));

    try client.noteRelayDisconnected(0);
    const reconnect_policy = try client.inspectPolicy(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expectEqual(@as(u8, 1), reconnect_policy.reconnect_count);
    try std.testing.expect(!reconnect_policy.live_subscription_active);
    try std.testing.expect(reconnect_policy.nextStep() == .reconnect);
    try std.testing.expectEqualStrings(
        "wss://relay.one",
        reconnect_policy.nextStep().reconnect.entry.descriptor.relay_url,
    );
}
