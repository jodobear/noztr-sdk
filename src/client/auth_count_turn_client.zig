const std = @import("std");
const count_turn = @import("count_turn_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth = @import("../relay/auth.zig");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const AuthCountTurnClientError =
    count_turn.CountTurnClientError ||
    relay_auth_client.RelayAuthClientError;

pub const AuthCountTurnClientConfig = struct {
    count_turn: count_turn.CountTurnClientConfig = .{},
};

pub const AuthCountTurnClientStorage = struct {
    count_turn: count_turn.CountTurnClientStorage = .{},
};

pub const AuthCountEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthCountEvent = relay_auth_client.PreparedRelayAuthEvent;

pub const AuthCountTurnStep = union(enum) {
    authenticate: runtime.RelayPoolAuthStep,
    count: runtime.RelayPoolCountStep,
};

pub const AuthCountTurnResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    counted: count_turn.CountTurnResult,
};

pub const AuthCountTurnClient = struct {
    config: AuthCountTurnClientConfig,
    count_turn: count_turn.CountTurnClient,

    pub fn init(
        config: AuthCountTurnClientConfig,
        storage: *AuthCountTurnClientStorage,
    ) AuthCountTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .count_turn = count_turn.CountTurnClient.attach(
                config.count_turn,
                &storage.count_turn,
            ),
        };
    }

    pub fn attach(
        config: AuthCountTurnClientConfig,
        storage: *AuthCountTurnClientStorage,
    ) AuthCountTurnClient {
        return .{
            .config = config,
            .count_turn = count_turn.CountTurnClient.attach(
                config.count_turn,
                &storage.count_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *AuthCountTurnClient,
        relay_url_text: []const u8,
    ) AuthCountTurnClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "count_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *AuthCountTurnClient,
        relay_index: u8,
    ) AuthCountTurnClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "count_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *AuthCountTurnClient,
        relay_index: u8,
    ) AuthCountTurnClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "count_turn", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *AuthCountTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) AuthCountTurnClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "count_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const AuthCountTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "count_turn", storage);
    }

    pub fn inspectAuth(
        self: *const AuthCountTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.count_turn.relay_exchange.relay_pool.inspectAuth(storage);
    }

    pub fn inspectCount(
        self: *const AuthCountTurnClient,
        specs: []const runtime.RelayCountSpec,
        storage: *runtime.RelayPoolCountStorage,
    ) AuthCountTurnClientError!runtime.RelayPoolCountPlan {
        return self.count_turn.relay_exchange.relay_pool.inspectCounts(specs, storage);
    }

    pub fn nextStep(
        self: *const AuthCountTurnClient,
        auth_storage: *runtime.RelayPoolAuthStorage,
        specs: []const runtime.RelayCountSpec,
        count_storage: *runtime.RelayPoolCountStorage,
    ) AuthCountTurnClientError!?AuthCountTurnStep {
        const auth_plan = self.inspectAuth(auth_storage);
        if (auth_plan.nextStep()) |step| {
            return .{ .authenticate = step };
        }

        const count_plan = try self.inspectCount(specs, count_storage);
        if (count_plan.nextStep()) |step| {
            return .{ .count = step };
        }

        return null;
    }

    pub fn prepareAuthEvent(
        self: *const AuthCountTurnClient,
        auth_storage: *AuthCountEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) AuthCountTurnClientError!PreparedAuthCountEvent {
        const target = try self.selectAuthTarget(step);
        fillAuthEventStorage(auth_storage, target.relay.relay_url, target.challenge);

        const draft = local_operator.LocalEventDraft{
            .kind = noztr.nip42_auth.auth_event_kind,
            .created_at = created_at,
            .content = "",
            .tags = auth_storage.tags[0..],
        };
        var event = try self.count_turn.relay_exchange.local_operator.signDraft(secret_key, &draft);
        const event_json = try self.count_turn.relay_exchange.local_operator.serializeEventJson(
            event_json_output,
            &event,
        );
        const auth_message_json = try serializeAuthClientMessage(auth_message_output, &event);
        return .{
            .relay = target.relay,
            .challenge = auth_storage.challengeText(),
            .event = event,
            .event_json = event_json,
            .auth_message_json = auth_message_json,
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *AuthCountTurnClient,
        prepared: *const PreparedAuthCountEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) AuthCountTurnClientError!AuthCountTurnResult {
        try self.requireCurrentAuth(prepared.relay, prepared.challenge);
        try self.count_turn.relay_exchange.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = prepared.relay };
    }

    pub fn beginCountTurn(
        self: *const AuthCountTurnClient,
        output: []u8,
        specs: []const runtime.RelayCountSpec,
    ) AuthCountTurnClientError!count_turn.CountTurnRequest {
        return self.count_turn.beginTurn(output, specs);
    }

    pub fn acceptCountMessageJson(
        self: *const AuthCountTurnClient,
        request: *const count_turn.CountTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) AuthCountTurnClientError!AuthCountTurnResult {
        const counted = try self.count_turn.acceptCountMessageJson(
            request,
            relay_message_json,
            scratch,
        );
        return .{ .counted = counted };
    }

    fn selectAuthTarget(
        self: *const AuthCountTurnClient,
        step: *const runtime.RelayPoolAuthStep,
    ) AuthCountTurnClientError!relay_auth_client.RelayAuthTarget {
        const live_descriptor = self.count_turn.relay_exchange.relay_pool.descriptor(
            step.entry.descriptor.relay_index,
        ) orelse {
            return error.StaleAuthStep;
        };
        if (!std.mem.eql(u8, live_descriptor.relay_url, step.entry.descriptor.relay_url)) {
            return error.StaleAuthStep;
        }

        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        const current = plan.entry(step.entry.descriptor.relay_index) orelse return error.StaleAuthStep;
        if (!std.mem.eql(u8, current.descriptor.relay_url, step.entry.descriptor.relay_url)) {
            return error.StaleAuthStep;
        }
        if (current.action != .authenticate) return error.RelayNotReady;
        if (!std.mem.eql(u8, current.challenge, step.entry.challenge)) return error.StaleAuthStep;

        return .{
            .relay = current.descriptor,
            .challenge = current.challenge,
        };
    }

    fn requireCurrentAuth(
        self: *const AuthCountTurnClient,
        descriptor: runtime.RelayDescriptor,
        challenge: []const u8,
    ) AuthCountTurnClientError!void {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        const current = plan.entry(descriptor.relay_index) orelse return error.StaleAuthStep;
        if (!std.mem.eql(u8, current.descriptor.relay_url, descriptor.relay_url)) {
            return error.StaleAuthStep;
        }
        if (current.action != .authenticate) return error.RelayNotReady;
        if (!std.mem.eql(u8, current.challenge, challenge)) return error.StaleAuthStep;
    }
};

fn fillAuthEventStorage(
    storage: *AuthCountEventStorage,
    relay_url_text: []const u8,
    challenge: []const u8,
) void {
    std.debug.assert(relay_url_text.len <= relay_auth.relay_url_max_bytes);
    std.debug.assert(challenge.len <= noztr.nip42_auth.challenge_max_bytes);

    storage.* = .{};
    storage.relay_url_len = @intCast(relay_url_text.len);
    storage.challenge_len = @intCast(challenge.len);
    @memcpy(storage.relay_url[0..relay_url_text.len], relay_url_text);
    @memcpy(storage.challenge[0..challenge.len], challenge);
    storage.relay_items = .{ "relay", storage.relayUrl() };
    storage.challenge_items = .{ "challenge", storage.challengeText() };
    storage.tags[0] = .{ .items = storage.relay_items[0..] };
    storage.tags[1] = .{ .items = storage.challenge_items[0..] };
}

fn serializeAuthClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) AuthCountTurnClientError![]const u8 {
    const message = noztr.nip01_message.ClientMessage{ .auth = .{ .event = event.* } };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

test "auth count turn client exposes caller-owned config and storage" {
    var storage = AuthCountTurnClientStorage{};
    var client = AuthCountTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.count_turn.relay_exchange.relay_pool.relayCount());
}

test "auth count turn client authenticates then resumes one bounded count turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = AuthCountTurnClientStorage{};
    var client = AuthCountTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const noztr_local = @import("noztr");
    const filter = try noztr_local.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr_local.nip01_filter.Filter{filter})[0..] },
    };

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var count_plan_storage = runtime.RelayPoolCountStorage{};
    const auth_step = (try client.nextStep(&auth_plan_storage, specs[0..], &count_plan_storage)).?.authenticate;

    const secret_key = [_]u8{0x44} ** 32;
    var auth_event_storage = AuthCountEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        80,
    );
    const auth_result = try client.acceptPreparedAuthEvent(&prepared_auth, 85, 60);
    try std.testing.expect(auth_result == .authenticated);

    const count_step = (try client.nextStep(&auth_plan_storage, specs[0..], &count_plan_storage)).?.count;
    try std.testing.expectEqual(relay.relay_index, count_step.entry.descriptor.relay_index);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginCountTurn(request_output[0..], specs[0..]);
    var reply_output: [128]u8 = undefined;
    const count_json = try noztr_local.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 12 } },
    );
    const result = try client.acceptCountMessageJson(&request, count_json, arena.allocator());
    try std.testing.expect(result == .counted);
    try std.testing.expectEqual(@as(u64, 12), result.counted.count);
}

test "auth count turn client rejects stale auth steps and disconnected count recovery" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr_local = @import("noztr");
    const filter = try noztr_local.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr_local.nip01_filter.Filter{filter})[0..] },
    };

    var stale_storage = AuthCountTurnClientStorage{};
    var stale_client = AuthCountTurnClient.init(.{}, &stale_storage);
    const stale_relay = try stale_client.addRelay("wss://relay.one");
    try stale_client.markRelayConnected(stale_relay.relay_index);
    try stale_client.noteRelayAuthChallenge(stale_relay.relay_index, "challenge-1");

    var stale_auth_storage = runtime.RelayPoolAuthStorage{};
    var stale_count_storage = runtime.RelayPoolCountStorage{};
    const stale_step = (try stale_client.nextStep(
        &stale_auth_storage,
        specs[0..],
        &stale_count_storage,
    )).?.authenticate;
    const secret_key = [_]u8{0x45} ** 32;
    var auth_event_storage = AuthCountEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const stale_prepared_auth = try stale_client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &stale_step,
        &secret_key,
        81,
    );
    try stale_client.noteRelayDisconnected(stale_relay.relay_index);
    try stale_client.markRelayConnected(stale_relay.relay_index);
    try stale_client.noteRelayAuthChallenge(stale_relay.relay_index, "challenge-2");

    try std.testing.expectError(
        error.StaleAuthStep,
        stale_client.acceptPreparedAuthEvent(&stale_prepared_auth, 82, 60),
    );

    var disconnected_storage = AuthCountTurnClientStorage{};
    var disconnected_client = AuthCountTurnClient.init(.{}, &disconnected_storage);
    const disconnected_relay = try disconnected_client.addRelay("wss://relay.two");
    try disconnected_client.markRelayConnected(disconnected_relay.relay_index);
    try disconnected_client.noteRelayAuthChallenge(disconnected_relay.relay_index, "challenge-3");

    var disconnected_auth_storage = runtime.RelayPoolAuthStorage{};
    var disconnected_count_storage = runtime.RelayPoolCountStorage{};
    const auth_step = (try disconnected_client.nextStep(
        &disconnected_auth_storage,
        specs[0..],
        &disconnected_count_storage,
    )).?.authenticate;
    const prepared_auth = try disconnected_client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        83,
    );
    _ = try disconnected_client.acceptPreparedAuthEvent(&prepared_auth, 84, 60);
    try disconnected_client.noteRelayDisconnected(disconnected_relay.relay_index);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    try std.testing.expectError(
        error.NoReadyRelay,
        disconnected_client.beginCountTurn(request_output[0..], specs[0..]),
    );
}
