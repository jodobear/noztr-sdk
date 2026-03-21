const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_response = @import("relay_response_client.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const RelayExchangeClientError =
    local_operator.LocalOperatorClientError ||
    relay_response.RelayResponseClientError ||
    runtime.RelayPoolError ||
    runtime.RelaySubscriptionError ||
    runtime.RelayCountError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoReadyRelay,
        RelayNotReady,
    };

pub const RelayExchangeClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    relay_response: relay_response.RelayResponseClientConfig = .{},
};

pub const RelayExchangeClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const PublishExchangeRequest = struct {
    relay: runtime.RelayDescriptor,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    event_message_json: []const u8,
};

pub const PublishExchangeOutcome = struct {
    relay: runtime.RelayDescriptor,
    event_id: [32]u8,
    accepted: bool,
    status: []const u8,
};

pub const CountExchangeRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const CountExchangeOutcome = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    count: u64,
};

pub const SubscriptionExchangeRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const SubscriptionExchangeOutcome = struct {
    relay: runtime.RelayDescriptor,
    message: relay_response.RelaySubscriptionMessageOutcome,
};

pub const CloseExchangeRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const RelayExchangeClient = struct {
    config: RelayExchangeClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    relay_response: relay_response.RelayResponseClient,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: RelayExchangeClientConfig,
        storage: *RelayExchangeClientStorage,
    ) RelayExchangeClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: RelayExchangeClientConfig,
        storage: *RelayExchangeClientStorage,
    ) RelayExchangeClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *RelayExchangeClient,
        relay_url_text: []const u8,
    ) RelayExchangeClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "relay_pool", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *RelayExchangeClient,
        relay_index: u8,
    ) RelayExchangeClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayExchangeClient,
        relay_index: u8,
    ) RelayExchangeClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayExchangeClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayExchangeClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "relay_pool",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const RelayExchangeClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "relay_pool", storage);
    }

    pub fn beginPublish(
        self: *const RelayExchangeClient,
        event_json_output: []u8,
        event_message_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const local_operator.LocalEventDraft,
    ) RelayExchangeClientError!PublishExchangeRequest {
        var publish_storage = runtime.RelayPoolPublishStorage{};
        const publish_plan = self.relay_pool.inspectPublish(&publish_storage);
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
        self: *const RelayExchangeClient,
        request: *const PublishExchangeRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayExchangeClientError!PublishExchangeOutcome {
        const ok = try self.relay_response.acceptPublishOkJson(
            &request.event.id,
            relay_message_json,
            scratch,
        );
        return .{
            .relay = request.relay,
            .event_id = ok.event_id,
            .accepted = ok.accepted,
            .status = ok.status,
        };
    }

    pub fn beginCount(
        self: *const RelayExchangeClient,
        output: []u8,
        specs: []const runtime.RelayCountSpec,
    ) RelayExchangeClientError!CountExchangeRequest {
        var count_storage = runtime.RelayPoolCountStorage{};
        const count_plan = try self.relay_pool.inspectCounts(specs, &count_storage);
        const count_step = count_plan.nextStep() orelse return error.NoReadyRelay;
        const request_json = try serializeRequestLike(
            output,
            count_step.entry.subscription_id,
            count_step.entry.filters,
            .count,
        );
        return .{
            .relay = count_step.entry.descriptor,
            .subscription_id = count_step.entry.subscription_id,
            .request_json = request_json,
        };
    }

    pub fn acceptCountMessageJson(
        self: *const RelayExchangeClient,
        request: *const CountExchangeRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayExchangeClientError!CountExchangeOutcome {
        const count = try self.relay_response.acceptCountMessageJson(
            request.subscription_id,
            relay_message_json,
            scratch,
        );
        return .{
            .relay = request.relay,
            .subscription_id = count.subscription_id,
            .count = count.count,
        };
    }

    pub fn beginSubscription(
        self: *const RelayExchangeClient,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) RelayExchangeClientError!SubscriptionExchangeRequest {
        var subscription_storage = runtime.RelayPoolSubscriptionStorage{};
        const subscription_plan = try self.relay_pool.inspectSubscriptions(specs, &subscription_storage);
        const subscription_step = subscription_plan.nextStep() orelse return error.NoReadyRelay;
        try self.relay_response.beginSubscriptionTranscript(
            transcript,
            subscription_step.entry.subscription_id,
        );
        const request_json = try serializeRequestLike(
            output,
            subscription_step.entry.subscription_id,
            subscription_step.entry.filters,
            .req,
        );
        return .{
            .relay = subscription_step.entry.descriptor,
            .subscription_id = subscription_step.entry.subscription_id,
            .request_json = request_json,
        };
    }

    pub fn acceptSubscriptionMessageJson(
        self: *const RelayExchangeClient,
        request: *const SubscriptionExchangeRequest,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayExchangeClientError!SubscriptionExchangeOutcome {
        const message = try self.relay_response.acceptSubscriptionMessageJson(
            transcript,
            relay_message_json,
            scratch,
        );
        return .{
            .relay = request.relay,
            .message = message,
        };
    }

    pub fn composeClose(
        self: *const RelayExchangeClient,
        output: []u8,
        request: *const SubscriptionExchangeRequest,
    ) RelayExchangeClientError!CloseExchangeRequest {
        try self.requireReadyRelay(&request.relay);
        const message = noztr.nip01_message.ClientMessage{
            .close = .{ .subscription_id = request.subscription_id },
        };
        const request_json = try noztr.nip01_message.client_message_serialize_json(output, &message);
        return .{
            .relay = request.relay,
            .subscription_id = request.subscription_id,
            .request_json = request_json,
        };
    }

    fn requireReadyRelay(
        self: *const RelayExchangeClient,
        descriptor: *const runtime.RelayDescriptor,
    ) RelayExchangeClientError!void {
        const live_descriptor = self.relay_pool.descriptor(descriptor.relay_index) orelse {
            return error.RelayNotReady;
        };
        if (!std.mem.eql(u8, live_descriptor.relay_url, descriptor.relay_url)) {
            return error.RelayNotReady;
        }

        var storage = runtime.RelayPoolPlanStorage{};
        const runtime_plan = self.inspectRelayRuntime(&storage);
        const current = runtime_plan.entry(descriptor.relay_index) orelse return error.RelayNotReady;
        if (!std.mem.eql(u8, current.descriptor.relay_url, descriptor.relay_url)) {
            return error.RelayNotReady;
        }
        if (current.action != .ready) return error.RelayNotReady;
    }
};

const RequestKind = enum {
    req,
    count,
};

fn serializeRequestLike(
    output: []u8,
    subscription_id: []const u8,
    filters_in: []const noztr.nip01_filter.Filter,
    kind: RequestKind,
) RelayExchangeClientError![]const u8 {
    var filters: [noztr.limits.message_filters_max]noztr.nip01_filter.Filter =
        [_]noztr.nip01_filter.Filter{.{}} ** noztr.limits.message_filters_max;
    for (filters_in, 0..) |filter, index| {
        filters[index] = filter;
    }
    const filter_count: u8 = @intCast(filters_in.len);
    const message: noztr.nip01_message.ClientMessage = switch (kind) {
        .req => .{
            .req = .{
                .subscription_id = subscription_id,
                .filters = filters,
                .filters_count = filter_count,
            },
        },
        .count => .{
            .count = .{
                .subscription_id = subscription_id,
                .filters = filters,
                .filters_count = filter_count,
            },
        },
    };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

fn serializeEventClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) RelayExchangeClientError![]const u8 {
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

test "relay exchange client composes publish exchange and validates matching ok" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelayExchangeClientStorage{};
    var client = RelayExchangeClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const secret_key = [_]u8{0x11} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 7,
        .content = "hello exchange publish",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginPublish(
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
    const outcome = try client.acceptPublishOkJson(&request, ok_json, arena.allocator());
    try std.testing.expect(outcome.accepted);
}

test "relay exchange client composes count exchange and validates matching count reply" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelayExchangeClientStorage{};
    var client = RelayExchangeClient.init(.{}, &storage);
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
    const request = try client.beginCount(request_output[0..], specs[0..]);
    try std.testing.expectEqualStrings("wss://relay.one", request.relay.relay_url);

    var response_output: [128]u8 = undefined;
    const count_json = try noztr.nip01_message.relay_message_serialize_json(
        response_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 42 } },
    );
    const outcome = try client.acceptCountMessageJson(&request, count_json, arena.allocator());
    try std.testing.expectEqual(@as(u64, 42), outcome.count);
}

test "relay exchange client composes subscription exchange intake and close request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = RelayExchangeClientStorage{};
    var client = RelayExchangeClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var transcript = relay_response.RelaySubscriptionTranscriptStorage{};
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginSubscription(&transcript, request_output[0..], specs[0..]);
    try std.testing.expectEqualStrings("feed", transcript.subscriptionId());

    const secret_key = [_]u8{0x11} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 8,
        .tags = &.{},
        .content = "hello exchange subscription",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var response_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        response_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    const outcome = try client.acceptSubscriptionMessageJson(
        &request,
        &transcript,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(outcome.message == .event);

    const close = try client.composeClose(request_output[0..], &request);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", close.request_json);
}
