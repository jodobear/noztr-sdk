const std = @import("std");
const relay_exchange = @import("relay_exchange_client.zig");
const relay_response = @import("relay_response_client.zig");
const runtime = @import("../runtime/mod.zig");

pub const SubscriptionTurnClientError =
    relay_exchange.RelayExchangeClientError ||
    error{IncompleteTranscript};

pub const SubscriptionTurnClientConfig = struct {
    relay_exchange: relay_exchange.RelayExchangeClientConfig = .{},
};

pub const SubscriptionTurnClientStorage = struct {
    relay_exchange: relay_exchange.RelayExchangeClientStorage = .{},
    transcript: relay_response.RelaySubscriptionTranscriptStorage = .{},
    state: SubscriptionTurnState = undefined,
};

pub const SubscriptionTurnState = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    event_count: u32 = 0,
    saw_eose: bool = false,
    saw_closed: bool = false,
};

pub const SubscriptionTurnRequest = struct {
    subscription: relay_exchange.SubscriptionExchangeRequest,
};

pub const SubscriptionTurnIntake = struct {
    subscription: relay_exchange.SubscriptionExchangeOutcome,
    event_count: u32,
    complete: bool,
};

pub const SubscriptionTurnCompletion = enum {
    eose,
    closed,
};

pub const SubscriptionTurnResult = struct {
    request: relay_exchange.SubscriptionExchangeRequest,
    close: relay_exchange.CloseExchangeRequest,
    event_count: u32,
    completion: SubscriptionTurnCompletion,
};

pub const SubscriptionTurnClient = struct {
    config: SubscriptionTurnClientConfig,
    relay_exchange: relay_exchange.RelayExchangeClient,

    pub fn init(
        config: SubscriptionTurnClientConfig,
        storage: *SubscriptionTurnClientStorage,
    ) SubscriptionTurnClient {
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
        config: SubscriptionTurnClientConfig,
        storage: *SubscriptionTurnClientStorage,
    ) SubscriptionTurnClient {
        return .{
            .config = config,
            .relay_exchange = relay_exchange.RelayExchangeClient.attach(
                config.relay_exchange,
                &storage.relay_exchange,
            ),
        };
    }

    pub fn addRelay(
        self: *SubscriptionTurnClient,
        relay_url_text: []const u8,
    ) SubscriptionTurnClientError!runtime.RelayDescriptor {
        return self.relay_exchange.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *SubscriptionTurnClient,
        relay_index: u8,
    ) SubscriptionTurnClientError!void {
        return self.relay_exchange.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *SubscriptionTurnClient,
        relay_index: u8,
    ) SubscriptionTurnClientError!void {
        return self.relay_exchange.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *SubscriptionTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) SubscriptionTurnClientError!void {
        return self.relay_exchange.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const SubscriptionTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_exchange.inspectRelayRuntime(storage);
    }

    pub fn inspectSubscriptions(
        self: *const SubscriptionTurnClient,
        specs: []const runtime.RelaySubscriptionSpec,
        storage: *runtime.RelayPoolSubscriptionStorage,
    ) SubscriptionTurnClientError!runtime.RelayPoolSubscriptionPlan {
        return self.relay_exchange.relay_pool.inspectSubscriptions(specs, storage);
    }

    pub fn beginTurn(
        self: *const SubscriptionTurnClient,
        storage: *SubscriptionTurnClientStorage,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) SubscriptionTurnClientError!SubscriptionTurnRequest {
        const request = try self.relay_exchange.beginSubscription(
            &storage.transcript,
            output,
            specs,
        );
        storage.state = .{
            .relay = request.relay,
            .subscription_id = request.subscription_id,
        };
        return .{ .subscription = request };
    }

    pub fn acceptSubscriptionMessageJson(
        self: *const SubscriptionTurnClient,
        storage: *SubscriptionTurnClientStorage,
        request: *const SubscriptionTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) SubscriptionTurnClientError!SubscriptionTurnIntake {
        const outcome = try self.relay_exchange.acceptSubscriptionMessageJson(
            &request.subscription,
            &storage.transcript,
            relay_message_json,
            scratch,
        );

        switch (outcome.message) {
            .event => storage.state.event_count += 1,
            .eose => storage.state.saw_eose = true,
            .closed => storage.state.saw_closed = true,
        }

        return .{
            .subscription = outcome,
            .event_count = storage.state.event_count,
            .complete = storage.state.saw_eose or storage.state.saw_closed,
        };
    }

    pub fn completeTurn(
        self: *const SubscriptionTurnClient,
        storage: *const SubscriptionTurnClientStorage,
        output: []u8,
        request: *const SubscriptionTurnRequest,
    ) SubscriptionTurnClientError!SubscriptionTurnResult {
        if (!storage.state.saw_eose and !storage.state.saw_closed) {
            return error.IncompleteTranscript;
        }

        const close = try self.relay_exchange.composeClose(output, &request.subscription);
        return .{
            .request = request.subscription,
            .close = close,
            .event_count = storage.state.event_count,
            .completion = if (storage.state.saw_closed) .closed else .eose,
        };
    }
};

test "subscription turn client exposes caller-owned config and storage" {
    var storage = SubscriptionTurnClientStorage{};
    var client = SubscriptionTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_exchange.relay_pool.relayCount());
}

test "subscription turn client closes one bounded eose turn explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = SubscriptionTurnClientStorage{};
    var client = SubscriptionTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(&storage, request_output[0..], specs[0..]);

    const secret_key = [_]u8{0x31} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 93,
        .tags = &.{},
        .content = "hello subscription turn",
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

    const result = try client.completeTurn(&storage, request_output[0..], &request);
    try std.testing.expectEqual(@as(u32, 1), result.event_count);
    try std.testing.expectEqual(.eose, result.completion);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", result.close.request_json);
}

test "subscription turn client closes closed-only turns and rejects partial ones" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = SubscriptionTurnClientStorage{};
    var client = SubscriptionTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(&storage, request_output[0..], specs[0..]);

    const closed_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .closed = .{ .subscription_id = "feed", .status = "error: end of turn" } },
    );
    const closed_intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        closed_json,
        arena.allocator(),
    );
    try std.testing.expect(closed_intake.subscription.message == .closed);
    try std.testing.expect(closed_intake.complete);

    const closed_result = try client.completeTurn(&storage, request_output[0..], &request);
    try std.testing.expectEqual(.closed, closed_result.completion);

    var partial_storage = SubscriptionTurnClientStorage{};
    var partial_client = SubscriptionTurnClient.init(.{}, &partial_storage);
    const partial_ready = try partial_client.addRelay("wss://relay.two");
    try partial_client.markRelayConnected(partial_ready.relay_index);
    const partial_request = try partial_client.beginTurn(&partial_storage, request_output[0..], specs[0..]);

    const secret_key = [_]u8{0x32} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 94,
        .tags = &.{},
        .content = "partial subscription turn",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    _ = try partial_client.acceptSubscriptionMessageJson(
        &partial_storage,
        &partial_request,
        event_json,
        arena.allocator(),
    );
    try std.testing.expectError(
        error.IncompleteTranscript,
        partial_client.completeTurn(&partial_storage, request_output[0..], &partial_request),
    );
}

test "subscription turn client rejects stale relay completion posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    var storage = SubscriptionTurnClientStorage{};
    var client = SubscriptionTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(&storage, request_output[0..], specs[0..]);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        eose_json,
        arena.allocator(),
    );

    try client.noteRelayDisconnected(ready.relay_index);
    try std.testing.expectError(
        error.RelayNotReady,
        client.completeTurn(&storage, request_output[0..], &request),
    );
}
