const std = @import("std");
const noztr = @import("noztr");
const legacy_dm_replay_job = @import("legacy_dm_replay_job_client.zig");
const legacy_dm_replay_turn = @import("legacy_dm_replay_turn_client.zig");
const legacy_dm_subscription_job = @import("legacy_dm_subscription_job_client.zig");
const local_operator = @import("local_operator_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const sync_runtime_support = @import("sync_runtime_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const workflows = @import("../workflows/mod.zig");

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
        return sync_runtime_support.addRelay(self, relay_url_text);
    }

    pub fn markRelayConnected(
        self: *LegacyDmSyncRuntimeClient,
        relay_index: u8,
    ) LegacyDmSyncRuntimeClientError!void {
        return sync_runtime_support.markRelayConnected(self, relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LegacyDmSyncRuntimeClient,
        relay_index: u8,
    ) LegacyDmSyncRuntimeClientError!void {
        return sync_runtime_support.noteRelayDisconnected(self, relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *LegacyDmSyncRuntimeClient,
        relay_index: u8,
        challenge: []const u8,
    ) LegacyDmSyncRuntimeClientError!void {
        return sync_runtime_support.noteRelayAuthChallenge(self, relay_index, challenge);
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
        return sync_runtime_support.inspectRelayRuntime(self, storage);
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
        self: *LegacyDmSyncRuntimeClient,
        prepared: *const PreparedLegacyDmSyncRuntimeAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) LegacyDmSyncRuntimeClientError!runtime.RelayDescriptor {
        return sync_runtime_support.acceptPreparedAuthEvent(
            self,
            prepared,
            now_unix_seconds,
            window_seconds,
        );
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

test "legacy dm sync runtime client exposes caller-owned config and storage" {
    var storage = LegacyDmSyncRuntimeClientStorage{};
    var client = LegacyDmSyncRuntimeClient.init(.{
        .owner_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expect(!client.replayPhaseComplete());
    try std.testing.expect(!client.liveSubscriptionActive());
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

    var storage_buf = LegacyDmSyncRuntimeClientStorage{};
    var client = LegacyDmSyncRuntimeClient.init(.{
        .owner_private_key = recipient_secret,
    }, &storage_buf);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("legacy-dm", relay.relay_url, .{ .offset = 7 });

    const sender = workflows.LegacyDmSession.init(&sender_secret);
    var replay_outbound = workflows.LegacyDmOutboundStorage{};
    const replay_prepared = try sender.buildDirectMessageEvent(&replay_outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy dm sync runtime replay payload",
        .created_at = 41,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });

    var live_outbound = workflows.LegacyDmOutboundStorage{};
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

    var runtime_storage = LegacyDmSyncRuntimePlanStorage{};
    const auth_plan = try client.inspectRuntime(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &runtime_storage,
    );
    try std.testing.expect(auth_plan.nextStep() == .authenticate);

    var auth_storage = LegacyDmSyncRuntimeAuthEventStorage{};
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
    var client_storage = LegacyDmSyncRuntimeClientStorage{};
    var client = LegacyDmSyncRuntimeClient.init(.{
        .owner_private_key = [_]u8{0x33} ** 32,
    }, &client_storage);
    client.markReplayCatchupComplete();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    var runtime_storage = LegacyDmSyncRuntimePlanStorage{};
    const plan = try client.inspectRuntime(
        checkpoint_store,
        &.{},
        &.{},
        &runtime_storage,
    );
    try std.testing.expect(plan.nextStep() == .idle);
}
