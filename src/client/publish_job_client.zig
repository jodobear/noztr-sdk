const std = @import("std");
const auth_publish_turn = @import("auth_publish_turn_client.zig");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const publish_turn = @import("publish_turn_client.zig");
const runtime = @import("../runtime/mod.zig");

pub const PublishJobClientError = auth_publish_turn.AuthPublishTurnClientError;

pub const PublishJobClientConfig = struct {
    auth_publish_turn: auth_publish_turn.AuthPublishTurnClientConfig = .{},
};

pub const PublishJobClientStorage = struct {
    auth_publish_turn: auth_publish_turn.AuthPublishTurnClientStorage = .{},
};

pub const PublishJobAuthEventStorage = auth_publish_turn.AuthPublishEventStorage;
pub const PreparedPublishJobAuthEvent = auth_publish_turn.PreparedAuthPublishEvent;
pub const PublishJobRequest = publish_turn.PublishTurnRequest;

pub const PublishJobReady = union(enum) {
    authenticate: PreparedPublishJobAuthEvent,
    publish: PublishJobRequest,
};

pub const PublishJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    published: publish_turn.PublishTurnResult,
};

pub const PublishJobClient = struct {
    config: PublishJobClientConfig,
    auth_publish_turn: auth_publish_turn.AuthPublishTurnClient,

    pub fn init(
        config: PublishJobClientConfig,
        storage: *PublishJobClientStorage,
    ) PublishJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .auth_publish_turn = auth_publish_turn.AuthPublishTurnClient.attach(
                config.auth_publish_turn,
                &storage.auth_publish_turn,
            ),
        };
    }

    pub fn attach(
        config: PublishJobClientConfig,
        storage: *PublishJobClientStorage,
    ) PublishJobClient {
        return .{
            .config = config,
            .auth_publish_turn = auth_publish_turn.AuthPublishTurnClient.attach(
                config.auth_publish_turn,
                &storage.auth_publish_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *PublishJobClient,
        relay_url_text: []const u8,
    ) PublishJobClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "auth_publish_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *PublishJobClient,
        relay_index: u8,
    ) PublishJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "auth_publish_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *PublishJobClient,
        relay_index: u8,
    ) PublishJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "auth_publish_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *PublishJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) PublishJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "auth_publish_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const PublishJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "auth_publish_turn", storage);
    }

    pub fn prepareJob(
        self: *const PublishJobClient,
        auth_storage: *PublishJobAuthEventStorage,
        event_json_output: []u8,
        message_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const local_operator.LocalEventDraft,
        created_at: u64,
    ) PublishJobClientError!PublishJobReady {
        var auth_plan_storage = runtime.RelayPoolAuthStorage{};
        var publish_plan_storage = runtime.RelayPoolPublishStorage{};
        const next = self.auth_publish_turn.nextStep(&auth_plan_storage, &publish_plan_storage) orelse {
            return error.NoAuthOrPublishStep;
        };

        return switch (next) {
            .authenticate => .{
                .authenticate = try self.auth_publish_turn.prepareAuthEvent(
                    auth_storage,
                    event_json_output,
                    message_output,
                    &next.authenticate,
                    secret_key,
                    created_at,
                ),
            },
            .publish => .{
                .publish = try self.auth_publish_turn.beginPublishTurn(
                    event_json_output,
                    message_output,
                    secret_key,
                    draft,
                ),
            },
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *PublishJobClient,
        prepared: *const PreparedPublishJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) PublishJobClientError!PublishJobResult {
        const result = try self.auth_publish_turn.acceptPreparedAuthEvent(
            prepared,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = result.authenticated };
    }

    pub fn acceptPublishOkJson(
        self: *const PublishJobClient,
        request: *const PublishJobRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) PublishJobClientError!PublishJobResult {
        const result = try self.auth_publish_turn.acceptPublishOkJson(
            request,
            relay_message_json,
            scratch,
        );
        return .{ .published = result.published };
    }
};

test "publish job client exposes caller-owned config and storage" {
    var storage = PublishJobClientStorage{};
    var client = PublishJobClient.init(.{}, &storage);

    try std.testing.expectEqual(
        @as(u8, 0),
        client.auth_publish_turn.publish_turn.relay_pool.relayCount(),
    );
}

test "publish job client prepares ready publish work without auth gating" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = PublishJobClientStorage{};
    var client = PublishJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x61} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 91,
        .content = "publish job ready path",
    };
    var auth_storage = PublishJobAuthEventStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
        &auth_storage,
        event_json_output[0..],
        message_output[0..],
        &secret_key,
        &draft,
        90,
    );
    try std.testing.expect(ready == .publish);

    var reply_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .ok = .{ .event_id = ready.publish.event.id, .accepted = true, .status = "" } },
    );
    const result = try client.acceptPublishOkJson(&ready.publish, ok_json, arena.allocator());
    try std.testing.expect(result == .published);
    try std.testing.expect(result.published.accepted);
}

test "publish job client drives auth-gated publish progression through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = PublishJobClientStorage{};
    var client = PublishJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const secret_key = [_]u8{0x62} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 93,
        .content = "auth publish job path",
    };
    var auth_storage = PublishJobAuthEventStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        event_json_output[0..],
        message_output[0..],
        &secret_key,
        &draft,
        92,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        event_json_output[0..],
        message_output[0..],
        &secret_key,
        &draft,
        92,
    );
    try std.testing.expect(second_ready == .publish);

    var reply_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .ok = .{ .event_id = second_ready.publish.event.id, .accepted = true, .status = "" } },
    );
    const publish_result = try client.acceptPublishOkJson(
        &second_ready.publish,
        ok_json,
        arena.allocator(),
    );
    try std.testing.expect(publish_result == .published);
    try std.testing.expect(publish_result.published.accepted);
}

test "publish job client rejects stale auth acceptance explicitly" {
    const noztr = @import("noztr");
    var storage = PublishJobClientStorage{};
    var client = PublishJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const secret_key = [_]u8{0x63} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 95,
        .content = "stale auth publish job",
    };
    var auth_storage = PublishJobAuthEventStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
        &auth_storage,
        event_json_output[0..],
        message_output[0..],
        &secret_key,
        &draft,
        94,
    );
    try std.testing.expect(ready == .authenticate);

    try client.noteRelayDisconnected(relay.relay_index);
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-2");
    try std.testing.expectError(
        error.StaleAuthStep,
        client.acceptPreparedAuthEvent(&ready.authenticate, 96, 60),
    );
}
