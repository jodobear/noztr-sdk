const std = @import("std");
const publish_turn = @import("publish_turn_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const AuthPublishTurnClientError =
    publish_turn.PublishTurnClientError ||
    relay_auth_client.RelayAuthClientError ||
    error{NoAuthOrPublishStep};

pub const AuthPublishTurnClientConfig = struct {
    publish_turn: publish_turn.PublishTurnClientConfig = .{},
};

pub const AuthPublishTurnClientStorage = struct {
    publish_turn: publish_turn.PublishTurnClientStorage = .{},
};

pub const AuthPublishEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthPublishEvent = relay_auth_client.PreparedRelayAuthEvent;

pub const AuthPublishTurnStep = union(enum) {
    authenticate: runtime.RelayPoolAuthStep,
    publish: runtime.RelayPoolPublishStep,
};

pub const AuthPublishTurnResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    published: publish_turn.PublishTurnResult,
};

pub const AuthPublishTurnClient = struct {
    config: AuthPublishTurnClientConfig,
    publish_turn: publish_turn.PublishTurnClient,

    pub fn init(
        config: AuthPublishTurnClientConfig,
        storage: *AuthPublishTurnClientStorage,
    ) AuthPublishTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .publish_turn = publish_turn.PublishTurnClient.attach(
                config.publish_turn,
                &storage.publish_turn,
            ),
        };
    }

    pub fn attach(
        config: AuthPublishTurnClientConfig,
        storage: *AuthPublishTurnClientStorage,
    ) AuthPublishTurnClient {
        return .{
            .config = config,
            .publish_turn = publish_turn.PublishTurnClient.attach(
                config.publish_turn,
                &storage.publish_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *AuthPublishTurnClient,
        relay_url_text: []const u8,
    ) AuthPublishTurnClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "publish_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *AuthPublishTurnClient,
        relay_index: u8,
    ) AuthPublishTurnClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "publish_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *AuthPublishTurnClient,
        relay_index: u8,
    ) AuthPublishTurnClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "publish_turn", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *AuthPublishTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) AuthPublishTurnClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "publish_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const AuthPublishTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "publish_turn", storage);
    }

    pub fn inspectAuth(
        self: *const AuthPublishTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.publish_turn.relay_pool.inspectAuth(storage);
    }

    pub fn inspectPublish(
        self: *const AuthPublishTurnClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.publish_turn.inspectPublish(storage);
    }

    pub fn nextStep(
        self: *const AuthPublishTurnClient,
        auth_storage: *runtime.RelayPoolAuthStorage,
        publish_storage: *runtime.RelayPoolPublishStorage,
    ) ?AuthPublishTurnStep {
        const auth_plan = self.inspectAuth(auth_storage);
        if (auth_plan.nextStep()) |step| {
            return .{ .authenticate = step };
        }

        const publish_plan = self.inspectPublish(publish_storage);
        if (publish_plan.nextStep()) |step| {
            return .{ .publish = step };
        }

        return null;
    }

    pub fn prepareAuthEvent(
        self: *const AuthPublishTurnClient,
        auth_storage: *AuthPublishEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) AuthPublishTurnClientError!PreparedAuthPublishEvent {
        const target = try self.selectAuthTarget(step);
        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.publish_turn.local_operator,
            auth_storage,
            event_json_output,
            auth_message_output,
            secret_key,
            created_at,
            target.relay.relay_url,
            target.challenge,
        );
        return .{
            .relay = target.relay,
            .challenge = auth_storage.challengeText(),
            .event = payload.event,
            .event_json = payload.event_json,
            .auth_message_json = payload.auth_message_json,
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *AuthPublishTurnClient,
        prepared: *const PreparedAuthPublishEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) AuthPublishTurnClientError!AuthPublishTurnResult {
        try self.requireCurrentAuth(prepared.relay, prepared.challenge);
        try self.publish_turn.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = prepared.relay };
    }

    pub fn beginPublishTurn(
        self: *const AuthPublishTurnClient,
        event_json_output: []u8,
        event_message_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const local_operator.LocalEventDraft,
    ) AuthPublishTurnClientError!publish_turn.PublishTurnRequest {
        return self.publish_turn.beginTurn(
            event_json_output,
            event_message_output,
            secret_key,
            draft,
        );
    }

    pub fn acceptPublishOkJson(
        self: *const AuthPublishTurnClient,
        request: *const publish_turn.PublishTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) AuthPublishTurnClientError!AuthPublishTurnResult {
        const published = try self.publish_turn.acceptPublishOkJson(request, relay_message_json, scratch);
        return .{ .published = published };
    }

    fn selectAuthTarget(
        self: *const AuthPublishTurnClient,
        step: *const runtime.RelayPoolAuthStep,
    ) AuthPublishTurnClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(&self.publish_turn.relay_pool, plan, step);
    }

    fn requireCurrentAuth(
        self: *const AuthPublishTurnClient,
        descriptor: runtime.RelayDescriptor,
        challenge: []const u8,
    ) AuthPublishTurnClientError!void {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.requireCurrentAuth(plan, descriptor, challenge);
    }
};

test "auth publish turn client exposes caller-owned config and shared publish-turn storage" {
    var storage = AuthPublishTurnClientStorage{};
    var client = AuthPublishTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.publish_turn.relay_pool.relayCount());
}

test "auth publish turn client drives one auth-gated publish progression explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = AuthPublishTurnClientStorage{};
    var client = AuthPublishTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var publish_plan_storage = runtime.RelayPoolPublishStorage{};
    const first_step = client.nextStep(&auth_plan_storage, &publish_plan_storage).?;
    try std.testing.expect(first_step == .authenticate);

    const secret_key = [_]u8{0x21} ** 32;
    var auth_event_storage = AuthPublishEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &first_step.authenticate,
        &secret_key,
        80,
    );
    const auth_result = try client.acceptPreparedAuthEvent(&prepared_auth, 85, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_step = client.nextStep(&auth_plan_storage, &publish_plan_storage).?;
    try std.testing.expect(second_step == .publish);

    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 81,
        .content = "hello auth publish turn",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const publish_request = try client.beginPublishTurn(
        event_json_output[0..],
        event_message_output[0..],
        &secret_key,
        &draft,
    );

    var reply_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .ok = .{ .event_id = publish_request.event.id, .accepted = true, .status = "" } },
    );
    const publish_result = try client.acceptPublishOkJson(
        &publish_request,
        ok_json,
        arena.allocator(),
    );
    try std.testing.expect(publish_result == .published);
    try std.testing.expect(publish_result.published.accepted);
}

test "auth publish turn client rejects stale auth acceptance and disconnected-after-auth publish" {
    var storage = AuthPublishTurnClientStorage{};
    var client = AuthPublishTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var publish_plan_storage = runtime.RelayPoolPublishStorage{};
    const auth_step = client.nextStep(&auth_plan_storage, &publish_plan_storage).?.authenticate;

    const secret_key = [_]u8{0x22} ** 32;
    var auth_event_storage = AuthPublishEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        82,
    );

    try client.noteRelayDisconnected(relay.relay_index);
    try std.testing.expectError(
        error.RelayNotReady,
        client.acceptPreparedAuthEvent(&prepared_auth, 85, 60),
    );

    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    const fresh_step = client.nextStep(&auth_plan_storage, &publish_plan_storage).?.authenticate;
    const fresh_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &fresh_step,
        &secret_key,
        83,
    );
    _ = try client.acceptPreparedAuthEvent(&fresh_auth, 85, 60);
    try client.noteRelayDisconnected(relay.relay_index);

    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 84,
        .content = "disconnected after auth",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    try std.testing.expectError(
        error.NoReadyRelay,
        client.beginPublishTurn(
            event_json_output[0..],
            event_message_output[0..],
            &secret_key,
            &draft,
        ),
    );
}
