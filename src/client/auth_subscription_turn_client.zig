const std = @import("std");
const subscription_turn = @import("subscription_turn_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const AuthSubscriptionTurnClientError =
    subscription_turn.SubscriptionTurnClientError ||
    relay_auth_client.RelayAuthClientError;

pub const AuthSubscriptionTurnClientConfig = struct {
    subscription_turn: subscription_turn.SubscriptionTurnClientConfig = .{},
};

pub const AuthSubscriptionTurnClientStorage = struct {
    subscription_turn: subscription_turn.SubscriptionTurnClientStorage = .{},
};

pub const AuthSubscriptionEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthSubscriptionEvent = relay_auth_client.PreparedRelayAuthEvent;

pub const AuthSubscriptionTurnStep = union(enum) {
    authenticate: runtime.RelayPoolAuthStep,
    subscription: runtime.RelayPoolSubscriptionStep,
};

pub const AuthSubscriptionTurnResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    subscribed: subscription_turn.SubscriptionTurnResult,
};

pub const AuthSubscriptionTurnClient = struct {
    config: AuthSubscriptionTurnClientConfig,
    subscription_turn: subscription_turn.SubscriptionTurnClient,

    pub fn init(
        config: AuthSubscriptionTurnClientConfig,
        storage: *AuthSubscriptionTurnClientStorage,
    ) AuthSubscriptionTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .subscription_turn = subscription_turn.SubscriptionTurnClient.attach(
                config.subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn attach(
        config: AuthSubscriptionTurnClientConfig,
        storage: *AuthSubscriptionTurnClientStorage,
    ) AuthSubscriptionTurnClient {
        return .{
            .config = config,
            .subscription_turn = subscription_turn.SubscriptionTurnClient.attach(
                config.subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *AuthSubscriptionTurnClient,
        relay_url_text: []const u8,
    ) AuthSubscriptionTurnClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "subscription_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *AuthSubscriptionTurnClient,
        relay_index: u8,
    ) AuthSubscriptionTurnClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "subscription_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *AuthSubscriptionTurnClient,
        relay_index: u8,
    ) AuthSubscriptionTurnClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "subscription_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *AuthSubscriptionTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) AuthSubscriptionTurnClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "subscription_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const AuthSubscriptionTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "subscription_turn", storage);
    }

    pub fn inspectAuth(
        self: *const AuthSubscriptionTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.subscription_turn.relay_exchange.relay_pool.inspectAuth(storage);
    }

    pub fn inspectSubscriptions(
        self: *const AuthSubscriptionTurnClient,
        specs: []const runtime.RelaySubscriptionSpec,
        storage: *runtime.RelayPoolSubscriptionStorage,
    ) AuthSubscriptionTurnClientError!runtime.RelayPoolSubscriptionPlan {
        return self.subscription_turn.inspectSubscriptions(specs, storage);
    }

    pub fn nextStep(
        self: *const AuthSubscriptionTurnClient,
        auth_storage: *runtime.RelayPoolAuthStorage,
        specs: []const runtime.RelaySubscriptionSpec,
        subscription_storage: *runtime.RelayPoolSubscriptionStorage,
    ) AuthSubscriptionTurnClientError!?AuthSubscriptionTurnStep {
        const auth_plan = self.inspectAuth(auth_storage);
        if (auth_plan.nextStep()) |step| {
            return .{ .authenticate = step };
        }

        const subscription_plan = try self.inspectSubscriptions(specs, subscription_storage);
        if (subscription_plan.nextStep()) |step| {
            return .{ .subscription = step };
        }

        return null;
    }

    pub fn prepareAuthEvent(
        self: *const AuthSubscriptionTurnClient,
        auth_storage: *AuthSubscriptionEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) AuthSubscriptionTurnClientError!PreparedAuthSubscriptionEvent {
        const target = try self.selectAuthTarget(step);
        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.subscription_turn.relay_exchange.local_operator,
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
        self: *AuthSubscriptionTurnClient,
        prepared: *const PreparedAuthSubscriptionEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) AuthSubscriptionTurnClientError!AuthSubscriptionTurnResult {
        try self.requireCurrentAuth(prepared.relay, prepared.challenge);
        try self.subscription_turn.relay_exchange.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = prepared.relay };
    }

    pub fn beginSubscriptionTurn(
        self: *const AuthSubscriptionTurnClient,
        storage: *AuthSubscriptionTurnClientStorage,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) AuthSubscriptionTurnClientError!subscription_turn.SubscriptionTurnRequest {
        return self.subscription_turn.beginTurn(&storage.subscription_turn, output, specs);
    }

    pub fn acceptSubscriptionMessageJson(
        self: *const AuthSubscriptionTurnClient,
        storage: *AuthSubscriptionTurnClientStorage,
        request: *const subscription_turn.SubscriptionTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) AuthSubscriptionTurnClientError!subscription_turn.SubscriptionTurnIntake {
        return self.subscription_turn.acceptSubscriptionMessageJson(
            &storage.subscription_turn,
            request,
            relay_message_json,
            scratch,
        );
    }

    pub fn completeSubscriptionTurn(
        self: *const AuthSubscriptionTurnClient,
        storage: *const AuthSubscriptionTurnClientStorage,
        output: []u8,
        request: *const subscription_turn.SubscriptionTurnRequest,
    ) AuthSubscriptionTurnClientError!AuthSubscriptionTurnResult {
        const subscribed = try self.subscription_turn.completeTurn(
            &storage.subscription_turn,
            output,
            request,
        );
        return .{ .subscribed = subscribed };
    }

    fn selectAuthTarget(
        self: *const AuthSubscriptionTurnClient,
        step: *const runtime.RelayPoolAuthStep,
    ) AuthSubscriptionTurnClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(
            &self.subscription_turn.relay_exchange.relay_pool,
            plan,
            step,
        );
    }

    fn requireCurrentAuth(
        self: *const AuthSubscriptionTurnClient,
        descriptor: runtime.RelayDescriptor,
        challenge: []const u8,
    ) AuthSubscriptionTurnClientError!void {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.requireCurrentAuth(plan, descriptor, challenge);
    }
};

test "auth subscription turn client exposes caller-owned config and storage" {
    var storage = AuthSubscriptionTurnClientStorage{};
    var client = AuthSubscriptionTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(
        @as(u8, 0),
        client.subscription_turn.relay_exchange.relay_pool.relayCount(),
    );
}

test "auth subscription turn client authenticates then resumes one bounded subscription turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = AuthSubscriptionTurnClientStorage{};
    var client = AuthSubscriptionTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var subscription_plan_storage = runtime.RelayPoolSubscriptionStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &subscription_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x48} ** 32;
    var auth_event_storage = AuthSubscriptionEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        90,
    );
    const auth_result = try client.acceptPreparedAuthEvent(&prepared_auth, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const subscription_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &subscription_plan_storage,
    )).?.subscription;
    try std.testing.expectEqual(relay.relay_index, subscription_step.entry.descriptor.relay_index);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginSubscriptionTurn(&storage, request_output[0..], specs[0..]);

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "hello auth subscription turn",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    const event_intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(event_intake.subscription.message == .event);
    try std.testing.expect(!event_intake.complete);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    const eose_intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(eose_intake.subscription.message == .eose);
    try std.testing.expect(eose_intake.complete);

    const result = try client.completeSubscriptionTurn(&storage, request_output[0..], &request);
    try std.testing.expect(result == .subscribed);
    try std.testing.expectEqual(@as(u32, 1), result.subscribed.event_count);
    try std.testing.expectEqual(.eose, result.subscribed.completion);
}

test "auth subscription turn client rejects partial transcript after auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = AuthSubscriptionTurnClientStorage{};
    var client = AuthSubscriptionTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var subscription_plan_storage = runtime.RelayPoolSubscriptionStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &subscription_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x49} ** 32;
    var auth_event_storage = AuthSubscriptionEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        90,
    );
    _ = try client.acceptPreparedAuthEvent(&prepared_auth, 95, 60);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginSubscriptionTurn(&storage, request_output[0..], specs[0..]);

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "partial auth subscription turn",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        event_json,
        arena.allocator(),
    );

    try std.testing.expectError(
        error.IncompleteTranscript,
        client.completeSubscriptionTurn(&storage, request_output[0..], &request),
    );
}

test "auth subscription turn client rejects stale auth posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var storage = AuthSubscriptionTurnClientStorage{};
    var client = AuthSubscriptionTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = runtime.RelayPoolAuthStorage{};
    var subscription_plan_storage = runtime.RelayPoolSubscriptionStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &subscription_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x4A} ** 32;
    var auth_event_storage = AuthSubscriptionEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        90,
    );

    try client.noteRelayDisconnected(relay.relay_index);
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-2");
    try std.testing.expectError(
        error.StaleAuthStep,
        client.acceptPreparedAuthEvent(&prepared_auth, 95, 60),
    );
}
