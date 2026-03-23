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

pub const ClientError =
    mailbox_replay_job.MailboxReplayJobClientError ||
    mailbox_subscription_job.MailboxSubscriptionJobClientError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleAuthStep,
        RelayNotReady,
        RuntimeNotEmpty,
    };

pub const Config = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: mailbox_replay_job.MailboxReplayJobClientConfig = undefined,
    subscription_turn: mailbox_subscription_job.MailboxSubscriptionJobClientConfig = undefined,
};

pub const Storage = struct {
    replay_job: mailbox_replay_job.MailboxReplayJobClientStorage = .{},
    subscription_job: mailbox_subscription_job.MailboxSubscriptionJobClientStorage = .{},
    replay_phase_complete: bool = false,
    live_subscription_active: bool = false,
    live_subscription_request: mailbox_subscription_job.MailboxSubscriptionJobRequest = undefined,
};

pub const PlanStorage = dm_sync_runtime_support.PlanStorage;

pub const ResumeStorage = struct {
    relay_members: runtime.RelayPoolMemberStorage = .{},
};

pub const ResumeState = struct {
    relay_count: u8 = 0,
    current_relay_index: u8 = 0,
    replay_phase_complete: bool = false,
    _storage: *const ResumeStorage,

    pub fn relayUrl(self: *const ResumeState, index: u8) ?[]const u8 {
        if (index >= self.relay_count) return null;
        return self._storage.relay_members.records[index].relayUrl();
    }
};

pub const Step =
    dm_sync_runtime_support.Step(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const Plan =
    dm_sync_runtime_support.Plan(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const PolicyStorage = dm_sync_runtime_support.PolicyStorage;
pub const PolicyStep =
    dm_sync_runtime_support.PolicyStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const PolicyPlan =
    dm_sync_runtime_support.PolicyPlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const OrchestrationStorage = dm_sync_runtime_support.OrchestrationStorage;
pub const OrchestrationStep =
    dm_sync_runtime_support.OrchestrationStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const OrchestrationPlan =
    dm_sync_runtime_support.OrchestrationPlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const CadenceRequest = dm_sync_runtime_support.CadenceRequest;
pub const CadenceStorage = dm_sync_runtime_support.CadenceStorage;
pub const CadenceWaitReason = dm_sync_runtime_support.CadenceWaitReason;
pub const CadenceWait = dm_sync_runtime_support.CadenceWait;
pub const CadenceStep =
    dm_sync_runtime_support.CadenceStep(mailbox_subscription_job.MailboxSubscriptionJobRequest);
pub const CadencePlan =
    dm_sync_runtime_support.CadencePlan(mailbox_subscription_job.MailboxSubscriptionJobRequest);

pub const AuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const ReplayRequest = mailbox_replay_job.MailboxReplayJobRequest;
pub const ReplayIntake = mailbox_replay_job.MailboxReplayJobIntake;
pub const SubscriptionRequest = mailbox_subscription_job.MailboxSubscriptionJobRequest;
pub const SubscriptionIntake = mailbox_subscription_job.MailboxSubscriptionJobIntake;

pub const Client = struct {
    config: Config,
    local_operator: local_operator.LocalOperatorClient,
    replay_job: mailbox_replay_job.MailboxReplayJobClient,
    subscription_job: mailbox_subscription_job.MailboxSubscriptionJobClient,
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
        config: Config,
        storage: *Storage,
    ) Client {
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

    pub fn relayCount(self: *const Client) u8 {
        return self.replay_job.relayCount();
    }

    pub fn currentRelayUrl(self: *const Client) ?[]const u8 {
        return self.replay_job.currentRelayUrl();
    }

    pub fn currentRelayAuthChallenge(self: *const Client) ?[]const u8 {
        return self.replay_job.currentRelayAuthChallenge();
    }

    pub fn replayPhaseComplete(self: *const Client) bool {
        return self.storage.replay_phase_complete;
    }

    pub fn exportResumeState(
        self: *const Client,
        storage: *ResumeStorage,
    ) ResumeState {
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

    pub fn liveSubscriptionActive(self: *const Client) bool {
        return self.storage.live_subscription_active;
    }

    pub fn hydrateRelayListEventJson(
        self: *Client,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) ClientError!u8 {
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
        self: *Client,
        relay_index: u8,
    ) ClientError![]const u8 {
        const replay_url = try self.replay_job.selectRelay(relay_index);
        const subscription_url = try self.subscription_job.selectRelay(relay_index);
        std.debug.assert(std.mem.eql(u8, replay_url, subscription_url));
        return replay_url;
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
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
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
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
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
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
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
            mailbox_subscription_job.MailboxSubscriptionJobRequest,
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
            &self.config.recipient_private_key,
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
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) ClientError!ReplayIntake {
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
        self: *Client,
        output: []u8,
        request: *const ReplayRequest,
    ) ClientError!mailbox_replay_job.MailboxReplayJobResult {
        return self.replay_job.completeReplayJob(output, request);
    }

    pub fn saveReplayTurnResult(
        self: *Client,
        archive: store.RelayCheckpointArchive,
        result: *const mailbox_replay_turn.MailboxReplayTurnResult,
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
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) ClientError!SubscriptionIntake {
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
        self: *Client,
        output: []u8,
        request: *const SubscriptionRequest,
    ) ClientError!mailbox_subscription_job.MailboxSubscriptionJobResult {
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
    left: *const SubscriptionRequest,
    right: *const SubscriptionRequest,
) bool {
    return left.subscription.relay.relay_index == right.subscription.relay.relay_index and
        std.mem.eql(u8, left.subscription.relay.relay_url, right.subscription.relay.relay_url) and
        std.mem.eql(u8, left.subscription.subscription_id, right.subscription.subscription_id);
}

fn restoreReplayTurnMembers(
    replay_turn: *mailbox_replay_turn.MailboxReplayTurnClient,
    members: *const runtime.RelayPoolMemberSet,
    current_relay_index: u8,
) ClientError!void {
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
) ClientError!void {
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
    var storage = Storage{};
    var client = Client.init(.{
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
    var client_storage = Storage{};
    var client = Client.init(.{
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

    var resume_storage = ResumeStorage{};
    const resume_state = client.exportResumeState(&resume_storage);
    try std.testing.expectEqual(@as(u8, 1), resume_state.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", resume_state.relayUrl(0).?);
    try std.testing.expect(resume_state.replay_phase_complete);

    var restored_storage = Storage{};
    var restored = Client.init(.{
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
    var runtime_storage = PlanStorage{};
    const plan = try restored.inspectRuntime(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(plan.nextStep() == .idle);

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

test "mailbox sync runtime client plans authenticate replay subscribe and receive explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage_buf = Storage{};
    var client = Client.init(.{
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
    var storage = Storage{};
    var client = Client.init(.{
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

test "mailbox sync runtime client returns idle when catchup is complete and no live specs remain" {
    var client_storage = Storage{};
    var client = Client.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
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

test "mailbox sync runtime client exposes broader dm orchestration phases" {
    var client_storage = Storage{};
    var client = Client.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
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

test "mailbox sync runtime client cadence can defer reconnect until caller backoff expires" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    const recipient_secret = [_]u8{0x33} ** 32;
    var client_storage = Storage{};
    var client = Client.init(.{
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

    var cadence_storage = CadenceStorage{};
    const waiting = try client.inspectCadence(
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
        CadenceWaitReason.reconnect_backoff,
        waiting.nextStep().wait.reason,
    );

    const due = try client.inspectCadence(
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
