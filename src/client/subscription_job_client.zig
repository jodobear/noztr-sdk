const std = @import("std");
const auth_subscription_turn = @import("auth_subscription_turn_client.zig");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const runtime = @import("../runtime/mod.zig");
const subscription_turn = @import("subscription_turn_client.zig");

pub const SubscriptionJobClientError = auth_subscription_turn.AuthSubscriptionTurnClientError;

pub const SubscriptionJobClientConfig = struct {
    auth_subscription_turn: auth_subscription_turn.AuthSubscriptionTurnClientConfig = .{},
};

pub const SubscriptionJobClientStorage = struct {
    auth_subscription_turn: auth_subscription_turn.AuthSubscriptionTurnClientStorage = .{},
};

pub const SubscriptionJobAuthEventStorage = auth_subscription_turn.AuthSubscriptionEventStorage;
pub const PreparedSubscriptionJobAuthEvent = auth_subscription_turn.PreparedAuthSubscriptionEvent;
pub const SubscriptionJobRequest = subscription_turn.SubscriptionTurnRequest;
pub const SubscriptionJobIntake = subscription_turn.SubscriptionTurnIntake;

pub const SubscriptionJobReady = union(enum) {
    authenticate: PreparedSubscriptionJobAuthEvent,
    subscription: SubscriptionJobRequest,
};

pub const SubscriptionJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    subscribed: subscription_turn.SubscriptionTurnResult,
};

pub const SubscriptionJobClient = struct {
    config: SubscriptionJobClientConfig,
    auth_subscription_turn: auth_subscription_turn.AuthSubscriptionTurnClient,

    pub fn init(
        config: SubscriptionJobClientConfig,
        storage: *SubscriptionJobClientStorage,
    ) SubscriptionJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .auth_subscription_turn = auth_subscription_turn.AuthSubscriptionTurnClient.attach(
                config.auth_subscription_turn,
                &storage.auth_subscription_turn,
            ),
        };
    }

    pub fn attach(
        config: SubscriptionJobClientConfig,
        storage: *SubscriptionJobClientStorage,
    ) SubscriptionJobClient {
        return .{
            .config = config,
            .auth_subscription_turn = auth_subscription_turn.AuthSubscriptionTurnClient.attach(
                config.auth_subscription_turn,
                &storage.auth_subscription_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *SubscriptionJobClient,
        relay_url_text: []const u8,
    ) SubscriptionJobClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "auth_subscription_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *SubscriptionJobClient,
        relay_index: u8,
    ) SubscriptionJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(
            self,
            "auth_subscription_turn",
            relay_index,
        );
    }

    pub fn noteRelayDisconnected(
        self: *SubscriptionJobClient,
        relay_index: u8,
    ) SubscriptionJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "auth_subscription_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *SubscriptionJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) SubscriptionJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "auth_subscription_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const SubscriptionJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(
            self,
            "auth_subscription_turn",
            storage,
        );
    }

    pub fn prepareJob(
        self: *const SubscriptionJobClient,
        storage: *SubscriptionJobClientStorage,
        auth_storage: *SubscriptionJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        specs: []const runtime.RelaySubscriptionSpec,
        created_at: u64,
    ) SubscriptionJobClientError!SubscriptionJobReady {
        var auth_plan_storage = runtime.RelayPoolAuthStorage{};
        var subscription_plan_storage = runtime.RelayPoolSubscriptionStorage{};
        const next = try self.auth_subscription_turn.nextStep(
            &auth_plan_storage,
            specs,
            &subscription_plan_storage,
        ) orelse return error.NoReadyRelay;

        return switch (next) {
            .authenticate => .{
                .authenticate = try self.auth_subscription_turn.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &next.authenticate,
                    secret_key,
                    created_at,
                ),
            },
            .subscription => .{
                .subscription = try self.auth_subscription_turn.beginSubscriptionTurn(
                    &storage.auth_subscription_turn,
                    request_output,
                    specs,
                ),
            },
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *SubscriptionJobClient,
        prepared: *const PreparedSubscriptionJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) SubscriptionJobClientError!SubscriptionJobResult {
        const result = try self.auth_subscription_turn.acceptPreparedAuthEvent(
            prepared,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = result.authenticated };
    }

    pub fn acceptSubscriptionMessageJson(
        self: *const SubscriptionJobClient,
        storage: *SubscriptionJobClientStorage,
        request: *const SubscriptionJobRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) SubscriptionJobClientError!SubscriptionJobIntake {
        return self.auth_subscription_turn.acceptSubscriptionMessageJson(
            &storage.auth_subscription_turn,
            request,
            relay_message_json,
            scratch,
        );
    }

    pub fn completeSubscriptionJob(
        self: *const SubscriptionJobClient,
        storage: *SubscriptionJobClientStorage,
        output: []u8,
        request: *const SubscriptionJobRequest,
    ) SubscriptionJobClientError!SubscriptionJobResult {
        const result = try self.auth_subscription_turn.completeSubscriptionTurn(
            &storage.auth_subscription_turn,
            output,
            request,
        );
        return .{ .subscribed = result.subscribed };
    }
};

test "subscription job client exposes caller-owned config and storage" {
    var storage = SubscriptionJobClientStorage{};
    var client = SubscriptionJobClient.init(.{}, &storage);

    try std.testing.expectEqual(
        @as(u8, 0),
        client.auth_subscription_turn.subscription_turn.relay_exchange.relay_pool.relayCount(),
    );
}

test "subscription job client drives auth-gated bounded transcript work through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = SubscriptionJobClientStorage{};
    var client = SubscriptionJobClient.init(.{}, &storage);
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

    const secret_key = [_]u8{0x73} ** 32;
    var auth_storage = SubscriptionJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &storage,
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
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(second_ready == .subscription);
    try std.testing.expectEqual(relay.relay_index, second_ready.subscription.subscription.relay.relay_index);

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "subscription job event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &storage,
        &second_ready.subscription,
        event_json,
        arena.allocator(),
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    const intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &second_ready.subscription,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(intake.complete);

    const result = try client.completeSubscriptionJob(
        &storage,
        request_output[0..],
        &second_ready.subscription,
    );
    try std.testing.expect(result == .subscribed);
    try std.testing.expectEqual(.eose, result.subscribed.completion);
}

test "subscription job client rejects partial transcript after auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = SubscriptionJobClientStorage{};
    var client = SubscriptionJobClient.init(.{}, &storage);
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

    const secret_key = [_]u8{0x74} ** 32;
    var auth_storage = SubscriptionJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    _ = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);

    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(second_ready == .subscription);

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 91,
        .tags = &.{},
        .content = "partial subscription job event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &storage,
        &second_ready.subscription,
        event_json,
        arena.allocator(),
    );

    try std.testing.expectError(
        error.IncompleteTranscript,
        client.completeSubscriptionJob(&storage, request_output[0..], &second_ready.subscription),
    );
}

test "subscription job client rejects stale auth posture explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = SubscriptionJobClientStorage{};
    var client = SubscriptionJobClient.init(.{}, &storage);
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

    const secret_key = [_]u8{0x75} ** 32;
    var auth_storage = SubscriptionJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
        &storage,
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
