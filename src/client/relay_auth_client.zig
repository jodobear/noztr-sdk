const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
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

pub const RelayAuthTarget = relay_auth_support.RelayAuthTarget;
pub const RelayAuthEventStorage = relay_auth_support.RelayAuthEventStorage;
pub const PreparedRelayAuthEvent = relay_auth_support.PreparedRelayAuthEvent;

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
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(&self.relay_pool, plan, step);
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
        return relay_auth_support.requireCurrentAuth(plan, descriptor, challenge);
    }
};

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
