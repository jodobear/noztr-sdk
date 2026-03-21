const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const runtime = @import("../runtime/mod.zig");

pub fn addRelay(self: anytype, relay_url_text: []const u8) !runtime.RelayDescriptor {
    const replay_relay = try self.replay_job.addRelay(relay_url_text);
    const subscription_relay = try self.subscription_job.addRelay(relay_url_text);
    std.debug.assert(std.mem.eql(u8, replay_relay.relay_url, subscription_relay.relay_url));
    return replay_relay;
}

pub fn markRelayConnected(self: anytype, relay_index: u8) !void {
    try self.replay_job.markRelayConnected(relay_index);
    try self.subscription_job.markRelayConnected(relay_index);
}

pub fn noteRelayDisconnected(self: anytype, relay_index: u8) !void {
    try self.replay_job.noteRelayDisconnected(relay_index);
    try self.subscription_job.noteRelayDisconnected(relay_index);
    self.storage.live_subscription_active = false;
}

pub fn noteRelayAuthChallenge(
    self: anytype,
    relay_index: u8,
    challenge: []const u8,
) !void {
    try self.replay_job.noteRelayAuthChallenge(relay_index, challenge);
    try self.subscription_job.noteRelayAuthChallenge(relay_index, challenge);
}

pub fn inspectRelayRuntime(
    self: anytype,
    storage: *runtime.RelayPoolPlanStorage,
) runtime.RelayPoolPlan {
    return self.replay_job.inspectRelayRuntime(storage);
}

pub fn selectAuthTarget(
    self: anytype,
    step: *const runtime.RelayPoolAuthStep,
) !relay_auth_client.RelayAuthTarget {
    var auth_storage = runtime.RelayPoolAuthStorage{};
    const plan = self.replay_job.replay_turn.inspectAuth(&auth_storage);
    return relay_auth_support.selectAuthTarget(
        &self.replay_job.replay_turn.replay_turn.replay_exchange.replay.relay_pool,
        plan,
        step,
    );
}

pub fn prepareAuthEvent(
    self: anytype,
    auth_storage: *relay_auth_client.RelayAuthEventStorage,
    event_json_output: []u8,
    auth_message_output: []u8,
    step: *const runtime.RelayPoolAuthStep,
    secret_key: *const [local_operator.secret_key_bytes]u8,
    created_at: u64,
) !relay_auth_client.PreparedRelayAuthEvent {
    const target = try selectAuthTarget(self, step);
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
    self: anytype,
    prepared: *const relay_auth_client.PreparedRelayAuthEvent,
    now_unix_seconds: u64,
    window_seconds: u32,
) !runtime.RelayDescriptor {
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

test "sync runtime support fans out lifecycle operations and auth acceptance" {
    const FakeTurn = struct {
        fn inspectAuth(
            self: *@This(),
            storage: *runtime.RelayPoolAuthStorage,
        ) runtime.RelayPoolAuthPlan {
            _ = self;
            _ = storage;
            return .{};
        }

        fn acceptRelayAuthEvent(
            self: *@This(),
            relay_index: u8,
            auth_event: *const @import("noztr").nip01_event.Event,
            now_unix_seconds: u64,
            window_seconds: u32,
        ) !runtime.RelayDescriptor {
            _ = self;
            _ = auth_event;
            _ = now_unix_seconds;
            _ = window_seconds;
            return .{ .relay_index = relay_index, .relay_url = "wss://relay.one" };
        }

        replay_turn: struct {
            replay_exchange: struct {
                replay: struct {
                    relay_pool: runtime.RelayPool = undefined,
                } = .{},
            } = .{},
        } = .{},
    };

    const FakeReplayJob = struct {
        replay_turn: FakeTurn = .{},
        connected: bool = false,
        disconnected: bool = false,
        challenged: bool = false,

        fn addRelay(self: *@This(), relay_url_text: []const u8) !runtime.RelayDescriptor {
            _ = self;
            return .{ .relay_index = 0, .relay_url = relay_url_text };
        }

        fn markRelayConnected(self: *@This(), relay_index: u8) !void {
            _ = relay_index;
            self.connected = true;
        }

        fn noteRelayDisconnected(self: *@This(), relay_index: u8) !void {
            _ = relay_index;
            self.disconnected = true;
        }

        fn noteRelayAuthChallenge(self: *@This(), relay_index: u8, challenge: []const u8) !void {
            _ = relay_index;
            _ = challenge;
            self.challenged = true;
        }

        fn inspectRelayRuntime(
            self: *@This(),
            storage: *runtime.RelayPoolPlanStorage,
        ) runtime.RelayPoolPlan {
            _ = self;
            _ = storage;
            return .{};
        }
    };

    const FakeSubscriptionTurn = struct {
        fn acceptRelayAuthEvent(
            self: *@This(),
            relay_index: u8,
            auth_event: *const @import("noztr").nip01_event.Event,
            now_unix_seconds: u64,
            window_seconds: u32,
        ) !runtime.RelayDescriptor {
            _ = self;
            _ = auth_event;
            _ = now_unix_seconds;
            _ = window_seconds;
            return .{ .relay_index = relay_index, .relay_url = "wss://relay.one" };
        }
    };

    const FakeSubscriptionJob = struct {
        subscription_turn: FakeSubscriptionTurn = .{},
        connected: bool = false,
        disconnected: bool = false,
        challenged: bool = false,

        fn addRelay(self: *@This(), relay_url_text: []const u8) !runtime.RelayDescriptor {
            _ = self;
            return .{ .relay_index = 0, .relay_url = relay_url_text };
        }

        fn markRelayConnected(self: *@This(), relay_index: u8) !void {
            _ = relay_index;
            self.connected = true;
        }

        fn noteRelayDisconnected(self: *@This(), relay_index: u8) !void {
            _ = relay_index;
            self.disconnected = true;
        }

        fn noteRelayAuthChallenge(self: *@This(), relay_index: u8, challenge: []const u8) !void {
            _ = relay_index;
            _ = challenge;
            self.challenged = true;
        }
    };

    const FakeStorage = struct {
        live_subscription_active: bool = true,
    };

    const FakeSelf = struct {
        replay_job: FakeReplayJob = .{},
        subscription_job: FakeSubscriptionJob = .{},
        storage: *FakeStorage,
        local_operator: local_operator.LocalOperatorClient = local_operator.LocalOperatorClient.init(.{}),
    };

    var storage = FakeStorage{};
    var self: FakeSelf = .{ .storage = &storage };
    var plan_storage = runtime.RelayPoolPlanStorage{};
    const descriptor = try addRelay(&self, "wss://relay.one");
    try std.testing.expectEqualStrings("wss://relay.one", descriptor.relay_url);

    try markRelayConnected(&self, 0);
    try std.testing.expect(self.replay_job.connected);
    try std.testing.expect(self.subscription_job.connected);

    try noteRelayAuthChallenge(&self, 0, "challenge-1");
    try std.testing.expect(self.replay_job.challenged);
    try std.testing.expect(self.subscription_job.challenged);

    try noteRelayDisconnected(&self, 0);
    try std.testing.expect(self.replay_job.disconnected);
    try std.testing.expect(self.subscription_job.disconnected);
    try std.testing.expect(!storage.live_subscription_active);

    _ = inspectRelayRuntime(&self, &plan_storage);
}
