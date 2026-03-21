const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const subscription_turn = @import("subscription_turn_client.zig");
const workflows = @import("../workflows/mod.zig");

const mailbox_wrap_event_kind: u32 = 1059;

pub const MailboxSubscriptionTurnClientError =
    subscription_turn.SubscriptionTurnClientError ||
    workflows.MailboxError;

pub const MailboxSubscriptionTurnClientConfig = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    subscription_turn: subscription_turn.SubscriptionTurnClientConfig = .{},
};

pub const MailboxSubscriptionTurnClientStorage = struct {
    mailbox: workflows.MailboxSession = undefined,
    subscription_turn: subscription_turn.SubscriptionTurnClientStorage = .{},
};

pub const MailboxSubscriptionTurnRequest = subscription_turn.SubscriptionTurnRequest;
pub const MailboxSubscriptionTurnResult = subscription_turn.SubscriptionTurnResult;

pub const MailboxSubscriptionTurnIntake = struct {
    subscription: subscription_turn.SubscriptionTurnIntake,
    envelope: ?workflows.MailboxEnvelopeOutcome,
};

pub const MailboxSubscriptionTurnClient = struct {
    config: MailboxSubscriptionTurnClientConfig,
    storage: *MailboxSubscriptionTurnClientStorage,
    subscription_turn: subscription_turn.SubscriptionTurnClient,

    pub fn init(
        config: MailboxSubscriptionTurnClientConfig,
        storage: *MailboxSubscriptionTurnClientStorage,
    ) MailboxSubscriptionTurnClient {
        storage.* = .{
            .mailbox = workflows.MailboxSession.init(&config.recipient_private_key),
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
        config: MailboxSubscriptionTurnClientConfig,
        storage: *MailboxSubscriptionTurnClientStorage,
    ) MailboxSubscriptionTurnClient {
        return .{
            .config = config,
            .storage = storage,
            .subscription_turn = subscription_turn.SubscriptionTurnClient.attach(
                config.subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn relayCount(self: *const MailboxSubscriptionTurnClient) u8 {
        return self.storage.mailbox.relayCount();
    }

    pub fn currentRelayUrl(self: *const MailboxSubscriptionTurnClient) ?[]const u8 {
        return self.storage.mailbox.currentRelayUrl();
    }

    pub fn currentRelayAuthChallenge(self: *const MailboxSubscriptionTurnClient) ?[]const u8 {
        return self.storage.mailbox.currentRelayAuthChallenge();
    }

    pub fn hydrateRelayListEventJson(
        self: *MailboxSubscriptionTurnClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxSubscriptionTurnClientError!u8 {
        const relay_count = try self.storage.mailbox.hydrateRelayListEventJson(event_json, scratch);
        self.subscription_turn = subscription_turn.SubscriptionTurnClient.init(
            self.config.subscription_turn,
            &self.storage.subscription_turn,
        );

        var relay_index: u8 = 0;
        while (relay_index < relay_count) : (relay_index += 1) {
            const relay_url_text = try self.storage.mailbox.selectRelay(relay_index);
            _ = try self.subscription_turn.addRelay(relay_url_text);
        }
        if (relay_count > 0) {
            _ = try self.storage.mailbox.selectRelay(0);
        }
        return relay_count;
    }

    pub fn selectRelay(
        self: *MailboxSubscriptionTurnClient,
        relay_index: u8,
    ) MailboxSubscriptionTurnClientError![]const u8 {
        return self.storage.mailbox.selectRelay(relay_index);
    }

    pub fn markRelayConnected(
        self: *MailboxSubscriptionTurnClient,
        relay_index: u8,
    ) MailboxSubscriptionTurnClientError!void {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.markCurrentRelayConnected();
        try self.subscription_turn.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *MailboxSubscriptionTurnClient,
        relay_index: u8,
    ) MailboxSubscriptionTurnClientError!void {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.noteCurrentRelayDisconnected();
        try self.subscription_turn.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *MailboxSubscriptionTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) MailboxSubscriptionTurnClientError!void {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.noteCurrentRelayAuthChallenge(challenge);
        try self.subscription_turn.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn acceptRelayAuthEvent(
        self: *MailboxSubscriptionTurnClient,
        relay_index: u8,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) MailboxSubscriptionTurnClientError!runtime.RelayDescriptor {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.acceptCurrentRelayAuthEvent(
            auth_event,
            now_unix_seconds,
            window_seconds,
        );
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
        self: *const MailboxSubscriptionTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.subscription_turn.inspectRelayRuntime(storage);
    }

    pub fn inspectAuth(
        self: *const MailboxSubscriptionTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.subscription_turn.relay_exchange.relay_pool.inspectAuth(storage);
    }

    pub fn inspectSubscriptions(
        self: *const MailboxSubscriptionTurnClient,
        specs: []const runtime.RelaySubscriptionSpec,
        storage: *runtime.RelayPoolSubscriptionStorage,
    ) MailboxSubscriptionTurnClientError!runtime.RelayPoolSubscriptionPlan {
        return self.subscription_turn.inspectSubscriptions(specs, storage);
    }

    pub fn beginTurn(
        self: *MailboxSubscriptionTurnClient,
        output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
    ) MailboxSubscriptionTurnClientError!MailboxSubscriptionTurnRequest {
        const request = try self.subscription_turn.beginTurn(
            &self.storage.subscription_turn,
            output,
            specs,
        );
        _ = try self.storage.mailbox.selectRelay(request.subscription.relay.relay_index);
        return request;
    }

    pub fn acceptSubscriptionMessageJson(
        self: *MailboxSubscriptionTurnClient,
        request: *const MailboxSubscriptionTurnRequest,
        relay_message_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxSubscriptionTurnClientError!MailboxSubscriptionTurnIntake {
        const subscription = try self.subscription_turn.acceptSubscriptionMessageJson(
            &self.storage.subscription_turn,
            request,
            relay_message_json,
            scratch,
        );

        var envelope: ?workflows.MailboxEnvelopeOutcome = null;
        if (subscription.subscription.message == .event and
            subscription.subscription.message.event.event.kind == mailbox_wrap_event_kind)
        {
            envelope = try self.storage.mailbox.acceptWrappedEnvelopeEvent(
                &subscription.subscription.message.event.event,
                recipients_out,
                thumbs_out,
                fallbacks_out,
                scratch,
            );
        }

        return .{
            .subscription = subscription,
            .envelope = envelope,
        };
    }

    pub fn completeTurn(
        self: *const MailboxSubscriptionTurnClient,
        output: []u8,
        request: *const MailboxSubscriptionTurnRequest,
    ) MailboxSubscriptionTurnClientError!MailboxSubscriptionTurnResult {
        return self.subscription_turn.completeTurn(
            &self.storage.subscription_turn,
            output,
            request,
        );
    }
};

test "mailbox subscription turn client exposes caller-owned config and storage" {
    var storage = MailboxSubscriptionTurnClientStorage{};
    var client = MailboxSubscriptionTurnClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
}

test "mailbox subscription turn client accepts live transcript events through mailbox intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var client_storage = MailboxSubscriptionTurnClientStorage{};
    var client = MailboxSubscriptionTurnClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &client_storage);

    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try client.markRelayConnected(0);

    var sender_session = workflows.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = workflows.MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "mailbox subscription turn payload",
            .created_at = 41,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const specs = [_]runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(request_output[0..], specs[0..]);

    const wrap_event = try noztr.nip01_event.event_parse_json(outbound.wrap_event_json, arena.allocator());
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-feed", .event = wrap_event } },
    );

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const event_intake = try client.acceptSubscriptionMessageJson(
        &request,
        event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(event_intake.subscription.subscription.message == .event);
    try std.testing.expect(event_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox subscription turn payload",
        event_intake.envelope.?.direct_message.message.content,
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    const eose_intake = try client.acceptSubscriptionMessageJson(
        &request,
        eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(eose_intake.envelope == null);
    try std.testing.expect(eose_intake.subscription.complete);

    const result = try client.completeTurn(request_output[0..], &request);
    try std.testing.expectEqual(@as(u32, 1), result.event_count);
    try std.testing.expectEqual(.eose, result.completion);
}

fn buildRelayListEventJson(
    output: []u8,
    relay_text: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_text } },
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = relay_list_author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .tags = tags[0..],
        .content = "",
    };
    try noztr.nostr_keys.nostr_sign_event(signer_secret_key, &event);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":10050," ++
            "\"tags\":[[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_text,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
