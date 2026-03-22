const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const runtime = @import("../runtime/mod.zig");
const subscription_turn = @import("subscription_turn_client.zig");
const workflows = @import("../workflows/mod.zig");

pub const LegacyDmSubscriptionTurnClientError =
    subscription_turn.SubscriptionTurnClientError ||
    workflows.dm.legacy.LegacyDmError;

pub const LegacyDmSubscriptionTurnClientConfig = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    subscription_turn: subscription_turn.SubscriptionTurnClientConfig = .{},
};

pub const LegacyDmSubscriptionTurnClientStorage = struct {
    session: workflows.dm.legacy.LegacyDmSession = undefined,
    subscription_turn: subscription_turn.SubscriptionTurnClientStorage = .{},
};

pub const LegacyDmSubscriptionTurnRequest = subscription_turn.SubscriptionTurnRequest;
pub const LegacyDmSubscriptionTurnResult = subscription_turn.SubscriptionTurnResult;

pub const LegacyDmSubscriptionTurnIntake = struct {
    subscription: subscription_turn.SubscriptionTurnIntake,
    message: ?workflows.dm.legacy.LegacyDmMessageOutcome,
};

pub const LegacyDmSubscriptionTurnClient = struct {
    config: LegacyDmSubscriptionTurnClientConfig,
    storage: *LegacyDmSubscriptionTurnClientStorage,
    subscription_turn: subscription_turn.SubscriptionTurnClient,

    pub fn init(
        config: LegacyDmSubscriptionTurnClientConfig,
        storage: *LegacyDmSubscriptionTurnClientStorage,
    ) LegacyDmSubscriptionTurnClient {
        storage.* = .{
            .session = workflows.dm.legacy.LegacyDmSession.init(&config.owner_private_key),
        };
        return .{
            .config = config,
            .storage = storage,
            .subscription_turn = subscription_turn.SubscriptionTurnClient.attach(
                config.subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn attach(
        config: LegacyDmSubscriptionTurnClientConfig,
        storage: *LegacyDmSubscriptionTurnClientStorage,
    ) LegacyDmSubscriptionTurnClient {
        return .{
            .config = config,
            .storage = storage,
            .subscription_turn = subscription_turn.SubscriptionTurnClient.attach(
                config.subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *LegacyDmSubscriptionTurnClient,
        relay_url_text: []const u8,
    ) LegacyDmSubscriptionTurnClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "subscription_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *LegacyDmSubscriptionTurnClient,
        relay_index: u8,
    ) LegacyDmSubscriptionTurnClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "subscription_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LegacyDmSubscriptionTurnClient,
        relay_index: u8,
    ) LegacyDmSubscriptionTurnClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "subscription_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *LegacyDmSubscriptionTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) LegacyDmSubscriptionTurnClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "subscription_turn",
            relay_index,
            challenge,
        );
    }

    pub fn acceptRelayAuthEvent(
        self: *LegacyDmSubscriptionTurnClient,
        relay_index: u8,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) LegacyDmSubscriptionTurnClientError!runtime.RelayDescriptor {
        try self.subscription_turn.relay_exchange.relay_pool.acceptRelayAuthEvent(
            relay_index,
            auth_event,
            now_unix_seconds,
            window_seconds,
        );
        return self.subscription_turn.relay_exchange.relay_pool.descriptor(relay_index) orelse {
            return error.InvalidRelayIndex;
        };
    }

    pub fn inspectRelayRuntime(
        self: *const LegacyDmSubscriptionTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "subscription_turn", storage);
    }

    pub fn inspectAuth(
        self: *const LegacyDmSubscriptionTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.subscription_turn.relay_exchange.relay_pool.inspectAuth(storage);
    }

    pub fn inspectSubscriptions(
        self: *const LegacyDmSubscriptionTurnClient,
        specs: []const runtime.RelaySubscriptionSpec,
        storage: *runtime.RelayPoolSubscriptionStorage,
    ) LegacyDmSubscriptionTurnClientError!runtime.RelayPoolSubscriptionPlan {
        return self.subscription_turn.inspectSubscriptions(specs, storage);
    }

    pub fn beginTurn(
        self: *const LegacyDmSubscriptionTurnClient,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) LegacyDmSubscriptionTurnClientError!LegacyDmSubscriptionTurnRequest {
        return self.subscription_turn.beginTurn(&self.storage.subscription_turn, output, specs);
    }

    pub fn acceptSubscriptionMessageJson(
        self: *LegacyDmSubscriptionTurnClient,
        request: *const LegacyDmSubscriptionTurnRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) LegacyDmSubscriptionTurnClientError!LegacyDmSubscriptionTurnIntake {
        const subscription = try self.subscription_turn.acceptSubscriptionMessageJson(
            &self.storage.subscription_turn,
            request,
            relay_message_json,
            scratch,
        );

        var message: ?workflows.dm.legacy.LegacyDmMessageOutcome = null;
        if (subscription.subscription.message == .event and
            subscription.subscription.message.event.event.kind == noztr.nip04.dm_kind)
        {
            message = try self.storage.session.acceptDirectMessageEvent(
                &subscription.subscription.message.event.event,
                plaintext_output,
            );
        }

        return .{
            .subscription = subscription,
            .message = message,
        };
    }

    pub fn completeTurn(
        self: *const LegacyDmSubscriptionTurnClient,
        output: []u8,
        request: *const LegacyDmSubscriptionTurnRequest,
    ) LegacyDmSubscriptionTurnClientError!LegacyDmSubscriptionTurnResult {
        return self.subscription_turn.completeTurn(&self.storage.subscription_turn, output, request);
    }
};

test "legacy dm subscription turn client accepts live transcript events through dm intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x31} ** 32;
    const recipient_secret = [_]u8{0x42} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var outbound = workflows.dm.legacy.LegacyDmOutboundStorage{};
    const sender = workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    const prepared = try sender.buildDirectMessageEvent(&outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy live intake",
        .created_at = 70,
        .iv = [_]u8{0x44} ** noztr.limits.nip04_iv_bytes,
    });

    var storage = LegacyDmSubscriptionTurnClientStorage{};
    var client = LegacyDmSubscriptionTurnClient.init(.{
        .owner_private_key = recipient_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-live", .event = prepared.event } },
    );
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const intake = try client.acceptSubscriptionMessageJson(
        &request,
        event_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    try std.testing.expect(intake.subscription.subscription.message == .event);
    try std.testing.expect(intake.message != null);
    try std.testing.expectEqualStrings("legacy live intake", intake.message.?.plaintext);
}
