const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const dm_sync_runtime_support = @import("dm_sync_runtime_support.zig");
const mailbox_replay_job = @import("mailbox_replay_job_client.zig");
const mailbox_replay_turn = @import("mailbox_replay_turn_client.zig");
const mailbox_subscription_job = @import("mailbox_subscription_job_client.zig");
const mailbox_subscription_turn = @import("mailbox_subscription_turn_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const sync_runtime_support = @import("sync_runtime_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const MailboxSyncRuntimeClientError =
    mailbox_replay_job.MailboxReplayJobClientError ||
    mailbox_subscription_job.MailboxSubscriptionJobClientError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleAuthStep,
        RelayNotReady,
        RuntimeNotEmpty,
    };

pub const MailboxSyncRuntimeClientConfig = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: mailbox_replay_job.MailboxReplayJobClientConfig = undefined,
    subscription_turn: mailbox_subscription_job.MailboxSubscriptionJobClientConfig = undefined,
};

pub const MailboxSyncRuntimeClientStorage = struct {
    replay_job: mailbox_replay_job.MailboxReplayJobClientStorage = .{},
    subscription_job: mailbox_subscription_job.MailboxSubscriptionJobClientStorage = .{},
    replay_phase_complete: bool = false,
    live_subscription_active: bool = false,
    live_subscription_request: mailbox_subscription_job.MailboxSubscriptionJobRequest = undefined,
};

pub const MailboxSyncRuntimePlanStorage = dm_sync_runtime_support.SyncRuntimePlanStorage;

pub const MailboxSyncRuntimeResumeStorage = struct {
    relay_members: runtime.RelayPoolMemberStorage = .{},
};

pub const MailboxSyncRuntimeResumeState = struct {
    relay_count: u8 = 0,
    current_relay_index: u8 = 0,
    replay_phase_complete: bool = false,
    _storage: *const MailboxSyncRuntimeResumeStorage,

    pub fn relayUrl(self: *const MailboxSyncRuntimeResumeState, index: u8) ?[]const u8 {
        if (index >= self.relay_count) return null;
        return self._storage.relay_members.records[index].relayUrl();
    }
};

pub const MailboxSyncRuntimeStep =
    dm_sync_runtime_support.SyncRuntimeStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxSyncRuntimePlan =
    dm_sync_runtime_support.SyncRuntimePlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxLongLivedDmPolicyStorage = dm_sync_runtime_support.LongLivedDmPolicyStorage;
pub const MailboxLongLivedDmPolicyStep =
    dm_sync_runtime_support.LongLivedDmPolicyStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxLongLivedDmPolicyPlan =
    dm_sync_runtime_support.LongLivedDmPolicyPlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxDmOrchestrationStorage = dm_sync_runtime_support.DmOrchestrationStorage;
pub const MailboxDmOrchestrationStep =
    dm_sync_runtime_support.DmOrchestrationStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxDmOrchestrationPlan =
    dm_sync_runtime_support.DmOrchestrationPlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxDmRuntimeCadenceRequest = dm_sync_runtime_support.DmRuntimeCadenceRequest;
pub const MailboxDmRuntimeCadenceStorage = dm_sync_runtime_support.DmRuntimeCadenceStorage;
pub const MailboxDmRuntimeCadenceWaitReason = dm_sync_runtime_support.DmRuntimeCadenceWaitReason;
pub const MailboxDmRuntimeCadenceWait = dm_sync_runtime_support.DmRuntimeCadenceWait;
pub const MailboxDmRuntimeCadenceStep =
    dm_sync_runtime_support.DmRuntimeCadenceStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const MailboxDmRuntimeCadencePlan =
    dm_sync_runtime_support.DmRuntimeCadencePlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);

pub const MailboxSyncRuntimeAuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedMailboxSyncRuntimeAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const MailboxSyncRuntimeReplayRequest = mailbox_replay_job.MailboxReplayJobRequest;
pub const MailboxSyncRuntimeReplayIntake = mailbox_replay_job.MailboxReplayJobIntake;
pub const MailboxSyncRuntimeSubscriptionRequest = mailbox_subscription_job.MailboxSubscriptionJobRequest;
pub const MailboxSyncRuntimeSubscriptionIntake = mailbox_subscription_job.MailboxSubscriptionJobIntake;

pub const MailboxSyncRuntimeClient = struct {
    config: MailboxSyncRuntimeClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    replay_job: mailbox_replay_job.MailboxReplayJobClient,
    subscription_job: mailbox_subscription_job.MailboxSubscriptionJobClient,
    storage: *MailboxSyncRuntimeClientStorage,

    pub fn init(
        config: MailboxSyncRuntimeClientConfig,
        storage: *MailboxSyncRuntimeClientStorage,
    ) MailboxSyncRuntimeClient {
        storage.* = .{};
        const normalized = normalizeConfig(config);
        return .{
            .config = normalized,
            .local_operator = local_operator.LocalOperatorClient.init(normalized.local_operator),
            .replay_job = mailbox_replay_job.MailboxReplayJobClient.init(
                normalized.replay_turn,
                &storage.replay_job,
            ),
            .subscription_job = mailbox_subscription_job.MailboxSubscriptionJobClient.init(
                normalized.subscription_turn,
                &storage.subscription_job,
            ),
            .storage = storage,
        };
    }

    pub fn attach(
        config: MailboxSyncRuntimeClientConfig,
        storage: *MailboxSyncRuntimeClientStorage,
    ) MailboxSyncRuntimeClient {
        const normalized = normalizeConfig(config);
        return .{
            .config = normalized,
            .local_operator = local_operator.LocalOperatorClient.init(normalized.local_operator),
            .replay_job = mailbox_replay_job.MailboxReplayJobClient.attach(
                normalized.replay_turn,
                &storage.replay_job,
            ),
            .subscription_job = mailbox_subscription_job.MailboxSubscriptionJobClient.attach(
                normalized.subscription_turn,
                &storage.subscription_job,
            ),
            .storage = storage,
        };
    }

    pub fn relayCount(self: *const MailboxSyncRuntimeClient) u8 {
        return self.replay_job.relayCount();
    }

    pub fn currentRelayUrl(self: *const MailboxSyncRuntimeClient) ?[]const u8 {
        return self.replay_job.currentRelayUrl();
    }

    pub fn currentRelayAuthChallenge(self: *const MailboxSyncRuntimeClient) ?[]const u8 {
        return self.replay_job.currentRelayAuthChallenge();
    }

    pub fn replayPhaseComplete(self: *const MailboxSyncRuntimeClient) bool {
        return self.storage.replay_phase_complete;
    }

    pub fn exportResumeState(
        self: *const MailboxSyncRuntimeClient,
        storage: *MailboxSyncRuntimeResumeStorage,
    ) MailboxSyncRuntimeResumeState {
        const members = self.replay_job.replay_turn.storage.mailbox.exportRelayPoolMembers(
            &storage.relay_members,
        );
        return .{
            .relay_count = members.relay_count,
            .current_relay_index = self.replay_job.replay_turn.storage.mailbox.currentRelayIndex() orelse 0,
            .replay_phase_complete = self.storage.replay_phase_complete,
            ._storage = storage,
        };
    }

    pub fn restoreResumeState(
        self: *MailboxSyncRuntimeClient,
        state: *const MailboxSyncRuntimeResumeState,
    ) MailboxSyncRuntimeClientError!void {
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
            state.current_relay_index,
        );
        try restoreSubscriptionTurnMembers(
            &self.subscription_job.subscription_turn,
            &members,
            state.current_relay_index,
        );
        self.storage.replay_phase_complete = state.replay_phase_complete;
        self.storage.live_subscription_active = false;
    }

    pub fn liveSubscriptionActive(self: *const MailboxSyncRuntimeClient) bool {
        return self.storage.live_subscription_active;
    }

    pub fn hydrateRelayListEventJson(
        self: *MailboxSyncRuntimeClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxSyncRuntimeClientError!u8 {
        const replay_count = try self.replay_job.hydrateRelayListEventJson(event_json, scratch);
        const subscription_count = try self.subscription_job.hydrateRelayListEventJson(
            event_json,
            scratch,
        );
        std.debug.assert(replay_count == subscription_count);
        self.storage.replay_phase_complete = false;
        self.storage.live_subscription_active = false;
        return replay_count;
    }

    pub fn selectRelay(
        self: *MailboxSyncRuntimeClient,
        relay_index: u8,
    ) MailboxSyncRuntimeClientError![]const u8 {
        const replay_url = try self.replay_job.selectRelay(relay_index);
        const subscription_url = try self.subscription_job.selectRelay(relay_index);
        std.debug.assert(std.mem.eql(u8, replay_url, subscription_url));
        return replay_url;
    }

    pub fn markRelayConnected(
        self: *MailboxSyncRuntimeClient,
        relay_index: u8,
    ) MailboxSyncRuntimeClientError!void {
        return sync_runtime_support.markRelayConnected(self, relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *MailboxSyncRuntimeClient,
        relay_index: u8,
    ) MailboxSyncRuntimeClientError!void {
        return sync_runtime_support.noteRelayDisconnected(self, relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *MailboxSyncRuntimeClient,
        relay_index: u8,
        challenge: []const u8,
    ) MailboxSyncRuntimeClientError!void {
        return sync_runtime_support.noteRelayAuthChallenge(self, relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const MailboxSyncRuntimeClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return sync_runtime_support.inspectRelayRuntime(self, storage);
    }

    pub fn inspectRuntime(
        self: *const MailboxSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *MailboxSyncRuntimePlanStorage,
    ) MailboxSyncRuntimeClientError!MailboxSyncRuntimePlan {
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

        return dm_sync_runtime_support.buildSyncRuntimePlan(
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
            auth_plan,
            replay_plan,
            subscription_plan,
            self.storage.replay_phase_complete,
            self.storage.live_subscription_active,
            self.storage.live_subscription_request,
        );
    }

    pub fn inspectLongLivedDmPolicy(
        self: *const MailboxSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *MailboxLongLivedDmPolicyStorage,
    ) MailboxSyncRuntimeClientError!MailboxLongLivedDmPolicyPlan {
        const relay_runtime = self.inspectRelayRuntime(&storage.relay_runtime);
        const runtime_plan = try self.inspectRuntime(
            checkpoint_store,
            replay_specs,
            subscription_specs,
            &storage.runtime,
        );

        return dm_sync_runtime_support.classifyLongLivedDmPolicy(
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
            self.relayCount(),
            relay_runtime,
            runtime_plan,
            self.storage.live_subscription_active,
        );
    }

    pub fn inspectDmOrchestration(
        self: *const MailboxSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        storage: *MailboxDmOrchestrationStorage,
    ) MailboxSyncRuntimeClientError!MailboxDmOrchestrationPlan {
        const policy_plan = try self.inspectLongLivedDmPolicy(
            checkpoint_store,
            replay_specs,
            subscription_specs,
            &storage.policy,
        );
        return dm_sync_runtime_support.buildDmOrchestration(
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
            policy_plan,
        );
    }

    pub fn inspectDmRuntimeCadence(
        self: *const MailboxSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        replay_specs: []const runtime.RelayReplaySpec,
        subscription_specs: []const runtime.RelaySubscriptionSpec,
        request: MailboxDmRuntimeCadenceRequest,
        storage: *MailboxDmRuntimeCadenceStorage,
    ) MailboxSyncRuntimeClientError!MailboxDmRuntimeCadencePlan {
        const orchestration = try self.inspectDmOrchestration(
            checkpoint_store,
            replay_specs,
            subscription_specs,
            &storage.orchestration,
        );
        return dm_sync_runtime_support.buildDmRuntimeCadence(
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
            orchestration,
            request,
        );
    }

    pub fn markReplayCatchupComplete(self: *MailboxSyncRuntimeClient) void {
        self.storage.replay_phase_complete = true;
    }

    pub fn resetReplayCatchup(self: *MailboxSyncRuntimeClient) void {
        self.storage.replay_phase_complete = false;
    }

    pub fn prepareAuthEvent(
        self: *MailboxSyncRuntimeClient,
        auth_storage: *MailboxSyncRuntimeAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) MailboxSyncRuntimeClientError!PreparedMailboxSyncRuntimeAuthEvent {
        return sync_runtime_support.prepareAuthEvent(
            self,
            auth_storage,
            event_json_output,
            auth_message_output,
            step,
            &self.config.recipient_private_key,
            created_at,
        );
    }

    pub fn acceptPreparedAuthEvent(
        self: *MailboxSyncRuntimeClient,
        prepared: *const PreparedMailboxSyncRuntimeAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) MailboxSyncRuntimeClientError!runtime.RelayDescriptor {
        return sync_runtime_support.acceptPreparedAuthEvent(
            self,
            prepared,
            now_unix_seconds,
            window_seconds,
        );
    }

    pub fn beginReplayTurn(
        self: *MailboxSyncRuntimeClient,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) MailboxSyncRuntimeClientError!MailboxSyncRuntimeReplayRequest {
        return self.replay_job.replay_turn.beginTurn(
            checkpoint_store,
            output,
            subscription_id,
            specs,
        );
    }

    pub fn acceptReplayMessageJson(
        self: *MailboxSyncRuntimeClient,
        request: *const MailboxSyncRuntimeReplayRequest,
        relay_message_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxSyncRuntimeClientError!MailboxSyncRuntimeReplayIntake {
        return self.replay_job.acceptReplayMessageJson(
            request,
            relay_message_json,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
    }

    pub fn completeReplayTurn(
        self: *MailboxSyncRuntimeClient,
        output: []u8,
        request: *const MailboxSyncRuntimeReplayRequest,
    ) MailboxSyncRuntimeClientError!mailbox_replay_job.MailboxReplayJobResult {
        return self.replay_job.completeReplayJob(output, request);
    }

    pub fn saveReplayTurnResult(
        self: *MailboxSyncRuntimeClient,
        archive: store.RelayCheckpointArchive,
        result: *const mailbox_replay_turn.MailboxReplayTurnResult,
    ) MailboxSyncRuntimeClientError!void {
        return self.replay_job.saveJobResult(archive, result);
    }

    pub fn beginSubscriptionTurn(
        self: *MailboxSyncRuntimeClient,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) MailboxSyncRuntimeClientError!MailboxSyncRuntimeSubscriptionRequest {
        const request = try self.subscription_job.subscription_turn.beginTurn(output, specs);
        self.storage.live_subscription_request = request;
        self.storage.live_subscription_active = true;
        return request;
    }

    pub fn acceptSubscriptionMessageJson(
        self: *MailboxSyncRuntimeClient,
        request: *const MailboxSyncRuntimeSubscriptionRequest,
        relay_message_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxSyncRuntimeClientError!MailboxSyncRuntimeSubscriptionIntake {
        return self.subscription_job.acceptSubscriptionMessageJson(
            request,
            relay_message_json,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
    }

    pub fn completeSubscriptionTurn(
        self: *MailboxSyncRuntimeClient,
        output: []u8,
        request: *const MailboxSyncRuntimeSubscriptionRequest,
    ) MailboxSyncRuntimeClientError!mailbox_subscription_job.MailboxSubscriptionJobResult {
        const result = try self.subscription_job.completeSubscriptionJob(output, request);
        if (sameSubscriptionRequest(&self.storage.live_subscription_request, request)) {
            self.storage.live_subscription_active = false;
        }
        return result;
    }
};

fn normalizeConfig(config: MailboxSyncRuntimeClientConfig) MailboxSyncRuntimeClientConfig {
    var updated = config;
    updated.replay_turn = .{
        .recipient_private_key = config.recipient_private_key,
        .local_operator = config.local_operator,
        .replay_turn = .{
            .recipient_private_key = config.recipient_private_key,
            .replay_turn = config.replay_turn.replay_turn.replay_turn,
        },
    };
    updated.subscription_turn = .{
        .recipient_private_key = config.recipient_private_key,
        .local_operator = config.local_operator,
        .subscription_turn = .{
            .recipient_private_key = config.recipient_private_key,
            .subscription_turn = config.subscription_turn.subscription_turn.subscription_turn,
        },
    };
    return updated;
}

fn sameSubscriptionRequest(
    left: *const MailboxSyncRuntimeSubscriptionRequest,
    right: *const MailboxSyncRuntimeSubscriptionRequest,
) bool {
    return left.subscription.relay.relay_index == right.subscription.relay.relay_index and
        std.mem.eql(u8, left.subscription.relay.relay_url, right.subscription.relay.relay_url) and
        std.mem.eql(u8, left.subscription.subscription_id, right.subscription.subscription_id);
}

fn restoreReplayTurnMembers(
    replay_turn: *mailbox_replay_turn.MailboxReplayTurnClient,
    members: *const runtime.RelayPoolMemberSet,
    current_relay_index: u8,
) MailboxSyncRuntimeClientError!void {
    try replay_turn.storage.mailbox.restoreRelayPoolMembers(members, current_relay_index);
    replay_turn.replay_turn = runtimeRelayReplayTurnClient(replay_turn);

    var index: u8 = 0;
    while (index < members.relay_count) : (index += 1) {
        const record = members.entry(index) orelse unreachable;
        _ = try replay_turn.replay_turn.addRelay(record.relayUrl());
    }
}

fn restoreSubscriptionTurnMembers(
    subscription_turn: *mailbox_subscription_turn.MailboxSubscriptionTurnClient,
    members: *const runtime.RelayPoolMemberSet,
    current_relay_index: u8,
) MailboxSyncRuntimeClientError!void {
    try subscription_turn.storage.mailbox.restoreRelayPoolMembers(members, current_relay_index);
    subscription_turn.subscription_turn = runtimeSubscriptionTurnClient(subscription_turn);

    var index: u8 = 0;
    while (index < members.relay_count) : (index += 1) {
        const record = members.entry(index) orelse unreachable;
        _ = try subscription_turn.subscription_turn.addRelay(record.relayUrl());
    }
}

fn runtimeRelayReplayTurnClient(
    replay_turn: *mailbox_replay_turn.MailboxReplayTurnClient,
) @TypeOf(replay_turn.replay_turn) {
    return @TypeOf(replay_turn.replay_turn).init(
        replay_turn.config.replay_turn,
        &replay_turn.storage.replay_turn,
    );
}

fn runtimeSubscriptionTurnClient(
    subscription_turn: *mailbox_subscription_turn.MailboxSubscriptionTurnClient,
) @TypeOf(subscription_turn.subscription_turn) {
    return @TypeOf(subscription_turn.subscription_turn).init(
        subscription_turn.config.subscription_turn,
        &subscription_turn.storage.subscription_turn,
    );
}

test "mailbox sync runtime client exposes caller-owned config and storage" {
    var storage = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
    try std.testing.expect(!client.replayPhaseComplete());
    try std.testing.expect(!client.liveSubscriptionActive());
}

test "mailbox sync runtime client exports durable resume state and restores subscribe posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const recipient_secret = [_]u8{0x33} ** 32;
    var client_storage = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &client_storage);

    var relay_list_storage: [1024]u8 = undefined;
    const relay_list_json = try buildRelayListEventJson(
        relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    client.markReplayCatchupComplete();

    var resume_storage = MailboxSyncRuntimeResumeStorage{};
    const resume_state = client.exportResumeState(&resume_storage);
    try std.testing.expectEqual(@as(u8, 1), resume_state.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", resume_state.relayUrl(0).?);
    try std.testing.expect(resume_state.replay_phase_complete);

    var restored_storage = MailboxSyncRuntimeClientStorage{};
    var restored = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &restored_storage);
    try restored.restoreResumeState(&resume_state);

    try std.testing.expectEqual(@as(u8, 1), restored.relayCount());
    try std.testing.expect(restored.replayPhaseComplete());
    try std.testing.expect(!restored.liveSubscriptionActive());
    try std.testing.expectEqualStrings("wss://relay.one", restored.currentRelayUrl().?);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var runtime_storage = MailboxSyncRuntimePlanStorage{};
    const plan = try restored.inspectRuntime(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(plan.nextStep() == .idle);

    var policy_storage = MailboxLongLivedDmPolicyStorage{};
    const policy = try restored.inspectLongLivedDmPolicy(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expectEqual(@as(u8, 1), policy.reconnect_count);
    try std.testing.expect(policy.nextStep() == .reconnect);
    try std.testing.expect(policy.nextStep().reconnect.entry.action == .connect);
}

test "mailbox sync runtime client plans authenticate replay subscribe and receive explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage_buf = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &storage_buf);

    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    try client.noteRelayAuthChallenge(0, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 7 });

    var sender_session = @import("../workflows/mod.zig").dm.mailbox.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var replay_outbound_buffer = @import("../workflows/mod.zig").dm.mailbox.MailboxOutboundBuffer{};
    const replay_outbound = try sender_session.beginDirectMessage(
        &replay_outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "mailbox sync runtime replay payload",
            .created_at = 41,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var live_outbound_buffer = @import("../workflows/mod.zig").dm.mailbox.MailboxOutboundBuffer{};
    const live_outbound = try sender_session.beginDirectMessage(
        &live_outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "mailbox sync runtime live payload",
            .created_at = 42,
            .wrap_signer_private_key = [_]u8{0x23} ** 32,
            .seal_nonce = [_]u8{0x46} ** 32,
            .wrap_nonce = [_]u8{0x57} ** 32,
        },
        arena.allocator(),
    );

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };
    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var runtime_storage = MailboxSyncRuntimePlanStorage{};
    var policy_storage = MailboxLongLivedDmPolicyStorage{};
    const auth_plan = try client.inspectRuntime(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(auth_plan.nextStep() == .authenticate);
    const auth_policy = try client.inspectLongLivedDmPolicy(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &policy_storage,
    );
    try std.testing.expect(auth_policy.nextStep() == .authenticate);

    var auth_storage = MailboxSyncRuntimeAuthEventStorage{};
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
    const replay_policy = try client.inspectLongLivedDmPolicy(
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
        "mailbox-replay",
        replay_specs[0..],
    );
    const replay_wrap_event = try noztr.nip01_event.event_parse_json(
        replay_outbound.wrap_event_json,
        arena.allocator(),
    );
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-replay", .event = replay_wrap_event } },
    );
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    _ = try client.acceptReplayMessageJson(
        &replay_request,
        replay_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    const replay_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-replay" } },
    );
    _ = try client.acceptReplayMessageJson(
        &replay_request,
        replay_eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
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
    const subscribe_policy = try client.inspectLongLivedDmPolicy(
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
    const receive_policy = try client.inspectLongLivedDmPolicy(
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

    const live_wrap_event = try noztr.nip01_event.event_parse_json(
        live_outbound.wrap_event_json,
        arena.allocator(),
    );
    const live_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-feed", .event = live_wrap_event } },
    );
    const live_intake = try client.acceptSubscriptionMessageJson(
        &live_request,
        live_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(live_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox sync runtime live payload",
        live_intake.envelope.?.direct_message.message.content,
    );

    const live_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &live_request,
        live_eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    const live_result = try client.completeSubscriptionTurn(request_output[0..], &live_request);
    try std.testing.expect(live_result == .subscribed);
}

test "mailbox sync runtime client long-lived policy falls back to reconnect after disconnect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const recipient_secret = [_]u8{0x33} ** 32;
    var storage = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &storage);

    var relay_list_storage: [1024]u8 = undefined;
    const relay_list_json = try buildRelayListEventJson(
        relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    client.markReplayCatchupComplete();

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const live_request = try client.beginSubscriptionTurn(
        request_output[0..],
        subscription_specs[0..],
    );

    var policy_storage = MailboxLongLivedDmPolicyStorage{};
    const receive_policy = try client.inspectLongLivedDmPolicy(
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
    const reconnect_policy = try client.inspectLongLivedDmPolicy(
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

test "mailbox sync runtime client returns idle when catchup is complete and no live specs remain" {
    var client_storage = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &client_storage);
    client.markReplayCatchupComplete();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    var runtime_storage = MailboxSyncRuntimePlanStorage{};
    const plan = try client.inspectRuntime(
        checkpoint_store,
        &.{},
        &.{},
        &runtime_storage,
    );
    try std.testing.expect(plan.nextStep() == .idle);
}

test "mailbox sync runtime client exposes broader dm orchestration phases" {
    var client_storage = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &client_storage);

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    var orchestration_storage = MailboxDmOrchestrationStorage{};

    const empty = try client.inspectDmOrchestration(
        checkpoint_store,
        &.{},
        &.{},
        &orchestration_storage,
    );
    try std.testing.expect(empty.needs_relay_configuration);
    try std.testing.expect(empty.nextStep() == .configure_relays);
}

test "mailbox sync runtime client cadence can defer reconnect until caller backoff expires" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const recipient_secret = [_]u8{0x33} ** 32;
    var client_storage = MailboxSyncRuntimeClientStorage{};
    var client = MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &client_storage);

    var relay_list_json_storage: [1024]u8 = undefined;
    const relay_list_json = try buildRelayListEventJson(
        relay_list_json_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    client.markReplayCatchupComplete();
    try client.noteRelayDisconnected(0);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var cadence_storage = MailboxDmRuntimeCadenceStorage{};
    const waiting = try client.inspectDmRuntimeCadence(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        .{
            .now_unix_seconds = 100,
            .reconnect_not_before_unix_seconds = 120,
        },
        &cadence_storage,
    );
    try std.testing.expect(waiting.blocked_by_reconnect_backoff);
    try std.testing.expect(waiting.nextStep() == .wait);
    try std.testing.expectEqual(
        MailboxDmRuntimeCadenceWaitReason.reconnect_backoff,
        waiting.nextStep().wait.reason,
    );

    const due = try client.inspectDmRuntimeCadence(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        .{
            .now_unix_seconds = 120,
            .reconnect_not_before_unix_seconds = 120,
        },
        &cadence_storage,
    );
    try std.testing.expect(due.nextStep() == .reconnect);
}

fn buildRelayListEventJson(
    output: []u8,
    relay_text: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_text } },
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = relay_list_author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .tags = tags[0..],
        .content = "",
    };
    try noztr.nostr_keys.nostr_sign_event(signer_secret_key, &event);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":10050," ++
            "\"tags\":[[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_text,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
