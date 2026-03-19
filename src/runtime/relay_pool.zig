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

    fn requireRelay(self: *RelayPool, relay_index: u8) RelayPoolError!*session.RelaySession {
        return self._storage.pool.getRelay(relay_index) orelse error.InvalidRelayIndex;
    }
};

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
