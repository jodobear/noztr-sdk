const std = @import("std");
const internal_pool = @import("../relay/pool.zig");
const session = @import("../relay/session.zig");
const noztr = @import("noztr");

pub const pool_capacity: u8 = internal_pool.pool_capacity;

pub const RelayPoolError =
    noztr.nip42_auth.AuthError ||
    error{
        InvalidRelayUrl,
        RelayUrlTooLong,
        PoolFull,
        InvalidRelayIndex,
        ChallengeEmpty,
        ChallengeTooLong,
        NotConnected,
        AuthNotRequired,
    };

pub const RelayPoolAction = enum {
    connect,
    authenticate,
    ready,
};

pub const RelayDescriptor = struct {
    relay_index: u8,
    relay_url: []const u8,
};

pub const RelayPoolEntry = struct {
    descriptor: RelayDescriptor,
    action: RelayPoolAction,
};

pub const RelayPoolStorage = struct {
    pool: internal_pool.Pool = internal_pool.Pool.init(),
};

pub const RelayPoolPlanStorage = struct {
    entries: [pool_capacity]RelayPoolEntry = undefined,
};

pub const RelayPoolPlan = struct {
    entries: []const RelayPoolEntry = &.{},
    relay_count: u8 = 0,
    connect_count: u8 = 0,
    authenticate_count: u8 = 0,
    ready_count: u8 = 0,

    pub fn entry(self: *const RelayPoolPlan, index: u8) ?RelayPoolEntry {
        if (index >= self.relay_count) return null;
        return self.entries[index];
    }
};

pub const RelayPoolStep = struct {
    entry: RelayPoolEntry,
};

pub const RelayPool = struct {
    _storage: *RelayPoolStorage,

    pub fn init(storage: *RelayPoolStorage) RelayPool {
        storage.* = .{};
        return .{ ._storage = storage };
    }

    pub fn addRelay(self: *RelayPool, relay_url: []const u8) RelayPoolError!RelayDescriptor {
        const relay_index = try self._storage.pool.addRelay(relay_url);
        return self.descriptor(relay_index).?;
    }

    pub fn relayCount(self: *const RelayPool) u8 {
        return self._storage.pool.count;
    }

    pub fn descriptor(self: *const RelayPool, relay_index: u8) ?RelayDescriptor {
        const relay = self._storage.pool.getRelayConst(relay_index) orelse return null;
        return .{
            .relay_index = relay_index,
            .relay_url = relay.auth_session.relayUrl(),
        };
    }

    pub fn markRelayConnected(self: *RelayPool, relay_index: u8) RelayPoolError!void {
        const relay = try self.requireRelay(relay_index);
        relay.connect();
    }

    pub fn noteRelayDisconnected(self: *RelayPool, relay_index: u8) RelayPoolError!void {
        const relay = try self.requireRelay(relay_index);
        relay.disconnect();
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayPool,
        relay_index: u8,
        challenge: []const u8,
    ) RelayPoolError!void {
        const relay = try self.requireRelay(relay_index);
        try relay.requireAuth(challenge);
    }

    pub fn acceptRelayAuthEvent(
        self: *RelayPool,
        relay_index: u8,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) RelayPoolError!void {
        const relay = try self.requireRelay(relay_index);
        try relay.acceptAuthEvent(auth_event, now_unix_seconds, window_seconds);
    }

    pub fn inspectRuntime(self: *const RelayPool, storage: *RelayPoolPlanStorage) RelayPoolPlan {
        var connect_count: u8 = 0;
        var authenticate_count: u8 = 0;
        var ready_count: u8 = 0;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const action = classifyAction(relay.state);
            storage.entries[relay_index] = .{
                .descriptor = .{
                    .relay_index = relay_index,
                    .relay_url = relay.auth_session.relayUrl(),
                },
                .action = action,
            };
            switch (action) {
                .connect => connect_count += 1,
                .authenticate => authenticate_count += 1,
                .ready => ready_count += 1,
            }
        }

        return .{
            .entries = storage.entries[0..self._storage.pool.count],
            .relay_count = self._storage.pool.count,
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .ready_count = ready_count,
        };
    }

    fn requireRelay(self: *RelayPool, relay_index: u8) RelayPoolError!*session.RelaySession {
        return self._storage.pool.getRelay(relay_index) orelse error.InvalidRelayIndex;
    }
};

fn classifyAction(state: session.SessionState) RelayPoolAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .ready,
    };
}

test "relay pool storage initializes bounded public runtime state" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = &pool;
    try std.testing.expectEqual(@as(u8, 0), storage.pool.count);
}

test "relay pool wraps relay-local add and state transitions" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.one");
    try std.testing.expectEqual(@as(u8, 1), pool.relayCount());
    try std.testing.expectEqual(first.relay_index, second.relay_index);
    try std.testing.expectEqualStrings("wss://relay.one", first.relay_url);

    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.noteRelayDisconnected(first.relay_index);
}

test "relay pool rejects invalid relay index state changes" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    try std.testing.expectError(error.InvalidRelayIndex, pool.markRelayConnected(0));
}

test "relay pool inspects bounded runtime state by relay" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    var plan_storage = RelayPoolPlanStorage{};
    const plan = pool.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
    try std.testing.expectEqual(@as(u8, 0), plan.ready_count);
    try std.testing.expectEqual(RelayPoolAction.authenticate, plan.entry(first.relay_index).?.action);
    try std.testing.expectEqual(RelayPoolAction.connect, plan.entry(second.relay_index).?.action);
}
