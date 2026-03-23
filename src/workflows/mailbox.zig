const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const relay_pool = @import("../relay/pool.zig");
const relay_session = @import("../relay/session.zig");
const relay_url = @import("../relay/url.zig");
const shared_runtime = @import("../runtime/mod.zig");

pub const max_seen_wraps: u8 = relay_pool.pool_capacity;
const seal_event_kind: u32 = 13;
const wrap_event_kind: u32 = 1059;

pub const MailboxError =
    noztr.nip17_private_messages.PrivateMessageError ||
    noztr.nip17_private_messages.RelayListError ||
    noztr.nip44.ConversationEncryptionError ||
    noztr.nip42_auth.AuthError ||
    noztr.nip01_event.EventShapeError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    error{
        ChallengeEmpty,
        ChallengeTooLong,
        InvalidReplyTag,
        InvalidRecipientPrivateKey,
        InvalidRecipientPubkey,
        InvalidWrapSignerPrivateKey,
        UnsupportedRumorKind,
        BackendUnavailable,
        RelayUrlTooLong,
        PoolFull,
        NoRelays,
        InvalidRelayIndex,
        InvalidRelayPoolStep,
        WorkflowRelayMissing,
        RelayDisconnected,
        RelayAuthRequired,
        AuthNotRequired,
        RelayListAuthorMismatch,
        RelayListRecipientMismatch,
        SenderRelayListAuthorMismatch,
        DuplicateWrap,
        SeenWrapTableFull,
        NoReceiveRelay,
        StaleReceiveTurn,
        InvalidReceiveTurnRelay,
        NoSyncStep,
        InvalidSyncTurnAction,
    };

/// Parsed mailbox intake result.
/// `rumor_event` and `message` borrow from caller-provided parse scratch.
pub const MailboxMessageOutcome = struct {
    wrap_event_id: [32]u8,
    rumor_event: noztr.nip01_event.Event,
    message: noztr.nip17_private_messages.DmMessageInfo,
};

/// Parsed mailbox file-message intake result.
/// `rumor_event`, `file_message`, and nested slices borrow from caller-provided parse scratch.
pub const MailboxFileMessageOutcome = struct {
    wrap_event_id: [32]u8,
    rumor_event: noztr.nip01_event.Event,
    file_message: noztr.nip17_private_messages.FileMessageInfo,
};

pub const MailboxEnvelopeOutcome = union(enum) {
    direct_message: MailboxMessageOutcome,
    file_message: MailboxFileMessageOutcome,
};

pub const MailboxFileDimensions = noztr.nip17_private_messages.FileDimensions;

/// Caller-owned storage for one outbound wrapped-message JSON payload.
/// `MailboxOutboundMessage.wrap_event_json` borrows from this buffer until it is overwritten.
pub const MailboxOutboundBuffer = struct {
    storage: [noztr.limits.event_json_max]u8 = [_]u8{0} ** noztr.limits.event_json_max,

    fn writable(self: *MailboxOutboundBuffer) []u8 {
        return self.storage[0..];
    }
};

pub const MailboxDirectMessageRequest = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    reply_to: ?noztr.nip17_private_messages.DmReplyRef = null,
    content: []const u8,
    created_at: u64,
    wrap_signer_private_key: [32]u8,
    seal_nonce: [32]u8,
    wrap_nonce: [32]u8,
};

pub const MailboxFileMessageRequest = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    file_url: []const u8,
    file_type: []const u8,
    decryption_key: []const u8,
    decryption_nonce: []const u8,
    encrypted_file_hash: [32]u8,
    original_file_hash: ?[32]u8 = null,
    size: ?u64 = null,
    dimensions: ?MailboxFileDimensions = null,
    blurhash: ?[]const u8 = null,
    thumbs: []const []const u8 = &.{},
    fallbacks: []const []const u8 = &.{},
    created_at: u64,
    wrap_signer_private_key: [32]u8,
    seal_nonce: [32]u8,
    wrap_nonce: [32]u8,
};

/// Transport-ready outbound mailbox payload.
/// `wrap_event_json` borrows from the caller-provided `MailboxOutboundBuffer`.
pub const MailboxOutboundMessage = struct {
    relay_url: []const u8,
    wrap_event_id: [32]u8,
    wrap_event_json: []const u8,
};

pub const MailboxDeliveryStorage = struct {
    relay_urls: [relay_pool.pool_capacity][relay_url.relay_url_max_bytes]u8 =
        [_][relay_url.relay_url_max_bytes]u8{[_]u8{0} ** relay_url.relay_url_max_bytes} **
        relay_pool.pool_capacity,
    relay_url_lens: [relay_pool.pool_capacity]u16 = [_]u16{0} ** relay_pool.pool_capacity,
    recipient_targets: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,
    sender_copy_targets: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,

    fn clear(self: *MailboxDeliveryStorage) void {
        self.relay_url_lens = [_]u16{0} ** relay_pool.pool_capacity;
        self.recipient_targets = [_]bool{false} ** relay_pool.pool_capacity;
        self.sender_copy_targets = [_]bool{false} ** relay_pool.pool_capacity;
    }

    fn relayUrl(self: *const MailboxDeliveryStorage, index: u8) []const u8 {
        return self.relay_urls[index][0..self.relay_url_lens[index]];
    }
};

pub const MailboxDeliveryRole = struct {
    recipient: bool = false,
    sender_copy: bool = false,
};

pub const MailboxDeliveryStep = struct {
    relay_index: u8,
    relay_url: []const u8,
    role: MailboxDeliveryRole,
    wrap_event_id: [32]u8,
    wrap_event_json: []const u8,
};

pub const MailboxDeliveryPlan = struct {
    relay_count: u8,
    wrap_event_id: [32]u8,
    wrap_event_json: []const u8,
    _storage: *const MailboxDeliveryStorage,

    pub fn relayUrl(self: *const MailboxDeliveryPlan, index: u8) ?[]const u8 {
        if (index >= self.relay_count) return null;
        return self._storage.relayUrl(index);
    }

    pub fn role(self: *const MailboxDeliveryPlan, index: u8) ?MailboxDeliveryRole {
        if (index >= self.relay_count) return null;
        return .{
            .recipient = self._storage.recipient_targets[index],
            .sender_copy = self._storage.sender_copy_targets[index],
        };
    }

    pub fn deliversToRecipient(self: *const MailboxDeliveryPlan, index: u8) bool {
        const delivery_role = self.role(index) orelse return false;
        return delivery_role.recipient;
    }

    pub fn deliversSenderCopy(self: *const MailboxDeliveryPlan, index: u8) bool {
        const delivery_role = self.role(index) orelse return false;
        return delivery_role.sender_copy;
    }

    pub fn nextRelayIndex(self: *const MailboxDeliveryPlan) ?u8 {
        var index: u8 = 0;
        while (index < self.relay_count) : (index += 1) {
            if (self.deliversToRecipient(index)) return index;
        }
        index = 0;
        while (index < self.relay_count) : (index += 1) {
            if (self.deliversSenderCopy(index)) return index;
        }
        return null;
    }

    pub fn nextRecipientRelayIndex(self: *const MailboxDeliveryPlan) ?u8 {
        var index: u8 = 0;
        while (index < self.relay_count) : (index += 1) {
            if (self.deliversToRecipient(index)) return index;
        }
        return null;
    }

    pub fn nextSenderCopyRelayIndex(self: *const MailboxDeliveryPlan) ?u8 {
        var index: u8 = 0;
        while (index < self.relay_count) : (index += 1) {
            if (self.deliversSenderCopy(index)) return index;
        }
        return null;
    }

    pub fn nextStep(self: *const MailboxDeliveryPlan) ?MailboxDeliveryStep {
        const relay_index = self.nextRelayIndex() orelse return null;
        return .{
            .relay_index = relay_index,
            .relay_url = self.relayUrl(relay_index).?,
            .role = self.role(relay_index).?,
            .wrap_event_id = self.wrap_event_id,
            .wrap_event_json = self.wrap_event_json,
        };
    }

    pub fn nextRecipientStep(self: *const MailboxDeliveryPlan) ?MailboxDeliveryStep {
        const relay_index = self.nextRecipientRelayIndex() orelse return null;
        return .{
            .relay_index = relay_index,
            .relay_url = self.relayUrl(relay_index).?,
            .role = self.role(relay_index).?,
            .wrap_event_id = self.wrap_event_id,
            .wrap_event_json = self.wrap_event_json,
        };
    }

    pub fn nextSenderCopyStep(self: *const MailboxDeliveryPlan) ?MailboxDeliveryStep {
        const relay_index = self.nextSenderCopyRelayIndex() orelse return null;
        return .{
            .relay_index = relay_index,
            .relay_url = self.relayUrl(relay_index).?,
            .role = self.role(relay_index).?,
            .wrap_event_id = self.wrap_event_id,
            .wrap_event_json = self.wrap_event_json,
        };
    }
};

pub const MailboxRuntimeAction = enum {
    connect,
    authenticate,
    receive,
};

pub const MailboxRuntimeEntry = struct {
    relay_index: u8,
    relay_url: []const u8,
    action: MailboxRuntimeAction,
    is_current: bool,
};

pub const MailboxRuntimeStep = struct {
    entry: MailboxRuntimeEntry,
};

pub const MailboxRelayPoolStorage = struct {
    relay_pool_storage: shared_runtime.RelayPoolStorage = .{},
};

pub const MailboxRelayPoolRuntimeStorage = struct {
    relay_pool_storage: MailboxRelayPoolStorage = .{},
    plan_storage: shared_runtime.RelayPoolPlanStorage = .{},
};

pub const MailboxWorkflowAction = enum {
    connect,
    authenticate,
    receive,
    publish_recipient,
    publish_sender_copy,
    idle,
};

pub const MailboxWorkflowEntry = struct {
    relay_index: u8,
    relay_url: []const u8,
    action: MailboxWorkflowAction,
    is_current: bool = false,
    role: MailboxDeliveryRole = .{},
    wrap_event_id: ?[32]u8 = null,
    wrap_event_json: ?[]const u8 = null,
};

pub const MailboxWorkflowStep = struct {
    entry: MailboxWorkflowEntry,
};

pub const MailboxWorkflowStorage = struct {
    runtime: MailboxRuntimeStorage = .{},
    actions: [relay_pool.pool_capacity]MailboxWorkflowAction = [_]MailboxWorkflowAction{.idle} **
        relay_pool.pool_capacity,
    recipient_targets: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,
    sender_copy_targets: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,

    fn clear(self: *MailboxWorkflowStorage) void {
        self.runtime.clear();
        self.actions = [_]MailboxWorkflowAction{.idle} ** relay_pool.pool_capacity;
        self.recipient_targets = [_]bool{false} ** relay_pool.pool_capacity;
        self.sender_copy_targets = [_]bool{false} ** relay_pool.pool_capacity;
    }
};

pub const MailboxWorkflowRequest = struct {
    pending_delivery: ?*const MailboxDeliveryPlan = null,
    storage: *MailboxWorkflowStorage,
};

pub const MailboxWorkflowPlan = struct {
    relay_count: u8,
    connect_count: u8 = 0,
    authenticate_count: u8 = 0,
    receive_count: u8 = 0,
    publish_recipient_count: u8 = 0,
    publish_sender_copy_count: u8 = 0,
    idle_count: u8 = 0,
    _session: *const MailboxSession,
    _runtime: MailboxRuntimePlan,
    _delivery: ?*const MailboxDeliveryPlan,
    _storage: *const MailboxWorkflowStorage,

    pub fn entry(self: *const MailboxWorkflowPlan, index: u8) ?MailboxWorkflowEntry {
        const runtime_entry = self._runtime.entry(index) orelse return null;
        const delivery_role: MailboxDeliveryRole = .{
            .recipient = self._storage.recipient_targets[index],
            .sender_copy = self._storage.sender_copy_targets[index],
        };
        return .{
            .relay_index = runtime_entry.relay_index,
            .relay_url = runtime_entry.relay_url,
            .action = self._storage.actions[index],
            .is_current = runtime_entry.is_current,
            .role = delivery_role,
            .wrap_event_id = if (delivery_role.recipient or delivery_role.sender_copy)
                self._delivery.?.wrap_event_id
            else
                null,
            .wrap_event_json = if (delivery_role.recipient or delivery_role.sender_copy)
                self._delivery.?.wrap_event_json
            else
                null,
        };
    }

    pub fn runtimePlan(self: *const MailboxWorkflowPlan) *const MailboxRuntimePlan {
        return &self._runtime;
    }

    pub fn nextEntry(self: *const MailboxWorkflowPlan) ?MailboxWorkflowEntry {
        if (self._delivery) |delivery| {
            if (delivery.nextRecipientRelayIndex()) |delivery_index| {
                if (self.entryForDeliveryIndex(delivery_index)) |selected| return selected;
            }
        }

        for ([_]MailboxWorkflowAction{ .receive, .authenticate, .connect }) |priority| {
            if (self.findPriorityEntry(priority)) |selected| return selected;
        }

        if (self._delivery) |delivery| {
            if (delivery.nextSenderCopyRelayIndex()) |delivery_index| {
                if (self.entryForDeliveryIndex(delivery_index)) |selected| {
                    if (selected.action == .publish_sender_copy) return selected;
                }
            }
        }
        return null;
    }

    pub fn nextStep(self: *const MailboxWorkflowPlan) ?MailboxWorkflowStep {
        const selected_entry = self.nextEntry() orelse return null;
        return .{ .entry = selected_entry };
    }

    fn entryForDeliveryIndex(
        self: *const MailboxWorkflowPlan,
        delivery_index: u8,
    ) ?MailboxWorkflowEntry {
        const delivery = self._delivery orelse return null;
        const relay_url_text = delivery.relayUrl(delivery_index) orelse return null;
        var index: u8 = 0;
        while (index < self.relay_count) : (index += 1) {
            const candidate = self.entry(index) orelse continue;
            if (!relay_url.relayUrlsEquivalent(candidate.relay_url, relay_url_text)) continue;
            return candidate;
        }
        return null;
    }

    fn findPriorityEntry(
        self: *const MailboxWorkflowPlan,
        action: MailboxWorkflowAction,
    ) ?MailboxWorkflowEntry {
        var current_match: ?MailboxWorkflowEntry = null;
        var first_match: ?MailboxWorkflowEntry = null;
        var index: u8 = 0;
        while (index < self.relay_count) : (index += 1) {
            const candidate = self.entry(index) orelse continue;
            if (candidate.action != action) continue;
            if (first_match == null) first_match = candidate;
            if (candidate.is_current) {
                current_match = candidate;
                break;
            }
        }
        if (current_match) |selected| return selected;
        return first_match;
    }
};

pub const MailboxRuntimeStorage = struct {
    relay_indexes: [relay_pool.pool_capacity]u8 = [_]u8{0} ** relay_pool.pool_capacity,
    actions: [relay_pool.pool_capacity]MailboxRuntimeAction = [_]MailboxRuntimeAction{.connect} ** relay_pool.pool_capacity,
    current_flags: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,

    fn clear(self: *MailboxRuntimeStorage) void {
        self.relay_indexes = [_]u8{0} ** relay_pool.pool_capacity;
        self.actions = [_]MailboxRuntimeAction{.connect} ** relay_pool.pool_capacity;
        self.current_flags = [_]bool{false} ** relay_pool.pool_capacity;
    }
};

pub const MailboxRuntimePlan = struct {
    relay_count: u8,
    connect_count: u8,
    authenticate_count: u8,
    receive_count: u8,
    _session: *const MailboxSession,
    _storage: *const MailboxRuntimeStorage,

    pub fn entry(self: *const MailboxRuntimePlan, index: u8) ?MailboxRuntimeEntry {
        if (index >= self.relay_count) return null;
        const relay_index = self._storage.relay_indexes[index];
        const relay = self._session._state.pool.getRelayConst(relay_index) orelse return null;
        return .{
            .relay_index = relay_index,
            .relay_url = relay.auth_session.relayUrl(),
            .action = self._storage.actions[index],
            .is_current = self._storage.current_flags[index],
        };
    }

    pub fn nextEntry(self: *const MailboxRuntimePlan) ?MailboxRuntimeEntry {
        const priorities = [_]MailboxRuntimeAction{ .receive, .authenticate, .connect };
        for (priorities) |priority| {
            var current_match: ?MailboxRuntimeEntry = null;
            var first_match: ?MailboxRuntimeEntry = null;
            var index: u8 = 0;
            while (index < self.relay_count) : (index += 1) {
                const candidate = self.entry(index) orelse continue;
                if (candidate.action != priority) continue;
                if (first_match == null) first_match = candidate;
                if (candidate.is_current) {
                    current_match = candidate;
                    break;
                }
            }
            if (current_match) |runtime_entry| return runtime_entry;
            if (first_match) |runtime_entry| return runtime_entry;
        }
        return null;
    }

    pub fn nextStep(self: *const MailboxRuntimePlan) ?MailboxRuntimeStep {
        const selected_entry = self.nextEntry() orelse return null;
        return .{ .entry = selected_entry };
    }

    pub fn nextReceiveEntry(self: *const MailboxRuntimePlan) ?MailboxRuntimeEntry {
        var current_match: ?MailboxRuntimeEntry = null;
        var first_match: ?MailboxRuntimeEntry = null;
        var index: u8 = 0;
        while (index < self.relay_count) : (index += 1) {
            const candidate = self.entry(index) orelse continue;
            if (candidate.action != .receive) continue;
            if (first_match == null) first_match = candidate;
            if (candidate.is_current) {
                current_match = candidate;
                break;
            }
        }
        if (current_match) |selected| return selected;
        return first_match;
    }

    pub fn nextReceiveStep(self: *const MailboxRuntimePlan) ?MailboxRuntimeStep {
        const selected_entry = self.nextReceiveEntry() orelse return null;
        return .{ .entry = selected_entry };
    }
};

pub const MailboxReceiveTurnStorage = struct {
    runtime: MailboxRuntimeStorage = .{},
};

pub const MailboxReceiveTurnRequest = struct {
    relay_index: u8,
    relay_url: []const u8,
};

pub const MailboxReceiveTurnResult = struct {
    request: MailboxReceiveTurnRequest,
    envelope: MailboxEnvelopeOutcome,
};

pub const MailboxSyncTurnStorage = struct {
    workflow: MailboxWorkflowStorage = .{},
};

pub const MailboxSyncTurnRequest = union(enum) {
    connect: MailboxWorkflowEntry,
    authenticate: MailboxWorkflowEntry,
    publish: MailboxDeliveryStep,
    receive: MailboxReceiveTurnRequest,
};

pub const MailboxSyncTurnResult = union(enum) {
    received: MailboxReceiveTurnResult,
};

pub const MailboxSession = struct {
    const State = struct {
        pool: relay_pool.Pool,
        current_relay_index: u8,
        recipient_private_key: [32]u8,
        seen_wrap_ids: [max_seen_wraps][32]u8 = [_][32]u8{[_]u8{0} ** 32} ** max_seen_wraps,
        seen_wrap_count: u8 = 0,
    };

    _state: State,

    pub fn init(recipient_private_key: *const [32]u8) MailboxSession {
        return .{
            ._state = .{
                .pool = relay_pool.Pool.init(),
                .current_relay_index = 0,
                .recipient_private_key = recipient_private_key.*,
            },
        };
    }

    pub fn relayCount(self: *const MailboxSession) u8 {
        return self._state.pool.count;
    }

    pub fn currentRelayUrl(self: *const MailboxSession) ?[]const u8 {
        const current = self.currentRelayConst() orelse return null;
        return current.auth_session.relayUrl();
    }

    pub fn currentRelayIndex(self: *const MailboxSession) ?u8 {
        if (self._state.pool.count == 0) return null;
        return self._state.current_relay_index;
    }

    pub fn currentRelayCanReceive(self: *const MailboxSession) bool {
        const current = self.currentRelayConst() orelse return false;
        return current.canSendRequests();
    }

    pub fn currentRelayAuthChallenge(self: *const MailboxSession) ?[]const u8 {
        const current = self.currentRelayConst() orelse return null;
        if (current.state != .auth_required) return null;
        if (current.auth_session.state.challenge_len == 0) return null;
        return current.auth_session.state.challenge[0..current.auth_session.state.challenge_len];
    }

    pub fn exportRelayPool(
        self: *const MailboxSession,
        storage: *MailboxRelayPoolStorage,
    ) shared_runtime.RelayPool {
        storage.* = .{};
        storage.relay_pool_storage.pool = self._state.pool;
        return shared_runtime.RelayPool.attach(&storage.relay_pool_storage);
    }

    pub fn exportRelayPoolMembers(
        self: *const MailboxSession,
        storage: *shared_runtime.RelayPoolMemberStorage,
    ) shared_runtime.RelayPoolMemberSet {
        var relay_pool_storage = MailboxRelayPoolStorage{};
        var relay_pool_view = self.exportRelayPool(&relay_pool_storage);
        return relay_pool_view.exportMembers(storage) catch unreachable;
    }

    pub fn restoreRelayPoolMembers(
        self: *MailboxSession,
        members: *const shared_runtime.RelayPoolMemberSet,
        current_relay_index: u8,
    ) MailboxError!void {
        if (members.relay_count > 0 and current_relay_index >= members.relay_count) {
            return error.InvalidRelayIndex;
        }

        self._state.pool = relay_pool.Pool.init();
        var index: u8 = 0;
        while (index < members.relay_count) : (index += 1) {
            const record = members.entry(index) orelse unreachable;
            _ = try self._state.pool.addRelay(record.relayUrl());
        }
        self._state.current_relay_index = if (members.relay_count == 0) 0 else current_relay_index;
        self._state.seen_wrap_count = 0;
    }

    pub fn inspectRelayPoolRuntime(
        self: *const MailboxSession,
        storage: *MailboxRelayPoolRuntimeStorage,
    ) shared_runtime.RelayPoolPlan {
        var relay_pool_view = self.exportRelayPool(&storage.relay_pool_storage);
        return relay_pool_view.inspectRuntime(&storage.plan_storage);
    }

    pub fn inspectRuntime(
        self: *const MailboxSession,
        runtime_storage: *MailboxRuntimeStorage,
    ) MailboxError!MailboxRuntimePlan {
        if (self._state.pool.count == 0) return error.NoRelays;

        runtime_storage.clear();
        var connect_count: u8 = 0;
        var authenticate_count: u8 = 0;
        var receive_count: u8 = 0;
        var index: u8 = 0;
        while (index < self._state.pool.count) : (index += 1) {
            const relay = self._state.pool.getRelayConst(index) orelse unreachable;
            runtime_storage.relay_indexes[index] = index;
            runtime_storage.current_flags[index] = index == self._state.current_relay_index;
            runtime_storage.actions[index] = switch (relay.state) {
                .disconnected => blk: {
                    connect_count += 1;
                    break :blk .connect;
                },
                .auth_required => blk: {
                    authenticate_count += 1;
                    break :blk .authenticate;
                },
                .connected => blk: {
                    receive_count += 1;
                    break :blk .receive;
                },
            };
        }

        return .{
            .relay_count = self._state.pool.count,
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .receive_count = receive_count,
            ._session = self,
            ._storage = runtime_storage,
        };
    }

    pub fn inspectWorkflow(
        self: *const MailboxSession,
        request: MailboxWorkflowRequest,
    ) MailboxError!MailboxWorkflowPlan {
        request.storage.clear();
        const runtime = try self.inspectRuntime(&request.storage.runtime);

        if (request.pending_delivery) |delivery| {
            var delivery_index: u8 = 0;
            while (delivery_index < delivery.relay_count) : (delivery_index += 1) {
                _ = self.findRelayIndexByUrl(delivery.relayUrl(delivery_index).?) orelse {
                    return error.WorkflowRelayMissing;
                };
            }
        }

        var plan: MailboxWorkflowPlan = .{
            .relay_count = runtime.relay_count,
            ._session = self,
            ._runtime = runtime,
            ._delivery = request.pending_delivery,
            ._storage = request.storage,
        };

        var index: u8 = 0;
        while (index < runtime.relay_count) : (index += 1) {
            const runtime_entry = runtime.entry(index) orelse continue;
            const delivery_role = if (request.pending_delivery) |delivery|
                self.deliveryRoleForRelay(delivery, runtime_entry.relay_url)
            else
                MailboxDeliveryRole{};
            request.storage.recipient_targets[index] = delivery_role.recipient;
            request.storage.sender_copy_targets[index] = delivery_role.sender_copy;
            request.storage.actions[index] = switch (runtime_entry.action) {
                .connect => blk: {
                    plan.connect_count += 1;
                    break :blk .connect;
                },
                .authenticate => blk: {
                    plan.authenticate_count += 1;
                    break :blk .authenticate;
                },
                .receive => if (delivery_role.recipient) blk: {
                    plan.publish_recipient_count += 1;
                    break :blk .publish_recipient;
                } else if (delivery_role.sender_copy) blk: {
                    plan.publish_sender_copy_count += 1;
                    break :blk .publish_sender_copy;
                } else if (runtime_entry.is_current) blk: {
                    plan.receive_count += 1;
                    break :blk .receive;
                } else blk: {
                    plan.idle_count += 1;
                    break :blk .idle;
                },
            };
        }

        return plan;
    }

    pub fn hydrateRelayListEventJson(
        self: *MailboxSession,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!u8 {
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.hydrateRelayListEvent(&event);
    }

    pub fn hydrateRelayListEvent(
        self: *MailboxSession,
        event: *const noztr.nip01_event.Event,
    ) MailboxError!u8 {
        try noztr.nip01_event.event_verify(event);
        const recipient_pubkey = noztr.nostr_keys.nostr_derive_public_key(
            &self._state.recipient_private_key,
        ) catch |err| return switch (err) {
            error.InvalidSecretKey => error.InvalidRecipientPrivateKey,
            error.BackendUnavailable => error.BackendUnavailable,
            error.InvalidEvent => unreachable,
        };
        if (!std.mem.eql(u8, &event.pubkey, &recipient_pubkey)) {
            return error.RelayListAuthorMismatch;
        }
        var relays: [relay_pool.pool_capacity][]const u8 = undefined;
        const relay_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
            event,
            relays[0..],
        );

        self._state.pool = relay_pool.Pool.init();
        self._state.current_relay_index = 0;
        var index: u16 = 0;
        while (index < relay_count) : (index += 1) {
            _ = try self._state.pool.addRelay(relays[index]);
        }
        return self._state.pool.count;
    }

    pub fn markCurrentRelayConnected(self: *MailboxSession) MailboxError!void {
        const current = self.currentRelay() orelse return error.NoRelays;
        current.connect();
    }

    pub fn noteCurrentRelayDisconnected(self: *MailboxSession) MailboxError!void {
        const current = self.currentRelay() orelse return error.NoRelays;
        current.disconnect();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *MailboxSession,
        challenge: []const u8,
    ) MailboxError!void {
        const current = self.currentRelay() orelse return error.NoRelays;
        current.requireAuth(challenge) catch |err| return switch (err) {
            error.NotConnected => error.RelayDisconnected,
            error.ChallengeEmpty => error.ChallengeEmpty,
            error.ChallengeTooLong => error.ChallengeTooLong,
        };
    }

    pub fn acceptCurrentRelayAuthEventJson(
        self: *MailboxSession,
        auth_event_json: []const u8,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) MailboxError!void {
        const auth_event = try noztr.nip01_event.event_parse_json(auth_event_json, scratch);
        try self.acceptCurrentRelayAuthEvent(&auth_event, now_unix_seconds, window_seconds);
    }

    pub fn acceptCurrentRelayAuthEvent(
        self: *MailboxSession,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) MailboxError!void {
        const current = self.currentRelay() orelse return error.NoRelays;
        try current.acceptAuthEvent(auth_event, now_unix_seconds, window_seconds);
    }

    pub fn advanceRelay(self: *MailboxSession) MailboxError![]const u8 {
        if (self._state.pool.count == 0) return error.NoRelays;

        self._state.current_relay_index =
            (self._state.current_relay_index + 1) % self._state.pool.count;
        const current = self.currentRelay() orelse unreachable;
        return current.auth_session.relayUrl();
    }

    pub fn selectRelay(self: *MailboxSession, relay_index: u8) MailboxError![]const u8 {
        if (self._state.pool.count == 0) return error.NoRelays;
        if (self._state.pool.getRelay(relay_index) == null) return error.InvalidRelayIndex;
        self._state.current_relay_index = relay_index;
        return self.currentRelayUrl() orelse unreachable;
    }

    pub fn selectRelayPoolStep(
        self: *MailboxSession,
        step: *const shared_runtime.RelayPoolStep,
    ) MailboxError![]const u8 {
        const descriptor = step.entry.descriptor;
        const relay = self._state.pool.getRelayConst(descriptor.relay_index) orelse {
            return error.InvalidRelayPoolStep;
        };
        if (!std.mem.eql(u8, relay.auth_session.relayUrl(), descriptor.relay_url)) {
            return error.InvalidRelayPoolStep;
        }
        if (step.entry.action != classifyMailboxRelayAction(relay.state)) {
            return error.InvalidRelayPoolStep;
        }
        return self.selectRelay(descriptor.relay_index);
    }

    pub fn selectWorkflowRelay(
        self: *MailboxSession,
        step: MailboxWorkflowStep,
    ) MailboxError![]const u8 {
        return self.selectRelay(step.entry.relay_index);
    }

    pub fn beginReceiveTurn(
        self: *MailboxSession,
        storage: *MailboxReceiveTurnStorage,
    ) MailboxError!MailboxReceiveTurnRequest {
        const runtime = try self.inspectRuntime(&storage.runtime);
        const entry = runtime.nextReceiveEntry() orelse return error.NoReceiveRelay;
        const relay_url_text = try self.selectRelay(entry.relay_index);
        return .{
            .relay_index = entry.relay_index,
            .relay_url = relay_url_text,
        };
    }

    pub fn acceptReceiveEnvelopeJson(
        self: *MailboxSession,
        request: *const MailboxReceiveTurnRequest,
        wrap_event_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxReceiveTurnResult {
        try self.requireCurrentReceiveTurn(request);
        return .{
            .request = request.*,
            .envelope = try self.acceptWrappedEnvelopeJson(
                wrap_event_json,
                recipients_out,
                thumbs_out,
                fallbacks_out,
                scratch,
            ),
        };
    }

    pub fn beginSyncTurn(
        self: *MailboxSession,
        request: MailboxWorkflowRequest,
    ) MailboxError!MailboxSyncTurnRequest {
        const workflow = try self.inspectWorkflow(request);
        const step = workflow.nextStep() orelse return error.NoSyncStep;
        const relay_url_text = try self.selectWorkflowRelay(step);
        switch (step.entry.action) {
            .connect => return .{ .connect = step.entry },
            .authenticate => return .{ .authenticate = step.entry },
            .publish_recipient, .publish_sender_copy => return .{
                .publish = .{
                    .relay_index = step.entry.relay_index,
                    .relay_url = relay_url_text,
                    .role = step.entry.role,
                    .wrap_event_id = step.entry.wrap_event_id orelse return error.InvalidSyncTurnAction,
                    .wrap_event_json = step.entry.wrap_event_json orelse return error.InvalidSyncTurnAction,
                },
            },
            .receive => return .{
                .receive = .{
                    .relay_index = step.entry.relay_index,
                    .relay_url = relay_url_text,
                },
            },
            .idle => return error.NoSyncStep,
        }
    }

    pub fn acceptSyncEnvelopeJson(
        self: *MailboxSession,
        request: *const MailboxSyncTurnRequest,
        wrap_event_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxSyncTurnResult {
        return switch (request.*) {
            .receive => |receive| .{
                .received = try self.acceptReceiveEnvelopeJson(
                    &receive,
                    wrap_event_json,
                    recipients_out,
                    thumbs_out,
                    fallbacks_out,
                    scratch,
                ),
            },
            else => error.InvalidSyncTurnAction,
        };
    }

    pub fn acceptWrappedMessageJson(
        self: *MailboxSession,
        wrap_event_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxMessageOutcome {
        try self.requireCurrentRelayReady();

        const wrap_event = try noztr.nip01_event.event_parse_json(wrap_event_json, scratch);
        if (self.hasSeenWrap(&wrap_event.id)) return error.DuplicateWrap;

        var rumor_event: noztr.nip01_event.Event = undefined;
        const message = try noztr.nip17_private_messages.nip17_unwrap_message(
            &rumor_event,
            &self._state.recipient_private_key,
            &wrap_event,
            recipients_out,
            scratch,
        );
        try self.rememberWrap(&wrap_event.id);
        return .{
            .wrap_event_id = wrap_event.id,
            .rumor_event = rumor_event,
            .message = message,
        };
    }

    pub fn acceptWrappedFileMessageJson(
        self: *MailboxSession,
        wrap_event_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxFileMessageOutcome {
        try self.requireCurrentRelayReady();

        const wrap_event = try noztr.nip01_event.event_parse_json(wrap_event_json, scratch);
        if (self.hasSeenWrap(&wrap_event.id)) return error.DuplicateWrap;

        var rumor_event: noztr.nip01_event.Event = undefined;
        const file_message = try noztr.nip17_private_messages.nip17_unwrap_file_message(
            &rumor_event,
            &self._state.recipient_private_key,
            &wrap_event,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
        try self.rememberWrap(&wrap_event.id);
        return .{
            .wrap_event_id = wrap_event.id,
            .rumor_event = rumor_event,
            .file_message = file_message,
        };
    }

    pub fn acceptWrappedEnvelopeJson(
        self: *MailboxSession,
        wrap_event_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxEnvelopeOutcome {
        try self.requireCurrentRelayReady();

        const wrap_event = try noztr.nip01_event.event_parse_json(wrap_event_json, scratch);
        return self.acceptWrappedEnvelopeEvent(
            &wrap_event,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
    }

    pub fn acceptWrappedEnvelopeEvent(
        self: *MailboxSession,
        wrap_event: *const noztr.nip01_event.Event,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxEnvelopeOutcome {
        try self.requireCurrentRelayReady();

        if (self.hasSeenWrap(&wrap_event.id)) return error.DuplicateWrap;

        var rumor_event: noztr.nip01_event.Event = undefined;
        try noztr.nip59_wrap.nip59_unwrap(
            &rumor_event,
            &self._state.recipient_private_key,
            wrap_event,
            scratch,
        );

        const outcome: MailboxEnvelopeOutcome = switch (rumor_event.kind) {
            noztr.nip17_private_messages.dm_kind => .{
                .direct_message = .{
                    .wrap_event_id = wrap_event.id,
                    .rumor_event = rumor_event,
                    .message = try noztr.nip17_private_messages.nip17_message_parse(
                        &rumor_event,
                        recipients_out,
                    ),
                },
            },
            noztr.nip17_private_messages.file_dm_kind => .{
                .file_message = .{
                    .wrap_event_id = wrap_event.id,
                    .rumor_event = rumor_event,
                    .file_message = try noztr.nip17_private_messages.nip17_file_message_parse(
                        &rumor_event,
                        recipients_out,
                        thumbs_out,
                        fallbacks_out,
                    ),
                },
            },
            else => return error.UnsupportedRumorKind,
        };

        try self.rememberWrap(&wrap_event.id);
        return outcome;
    }

    pub fn beginDirectMessage(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        request: *const MailboxDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxOutboundMessage {
        try self.requireCurrentRelayReady();

        const built = try self.buildDirectMessageWrap(buffer, request, scratch);
        return .{
            .relay_url = self.currentRelayUrl() orelse unreachable,
            .wrap_event_id = built.wrap_event_id,
            .wrap_event_json = built.wrap_event_json,
        };
    }

    pub fn beginFileMessage(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        request: *const MailboxFileMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxOutboundMessage {
        try self.requireCurrentRelayReady();

        const built = try self.buildFileMessageWrap(buffer, request, scratch);
        return .{
            .relay_url = self.currentRelayUrl() orelse unreachable,
            .wrap_event_id = built.wrap_event_id,
            .wrap_event_json = built.wrap_event_json,
        };
    }

    pub fn planDirectMessageRelayFanout(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        delivery_storage: *MailboxDeliveryStorage,
        recipient_relay_list_event_json: []const u8,
        request: *const MailboxDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxDeliveryPlan {
        return self.planDirectMessageDelivery(
            buffer,
            delivery_storage,
            recipient_relay_list_event_json,
            null,
            request,
            scratch,
        );
    }

    pub fn planDirectMessageDelivery(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        delivery_storage: *MailboxDeliveryStorage,
        recipient_relay_list_event_json: []const u8,
        sender_relay_list_event_json: ?[]const u8,
        request: *const MailboxDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxDeliveryPlan {
        const built = try self.buildDirectMessageWrap(buffer, request, scratch);
        return self.buildDeliveryPlan(
            delivery_storage,
            recipient_relay_list_event_json,
            sender_relay_list_event_json,
            &request.recipient_pubkey,
            request.recipient_relay_hint,
            built.wrap_event_id,
            built.wrap_event_json,
            scratch,
        );
    }

    pub fn planFileMessageRelayFanout(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        delivery_storage: *MailboxDeliveryStorage,
        recipient_relay_list_event_json: []const u8,
        request: *const MailboxFileMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxDeliveryPlan {
        return self.planFileMessageDelivery(
            buffer,
            delivery_storage,
            recipient_relay_list_event_json,
            null,
            request,
            scratch,
        );
    }

    pub fn planFileMessageDelivery(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        delivery_storage: *MailboxDeliveryStorage,
        recipient_relay_list_event_json: []const u8,
        sender_relay_list_event_json: ?[]const u8,
        request: *const MailboxFileMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxDeliveryPlan {
        const built = try self.buildFileMessageWrap(buffer, request, scratch);
        return self.buildDeliveryPlan(
            delivery_storage,
            recipient_relay_list_event_json,
            sender_relay_list_event_json,
            &request.recipient_pubkey,
            request.recipient_relay_hint,
            built.wrap_event_id,
            built.wrap_event_json,
            scratch,
        );
    }

    fn currentRelay(self: *MailboxSession) ?*relay_session.RelaySession {
        return self._state.pool.getRelay(self._state.current_relay_index);
    }

    fn findRelayIndexByUrl(self: *const MailboxSession, relay_url_text: []const u8) ?u8 {
        var index: u8 = 0;
        while (index < self._state.pool.count) : (index += 1) {
            const relay = self._state.pool.getRelayConst(index) orelse continue;
            if (relay_url.relayUrlsEquivalent(relay.auth_session.relayUrl(), relay_url_text)) {
                return index;
            }
        }
        return null;
    }

    fn deliveryRoleForRelay(
        self: *const MailboxSession,
        delivery: *const MailboxDeliveryPlan,
        relay_url_text: []const u8,
    ) MailboxDeliveryRole {
        _ = self;
        var role = MailboxDeliveryRole{};
        var index: u8 = 0;
        while (index < delivery.relay_count) : (index += 1) {
            const delivery_relay_url = delivery.relayUrl(index) orelse continue;
            if (!relay_url.relayUrlsEquivalent(delivery_relay_url, relay_url_text)) continue;
            role.recipient = delivery.deliversToRecipient(index);
            role.sender_copy = delivery.deliversSenderCopy(index);
            break;
        }
        return role;
    }

    fn buildDirectMessageWrap(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        request: *const MailboxDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!struct { wrap_event_id: [32]u8, wrap_event_json: []const u8 } {
        const sender_pubkey = try self.actorPubkey();
        _ = noztr.nostr_keys.nostr_derive_public_key(&request.wrap_signer_private_key) catch |err| {
            return switch (err) {
                error.InvalidSecretKey => error.InvalidWrapSignerPrivateKey,
                error.BackendUnavailable => error.BackendUnavailable,
                error.InvalidEvent => unreachable,
            };
        };
        var built_recipient_tag: noztr.nip17_private_messages.BuiltTag = .{};
        var reply_tag_storage: MailboxReplyTagStorage = .{};
        const recipient_hex = std.fmt.bytesToHex(request.recipient_pubkey, .lower);
        const recipient_tag = try noztr.nip17_private_messages.nip17_build_recipient_tag(
            &built_recipient_tag,
            recipient_hex[0..],
            request.recipient_relay_hint,
        );
        var rumor_tags: [2]noztr.nip01_event.EventTag = undefined;
        rumor_tags[0] = recipient_tag;
        var rumor_tag_count: usize = 1;
        if (request.reply_to) |reply_to| {
            rumor_tags[1] = try buildReplyTag(&reply_tag_storage, &reply_to);
            rumor_tag_count = 2;
        }
        var rumor_event = noztr.nip01_event.Event{
            .id = [_]u8{0} ** 32,
            .pubkey = sender_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip17_private_messages.dm_kind,
            .created_at = request.created_at,
            .content = request.content,
            .tags = rumor_tags[0..rumor_tag_count],
        };
        rumor_event.id = try noztr.nip01_event.event_compute_id_checked(&rumor_event);
        const rumor_json_storage = try scratch.alloc(u8, noztr.limits.event_json_max);
        const seal_json_storage = try scratch.alloc(u8, noztr.limits.event_json_max);
        const seal_payload_storage =
            try scratch.alloc(u8, noztr.limits.nip44_payload_base64_max_bytes);
        const wrap_payload_storage =
            try scratch.alloc(u8, noztr.limits.nip44_payload_base64_max_bytes);
        var seal_event: noztr.nip01_event.Event = undefined;
        var wrap_event: noztr.nip59_wrap.BuiltWrapEvent = .{};
        _ = noztr.nip59_wrap.nip59_build_outbound_for_recipient(
            &seal_event,
            &wrap_event,
            &self._state.recipient_private_key,
            &request.wrap_signer_private_key,
            &request.recipient_pubkey,
            &rumor_event,
            rumor_json_storage,
            seal_json_storage,
            seal_payload_storage,
            wrap_payload_storage,
            request.created_at + 1,
            request.created_at + 2,
            &request.seal_nonce,
            &request.wrap_nonce,
        ) catch |err| return switch (err) {
            error.InvalidSecretKey => unreachable,
            error.InvalidPublicKey => error.InvalidRecipientPubkey,
            error.InvalidPrivateKey => error.InvalidRecipientPrivateKey,
            error.BackendUnavailable => error.BackendUnavailable,
            error.EntropyUnavailable => error.EntropyUnavailable,
            error.InvalidRumorEvent => error.InvalidWrapEvent,
            error.InvalidSealEvent => error.InvalidWrapEvent,
            error.InvalidWrapEvent => error.InvalidWrapEvent,
            error.InvalidEvent => error.InvalidWrapEvent,
            error.BufferTooSmall => error.BufferTooSmall,
            error.InvalidBase64 => error.InvalidBase64,
            error.InvalidVersion => error.InvalidVersion,
            error.UnsupportedEncoding => error.UnsupportedEncoding,
            error.InvalidPayloadLength => error.InvalidPayloadLength,
            error.InvalidMac => error.InvalidMac,
            error.InvalidNonceLength => error.InvalidNonceLength,
            error.InvalidPadding => error.InvalidPadding,
            error.InvalidConversationKeyLength => error.InvalidConversationKeyLength,
            error.InvalidPlaintextLength => error.InvalidPlaintextLength,
        };
        return .{
            .wrap_event_id = wrap_event.event.id,
            .wrap_event_json = try noztr.nip01_event.event_serialize_json_object(
                buffer.writable(),
                &wrap_event.event,
            ),
        };
    }

    fn buildFileMessageWrap(
        self: *MailboxSession,
        buffer: *MailboxOutboundBuffer,
        request: *const MailboxFileMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxError!struct { wrap_event_id: [32]u8, wrap_event_json: []const u8 } {
        const sender_pubkey = try self.actorPubkey();
        _ = noztr.nostr_keys.nostr_derive_public_key(&request.wrap_signer_private_key) catch |err| {
            return switch (err) {
                error.InvalidSecretKey => error.InvalidWrapSignerPrivateKey,
                error.BackendUnavailable => error.BackendUnavailable,
                error.InvalidEvent => unreachable,
            };
        };

        const base_tag_count: usize = 6 +
            @as(usize, if (request.original_file_hash != null) 1 else 0) +
            @as(usize, if (request.size != null) 1 else 0) +
            @as(usize, if (request.dimensions != null) 1 else 0) +
            @as(usize, if (request.blurhash != null) 1 else 0);
        const total_tag_count = base_tag_count + request.thumbs.len + request.fallbacks.len;
        var rumor_tags = try scratch.alloc(noztr.nip01_event.EventTag, total_tag_count);
        var built_metadata_tags = try scratch.alloc(
            noztr.nip17_private_messages.BuiltFileMetadataTag,
            total_tag_count - 1,
        );
        var tag_index: usize = 0;
        var metadata_index: usize = 0;

        var built_recipient_tag: noztr.nip17_private_messages.BuiltTag = .{};
        const recipient_hex = std.fmt.bytesToHex(request.recipient_pubkey, .lower);
        rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_recipient_tag(
            &built_recipient_tag,
            recipient_hex[0..],
            request.recipient_relay_hint,
        );
        tag_index += 1;

        const encrypted_file_hash_hex = std.fmt.bytesToHex(request.encrypted_file_hash, .lower);
        rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_file_type_tag(
            &built_metadata_tags[metadata_index],
            request.file_type,
        );
        tag_index += 1;
        metadata_index += 1;
        rumor_tags[tag_index] =
            try noztr.nip17_private_messages.nip17_build_file_encryption_algorithm_tag(
                &built_metadata_tags[metadata_index],
                .aes_gcm,
            );
        tag_index += 1;
        metadata_index += 1;
        rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_file_decryption_key_tag(
            &built_metadata_tags[metadata_index],
            request.decryption_key,
        );
        tag_index += 1;
        metadata_index += 1;
        rumor_tags[tag_index] =
            try noztr.nip17_private_messages.nip17_build_file_decryption_nonce_tag(
                &built_metadata_tags[metadata_index],
                request.decryption_nonce,
            );
        tag_index += 1;
        metadata_index += 1;
        rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_file_hash_tag(
            &built_metadata_tags[metadata_index],
            encrypted_file_hash_hex[0..],
        );
        tag_index += 1;
        metadata_index += 1;

        if (request.original_file_hash) |original_file_hash| {
            const original_hex = std.fmt.bytesToHex(original_file_hash, .lower);
            rumor_tags[tag_index] =
                try noztr.nip17_private_messages.nip17_build_file_original_hash_tag(
                    &built_metadata_tags[metadata_index],
                    original_hex[0..],
                );
            tag_index += 1;
            metadata_index += 1;
        }

        if (request.size) |size| {
            rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_file_size_tag(
                &built_metadata_tags[metadata_index],
                size,
            );
            tag_index += 1;
            metadata_index += 1;
        }

        if (request.dimensions) |dimensions| {
            rumor_tags[tag_index] =
                try noztr.nip17_private_messages.nip17_build_file_dimensions_tag(
                    &built_metadata_tags[metadata_index],
                    dimensions,
                );
            tag_index += 1;
            metadata_index += 1;
        }

        if (request.blurhash) |blurhash| {
            rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_file_blurhash_tag(
                &built_metadata_tags[metadata_index],
                blurhash,
            );
            tag_index += 1;
            metadata_index += 1;
        }

        for (request.thumbs) |thumb| {
            rumor_tags[tag_index] = try noztr.nip17_private_messages.nip17_build_file_thumb_tag(
                &built_metadata_tags[metadata_index],
                thumb,
            );
            tag_index += 1;
            metadata_index += 1;
        }
        for (request.fallbacks) |fallback| {
            rumor_tags[tag_index] =
                try noztr.nip17_private_messages.nip17_build_file_fallback_tag(
                    &built_metadata_tags[metadata_index],
                    fallback,
                );
            tag_index += 1;
            metadata_index += 1;
        }

        var rumor_event = noztr.nip01_event.Event{
            .id = [_]u8{0} ** 32,
            .pubkey = sender_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip17_private_messages.file_dm_kind,
            .created_at = request.created_at,
            .content = request.file_url,
            .tags = rumor_tags[0..tag_index],
        };

        var parsed_recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
        const parsed_thumbs = try scratch.alloc([]const u8, request.thumbs.len);
        const parsed_fallbacks = try scratch.alloc([]const u8, request.fallbacks.len);
        _ = try noztr.nip17_private_messages.nip17_file_message_parse(
            &rumor_event,
            parsed_recipients[0..],
            parsed_thumbs,
            parsed_fallbacks,
        );
        rumor_event.id = try noztr.nip01_event.event_compute_id_checked(&rumor_event);

        const rumor_json_storage = try scratch.alloc(u8, noztr.limits.event_json_max);
        const seal_json_storage = try scratch.alloc(u8, noztr.limits.event_json_max);
        const seal_payload_storage =
            try scratch.alloc(u8, noztr.limits.nip44_payload_base64_max_bytes);
        const wrap_payload_storage =
            try scratch.alloc(u8, noztr.limits.nip44_payload_base64_max_bytes);
        var seal_event: noztr.nip01_event.Event = undefined;
        var wrap_event: noztr.nip59_wrap.BuiltWrapEvent = .{};
        _ = noztr.nip59_wrap.nip59_build_outbound_for_recipient(
            &seal_event,
            &wrap_event,
            &self._state.recipient_private_key,
            &request.wrap_signer_private_key,
            &request.recipient_pubkey,
            &rumor_event,
            rumor_json_storage,
            seal_json_storage,
            seal_payload_storage,
            wrap_payload_storage,
            request.created_at + 1,
            request.created_at + 2,
            &request.seal_nonce,
            &request.wrap_nonce,
        ) catch |err| return switch (err) {
            error.InvalidSecretKey => unreachable,
            error.InvalidPublicKey => error.InvalidRecipientPubkey,
            error.InvalidPrivateKey => error.InvalidRecipientPrivateKey,
            error.BackendUnavailable => error.BackendUnavailable,
            error.EntropyUnavailable => error.EntropyUnavailable,
            error.InvalidRumorEvent => error.InvalidFileMetadataTag,
            error.InvalidSealEvent => error.InvalidWrapEvent,
            error.InvalidWrapEvent => error.InvalidWrapEvent,
            error.InvalidEvent => error.InvalidWrapEvent,
            error.BufferTooSmall => error.BufferTooSmall,
            error.InvalidBase64 => error.InvalidBase64,
            error.InvalidVersion => error.InvalidVersion,
            error.UnsupportedEncoding => error.UnsupportedEncoding,
            error.InvalidPayloadLength => error.InvalidPayloadLength,
            error.InvalidMac => error.InvalidMac,
            error.InvalidNonceLength => error.InvalidNonceLength,
            error.InvalidPadding => error.InvalidPadding,
            error.InvalidConversationKeyLength => error.InvalidConversationKeyLength,
            error.InvalidPlaintextLength => error.InvalidPlaintextLength,
        };
        return .{
            .wrap_event_id = wrap_event.event.id,
            .wrap_event_json = try noztr.nip01_event.event_serialize_json_object(
                buffer.writable(),
                &wrap_event.event,
            ),
        };
    }

    fn buildDeliveryPlan(
        self: *MailboxSession,
        delivery_storage: *MailboxDeliveryStorage,
        recipient_relay_list_event_json: []const u8,
        sender_relay_list_event_json: ?[]const u8,
        recipient_pubkey: *const [32]u8,
        recipient_relay_hint: ?[]const u8,
        wrap_event_id: [32]u8,
        wrap_event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxError!MailboxDeliveryPlan {
        const relay_list_event = try noztr.nip01_event.event_parse_json(
            recipient_relay_list_event_json,
            scratch,
        );
        try noztr.nip01_event.event_verify(&relay_list_event);
        if (!std.mem.eql(u8, &relay_list_event.pubkey, recipient_pubkey)) {
            return error.RelayListRecipientMismatch;
        }

        var extracted_relays: [relay_pool.pool_capacity][]const u8 = undefined;
        const extracted_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
            &relay_list_event,
            extracted_relays[0..],
        );
        delivery_storage.clear();

        if (recipient_relay_hint) |hint| {
            if (relayListContainsEquivalent(extracted_relays[0..extracted_count], hint)) {
                const hint_index = try rememberPublishRelay(delivery_storage, hint);
                delivery_storage.recipient_targets[hint_index] = true;
            }
        }

        var index: u16 = 0;
        while (index < extracted_count) : (index += 1) {
            const relay_index = try rememberPublishRelay(delivery_storage, extracted_relays[index]);
            delivery_storage.recipient_targets[relay_index] = true;
        }

        if (sender_relay_list_event_json) |sender_relay_list_json| {
            const sender_relay_list_event = try noztr.nip01_event.event_parse_json(
                sender_relay_list_json,
                scratch,
            );
            try noztr.nip01_event.event_verify(&sender_relay_list_event);
            const sender_pubkey = try self.actorPubkey();
            if (!std.mem.eql(u8, &sender_relay_list_event.pubkey, &sender_pubkey)) {
                return error.SenderRelayListAuthorMismatch;
            }

            var sender_relays: [relay_pool.pool_capacity][]const u8 = undefined;
            const sender_relay_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
                &sender_relay_list_event,
                sender_relays[0..],
            );
            var sender_index: u16 = 0;
            while (sender_index < sender_relay_count) : (sender_index += 1) {
                const relay_index = try rememberPublishRelay(
                    delivery_storage,
                    sender_relays[sender_index],
                );
                delivery_storage.sender_copy_targets[relay_index] = true;
            }
        }

        var relay_count: u8 = 0;
        while (relay_count < relay_pool.pool_capacity and delivery_storage.relay_url_lens[relay_count] != 0) {
            relay_count += 1;
        }

        return .{
            .wrap_event_id = wrap_event_id,
            .wrap_event_json = wrap_event_json,
            .relay_count = relay_count,
            ._storage = delivery_storage,
        };
    }

    fn currentRelayConst(self: *const MailboxSession) ?*const relay_session.RelaySession {
        return self._state.pool.getRelayConst(self._state.current_relay_index);
    }

    fn actorPubkey(self: *const MailboxSession) MailboxError![32]u8 {
        return noztr.nostr_keys.nostr_derive_public_key(&self._state.recipient_private_key) catch |err| {
            return switch (err) {
                error.InvalidSecretKey => error.InvalidRecipientPrivateKey,
                error.BackendUnavailable => error.BackendUnavailable,
                error.InvalidEvent => unreachable,
            };
        };
    }

    fn requireCurrentReceiveTurn(
        self: *const MailboxSession,
        request: *const MailboxReceiveTurnRequest,
    ) MailboxError!void {
        const current = self.currentRelayConst() orelse return error.NoRelays;
        if (self._state.current_relay_index != request.relay_index) return error.StaleReceiveTurn;
        if (!std.mem.eql(u8, current.auth_session.relayUrl(), request.relay_url)) {
            return error.StaleReceiveTurn;
        }
        if (!current.canSendRequests()) return error.InvalidReceiveTurnRelay;
    }

    fn requireCurrentRelayReady(self: *MailboxSession) MailboxError!void {
        const current = self.currentRelay() orelse return error.NoRelays;
        if (current.canSendRequests()) return;
        return switch (current.state) {
            .disconnected => error.RelayDisconnected,
            .auth_required => error.RelayAuthRequired,
            .connected => unreachable,
        };
    }

    fn hasSeenWrap(self: *const MailboxSession, wrap_event_id: *const [32]u8) bool {
        var index: u8 = 0;
        while (index < self._state.seen_wrap_count) : (index += 1) {
            if (std.mem.eql(u8, &self._state.seen_wrap_ids[index], wrap_event_id)) return true;
        }
        return false;
    }

    fn rememberWrap(self: *MailboxSession, wrap_event_id: *const [32]u8) MailboxError!void {
        if (self.hasSeenWrap(wrap_event_id)) return;
        if (self._state.seen_wrap_count == max_seen_wraps) {
            std.mem.copyForwards(
                [32]u8,
                self._state.seen_wrap_ids[0 .. max_seen_wraps - 1],
                self._state.seen_wrap_ids[1..max_seen_wraps],
            );
            self._state.seen_wrap_ids[max_seen_wraps - 1] = wrap_event_id.*;
            return;
        }
        self._state.seen_wrap_ids[self._state.seen_wrap_count] = wrap_event_id.*;
        self._state.seen_wrap_count += 1;
    }
};

const MailboxReplyTagStorage = struct {
    event_id_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    relay_hint_storage: [noztr.limits.tag_item_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.tag_item_bytes_max,
    items: [4][]const u8 = undefined,
};

fn buildReplyTag(
    storage: *MailboxReplyTagStorage,
    reply_to: *const noztr.nip17_private_messages.DmReplyRef,
) MailboxError!noztr.nip01_event.EventTag {
    const event_id_hex = std.fmt.bytesToHex(reply_to.event_id, .lower);
    @memcpy(storage.event_id_hex[0..], event_id_hex[0..]);
    storage.items[0] = "e";
    storage.items[1] = storage.event_id_hex[0..];
    var item_count: usize = 2;
    if (reply_to.relay_hint) |hint| {
        const copied = try copyReplyRelayHint(storage.relay_hint_storage[0..], hint);
        storage.items[2] = copied;
        storage.items[3] = "reply";
        item_count = 4;
    } else {
        storage.items[2] = "";
        storage.items[3] = "reply";
        item_count = 4;
    }
    return .{ .items = storage.items[0..item_count] };
}

fn copyReplyRelayHint(output: []u8, relay_hint: []const u8) MailboxError![]const u8 {
    if (relay_hint.len == 0) return error.InvalidReplyTag;
    if (relay_hint.len > output.len) return error.InvalidReplyTag;
    relay_url.relayUrlValidate(relay_hint) catch return error.InvalidReplyTag;
    @memcpy(output[0..relay_hint.len], relay_hint);
    return output[0..relay_hint.len];
}

fn relayListContainsEquivalent(relays: []const []const u8, candidate: []const u8) bool {
    for (relays) |relay| {
        if (relay_url.relayUrlsEquivalent(relay, candidate)) return true;
    }
    return false;
}

fn rememberPublishRelay(
    storage: *MailboxDeliveryStorage,
    relay: []const u8,
) MailboxError!u8 {
    var used: u8 = 0;
    while (used < relay_pool.pool_capacity and storage.relay_url_lens[used] != 0) : (used += 1) {
        if (relay_url.relayUrlsEquivalent(storage.relayUrl(used), relay)) return used;
    }
    if (used == relay_pool.pool_capacity) return error.PoolFull;
    if (relay.len > relay_url.relay_url_max_bytes) return error.RelayUrlTooLong;

    @memset(storage.relay_urls[used][0..], 0);
    std.mem.copyForwards(u8, storage.relay_urls[used][0..relay.len], relay);
    storage.relay_url_lens[used] = @intCast(relay.len);
    return used;
}

test "mailbox session hydrates relay list and unwraps one message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try std.testing.expectEqual(@as(u8, 1), session.relayCount());
    try std.testing.expectEqualStrings("wss://relay.one", session.currentRelayUrl().?);

    try session.markCurrentRelayConnected();

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    const outcome = try session.acceptWrappedMessageJson(
        wrap_event_json,
        recipients[0..],
        arena.allocator(),
    );
    const recipient_pubkey_hex = std.fmt.bytesToHex(&outcome.message.recipients[0].pubkey, .lower);

    try std.testing.expectEqualStrings("wrapped hello", outcome.message.content);
    try std.testing.expectEqual(@as(usize, 1), outcome.message.recipients.len);
    try std.testing.expectEqualStrings(
        "1111111111111111111111111111111111111111111111111111111111111111",
        recipient_pubkey_hex[0..],
    );
}

test "mailbox session rejects malformed relay list event json" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var scratch_storage: [512]u8 = undefined;
    var scratch = std.heap.FixedBufferAllocator.init(&scratch_storage);

    try std.testing.expectError(
        error.InvalidField,
        session.hydrateRelayListEventJson(
            "{\"kind\":\"10050\"}",
            scratch.allocator(),
        ),
    );
}

test "mailbox session rejects malformed relay list tags" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "https://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );

    try std.testing.expectError(
        error.InvalidRelayUrl,
        session.hydrateRelayListEventJson(relay_list_json, arena.allocator()),
    );
}

test "mailbox session rejects invalid relay list signatures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    const sig_marker = std.mem.indexOf(u8, relay_list_json, "\"sig\":\"") orelse unreachable;
    relay_list_storage[sig_marker + 7] = if (relay_list_storage[sig_marker + 7] == '0') '1' else '0';

    try std.testing.expectError(
        error.InvalidSignature,
        session.hydrateRelayListEventJson(relay_list_storage[0..relay_list_json.len], arena.allocator()),
    );
}

test "mailbox session rejects relay lists authored by a different pubkey" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    const items = [_][]const u8{ "relay", "wss://relay.one" };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = items[0..] }};
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = test_wrap_signer_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = 1_710_000_030,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&test_wrap_signer_secret, &event);

    try std.testing.expectError(
        error.RelayListAuthorMismatch,
        session.hydrateRelayListEvent(&event),
    );
}

test "mailbox session rejects malformed wrapped messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    try std.testing.expectError(
        error.InvalidWrapEvent,
        session.acceptWrappedMessageJson(
            "{\"id\":\"0000000000000000000000000000000000000000000000000000000000000000\"," ++
                "\"pubkey\":\"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9\"," ++
                "\"created_at\":1710000020,\"kind\":1059,\"tags\":[],\"content\":\"\",\"sig\":\"" ++
                "0000000000000000000000000000000000000000000000000000000000000000" ++
                "0000000000000000000000000000000000000000000000000000000000000000\"}",
            recipients[0..],
            arena.allocator(),
        ),
    );
}

test "mailbox session requires a connected relay before intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    try std.testing.expectError(
        error.RelayDisconnected,
        session.acceptWrappedMessageJson(wrap_event_json, recipients[0..], arena.allocator()),
    );
}

test "mailbox session rejects duplicate wrapped messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    _ = try session.acceptWrappedMessageJson(wrap_event_json, recipients[0..], arena.allocator());

    try std.testing.expectError(
        error.DuplicateWrap,
        session.acceptWrappedMessageJson(wrap_event_json, recipients[0..], arena.allocator()),
    );
}

test "mailbox session unwraps wrapped file messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var session = MailboxSession.init(&test_wrap_recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_003,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedFileMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;

    const outcome = try session.acceptWrappedFileMessageJson(
        wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("https://cdn.example/file.enc", outcome.file_message.file_url);
    try std.testing.expectEqualStrings("image/jpeg", outcome.file_message.file_type);
    try std.testing.expectEqualStrings("secret-key", outcome.file_message.decryption_key);
    try std.testing.expectEqual(@as(usize, 1), outcome.file_message.recipients.len);
    try std.testing.expectEqual(@as(usize, 1), outcome.file_message.thumbs.len);
    try std.testing.expectEqual(@as(usize, 1), outcome.file_message.fallbacks.len);
}

test "mailbox session generic envelope intake classifies direct and file messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var direct_session = MailboxSession.init(&test_wrap_recipient_private_key);
    var file_session = MailboxSession.init(&test_wrap_recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_004,
        &test_wrap_recipient_private_key,
    );
    _ = try direct_session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    _ = try file_session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try direct_session.markCurrentRelayConnected();
    try file_session.markCurrentRelayConnected();

    var direct_wrap_storage: [8192]u8 = undefined;
    const direct_wrap_json = try buildValidWrappedMessageJson(direct_wrap_storage[0..]);
    var direct_recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var no_thumbs: [0][]const u8 = .{};
    var no_fallbacks: [0][]const u8 = .{};
    const direct = try direct_session.acceptWrappedEnvelopeJson(
        direct_wrap_json,
        direct_recipients[0..],
        no_thumbs[0..],
        no_fallbacks[0..],
        arena.allocator(),
    );
    try std.testing.expect(direct == .direct_message);
    try std.testing.expectEqualStrings("wrapped hello", direct.direct_message.message.content);

    var file_wrap_storage: [8192]u8 = undefined;
    const file_wrap_json = try buildValidWrappedFileMessageJson(file_wrap_storage[0..]);
    var file_recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const file = try file_session.acceptWrappedEnvelopeJson(
        file_wrap_json,
        file_recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );
    try std.testing.expect(file == .file_message);
    try std.testing.expectEqualStrings("https://cdn.example/file.enc", file.file_message.file_message.file_url);
}

test "mailbox session generic envelope intake rejects unsupported rumor kinds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var session = MailboxSession.init(&test_wrap_recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_005,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidUnsupportedWrappedJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [0][]const u8 = .{};
    var fallbacks: [0][]const u8 = .{};

    try std.testing.expectError(
        error.UnsupportedRumorKind,
        session.acceptWrappedEnvelopeJson(
            wrap_event_json,
            recipients[0..],
            thumbs[0..],
            fallbacks[0..],
            arena.allocator(),
        ),
    );
}

test "mailbox session advance relay resets receive readiness" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonTwo(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expect(session.currentRelayCanReceive());

    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try std.testing.expect(!session.currentRelayCanReceive());
}

test "mailbox session runtime inspection classifies relay actions and marks current relay" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var runtime_storage = MailboxRuntimeStorage{};
    const runtime = try session.inspectRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 3), runtime.relay_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.connect_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.receive_count);

    const first = runtime.entry(0).?;
    try std.testing.expectEqual(@as(u8, 0), first.relay_index);
    try std.testing.expectEqual(MailboxRuntimeAction.authenticate, first.action);
    try std.testing.expect(!first.is_current);
    const second = runtime.entry(1).?;
    try std.testing.expectEqual(@as(u8, 1), second.relay_index);
    try std.testing.expectEqual(MailboxRuntimeAction.receive, second.action);
    try std.testing.expect(second.is_current);
    const third = runtime.entry(2).?;
    try std.testing.expectEqual(@as(u8, 2), third.relay_index);
    try std.testing.expectEqual(MailboxRuntimeAction.connect, third.action);
    try std.testing.expect(!third.is_current);
}

test "mailbox session explicit relay selection switches current relay without mutating states" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");
    try std.testing.expectEqualStrings("wss://relay.three", try session.selectRelay(2));
    try std.testing.expectEqualStrings("wss://relay.three", session.currentRelayUrl().?);
    try std.testing.expect(!session.currentRelayCanReceive());

    var runtime_storage = MailboxRuntimeStorage{};
    const runtime = try session.inspectRuntime(&runtime_storage);
    try std.testing.expect(runtime.entry(0).?.relay_index == 0);
    try std.testing.expectEqual(MailboxRuntimeAction.authenticate, runtime.entry(0).?.action);
    try std.testing.expect(runtime.entry(2).?.is_current);

    try std.testing.expectError(error.InvalidRelayIndex, session.selectRelay(3));
}

test "mailbox runtime next step prefers receive then authenticate then connect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var runtime_storage = MailboxRuntimeStorage{};
    const runtime = try session.inspectRuntime(&runtime_storage);
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep().?;
    try std.testing.expectEqual(MailboxRuntimeAction.receive, next.action);
    try std.testing.expectEqualStrings("wss://relay.two", next.relay_url);
    try std.testing.expect(next.is_current);
    try std.testing.expectEqual(next.action, next_step.entry.action);
    try std.testing.expectEqualStrings(next.relay_url, next_step.entry.relay_url);
    try std.testing.expectEqual(next.is_current, next_step.entry.is_current);
}

test "mailbox runtime next step falls back to authenticate before connect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var runtime_storage = MailboxRuntimeStorage{};
    const auth_runtime = try session.inspectRuntime(&runtime_storage);
    const auth_next = auth_runtime.nextEntry().?;
    const auth_step = auth_runtime.nextStep().?;
    try std.testing.expectEqual(MailboxRuntimeAction.authenticate, auth_next.action);
    try std.testing.expectEqualStrings("wss://relay.one", auth_next.relay_url);
    try std.testing.expectEqual(auth_next.action, auth_step.entry.action);
    try std.testing.expectEqualStrings(auth_next.relay_url, auth_step.entry.relay_url);
}

test "mailbox runtime next step falls back to connect when no relay can receive or authenticate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try std.testing.expectEqualStrings("wss://relay.two", try session.selectRelay(1));

    var runtime_storage = MailboxRuntimeStorage{};
    const runtime = try session.inspectRuntime(&runtime_storage);
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep().?;
    try std.testing.expectEqual(MailboxRuntimeAction.connect, next.action);
    try std.testing.expectEqualStrings("wss://relay.two", next.relay_url);
    try std.testing.expect(next.is_current);
    try std.testing.expectEqual(next.action, next_step.entry.action);
    try std.testing.expectEqualStrings(next.relay_url, next_step.entry.relay_url);
    try std.testing.expectEqual(next.is_current, next_step.entry.is_current);
}

test "mailbox runtime next step returns null for an empty plan" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var runtime_storage = MailboxRuntimeStorage{};
    const runtime = MailboxRuntimePlan{
        .relay_count = 0,
        .connect_count = 0,
        .authenticate_count = 0,
        .receive_count = 0,
        ._session = &session,
        ._storage = &runtime_storage,
    };
    try std.testing.expect(runtime.nextEntry() == null);
    try std.testing.expect(runtime.nextStep() == null);
    try std.testing.expect(runtime.nextReceiveEntry() == null);
    try std.testing.expect(runtime.nextReceiveStep() == null);
}

test "mailbox receive turn selects one ready relay and accepts one wrapped envelope" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var session = MailboxSession.init(&test_wrap_recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonTwo(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var receive_storage = MailboxReceiveTurnStorage{};
    const request = try session.beginReceiveTurn(&receive_storage);
    try std.testing.expectEqual(@as(u8, 1), request.relay_index);
    try std.testing.expectEqualStrings("wss://relay.two", request.relay_url);

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const result = try session.acceptReceiveEnvelopeJson(
        &request,
        wrap_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(result.envelope == .direct_message);
    try std.testing.expectEqualStrings("wrapped hello", result.envelope.direct_message.message.content);
}

test "mailbox receive turn rejects stale relay selection explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var session = MailboxSession.init(&test_wrap_recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonTwo(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var receive_storage = MailboxReceiveTurnStorage{};
    const request = try session.beginReceiveTurn(&receive_storage);
    try std.testing.expectEqualStrings("wss://relay.one", try session.selectRelay(0));

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    try std.testing.expectError(
        error.StaleReceiveTurn,
        session.acceptReceiveEnvelopeJson(
            &request,
            wrap_event_json,
            recipients[0..],
            thumbs[0..0],
            fallbacks[0..0],
            arena.allocator(),
        ),
    );
}

test "mailbox sync turn promotes pending delivery into one explicit publish step" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var sender_session = MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [4096]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonTwo(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        1_710_000_041,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try sender_session.advanceRelay());
    try sender_session.markCurrentRelayConnected();

    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonOne(
        recipient_relay_list_storage[0..],
        "wss://relay.two",
        1_710_000_042,
        &recipient_secret,
    );
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};
    const delivery = try sender_session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two",
            .content = "sync publish payload",
            .created_at = 44,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var sync_storage = MailboxSyncTurnStorage{};
    const sync_request = try sender_session.beginSyncTurn(.{
        .pending_delivery = &delivery,
        .storage = &sync_storage.workflow,
    });
    try std.testing.expect(sync_request == .publish);
    try std.testing.expectEqualStrings("wss://relay.two", sync_request.publish.relay_url);
    try std.testing.expect(sync_request.publish.role.recipient);
}

test "mailbox direct-message delivery keeps reply refs in the wrapped rumor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);
    const reply_event_id = [_]u8{0x77} ** 32;

    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_051,
        &recipient_secret,
    );

    var sender_session = MailboxSession.init(&sender_secret);
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};
    const delivery = try sender_session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        relay_list_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .reply_to = .{
                .event_id = reply_event_id,
                .relay_hint = "wss://thread.example",
            },
            .content = "reply over mailbox",
            .created_at = 55,
            .wrap_signer_private_key = [_]u8{0x33} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var recipient_session = MailboxSession.init(&recipient_secret);
    _ = try recipient_session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try recipient_session.markCurrentRelayConnected();
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const envelope = try recipient_session.acceptWrappedEnvelopeJson(
        delivery.wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );
    try std.testing.expect(envelope == .direct_message);
    try std.testing.expect(envelope.direct_message.message.reply_to != null);
    try std.testing.expectEqualSlices(
        u8,
        &reply_event_id,
        &envelope.direct_message.message.reply_to.?.event_id,
    );
    try std.testing.expectEqualStrings(
        "wss://thread.example",
        envelope.direct_message.message.reply_to.?.relay_hint.?,
    );
}

test "mailbox sync turn falls back to receive and reuses the receive turn floor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var session = MailboxSession.init(&test_wrap_recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var sync_storage = MailboxSyncTurnStorage{};
    const sync_request = try session.beginSyncTurn(.{
        .storage = &sync_storage.workflow,
    });
    try std.testing.expect(sync_request == .receive);
    try std.testing.expectEqualStrings("wss://relay.one", sync_request.receive.relay_url);

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const result = try session.acceptSyncEnvelopeJson(
        &sync_request,
        wrap_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(result == .received);
    try std.testing.expectEqualStrings("wrapped hello", result.received.envelope.direct_message.message.content);
}

test "mailbox workflow inspection keeps only the current connected relay on receive and leaves others idle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var workflow_storage = MailboxWorkflowStorage{};
    const workflow = try session.inspectWorkflow(.{
        .storage = &workflow_storage,
    });
    try std.testing.expectEqual(@as(u8, 1), workflow.receive_count);
    try std.testing.expectEqual(@as(u8, 1), workflow.idle_count);
    try std.testing.expectEqual(@as(u8, 1), workflow.connect_count);
    try std.testing.expectEqual(MailboxWorkflowAction.idle, workflow.entry(0).?.action);
    try std.testing.expectEqual(MailboxWorkflowAction.receive, workflow.entry(1).?.action);
    try std.testing.expect(workflow.entry(1).?.is_current);
    try std.testing.expectEqual(MailboxWorkflowAction.connect, workflow.entry(2).?.action);
}

test "mailbox workflow inspection promotes pending direct-message delivery relays into publish actions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var session = MailboxSession.init(&sender_private_key);
    var sender_relay_list_storage: [4096]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonThree(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two/inbox",
        "wss://relay.three",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two/inbox", try session.advanceRelay());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.three", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};
    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonTwo(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        1_710_000_040,
        &recipient_private_key,
    );
    const delivery = try session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        sender_relay_list_json,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two/inbox",
            .content = "hello workflow",
            .created_at = 1_710_000_100,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var workflow_storage = MailboxWorkflowStorage{};
    const workflow = try session.inspectWorkflow(.{
        .pending_delivery = &delivery,
        .storage = &workflow_storage,
    });
    try std.testing.expectEqual(@as(u8, 2), workflow.publish_recipient_count);
    try std.testing.expectEqual(@as(u8, 1), workflow.publish_sender_copy_count);
    try std.testing.expectEqual(@as(u8, 0), workflow.receive_count);
    const first = workflow.entry(0).?;
    try std.testing.expectEqual(MailboxWorkflowAction.publish_recipient, first.action);
    try std.testing.expect(first.role.recipient);
    try std.testing.expect(first.role.sender_copy);
    try std.testing.expect(first.wrap_event_json != null);
    const second = workflow.entry(1).?;
    try std.testing.expectEqual(MailboxWorkflowAction.publish_recipient, second.action);
    try std.testing.expect(second.role.recipient);
    try std.testing.expect(second.role.sender_copy);
    const third = workflow.entry(2).?;
    try std.testing.expectEqual(MailboxWorkflowAction.publish_sender_copy, third.action);
    try std.testing.expect(!third.role.recipient);
    try std.testing.expect(third.role.sender_copy);
}

test "mailbox workflow next entry follows delivery order while preserving relay readiness preconditions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var session = MailboxSession.init(&sender_private_key);
    var sender_relay_list_storage: [4096]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonThree(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two/inbox",
        "wss://relay.three",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two/inbox", try session.advanceRelay());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};
    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonTwo(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        1_710_000_040,
        &recipient_private_key,
    );
    const delivery = try session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        sender_relay_list_json,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two/inbox",
            .content = "hello workflow",
            .created_at = 1_710_000_100,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var workflow_storage = MailboxWorkflowStorage{};
    const workflow = try session.inspectWorkflow(.{
        .pending_delivery = &delivery,
        .storage = &workflow_storage,
    });
    const next = workflow.nextEntry().?;
    try std.testing.expectEqual(MailboxWorkflowAction.authenticate, next.action);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", next.relay_url);
    try std.testing.expect(next.role.recipient);
    try std.testing.expect(next.role.sender_copy);
}

test "mailbox workflow next entry falls back to current receive when no delivery is pending" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var workflow_storage = MailboxWorkflowStorage{};
    const workflow = try session.inspectWorkflow(.{
        .storage = &workflow_storage,
    });
    const next = workflow.nextEntry().?;
    try std.testing.expectEqual(MailboxWorkflowAction.receive, next.action);
    try std.testing.expectEqualStrings("wss://relay.two", next.relay_url);
    try std.testing.expect(next.is_current);
}

test "mailbox workflow next step packages the selected workflow entry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var workflow_storage = MailboxWorkflowStorage{};
    const workflow = try session.inspectWorkflow(.{
        .storage = &workflow_storage,
    });
    const next = workflow.nextEntry().?;
    const next_step = workflow.nextStep().?;
    try std.testing.expectEqual(next.action, next_step.entry.action);
    try std.testing.expectEqual(next.relay_index, next_step.entry.relay_index);
    try std.testing.expectEqualStrings(next.relay_url, next_step.entry.relay_url);
    try std.testing.expectEqual(next.is_current, next_step.entry.is_current);
}

test "mailbox workflow next step returns null for an empty plan" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var workflow_storage = MailboxWorkflowStorage{};
    var runtime_storage = MailboxRuntimeStorage{};
    const workflow = MailboxWorkflowPlan{
        .relay_count = 0,
        ._session = &session,
        ._runtime = .{
            .relay_count = 0,
            .connect_count = 0,
            .authenticate_count = 0,
            .receive_count = 0,
            ._session = &session,
            ._storage = &runtime_storage,
        },
        ._delivery = null,
        ._storage = &workflow_storage,
    };
    try std.testing.expect(workflow.nextEntry() == null);
    try std.testing.expect(workflow.nextStep() == null);
}

test "mailbox workflow relay selection follows the typed workflow step" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [4096]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonThree(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        "wss://relay.three",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();

    var workflow_storage = MailboxWorkflowStorage{};
    const workflow = try session.inspectWorkflow(.{
        .storage = &workflow_storage,
    });
    const next_step = workflow.nextStep().?;
    try std.testing.expectEqualStrings("wss://relay.two", try session.selectWorkflowRelay(next_step));
    try std.testing.expectEqualStrings("wss://relay.two", session.currentRelayUrl().?);
}

test "mailbox session relay list hydration replaces stale relays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var first_storage: [2048]u8 = undefined;
    var second_storage: [2048]u8 = undefined;
    const first_json = try buildRelayListEventJsonTwo(
        first_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    const second_json = try buildRelayListEventJsonOne(
        second_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );

    _ = try session.hydrateRelayListEventJson(first_json, arena.allocator());
    try std.testing.expectEqual(@as(u8, 2), session.relayCount());
    _ = try session.hydrateRelayListEventJson(second_json, arena.allocator());

    try std.testing.expectEqual(@as(u8, 1), session.relayCount());
    try std.testing.expectEqualStrings("wss://relay.one", session.currentRelayUrl().?);
}

test "mailbox session blocks intake until auth succeeds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.acceptWrappedMessageJson(wrap_event_json, recipients[0..], arena.allocator()),
    );

    const auth_event_json =
        \\{"id":"3dc7a38754fee63558d2020588ad38b8baac483969944a6b144735cf415acaa8","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","challenge-1"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    try session.acceptCurrentRelayAuthEventJson(
        auth_event_json,
        1_773_533_654,
        60,
        arena.allocator(),
    );
    const outcome = try session.acceptWrappedMessageJson(
        wrap_event_json,
        recipients[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wrapped hello", outcome.message.content);
}

test "mailbox session preserves auth gating across relay rotation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonTwo(
        relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two",
        1_710_000_031,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());
    try session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.one", try session.advanceRelay());
    try session.markCurrentRelayConnected();
    try std.testing.expect(!session.currentRelayCanReceive());

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.acceptWrappedMessageJson(wrap_event_json, recipients[0..], arena.allocator()),
    );
}

test "mailbox session blocks intake after same relay disconnect until reconnected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var wrap_json_storage: [8192]u8 = undefined;
    const wrap_event_json = try buildValidWrappedMessageJson(wrap_json_storage[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;

    try session.noteCurrentRelayDisconnected();
    try std.testing.expectError(
        error.RelayDisconnected,
        session.acceptWrappedMessageJson(wrap_event_json, recipients[0..], arena.allocator()),
    );

    try session.markCurrentRelayConnected();
    const outcome = try session.acceptWrappedMessageJson(
        wrap_event_json,
        recipients[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wrapped hello", outcome.message.content);
}

test "mailbox session builds one outbound direct message that recipient session can unwrap" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var sender_relay_list_storage: [2048]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonOne(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "hello outbound",
            .created_at = 1_710_000_100,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", outbound.relay_url);

    const parsed_wrap = try noztr.nip01_event.event_parse_json(outbound.wrap_event_json, arena.allocator());
    try noztr.nip59_wrap.nip59_validate_wrap_structure(&parsed_wrap);
    try std.testing.expect(std.mem.eql(u8, &parsed_wrap.id, &outbound.wrap_event_id));
    try std.testing.expectEqual(@as(usize, 1), parsed_wrap.tags.len);
    try std.testing.expectEqualStrings("p", parsed_wrap.tags[0].items[0]);
    const recipient_pubkey_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    try std.testing.expectEqualStrings(recipient_pubkey_hex[0..], parsed_wrap.tags[0].items[1]);

    var recipient_session = MailboxSession.init(&recipient_private_key);
    var recipient_relay_list_storage: [2048]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonOne(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_031,
        &recipient_private_key,
    );
    _ = try recipient_session.hydrateRelayListEventJson(
        recipient_relay_list_json,
        arena.allocator(),
    );
    try recipient_session.markCurrentRelayConnected();

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    const outcome = try recipient_session.acceptWrappedMessageJson(
        outbound.wrap_event_json,
        recipients[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("hello outbound", outcome.message.content);
    try std.testing.expectEqual(@as(usize, 1), outcome.message.recipients.len);
    try std.testing.expect(std.mem.eql(u8, &recipient_pubkey, &outcome.message.recipients[0].pubkey));
}

test "mailbox session builds one outbound file message that recipient session can unwrap" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var sender_relay_list_storage: [2048]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonOne(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = MailboxOutboundBuffer{};
    const outbound = try sender_session.beginFileMessage(
        &outbound_buffer,
        &testFileMessageRequest(recipient_pubkey),
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", outbound.relay_url);

    var recipient_session = MailboxSession.init(&recipient_private_key);
    var recipient_relay_list_storage: [2048]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonOne(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_031,
        &recipient_private_key,
    );
    _ = try recipient_session.hydrateRelayListEventJson(
        recipient_relay_list_json,
        arena.allocator(),
    );
    try recipient_session.markCurrentRelayConnected();

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const outcome = try recipient_session.acceptWrappedEnvelopeJson(
        outbound.wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );
    try std.testing.expect(outcome == .file_message);
    try std.testing.expectEqualStrings(
        "https://cdn.example/file.enc",
        outcome.file_message.file_message.file_url,
    );
    try std.testing.expectEqualStrings(
        "image/jpeg",
        outcome.file_message.file_message.file_type,
    );
    try std.testing.expectEqual(@as(usize, 1), outcome.file_message.file_message.recipients.len);
    try std.testing.expectEqual(@as(usize, 1), outcome.file_message.file_message.thumbs.len);
}

test "mailbox unsigned event-object json includes id, omits sig, and is not canonical preimage json" {
    var rumor_fixture: TestRumorFixture = undefined;
    try buildRumorFixture(&rumor_fixture);

    var canonical_storage: [1024]u8 = undefined;
    const canonical_json = try noztr.nip01_event.event_serialize_canonical_json(
        canonical_storage[0..],
        &rumor_fixture.event,
    );

    try std.testing.expect(std.mem.indexOf(u8, rumor_fixture.json, "\"id\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rumor_fixture.json, "\"sig\":\"") == null);
    try std.testing.expect(!std.mem.eql(u8, rumor_fixture.json, canonical_json));
}

test "mailbox session outbound direct message uses current relay target and blocks when relay is not ready" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var session = MailboxSession.init(&sender_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());

    var outbound_buffer = MailboxOutboundBuffer{};
    const request: MailboxDirectMessageRequest = .{
        .recipient_pubkey = recipient_pubkey,
        .content = "hello outbound",
        .created_at = 1_710_000_100,
        .wrap_signer_private_key = [_]u8{0x22} ** 32,
        .seal_nonce = [_]u8{0x44} ** 32,
        .wrap_nonce = [_]u8{0x55} ** 32,
    };
    try std.testing.expectError(
        error.RelayDisconnected,
        session.beginDirectMessage(&outbound_buffer, &request, arena.allocator()),
    );

    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.beginDirectMessage(&outbound_buffer, &request, arena.allocator()),
    );
}

test "mailbox session outbound direct message rejects invalid recipient pubkeys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    var session = MailboxSession.init(&sender_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var outbound_buffer = MailboxOutboundBuffer{};
    try std.testing.expectError(
        error.InvalidRecipientPubkey,
        session.beginDirectMessage(
            &outbound_buffer,
            &.{
                .recipient_pubkey = [_]u8{0} ** 32,
                .content = "hello outbound",
                .created_at = 1_710_000_100,
                .wrap_signer_private_key = [_]u8{0x22} ** 32,
                .seal_nonce = [_]u8{0x44} ** 32,
                .wrap_nonce = [_]u8{0x55} ** 32,
            },
            arena.allocator(),
        ),
    );
}

test "mailbox session plans relay fanout against recipient relay list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};
    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonTwo(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        1_710_000_040,
        &recipient_private_key,
    );

    const plan = try sender_session.planDirectMessageRelayFanout(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two/inbox",
            .content = "hello fanout",
            .created_at = 1_710_000_100,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", plan.relayUrl(0).?);
    try std.testing.expectEqualStrings("wss://relay.one", plan.relayUrl(1).?);
    try std.testing.expect(plan.deliversToRecipient(0));
    try std.testing.expect(!plan.deliversSenderCopy(0));
    try std.testing.expect(plan.deliversToRecipient(1));
    try std.testing.expect(!plan.deliversSenderCopy(1));

    const parsed_wrap = try noztr.nip01_event.event_parse_json(plan.wrap_event_json, arena.allocator());
    try noztr.nip59_wrap.nip59_validate_wrap_structure(&parsed_wrap);
    try std.testing.expect(std.mem.eql(u8, &parsed_wrap.id, &plan.wrap_event_id));

    var recipient_session = MailboxSession.init(&recipient_private_key);
    _ = try recipient_session.hydrateRelayListEventJson(
        recipient_relay_list_json,
        arena.allocator(),
    );
    _ = try recipient_session.advanceRelay();
    try recipient_session.markCurrentRelayConnected();

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    const outcome = try recipient_session.acceptWrappedMessageJson(
        plan.wrap_event_json,
        recipients[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("hello fanout", outcome.message.content);
}

test "mailbox session plans sender copy delivery without duplicating equivalent relay urls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};

    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonTwo(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        1_710_000_040,
        &recipient_private_key,
    );

    var sender_relay_list_storage: [4096]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonTwo(
        sender_relay_list_storage[0..],
        "wss://relay.two/inbox",
        "wss://relay.three",
        1_710_000_041,
        &sender_private_key,
    );

    const plan = try sender_session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        sender_relay_list_json,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two/inbox",
            .content = "hello sender copy",
            .created_at = 1_710_000_100,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    try std.testing.expectEqual(@as(u8, 3), plan.relay_count);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", plan.relayUrl(0).?);
    try std.testing.expect(plan.deliversToRecipient(0));
    try std.testing.expect(plan.deliversSenderCopy(0));
    try std.testing.expectEqualStrings("wss://relay.one", plan.relayUrl(1).?);
    try std.testing.expect(plan.deliversToRecipient(1));
    try std.testing.expect(!plan.deliversSenderCopy(1));
    try std.testing.expectEqualStrings("wss://relay.three", plan.relayUrl(2).?);
    try std.testing.expect(!plan.deliversToRecipient(2));
    try std.testing.expect(plan.deliversSenderCopy(2));
    try std.testing.expectEqual(@as(?u8, 0), plan.nextRelayIndex());
    try std.testing.expectEqual(@as(?u8, 0), plan.nextRecipientRelayIndex());
    try std.testing.expectEqual(@as(?u8, 0), plan.nextSenderCopyRelayIndex());
    const next_step = plan.nextStep().?;
    const next_recipient = plan.nextRecipientStep().?;
    const next_sender_copy = plan.nextSenderCopyStep().?;
    try std.testing.expectEqual(@as(u8, 0), next_step.relay_index);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", next_step.relay_url);
    try std.testing.expect(next_step.role.recipient);
    try std.testing.expect(next_step.role.sender_copy);
    try std.testing.expect(std.mem.eql(u8, &next_step.wrap_event_id, &plan.wrap_event_id));
    try std.testing.expectEqualStrings(plan.wrap_event_json, next_step.wrap_event_json);
    try std.testing.expectEqual(next_step.relay_index, next_recipient.relay_index);
    try std.testing.expectEqual(next_step.relay_index, next_sender_copy.relay_index);
}

test "mailbox session plans file-message delivery without duplicating equivalent relay urls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};

    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonTwo(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        1_710_000_040,
        &recipient_private_key,
    );

    var sender_relay_list_storage: [4096]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJsonTwo(
        sender_relay_list_storage[0..],
        "wss://relay.two/inbox",
        "wss://relay.three",
        1_710_000_041,
        &sender_private_key,
    );

    const plan = try sender_session.planFileMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        sender_relay_list_json,
        &testFileMessageRequest(recipient_pubkey),
        arena.allocator(),
    );

    try std.testing.expectEqual(@as(u8, 3), plan.relay_count);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", plan.relayUrl(0).?);
    try std.testing.expect(plan.deliversToRecipient(0));
    try std.testing.expect(plan.deliversSenderCopy(0));
    try std.testing.expectEqualStrings("wss://relay.one", plan.relayUrl(1).?);
    try std.testing.expect(plan.deliversToRecipient(1));
    try std.testing.expect(!plan.deliversSenderCopy(1));
    try std.testing.expectEqualStrings("wss://relay.three", plan.relayUrl(2).?);
    try std.testing.expect(!plan.deliversToRecipient(2));
    try std.testing.expect(plan.deliversSenderCopy(2));
    try std.testing.expectEqual(@as(?u8, 0), plan.nextRelayIndex());
    try std.testing.expectEqual(@as(?u8, 0), plan.nextRecipientRelayIndex());
    try std.testing.expectEqual(@as(?u8, 0), plan.nextSenderCopyRelayIndex());
    const next_step = plan.nextStep().?;
    const next_recipient = plan.nextRecipientStep().?;
    const next_sender_copy = plan.nextSenderCopyStep().?;
    try std.testing.expectEqual(@as(u8, 0), next_step.relay_index);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", next_step.relay_url);
    try std.testing.expect(next_step.role.recipient);
    try std.testing.expect(next_step.role.sender_copy);
    try std.testing.expectEqual(next_step.relay_index, next_recipient.relay_index);
    try std.testing.expectEqual(next_step.relay_index, next_sender_copy.relay_index);
}

test "mailbox delivery next relay prefers recipient targets before sender copy only relays" {
    var storage = MailboxDeliveryStorage{};
    std.mem.copyForwards(u8, storage.relay_urls[0][0.."wss://sender-copy".len], "wss://sender-copy");
    storage.relay_url_lens[0] = "wss://sender-copy".len;
    storage.sender_copy_targets[0] = true;
    std.mem.copyForwards(u8, storage.relay_urls[1][0.."wss://recipient".len], "wss://recipient");
    storage.relay_url_lens[1] = "wss://recipient".len;
    storage.recipient_targets[1] = true;
    const plan = MailboxDeliveryPlan{
        .relay_count = 2,
        .wrap_event_id = [_]u8{0} ** 32,
        .wrap_event_json = "",
        ._storage = &storage,
    };
    try std.testing.expectEqual(@as(?u8, 1), plan.nextRelayIndex());
    try std.testing.expectEqual(@as(?u8, 1), plan.nextRecipientRelayIndex());
    try std.testing.expectEqual(@as(?u8, 0), plan.nextSenderCopyRelayIndex());
    const next_step = plan.nextStep().?;
    const next_recipient = plan.nextRecipientStep().?;
    const next_sender_copy = plan.nextSenderCopyStep().?;
    try std.testing.expectEqual(@as(u8, 1), next_step.relay_index);
    try std.testing.expectEqualStrings("wss://recipient", next_step.relay_url);
    try std.testing.expect(next_step.role.recipient);
    try std.testing.expect(!next_step.role.sender_copy);
    try std.testing.expectEqual(@as(u8, 1), next_recipient.relay_index);
    try std.testing.expectEqual(@as(u8, 0), next_sender_copy.relay_index);
}

test "mailbox delivery next relay falls back to sender copy when no recipient relay exists" {
    var storage = MailboxDeliveryStorage{};
    std.mem.copyForwards(u8, storage.relay_urls[0][0.."wss://sender-copy".len], "wss://sender-copy");
    storage.relay_url_lens[0] = "wss://sender-copy".len;
    storage.sender_copy_targets[0] = true;
    const plan = MailboxDeliveryPlan{
        .relay_count = 1,
        .wrap_event_id = [_]u8{0} ** 32,
        .wrap_event_json = "",
        ._storage = &storage,
    };
    try std.testing.expectEqual(@as(?u8, 0), plan.nextRelayIndex());
    try std.testing.expect(plan.nextRecipientRelayIndex() == null);
    try std.testing.expectEqual(@as(?u8, 0), plan.nextSenderCopyRelayIndex());
    const next_step = plan.nextStep().?;
    try std.testing.expect(plan.nextRecipientStep() == null);
    const next_sender_copy = plan.nextSenderCopyStep().?;
    try std.testing.expectEqual(@as(u8, 0), next_step.relay_index);
    try std.testing.expectEqualStrings("wss://sender-copy", next_step.relay_url);
    try std.testing.expect(!next_step.role.recipient);
    try std.testing.expect(next_step.role.sender_copy);
    try std.testing.expectEqual(next_step.relay_index, next_sender_copy.relay_index);
}

test "mailbox delivery next relay returns null for an empty delivery plan" {
    var storage = MailboxDeliveryStorage{};
    const plan = MailboxDeliveryPlan{
        .relay_count = 0,
        .wrap_event_id = [_]u8{0} ** 32,
        .wrap_event_json = "",
        ._storage = &storage,
    };
    try std.testing.expect(plan.nextRelayIndex() == null);
    try std.testing.expect(plan.nextStep() == null);
    try std.testing.expect(plan.nextRecipientRelayIndex() == null);
    try std.testing.expect(plan.nextRecipientStep() == null);
    try std.testing.expect(plan.nextSenderCopyRelayIndex() == null);
    try std.testing.expect(plan.nextSenderCopyStep() == null);
}

test "mailbox session outbound file message rejects malformed metadata with typed errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var session = MailboxSession.init(&sender_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonOne(
        relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_030,
        &sender_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try session.markCurrentRelayConnected();

    var outbound_buffer = MailboxOutboundBuffer{};
    var request = testFileMessageRequest(recipient_pubkey);
    request.file_url = "not-a-url";
    try std.testing.expectError(
        error.InvalidFileUrl,
        session.beginFileMessage(&outbound_buffer, &request, arena.allocator()),
    );
}

test "mailbox session rejects relay fanout plans when relay list author does not match recipient" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const other_private_key = [_]u8{0x44} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};
    var wrong_relay_list_storage: [2048]u8 = undefined;
    const wrong_relay_list_json = try buildRelayListEventJsonOne(
        wrong_relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_040,
        &other_private_key,
    );

    try std.testing.expectError(
        error.RelayListRecipientMismatch,
        sender_session.planDirectMessageRelayFanout(
            &outbound_buffer,
            &delivery_storage,
            wrong_relay_list_json,
            &.{
                .recipient_pubkey = recipient_pubkey,
                .content = "hello fanout",
                .created_at = 1_710_000_100,
                .wrap_signer_private_key = [_]u8{0x22} ** 32,
                .seal_nonce = [_]u8{0x44} ** 32,
                .wrap_nonce = [_]u8{0x55} ** 32,
            },
            arena.allocator(),
        ),
    );
}

test "mailbox session rejects sender-copy delivery when sender relay list author does not match actor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_private_key = [_]u8{0x11} ** 32;
    const recipient_private_key = [_]u8{0x33} ** 32;
    const other_private_key = [_]u8{0x44} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_private_key);

    var sender_session = MailboxSession.init(&sender_private_key);
    var outbound_buffer = MailboxOutboundBuffer{};
    var delivery_storage = MailboxDeliveryStorage{};

    var recipient_relay_list_storage: [2048]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonOne(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        1_710_000_040,
        &recipient_private_key,
    );
    var wrong_sender_relay_list_storage: [2048]u8 = undefined;
    const wrong_sender_relay_list_json = try buildRelayListEventJsonOne(
        wrong_sender_relay_list_storage[0..],
        "wss://relay.two",
        1_710_000_041,
        &other_private_key,
    );

    try std.testing.expectError(
        error.SenderRelayListAuthorMismatch,
        sender_session.planDirectMessageDelivery(
            &outbound_buffer,
            &delivery_storage,
            recipient_relay_list_json,
            wrong_sender_relay_list_json,
            &.{
                .recipient_pubkey = recipient_pubkey,
                .content = "hello sender copy",
                .created_at = 1_710_000_100,
                .wrap_signer_private_key = [_]u8{0x22} ** 32,
                .seal_nonce = [_]u8{0x44} ** 32,
                .wrap_nonce = [_]u8{0x55} ** 32,
            },
            arena.allocator(),
        ),
    );
}

test "mailbox session deduplicates normalized-equivalent relay urls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    var relay_list_storage: [2048]u8 = undefined;
    const relay_list_json = try buildRelayListEventJsonTwo(
        relay_list_storage[0..],
        "wss://relay.example.com/path/exact",
        "WSS://RELAY.EXAMPLE.COM:443/path/exact?x=1#f",
        1_710_000_032,
        &test_wrap_recipient_private_key,
    );
    _ = try session.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try std.testing.expectEqual(@as(u8, 1), session.relayCount());
}

test "mailbox session evicts oldest seen wrap when duplicate table fills" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);

    var first_id: [32]u8 = undefined;
    var index: u8 = 0;
    while (index < max_seen_wraps + 1) : (index += 1) {
        var wrap_id = [_]u8{0} ** 32;
        wrap_id[31] = index;
        if (index == 0) first_id = wrap_id;
        try session.rememberWrap(&wrap_id);
    }

    try std.testing.expectEqual(@as(u8, max_seen_wraps), session._state.seen_wrap_count);
    try std.testing.expect(!session.hasSeenWrap(&first_id));
    const newest_id = [_]u8{0} ** 31 ++ [_]u8{max_seen_wraps};
    try std.testing.expect(session.hasSeenWrap(&newest_id));
}

test "mailbox session exposes caller-owned relay-pool adapter storage" {
    var relay_pool_storage = MailboxRelayPoolStorage{};
    var runtime_storage = MailboxRelayPoolRuntimeStorage{};
    _ = &relay_pool_storage;
    _ = &runtime_storage;
}

test "mailbox session exports the shared relay-pool runtime floor" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    _ = try session._state.pool.addRelay("wss://relay.one");
    _ = try session._state.pool.addRelay("wss://relay.two");
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var relay_pool_storage = MailboxRelayPoolStorage{};
    var relay_pool_view = session.exportRelayPool(&relay_pool_storage);
    try std.testing.expectEqual(@as(u8, 2), relay_pool_view.relayCount());

    var plan_storage = shared_runtime.RelayPoolPlanStorage{};
    const plan = relay_pool_view.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
}

test "mailbox session inspects shared relay-pool runtime through caller-owned storage" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    _ = try session._state.pool.addRelay("wss://relay.one");
    _ = try session._state.pool.addRelay("wss://relay.two");
    try session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var relay_pool_runtime = MailboxRelayPoolRuntimeStorage{};
    const plan = session.inspectRelayPoolRuntime(&relay_pool_runtime);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
    try std.testing.expectEqual(shared_runtime.RelayPoolAction.authenticate, plan.nextStep().?.entry.action);
}

test "mailbox session selects a shared relay-pool step back onto the mailbox session" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    _ = try session._state.pool.addRelay("wss://relay.one");
    _ = try session._state.pool.addRelay("wss://relay.two");

    var relay_pool_runtime = MailboxRelayPoolRuntimeStorage{};
    const plan = session.inspectRelayPoolRuntime(&relay_pool_runtime);
    const second = plan.entry(1).?;
    const selected_url = try session.selectRelayPoolStep(&.{ .entry = second });
    try std.testing.expectEqualStrings("wss://relay.two", selected_url);
    try std.testing.expectEqualStrings("wss://relay.two", session.currentRelayUrl().?);
}

test "mailbox session rejects stale relay-pool steps" {
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    var session = MailboxSession.init(&recipient_private_key);
    _ = try session._state.pool.addRelay("wss://relay.one");

    const bad_step = shared_runtime.RelayPoolStep{
        .entry = .{
            .descriptor = .{
                .relay_index = 0,
                .relay_url = "wss://relay.other",
            },
            .action = .connect,
        },
    };
    try std.testing.expectError(error.InvalidRelayPoolStep, session.selectRelayPoolStep(&bad_step));
}

fn classifyMailboxRelayAction(state: relay_session.SessionState) shared_runtime.RelayPoolAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .ready,
    };
}

const test_wrap_signer_pubkey = [_]u8{
    0xF9, 0x30, 0x8A, 0x01, 0x92, 0x58, 0xC3, 0x10,
    0x49, 0x34, 0x4F, 0x85, 0xF8, 0x9D, 0x52, 0x29,
    0xB5, 0x31, 0xC8, 0x45, 0x83, 0x6F, 0x99, 0xB0,
    0x86, 0x01, 0xF1, 0x13, 0xBC, 0xE0, 0x36, 0xF9,
};

fn testFileMessageRequest(recipient_pubkey: [32]u8) MailboxFileMessageRequest {
    return .{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_hint = "wss://relay.two/inbox",
        .file_url = "https://cdn.example/file.enc",
        .file_type = "image/jpeg",
        .decryption_key = "secret-key",
        .decryption_nonce = "secret-nonce",
        .encrypted_file_hash = [_]u8{0x11} ** 32,
        .original_file_hash = [_]u8{0x22} ** 32,
        .size = 4096,
        .dimensions = .{ .width = 800, .height = 600 },
        .blurhash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
        .thumbs = &.{"https://cdn.example/thumb.jpg"},
        .fallbacks = &.{"https://cdn.example/fallback.jpg"},
        .created_at = 1_710_000_100,
        .wrap_signer_private_key = [_]u8{0x22} ** 32,
        .seal_nonce = [_]u8{0x44} ** 32,
        .wrap_nonce = [_]u8{0x55} ** 32,
    };
}

const test_wrap_fixed_nonce_a = [_]u8{0} ** 31 ++ [_]u8{1};
const test_wrap_fixed_nonce_b = [_]u8{0} ** 31 ++ [_]u8{2};
const test_wrap_signer_secret = [_]u8{0} ** 31 ++ [_]u8{3};
const test_wrap_recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};

const TestSignedEventFixture = struct {
    event: noztr.nip01_event.Event,
    json_storage: [4096]u8,
    json: []const u8,
};

const TestRumorFixture = struct {
    event: noztr.nip01_event.Event,
    recipient_tag: noztr.nip17_private_messages.BuiltTag = .{},
    file_metadata_tags: [7]noztr.nip17_private_messages.BuiltFileMetadataTag = undefined,
    json_storage: [2048]u8,
    json: []const u8,
};

const TestWrapFixture = struct {
    rumor: TestRumorFixture,
    seal: TestSignedEventFixture,
    wrap: TestSignedEventFixture,
    seal_payload_storage: [4096]u8,
    wrap_payload_storage: [8192]u8,
};

fn buildValidWrappedMessageJson(output: []u8) ![]const u8 {
    std.debug.assert(builtin.is_test);

    var fixture: TestWrapFixture = undefined;
    try buildValidWrapFixture(&fixture);
    if (output.len < fixture.wrap.json.len) return error.BufferTooSmall;
    @memcpy(output[0..fixture.wrap.json.len], fixture.wrap.json);
    return output[0..fixture.wrap.json.len];
}

fn buildValidWrappedFileMessageJson(output: []u8) ![]const u8 {
    std.debug.assert(builtin.is_test);

    var fixture: TestWrapFixture = undefined;
    try buildValidFileWrapFixture(&fixture);
    if (output.len < fixture.wrap.json.len) return error.BufferTooSmall;
    @memcpy(output[0..fixture.wrap.json.len], fixture.wrap.json);
    return output[0..fixture.wrap.json.len];
}

fn buildValidUnsupportedWrappedJson(output: []u8) ![]const u8 {
    std.debug.assert(builtin.is_test);

    var fixture: TestWrapFixture = undefined;
    try buildValidUnsupportedWrapFixture(&fixture);
    if (output.len < fixture.wrap.json.len) return error.BufferTooSmall;
    @memcpy(output[0..fixture.wrap.json.len], fixture.wrap.json);
    return output[0..fixture.wrap.json.len];
}

fn buildRelayListEventJsonOne(
    output: []u8,
    relay_text: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(signer_secret_key);
    const items = [_][]const u8{ "relay", relay_text };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = items[0..] }};
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = relay_list_author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(signer_secret_key, &event);
    return relayListEventToJsonOne(output, &event, relay_text);
}

fn buildRelayListEventJsonTwo(
    output: []u8,
    relay_url_a: []const u8,
    relay_url_b: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(signer_secret_key);
    const items_a = [_][]const u8{ "relay", relay_url_a };
    const items_b = [_][]const u8{ "relay", relay_url_b };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = items_a[0..] },
        .{ .items = items_b[0..] },
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = relay_list_author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(signer_secret_key, &event);
    return relayListEventToJsonTwo(output, &event, relay_url_a, relay_url_b);
}

fn buildRelayListEventJsonThree(
    output: []u8,
    relay_url_a: []const u8,
    relay_url_b: []const u8,
    relay_url_c: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(signer_secret_key);
    const items_a = [_][]const u8{ "relay", relay_url_a };
    const items_b = [_][]const u8{ "relay", relay_url_b };
    const items_c = [_][]const u8{ "relay", relay_url_c };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = items_a[0..] },
        .{ .items = items_b[0..] },
        .{ .items = items_c[0..] },
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = relay_list_author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(signer_secret_key, &event);
    return relayListEventToJsonThree(output, &event, relay_url_a, relay_url_b, relay_url_c);
}

fn buildValidWrapFixture(output_fixture: *TestWrapFixture) !void {
    std.debug.assert(builtin.is_test);

    try buildRumorFixture(&output_fixture.rumor);
    try finishWrapFixture(output_fixture);
}

fn buildValidFileWrapFixture(output_fixture: *TestWrapFixture) !void {
    std.debug.assert(builtin.is_test);

    try buildFileRumorFixture(&output_fixture.rumor);
    try finishWrapFixture(output_fixture);
}

fn buildValidUnsupportedWrapFixture(output_fixture: *TestWrapFixture) !void {
    std.debug.assert(builtin.is_test);

    try buildUnsupportedRumorFixture(&output_fixture.rumor);
    try finishWrapFixture(output_fixture);
}

fn finishWrapFixture(output_fixture: *TestWrapFixture) !void {
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(
        &test_wrap_recipient_private_key,
    );
    var built_wrap: noztr.nip59_wrap.BuiltWrapEvent = .{};
    const built = try noztr.nip59_wrap.nip59_build_outbound_for_recipient(
        &output_fixture.seal.event,
        &built_wrap,
        &test_wrap_signer_secret,
        &test_wrap_signer_secret,
        &recipient_pubkey,
        &output_fixture.rumor.event,
        output_fixture.rumor.json_storage[0..],
        output_fixture.seal.json_storage[0..],
        output_fixture.seal_payload_storage[0..],
        output_fixture.wrap_payload_storage[0..],
        1_710_000_010,
        1_710_000_020,
        &test_wrap_fixed_nonce_a,
        &test_wrap_fixed_nonce_b,
    );
    output_fixture.rumor.json = built.rumor_json;
    output_fixture.seal.json = built.seal_json;
    output_fixture.seal.event.tags = &.{};
    output_fixture.wrap.event = built_wrap.event;
    output_fixture.wrap.json = try noztr.nip01_event.event_serialize_json_object(
        output_fixture.wrap.json_storage[0..],
        &output_fixture.wrap.event,
    );
}

fn buildRumorFixture(output_fixture: *TestRumorFixture) !void {
    const recipient_items = [_][]const u8{
        "p",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = recipient_items[0..] },
    };
    output_fixture.* = .{
        .event = .{
            .id = [_]u8{0} ** 32,
            .pubkey = test_wrap_signer_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = 14,
            .created_at = 1_710_000_000,
            .content = "wrapped hello",
            .tags = tags[0..],
        },
        .recipient_tag = .{},
        .file_metadata_tags = undefined,
        .json_storage = undefined,
        .json = undefined,
    };
    output_fixture.event.id = try noztr.nip01_event.event_compute_id(&output_fixture.event);
    output_fixture.json = try noztr.nip01_event.event_serialize_json_object_unsigned(
        output_fixture.json_storage[0..],
        &output_fixture.event,
    );
}

fn buildFileRumorFixture(output_fixture: *TestRumorFixture) !void {
    const tags = [_]noztr.nip01_event.EventTag{
        try noztr.nip17_private_messages.nip17_build_recipient_tag(
            &output_fixture.recipient_tag,
            "1111111111111111111111111111111111111111111111111111111111111111",
            null,
        ),
        try noztr.nip17_private_messages.nip17_build_file_type_tag(
            &output_fixture.file_metadata_tags[0],
            "image/jpeg",
        ),
        try noztr.nip17_private_messages.nip17_build_file_encryption_algorithm_tag(
            &output_fixture.file_metadata_tags[1],
            .aes_gcm,
        ),
        try noztr.nip17_private_messages.nip17_build_file_decryption_key_tag(
            &output_fixture.file_metadata_tags[2],
            "secret-key",
        ),
        try noztr.nip17_private_messages.nip17_build_file_decryption_nonce_tag(
            &output_fixture.file_metadata_tags[3],
            "secret-nonce",
        ),
        try noztr.nip17_private_messages.nip17_build_file_hash_tag(
            &output_fixture.file_metadata_tags[4],
            "1111111111111111111111111111111111111111111111111111111111111111",
        ),
        try noztr.nip17_private_messages.nip17_build_file_thumb_tag(
            &output_fixture.file_metadata_tags[5],
            "https://cdn.example/thumb.jpg",
        ),
        try noztr.nip17_private_messages.nip17_build_file_fallback_tag(
            &output_fixture.file_metadata_tags[6],
            "https://cdn.example/fallback.jpg",
        ),
    };
    output_fixture.* = .{
        .event = .{
            .id = [_]u8{0} ** 32,
            .pubkey = test_wrap_signer_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip17_private_messages.file_dm_kind,
            .created_at = 1_710_000_001,
            .content = "https://cdn.example/file.enc",
            .tags = tags[0..],
        },
        .recipient_tag = output_fixture.recipient_tag,
        .file_metadata_tags = output_fixture.file_metadata_tags,
        .json_storage = undefined,
        .json = undefined,
    };
    output_fixture.event.id = try noztr.nip01_event.event_compute_id(&output_fixture.event);
    output_fixture.json = try noztr.nip01_event.event_serialize_json_object_unsigned(
        output_fixture.json_storage[0..],
        &output_fixture.event,
    );
}

fn buildUnsupportedRumorFixture(output_fixture: *TestRumorFixture) !void {
    output_fixture.* = .{
        .event = .{
            .id = [_]u8{0} ** 32,
            .pubkey = test_wrap_signer_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = 1,
            .created_at = 1_710_000_002,
            .content = "note",
            .tags = &.{},
        },
        .json_storage = undefined,
        .json = undefined,
    };
    output_fixture.event.id = try noztr.nip01_event.event_compute_id(&output_fixture.event);
    output_fixture.json = try noztr.nip01_event.event_serialize_json_object_unsigned(
        output_fixture.json_storage[0..],
        &output_fixture.event,
    );
}

fn relayListEventToJsonOne(
    output: []u8,
    event: *const noztr.nip01_event.Event,
    relay_text: []const u8,
) error{BufferTooSmall}![]const u8 {
    _ = relay_text;
    return noztr.nip01_event.event_serialize_json_object(output, event) catch return error.BufferTooSmall;
}

fn relayListEventToJsonTwo(
    output: []u8,
    event: *const noztr.nip01_event.Event,
    relay_url_a: []const u8,
    relay_url_b: []const u8,
) error{BufferTooSmall}![]const u8 {
    _ = relay_url_a;
    _ = relay_url_b;
    return noztr.nip01_event.event_serialize_json_object(output, event) catch return error.BufferTooSmall;
}

fn relayListEventToJsonThree(
    output: []u8,
    event: *const noztr.nip01_event.Event,
    relay_url_a: []const u8,
    relay_url_b: []const u8,
    relay_url_c: []const u8,
) error{BufferTooSmall}![]const u8 {
    _ = relay_url_a;
    _ = relay_url_b;
    _ = relay_url_c;
    return noztr.nip01_event.event_serialize_json_object(output, event) catch return error.BufferTooSmall;
}
