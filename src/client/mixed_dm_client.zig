const std = @import("std");
const dm_capability = @import("dm_capability_client.zig");
const legacy_dm_replay_turn = @import("legacy_dm_replay_turn_client.zig");
const legacy_dm_subscription_turn = @import("legacy_dm_subscription_turn_client.zig");
const mailbox_replay_turn = @import("mailbox_replay_turn_client.zig");
const mailbox_subscription_turn = @import("mailbox_subscription_turn_client.zig");
const workflows = @import("../workflows/mod.zig");
const noztr = @import("noztr");

pub const MixedDmClientError =
    dm_capability.DmCapabilityClientError ||
    error{
        InvalidMailboxEnvelopeRecipients,
    };

pub const MixedDmClientConfig = struct {
    capability: dm_capability.DmCapabilityClientConfig = .{},
};

pub const MixedDmClientStorage = struct {
    capability: dm_capability.DmCapabilityClientStorage = .{},
};

pub const MixedDmProtocol = dm_capability.DmProtocol;
pub const MixedDmReplyPolicy = dm_capability.DmReplyPolicy;
pub const MixedDmReplyRouteRequest = dm_capability.DmReplySelectionRequest;
pub const MixedDmReplyRouteReason = dm_capability.DmReplySelectionReason;
pub const MixedDmReplyRoute = dm_capability.DmReplySelection;

pub const MixedDmObservedReplyRef = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const MixedDmObservedMailboxDirectMessage = struct {
    wrap_event_id: [32]u8,
    rumor_event_id: [32]u8,
    sender_pubkey: [32]u8,
    recipient_pubkey: [32]u8,
    recipient_count: u16,
    created_at: u64,
    reply_to: ?MixedDmObservedReplyRef = null,
    content: []const u8,
};

pub const MixedDmObservedMailboxFileMessage = struct {
    wrap_event_id: [32]u8,
    rumor_event_id: [32]u8,
    sender_pubkey: [32]u8,
    recipient_pubkey: [32]u8,
    recipient_count: u16,
    created_at: u64,
    reply_to: ?MixedDmObservedReplyRef = null,
    file_url: []const u8,
    file_type: []const u8,
};

pub const MixedDmObservedLegacyDirectMessage = struct {
    event_id: [32]u8,
    sender_pubkey: [32]u8,
    recipient_pubkey: [32]u8,
    created_at: u64,
    reply_to: ?MixedDmObservedReplyRef = null,
    content: []const u8,
};

pub const MixedDmObservedMessage = union(enum) {
    mailbox_direct_message: MixedDmObservedMailboxDirectMessage,
    mailbox_file_message: MixedDmObservedMailboxFileMessage,
    legacy_direct_message: MixedDmObservedLegacyDirectMessage,

    pub fn protocol(self: *const MixedDmObservedMessage) MixedDmProtocol {
        return switch (self.*) {
            .mailbox_direct_message,
            .mailbox_file_message,
            => .mailbox,
            .legacy_direct_message => .legacy,
        };
    }

    pub fn eventId(self: *const MixedDmObservedMessage) [32]u8 {
        return switch (self.*) {
            .mailbox_direct_message => |message| message.wrap_event_id,
            .mailbox_file_message => |message| message.wrap_event_id,
            .legacy_direct_message => |message| message.event_id,
        };
    }

    pub fn senderPubkey(self: *const MixedDmObservedMessage) [32]u8 {
        return switch (self.*) {
            .mailbox_direct_message => |message| message.sender_pubkey,
            .mailbox_file_message => |message| message.sender_pubkey,
            .legacy_direct_message => |message| message.sender_pubkey,
        };
    }

    pub fn recipientPubkey(self: *const MixedDmObservedMessage) [32]u8 {
        return switch (self.*) {
            .mailbox_direct_message => |message| message.recipient_pubkey,
            .mailbox_file_message => |message| message.recipient_pubkey,
            .legacy_direct_message => |message| message.recipient_pubkey,
        };
    }

    pub fn createdAt(self: *const MixedDmObservedMessage) u64 {
        return switch (self.*) {
            .mailbox_direct_message => |message| message.created_at,
            .mailbox_file_message => |message| message.created_at,
            .legacy_direct_message => |message| message.created_at,
        };
    }

    pub fn replyTo(self: *const MixedDmObservedMessage) ?MixedDmObservedReplyRef {
        return switch (self.*) {
            .mailbox_direct_message => |message| message.reply_to,
            .mailbox_file_message => |message| message.reply_to,
            .legacy_direct_message => |message| message.reply_to,
        };
    }
};

pub const MixedDmClient = struct {
    capability: dm_capability.DmCapabilityClient,

    pub fn init(
        config: MixedDmClientConfig,
        storage: *MixedDmClientStorage,
    ) MixedDmClient {
        storage.* = .{};
        return .{
            .capability = dm_capability.DmCapabilityClient.init(
                config.capability,
                &storage.capability,
            ),
        };
    }

    pub fn attach(
        config: MixedDmClientConfig,
        storage: *MixedDmClientStorage,
    ) MixedDmClient {
        return .{
            .capability = dm_capability.DmCapabilityClient.attach(
                config.capability,
                &storage.capability,
            ),
        };
    }

    pub fn inspectInboundProtocolKind(
        self: MixedDmClient,
        event_kind: u32,
    ) MixedDmClientError!MixedDmProtocol {
        return self.capability.inspectDmProtocolKind(event_kind);
    }

    pub fn selectReplyRoute(
        self: MixedDmClient,
        request: *const MixedDmReplyRouteRequest,
    ) MixedDmClientError!MixedDmReplyRoute {
        return self.capability.selectReplyProtocol(request);
    }

    pub fn selectReplyRouteForObservation(
        self: MixedDmClient,
        observation: *const MixedDmObservedMessage,
        policy: MixedDmReplyPolicy,
        recipient_mailbox_available: bool,
    ) MixedDmClientError!MixedDmReplyRoute {
        return self.selectReplyRoute(&.{
            .sender_protocol = observation.protocol(),
            .policy = policy,
            .recipient_mailbox_available = recipient_mailbox_available,
        });
    }

    pub fn observeMailboxEnvelope(
        _: MixedDmClient,
        envelope: *const workflows.dm.mailbox.MailboxEnvelopeOutcome,
    ) MixedDmClientError!MixedDmObservedMessage {
        return switch (envelope.*) {
            .direct_message => |message| .{
                .mailbox_direct_message = try observeMailboxDirectMessage(&message),
            },
            .file_message => |message| .{
                .mailbox_file_message = try observeMailboxFileMessage(&message),
            },
        };
    }

    pub fn observeLegacyMessage(
        _: MixedDmClient,
        message: *const workflows.dm.legacy.LegacyDmMessageOutcome,
    ) MixedDmObservedMessage {
        return .{
            .legacy_direct_message = observeLegacyDirectMessage(message),
        };
    }

    pub fn observeMailboxReplayIntake(
        self: MixedDmClient,
        intake: *const mailbox_replay_turn.MailboxReplayTurnIntake,
    ) MixedDmClientError!?MixedDmObservedMessage {
        const envelope = intake.envelope orelse return null;
        return try self.observeMailboxEnvelope(&envelope);
    }

    pub fn observeMailboxSubscriptionIntake(
        self: MixedDmClient,
        intake: *const mailbox_subscription_turn.MailboxSubscriptionTurnIntake,
    ) MixedDmClientError!?MixedDmObservedMessage {
        const envelope = intake.envelope orelse return null;
        return try self.observeMailboxEnvelope(&envelope);
    }

    pub fn observeLegacyReplayIntake(
        self: MixedDmClient,
        intake: *const legacy_dm_replay_turn.LegacyDmReplayTurnIntake,
    ) ?MixedDmObservedMessage {
        const message = intake.message orelse return null;
        return self.observeLegacyMessage(&message);
    }

    pub fn observeLegacySubscriptionIntake(
        self: MixedDmClient,
        intake: *const legacy_dm_subscription_turn.LegacyDmSubscriptionTurnIntake,
    ) ?MixedDmObservedMessage {
        const message = intake.message orelse return null;
        return self.observeLegacyMessage(&message);
    }
};

fn observeMailboxDirectMessage(
    message: *const workflows.dm.mailbox.MailboxMessageOutcome,
) MixedDmClientError!MixedDmObservedMailboxDirectMessage {
    if (message.message.recipients.len == 0) return error.InvalidMailboxEnvelopeRecipients;
    return .{
        .wrap_event_id = message.wrap_event_id,
        .rumor_event_id = message.rumor_event.id,
        .sender_pubkey = message.rumor_event.pubkey,
        .recipient_pubkey = message.message.recipients[0].pubkey,
        .recipient_count = @intCast(message.message.recipients.len),
        .created_at = message.rumor_event.created_at,
        .reply_to = observedReplyFromMailbox(message.message.reply_to),
        .content = message.message.content,
    };
}

fn observeMailboxFileMessage(
    message: *const workflows.dm.mailbox.MailboxFileMessageOutcome,
) MixedDmClientError!MixedDmObservedMailboxFileMessage {
    if (message.file_message.recipients.len == 0) return error.InvalidMailboxEnvelopeRecipients;
    return .{
        .wrap_event_id = message.wrap_event_id,
        .rumor_event_id = message.rumor_event.id,
        .sender_pubkey = message.rumor_event.pubkey,
        .recipient_pubkey = message.file_message.recipients[0].pubkey,
        .recipient_count = @intCast(message.file_message.recipients.len),
        .created_at = message.rumor_event.created_at,
        .reply_to = observedReplyFromMailbox(message.file_message.reply_to),
        .file_url = message.file_message.file_url,
        .file_type = message.file_message.file_type,
    };
}

fn observeLegacyDirectMessage(
    message: *const workflows.dm.legacy.LegacyDmMessageOutcome,
) MixedDmObservedLegacyDirectMessage {
    return .{
        .event_id = message.event.id,
        .sender_pubkey = message.event.pubkey,
        .recipient_pubkey = message.message.recipient_pubkey,
        .created_at = message.event.created_at,
        .reply_to = observedReplyFromLegacy(message.message.reply_to),
        .content = message.plaintext,
    };
}

fn observedReplyFromMailbox(
    reply_to: ?noztr.nip17_private_messages.DmReplyRef,
) ?MixedDmObservedReplyRef {
    const reply = reply_to orelse return null;
    return .{
        .event_id = reply.event_id,
        .relay_hint = reply.relay_hint,
    };
}

fn observedReplyFromLegacy(
    reply_to: ?noztr.nip04.Nip04ReplyRef,
) ?MixedDmObservedReplyRef {
    const reply = reply_to orelse return null;
    return .{
        .event_id = reply.event_id,
        .relay_hint = reply.relay_hint,
    };
}

test "mixed dm client normalizes mailbox and legacy observations and keeps reply routing explicit" {
    var storage = MixedDmClientStorage{};
    const client = MixedDmClient.init(.{}, &storage);

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var relay_list_client_storage = dm_capability.DmCapabilityClientStorage{};
    const relay_list_client = dm_capability.DmCapabilityClient.init(.{}, &relay_list_client_storage);
    var relay_tags: [1]noztr.nip01_event.EventTag = undefined;
    var built_tags: [1]noztr.nip17_private_messages.BuiltTag = undefined;
    var relay_list_storage = dm_capability.MailboxRelayListDraftStorage.init(
        relay_tags[0..],
        built_tags[0..],
    );
    var relay_list_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const relay_list = try relay_list_client.prepareMailboxRelayListPublish(
        relay_list_json_output[0..],
        &relay_list_storage,
        &recipient_secret,
        &.{ .created_at = 41, .relays = &.{"wss://dm.one"} },
    );

    var outbound = workflows.dm.mailbox.MailboxOutboundBuffer{};
    var delivery_storage = workflows.dm.mailbox.MailboxDeliveryStorage{};
    var sender_session = workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    const delivery = try sender_session.planDirectMessageDelivery(
        &outbound,
        &delivery_storage,
        relay_list.event_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "mailbox hello",
            .created_at = 42,
            .wrap_signer_private_key = sender_secret,
            .seal_nonce = [_]u8{0x33} ** 32,
            .wrap_nonce = [_]u8{0x44} ** 32,
        },
        arena.allocator(),
    );

    var recipient_session = workflows.dm.mailbox.MailboxSession.init(&recipient_secret);
    _ = try recipient_session.hydrateRelayListEventJson(relay_list.event_json, arena.allocator());
    try recipient_session.markCurrentRelayConnected();
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const mailbox_envelope = try recipient_session.acceptWrappedEnvelopeJson(
        delivery.wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );
    const mailbox_observation = try client.observeMailboxEnvelope(&mailbox_envelope);
    try std.testing.expectEqual(.mailbox, mailbox_observation.protocol());
    try std.testing.expectEqualStrings(
        "mailbox hello",
        mailbox_observation.mailbox_direct_message.content,
    );
    try std.testing.expectEqual(@as(u16, 1), mailbox_observation.mailbox_direct_message.recipient_count);
    try std.testing.expect(std.mem.eql(
        u8,
        &recipient_pubkey,
        &mailbox_observation.recipientPubkey(),
    ));

    var legacy_outbound = workflows.dm.legacy.LegacyDmOutboundStorage{};
    const legacy_sender = workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    const legacy_prepared = try legacy_sender.buildDirectMessageEvent(&legacy_outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy hello",
        .created_at = 43,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const legacy_recipient = workflows.dm.legacy.LegacyDmSession.init(&recipient_secret);
    const legacy_message = try legacy_recipient.acceptDirectMessageEvent(
        &legacy_prepared.event,
        plaintext_output[0..],
    );
    const legacy_observation = client.observeLegacyMessage(&legacy_message);
    try std.testing.expectEqual(.legacy, legacy_observation.protocol());
    try std.testing.expectEqualStrings(
        "legacy hello",
        legacy_observation.legacy_direct_message.content,
    );

    const reply_route = try client.selectReplyRouteForObservation(
        &mailbox_observation,
        .sender_protocol,
        true,
    );
    try std.testing.expectEqual(.mailbox, reply_route.protocol);

    const fallback_legacy = try client.selectReplyRouteForObservation(
        &legacy_observation,
        .prefer_mailbox,
        false,
    );
    try std.testing.expectEqual(.legacy, fallback_legacy.protocol);
}

test "mixed dm client keeps replay and subscription intake normalization bounded" {
    var storage = MixedDmClientStorage{};
    const client = MixedDmClient.init(.{}, &storage);

    const sender_secret = [_]u8{0x61} ** 32;
    const recipient_secret = [_]u8{0x72} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var relay_list_client_storage = dm_capability.DmCapabilityClientStorage{};
    const relay_list_client = dm_capability.DmCapabilityClient.init(.{}, &relay_list_client_storage);
    var relay_tags: [1]noztr.nip01_event.EventTag = undefined;
    var built_tags: [1]noztr.nip17_private_messages.BuiltTag = undefined;
    var relay_list_storage = dm_capability.MailboxRelayListDraftStorage.init(
        relay_tags[0..],
        built_tags[0..],
    );
    var relay_list_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const relay_list = try relay_list_client.prepareMailboxRelayListPublish(
        relay_list_json_output[0..],
        &relay_list_storage,
        &recipient_secret,
        &.{ .created_at = 49, .relays = &.{"wss://dm.one"} },
    );

    var outbound = workflows.dm.mailbox.MailboxOutboundBuffer{};
    var delivery_storage = workflows.dm.mailbox.MailboxDeliveryStorage{};
    var mailbox_sender = workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    const delivery = try mailbox_sender.planDirectMessageDelivery(
        &outbound,
        &delivery_storage,
        relay_list.event_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "mailbox replay",
            .created_at = 50,
            .wrap_signer_private_key = sender_secret,
            .seal_nonce = [_]u8{0x83} ** 32,
            .wrap_nonce = [_]u8{0x94} ** 32,
        },
        arena.allocator(),
    );
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    var mailbox_recipient = workflows.dm.mailbox.MailboxSession.init(&recipient_secret);
    _ = try mailbox_recipient.hydrateRelayListEventJson(relay_list.event_json, arena.allocator());
    try mailbox_recipient.markCurrentRelayConnected();
    const mailbox_envelope = try mailbox_recipient.acceptWrappedEnvelopeJson(
        delivery.wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );

    const mailbox_replay_intake = mailbox_replay_turn.MailboxReplayTurnIntake{
        .replay = undefined,
        .envelope = mailbox_envelope,
    };
    try std.testing.expect((try client.observeMailboxReplayIntake(&mailbox_replay_intake)) != null);

    const mailbox_subscription_intake = mailbox_subscription_turn.MailboxSubscriptionTurnIntake{
        .subscription = undefined,
        .envelope = mailbox_envelope,
    };
    try std.testing.expect((try client.observeMailboxSubscriptionIntake(&mailbox_subscription_intake)) != null);

    var legacy_outbound = workflows.dm.legacy.LegacyDmOutboundStorage{};
    const legacy_sender = workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    const legacy_prepared = try legacy_sender.buildDirectMessageEvent(&legacy_outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy replay",
        .created_at = 51,
        .iv = [_]u8{0xa5} ** noztr.limits.nip04_iv_bytes,
    });
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const legacy_recipient = workflows.dm.legacy.LegacyDmSession.init(&recipient_secret);
    const legacy_message = try legacy_recipient.acceptDirectMessageEvent(
        &legacy_prepared.event,
        plaintext_output[0..],
    );

    const legacy_replay_intake = legacy_dm_replay_turn.LegacyDmReplayTurnIntake{
        .replay = undefined,
        .message = legacy_message,
    };
    try std.testing.expect(client.observeLegacyReplayIntake(&legacy_replay_intake) != null);

    const legacy_subscription_intake = legacy_dm_subscription_turn.LegacyDmSubscriptionTurnIntake{
        .subscription = undefined,
        .message = legacy_message,
    };
    try std.testing.expect(client.observeLegacySubscriptionIntake(&legacy_subscription_intake) != null);
}
