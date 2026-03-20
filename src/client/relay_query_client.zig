const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const RelayQueryClientError =
    runtime.RelayPoolError ||
    runtime.RelaySubscriptionError ||
    runtime.RelayCountError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleQueryStep,
        RelayNotReady,
    };

pub const RelayQueryClientConfig = struct {};

pub const RelayQueryClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const RelayQueryTarget = struct {
    relay: runtime.RelayDescriptor,
};

pub const TargetedSubscriptionRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const TargetedCountRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const TargetedCloseRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const RelayQueryClient = struct {
    config: RelayQueryClientConfig,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: RelayQueryClientConfig,
        storage: *RelayQueryClientStorage,
    ) RelayQueryClient {
        storage.* = .{};
        return .{
            .config = config,
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: RelayQueryClientConfig,
        storage: *RelayQueryClientStorage,
    ) RelayQueryClient {
        return .{
            .config = config,
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *RelayQueryClient,
        relay_url_text: []const u8,
    ) RelayQueryClientError!runtime.RelayDescriptor {
        return self.relay_pool.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *RelayQueryClient,
        relay_index: u8,
    ) RelayQueryClientError!void {
        return self.relay_pool.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayQueryClient,
        relay_index: u8,
    ) RelayQueryClientError!void {
        return self.relay_pool.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayQueryClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayQueryClientError!void {
        return self.relay_pool.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const RelayQueryClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_pool.inspectRuntime(storage);
    }

    pub fn inspectSubscriptions(
        self: *const RelayQueryClient,
        specs: []const runtime.RelaySubscriptionSpec,
        storage: *runtime.RelayPoolSubscriptionStorage,
    ) RelayQueryClientError!runtime.RelayPoolSubscriptionPlan {
        return self.relay_pool.inspectSubscriptions(specs, storage);
    }

    pub fn inspectCounts(
        self: *const RelayQueryClient,
        specs: []const runtime.RelayCountSpec,
        storage: *runtime.RelayPoolCountStorage,
    ) RelayQueryClientError!runtime.RelayPoolCountPlan {
        return self.relay_pool.inspectCounts(specs, storage);
    }

    pub fn selectSubscriptionTarget(
        self: *const RelayQueryClient,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) RelayQueryClientError!RelayQueryTarget {
        try self.requireReadyRelay(&step.entry.descriptor);
        return .{ .relay = step.entry.descriptor };
    }

    pub fn selectCountTarget(
        self: *const RelayQueryClient,
        step: *const runtime.RelayPoolCountStep,
    ) RelayQueryClientError!RelayQueryTarget {
        try self.requireReadyRelay(&step.entry.descriptor);
        return .{ .relay = step.entry.descriptor };
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const RelayQueryClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) RelayQueryClientError!TargetedSubscriptionRequest {
        const target = try self.selectSubscriptionTarget(step);
        const request_json = try serializeRequestLike(
            output,
            .{
                .subscription_id = step.entry.subscription_id,
                .filters = step.entry.filters,
            },
            .req,
        );
        return .{
            .relay = target.relay,
            .subscription_id = step.entry.subscription_id,
            .request_json = request_json,
        };
    }

    pub fn composeTargetedCountRequest(
        self: *const RelayQueryClient,
        output: []u8,
        step: *const runtime.RelayPoolCountStep,
    ) RelayQueryClientError!TargetedCountRequest {
        const target = try self.selectCountTarget(step);
        const request_json = try serializeRequestLike(
            output,
            .{
                .subscription_id = step.entry.subscription_id,
                .filters = step.entry.filters,
            },
            .count,
        );
        return .{
            .relay = target.relay,
            .subscription_id = step.entry.subscription_id,
            .request_json = request_json,
        };
    }

    pub fn composeTargetedCloseRequest(
        self: *const RelayQueryClient,
        output: []u8,
        target: *const RelayQueryTarget,
        subscription_id: []const u8,
    ) RelayQueryClientError!TargetedCloseRequest {
        try self.requireReadyRelay(&target.relay);

        const message = noztr.nip01_message.ClientMessage{
            .close = .{
                .subscription_id = subscription_id,
            },
        };
        const request_json = try noztr.nip01_message.client_message_serialize_json(output, &message);
        return .{
            .relay = target.relay,
            .subscription_id = subscription_id,
            .request_json = request_json,
        };
    }

    fn requireReadyRelay(
        self: *const RelayQueryClient,
        descriptor: *const runtime.RelayDescriptor,
    ) RelayQueryClientError!void {
        const live_descriptor = self.relay_pool.descriptor(descriptor.relay_index) orelse {
            return error.StaleQueryStep;
        };
        if (!std.mem.eql(u8, live_descriptor.relay_url, descriptor.relay_url)) {
            return error.StaleQueryStep;
        }

        var storage = runtime.RelayPoolPlanStorage{};
        const plan = self.inspectRelayRuntime(&storage);
        const current = plan.entry(descriptor.relay_index) orelse return error.StaleQueryStep;
        if (!std.mem.eql(u8, current.descriptor.relay_url, descriptor.relay_url)) {
            return error.StaleQueryStep;
        }
        if (current.action != .ready) return error.RelayNotReady;
    }
};

const RequestLike = struct {
    subscription_id: []const u8,
    filters: []const noztr.nip01_filter.Filter,
};

const RequestKind = enum {
    req,
    count,
};

fn serializeRequestLike(
    output: []u8,
    request: RequestLike,
    kind: RequestKind,
) RelayQueryClientError![]const u8 {
    var filters: [noztr.limits.message_filters_max]noztr.nip01_filter.Filter =
        [_]noztr.nip01_filter.Filter{.{}} ** noztr.limits.message_filters_max;
    for (request.filters, 0..) |filter, index| {
        filters[index] = filter;
    }

    const filter_count: u8 = @intCast(request.filters.len);
    const message: noztr.nip01_message.ClientMessage = switch (kind) {
        .req => .{
            .req = .{
                .subscription_id = request.subscription_id,
                .filters = filters,
                .filters_count = filter_count,
            },
        },
        .count => .{
            .count = .{
                .subscription_id = request.subscription_id,
                .filters = filters,
                .filters_count = filter_count,
            },
        },
    };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

test "relay query client exposes caller-owned config and relay-pool storage" {
    var storage = RelayQueryClientStorage{};
    const client = RelayQueryClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "relay query client composes one targeted req count and close payload" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelayQueryClientStorage{};
    var client = RelayQueryClient.init(.{}, &storage);
    const first = try client.addRelay("wss://relay.one");
    const second = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(first.relay_index);
    try client.markRelayConnected(second.relay_index);
    try client.noteRelayAuthChallenge(second.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );

    const subscription_specs = [_]runtime.RelaySubscriptionSpec{
        .{
            .subscription_id = "feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var subscription_storage = runtime.RelayPoolSubscriptionStorage{};
    const subscription_plan = try client.inspectSubscriptions(
        subscription_specs[0..],
        &subscription_storage,
    );
    const subscription_step = subscription_plan.nextStep().?;

    var request_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_req = try client.composeTargetedSubscriptionRequest(
        request_buffer[0..],
        &subscription_step,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_req.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted_req.request_json, "[\"REQ\","));

    const count_specs = [_]runtime.RelayCountSpec{
        .{
            .subscription_id = "count-feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var count_storage = runtime.RelayPoolCountStorage{};
    const count_plan = try client.inspectCounts(count_specs[0..], &count_storage);
    const count_step = count_plan.nextStep().?;
    const targeted_count = try client.composeTargetedCountRequest(
        request_buffer[0..],
        &count_step,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_count.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted_count.request_json, "[\"COUNT\","));

    const target = try client.selectSubscriptionTarget(&subscription_step);
    const targeted_close = try client.composeTargetedCloseRequest(
        request_buffer[0..],
        &target,
        "feed",
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_close.relay.relay_url);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", targeted_close.request_json);
}

test "relay query client rejects stale or no-longer-ready query steps" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelayQueryClientStorage{};
    var client = RelayQueryClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{
            .subscription_id = "feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var subscription_storage = runtime.RelayPoolSubscriptionStorage{};
    const plan = try client.inspectSubscriptions(specs[0..], &subscription_storage);
    const step = plan.nextStep().?;

    try client.noteRelayDisconnected(relay.relay_index);
    try std.testing.expectError(error.RelayNotReady, client.selectSubscriptionTarget(&step));

    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try std.testing.expectError(error.RelayNotReady, client.selectSubscriptionTarget(&step));
}
