const std = @import("std");
const store = @import("../store/mod.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const RelayReplayClientError =
    store.ClientStoreError ||
    runtime.RelayPoolError ||
    runtime.RelayReplayError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleReplayStep,
        RelayNotReady,
        QueryLimitTooLarge,
        TooManyEventIds,
        TooManyAuthors,
        TooManyKinds,
    };

pub const RelayReplayClientConfig = struct {};

pub const RelayReplayClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const RelayReplayTarget = struct {
    relay: runtime.RelayDescriptor,
    checkpoint_scope: []const u8,
    query: store.ClientQuery,
};

pub const TargetedReplayRequest = struct {
    relay: runtime.RelayDescriptor,
    checkpoint_scope: []const u8,
    subscription_id: []const u8,
    query: store.ClientQuery,
    request_json: []const u8,
};

pub const RelayReplayClient = struct {
    config: RelayReplayClientConfig,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: RelayReplayClientConfig,
        storage: *RelayReplayClientStorage,
    ) RelayReplayClient {
        storage.* = .{};
        return .{
            .config = config,
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: RelayReplayClientConfig,
        storage: *RelayReplayClientStorage,
    ) RelayReplayClient {
        return .{
            .config = config,
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *RelayReplayClient,
        relay_url_text: []const u8,
    ) RelayReplayClientError!runtime.RelayDescriptor {
        return self.relay_pool.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *RelayReplayClient,
        relay_index: u8,
    ) RelayReplayClientError!void {
        return self.relay_pool.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayReplayClient,
        relay_index: u8,
    ) RelayReplayClientError!void {
        return self.relay_pool.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayReplayClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayReplayClientError!void {
        return self.relay_pool.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const RelayReplayClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_pool.inspectRuntime(storage);
    }

    pub fn inspectReplay(
        self: *const RelayReplayClient,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) RelayReplayClientError!runtime.RelayPoolReplayPlan {
        return self.relay_pool.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn selectReplayTarget(
        self: *const RelayReplayClient,
        step: *const runtime.RelayPoolReplayStep,
    ) RelayReplayClientError!RelayReplayTarget {
        try self.requireReplayRelay(&step.entry.descriptor);
        return .{
            .relay = step.entry.descriptor,
            .checkpoint_scope = step.entry.checkpoint_scope,
            .query = step.entry.query,
        };
    }

    pub fn composeTargetedReplayRequest(
        self: *const RelayReplayClient,
        output: []u8,
        step: *const runtime.RelayPoolReplayStep,
        subscription_id: []const u8,
    ) RelayReplayClientError!TargetedReplayRequest {
        const target = try self.selectReplayTarget(step);
        const request_json = try serializeReplayRequest(output, subscription_id, &target.query);
        return .{
            .relay = target.relay,
            .checkpoint_scope = target.checkpoint_scope,
            .subscription_id = subscription_id,
            .query = target.query,
            .request_json = request_json,
        };
    }

    fn requireReplayRelay(
        self: *const RelayReplayClient,
        descriptor: *const runtime.RelayDescriptor,
    ) RelayReplayClientError!void {
        const live_descriptor = self.relay_pool.descriptor(descriptor.relay_index) orelse {
            return error.StaleReplayStep;
        };
        if (!std.mem.eql(u8, live_descriptor.relay_url, descriptor.relay_url)) {
            return error.StaleReplayStep;
        }

        var runtime_storage = runtime.RelayPoolPlanStorage{};
        const runtime_plan = self.inspectRelayRuntime(&runtime_storage);
        const current = runtime_plan.entry(descriptor.relay_index) orelse return error.StaleReplayStep;
        if (!std.mem.eql(u8, current.descriptor.relay_url, descriptor.relay_url)) {
            return error.StaleReplayStep;
        }
        if (current.action != .ready) return error.RelayNotReady;
    }
};

fn serializeReplayRequest(
    output: []u8,
    subscription_id: []const u8,
    query: *const store.ClientQuery,
) RelayReplayClientError![]const u8 {
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

fn filterFromClientQuery(query: *const store.ClientQuery) RelayReplayClientError!noztr.nip01_filter.Filter {
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

test "relay replay client exposes caller-owned config and relay-pool storage" {
    var storage = RelayReplayClientStorage{};
    const client = RelayReplayClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "relay replay client composes one targeted replay req from checkpoint-backed query state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayReplayClientStorage{};
    var client = RelayReplayClient.init(.{}, &storage);
    const first = try client.addRelay("wss://relay.one");
    const second = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(first.relay_index);
    try client.markRelayConnected(second.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", "wss://relay.two", .{ .offset = 9 });

    const authors = [_]store.EventPubkeyHex{
        try store.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{
                .authors = authors[0..],
                .kinds = (&[_]u32{1})[0..],
                .since = 10,
                .limit = 16,
            },
        },
    };
    var replay_storage = runtime.RelayPoolReplayStorage{};
    const plan = try client.inspectReplay(checkpoint_store, replay_specs[0..], &replay_storage);
    const step = plan.nextStep().?;

    var request_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted = try client.composeTargetedReplayRequest(
        request_buffer[0..],
        &step,
        "replay-feed",
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted.relay.relay_url);
    try std.testing.expectEqualStrings("tooling", targeted.checkpoint_scope);
    try std.testing.expectEqual(store.IndexSelection.checkpoint_replay, targeted.query.index_selection);

    const parsed = try noztr.nip01_message.client_message_parse_json(
        targeted.request_json,
        arena.allocator(),
    );
    try std.testing.expect(parsed == .req);
    try std.testing.expectEqualStrings("replay-feed", parsed.req.subscription_id);
    try std.testing.expectEqual(@as(u8, 1), parsed.req.filters_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.req.filters[0].authors_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.req.filters[0].kinds_count);
    try std.testing.expectEqual(@as(u64, 10), parsed.req.filters[0].since.?);
    try std.testing.expectEqual(@as(u16, 16), parsed.req.filters[0].limit.?);
}

test "relay replay client rejects stale or no-longer-ready replay steps" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    var storage = RelayReplayClientStorage{};
    var client = RelayReplayClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = runtime.RelayPoolReplayStorage{};
    const plan = try client.inspectReplay(checkpoint_store, replay_specs[0..], &replay_storage);
    const step = plan.nextStep().?;

    try client.noteRelayDisconnected(relay.relay_index);
    try std.testing.expectError(error.RelayNotReady, client.selectReplayTarget(&step));

    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try std.testing.expectError(error.RelayNotReady, client.selectReplayTarget(&step));
}
