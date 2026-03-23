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
    workflows.dm.mailbox.MailboxError ||
    workflows.dm.legacy.LegacyDmError ||
    error{
        InvalidMailboxEnvelopeRecipients,
        MissingRecipientMailboxRelayList,
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

pub const MixedDmObservedMessageIdentity = struct {
    protocol: MixedDmProtocol,
    event_id: [32]u8,
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

    pub fn identity(self: *const MixedDmObservedMessage) MixedDmObservedMessageIdentity {
        return .{
            .protocol = self.protocol(),
            .event_id = self.eventId(),
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

pub const MixedDmSenderProtocolMemoryRecord = struct {
    occupied: bool = false,
    peer_pubkey: [32]u8 = [_]u8{0} ** 32,
    protocol: MixedDmProtocol = .legacy,
    last_observed_at: u64 = 0,
};

pub const MixedDmSenderProtocolMemory = struct {
    records: []MixedDmSenderProtocolMemoryRecord,

    pub fn init(records: []MixedDmSenderProtocolMemoryRecord) MixedDmSenderProtocolMemory {
        for (records) |*record| record.* = .{};
        return .{ .records = records };
    }

    pub fn protocolFor(
        self: *const MixedDmSenderProtocolMemory,
        peer_pubkey: *const [32]u8,
    ) ?MixedDmProtocol {
        for (self.records) |record| {
            if (!record.occupied) continue;
            if (std.mem.eql(u8, &record.peer_pubkey, peer_pubkey)) return record.protocol;
        }
        return null;
    }

    pub fn remember(
        self: *MixedDmSenderProtocolMemory,
        peer_pubkey: *const [32]u8,
        protocol: MixedDmProtocol,
        observed_at: u64,
    ) void {
        var first_free: ?usize = null;
        var oldest_index: usize = 0;
        var oldest_found = false;

        for (self.records, 0..) |*record, index| {
            if (!record.occupied) {
                if (first_free == null) first_free = index;
                continue;
            }

            if (std.mem.eql(u8, &record.peer_pubkey, peer_pubkey)) {
                if (observed_at >= record.last_observed_at) {
                    record.protocol = protocol;
                    record.last_observed_at = observed_at;
                }
                return;
            }

            if (!oldest_found or record.last_observed_at < self.records[oldest_index].last_observed_at) {
                oldest_index = index;
                oldest_found = true;
            }
        }

        const target_index = first_free orelse oldest_index;
        self.records[target_index] = .{
            .occupied = true,
            .peer_pubkey = peer_pubkey.*,
            .protocol = protocol,
            .last_observed_at = observed_at,
        };
    }
};

pub const MixedDmRememberedReplyRequest = struct {
    peer_pubkey: [32]u8,
    fallback_sender_protocol: MixedDmProtocol,
    policy: MixedDmReplyPolicy = .sender_protocol,
    recipient_mailbox_available: bool = false,
};

pub const MixedDmRememberedReplyRoute = struct {
    route: MixedDmReplyRoute,
    sender_protocol: MixedDmProtocol,
    remembered: bool,
};

pub const MixedDmDedupRecord = struct {
    occupied: bool = false,
    identity: MixedDmObservedMessageIdentity = .{
        .protocol = .legacy,
        .event_id = [_]u8{0} ** 32,
    },
    last_seen_at: u64 = 0,
};

pub const MixedDmDedupResult = enum {
    first_seen,
    duplicate,
};

pub const MixedDmDedupMemory = struct {
    records: []MixedDmDedupRecord,

    pub fn init(records: []MixedDmDedupRecord) MixedDmDedupMemory {
        for (records) |*record| record.* = .{};
        return .{ .records = records };
    }

    pub fn hasSeen(
        self: *const MixedDmDedupMemory,
        identity: *const MixedDmObservedMessageIdentity,
    ) bool {
        for (self.records) |record| {
            if (!record.occupied) continue;
            if (record.identity.protocol != identity.protocol) continue;
            if (std.mem.eql(u8, &record.identity.event_id, &identity.event_id)) return true;
        }
        return false;
    }

    pub fn note(
        self: *MixedDmDedupMemory,
        identity: *const MixedDmObservedMessageIdentity,
        seen_at: u64,
    ) MixedDmDedupResult {
        var first_free: ?usize = null;
        var oldest_index: usize = 0;
        var oldest_found = false;

        for (self.records, 0..) |*record, index| {
            if (!record.occupied) {
                if (first_free == null) first_free = index;
                continue;
            }

            if (record.identity.protocol == identity.protocol and
                std.mem.eql(u8, &record.identity.event_id, &identity.event_id))
            {
                if (seen_at >= record.last_seen_at) record.last_seen_at = seen_at;
                return .duplicate;
            }

            if (!oldest_found or record.last_seen_at < self.records[oldest_index].last_seen_at) {
                oldest_index = index;
                oldest_found = true;
            }
        }

        const target_index = first_free orelse oldest_index;
        self.records[target_index] = .{
            .occupied = true,
            .identity = identity.*,
            .last_seen_at = seen_at,
        };
        return .first_seen;
    }
};

pub const MixedDmOutboundStorage = struct {
    legacy: workflows.dm.legacy.LegacyDmOutboundStorage = .{},
    mailbox_outbound: workflows.dm.mailbox.MailboxOutboundBuffer = .{},
    mailbox_delivery: workflows.dm.mailbox.MailboxDeliveryStorage = .{},
};

pub const MixedDmDirectMessageRequest = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    reply_to: ?MixedDmObservedReplyRef = null,
    content: []const u8,
    created_at: u64,
    legacy_iv: [noztr.limits.nip04_iv_bytes]u8,
    recipient_relay_list_event_json: ?[]const u8 = null,
    sender_relay_list_event_json: ?[]const u8 = null,
    mailbox_wrap_signer_private_key: [32]u8,
    mailbox_seal_nonce: [32]u8,
    mailbox_wrap_nonce: [32]u8,
};

pub const MixedDmRememberedDirectMessageRequest = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    reply_to: ?MixedDmObservedReplyRef = null,
    content: []const u8,
    created_at: u64,
    fallback_sender_protocol: MixedDmProtocol,
    policy: MixedDmReplyPolicy = .sender_protocol,
    recipient_mailbox_available: bool = false,
    legacy_iv: [noztr.limits.nip04_iv_bytes]u8,
    recipient_relay_list_event_json: ?[]const u8 = null,
    sender_relay_list_event_json: ?[]const u8 = null,
    mailbox_wrap_signer_private_key: [32]u8,
    mailbox_seal_nonce: [32]u8,
    mailbox_wrap_nonce: [32]u8,
};

pub const MixedDmPreparedMailboxDirectMessage = struct {
    delivery: workflows.dm.mailbox.MailboxDeliveryPlan,
};

pub const MixedDmPreparedLegacyDirectMessage = struct {
    event: noztr.nip01_event.Event,
    event_json: []const u8,
};

pub const MixedDmPreparedDirectMessage = union(enum) {
    mailbox: MixedDmPreparedMailboxDirectMessage,
    legacy: MixedDmPreparedLegacyDirectMessage,

    pub fn protocol(self: *const MixedDmPreparedDirectMessage) MixedDmProtocol {
        return switch (self.*) {
            .mailbox => .mailbox,
            .legacy => .legacy,
        };
    }
};

pub const MixedDmRememberedPreparedDirectMessage = struct {
    prepared: MixedDmPreparedDirectMessage,
    sender_protocol: MixedDmProtocol,
    remembered: bool,
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

    pub fn rememberObservedSenderProtocol(
        _: MixedDmClient,
        memory: *MixedDmSenderProtocolMemory,
        observation: *const MixedDmObservedMessage,
    ) void {
        const sender_pubkey = observation.senderPubkey();
        memory.remember(
            &sender_pubkey,
            observation.protocol(),
            observation.createdAt(),
        );
    }

    pub fn rememberSenderProtocol(
        _: MixedDmClient,
        memory: *MixedDmSenderProtocolMemory,
        peer_pubkey: *const [32]u8,
        protocol: MixedDmProtocol,
        observed_at: u64,
    ) void {
        memory.remember(peer_pubkey, protocol, observed_at);
    }

    pub fn inspectRememberedSenderProtocol(
        _: MixedDmClient,
        memory: *const MixedDmSenderProtocolMemory,
        peer_pubkey: *const [32]u8,
    ) ?MixedDmProtocol {
        return memory.protocolFor(peer_pubkey);
    }

    pub fn selectRememberedReplyRoute(
        self: MixedDmClient,
        memory: *const MixedDmSenderProtocolMemory,
        request: *const MixedDmRememberedReplyRequest,
    ) MixedDmClientError!MixedDmRememberedReplyRoute {
        const remembered_protocol = memory.protocolFor(&request.peer_pubkey);
        const sender_protocol = remembered_protocol orelse request.fallback_sender_protocol;
        return .{
            .route = try self.selectReplyRoute(&.{
                .sender_protocol = sender_protocol,
                .policy = request.policy,
                .recipient_mailbox_available = request.recipient_mailbox_available,
            }),
            .sender_protocol = sender_protocol,
            .remembered = remembered_protocol != null,
        };
    }

    pub fn identifyObservedMessage(
        _: MixedDmClient,
        observation: *const MixedDmObservedMessage,
    ) MixedDmObservedMessageIdentity {
        return observation.identity();
    }

    pub fn hasSeenObservedMessage(
        _: MixedDmClient,
        memory: *const MixedDmDedupMemory,
        observation: *const MixedDmObservedMessage,
    ) bool {
        const identity = observation.identity();
        return memory.hasSeen(&identity);
    }

    pub fn noteObservedMessage(
        _: MixedDmClient,
        memory: *MixedDmDedupMemory,
        observation: *const MixedDmObservedMessage,
    ) MixedDmDedupResult {
        const identity = observation.identity();
        return memory.note(&identity, observation.createdAt());
    }

    pub fn prepareDirectMessage(
        _: MixedDmClient,
        event_json_output: []u8,
        sender_secret_key: *const [32]u8,
        storage: *MixedDmOutboundStorage,
        protocol: MixedDmProtocol,
        request: *const MixedDmDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MixedDmClientError!MixedDmPreparedDirectMessage {
        return switch (protocol) {
            .legacy => prepareLegacyDirectMessage(
                event_json_output,
                sender_secret_key,
                &storage.legacy,
                request,
            ),
            .mailbox => try prepareMailboxDirectMessage(
                sender_secret_key,
                storage,
                request,
                scratch,
            ),
        };
    }

    pub fn prepareRememberedDirectMessage(
        self: MixedDmClient,
        event_json_output: []u8,
        sender_secret_key: *const [32]u8,
        storage: *MixedDmOutboundStorage,
        memory: *const MixedDmSenderProtocolMemory,
        request: *const MixedDmRememberedDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MixedDmClientError!MixedDmRememberedPreparedDirectMessage {
        const route = try self.selectRememberedReplyRoute(memory, &.{
            .peer_pubkey = request.recipient_pubkey,
            .fallback_sender_protocol = request.fallback_sender_protocol,
            .policy = request.policy,
            .recipient_mailbox_available = request.recipient_mailbox_available,
        });
        return .{
            .prepared = try self.prepareDirectMessage(
                event_json_output,
                sender_secret_key,
                storage,
                route.route.protocol,
                &.{
                    .recipient_pubkey = request.recipient_pubkey,
                    .recipient_relay_hint = request.recipient_relay_hint,
                    .reply_to = request.reply_to,
                    .content = request.content,
                    .created_at = request.created_at,
                    .legacy_iv = request.legacy_iv,
                    .recipient_relay_list_event_json = request.recipient_relay_list_event_json,
                    .sender_relay_list_event_json = request.sender_relay_list_event_json,
                    .mailbox_wrap_signer_private_key = request.mailbox_wrap_signer_private_key,
                    .mailbox_seal_nonce = request.mailbox_seal_nonce,
                    .mailbox_wrap_nonce = request.mailbox_wrap_nonce,
                },
                scratch,
            ),
            .sender_protocol = route.sender_protocol,
            .remembered = route.remembered,
        };
    }
};

fn prepareLegacyDirectMessage(
    event_json_output: []u8,
    sender_secret_key: *const [32]u8,
    storage: *workflows.dm.legacy.LegacyDmOutboundStorage,
    request: *const MixedDmDirectMessageRequest,
) MixedDmClientError!MixedDmPreparedDirectMessage {
    const session = workflows.dm.legacy.LegacyDmSession.init(sender_secret_key);
    const prepared = try session.buildDirectMessageEvent(storage, &.{
        .recipient_pubkey = request.recipient_pubkey,
        .recipient_relay_hint = request.recipient_relay_hint,
        .reply_to = legacyReplyFromMixed(request.reply_to),
        .content = request.content,
        .created_at = request.created_at,
        .iv = request.legacy_iv,
    });
    return .{
        .legacy = .{
            .event = prepared.event,
            .event_json = try session.serializeDirectMessageEventJson(event_json_output, &prepared.event),
        },
    };
}

fn prepareMailboxDirectMessage(
    sender_secret_key: *const [32]u8,
    storage: *MixedDmOutboundStorage,
    request: *const MixedDmDirectMessageRequest,
    scratch: std.mem.Allocator,
) MixedDmClientError!MixedDmPreparedDirectMessage {
    const recipient_relay_list_event_json =
        request.recipient_relay_list_event_json orelse return error.MissingRecipientMailboxRelayList;
    var session = workflows.dm.mailbox.MailboxSession.init(sender_secret_key);
    return .{
        .mailbox = .{
            .delivery = try session.planDirectMessageDelivery(
                &storage.mailbox_outbound,
                &storage.mailbox_delivery,
                recipient_relay_list_event_json,
                request.sender_relay_list_event_json,
                &.{
                    .recipient_pubkey = request.recipient_pubkey,
                    .recipient_relay_hint = request.recipient_relay_hint,
                    .reply_to = mailboxReplyFromMixed(request.reply_to),
                    .content = request.content,
                    .created_at = request.created_at,
                    .wrap_signer_private_key = request.mailbox_wrap_signer_private_key,
                    .seal_nonce = request.mailbox_seal_nonce,
                    .wrap_nonce = request.mailbox_wrap_nonce,
                },
                scratch,
            ),
        },
    };
}

fn mailboxReplyFromMixed(reply_to: ?MixedDmObservedReplyRef) ?noztr.nip17_private_messages.DmReplyRef {
    const reply = reply_to orelse return null;
    return .{
        .event_id = reply.event_id,
        .relay_hint = reply.relay_hint,
    };
}

fn legacyReplyFromMixed(reply_to: ?MixedDmObservedReplyRef) ?noztr.nip04.Nip04ReplyRef {
    const reply = reply_to orelse return null;
    return .{
        .event_id = reply.event_id,
        .relay_hint = reply.relay_hint,
    };
}

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

test "mixed dm client keeps caller-owned sender protocol memory bounded and explicit" {
    var storage = MixedDmClientStorage{};
    const client = MixedDmClient.init(.{}, &storage);

    const peer_mailbox = [_]u8{0x11} ** 32;
    const peer_legacy = [_]u8{0x22} ** 32;
    const unknown_peer = [_]u8{0x33} ** 32;

    var records: [2]MixedDmSenderProtocolMemoryRecord = undefined;
    var memory = MixedDmSenderProtocolMemory.init(records[0..]);

    client.rememberSenderProtocol(&memory, &peer_mailbox, .mailbox, 100);
    client.rememberSenderProtocol(&memory, &peer_legacy, .legacy, 101);
    try std.testing.expectEqual(.mailbox, client.inspectRememberedSenderProtocol(&memory, &peer_mailbox).?);
    try std.testing.expectEqual(.legacy, client.inspectRememberedSenderProtocol(&memory, &peer_legacy).?);
    try std.testing.expect(client.inspectRememberedSenderProtocol(&memory, &unknown_peer) == null);

    const remembered_route = try client.selectRememberedReplyRoute(&memory, &.{
        .peer_pubkey = peer_mailbox,
        .fallback_sender_protocol = .legacy,
        .policy = .sender_protocol,
        .recipient_mailbox_available = true,
    });
    try std.testing.expect(remembered_route.remembered);
    try std.testing.expectEqual(.mailbox, remembered_route.sender_protocol);
    try std.testing.expectEqual(.mailbox, remembered_route.route.protocol);

    const fallback_route = try client.selectRememberedReplyRoute(&memory, &.{
        .peer_pubkey = unknown_peer,
        .fallback_sender_protocol = .legacy,
        .policy = .prefer_mailbox,
        .recipient_mailbox_available = false,
    });
    try std.testing.expect(!fallback_route.remembered);
    try std.testing.expectEqual(.legacy, fallback_route.sender_protocol);
    try std.testing.expectEqual(.legacy, fallback_route.route.protocol);

    const replacement_peer = [_]u8{0x44} ** 32;
    client.rememberSenderProtocol(&memory, &replacement_peer, .mailbox, 50);
    try std.testing.expect(client.inspectRememberedSenderProtocol(&memory, &peer_mailbox) == null);
}

test "mixed dm client dedupes observed mailbox and legacy messages without owning inbox state" {
    var storage = MixedDmClientStorage{};
    const client = MixedDmClient.init(.{}, &storage);

    const mailbox_observation: MixedDmObservedMessage = .{
        .mailbox_direct_message = .{
            .wrap_event_id = [_]u8{0x11} ** 32,
            .rumor_event_id = [_]u8{0x12} ** 32,
            .sender_pubkey = [_]u8{0x21} ** 32,
            .recipient_pubkey = [_]u8{0x22} ** 32,
            .recipient_count = 1,
            .created_at = 100,
            .content = "mailbox",
        },
    };
    const legacy_observation: MixedDmObservedMessage = .{
        .legacy_direct_message = .{
            .event_id = [_]u8{0x31} ** 32,
            .sender_pubkey = [_]u8{0x41} ** 32,
            .recipient_pubkey = [_]u8{0x42} ** 32,
            .created_at = 101,
            .content = "legacy",
        },
    };

    var records: [2]MixedDmDedupRecord = undefined;
    var memory = MixedDmDedupMemory.init(records[0..]);

    try std.testing.expectEqual(.first_seen, client.noteObservedMessage(&memory, &mailbox_observation));
    try std.testing.expect(client.hasSeenObservedMessage(&memory, &mailbox_observation));
    try std.testing.expectEqual(.duplicate, client.noteObservedMessage(&memory, &mailbox_observation));
    try std.testing.expectEqual(.first_seen, client.noteObservedMessage(&memory, &legacy_observation));

    const replacement: MixedDmObservedMessage = .{
        .mailbox_direct_message = .{
            .wrap_event_id = [_]u8{0x51} ** 32,
            .rumor_event_id = [_]u8{0x52} ** 32,
            .sender_pubkey = [_]u8{0x61} ** 32,
            .recipient_pubkey = [_]u8{0x62} ** 32,
            .recipient_count = 1,
            .created_at = 90,
            .content = "replacement",
        },
    };
    try std.testing.expectEqual(.first_seen, client.noteObservedMessage(&memory, &replacement));
    try std.testing.expect(!client.hasSeenObservedMessage(&memory, &mailbox_observation));
}

test "mixed dm client prepares mailbox and legacy outbound work explicitly" {
    var storage = MixedDmClientStorage{};
    const client = MixedDmClient.init(.{}, &storage);

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);
    const reply_event_id = [_]u8{0x99} ** 32;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var capability_storage = dm_capability.DmCapabilityClientStorage{};
    const capability = dm_capability.DmCapabilityClient.init(.{}, &capability_storage);
    var relay_tags: [1]noztr.nip01_event.EventTag = undefined;
    var built_tags: [1]noztr.nip17_private_messages.BuiltTag = undefined;
    var relay_list_storage = dm_capability.MailboxRelayListDraftStorage.init(
        relay_tags[0..],
        built_tags[0..],
    );
    var relay_list_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const relay_list = try capability.prepareMailboxRelayListPublish(
        relay_list_json_output[0..],
        &relay_list_storage,
        &recipient_secret,
        &.{ .created_at = 99, .relays = &.{"wss://dm.one"} },
    );

    var outbound_storage = MixedDmOutboundStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const mailbox = try client.prepareDirectMessage(
        event_json_output[0..],
        &sender_secret,
        &outbound_storage,
        .mailbox,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://dm.one",
            .reply_to = .{
                .event_id = reply_event_id,
                .relay_hint = "wss://thread.example",
            },
            .content = "mailbox mixed outbound",
            .created_at = 100,
            .legacy_iv = [_]u8{0xaa} ** noztr.limits.nip04_iv_bytes,
            .recipient_relay_list_event_json = relay_list.event_json,
            .mailbox_wrap_signer_private_key = sender_secret,
            .mailbox_seal_nonce = [_]u8{0xbb} ** 32,
            .mailbox_wrap_nonce = [_]u8{0xcc} ** 32,
        },
        arena.allocator(),
    );
    try std.testing.expectEqual(.mailbox, mailbox.protocol());
    try std.testing.expectEqualStrings("wss://dm.one", mailbox.mailbox.delivery.nextStep().?.relay_url);

    const legacy = try client.prepareDirectMessage(
        event_json_output[0..],
        &sender_secret,
        &outbound_storage,
        .legacy,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://legacy.one",
            .reply_to = .{
                .event_id = reply_event_id,
                .relay_hint = "wss://thread.example",
            },
            .content = "legacy mixed outbound",
            .created_at = 101,
            .legacy_iv = [_]u8{0xdd} ** noztr.limits.nip04_iv_bytes,
            .mailbox_wrap_signer_private_key = sender_secret,
            .mailbox_seal_nonce = [_]u8{0} ** 32,
            .mailbox_wrap_nonce = [_]u8{0} ** 32,
        },
        arena.allocator(),
    );
    try std.testing.expectEqual(.legacy, legacy.protocol());
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const legacy_session = workflows.dm.legacy.LegacyDmSession.init(&recipient_secret);
    const accepted = try legacy_session.acceptDirectMessageEvent(&legacy.legacy.event, plaintext_output[0..]);
    try std.testing.expect(accepted.message.reply_to != null);
    try std.testing.expectEqualSlices(u8, &reply_event_id, &accepted.message.reply_to.?.event_id);
}

test "mixed dm client prepares remembered outbound route over caller-owned memory" {
    var storage = MixedDmClientStorage{};
    const client = MixedDmClient.init(.{}, &storage);

    const sender_secret = [_]u8{0x31} ** 32;
    const recipient_secret = [_]u8{0x42} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var capability_storage = dm_capability.DmCapabilityClientStorage{};
    const capability = dm_capability.DmCapabilityClient.init(.{}, &capability_storage);
    var relay_tags: [1]noztr.nip01_event.EventTag = undefined;
    var built_tags: [1]noztr.nip17_private_messages.BuiltTag = undefined;
    var relay_list_storage = dm_capability.MailboxRelayListDraftStorage.init(
        relay_tags[0..],
        built_tags[0..],
    );
    var relay_list_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const relay_list = try capability.prepareMailboxRelayListPublish(
        relay_list_json_output[0..],
        &relay_list_storage,
        &recipient_secret,
        &.{ .created_at = 109, .relays = &.{"wss://dm.one"} },
    );

    var memory_records: [2]MixedDmSenderProtocolMemoryRecord = undefined;
    var memory = MixedDmSenderProtocolMemory.init(memory_records[0..]);
    client.rememberSenderProtocol(&memory, &recipient_pubkey, .mailbox, 110);

    var outbound_storage = MixedDmOutboundStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareRememberedDirectMessage(
        event_json_output[0..],
        &sender_secret,
        &outbound_storage,
        &memory,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://dm.one",
            .content = "remembered mailbox outbound",
            .created_at = 111,
            .fallback_sender_protocol = .legacy,
            .policy = .sender_protocol,
            .recipient_mailbox_available = true,
            .legacy_iv = [_]u8{0xee} ** noztr.limits.nip04_iv_bytes,
            .recipient_relay_list_event_json = relay_list.event_json,
            .mailbox_wrap_signer_private_key = sender_secret,
            .mailbox_seal_nonce = [_]u8{0xf1} ** 32,
            .mailbox_wrap_nonce = [_]u8{0xf2} ** 32,
        },
        arena.allocator(),
    );
    try std.testing.expect(prepared.remembered);
    try std.testing.expectEqual(.mailbox, prepared.sender_protocol);
    try std.testing.expectEqual(.mailbox, prepared.prepared.protocol());
}
