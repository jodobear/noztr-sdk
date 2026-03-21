const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const mailbox_subscription_turn = @import("mailbox_subscription_turn_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_url = @import("../relay/url.zig");
const runtime = @import("../runtime/mod.zig");

pub const MailboxSubscriptionJobClientError =
    mailbox_subscription_turn.MailboxSubscriptionTurnClientError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoReadyRelay,
        StaleAuthStep,
        RelayNotReady,
    };

pub const MailboxSubscriptionJobClientConfig = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    subscription_turn: mailbox_subscription_turn.MailboxSubscriptionTurnClientConfig = undefined,
};

pub const MailboxSubscriptionJobClientStorage = struct {
    subscription_turn: mailbox_subscription_turn.MailboxSubscriptionTurnClientStorage = .{},
};

pub const MailboxSubscriptionJobAuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedMailboxSubscriptionJobAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const MailboxSubscriptionJobRequest = mailbox_subscription_turn.MailboxSubscriptionTurnRequest;
pub const MailboxSubscriptionJobIntake = mailbox_subscription_turn.MailboxSubscriptionTurnIntake;

pub const MailboxSubscriptionJobReady = union(enum) {
    authenticate: PreparedMailboxSubscriptionJobAuthEvent,
    subscription: MailboxSubscriptionJobRequest,
};

pub const MailboxSubscriptionJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    subscribed: mailbox_subscription_turn.MailboxSubscriptionTurnResult,
};

pub const MailboxSubscriptionJobClient = struct {
    config: MailboxSubscriptionJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    subscription_turn: mailbox_subscription_turn.MailboxSubscriptionTurnClient,

    pub fn init(
        config: MailboxSubscriptionJobClientConfig,
        storage: *MailboxSubscriptionJobClientStorage,
    ) MailboxSubscriptionJobClient {
        storage.* = .{};
        return .{
            .config = configWithSubscriptionTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .subscription_turn = mailbox_subscription_turn.MailboxSubscriptionTurnClient.init(
                configWithSubscriptionTurn(config).subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn attach(
        config: MailboxSubscriptionJobClientConfig,
        storage: *MailboxSubscriptionJobClientStorage,
    ) MailboxSubscriptionJobClient {
        return .{
            .config = configWithSubscriptionTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .subscription_turn = mailbox_subscription_turn.MailboxSubscriptionTurnClient.attach(
                configWithSubscriptionTurn(config).subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn relayCount(self: *const MailboxSubscriptionJobClient) u8 {
        return self.subscription_turn.relayCount();
    }

    pub fn currentRelayUrl(self: *const MailboxSubscriptionJobClient) ?[]const u8 {
        return self.subscription_turn.currentRelayUrl();
    }

    pub fn currentRelayAuthChallenge(self: *const MailboxSubscriptionJobClient) ?[]const u8 {
        return self.subscription_turn.currentRelayAuthChallenge();
    }

    pub fn hydrateRelayListEventJson(
        self: *MailboxSubscriptionJobClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxSubscriptionJobClientError!u8 {
        return self.subscription_turn.hydrateRelayListEventJson(event_json, scratch);
    }

    pub fn selectRelay(
        self: *MailboxSubscriptionJobClient,
        relay_index: u8,
    ) MailboxSubscriptionJobClientError![]const u8 {
        return self.subscription_turn.selectRelay(relay_index);
    }

    pub fn markRelayConnected(
        self: *MailboxSubscriptionJobClient,
        relay_index: u8,
    ) MailboxSubscriptionJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "subscription_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *MailboxSubscriptionJobClient,
        relay_index: u8,
    ) MailboxSubscriptionJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "subscription_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *MailboxSubscriptionJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) MailboxSubscriptionJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "subscription_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const MailboxSubscriptionJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "subscription_turn", storage);
    }

    pub fn prepareJob(
        self: *MailboxSubscriptionJobClient,
        auth_storage: *MailboxSubscriptionJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
        created_at: u64,
    ) MailboxSubscriptionJobClientError!MailboxSubscriptionJobReady {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const auth_plan = self.subscription_turn.inspectAuth(&auth_storage_buf);
        if (auth_plan.nextStep()) |step| {
            return .{
                .authenticate = try self.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &step,
                    created_at,
                ),
            };
        }

        var subscription_storage_buf = runtime.RelayPoolSubscriptionStorage{};
        const subscription_plan = try self.subscription_turn.inspectSubscriptions(
            specs,
            &subscription_storage_buf,
        );
        _ = subscription_plan.nextStep() orelse return error.NoReadyRelay;
        return .{
            .subscription = try self.subscription_turn.beginTurn(
                request_output,
                specs,
            ),
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *MailboxSubscriptionJobClient,
        prepared: *const PreparedMailboxSubscriptionJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) MailboxSubscriptionJobClientError!MailboxSubscriptionJobResult {
        const descriptor = try self.subscription_turn.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = descriptor };
    }

    pub fn acceptSubscriptionMessageJson(
        self: *MailboxSubscriptionJobClient,
        request: *const MailboxSubscriptionJobRequest,
        relay_message_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxSubscriptionJobClientError!MailboxSubscriptionJobIntake {
        return self.subscription_turn.acceptSubscriptionMessageJson(
            request,
            relay_message_json,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
    }

    pub fn completeSubscriptionJob(
        self: *MailboxSubscriptionJobClient,
        output: []u8,
        request: *const MailboxSubscriptionJobRequest,
    ) MailboxSubscriptionJobClientError!MailboxSubscriptionJobResult {
        return .{ .subscribed = try self.subscription_turn.completeTurn(output, request) };
    }

    fn prepareAuthEvent(
        self: *MailboxSubscriptionJobClient,
        auth_storage: *MailboxSubscriptionJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) MailboxSubscriptionJobClientError!PreparedMailboxSubscriptionJobAuthEvent {
        const target = try self.selectAuthTarget(step);
        fillAuthEventStorage(auth_storage, target.relay.relay_url, target.challenge);

        const draft = local_operator.LocalEventDraft{
            .kind = noztr.nip42_auth.auth_event_kind,
            .created_at = created_at,
            .content = "",
            .tags = auth_storage.tags[0..],
        };
        var event = try self.local_operator.signDraft(&self.config.recipient_private_key, &draft);
        const event_json = try self.local_operator.serializeEventJson(event_json_output, &event);
        const auth_message_json = try serializeAuthClientMessage(auth_message_output, &event);
        return .{
            .relay = target.relay,
            .challenge = auth_storage.challengeText(),
            .event = event,
            .event_json = event_json,
            .auth_message_json = auth_message_json,
        };
    }

    fn selectAuthTarget(
        self: *const MailboxSubscriptionJobClient,
        step: *const runtime.RelayPoolAuthStep,
    ) MailboxSubscriptionJobClientError!relay_auth_client.RelayAuthTarget {
        const live_descriptor = self.subscription_turn.subscription_turn.relay_exchange.relay_pool.descriptor(
            step.entry.descriptor.relay_index,
        ) orelse return error.StaleAuthStep;
        if (!std.mem.eql(u8, live_descriptor.relay_url, step.entry.descriptor.relay_url)) {
            return error.StaleAuthStep;
        }

        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const plan = self.subscription_turn.inspectAuth(&auth_storage_buf);
        const current = plan.entry(step.entry.descriptor.relay_index) orelse return error.StaleAuthStep;
        if (!std.mem.eql(u8, current.descriptor.relay_url, step.entry.descriptor.relay_url)) {
            return error.StaleAuthStep;
        }
        if (current.action != .authenticate) return error.RelayNotReady;
        if (!std.mem.eql(u8, current.challenge, step.entry.challenge)) return error.StaleAuthStep;

        return .{
            .relay = current.descriptor,
            .challenge = current.challenge,
        };
    }
};

fn configWithSubscriptionTurn(
    config: MailboxSubscriptionJobClientConfig,
) MailboxSubscriptionJobClientConfig {
    var updated = config;
    updated.subscription_turn = .{
        .recipient_private_key = config.recipient_private_key,
        .subscription_turn = config.subscription_turn.subscription_turn,
    };
    return updated;
}

fn fillAuthEventStorage(
    storage: *MailboxSubscriptionJobAuthEventStorage,
    relay_url_text: []const u8,
    challenge: []const u8,
) void {
    std.debug.assert(relay_url_text.len <= relay_url.relay_url_max_bytes);
    std.debug.assert(challenge.len <= noztr.nip42_auth.challenge_max_bytes);

    storage.* = .{};
    storage.relay_url_len = @intCast(relay_url_text.len);
    storage.challenge_len = @intCast(challenge.len);
    @memcpy(storage.relay_url[0..relay_url_text.len], relay_url_text);
    @memcpy(storage.challenge[0..challenge.len], challenge);
    storage.relay_items = .{ "relay", storage.relayUrl() };
    storage.challenge_items = .{ "challenge", storage.challengeText() };
    storage.tags[0] = .{ .items = storage.relay_items[0..] };
    storage.tags[1] = .{ .items = storage.challenge_items[0..] };
}

fn serializeAuthClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) MailboxSubscriptionJobClientError![]const u8 {
    const message = noztr.nip01_message.ClientMessage{ .auth = .{ .event = event.* } };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

test "mailbox subscription job client exposes caller-owned config and storage" {
    var storage = MailboxSubscriptionJobClientStorage{};
    var client = MailboxSubscriptionJobClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
}

test "mailbox subscription job client drives auth-gated live mailbox intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage_buf = MailboxSubscriptionJobClientStorage{};
    var client = MailboxSubscriptionJobClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &storage_buf);

    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    try client.noteRelayAuthChallenge(0, "challenge-1");

    var sender_session = @import("../workflows/mod.zig").MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = @import("../workflows/mod.zig").MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "mailbox subscription job payload",
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

    var auth_storage = MailboxSubscriptionJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        specs[0..],
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        specs[0..],
        91,
    );
    try std.testing.expect(second_ready == .subscription);

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
        &second_ready.subscription,
        event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(event_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox subscription job payload",
        event_intake.envelope.?.direct_message.message.content,
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    _ = try client.acceptSubscriptionMessageJson(
        &second_ready.subscription,
        eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );

    const result = try client.completeSubscriptionJob(
        request_output[0..],
        &second_ready.subscription,
    );
    try std.testing.expect(result == .subscribed);
    try std.testing.expectEqual(@as(u32, 1), result.subscribed.event_count);
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
