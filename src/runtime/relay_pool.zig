const std = @import("std");
const internal_pool = @import("../relay/pool.zig");

pub const pool_capacity: u8 = internal_pool.pool_capacity;

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
};

test "relay pool storage initializes bounded public runtime state" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = &pool;
    try std.testing.expectEqual(@as(u8, 0), storage.pool.count);
}
