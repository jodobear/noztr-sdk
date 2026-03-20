const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_response = @import("relay_response_client.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const PublishTurnClientError =
    local_operator.LocalOperatorClientError ||
    relay_response.RelayResponseClientError ||
    runtime.RelayPoolError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoReadyRelay,
    };

pub const PublishTurnClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    relay_response: relay_response.RelayResponseClientConfig = .{},
};

pub const PublishTurnClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const PublishTurnRequest = struct {
    relay: runtime.RelayDescriptor,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    event_message_json: []const u8,
};

pub const PublishTurnResult = struct {
    request: PublishTurnRequest,
    event_id: [32]u8,
    accepted: bool,
    status: []const u8,
};

pub const PublishTurnClient = struct {
    config: PublishTurnClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    relay_response: relay_response.RelayResponseClient,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: PublishTurnClientConfig,
        storage: *PublishTurnClientStorage,
    ) PublishTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: PublishTurnClientConfig,
        storage: *PublishTurnClientStorage,
    ) PublishTurnClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *PublishTurnClient,
        relay_url_text: []const u8,
    ) PublishTurnClientError!runtime.RelayDescriptor {
        return self.relay_pool.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *PublishTurnClient,
        relay_index: u8,
    ) PublishTurnClientError!void {
        return self.relay_pool.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *PublishTurnClient,
        relay_index: u8,
    ) PublishTurnClientError!void {
        return self.relay_pool.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *PublishTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) PublishTurnClientError!void {
        return self.relay_pool.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const PublishTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_pool.inspectRuntime(storage);
    }

    pub fn inspectPublish(
        self: *const PublishTurnClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.relay_pool.inspectPublish(storage);
    }

    pub fn beginTurn(
        self: *const PublishTurnClient,
        event_json_output: []u8,
        event_message_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const local_operator.LocalEventDraft,
    ) PublishTurnClientError!PublishTurnRequest {
        var publish_storage = runtime.RelayPoolPublishStorage{};
        const publish_plan = self.inspectPublish(&publish_storage);
        const publish_step = publish_plan.nextStep() orelse return error.NoReadyRelay;

        var event = try self.local_operator.signDraft(secret_key, draft);
        const event_json = try self.local_operator.serializeEventJson(event_json_output, &event);
        const event_message_json = try serializeEventClientMessage(event_message_output, &event);
        return .{
            .relay = publish_step.entry.descriptor,
            .event = event,
            .event_json = event_json,
            .event_message_json = event_message_json,
        };
    }

    pub fn acceptPublishOkJson(
        self: *const PublishTurnClient,
        request: *const PublishTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) PublishTurnClientError!PublishTurnResult {
        const ok = try self.relay_response.acceptPublishOkJson(
            &request.event.id,
            relay_message_json,
            scratch,
        );
        return .{
            .request = request.*,
            .event_id = ok.event_id,
            .accepted = ok.accepted,
            .status = ok.status,
        };
    }
};

fn serializeEventClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) PublishTurnClientError![]const u8 {
    const prefix = "[\"EVENT\",";
    if (output.len < prefix.len + 1) return error.BufferTooSmall;

    @memcpy(output[0..prefix.len], prefix);
    const event_json = try noztr.nip01_event.event_serialize_json_object(
        output[prefix.len .. output.len - 1],
        event,
    );
    const end = prefix.len + event_json.len;
    output[end] = ']';
    return output[0 .. end + 1];
}

test "publish turn client exposes caller-owned config and relay-pool storage" {
    var storage = PublishTurnClientStorage{};
    const client = PublishTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "publish turn client composes one bounded publish turn and validates matching ok" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = PublishTurnClientStorage{};
    var client = PublishTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const secret_key = [_]u8{0x11} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 70,
        .content = "hello publish turn",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(
        event_json_output[0..],
        event_message_output[0..],
        &secret_key,
        &draft,
    );
    try std.testing.expectEqualStrings("wss://relay.one", request.relay.relay_url);

    var ok_json_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        ok_json_output[0..],
        &.{ .ok = .{ .event_id = request.event.id, .accepted = true, .status = "" } },
    );
    const result = try client.acceptPublishOkJson(&request, ok_json, arena.allocator());
    try std.testing.expect(result.accepted);
    try std.testing.expectEqualStrings(request.relay.relay_url, result.request.relay.relay_url);
}

test "publish turn client preserves rejected ok and wrong event reply posture explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = PublishTurnClientStorage{};
    var client = PublishTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const secret_key = [_]u8{0x12} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 71,
        .content = "hello rejected publish turn",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(
        event_json_output[0..],
        event_message_output[0..],
        &secret_key,
        &draft,
    );

    var ok_json_output: [256]u8 = undefined;
    const rejected_ok_json = try noztr.nip01_message.relay_message_serialize_json(
        ok_json_output[0..],
        &.{ .ok = .{ .event_id = request.event.id, .accepted = false, .status = "error: blocked" } },
    );
    const rejected = try client.acceptPublishOkJson(&request, rejected_ok_json, arena.allocator());
    try std.testing.expect(!rejected.accepted);
    try std.testing.expectEqualStrings("error: blocked", rejected.status);

    const wrong_event_json = try noztr.nip01_message.relay_message_serialize_json(
        ok_json_output[0..],
        &.{ .ok = .{ .event_id = [_]u8{0x77} ** 32, .accepted = true, .status = "" } },
    );
    try std.testing.expectError(
        error.UnexpectedEventId,
        client.acceptPublishOkJson(&request, wrong_event_json, arena.allocator()),
    );
}

test "publish turn client returns no ready relay when publish posture is stale" {
    var storage = PublishTurnClientStorage{};
    var client = PublishTurnClient.init(.{}, &storage);

    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);
    try client.noteRelayDisconnected(ready.relay_index);

    const secret_key = [_]u8{0x13} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 72,
        .content = "no ready relay",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    try std.testing.expectError(
        error.NoReadyRelay,
        client.beginTurn(
            event_json_output[0..],
            event_message_output[0..],
            &secret_key,
            &draft,
        ),
    );
}
