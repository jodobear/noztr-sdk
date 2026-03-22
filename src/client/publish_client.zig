const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const PublishClientError =
    local_operator.LocalOperatorClientError ||
    runtime.RelayPoolError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StalePublishStep,
        RelayNotReady,
    };

pub const PublishClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const PublishClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const PreparedPublishEvent = struct {
    event: noztr.nip01_event.Event,
    event_json: []const u8,
};

pub const PublishTarget = struct {
    relay: runtime.RelayDescriptor,
};

pub const TargetedPublishEvent = struct {
    relay: runtime.RelayDescriptor,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    event_message_json: []const u8,
};

pub const PublishClient = struct {
    config: PublishClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: PublishClientConfig,
        storage: *PublishClientStorage,
    ) PublishClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: PublishClientConfig,
        storage: *PublishClientStorage,
    ) PublishClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn addRelay(
        self: *PublishClient,
        relay_url_text: []const u8,
    ) PublishClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "relay_pool", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *PublishClient,
        relay_index: u8,
    ) PublishClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *PublishClient,
        relay_index: u8,
    ) PublishClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *PublishClient,
        relay_index: u8,
        challenge: []const u8,
    ) PublishClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "relay_pool",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const PublishClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "relay_pool", storage);
    }

    pub fn inspectPublish(
        self: *const PublishClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.relay_pool.inspectPublish(storage);
    }

    pub fn prepareSignedEvent(
        self: PublishClient,
        output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const local_operator.LocalEventDraft,
    ) PublishClientError!PreparedPublishEvent {
        var event = try self.local_operator.signDraft(secret_key, draft);
        const event_json = try self.local_operator.serializeEventJson(output, &event);
        return .{
            .event = event,
            .event_json = event_json,
        };
    }

    pub fn prepareExistingSignedEvent(
        self: PublishClient,
        output: []u8,
        event: *const noztr.nip01_event.Event,
    ) PublishClientError!PreparedPublishEvent {
        _ = self;

        const event_json = try noztr.nip01_event.event_serialize_json_object(output, event);
        return .{
            .event = event.*,
            .event_json = event_json,
        };
    }

    pub fn serializeEventClientMessage(
        self: PublishClient,
        output: []u8,
        event: *const noztr.nip01_event.Event,
    ) PublishClientError![]const u8 {
        _ = self;

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

    pub fn selectPublishTarget(
        self: *const PublishClient,
        step: *const runtime.RelayPoolPublishStep,
    ) PublishClientError!PublishTarget {
        const live_descriptor = self.relay_pool.descriptor(step.entry.descriptor.relay_index) orelse {
            return error.StalePublishStep;
        };
        if (!std.mem.eql(u8, live_descriptor.relay_url, step.entry.descriptor.relay_url)) {
            return error.StalePublishStep;
        }

        var storage = runtime.RelayPoolPublishStorage{};
        const plan = self.inspectPublish(&storage);
        const current = plan.entry(step.entry.descriptor.relay_index) orelse return error.StalePublishStep;
        if (!std.mem.eql(u8, current.descriptor.relay_url, step.entry.descriptor.relay_url)) {
            return error.StalePublishStep;
        }
        if (current.action != .publish) return error.RelayNotReady;

        return .{ .relay = current.descriptor };
    }

    pub fn composeTargetedPublish(
        self: *const PublishClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const PreparedPublishEvent,
    ) PublishClientError!TargetedPublishEvent {
        const target = try self.selectPublishTarget(step);
        const event_message_json = try self.serializeEventClientMessage(output, &prepared.event);
        return .{
            .relay = target.relay,
            .event = prepared.event,
            .event_json = prepared.event_json,
            .event_message_json = event_message_json,
        };
    }
};

test "publish client exposes caller-owned config and relay-pool storage" {
    var storage = PublishClientStorage{};
    const client = PublishClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "publish client prepares one signed local event and serializes one outbound event message" {
    var storage = PublishClientStorage{};
    var client = PublishClient.init(.{}, &storage);

    const publishable = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(publishable.relay_index);

    const secret_key = [_]u8{0x11} ** 32;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 42,
        .content = "hello publish client",
    };

    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareSignedEvent(event_json_buffer[0..], &secret_key, &draft);
    try noztr.nip01_event.event_verify(&prepared.event);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const plan = client.inspectPublish(&publish_storage);
    try std.testing.expectEqual(@as(u8, 1), plan.publish_count);
    const step = plan.nextStep().?;

    var message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted = try client.composeTargetedPublish(message_buffer[0..], &step, &prepared);
    try std.testing.expectEqualStrings("wss://relay.one", targeted.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted.event_message_json, "[\"EVENT\","));
    try std.testing.expect(std.mem.indexOf(u8, targeted.event_json, "\"hello publish client\"") != null);
}

test "publish client rejects stale or no-longer-ready publish steps" {
    var storage = PublishClientStorage{};
    var client = PublishClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const plan = client.inspectPublish(&publish_storage);
    const step = plan.nextStep().?;

    try client.noteRelayDisconnected(relay.relay_index);
    try std.testing.expectError(
        error.RelayNotReady,
        client.selectPublishTarget(&step),
    );

    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try std.testing.expectError(
        error.RelayNotReady,
        client.selectPublishTarget(&step),
    );
}

test "publish client prepares one caller-owned signed event for publish composition" {
    var storage = PublishClientStorage{};
    var client = PublishClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x33} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 10051,
        .created_at = 77,
        .tags = &.{},
        .content = "{\"relays\":[\"wss://relay.one\"]}",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareExistingSignedEvent(event_json_buffer[0..], &event);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const plan = client.inspectPublish(&publish_storage);
    const step = plan.nextStep().?;

    var message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted = try client.composeTargetedPublish(message_buffer[0..], &step, &prepared);
    try std.testing.expectEqualStrings("wss://relay.one", targeted.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted.event_message_json, "[\"EVENT\","));
    try std.testing.expect(std.mem.indexOf(u8, targeted.event_json, "\"kind\":10051") != null);
}
