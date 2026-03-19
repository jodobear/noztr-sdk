const std = @import("std");
const internal_pool = @import("../relay/pool.zig");
const session = @import("../relay/session.zig");
const relay_url = @import("../relay/url.zig");
const client = @import("../store/client_traits.zig");
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

pub const RelayPoolCheckpointError = RelayPoolError || error{
    CursorCountMismatch,
    PoolNotEmpty,
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

pub const RelayPoolCheckpointAction = enum {
    export_checkpoint,
    restore_checkpoint,
};

pub const RelayPoolCheckpointRecord = struct {
    relay_url: [relay_url.relay_url_max_bytes]u8 = [_]u8{0} ** relay_url.relay_url_max_bytes,
    relay_url_len: u16 = 0,
    cursor: client.EventCursor = .{},

    pub fn relayUrl(self: *const RelayPoolCheckpointRecord) []const u8 {
        std.debug.assert(self.relay_url_len <= relay_url.relay_url_max_bytes);
        return self.relay_url[0..self.relay_url_len];
    }
};

pub const RelayPoolCheckpointStorage = struct {
    records: [pool_capacity]RelayPoolCheckpointRecord = undefined,
};

pub const RelayPoolCheckpointSet = struct {
    records: []const RelayPoolCheckpointRecord = &.{},
    relay_count: u8 = 0,

    pub fn entry(self: *const RelayPoolCheckpointSet, index: u8) ?RelayPoolCheckpointRecord {
        if (index >= self.relay_count) return null;
        return self.records[index];
    }
};

pub const RelayPoolCheckpointStep = struct {
    action: RelayPoolCheckpointAction,
    record: RelayPoolCheckpointRecord,
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

    pub fn nextEntry(self: *const RelayPoolPlan) ?RelayPoolEntry {
        var index: usize = 0;
        while (index < self.entries.len) : (index += 1) {
            if (self.entries[index].action == .authenticate) return self.entries[index];
        }
        index = 0;
        while (index < self.entries.len) : (index += 1) {
            if (self.entries[index].action == .connect) return self.entries[index];
        }
        return null;
    }

    pub fn nextStep(self: *const RelayPoolPlan) ?RelayPoolStep {
        const selected = self.nextEntry() orelse return null;
        return .{ .entry = selected };
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

    pub fn addRelay(self: *RelayPool, relay_url_text: []const u8) RelayPoolError!RelayDescriptor {
        const relay_index = try self._storage.pool.addRelay(relay_url_text);
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

    pub fn exportCheckpoints(
        self: *const RelayPool,
        cursors: []const client.EventCursor,
        storage: *RelayPoolCheckpointStorage,
    ) RelayPoolCheckpointError!RelayPoolCheckpointSet {
        if (cursors.len < self._storage.pool.count) return error.CursorCountMismatch;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const relay_url_text = relay.auth_session.relayUrl();
            if (relay_url_text.len > relay_url.relay_url_max_bytes) return error.RelayUrlTooLong;

            storage.records[relay_index] = .{
                .relay_url_len = @intCast(relay_url_text.len),
                .cursor = cursors[relay_index],
            };
            @memcpy(storage.records[relay_index].relay_url[0..relay_url_text.len], relay_url_text);
        }

        return .{
            .records = storage.records[0..self._storage.pool.count],
            .relay_count = self._storage.pool.count,
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

test "relay pool checkpoint record exposes one bounded relay url slice" {
    var record = RelayPoolCheckpointRecord{
        .relay_url_len = 15,
        .cursor = .{ .offset = 7 },
    };
    @memcpy(record.relay_url[0..15], "wss://relay.one");
    try std.testing.expectEqualStrings("wss://relay.one", record.relayUrl());
    try std.testing.expectEqual(@as(u32, 7), record.cursor.offset);
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

test "relay pool runtime next-step prefers authenticate before connect" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    var plan_storage = RelayPoolPlanStorage{};
    const plan = pool.inspectRuntime(&plan_storage);
    const next_entry = plan.nextEntry().?;
    try std.testing.expectEqual(first.relay_index, next_entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolAction.authenticate, next_entry.action);

    const next_step = plan.nextStep().?;
    try std.testing.expectEqual(first.relay_index, next_step.entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolAction.authenticate, next_step.entry.action);
    try std.testing.expectEqualStrings("wss://relay.one", next_step.entry.descriptor.relay_url);

    _ = second;
}

test "relay pool runtime next-step is null when all relays are ready" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const relay = try pool.addRelay("wss://relay.one");
    try pool.markRelayConnected(relay.relay_index);

    var plan_storage = RelayPoolPlanStorage{};
    const plan = pool.inspectRuntime(&plan_storage);
    try std.testing.expect(plan.nextEntry() == null);
    try std.testing.expect(plan.nextStep() == null);
}

test "relay pool exports bounded relay checkpoints in pool order" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");
    _ = try pool.addRelay("wss://relay.two");

    const cursors = [_]client.EventCursor{
        .{ .offset = 7 },
        .{ .offset = 9 },
    };
    var checkpoint_storage = RelayPoolCheckpointStorage{};
    const checkpoints = try pool.exportCheckpoints(cursors[0..], &checkpoint_storage);
    try std.testing.expectEqual(@as(u8, 2), checkpoints.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", checkpoints.entry(0).?.relayUrl());
    try std.testing.expectEqual(@as(u32, 7), checkpoints.entry(0).?.cursor.offset);
    try std.testing.expectEqualStrings("wss://relay.two", checkpoints.entry(1).?.relayUrl());
    try std.testing.expectEqual(@as(u32, 9), checkpoints.entry(1).?.cursor.offset);
}
