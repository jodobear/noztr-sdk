const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const relay_response = @import("relay_response_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const RelaySessionClientError =
    local_operator.LocalOperatorClientError ||
    relay_response.RelayResponseClientError ||
    runtime.RelayPoolError ||
    runtime.RelaySubscriptionError ||
    runtime.RelayCountError ||
    runtime.RelayReplayError ||
    runtime.RelayPoolCheckpointError ||
    runtime.RelayPoolMemberError ||
    store.ClientStoreError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleRelaySession,
        StaleAuthStep,
        RelayNotReady,
        QueryLimitTooLarge,
        TooManyEventIds,
        TooManyAuthors,
        TooManyKinds,
    };

pub const RelaySessionClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    relay_response: relay_response.RelayResponseClientConfig = .{},
};

pub const RelaySessionClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const RelaySessionCloseRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const RelaySessionClient = struct {
    config: RelaySessionClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    relay_response: relay_response.RelayResponseClient,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: RelaySessionClientConfig,
        storage: *RelaySessionClientStorage,
    ) RelaySessionClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: RelaySessionClientConfig,
        storage: *RelaySessionClientStorage,
    ) RelaySessionClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *RelaySessionClient,
        relay_url_text: []const u8,
    ) RelaySessionClientError!runtime.RelayDescriptor {
        return self.relay_pool.addRelay(relay_url_text);
    }

    pub fn relayCount(self: *const RelaySessionClient) u8 {
        return self.relay_pool.relayCount();
    }

    pub fn markRelayConnected(
        self: *RelaySessionClient,
        relay_index: u8,
    ) RelaySessionClientError!void {
        try self.relay_pool.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelaySessionClient,
        relay_index: u8,
    ) RelaySessionClientError!void {
        try self.relay_pool.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelaySessionClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelaySessionClientError!void {
        try self.relay_pool.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const RelaySessionClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_pool.inspectRuntime(storage);
    }

    pub fn selectRelayRuntimeStep(
        self: *const RelaySessionClient,
        step: *const runtime.RelayPoolStep,
    ) RelaySessionClientError!runtime.RelayDescriptor {
        return self.requireCurrentDescriptor(&step.entry.descriptor);
    }

    pub fn beginSubscriptionTranscript(
        self: RelaySessionClient,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        subscription_id: []const u8,
    ) RelaySessionClientError!void {
        return self.relay_response.beginSubscriptionTranscript(transcript, subscription_id);
    }

    pub fn acceptSubscriptionMessageJson(
        self: RelaySessionClient,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelaySessionClientError!relay_response.RelaySubscriptionMessageOutcome {
        return self.relay_response.acceptSubscriptionMessageJson(
            transcript,
            relay_message_json,
            scratch,
        );
    }

    pub fn acceptCountMessageJson(
        self: RelaySessionClient,
        expected_subscription_id: []const u8,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelaySessionClientError!relay_response.RelayCountMessage {
        return self.relay_response.acceptCountMessageJson(
            expected_subscription_id,
            relay_message_json,
            scratch,
        );
    }

    pub fn acceptPublishOkJson(
        self: RelaySessionClient,
        expected_event_id: *const [32]u8,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelaySessionClientError!relay_response.RelayPublishOkMessage {
        return self.relay_response.acceptPublishOkJson(
            expected_event_id,
            relay_message_json,
            scratch,
        );
    }

    pub fn acceptNoticeJson(
        self: RelaySessionClient,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelaySessionClientError!relay_response.RelayNoticeMessage {
        return self.relay_response.acceptNoticeJson(relay_message_json, scratch);
    }

    pub fn acceptAuthChallengeJson(
        self: RelaySessionClient,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelaySessionClientError!relay_response.RelayAuthChallengeMessage {
        return self.relay_response.acceptAuthChallengeJson(relay_message_json, scratch);
    }

    pub fn composeCloseRequest(
        self: *const RelaySessionClient,
        output: []u8,
        descriptor: *const runtime.RelayDescriptor,
        subscription_id: []const u8,
    ) RelaySessionClientError!RelaySessionCloseRequest {
        const relay = try self.requireCurrentDescriptor(descriptor);
        const message = noztr.nip01_message.ClientMessage{
            .close = .{ .subscription_id = subscription_id },
        };
        const request_json = try noztr.nip01_message.client_message_serialize_json(output, &message);
        return .{
            .relay = relay,
            .subscription_id = subscription_id,
            .request_json = request_json,
        };
    }

    pub fn inspectAuth(
        self: *const RelaySessionClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.relay_pool.inspectAuth(storage);
    }

    pub fn selectAuthTarget(
        self: *const RelaySessionClient,
        step: *const runtime.RelayPoolAuthStep,
    ) RelaySessionClientError!relay_auth_support.RelayAuthTarget {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(&self.relay_pool, plan, step);
    }

    pub fn prepareAuthEvent(
        self: *const RelaySessionClient,
        auth_storage: *relay_auth_support.RelayAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) RelaySessionClientError!relay_auth_support.PreparedRelayAuthEvent {
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
        self: *RelaySessionClient,
        prepared: *const relay_auth_support.PreparedRelayAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) RelaySessionClientError!runtime.RelayDescriptor {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        try relay_auth_support.requireCurrentAuth(plan, prepared.relay, prepared.challenge);
        try self.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return prepared.relay;
    }

    pub fn inspectSubscriptions(
        self: *const RelaySessionClient,
        specs: []const runtime.RelaySubscriptionSpec,
        storage: *runtime.RelayPoolSubscriptionStorage,
    ) RelaySessionClientError!runtime.RelayPoolSubscriptionPlan {
        return self.relay_pool.inspectSubscriptions(specs, storage);
    }

    pub fn inspectCounts(
        self: *const RelaySessionClient,
        specs: []const runtime.RelayCountSpec,
        storage: *runtime.RelayPoolCountStorage,
    ) RelaySessionClientError!runtime.RelayPoolCountPlan {
        return self.relay_pool.inspectCounts(specs, storage);
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const RelaySessionClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) RelaySessionClientError!@import("relay_query_client.zig").TargetedSubscriptionRequest {
        const relay = try self.requireCurrentReadyForAction(&step.entry.descriptor, .ready);
        const request_json = try serializeRequestLike(
            output,
            .{
                .subscription_id = step.entry.subscription_id,
                .filters = step.entry.filters,
            },
            .req,
        );
        return .{
            .relay = relay,
            .subscription_id = step.entry.subscription_id,
            .request_json = request_json,
        };
    }

    pub fn composeTargetedCountRequest(
        self: *const RelaySessionClient,
        output: []u8,
        step: *const runtime.RelayPoolCountStep,
    ) RelaySessionClientError!@import("relay_query_client.zig").TargetedCountRequest {
        const relay = try self.requireCurrentReadyForAction(&step.entry.descriptor, .ready);
        const request_json = try serializeRequestLike(
            output,
            .{
                .subscription_id = step.entry.subscription_id,
                .filters = step.entry.filters,
            },
            .count,
        );
        return .{
            .relay = relay,
            .subscription_id = step.entry.subscription_id,
            .request_json = request_json,
        };
    }

    pub fn inspectPublish(
        self: *const RelaySessionClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.relay_pool.inspectPublish(storage);
    }

    pub fn prepareSignedEvent(
        self: RelaySessionClient,
        output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const local_operator.LocalEventDraft,
    ) RelaySessionClientError!@import("publish_client.zig").PreparedPublishEvent {
        var event = try self.local_operator.signDraft(secret_key, draft);
        const event_json = try self.local_operator.serializeEventJson(output, &event);
        return .{
            .event = event,
            .event_json = event_json,
        };
    }

    pub fn prepareExistingSignedEvent(
        self: RelaySessionClient,
        output: []u8,
        event: *const noztr.nip01_event.Event,
    ) RelaySessionClientError!@import("publish_client.zig").PreparedPublishEvent {
        _ = self;

        const event_json = try noztr.nip01_event.event_serialize_json_object(output, event);
        return .{
            .event = event.*,
            .event_json = event_json,
        };
    }

    pub fn composeTargetedPublish(
        self: *const RelaySessionClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const @import("publish_client.zig").PreparedPublishEvent,
    ) RelaySessionClientError!@import("publish_client.zig").TargetedPublishEvent {
        const relay = try self.requireCurrentPublishRelay(&step.entry.descriptor);
        const event_message_json = try serializeEventClientMessage(output, &prepared.event);
        return .{
            .relay = relay,
            .event = prepared.event,
            .event_json = prepared.event_json,
            .event_message_json = event_message_json,
        };
    }

    pub fn inspectReplay(
        self: *const RelaySessionClient,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) RelaySessionClientError!runtime.RelayPoolReplayPlan {
        return self.relay_pool.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn composeTargetedReplayRequest(
        self: *const RelaySessionClient,
        output: []u8,
        step: *const runtime.RelayPoolReplayStep,
        subscription_id: []const u8,
    ) RelaySessionClientError!@import("relay_replay_client.zig").TargetedReplayRequest {
        const relay = try self.requireCurrentReadyForAction(&step.entry.descriptor, .ready);
        const request_json = try serializeReplayRequest(output, subscription_id, &step.entry.query);
        return .{
            .relay = relay,
            .checkpoint_scope = step.entry.checkpoint_scope,
            .subscription_id = subscription_id,
            .query = step.entry.query,
            .request_json = request_json,
        };
    }

    pub fn beginReplay(
        self: *const RelaySessionClient,
        checkpoint_store: store.ClientCheckpointStore,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) RelaySessionClientError!@import("relay_replay_exchange_client.zig").ReplayExchangeRequest {
        var replay_storage = runtime.RelayPoolReplayStorage{};
        const replay_plan = try self.inspectReplay(checkpoint_store, specs, &replay_storage);
        const replay_step = replay_plan.nextStep() orelse return error.RelayNotReady;
        try self.beginSubscriptionTranscript(transcript, subscription_id);
        const targeted = try self.composeTargetedReplayRequest(output, &replay_step, subscription_id);
        return .{
            .relay = targeted.relay,
            .checkpoint_scope = targeted.checkpoint_scope,
            .query = targeted.query,
            .subscription_id = targeted.subscription_id,
            .request_json = targeted.request_json,
        };
    }

    pub fn exportMembers(
        self: *const RelaySessionClient,
        storage: *runtime.RelayPoolMemberStorage,
    ) RelaySessionClientError!runtime.RelayPoolMemberSet {
        return self.relay_pool.exportMembers(storage);
    }

    pub fn restoreMembers(
        self: *RelaySessionClient,
        members: *const runtime.RelayPoolMemberSet,
    ) RelaySessionClientError!void {
        try self.relay_pool.restoreMembers(members);
    }

    pub fn exportCheckpoints(
        self: *const RelaySessionClient,
        cursors: []const store.EventCursor,
        storage: *runtime.RelayPoolCheckpointStorage,
    ) RelaySessionClientError!runtime.RelayPoolCheckpointSet {
        return self.relay_pool.exportCheckpoints(cursors, storage);
    }

    pub fn restoreCheckpoints(
        self: *RelaySessionClient,
        checkpoints: *const runtime.RelayPoolCheckpointSet,
    ) RelaySessionClientError!void {
        try self.relay_pool.restoreCheckpoints(checkpoints);
    }

    fn requireCurrentDescriptor(
        self: *const RelaySessionClient,
        descriptor: *const runtime.RelayDescriptor,
    ) RelaySessionClientError!runtime.RelayDescriptor {
        const live = self.relay_pool.descriptor(descriptor.relay_index) orelse return error.StaleRelaySession;
        if (!std.mem.eql(u8, live.relay_url, descriptor.relay_url)) {
            return error.StaleRelaySession;
        }
        return live;
    }

    fn requireCurrentReadyForAction(
        self: *const RelaySessionClient,
        descriptor: *const runtime.RelayDescriptor,
        expected_runtime: runtime.RelayPoolAction,
    ) RelaySessionClientError!runtime.RelayDescriptor {
        const relay = try self.requireCurrentDescriptor(descriptor);
        var storage = runtime.RelayPoolPlanStorage{};
        const plan = self.inspectRelayRuntime(&storage);
        const current = plan.entry(relay.relay_index) orelse return error.StaleRelaySession;
        if (!std.mem.eql(u8, current.descriptor.relay_url, relay.relay_url)) {
            return error.StaleRelaySession;
        }
        if (current.action != expected_runtime) return error.RelayNotReady;
        return current.descriptor;
    }

    fn requireCurrentPublishRelay(
        self: *const RelaySessionClient,
        descriptor: *const runtime.RelayDescriptor,
    ) RelaySessionClientError!runtime.RelayDescriptor {
        const relay = try self.requireCurrentDescriptor(descriptor);
        var storage = runtime.RelayPoolPublishStorage{};
        const plan = self.inspectPublish(&storage);
        const current = plan.entry(relay.relay_index) orelse return error.StaleRelaySession;
        if (!std.mem.eql(u8, current.descriptor.relay_url, relay.relay_url)) {
            return error.StaleRelaySession;
        }
        if (current.action != .publish) return error.RelayNotReady;
        return current.descriptor;
    }
};

const RequestLike = struct {
    subscription_id: []const u8,
    filters: []const noztr.nip01_filter.Filter,
};

const RequestKind = enum {
    req,
    count,
};

fn serializeRequestLike(
    output: []u8,
    request: RequestLike,
    kind: RequestKind,
) RelaySessionClientError![]const u8 {
    var filters: [noztr.limits.message_filters_max]noztr.nip01_filter.Filter =
        [_]noztr.nip01_filter.Filter{.{}} ** noztr.limits.message_filters_max;
    for (request.filters, 0..) |filter, index| {
        filters[index] = filter;
    }

    const filter_count: u8 = @intCast(request.filters.len);
    const message: noztr.nip01_message.ClientMessage = switch (kind) {
        .req => .{
            .req = .{
                .subscription_id = request.subscription_id,
                .filters = filters,
                .filters_count = filter_count,
            },
        },
        .count => .{
            .count = .{
                .subscription_id = request.subscription_id,
                .filters = filters,
                .filters_count = filter_count,
            },
        },
    };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

fn serializeEventClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) RelaySessionClientError![]const u8 {
    const prefix = "[\"EVENT\",";
    if (output.len < prefix.len + 1) return error.BufferTooSmall;

    @memcpy(output[0..prefix.len], prefix);
    const event_json = try noztr.nip01_event.event_serialize_json_object(
        output[prefix.len .. output.len - 1],
        event,
    );
    const end = prefix.len + event_json.len;
    output[end] = ']';
    return output[0 .. end + 1];
}

fn serializeReplayRequest(
    output: []u8,
    subscription_id: []const u8,
    query: *const store.ClientQuery,
) RelaySessionClientError![]const u8 {
    const filter = try filterFromClientQuery(query);
    var filters: [noztr.limits.message_filters_max]noztr.nip01_filter.Filter =
        [_]noztr.nip01_filter.Filter{.{}} ** noztr.limits.message_filters_max;
    filters[0] = filter;

    const message = noztr.nip01_message.ClientMessage{
        .req = .{
            .subscription_id = subscription_id,
            .filters = filters,
            .filters_count = 1,
        },
    };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

fn filterFromClientQuery(query: *const store.ClientQuery) RelaySessionClientError!noztr.nip01_filter.Filter {
    var filter = noztr.nip01_filter.Filter{};

    if (query.ids.len > filter.ids.len) return error.TooManyEventIds;
    for (query.ids, 0..) |id_hex, index| {
        _ = std.fmt.hexToBytes(filter.ids[index][0..], id_hex[0..]) catch unreachable;
        filter.ids_prefix_nibbles[index] = @intCast(id_hex.len);
    }
    filter.ids_count = @intCast(query.ids.len);

    if (query.authors.len > filter.authors.len) return error.TooManyAuthors;
    for (query.authors, 0..) |author_hex, index| {
        _ = std.fmt.hexToBytes(filter.authors[index][0..], author_hex[0..]) catch unreachable;
        filter.authors_prefix_nibbles[index] = @intCast(author_hex.len);
    }
    filter.authors_count = @intCast(query.authors.len);

    if (query.kinds.len > filter.kinds.len) return error.TooManyKinds;
    for (query.kinds, 0..) |kind, index| {
        filter.kinds[index] = kind;
    }
    filter.kinds_count = @intCast(query.kinds.len);

    filter.since = query.since;
    filter.until = query.until;
    if (query.limit > std.math.maxInt(u16)) return error.QueryLimitTooLarge;
    filter.limit = @intCast(query.limit);
    return filter;
}

fn relayMessageJson(
    output: []u8,
    message: noztr.nip01_message.RelayMessage,
) ![]const u8 {
    return noztr.nip01_message.relay_message_serialize_json(output, &message);
}

fn sampleSignedEvent() !noztr.nip01_event.Event {
    var local = local_operator.LocalOperatorClient.init(.{});
    const secret_key = [_]u8{0x51} ** local_operator.secret_key_bytes;
    return local.signDraft(&secret_key, &.{
        .kind = 1,
        .created_at = 42,
        .content = "session event",
    });
}

test "relay session client exposes caller-owned runtime and response baseline" {
    var storage = RelaySessionClientStorage{};
    var client = RelaySessionClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    var runtime_storage = runtime.RelayPoolPlanStorage{};
    const plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), plan.ready_count);
    try std.testing.expectEqual(@as(u8, 1), client.relayCount());
    const ready_step = runtime.RelayPoolStep{ .entry = plan.entry(relay.relay_index).? };
    const selected = try client.selectRelayRuntimeStep(&ready_step);
    try std.testing.expectEqualStrings("wss://relay.one", selected.relay_url);
}

test "relay session client composes transcript intake and explicit close ownership" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelaySessionClientStorage{};
    var client = RelaySessionClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    var transcript = relay_response.RelaySubscriptionTranscriptStorage{};
    try client.beginSubscriptionTranscript(&transcript, "feed");

    const event = try sampleSignedEvent();
    var event_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_message_json = try relayMessageJson(event_json[0..], .{
        .event = .{
            .subscription_id = "feed",
            .event = event,
        },
    });
    const event_outcome = try client.acceptSubscriptionMessageJson(
        &transcript,
        event_message_json,
        arena.allocator(),
    );
    try std.testing.expect(event_outcome == .event);
    try std.testing.expectEqualStrings("feed", event_outcome.event.subscription_id);

    var close_json: [128]u8 = undefined;
    const close = try client.composeCloseRequest(close_json[0..], &relay, "feed");
    try std.testing.expectEqualStrings("wss://relay.one", close.relay.relay_url);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", close.request_json);
}

test "relay session client accepts count publish notice and auth relay messages explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelaySessionClientStorage{};
    const client = RelaySessionClient.init(.{}, &storage);

    var count_json: [128]u8 = undefined;
    const count_message_json = try relayMessageJson(count_json[0..], .{
        .count = .{ .subscription_id = "count-feed", .count = 7 },
    });
    const count_message = try client.acceptCountMessageJson(
        "count-feed",
        count_message_json,
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u64, 7), count_message.count);

    const event = try sampleSignedEvent();
    var ok_json: [256]u8 = undefined;
    const ok_message_json = try relayMessageJson(ok_json[0..], .{
        .ok = .{ .event_id = event.id, .accepted = true, .status = "ok" },
    });
    const ok_message = try client.acceptPublishOkJson(&event.id, ok_message_json, arena.allocator());
    try std.testing.expect(ok_message.accepted);

    var notice_json: [128]u8 = undefined;
    const notice_message_json = try relayMessageJson(notice_json[0..], .{
        .notice = .{ .message = "watch out" },
    });
    const notice = try client.acceptNoticeJson(notice_message_json, arena.allocator());
    try std.testing.expectEqualStrings("watch out", notice.message);

    var auth_json: [128]u8 = undefined;
    const auth_message_json = try relayMessageJson(auth_json[0..], .{
        .auth = .{ .challenge = "challenge-1" },
    });
    const auth = try client.acceptAuthChallengeJson(auth_message_json, arena.allocator());
    try std.testing.expectEqualStrings("challenge-1", auth.challenge);
}

test "relay session client composes publish for one caller-owned signed kernel event" {
    var storage = RelaySessionClientStorage{};
    var client = RelaySessionClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x44} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 443,
        .created_at = 88,
        .tags = &.{},
        .content = "{\"marmot\":true}",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareExistingSignedEvent(event_json_buffer[0..], &event);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;

    var message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted = try client.composeTargetedPublish(message_buffer[0..], &publish_step, &prepared);
    try std.testing.expectEqualStrings("wss://relay.one", targeted.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted.event_message_json, "[\"EVENT\","));
    try std.testing.expect(std.mem.indexOf(u8, targeted.event_json, "\"kind\":443") != null);
}
