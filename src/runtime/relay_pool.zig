const std = @import("std");
const internal_pool = @import("../relay/pool.zig");
const session = @import("../relay/session.zig");
const relay_url = @import("../relay/url.zig");
const client = @import("../store/client_traits.zig");
const relay_checkpoint = @import("../store/relay_checkpoint.zig");
const noztr = @import("noztr");

pub const pool_capacity: u8 = internal_pool.pool_capacity;
pub const subscription_specs_capacity: u8 = 8;
pub const count_specs_capacity: u8 = 8;
pub const replay_specs_capacity: u8 = 8;

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

pub const RelayPoolMemberError = RelayPoolError || error{
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

pub const RelayPoolPublishAction = enum {
    connect,
    authenticate,
    publish,
};

pub const RelayPoolPublishEntry = struct {
    descriptor: RelayDescriptor,
    action: RelayPoolPublishAction,
};

pub const RelayPoolPublishStorage = struct {
    entries: [pool_capacity]RelayPoolPublishEntry = undefined,
};

pub const RelayPoolPublishPlan = struct {
    entries: []const RelayPoolPublishEntry = &.{},
    relay_count: u8 = 0,
    connect_count: u8 = 0,
    authenticate_count: u8 = 0,
    publish_count: u8 = 0,

    pub fn entry(self: *const RelayPoolPublishPlan, index: u8) ?RelayPoolPublishEntry {
        if (index >= self.relay_count) return null;
        return self.entries[index];
    }

    pub fn nextEntry(self: *const RelayPoolPublishPlan) ?RelayPoolPublishEntry {
        var index: usize = 0;
        while (index < self.entries.len) : (index += 1) {
            if (self.entries[index].action == .publish) return self.entries[index];
        }
        return null;
    }

    pub fn nextStep(self: *const RelayPoolPublishPlan) ?RelayPoolPublishStep {
        const selected = self.nextEntry() orelse return null;
        return .{ .entry = selected };
    }
};

pub const RelayPoolPublishStep = struct {
    entry: RelayPoolPublishEntry,
};

pub const RelayPoolAuthAction = enum {
    connect,
    authenticate,
    ready,
};

pub const RelayPoolAuthEntry = struct {
    descriptor: RelayDescriptor,
    challenge: []const u8,
    action: RelayPoolAuthAction,
};

pub const RelayPoolAuthStorage = struct {
    entries: [pool_capacity]RelayPoolAuthEntry = undefined,
};

pub const RelayPoolAuthPlan = struct {
    entries: []const RelayPoolAuthEntry = &.{},
    relay_count: u8 = 0,
    connect_count: u8 = 0,
    authenticate_count: u8 = 0,
    ready_count: u8 = 0,

    pub fn entry(self: *const RelayPoolAuthPlan, index: u8) ?RelayPoolAuthEntry {
        if (index >= self.relay_count) return null;
        return self.entries[index];
    }

    pub fn nextEntry(self: *const RelayPoolAuthPlan) ?RelayPoolAuthEntry {
        var index: usize = 0;
        while (index < self.entries.len) : (index += 1) {
            if (self.entries[index].action == .authenticate) return self.entries[index];
        }
        return null;
    }

    pub fn nextStep(self: *const RelayPoolAuthPlan) ?RelayPoolAuthStep {
        const selected = self.nextEntry() orelse return null;
        return .{ .entry = selected };
    }
};

pub const RelayPoolAuthStep = struct {
    entry: RelayPoolAuthEntry,
};

pub const RelaySubscriptionError = error{
    TooManySubscriptionSpecs,
    EmptySubscriptionId,
    SubscriptionIdTooLong,
    EmptySubscriptionFilters,
    TooManySubscriptionFilters,
};

pub const RelayCountError = error{
    TooManyCountSpecs,
    EmptySubscriptionId,
    SubscriptionIdTooLong,
    EmptyCountFilters,
    TooManyCountFilters,
};

pub const RelayReplayError = client.ClientStoreError || error{
    TooManyReplaySpecs,
    MissingCheckpointStore,
    InvalidCheckpointScope,
    CheckpointScopeTooLong,
    InvalidRelayUrl,
    UnboundedReplayQuery,
};

pub const RelaySubscriptionSpec = struct {
    subscription_id: []const u8,
    filters: []const noztr.nip01_filter.Filter,
};

pub const RelayPoolSubscriptionAction = enum {
    connect,
    authenticate,
    subscribe,
};

pub const RelayPoolSubscriptionEntry = struct {
    descriptor: RelayDescriptor,
    subscription_id: []const u8,
    filters: []const noztr.nip01_filter.Filter,
    action: RelayPoolSubscriptionAction,
};

pub const RelayPoolSubscriptionStorage = struct {
    entries: [@as(usize, pool_capacity) * @as(usize, subscription_specs_capacity)]RelayPoolSubscriptionEntry = undefined,
};

pub const RelayPoolSubscriptionPlan = struct {
    entries: []const RelayPoolSubscriptionEntry = &.{},
    entry_count: u16 = 0,
    relay_count: u8 = 0,
    spec_count: u8 = 0,
    connect_count: u16 = 0,
    authenticate_count: u16 = 0,
    subscribe_count: u16 = 0,

    pub fn entry(self: *const RelayPoolSubscriptionPlan, index: u16) ?RelayPoolSubscriptionEntry {
        if (index >= self.entry_count) return null;
        return self.entries[index];
    }

    pub fn nextEntry(self: *const RelayPoolSubscriptionPlan) ?RelayPoolSubscriptionEntry {
        var index: u16 = 0;
        while (index < self.entry_count) : (index += 1) {
            const current = self.entries[index];
            if (current.action == .subscribe) return current;
        }
        return null;
    }

    pub fn nextStep(self: *const RelayPoolSubscriptionPlan) ?RelayPoolSubscriptionStep {
        const selected = self.nextEntry() orelse return null;
        return .{ .entry = selected };
    }
};

pub const RelayPoolSubscriptionStep = struct {
    entry: RelayPoolSubscriptionEntry,
};

pub const RelayCountSpec = struct {
    subscription_id: []const u8,
    filters: []const noztr.nip01_filter.Filter,
};

pub const RelayPoolCountAction = enum {
    connect,
    authenticate,
    count,
};

pub const RelayPoolCountEntry = struct {
    descriptor: RelayDescriptor,
    subscription_id: []const u8,
    filters: []const noztr.nip01_filter.Filter,
    action: RelayPoolCountAction,
};

pub const RelayPoolCountStorage = struct {
    entries: [@as(usize, pool_capacity) * @as(usize, count_specs_capacity)]RelayPoolCountEntry = undefined,
};

pub const RelayPoolCountPlan = struct {
    entries: []const RelayPoolCountEntry = &.{},
    entry_count: u16 = 0,
    relay_count: u8 = 0,
    spec_count: u8 = 0,
    connect_count: u16 = 0,
    authenticate_count: u16 = 0,
    count_count: u16 = 0,

    pub fn entry(self: *const RelayPoolCountPlan, index: u16) ?RelayPoolCountEntry {
        if (index >= self.entry_count) return null;
        return self.entries[index];
    }

    pub fn nextEntry(self: *const RelayPoolCountPlan) ?RelayPoolCountEntry {
        var index: u16 = 0;
        while (index < self.entry_count) : (index += 1) {
            const current = self.entries[index];
            if (current.action == .count) return current;
        }
        return null;
    }

    pub fn nextStep(self: *const RelayPoolCountPlan) ?RelayPoolCountStep {
        const selected = self.nextEntry() orelse return null;
        return .{ .entry = selected };
    }
};

pub const RelayPoolCountStep = struct {
    entry: RelayPoolCountEntry,
};

pub const RelayReplaySpec = struct {
    checkpoint_scope: []const u8,
    query: client.ClientQuery,
};

pub const RelayPoolReplayAction = enum {
    connect,
    authenticate,
    replay,
};

pub const RelayPoolReplayEntry = struct {
    descriptor: RelayDescriptor,
    checkpoint_scope: []const u8,
    query: client.ClientQuery,
    action: RelayPoolReplayAction,
};

pub const RelayPoolReplayStorage = struct {
    entries: [@as(usize, pool_capacity) * @as(usize, replay_specs_capacity)]RelayPoolReplayEntry = undefined,
};

pub const RelayPoolReplayPlan = struct {
    entries: []const RelayPoolReplayEntry = &.{},
    entry_count: u16 = 0,
    relay_count: u8 = 0,
    spec_count: u8 = 0,
    connect_count: u16 = 0,
    authenticate_count: u16 = 0,
    replay_count: u16 = 0,

    pub fn entry(self: *const RelayPoolReplayPlan, index: u16) ?RelayPoolReplayEntry {
        if (index >= self.entry_count) return null;
        return self.entries[index];
    }

    pub fn nextEntry(self: *const RelayPoolReplayPlan) ?RelayPoolReplayEntry {
        var index: u16 = 0;
        while (index < self.entry_count) : (index += 1) {
            const current = self.entries[index];
            if (current.action == .replay) return current;
        }
        return null;
    }

    pub fn nextStep(self: *const RelayPoolReplayPlan) ?RelayPoolReplayStep {
        const selected = self.nextEntry() orelse return null;
        return .{ .entry = selected };
    }
};

pub const RelayPoolReplayStep = struct {
    entry: RelayPoolReplayEntry,
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

pub const RelayPoolMemberRecord = struct {
    relay_url: [relay_url.relay_url_max_bytes]u8 = [_]u8{0} ** relay_url.relay_url_max_bytes,
    relay_url_len: u16 = 0,

    pub fn relayUrl(self: *const RelayPoolMemberRecord) []const u8 {
        std.debug.assert(self.relay_url_len <= relay_url.relay_url_max_bytes);
        return self.relay_url[0..self.relay_url_len];
    }
};

pub const RelayPoolMemberStorage = struct {
    records: [pool_capacity]RelayPoolMemberRecord = undefined,
};

pub const RelayPoolMemberSet = struct {
    records: []const RelayPoolMemberRecord = &.{},
    relay_count: u8 = 0,

    pub fn entry(self: *const RelayPoolMemberSet, index: u8) ?RelayPoolMemberRecord {
        if (index >= self.relay_count) return null;
        return self.records[index];
    }

    pub fn nextEntry(self: *const RelayPoolMemberSet) ?RelayPoolMemberRecord {
        if (self.relay_count == 0) return null;
        return self.records[0];
    }
};

pub const RelayPoolCheckpointSet = struct {
    records: []const RelayPoolCheckpointRecord = &.{},
    relay_count: u8 = 0,

    pub fn entry(self: *const RelayPoolCheckpointSet, index: u8) ?RelayPoolCheckpointRecord {
        if (index >= self.relay_count) return null;
        return self.records[index];
    }

    pub fn nextEntry(self: *const RelayPoolCheckpointSet) ?RelayPoolCheckpointRecord {
        if (self.relay_count == 0) return null;
        return self.records[0];
    }

    pub fn nextExportStep(self: *const RelayPoolCheckpointSet) ?RelayPoolCheckpointStep {
        const record = self.nextEntry() orelse return null;
        return .{
            .action = .export_checkpoint,
            .record = record,
        };
    }

    pub fn nextRestoreStep(self: *const RelayPoolCheckpointSet) ?RelayPoolCheckpointStep {
        const record = self.nextEntry() orelse return null;
        return .{
            .action = .restore_checkpoint,
            .record = record,
        };
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

    pub fn attach(storage: *RelayPoolStorage) RelayPool {
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

    pub fn inspectAuth(
        self: *const RelayPool,
        storage: *RelayPoolAuthStorage,
    ) RelayPoolAuthPlan {
        var connect_count: u8 = 0;
        var authenticate_count: u8 = 0;
        var ready_count: u8 = 0;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const action = classifyAuthAction(relay.state);
            const challenge = currentChallenge(relay);
            storage.entries[relay_index] = .{
                .descriptor = .{
                    .relay_index = relay_index,
                    .relay_url = relay.auth_session.relayUrl(),
                },
                .challenge = challenge,
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

    pub fn inspectSubscriptions(
        self: *const RelayPool,
        specs: []const RelaySubscriptionSpec,
        storage: *RelayPoolSubscriptionStorage,
    ) RelaySubscriptionError!RelayPoolSubscriptionPlan {
        if (specs.len > subscription_specs_capacity) return error.TooManySubscriptionSpecs;
        for (specs) |spec| {
            try validateSubscriptionSpec(&spec);
        }

        var connect_count: u16 = 0;
        var authenticate_count: u16 = 0;
        var subscribe_count: u16 = 0;
        var entry_index: u16 = 0;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const relay_descriptor: RelayDescriptor = .{
                .relay_index = relay_index,
                .relay_url = relay.auth_session.relayUrl(),
            };
            const action = classifySubscriptionAction(relay.state);

            for (specs, 0..) |spec, spec_index| {
                _ = spec_index;
                storage.entries[entry_index] = .{
                    .descriptor = relay_descriptor,
                    .subscription_id = spec.subscription_id,
                    .filters = spec.filters,
                    .action = action,
                };
                entry_index += 1;
                switch (action) {
                    .connect => connect_count += 1,
                    .authenticate => authenticate_count += 1,
                    .subscribe => subscribe_count += 1,
                }
            }
        }

        return .{
            .entries = storage.entries[0..entry_index],
            .entry_count = entry_index,
            .relay_count = self._storage.pool.count,
            .spec_count = @intCast(specs.len),
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .subscribe_count = subscribe_count,
        };
    }

    pub fn inspectReplay(
        self: *const RelayPool,
        checkpoint_store: client.ClientCheckpointStore,
        specs: []const RelayReplaySpec,
        storage: *RelayPoolReplayStorage,
    ) RelayReplayError!RelayPoolReplayPlan {
        if (specs.len > replay_specs_capacity) return error.TooManyReplaySpecs;

        var connect_count: u16 = 0;
        var authenticate_count: u16 = 0;
        var replay_count: u16 = 0;
        var entry_index: u16 = 0;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const relay_descriptor: RelayDescriptor = .{
                .relay_index = relay_index,
                .relay_url = relay.auth_session.relayUrl(),
            };
            const action = classifyReplayAction(relay.state);

            for (specs) |spec| {
                try validateReplaySpec(&spec);

                var checkpoint_name: [client.checkpoint_name_max_bytes]u8 = undefined;
                const name = try relay_checkpoint.checkpoint_name_for_relay(
                    spec.checkpoint_scope,
                    relay_descriptor.relay_url,
                    checkpoint_name[0..],
                );
                const checkpoint = try checkpoint_store.getCheckpoint(name);

                var query = spec.query;
                query.index_selection = .checkpoint_replay;
                query.cursor = if (checkpoint) |record| record.cursor else null;

                storage.entries[entry_index] = .{
                    .descriptor = relay_descriptor,
                    .checkpoint_scope = spec.checkpoint_scope,
                    .query = query,
                    .action = action,
                };
                entry_index += 1;

                switch (action) {
                    .connect => connect_count += 1,
                    .authenticate => authenticate_count += 1,
                    .replay => replay_count += 1,
                }
            }
        }

        return .{
            .entries = storage.entries[0..entry_index],
            .entry_count = entry_index,
            .relay_count = self._storage.pool.count,
            .spec_count = @intCast(specs.len),
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .replay_count = replay_count,
        };
    }

    pub fn inspectCounts(
        self: *const RelayPool,
        specs: []const RelayCountSpec,
        storage: *RelayPoolCountStorage,
    ) RelayCountError!RelayPoolCountPlan {
        if (specs.len > count_specs_capacity) return error.TooManyCountSpecs;
        for (specs) |spec| {
            try validateCountSpec(&spec);
        }

        var connect_count: u16 = 0;
        var authenticate_count: u16 = 0;
        var count_count: u16 = 0;
        var entry_index: u16 = 0;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const relay_descriptor: RelayDescriptor = .{
                .relay_index = relay_index,
                .relay_url = relay.auth_session.relayUrl(),
            };
            const action = classifyCountAction(relay.state);

            for (specs) |spec| {
                storage.entries[entry_index] = .{
                    .descriptor = relay_descriptor,
                    .subscription_id = spec.subscription_id,
                    .filters = spec.filters,
                    .action = action,
                };
                entry_index += 1;
                switch (action) {
                    .connect => connect_count += 1,
                    .authenticate => authenticate_count += 1,
                    .count => count_count += 1,
                }
            }
        }

        return .{
            .entries = storage.entries[0..entry_index],
            .entry_count = entry_index,
            .relay_count = self._storage.pool.count,
            .spec_count = @intCast(specs.len),
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .count_count = count_count,
        };
    }

    pub fn inspectPublish(
        self: *const RelayPool,
        storage: *RelayPoolPublishStorage,
    ) RelayPoolPublishPlan {
        var connect_count: u8 = 0;
        var authenticate_count: u8 = 0;
        var publish_count: u8 = 0;

        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const action = classifyPublishAction(relay.state);
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
                .publish => publish_count += 1,
            }
        }

        return .{
            .entries = storage.entries[0..self._storage.pool.count],
            .relay_count = self._storage.pool.count,
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .publish_count = publish_count,
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

    pub fn exportMembers(
        self: *const RelayPool,
        storage: *RelayPoolMemberStorage,
    ) RelayPoolMemberError!RelayPoolMemberSet {
        var relay_index: u8 = 0;
        while (relay_index < self._storage.pool.count) : (relay_index += 1) {
            const relay = self._storage.pool.getRelayConst(relay_index) orelse unreachable;
            const relay_url_text = relay.auth_session.relayUrl();
            if (relay_url_text.len > relay_url.relay_url_max_bytes) return error.RelayUrlTooLong;

            storage.records[relay_index] = .{
                .relay_url_len = @intCast(relay_url_text.len),
            };
            @memcpy(storage.records[relay_index].relay_url[0..relay_url_text.len], relay_url_text);
        }

        return .{
            .records = storage.records[0..self._storage.pool.count],
            .relay_count = self._storage.pool.count,
        };
    }

    pub fn restoreCheckpoints(
        self: *RelayPool,
        checkpoints: *const RelayPoolCheckpointSet,
    ) RelayPoolCheckpointError!void {
        if (self._storage.pool.count != 0) return error.PoolNotEmpty;

        var index: u8 = 0;
        while (index < checkpoints.relay_count) : (index += 1) {
            const record = checkpoints.entry(index) orelse unreachable;
            _ = try self.addRelay(record.relayUrl());
        }
    }

    pub fn restoreMembers(
        self: *RelayPool,
        members: *const RelayPoolMemberSet,
    ) RelayPoolMemberError!void {
        if (self._storage.pool.count != 0) return error.PoolNotEmpty;

        var index: u8 = 0;
        while (index < members.relay_count) : (index += 1) {
            const record = members.entry(index) orelse unreachable;
            _ = try self.addRelay(record.relayUrl());
        }
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

fn classifySubscriptionAction(state: session.SessionState) RelayPoolSubscriptionAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .subscribe,
    };
}

fn classifyAuthAction(state: session.SessionState) RelayPoolAuthAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .ready,
    };
}

fn classifyReplayAction(state: session.SessionState) RelayPoolReplayAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .replay,
    };
}

fn classifyCountAction(state: session.SessionState) RelayPoolCountAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .count,
    };
}

fn classifyPublishAction(state: session.SessionState) RelayPoolPublishAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .publish,
    };
}

fn currentChallenge(relay: *const session.RelaySession) []const u8 {
    const len = relay.auth_session.state.challenge_len;
    std.debug.assert(len <= noztr.nip42_auth.challenge_max_bytes);
    return relay.auth_session.state.challenge[0..len];
}

fn validateSubscriptionSpec(spec: *const RelaySubscriptionSpec) RelaySubscriptionError!void {
    if (spec.subscription_id.len == 0) return error.EmptySubscriptionId;
    if (spec.subscription_id.len > noztr.limits.subscription_id_bytes_max) {
        return error.SubscriptionIdTooLong;
    }
    if (spec.filters.len == 0) return error.EmptySubscriptionFilters;
    if (spec.filters.len > noztr.limits.message_filters_max) return error.TooManySubscriptionFilters;
}

fn validateCountSpec(spec: *const RelayCountSpec) RelayCountError!void {
    if (spec.subscription_id.len == 0) return error.EmptySubscriptionId;
    if (spec.subscription_id.len > noztr.limits.subscription_id_bytes_max) {
        return error.SubscriptionIdTooLong;
    }
    if (spec.filters.len == 0) return error.EmptyCountFilters;
    if (spec.filters.len > noztr.limits.message_filters_max) return error.TooManyCountFilters;
}

fn validateReplaySpec(spec: *const RelayReplaySpec) RelayReplayError!void {
    if (spec.query.limit == 0) return error.UnboundedReplayQuery;

    var name_buffer: [client.checkpoint_name_max_bytes]u8 = undefined;
    _ = try relay_checkpoint.checkpoint_name_for_relay(
        spec.checkpoint_scope,
        "wss://relay.validation",
        name_buffer[0..],
    );
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

test "relay pool inspects explicit auth posture and exposes the active challenge" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);

    var auth_storage = RelayPoolAuthStorage{};
    const plan = pool.inspectAuth(&auth_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 0), plan.connect_count);
    try std.testing.expectEqual(@as(u8, 1), plan.ready_count);
    try std.testing.expectEqual(RelayPoolAuthAction.authenticate, plan.entry(first.relay_index).?.action);
    try std.testing.expectEqualStrings("challenge-1", plan.entry(first.relay_index).?.challenge);
    try std.testing.expectEqual(RelayPoolAuthAction.ready, plan.entry(second.relay_index).?.action);
    try std.testing.expectEqualStrings("", plan.entry(second.relay_index).?.challenge);

    const step = plan.nextStep().?;
    try std.testing.expectEqual(first.relay_index, step.entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolAuthAction.authenticate, step.entry.action);
    try std.testing.expectEqualStrings("challenge-1", step.entry.challenge);
}

test "relay pool inspects explicit publish posture over current relay readiness" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    const third = try pool.addRelay("wss://relay.three");
    try pool.markRelayConnected(first.relay_index);
    try pool.markRelayConnected(second.relay_index);
    try pool.noteRelayAuthChallenge(second.relay_index, "challenge-1");

    var publish_storage = RelayPoolPublishStorage{};
    const plan = pool.inspectPublish(&publish_storage);
    try std.testing.expectEqual(@as(u8, 3), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.publish_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
    try std.testing.expectEqual(RelayPoolPublishAction.publish, plan.entry(first.relay_index).?.action);
    try std.testing.expectEqual(
        RelayPoolPublishAction.authenticate,
        plan.entry(second.relay_index).?.action,
    );
    try std.testing.expectEqual(RelayPoolPublishAction.connect, plan.entry(third.relay_index).?.action);
}

test "relay pool publish next-step selects the first ready relay only" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(second.relay_index);
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    var publish_storage = RelayPoolPublishStorage{};
    const plan = pool.inspectPublish(&publish_storage);
    const step = plan.nextStep().?;
    try std.testing.expectEqual(second.relay_index, step.entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolPublishAction.publish, step.entry.action);
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

test "relay pool restores relay membership from exported checkpoints" {
    var source_storage = RelayPoolStorage{};
    var source = RelayPool.init(&source_storage);
    _ = try source.addRelay("wss://relay.one");
    _ = try source.addRelay("wss://relay.two");

    const cursors = [_]client.EventCursor{
        .{ .offset = 7 },
        .{ .offset = 9 },
    };
    var checkpoint_storage = RelayPoolCheckpointStorage{};
    const checkpoints = try source.exportCheckpoints(cursors[0..], &checkpoint_storage);

    var restored_storage = RelayPoolStorage{};
    var restored = RelayPool.init(&restored_storage);
    try restored.restoreCheckpoints(&checkpoints);
    try std.testing.expectEqual(@as(u8, 2), restored.relayCount());
    try std.testing.expectEqualStrings("wss://relay.one", restored.descriptor(0).?.relay_url);
    try std.testing.expectEqualStrings("wss://relay.two", restored.descriptor(1).?.relay_url);

    var plan_storage = RelayPoolPlanStorage{};
    const plan = restored.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.connect_count);
}

test "relay pool exports bounded relay members in pool order" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");
    _ = try pool.addRelay("wss://relay.two");

    var member_storage = RelayPoolMemberStorage{};
    const members = try pool.exportMembers(&member_storage);
    try std.testing.expectEqual(@as(u8, 2), members.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", members.entry(0).?.relayUrl());
    try std.testing.expectEqualStrings("wss://relay.two", members.entry(1).?.relayUrl());
}

test "relay pool restores relay membership from exported members" {
    var source_storage = RelayPoolStorage{};
    var source = RelayPool.init(&source_storage);
    _ = try source.addRelay("wss://relay.one");
    _ = try source.addRelay("wss://relay.two");

    var member_storage = RelayPoolMemberStorage{};
    const members = try source.exportMembers(&member_storage);

    var restored_storage = RelayPoolStorage{};
    var restored = RelayPool.init(&restored_storage);
    try restored.restoreMembers(&members);
    try std.testing.expectEqual(@as(u8, 2), restored.relayCount());
    try std.testing.expectEqualStrings("wss://relay.one", restored.descriptor(0).?.relay_url);
    try std.testing.expectEqualStrings("wss://relay.two", restored.descriptor(1).?.relay_url);
}

test "relay pool restore rejects non-empty pools" {
    var source_storage = RelayPoolStorage{};
    var source = RelayPool.init(&source_storage);
    _ = try source.addRelay("wss://relay.one");

    const cursors = [_]client.EventCursor{.{ .offset = 7 }};
    var checkpoint_storage = RelayPoolCheckpointStorage{};
    const checkpoints = try source.exportCheckpoints(cursors[0..], &checkpoint_storage);

    var target_storage = RelayPoolStorage{};
    var target = RelayPool.init(&target_storage);
    _ = try target.addRelay("wss://relay.other");
    try std.testing.expectError(error.PoolNotEmpty, target.restoreCheckpoints(&checkpoints));
}

test "relay pool checkpoint set exposes typed export and restore steps" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");

    const cursors = [_]client.EventCursor{.{ .offset = 7 }};
    var checkpoint_storage = RelayPoolCheckpointStorage{};
    const checkpoints = try pool.exportCheckpoints(cursors[0..], &checkpoint_storage);

    const next_entry = checkpoints.nextEntry().?;
    try std.testing.expectEqualStrings("wss://relay.one", next_entry.relayUrl());

    const export_step = checkpoints.nextExportStep().?;
    try std.testing.expectEqual(RelayPoolCheckpointAction.export_checkpoint, export_step.action);
    try std.testing.expectEqualStrings("wss://relay.one", export_step.record.relayUrl());

    const restore_step = checkpoints.nextRestoreStep().?;
    try std.testing.expectEqual(RelayPoolCheckpointAction.restore_checkpoint, restore_step.action);
    try std.testing.expectEqualStrings("wss://relay.one", restore_step.record.relayUrl());
}

test "relay pool exposes bounded subscription vocabulary" {
    const filter = noztr.nip01_filter.Filter{ .kinds_count = 0 };
    const spec = RelaySubscriptionSpec{
        .subscription_id = "mailbox",
        .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
    };
    const storage = RelayPoolSubscriptionStorage{};

    try std.testing.expectEqualStrings("mailbox", spec.subscription_id);
    try std.testing.expectEqual(@as(usize, 1), spec.filters.len);
    try std.testing.expect(@TypeOf(storage) == RelayPoolSubscriptionStorage);
}

test "relay pool exposes bounded count vocabulary" {
    const filter = noztr.nip01_filter.Filter{};
    const spec = RelayCountSpec{
        .subscription_id = "count-feed",
        .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
    };

    try std.testing.expectEqualStrings("count-feed", spec.subscription_id);
    try std.testing.expectEqual(@as(usize, 1), spec.filters.len);
}

test "relay pool exposes bounded replay vocabulary" {
    const replay_spec = RelayReplaySpec{
        .checkpoint_scope = "relay-pool",
        .query = .{
            .limit = 16,
            .index_selection = .checkpoint_replay,
        },
    };
    const storage = RelayPoolReplayStorage{};

    try std.testing.expectEqualStrings("relay-pool", replay_spec.checkpoint_scope);
    try std.testing.expectEqual(@as(usize, 16), replay_spec.query.limit);
    try std.testing.expectEqual(client.IndexSelection.checkpoint_replay, replay_spec.query.index_selection);
    try std.testing.expect(@TypeOf(storage) == RelayPoolReplayStorage);
}

test "relay pool inspects subscription targets over bounded relay readiness" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    _ = try pool.addRelay("wss://relay.three");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);

    const filter = noztr.nip01_filter.Filter{
        .kinds = [_]u32{1} ++ ([_]u32{0} ** (noztr.limits.filter_kinds_max - 1)),
        .kinds_count = 1,
    };
    const specs = [_]RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var subscription_storage = RelayPoolSubscriptionStorage{};
    const plan = try pool.inspectSubscriptions(specs[0..], &subscription_storage);

    try std.testing.expectEqual(@as(u8, 3), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.spec_count);
    try std.testing.expectEqual(@as(u16, 3), plan.entry_count);
    try std.testing.expectEqual(@as(u16, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u16, 1), plan.subscribe_count);
    try std.testing.expectEqual(@as(u16, 1), plan.connect_count);
    try std.testing.expectEqual(RelayPoolSubscriptionAction.authenticate, plan.entry(0).?.action);
    try std.testing.expectEqualStrings("feed", plan.entry(1).?.subscription_id);
    try std.testing.expectEqual(RelayPoolSubscriptionAction.subscribe, plan.entry(1).?.action);
    try std.testing.expectEqualStrings("wss://relay.three", plan.entry(2).?.descriptor.relay_url);
}

test "relay pool inspects count targets over bounded relay readiness" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);

    const filter = noztr.nip01_filter.Filter{};
    const specs = [_]RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var count_storage = RelayPoolCountStorage{};
    const plan = try pool.inspectCounts(specs[0..], &count_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.spec_count);
    try std.testing.expectEqual(@as(u16, 1), plan.count_count);
    try std.testing.expectEqual(@as(u16, 1), plan.authenticate_count);
    try std.testing.expectEqualStrings("count-feed", plan.entry(1).?.subscription_id);
    try std.testing.expectEqual(RelayPoolCountAction.count, plan.entry(1).?.action);
}

test "relay pool inspects replay targets over bounded relay readiness and stored checkpoints" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_archive = relay_checkpoint.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    _ = try pool.addRelay("wss://relay.three");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);

    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.two", .{ .offset = 7 });

    const specs = [_]RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{
                .limit = 16,
                .index_selection = .author_time,
            },
        },
    };
    var replay_storage = RelayPoolReplayStorage{};
    const plan = try pool.inspectReplay(
        memory_store.asClientStore().checkpoint_store.?,
        specs[0..],
        &replay_storage,
    );

    try std.testing.expectEqual(@as(u8, 3), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.spec_count);
    try std.testing.expectEqual(@as(u16, 3), plan.entry_count);
    try std.testing.expectEqual(@as(u16, 1), plan.connect_count);
    try std.testing.expectEqual(@as(u16, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u16, 1), plan.replay_count);
    try std.testing.expectEqualStrings("mailbox", plan.entry(1).?.checkpoint_scope);
    try std.testing.expectEqual(client.IndexSelection.checkpoint_replay, plan.entry(1).?.query.index_selection);
    try std.testing.expectEqual(@as(u32, 7), plan.entry(1).?.query.cursor.?.offset);
    try std.testing.expect(plan.entry(2).?.query.cursor == null);
}

test "relay pool replay inspection rejects invalid specs" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");

    const invalid_specs = [_]RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{},
        },
    };
    var replay_storage = RelayPoolReplayStorage{};
    try std.testing.expectError(
        error.UnboundedReplayQuery,
        pool.inspectReplay(memory_store.asClientStore().checkpoint_store.?, invalid_specs[0..], &replay_storage),
    );
}

test "relay pool replay plan selects the next replay-ready entry" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_archive = relay_checkpoint.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.two", .{ .offset = 11 });

    const specs = [_]RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = RelayPoolReplayStorage{};
    const plan = try pool.inspectReplay(
        memory_store.asClientStore().checkpoint_store.?,
        specs[0..],
        &replay_storage,
    );
    const next_entry = plan.nextEntry().?;
    try std.testing.expectEqual(second.relay_index, next_entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolReplayAction.replay, next_entry.action);
    try std.testing.expectEqual(@as(u32, 11), next_entry.query.cursor.?.offset);
}

test "relay pool replay next-entry is null when no relay is replay-ready" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    _ = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    const specs = [_]RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = RelayPoolReplayStorage{};
    const plan = try pool.inspectReplay(
        memory_store.asClientStore().checkpoint_store.?,
        specs[0..],
        &replay_storage,
    );
    try std.testing.expect(plan.nextEntry() == null);
}

test "relay pool replay plan exposes a typed next replay step" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_archive = relay_checkpoint.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(second.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.two", .{ .offset = 13 });

    const specs = [_]RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = RelayPoolReplayStorage{};
    const plan = try pool.inspectReplay(
        memory_store.asClientStore().checkpoint_store.?,
        specs[0..],
        &replay_storage,
    );
    const next_step = plan.nextStep().?;
    try std.testing.expectEqual(second.relay_index, next_step.entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolReplayAction.replay, next_step.entry.action);
    try std.testing.expectEqual(@as(u32, 13), next_step.entry.query.cursor.?.offset);
}

test "relay pool subscription inspection rejects invalid specs" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");
    var subscription_storage = RelayPoolSubscriptionStorage{};
    const invalid_specs = [_]RelaySubscriptionSpec{
        .{ .subscription_id = "", .filters = (&[_]noztr.nip01_filter.Filter{.{}})[0..] },
    };
    try std.testing.expectError(
        error.EmptySubscriptionId,
        pool.inspectSubscriptions(invalid_specs[0..], &subscription_storage),
    );
}

test "relay pool count inspection rejects invalid specs" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);

    var count_storage = RelayPoolCountStorage{};
    const invalid_specs = [_]RelayCountSpec{
        .{ .subscription_id = "", .filters = (&[_]noztr.nip01_filter.Filter{.{}})[0..] },
    };
    try std.testing.expectError(
        error.EmptySubscriptionId,
        pool.inspectCounts(invalid_specs[0..], &count_storage),
    );
}

test "relay pool subscription plan selects the next subscribe-ready entry" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);

    const filter = noztr.nip01_filter.Filter{
        .kinds = [_]u32{1} ++ ([_]u32{0} ** (noztr.limits.filter_kinds_max - 1)),
        .kinds_count = 1,
    };
    const specs = [_]RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var subscription_storage = RelayPoolSubscriptionStorage{};
    const plan = try pool.inspectSubscriptions(specs[0..], &subscription_storage);
    const next_entry = plan.nextEntry().?;

    try std.testing.expectEqual(second.relay_index, next_entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolSubscriptionAction.subscribe, next_entry.action);
    try std.testing.expectEqualStrings("feed", next_entry.subscription_id);
}

test "relay pool subscription plan next-entry is null when no relay is subscribe-ready" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    const filter = noztr.nip01_filter.Filter{
        .kinds = [_]u32{1} ++ ([_]u32{0} ** (noztr.limits.filter_kinds_max - 1)),
        .kinds_count = 1,
    };
    const specs = [_]RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var subscription_storage = RelayPoolSubscriptionStorage{};
    const plan = try pool.inspectSubscriptions(specs[0..], &subscription_storage);
    try std.testing.expect(plan.nextEntry() == null);
}

test "relay pool count plan selects the next count-ready entry" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(second.relay_index);

    const filter = noztr.nip01_filter.Filter{};
    const specs = [_]RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var count_storage = RelayPoolCountStorage{};
    const plan = try pool.inspectCounts(specs[0..], &count_storage);
    const next_entry = plan.nextEntry().?;
    try std.testing.expectEqual(RelayPoolCountAction.count, next_entry.action);
    try std.testing.expectEqualStrings("count-feed", next_entry.subscription_id);
}

test "relay pool count plan next-entry is null when no relay is count-ready" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    _ = try pool.addRelay("wss://relay.one");

    const filter = noztr.nip01_filter.Filter{};
    const specs = [_]RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var count_storage = RelayPoolCountStorage{};
    const plan = try pool.inspectCounts(specs[0..], &count_storage);
    try std.testing.expect(plan.nextEntry() == null);
}

test "relay pool count plan exposes a typed next count step" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const relay = try pool.addRelay("wss://relay.one");
    try pool.markRelayConnected(relay.relay_index);

    const filter = noztr.nip01_filter.Filter{};
    const specs = [_]RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var count_storage = RelayPoolCountStorage{};
    const plan = try pool.inspectCounts(specs[0..], &count_storage);
    const next_step = plan.nextStep().?;
    try std.testing.expectEqual(RelayPoolCountAction.count, next_step.entry.action);
    try std.testing.expectEqualStrings("count-feed", next_step.entry.subscription_id);
}

test "relay pool subscription plan exposes a typed next subscribe step" {
    var storage = RelayPoolStorage{};
    var pool = RelayPool.init(&storage);
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.two");
    try pool.markRelayConnected(first.relay_index);
    try pool.noteRelayAuthChallenge(first.relay_index, "challenge-1");
    try pool.markRelayConnected(second.relay_index);

    const filter = noztr.nip01_filter.Filter{
        .kinds = [_]u32{1} ++ ([_]u32{0} ** (noztr.limits.filter_kinds_max - 1)),
        .kinds_count = 1,
    };
    const specs = [_]RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var subscription_storage = RelayPoolSubscriptionStorage{};
    const plan = try pool.inspectSubscriptions(specs[0..], &subscription_storage);
    const next_step = plan.nextStep().?;

    try std.testing.expectEqual(second.relay_index, next_step.entry.descriptor.relay_index);
    try std.testing.expectEqual(RelayPoolSubscriptionAction.subscribe, next_step.entry.action);
    try std.testing.expectEqualStrings("feed", next_step.entry.subscription_id);
}
