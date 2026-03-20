const std = @import("std");
const relay_exchange = @import("relay_exchange_client.zig");
const runtime = @import("../runtime/mod.zig");

pub const CountTurnClientError = relay_exchange.RelayExchangeClientError;

pub const CountTurnClientConfig = struct {
    relay_exchange: relay_exchange.RelayExchangeClientConfig = .{},
};

pub const CountTurnClientStorage = struct {
    relay_exchange: relay_exchange.RelayExchangeClientStorage = .{},
};

pub const CountTurnRequest = struct {
    count: relay_exchange.CountExchangeRequest,
};

pub const CountTurnResult = struct {
    request: relay_exchange.CountExchangeRequest,
    count: u64,
};

pub const CountTurnClient = struct {
    config: CountTurnClientConfig,
    relay_exchange: relay_exchange.RelayExchangeClient,

    pub fn init(
        config: CountTurnClientConfig,
        storage: *CountTurnClientStorage,
    ) CountTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .relay_exchange = relay_exchange.RelayExchangeClient.init(
                config.relay_exchange,
                &storage.relay_exchange,
            ),
        };
    }

    pub fn attach(
        config: CountTurnClientConfig,
        storage: *CountTurnClientStorage,
    ) CountTurnClient {
        return .{
            .config = config,
            .relay_exchange = relay_exchange.RelayExchangeClient.attach(
                config.relay_exchange,
                &storage.relay_exchange,
            ),
        };
    }

    pub fn addRelay(
        self: *CountTurnClient,
        relay_url_text: []const u8,
    ) CountTurnClientError!runtime.RelayDescriptor {
        return self.relay_exchange.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *CountTurnClient,
        relay_index: u8,
    ) CountTurnClientError!void {
        return self.relay_exchange.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *CountTurnClient,
        relay_index: u8,
    ) CountTurnClientError!void {
        return self.relay_exchange.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *CountTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) CountTurnClientError!void {
        return self.relay_exchange.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const CountTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_exchange.inspectRelayRuntime(storage);
    }

    pub fn beginTurn(
        self: *const CountTurnClient,
        output: []u8,
        specs: []const runtime.RelayCountSpec,
    ) CountTurnClientError!CountTurnRequest {
        return .{ .count = try self.relay_exchange.beginCount(output, specs) };
    }

    pub fn acceptCountMessageJson(
        self: *const CountTurnClient,
        request: *const CountTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) CountTurnClientError!CountTurnResult {
        const count = try self.relay_exchange.acceptCountMessageJson(
            &request.count,
            relay_message_json,
            scratch,
        );
        return .{
            .request = request.count,
            .count = count.count,
        };
    }
};

test "count turn client exposes caller-owned config and storage" {
    var storage = CountTurnClientStorage{};
    var client = CountTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_exchange.relay_pool.relayCount());
}

test "count turn client composes one bounded count turn and preserves zero counts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = CountTurnClientStorage{};
    var client = CountTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);
    try std.testing.expectEqualStrings("wss://relay.one", request.count.relay.relay_url);

    var reply_output: [128]u8 = undefined;
    const count_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 0 } },
    );
    const result = try client.acceptCountMessageJson(&request, count_json, arena.allocator());
    try std.testing.expectEqual(@as(u64, 0), result.count);
}

test "count turn client rejects wrong subscription replies and no-ready relay posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = CountTurnClientStorage{};
    var client = CountTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);

    var reply_output: [128]u8 = undefined;
    const wrong_count_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .count = .{ .subscription_id = "other-feed", .count = 42 } },
    );
    try std.testing.expectError(
        error.UnexpectedSubscriptionId,
        client.acceptCountMessageJson(&request, wrong_count_json, arena.allocator()),
    );

    try client.noteRelayDisconnected(ready.relay_index);
    try std.testing.expectError(
        error.NoReadyRelay,
        client.beginTurn(request_output[0..], specs[0..]),
    );
}
