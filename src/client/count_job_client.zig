const std = @import("std");
const auth_count_turn = @import("auth_count_turn_client.zig");
const count_turn = @import("count_turn_client.zig");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const runtime = @import("../runtime/mod.zig");

pub const CountJobClientError = auth_count_turn.AuthCountTurnClientError;

pub const CountJobClientConfig = struct {
    auth_count_turn: auth_count_turn.AuthCountTurnClientConfig = .{},
};

pub const CountJobClientStorage = struct {
    auth_count_turn: auth_count_turn.AuthCountTurnClientStorage = .{},
};

pub const CountJobAuthEventStorage = auth_count_turn.AuthCountEventStorage;
pub const PreparedCountJobAuthEvent = auth_count_turn.PreparedAuthCountEvent;
pub const CountJobRequest = count_turn.CountTurnRequest;

pub const CountJobReady = union(enum) {
    authenticate: PreparedCountJobAuthEvent,
    count: CountJobRequest,
};

pub const CountJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    counted: count_turn.CountTurnResult,
};

pub const CountJobClient = struct {
    config: CountJobClientConfig,
    auth_count_turn: auth_count_turn.AuthCountTurnClient,

    pub fn init(
        config: CountJobClientConfig,
        storage: *CountJobClientStorage,
    ) CountJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .auth_count_turn = auth_count_turn.AuthCountTurnClient.attach(
                config.auth_count_turn,
                &storage.auth_count_turn,
            ),
        };
    }

    pub fn attach(
        config: CountJobClientConfig,
        storage: *CountJobClientStorage,
    ) CountJobClient {
        return .{
            .config = config,
            .auth_count_turn = auth_count_turn.AuthCountTurnClient.attach(
                config.auth_count_turn,
                &storage.auth_count_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *CountJobClient,
        relay_url_text: []const u8,
    ) CountJobClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "auth_count_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *CountJobClient,
        relay_index: u8,
    ) CountJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "auth_count_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *CountJobClient,
        relay_index: u8,
    ) CountJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "auth_count_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *CountJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) CountJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "auth_count_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const CountJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "auth_count_turn", storage);
    }

    pub fn prepareJob(
        self: *const CountJobClient,
        auth_storage: *CountJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        specs: []const runtime.RelayCountSpec,
        created_at: u64,
    ) CountJobClientError!CountJobReady {
        var auth_plan_storage = runtime.RelayPoolAuthStorage{};
        var count_plan_storage = runtime.RelayPoolCountStorage{};
        const next = try self.auth_count_turn.nextStep(
            &auth_plan_storage,
            specs,
            &count_plan_storage,
        ) orelse return error.NoReadyRelay;

        return switch (next) {
            .authenticate => .{
                .authenticate = try self.auth_count_turn.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &next.authenticate,
                    secret_key,
                    created_at,
                ),
            },
            .count => .{
                .count = try self.auth_count_turn.beginCountTurn(request_output, specs),
            },
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *CountJobClient,
        prepared: *const PreparedCountJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) CountJobClientError!CountJobResult {
        const result = try self.auth_count_turn.acceptPreparedAuthEvent(
            prepared,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = result.authenticated };
    }

    pub fn acceptCountMessageJson(
        self: *const CountJobClient,
        request: *const CountJobRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) CountJobClientError!CountJobResult {
        const result = try self.auth_count_turn.acceptCountMessageJson(
            request,
            relay_message_json,
            scratch,
        );
        return .{ .counted = result.counted };
    }
};

test "count job client exposes caller-owned config and storage" {
    var storage = CountJobClientStorage{};
    var client = CountJobClient.init(.{}, &storage);

    try std.testing.expectEqual(
        @as(u8, 0),
        client.auth_count_turn.count_turn.relay_exchange.relay_pool.relayCount(),
    );
}

test "count job client drives auth-gated count work through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = CountJobClientStorage{};
    var client = CountJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    const secret_key = [_]u8{0x71} ** 32;
    var auth_storage = CountJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(second_ready == .count);
    try std.testing.expectEqual(relay.relay_index, second_ready.count.count.relay.relay_index);

    var reply_output: [128]u8 = undefined;
    const count_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 7 } },
    );
    const result = try client.acceptCountMessageJson(
        &second_ready.count,
        count_json,
        arena.allocator(),
    );
    try std.testing.expect(result == .counted);
    try std.testing.expectEqual(@as(u64, 7), result.counted.count);
}

test "count job client rejects stale auth posture explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = CountJobClientStorage{};
    var client = CountJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    const secret_key = [_]u8{0x72} ** 32;
    var auth_storage = CountJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(ready == .authenticate);

    try client.noteRelayDisconnected(relay.relay_index);
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-2");
    try std.testing.expectError(
        error.StaleAuthStep,
        client.acceptPreparedAuthEvent(&ready.authenticate, 95, 60),
    );
}
