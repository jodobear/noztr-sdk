const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth = @import("../relay/auth.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const RelayAuthClientError =
    local_operator.LocalOperatorClientError ||
    runtime.RelayPoolError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleAuthStep,
        RelayNotReady,
    };

pub const RelayAuthClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const RelayAuthClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const RelayAuthTarget = struct {
    relay: runtime.RelayDescriptor,
    challenge: []const u8,
};

pub const RelayAuthEventStorage = struct {
    relay_url: [relay_auth.relay_url_max_bytes]u8 = [_]u8{0} ** relay_auth.relay_url_max_bytes,
    relay_url_len: u16 = 0,
    challenge: [noztr.nip42_auth.challenge_max_bytes]u8 =
        [_]u8{0} ** noztr.nip42_auth.challenge_max_bytes,
    challenge_len: u8 = 0,
    relay_items: [2][]const u8 = undefined,
    challenge_items: [2][]const u8 = undefined,
    tags: [2]noztr.nip01_event.EventTag = undefined,

    pub fn relayUrl(self: *const RelayAuthEventStorage) []const u8 {
        return self.relay_url[0..self.relay_url_len];
    }

    pub fn challengeText(self: *const RelayAuthEventStorage) []const u8 {
        return self.challenge[0..self.challenge_len];
    }
};

pub const PreparedRelayAuthEvent = struct {
    relay: runtime.RelayDescriptor,
    challenge: []const u8,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    auth_message_json: []const u8,
};

pub const RelayAuthClient = struct {
    config: RelayAuthClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: RelayAuthClientConfig,
        storage: *RelayAuthClientStorage,
    ) RelayAuthClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: RelayAuthClientConfig,
        storage: *RelayAuthClientStorage,
    ) RelayAuthClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *RelayAuthClient,
        relay_url_text: []const u8,
    ) RelayAuthClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "relay_pool", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *RelayAuthClient,
        relay_index: u8,
    ) RelayAuthClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayAuthClient,
        relay_index: u8,
    ) RelayAuthClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayAuthClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayAuthClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "relay_pool",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const RelayAuthClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "relay_pool", storage);
    }

    pub fn inspectAuth(
        self: *const RelayAuthClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.relay_pool.inspectAuth(storage);
    }

    pub fn selectAuthTarget(
        self: *const RelayAuthClient,
        step: *const runtime.RelayPoolAuthStep,
    ) RelayAuthClientError!RelayAuthTarget {
        const live_descriptor = self.relay_pool.descriptor(step.entry.descriptor.relay_index) orelse {
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

    pub fn prepareAuthEvent(
        self: *const RelayAuthClient,
        auth_storage: *RelayAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) RelayAuthClientError!PreparedRelayAuthEvent {
        const target = try self.selectAuthTarget(step);
        fillAuthEventStorage(auth_storage, target.relay.relay_url, target.challenge);

        const draft = local_operator.LocalEventDraft{
            .kind = noztr.nip42_auth.auth_event_kind,
            .created_at = created_at,
            .content = "",
            .tags = auth_storage.tags[0..],
        };
        var event = try self.local_operator.signDraft(secret_key, &draft);
        const event_json = try self.local_operator.serializeEventJson(event_json_output, &event);
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
        self: *RelayAuthClient,
        prepared: *const PreparedRelayAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) RelayAuthClientError!runtime.RelayDescriptor {
        try self.requireCurrentAuth(prepared.relay, prepared.challenge);
        try self.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return prepared.relay;
    }

    fn requireCurrentAuth(
        self: *const RelayAuthClient,
        descriptor: runtime.RelayDescriptor,
        challenge: []const u8,
    ) RelayAuthClientError!void {
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
    storage: *RelayAuthEventStorage,
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
) RelayAuthClientError![]const u8 {
    const message = noztr.nip01_message.ClientMessage{ .auth = .{ .event = event.* } };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

test "relay auth client exposes caller-owned config and relay-pool storage" {
    var storage = RelayAuthClientStorage{};
    const client = RelayAuthClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "relay auth client composes one signed auth event and returns the relay to ready" {
    var storage = RelayAuthClientStorage{};
    var client = RelayAuthClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    const auth_plan = client.inspectAuth(&auth_plan_storage);
    try std.testing.expectEqual(@as(u8, 1), auth_plan.authenticate_count);
    const step = auth_plan.nextStep().?;

    const secret_key = [_]u8{0x41} ** 32;
    var event_storage = RelayAuthEventStorage{};
    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared = try client.prepareAuthEvent(
        &event_storage,
        event_json_buffer[0..],
        auth_message_buffer[0..],
        &step,
        &secret_key,
        42,
    );

    try std.testing.expectEqualStrings("wss://relay.one", prepared.relay.relay_url);
    try std.testing.expectEqualStrings("challenge-1", prepared.challenge);
    try std.testing.expect(std.mem.startsWith(u8, prepared.auth_message_json, "[\"AUTH\","));
    try noztr.nip42_auth.auth_validate_event(
        &prepared.event,
        prepared.relay.relay_url,
        prepared.challenge,
        45,
        60,
    );

    const accepted = try client.acceptPreparedAuthEvent(&prepared, 45, 60);
    try std.testing.expectEqual(relay.relay_index, accepted.relay_index);

    var runtime_storage = runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);
    try std.testing.expectEqual(runtime.RelayPoolAction.ready, runtime_plan.entry(relay.relay_index).?.action);
}

test "relay auth client rejects auth steps that are no longer auth-required" {
    var storage = RelayAuthClientStorage{};
    var client = RelayAuthClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    const auth_plan = client.inspectAuth(&auth_plan_storage);
    const step = auth_plan.nextStep().?;

    const secret_key = [_]u8{0x42} ** 32;
    var event_storage = RelayAuthEventStorage{};
    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared = try client.prepareAuthEvent(
        &event_storage,
        event_json_buffer[0..],
        auth_message_buffer[0..],
        &step,
        &secret_key,
        42,
    );

    try client.noteRelayDisconnected(relay.relay_index);
    try std.testing.expectError(error.RelayNotReady, client.acceptPreparedAuthEvent(&prepared, 45, 60));
}
