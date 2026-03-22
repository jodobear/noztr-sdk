const std = @import("std");
const noztr = @import("noztr");
const relay_session = @import("../relay/session.zig");

pub const max_group_host_bytes: u16 = noztr.limits.tag_item_bytes_max;
pub const max_group_id_bytes: u16 = noztr.limits.tag_item_bytes_max;
pub const previous_refs_history_capacity: u8 = 50;
pub const previous_ref_text_bytes: u8 = 8;

pub const GroupJoinRequestInfo = noztr.nip29_relay_groups.GroupJoinRequestInfo;
pub const GroupLeaveRequestInfo = noztr.nip29_relay_groups.GroupLeaveRequestInfo;
pub const GroupMetadata = noztr.nip29_relay_groups.GroupMetadata;
pub const GroupAdmin = noztr.nip29_relay_groups.GroupAdmin;
pub const GroupMember = noztr.nip29_relay_groups.GroupMember;
pub const GroupRole = noztr.nip29_relay_groups.GroupRole;
pub const GroupRelayState = relay_session.SessionState;

pub const GroupObservedEventKind = enum {
    metadata,
    admins,
    members,
    roles,
    put_user,
    remove_user,
    join_request,
    leave_request,
    generic,
};

pub const GroupSessionError =
    noztr.nip29_relay_groups.GroupError ||
    noztr.nip42_auth.AuthError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    noztr.nip01_event.EventShapeError ||
    noztr.nostr_keys.NostrKeysError ||
    error{
        InvalidRelayUrl,
        RelayUrlTooLong,
        RelayDisconnected,
        RelayAuthRequired,
        AuthNotRequired,
        ChallengeEmpty,
        ChallengeTooLong,
        GroupRelayHostMismatch,
        UnsupportedGroupEventKind,
        EventGroupMismatch,
        UnknownPreviousReference,
    };

pub const GroupStateEventKind = enum {
    metadata,
    admins,
    members,
    roles,
    put_user,
    remove_user,
};

pub const GroupSessionCapacity = struct {
    users: usize,
    supported_roles: usize,
    user_roles: usize,
};

pub const GroupSessionStorage = struct {
    users: []noztr.nip29_relay_groups.GroupStateUser,
    supported_roles: []noztr.nip29_relay_groups.GroupRole,
    user_roles: [][]const u8,

    pub fn init(
        users: []noztr.nip29_relay_groups.GroupStateUser,
        supported_roles: []noztr.nip29_relay_groups.GroupRole,
        user_roles: [][]const u8,
    ) GroupSessionStorage {
        return .{
            .users = users,
            .supported_roles = supported_roles,
            .user_roles = user_roles,
        };
    }

    pub fn capacity(self: GroupSessionStorage) GroupSessionCapacity {
        return .{
            .users = self.users.len,
            .supported_roles = self.supported_roles.len,
            .user_roles = self.user_roles.len,
        };
    }
};

pub const GroupSessionConfig = struct {
    reference_text: []const u8,
    relay_url: []const u8,
    storage: GroupSessionStorage,
};

pub const GroupSessionView = struct {
    reference: noztr.nip29_relay_groups.GroupReference,
    relay_url: []const u8,
    relay_ready: bool,
    metadata: noztr.nip29_relay_groups.GroupMetadata,
    users: []const noztr.nip29_relay_groups.GroupStateUser,
    supported_roles: []const noztr.nip29_relay_groups.GroupRole,
};

/// Caller-owned storage for one outbound `NIP-29` event JSON payload.
/// `OutboundEvent.event_json` borrows from this buffer until it is overwritten.
pub const OutboundBuffer = struct {
    storage: [noztr.limits.event_json_max]u8 = [_]u8{0} ** noztr.limits.event_json_max,

    fn writable(self: *OutboundBuffer) []u8 {
        return self.storage[0..];
    }
};

pub const PublishContext = struct {
    created_at: u64,
    author_secret_key: [32]u8,
    buffer: *OutboundBuffer,

    pub fn init(
        created_at: u64,
        author_secret_key: *const [32]u8,
        buffer: *OutboundBuffer,
    ) PublishContext {
        return .{
            .created_at = created_at,
            .author_secret_key = author_secret_key.*,
            .buffer = buffer,
        };
    }

    fn writable(self: PublishContext) []u8 {
        return self.buffer.writable();
    }
};

pub const OutboundEvent = struct {
    relay_url: []const u8,
    event_id: [32]u8,
    event_json: []const u8,
};

pub const CheckpointBuffers = struct {
    metadata: OutboundBuffer = .{},
    admins: OutboundBuffer = .{},
    members: OutboundBuffer = .{},
    roles: OutboundBuffer = .{},
};

pub const CheckpointContext = struct {
    created_at_base: u64,
    author_secret_key: [32]u8,
    buffers: *CheckpointBuffers,

    pub fn init(
        created_at_base: u64,
        author_secret_key: *const [32]u8,
        buffers: *CheckpointBuffers,
    ) CheckpointContext {
        return .{
            .created_at_base = created_at_base,
            .author_secret_key = author_secret_key.*,
            .buffers = buffers,
        };
    }

    fn metadataContext(self: *const CheckpointContext) PublishContext {
        return .init(self.created_at_base, &self.author_secret_key, &self.buffers.metadata);
    }

    fn adminsContext(self: *const CheckpointContext) PublishContext {
        return .init(self.created_at_base + 1, &self.author_secret_key, &self.buffers.admins);
    }

    fn membersContext(self: *const CheckpointContext) PublishContext {
        return .init(self.created_at_base + 2, &self.author_secret_key, &self.buffers.members);
    }

    fn rolesContext(self: *const CheckpointContext) PublishContext {
        return .init(self.created_at_base + 3, &self.author_secret_key, &self.buffers.roles);
    }
};

pub const Checkpoint = struct {
    relay_url: []const u8,
    metadata_event_json: []const u8,
    admins_event_json: []const u8,
    members_event_json: []const u8,
    roles_event_json: []const u8,

    pub fn eventJsons(self: *const Checkpoint, out: *[4][]const u8) []const []const u8 {
        out.* = .{
            self.metadata_event_json,
            self.admins_event_json,
            self.members_event_json,
            self.roles_event_json,
        };
        return out[0..];
    }
};

pub const GroupJoinRequestDraft = struct {
    invite_code: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8 = &.{},
};

pub const GroupLeaveRequestDraft = struct {
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8 = &.{},
};

pub const GroupMetadataDraft = struct {
    name: ?[]const u8 = null,
    picture: ?[]const u8 = null,
    about: ?[]const u8 = null,
    is_private: bool = false,
    is_restricted: bool = false,
    is_hidden: bool = false,
    is_closed: bool = false,
};

pub const GroupAdminsDraft = struct {
    admins: []const GroupAdmin,
};

pub const GroupMembersDraft = struct {
    members: []const GroupMember,
};

pub const GroupRolesDraft = struct {
    roles: []const GroupRole,
};

pub const GroupPutUserDraft = struct {
    pubkey: [32]u8,
    roles: []const []const u8,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8 = &.{},
};

pub const GroupRemoveUserDraft = struct {
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8 = &.{},
};

pub const GroupSession = struct {
    const State = struct {
        const RecentEventRef = struct {
            previous_ref: [previous_ref_text_bytes]u8 = [_]u8{0} ** previous_ref_text_bytes,
            pubkey: [32]u8 = [_]u8{0} ** 32,
        };

        relay: relay_session.RelaySession,
        reference_host: [max_group_host_bytes]u8 = [_]u8{0} ** max_group_host_bytes,
        reference_host_len: u16 = 0,
        group_id: [max_group_id_bytes]u8 = [_]u8{0} ** max_group_id_bytes,
        group_id_len: u16 = 0,
        group_state: noztr.nip29_relay_groups.GroupState,
        recent_refs: [previous_refs_history_capacity]RecentEventRef = [_]RecentEventRef{.{}} **
            previous_refs_history_capacity,
        recent_ref_count: u8 = 0,
        recent_ref_head: u8 = 0,
    };

    _state: State,

    pub fn init(
        config: GroupSessionConfig,
    ) GroupSessionError!GroupSession {
        return initWithStorage(
            config.reference_text,
            config.relay_url,
            config.storage.users,
            config.storage.supported_roles,
            config.storage.user_roles,
        );
    }

    pub fn initWithStorage(
        reference_text: []const u8,
        relay_url: []const u8,
        user_storage: []noztr.nip29_relay_groups.GroupStateUser,
        supported_role_storage: []noztr.nip29_relay_groups.GroupRole,
        user_role_storage: [][]const u8,
    ) GroupSessionError!GroupSession {
        const reference = try noztr.nip29_relay_groups.group_reference_parse(reference_text);
        const relay = try relay_session.RelaySession.init(relay_url);
        try ensureRelayMatchesReferenceHost(reference.host, relay_url);

        var session = GroupSession{
            ._state = .{
                .relay = relay,
                .group_state = noztr.nip29_relay_groups.GroupState.init(
                    user_storage,
                    supported_role_storage,
                    user_role_storage,
                ),
            },
        };
        session.storeReference(reference);
        session._state.group_state.reset();
        return session;
    }

    pub fn groupReference(self: *const GroupSession) noztr.nip29_relay_groups.GroupReference {
        return .{
            .host = self._state.reference_host[0..self._state.reference_host_len],
            .id = self._state.group_id[0..self._state.group_id_len],
        };
    }

    pub fn currentRelayUrl(self: *const GroupSession) []const u8 {
        return self._state.relay.auth_session.relayUrl();
    }

    pub fn currentRelayCanReceive(self: *const GroupSession) bool {
        return self._state.relay.canSendRequests();
    }

    pub fn currentRelayState(self: *const GroupSession) GroupRelayState {
        return self._state.relay.state;
    }

    pub fn markCurrentRelayConnected(self: *GroupSession) void {
        self._state.relay.connect();
    }

    pub fn noteCurrentRelayDisconnected(self: *GroupSession) void {
        self._state.relay.disconnect();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *GroupSession,
        challenge: []const u8,
    ) GroupSessionError!void {
        self._state.relay.requireAuth(challenge) catch |err| return switch (err) {
            error.NotConnected => error.RelayDisconnected,
            error.ChallengeEmpty => error.ChallengeEmpty,
            error.ChallengeTooLong => error.ChallengeTooLong,
        };
    }

    pub fn acceptCurrentRelayAuthEventJson(
        self: *GroupSession,
        auth_event_json: []const u8,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) GroupSessionError!void {
        const auth_event = try noztr.nip01_event.event_parse_json(auth_event_json, scratch);
        try self._state.relay.acceptAuthEvent(&auth_event, now_unix_seconds, window_seconds);
    }

    pub fn resetState(self: *GroupSession) void {
        self._state.group_state.reset();
        self._state.recent_ref_count = 0;
        self._state.recent_ref_head = 0;
    }

    pub fn groupState(self: *const GroupSession) *const noztr.nip29_relay_groups.GroupState {
        return &self._state.group_state;
    }

    pub fn view(self: *const GroupSession) GroupSessionView {
        const group_state = self.groupState();
        return .{
            .reference = self.groupReference(),
            .relay_url = self.currentRelayUrl(),
            .relay_ready = self.currentRelayCanReceive(),
            .metadata = group_state.metadata,
            .users = group_state.users,
            .supported_roles = group_state.supported_roles,
        };
    }

    pub fn applySnapshotEvents(
        self: *GroupSession,
        events: []const *const noztr.nip01_event.Event,
    ) GroupSessionError!void {
        self.resetState();
        self.applyReplayEvents(events) catch |err| {
            self.resetState();
            return err;
        };
    }

    pub fn applySnapshotEventJsons(
        self: *GroupSession,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!void {
        self.resetState();
        self.applyReplayEventJsons(event_jsons, scratch) catch |err| {
            self.resetState();
            return err;
        };
    }

    pub fn applyIncrementalStateEventJson(
        self: *GroupSession,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupStateEventKind {
        return self.applyReplayEventJson(event_json, scratch);
    }

    pub fn applyIncrementalStateEvent(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
    ) GroupSessionError!GroupStateEventKind {
        return self.applyReplayEvent(event);
    }

    pub fn acceptJoinRequestEventJson(
        self: *GroupSession,
        event_json: []const u8,
        previous_storage: [][]const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupJoinRequestInfo {
        try self.requireRelayReady();
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.acceptJoinRequestEvent(&event, previous_storage);
    }

    pub fn acceptJoinRequestEvent(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
        previous_storage: [][]const u8,
    ) GroupSessionError!GroupJoinRequestInfo {
        try self.requireRelayReady();
        try noztr.nip01_event.event_verify(event);
        const info = try noztr.nip29_relay_groups.group_join_request_extract(event, previous_storage);
        try self.requirePinnedGroup(info.group_id);
        try self.requireKnownPreviousRefs(info.previous_refs);
        self.rememberObservedEvent(event);
        return info;
    }

    pub fn acceptLeaveRequestEventJson(
        self: *GroupSession,
        event_json: []const u8,
        previous_storage: [][]const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupLeaveRequestInfo {
        try self.requireRelayReady();
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.acceptLeaveRequestEvent(&event, previous_storage);
    }

    pub fn acceptLeaveRequestEvent(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
        previous_storage: [][]const u8,
    ) GroupSessionError!GroupLeaveRequestInfo {
        try self.requireRelayReady();
        try noztr.nip01_event.event_verify(event);
        const info = try noztr.nip29_relay_groups.group_leave_request_extract(event, previous_storage);
        try self.requirePinnedGroup(info.group_id);
        try self.requireKnownPreviousRefs(info.previous_refs);
        self.rememberObservedEvent(event);
        return info;
    }

    pub fn observeGroupEventJson(
        self: *GroupSession,
        event_json: []const u8,
        previous_storage: [][]const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupObservedEventKind {
        try self.requireRelayReady();
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.observeGroupEvent(&event, previous_storage);
    }

    pub fn observeGroupEvent(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
        previous_storage: [][]const u8,
    ) GroupSessionError!GroupObservedEventKind {
        return switch (event.kind) {
            noztr.nip29_relay_groups.group_metadata_kind,
            noztr.nip29_relay_groups.group_admins_kind,
            noztr.nip29_relay_groups.group_members_kind,
            noztr.nip29_relay_groups.group_roles_kind,
            noztr.nip29_relay_groups.group_put_user_kind,
            noztr.nip29_relay_groups.group_remove_user_kind,
            => mapObservedStateKind(try self.applyIncrementalStateEvent(event)),
            noztr.nip29_relay_groups.group_join_request_kind => blk: {
                _ = try self.acceptJoinRequestEvent(event, previous_storage);
                break :blk .join_request;
            },
            noztr.nip29_relay_groups.group_leave_request_kind => blk: {
                _ = try self.acceptLeaveRequestEvent(event, previous_storage);
                break :blk .leave_request;
            },
            else => blk: {
                try self.observeGenericGroupEvent(event, previous_storage);
                break :blk .generic;
            },
        };
    }

    pub fn selectPreviousRefs(
        self: *const GroupSession,
        author_pubkey: ?*const [32]u8,
        output: [][]const u8,
    ) []const []const u8 {
        var count: usize = 0;
        var reverse_index: u8 = 0;
        while (reverse_index < self._state.recent_ref_count and count < output.len) : (reverse_index += 1) {
            const entry = self.historyEntryFromNewest(reverse_index);
            if (author_pubkey) |value| {
                if (std.mem.eql(u8, &entry.pubkey, value)) continue;
            }
            output[count] = entry.previous_ref[0..];
            count += 1;
        }
        return output[0..count];
    }

    pub fn beginJoinRequest(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupJoinRequestDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        try self.requireKnownPreviousRefs(request.previous_refs);

        var tags: [noztr.limits.tags_max + 2]noztr.nip01_event.EventTag = undefined;
        var previous_items: [noztr.limits.tags_max][2][]const u8 = undefined;
        var group_items: [2][]const u8 = undefined;
        var code_items: [2][]const u8 = undefined;
        const tag_count = try buildJoinLeaveTags(
            self.groupReference().id,
            request.invite_code,
            request.previous_refs,
            tags[0..],
            previous_items[0..],
            &group_items,
            &code_items,
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_join_request_kind,
            request.reason orelse "",
            tags[0..tag_count],
        );
    }

    pub fn beginMetadataSnapshot(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupMetadataDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        return self.buildMetadataSnapshotEvent(context, request);
    }

    pub fn beginAdminsSnapshot(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupAdminsDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        return self.buildAdminsSnapshotEvent(context, request.admins);
    }

    pub fn beginMembersSnapshot(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupMembersDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        return self.buildMembersSnapshotEvent(context, request.members);
    }

    pub fn beginRolesSnapshot(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupRolesDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        return self.buildRolesSnapshotEvent(context, request.roles);
    }

    pub fn beginLeaveRequest(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupLeaveRequestDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        try self.requireKnownPreviousRefs(request.previous_refs);

        var tags: [noztr.limits.tags_max + 1]noztr.nip01_event.EventTag = undefined;
        var previous_items: [noztr.limits.tags_max][2][]const u8 = undefined;
        var group_items: [2][]const u8 = undefined;
        const tag_count = try buildGroupAndPreviousTags(
            self.groupReference().id,
            request.previous_refs,
            tags[0..],
            previous_items[0..],
            &group_items,
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_leave_request_kind,
            request.reason orelse "",
            tags[0..tag_count],
        );
    }

    pub fn beginPutUser(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupPutUserDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        try self.requireKnownPreviousRefs(request.previous_refs);

        var tags: [noztr.limits.tags_max + 2]noztr.nip01_event.EventTag = undefined;
        var previous_items: [noztr.limits.tags_max][2][]const u8 = undefined;
        var group_items: [2][]const u8 = undefined;
        var user_items: [noztr.limits.tag_items_max][]const u8 = undefined;
        const tag_count = try buildModerationTags(
            self.groupReference().id,
            request.pubkey,
            request.roles,
            request.previous_refs,
            tags[0..],
            previous_items[0..],
            &group_items,
            &user_items,
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_put_user_kind,
            request.reason orelse "",
            tags[0..tag_count],
        );
    }

    pub fn beginRemoveUser(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupRemoveUserDraft,
    ) GroupSessionError!OutboundEvent {
        try self.requireRelayReady();
        try self.requireKnownPreviousRefs(request.previous_refs);

        var tags: [noztr.limits.tags_max + 2]noztr.nip01_event.EventTag = undefined;
        var previous_items: [noztr.limits.tags_max][2][]const u8 = undefined;
        var group_items: [2][]const u8 = undefined;
        var user_items: [noztr.limits.tag_items_max][]const u8 = undefined;
        const tag_count = try buildModerationTags(
            self.groupReference().id,
            request.pubkey,
            &.{},
            request.previous_refs,
            tags[0..],
            previous_items[0..],
            &group_items,
            &user_items,
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_remove_user_kind,
            request.reason orelse "",
            tags[0..tag_count],
        );
    }

    pub fn acceptCanonicalStateEventJson(
        self: *GroupSession,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupStateEventKind {
        return self.applyIncrementalStateEventJson(event_json, scratch);
    }

    pub fn exportCheckpoint(
        self: *const GroupSession,
        context: CheckpointContext,
    ) GroupSessionError!Checkpoint {
        const metadata = self.groupState().metadata;
        var admins_storage: [noztr.limits.tags_max]GroupAdmin = undefined;
        var members_storage: [noztr.limits.tags_max]GroupMember = undefined;
        const admins = self.collectCurrentAdmins(admins_storage[0..]);
        const members = self.collectCurrentMembers(members_storage[0..]);

        const metadata_event = try self.buildMetadataSnapshotEvent(
            context.metadataContext(),
            &.{
                .name = metadata.name,
                .picture = metadata.picture,
                .about = metadata.about,
                .is_private = metadata.is_private,
                .is_restricted = metadata.is_restricted,
                .is_hidden = metadata.is_hidden,
                .is_closed = metadata.is_closed,
            },
        );
        const admins_event = try self.buildAdminsSnapshotEvent(
            context.adminsContext(),
            admins,
        );
        const members_event = try self.buildMembersSnapshotEvent(
            context.membersContext(),
            members,
        );
        const roles_event = try self.buildRolesSnapshotEvent(
            context.rolesContext(),
            self.groupState().supported_roles,
        );
        return .{
            .relay_url = self.currentRelayUrl(),
            .metadata_event_json = metadata_event.event_json,
            .admins_event_json = admins_event.event_json,
            .members_event_json = members_event.event_json,
            .roles_event_json = roles_event.event_json,
        };
    }

    pub fn restoreCheckpointEventJsons(
        self: *GroupSession,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!void {
        self.resetState();
        self.applyReplayEventJsonsUnchecked(event_jsons, scratch) catch |err| {
            self.resetState();
            return err;
        };
    }

    fn applyReplayEventJson(
        self: *GroupSession,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupStateEventKind {
        try self.requireRelayReady();
        return self.applyReplayEventJsonUnchecked(event_json, scratch);
    }

    fn applyReplayEvents(
        self: *GroupSession,
        events: []const *const noztr.nip01_event.Event,
    ) GroupSessionError!void {
        for (events) |event| {
            _ = try self.applyReplayEvent(event);
        }
    }

    fn applyReplayEventJsons(
        self: *GroupSession,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!void {
        for (event_jsons) |event_json| {
            _ = try self.applyReplayEventJson(event_json, scratch);
        }
    }

    fn applyReplayEvent(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
    ) GroupSessionError!GroupStateEventKind {
        try self.requireRelayReady();
        return self.applyReplayEventUnchecked(event);
    }

    fn applyReplayEventJsonUnchecked(
        self: *GroupSession,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!GroupStateEventKind {
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.applyReplayEventUnchecked(&event);
    }

    fn applyReplayEventJsonsUnchecked(
        self: *GroupSession,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupSessionError!void {
        for (event_jsons) |event_json| {
            _ = try self.applyReplayEventJsonUnchecked(event_json, scratch);
        }
    }

    fn applyReplayEventUnchecked(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
    ) GroupSessionError!GroupStateEventKind {
        const event_kind = try classifyStateEventKind(event.kind);
        try noztr.nip01_event.event_verify(event);
        const event_group_id = try extractStateEventGroupId(event);
        try self.requirePinnedGroup(event_group_id);
        try self.validateStateEventPreviousRefs(event);
        try noztr.nip29_relay_groups.group_state_apply_event(&self._state.group_state, event);
        self.rememberObservedEvent(event);
        return event_kind;
    }

    fn buildMetadataSnapshotEvent(
        self: *const GroupSession,
        context: PublishContext,
        request: *const GroupMetadataDraft,
    ) GroupSessionError!OutboundEvent {
        var tags: [8]noztr.nip01_event.EventTag = undefined;
        var built_tags: [8]noztr.nip29_relay_groups.BuiltTag = undefined;
        const tag_count = try buildMetadataSnapshotTags(
            self.groupReference().id,
            request,
            tags[0..],
            built_tags[0..],
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_metadata_kind,
            "",
            tags[0..tag_count],
        );
    }

    fn buildAdminsSnapshotEvent(
        self: *const GroupSession,
        context: PublishContext,
        admins: []const GroupAdmin,
    ) GroupSessionError!OutboundEvent {
        var tags: [noztr.limits.tags_max]noztr.nip01_event.EventTag = undefined;
        var built_tags: [noztr.limits.tags_max]noztr.nip29_relay_groups.BuiltTag = undefined;
        var pubkey_hexes: [noztr.limits.tags_max][noztr.limits.pubkey_hex_length]u8 = undefined;
        const tag_count = try buildAdminsSnapshotTags(
            self.groupReference().id,
            admins,
            tags[0..],
            built_tags[0..],
            pubkey_hexes[0..],
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_admins_kind,
            "",
            tags[0..tag_count],
        );
    }

    fn buildMembersSnapshotEvent(
        self: *const GroupSession,
        context: PublishContext,
        members: []const GroupMember,
    ) GroupSessionError!OutboundEvent {
        var tags: [noztr.limits.tags_max]noztr.nip01_event.EventTag = undefined;
        var built_tags: [noztr.limits.tags_max]noztr.nip29_relay_groups.BuiltTag = undefined;
        var pubkey_hexes: [noztr.limits.tags_max][noztr.limits.pubkey_hex_length]u8 = undefined;
        const tag_count = try buildMembersSnapshotTags(
            self.groupReference().id,
            members,
            tags[0..],
            built_tags[0..],
            pubkey_hexes[0..],
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_members_kind,
            "",
            tags[0..tag_count],
        );
    }

    fn buildRolesSnapshotEvent(
        self: *const GroupSession,
        context: PublishContext,
        roles: []const GroupRole,
    ) GroupSessionError!OutboundEvent {
        var tags: [noztr.limits.tags_max]noztr.nip01_event.EventTag = undefined;
        var built_tags: [noztr.limits.tags_max]noztr.nip29_relay_groups.BuiltTag = undefined;
        const tag_count = try buildRolesSnapshotTags(
            self.groupReference().id,
            roles,
            tags[0..],
            built_tags[0..],
        );
        return self.buildOutboundEvent(
            context,
            noztr.nip29_relay_groups.group_roles_kind,
            "",
            tags[0..tag_count],
        );
    }

    fn collectCurrentAdmins(
        self: *const GroupSession,
        output: []GroupAdmin,
    ) []const GroupAdmin {
        var count: usize = 0;
        for (self.groupState().users) |user| {
            if (user.roles.len == 0) continue;
            output[count] = .{
                .pubkey = user.pubkey,
                .label = user.label,
                .roles = user.roles,
            };
            count += 1;
        }
        return output[0..count];
    }

    fn collectCurrentMembers(
        self: *const GroupSession,
        output: []GroupMember,
    ) []const GroupMember {
        var count: usize = 0;
        for (self.groupState().users) |user| {
            if (!user.is_member) continue;
            output[count] = .{
                .pubkey = user.pubkey,
                .label = user.label,
            };
            count += 1;
        }
        return output[0..count];
    }

    fn storeReference(
        self: *GroupSession,
        reference: noztr.nip29_relay_groups.GroupReference,
    ) void {
        std.debug.assert(reference.host.len <= self._state.reference_host.len);
        std.debug.assert(reference.id.len <= self._state.group_id.len);

        @memcpy(self._state.reference_host[0..reference.host.len], reference.host);
        self._state.reference_host_len = @intCast(reference.host.len);
        @memcpy(self._state.group_id[0..reference.id.len], reference.id);
        self._state.group_id_len = @intCast(reference.id.len);
    }

    fn requireRelayReady(self: *const GroupSession) GroupSessionError!void {
        if (self._state.relay.canSendRequests()) return;
        return switch (self._state.relay.state) {
            .disconnected => error.RelayDisconnected,
            .auth_required => error.RelayAuthRequired,
            .connected => unreachable,
        };
    }

    fn requirePinnedGroup(self: *const GroupSession, group_id: []const u8) GroupSessionError!void {
        if (std.mem.eql(u8, group_id, self.groupReference().id)) return;
        return error.EventGroupMismatch;
    }

    fn validateStateEventPreviousRefs(
        self: *const GroupSession,
        event: *const noztr.nip01_event.Event,
    ) GroupSessionError!void {
        switch (event.kind) {
            noztr.nip29_relay_groups.group_put_user_kind => {
                var roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
                var previous: [noztr.limits.tags_max][]const u8 = undefined;
                const info = try noztr.nip29_relay_groups.group_put_user_extract(
                    event,
                    roles[0..],
                    previous[0..],
                );
                try self.requireKnownPreviousRefs(info.previous_refs);
            },
            noztr.nip29_relay_groups.group_remove_user_kind => {
                var previous: [noztr.limits.tags_max][]const u8 = undefined;
                const info = try noztr.nip29_relay_groups.group_remove_user_extract(
                    event,
                    previous[0..],
                );
                try self.requireKnownPreviousRefs(info.previous_refs);
            },
            else => {},
        }
    }

    fn observeGenericGroupEvent(
        self: *GroupSession,
        event: *const noztr.nip01_event.Event,
        previous_storage: [][]const u8,
    ) GroupSessionError!void {
        try self.requireRelayReady();
        try noztr.nip01_event.event_verify(event);
        const group_id = try extractGroupTagGroupId(event.tags);
        try self.requirePinnedGroup(group_id);
        const previous_refs = try collectPreviousRefsFromTags(event.tags, previous_storage);
        try self.requireKnownPreviousRefs(previous_refs);
        self.rememberObservedEvent(event);
    }

    fn buildOutboundEvent(
        self: *const GroupSession,
        context: PublishContext,
        kind: u32,
        content: []const u8,
        tags: []const noztr.nip01_event.EventTag,
    ) GroupSessionError!OutboundEvent {
        const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&context.author_secret_key);
        var event = noztr.nip01_event.Event{
            .id = [_]u8{0} ** 32,
            .pubkey = author_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = kind,
            .created_at = context.created_at,
            .content = content,
            .tags = tags,
        };
        try noztr.nostr_keys.nostr_sign_event(&context.author_secret_key, &event);
        const event_json = try noztr.nip01_event.event_serialize_json_object(
            context.writable(),
            &event,
        );
        return .{
            .relay_url = self.currentRelayUrl(),
            .event_id = event.id,
            .event_json = event_json,
        };
    }

    fn requireKnownPreviousRefs(
        self: *const GroupSession,
        previous_refs: []const []const u8,
    ) GroupSessionError!void {
        for (previous_refs) |previous_ref| {
            if (self.hasPreviousRef(previous_ref)) continue;
            return error.UnknownPreviousReference;
        }
    }

    fn hasPreviousRef(self: *const GroupSession, previous_ref: []const u8) bool {
        std.debug.assert(previous_ref.len == previous_ref_text_bytes);

        var index: u8 = 0;
        while (index < self._state.recent_ref_count) : (index += 1) {
            const entry = self.historyEntryFromNewest(index);
            if (std.mem.eql(u8, entry.previous_ref[0..], previous_ref)) return true;
        }
        return false;
    }

    fn rememberObservedEvent(self: *GroupSession, event: *const noztr.nip01_event.Event) void {
        std.debug.assert(self._state.recent_ref_count <= previous_refs_history_capacity);

        const event_id_hex = std.fmt.bytesToHex(event.id, .lower);
        const slot_index = self._state.recent_ref_head;
        @memcpy(
            self._state.recent_refs[slot_index].previous_ref[0..previous_ref_text_bytes],
            event_id_hex[0..previous_ref_text_bytes],
        );
        self._state.recent_refs[slot_index].pubkey = event.pubkey;
        self._state.recent_ref_head = incrementHistoryIndex(slot_index);
        if (self._state.recent_ref_count < previous_refs_history_capacity) {
            self._state.recent_ref_count += 1;
        }
    }

    fn historyEntryFromNewest(self: *const GroupSession, reverse_index: u8) *const State.RecentEventRef {
        std.debug.assert(reverse_index < self._state.recent_ref_count);

        var index = self._state.recent_ref_head;
        var remaining: u8 = 0;
        while (remaining <= reverse_index) : (remaining += 1) {
            index = decrementHistoryIndex(index);
        }
        return &self._state.recent_refs[index];
    }
};

fn mapObservedStateKind(kind: GroupStateEventKind) GroupObservedEventKind {
    return switch (kind) {
        .metadata => .metadata,
        .admins => .admins,
        .members => .members,
        .roles => .roles,
        .put_user => .put_user,
        .remove_user => .remove_user,
    };
}

fn incrementHistoryIndex(index: u8) u8 {
    std.debug.assert(index < previous_refs_history_capacity);
    return if (index + 1 == previous_refs_history_capacity) 0 else index + 1;
}

fn decrementHistoryIndex(index: u8) u8 {
    std.debug.assert(index < previous_refs_history_capacity);
    return if (index == 0) previous_refs_history_capacity - 1 else index - 1;
}

fn classifyStateEventKind(kind: u32) GroupSessionError!GroupStateEventKind {
    return switch (kind) {
        noztr.nip29_relay_groups.group_metadata_kind => .metadata,
        noztr.nip29_relay_groups.group_admins_kind => .admins,
        noztr.nip29_relay_groups.group_members_kind => .members,
        noztr.nip29_relay_groups.group_roles_kind => .roles,
        noztr.nip29_relay_groups.group_put_user_kind => .put_user,
        noztr.nip29_relay_groups.group_remove_user_kind => .remove_user,
        else => error.UnsupportedGroupEventKind,
    };
}

fn extractStateEventGroupId(
    event: *const noztr.nip01_event.Event,
) GroupSessionError![]const u8 {
    switch (event.kind) {
        noztr.nip29_relay_groups.group_metadata_kind,
        noztr.nip29_relay_groups.group_admins_kind,
        noztr.nip29_relay_groups.group_members_kind,
        noztr.nip29_relay_groups.group_roles_kind,
        => return extractIdentifierTagGroupId(event.tags),
        noztr.nip29_relay_groups.group_put_user_kind => {
            return extractGroupTagGroupId(event.tags);
        },
        noztr.nip29_relay_groups.group_remove_user_kind => {
            return extractGroupTagGroupId(event.tags);
        },
        else => return error.UnsupportedGroupEventKind,
    }
}

fn extractIdentifierTagGroupId(tags: []const noztr.nip01_event.EventTag) GroupSessionError![]const u8 {
    var group_id: ?[]const u8 = null;
    for (tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "d")) continue;
        if (group_id != null) return error.DuplicateIdentifierTag;
        if (tag.items.len != 2) return error.InvalidIdentifierTag;
        var built_tag: noztr.nip29_relay_groups.BuiltTag = .{};
        _ = try noztr.nip29_relay_groups.group_build_identifier_tag(&built_tag, tag.items[1]);
        group_id = tag.items[1];
    }
    return group_id orelse error.MissingIdentifierTag;
}

fn extractGroupTagGroupId(tags: []const noztr.nip01_event.EventTag) GroupSessionError![]const u8 {
    var group_id: ?[]const u8 = null;
    for (tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "h")) continue;
        if (group_id != null) return error.DuplicateGroupTag;
        if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidGroupTag;
        var built_tag: noztr.nip29_relay_groups.BuiltTag = .{};
        _ = try noztr.nip29_relay_groups.group_build_group_tag(&built_tag, tag.items[1]);
        if (tag.items.len == 3) {
            const parsed = std.Uri.parse(tag.items[2]) catch return error.InvalidGroupTag;
            if (parsed.scheme.len == 0 or parsed.host == null) return error.InvalidGroupTag;
        }
        group_id = tag.items[1];
    }
    return group_id orelse error.MissingGroupTag;
}

fn collectPreviousRefsFromTags(
    tags: []const noztr.nip01_event.EventTag,
    out_previous: [][]const u8,
) GroupSessionError![]const []const u8 {
    var count: usize = 0;
    for (tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "previous")) continue;
        if (count == out_previous.len) return error.BufferTooSmall;
        if (tag.items.len != 2) return error.InvalidPreviousTag;
        var built_tag: noztr.nip29_relay_groups.BuiltTag = .{};
        _ = try noztr.nip29_relay_groups.group_build_previous_tag(&built_tag, tag.items[1]);
        out_previous[count] = tag.items[1];
        count += 1;
    }
    return out_previous[0..count];
}

fn ensureRelayMatchesReferenceHost(
    reference_host: []const u8,
    relay_url: []const u8,
) GroupSessionError!void {
    const parsed = std.Uri.parse(relay_url) catch return error.GroupRelayHostMismatch;
    var host_storage: [std.Uri.host_name_max]u8 = undefined;
    const relay_host = parsed.getHost(host_storage[0..]) catch {
        return error.GroupRelayHostMismatch;
    };

    var normalized_authority_storage: [std.Uri.host_name_max + 8]u8 = undefined;
    const normalized_authority = try composeRelayAuthority(
        normalized_authority_storage[0..],
        relay_host,
        parsed.scheme,
        parsed.port,
        false,
    );
    var explicit_authority_storage: [std.Uri.host_name_max + 8]u8 = undefined;
    const explicit_authority = try composeRelayAuthority(
        explicit_authority_storage[0..],
        relay_host,
        parsed.scheme,
        parsed.port,
        true,
    );
    if (std.ascii.eqlIgnoreCase(reference_host, relay_host)) return;
    if (std.ascii.eqlIgnoreCase(reference_host, normalized_authority)) return;
    if (std.ascii.eqlIgnoreCase(reference_host, explicit_authority)) return;
    return error.GroupRelayHostMismatch;
}

fn composeRelayAuthority(
    output: []u8,
    relay_host: []const u8,
    scheme: []const u8,
    port: ?u16,
    include_default_port: bool,
) error{BufferTooSmall}![]const u8 {
    const resolved_port = if (port) |value| value else if (std.ascii.eqlIgnoreCase(scheme, "ws"))
        @as(u16, 80)
    else if (std.ascii.eqlIgnoreCase(scheme, "wss"))
        @as(u16, 443)
    else
        null;
    if (resolved_port) |value| {
        const is_default_ws = std.ascii.eqlIgnoreCase(scheme, "ws") and value == 80;
        const is_default_wss = std.ascii.eqlIgnoreCase(scheme, "wss") and value == 443;
        if (include_default_port or (!is_default_ws and !is_default_wss)) {
            return std.fmt.bufPrint(output, "{s}:{d}", .{ relay_host, value }) catch {
                return error.BufferTooSmall;
            };
        }
    }
    if (relay_host.len > output.len) return error.BufferTooSmall;
    @memcpy(output[0..relay_host.len], relay_host);
    return output[0..relay_host.len];
}

fn buildJoinLeaveTags(
    group_id: []const u8,
    invite_code: ?[]const u8,
    previous_refs: []const []const u8,
    tags_out: []noztr.nip01_event.EventTag,
    previous_items_out: [][2][]const u8,
    group_items_out: *[2][]const u8,
    code_items_out: *[2][]const u8,
) GroupSessionError!usize {
    var count = try buildGroupAndPreviousTags(
        group_id,
        previous_refs,
        tags_out,
        previous_items_out,
        group_items_out,
    );
    if (invite_code) |code| {
        if (count == tags_out.len) return error.BufferTooSmall;
        try validateCodeTag(code);
        code_items_out.* = .{ "code", code };
        tags_out[count] = .{ .items = code_items_out[0..2] };
        count += 1;
    }
    return count;
}

fn buildMetadataSnapshotTags(
    group_id: []const u8,
    request: *const GroupMetadataDraft,
    tags_out: []noztr.nip01_event.EventTag,
    built_tags: []noztr.nip29_relay_groups.BuiltTag,
) GroupSessionError!usize {
    std.debug.assert(tags_out.len >= 8);
    std.debug.assert(built_tags.len >= 8);

    var count: usize = 0;
    tags_out[count] = try noztr.nip29_relay_groups.group_build_identifier_tag(
        &built_tags[count],
        group_id,
    );
    count += 1;
    if (request.name) |name| {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_name_tag(&built_tags[count], name);
        count += 1;
    }
    if (request.picture) |picture| {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_picture_tag(
            &built_tags[count],
            picture,
        );
        count += 1;
    }
    if (request.about) |about| {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_about_tag(&built_tags[count], about);
        count += 1;
    }
    if (request.is_private) {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_flag_tag(
            &built_tags[count],
            .private,
        );
        count += 1;
    }
    if (request.is_restricted) {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_flag_tag(
            &built_tags[count],
            .restricted,
        );
        count += 1;
    }
    if (request.is_hidden) {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_flag_tag(
            &built_tags[count],
            .hidden,
        );
        count += 1;
    }
    if (request.is_closed) {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_flag_tag(
            &built_tags[count],
            .closed,
        );
        count += 1;
    }
    return count;
}

fn buildAdminsSnapshotTags(
    group_id: []const u8,
    admins: []const GroupAdmin,
    tags_out: []noztr.nip01_event.EventTag,
    built_tags: []noztr.nip29_relay_groups.BuiltTag,
    pubkey_hexes: [][noztr.limits.pubkey_hex_length]u8,
) GroupSessionError!usize {
    if (admins.len + 1 > tags_out.len) return error.BufferTooSmall;
    if (admins.len + 1 > built_tags.len) return error.BufferTooSmall;
    if (admins.len > pubkey_hexes.len) return error.BufferTooSmall;

    var count: usize = 0;
    tags_out[count] = try noztr.nip29_relay_groups.group_build_identifier_tag(
        &built_tags[count],
        group_id,
    );
    count += 1;
    for (admins, 0..) |admin, index| {
        const pubkey_hex = std.fmt.bytesToHex(admin.pubkey, .lower);
        @memcpy(pubkey_hexes[index][0..], pubkey_hex[0..]);
        tags_out[count] = try noztr.nip29_relay_groups.group_build_admin_tag(
            &built_tags[count],
            pubkey_hexes[index][0..],
            admin.label,
            admin.roles,
        );
        count += 1;
    }
    return count;
}

fn buildMembersSnapshotTags(
    group_id: []const u8,
    members: []const GroupMember,
    tags_out: []noztr.nip01_event.EventTag,
    built_tags: []noztr.nip29_relay_groups.BuiltTag,
    pubkey_hexes: [][noztr.limits.pubkey_hex_length]u8,
) GroupSessionError!usize {
    if (members.len + 1 > tags_out.len) return error.BufferTooSmall;
    if (members.len + 1 > built_tags.len) return error.BufferTooSmall;
    if (members.len > pubkey_hexes.len) return error.BufferTooSmall;

    var count: usize = 0;
    tags_out[count] = try noztr.nip29_relay_groups.group_build_identifier_tag(
        &built_tags[count],
        group_id,
    );
    count += 1;
    for (members, 0..) |member, index| {
        const pubkey_hex = std.fmt.bytesToHex(member.pubkey, .lower);
        @memcpy(pubkey_hexes[index][0..], pubkey_hex[0..]);
        tags_out[count] = try noztr.nip29_relay_groups.group_build_member_tag(
            &built_tags[count],
            pubkey_hexes[index][0..],
            member.label,
        );
        count += 1;
    }
    return count;
}

fn buildRolesSnapshotTags(
    group_id: []const u8,
    roles: []const GroupRole,
    tags_out: []noztr.nip01_event.EventTag,
    built_tags: []noztr.nip29_relay_groups.BuiltTag,
) GroupSessionError!usize {
    if (roles.len + 1 > tags_out.len) return error.BufferTooSmall;
    if (roles.len + 1 > built_tags.len) return error.BufferTooSmall;

    var count: usize = 0;
    tags_out[count] = try noztr.nip29_relay_groups.group_build_identifier_tag(
        &built_tags[count],
        group_id,
    );
    count += 1;
    for (roles) |role| {
        tags_out[count] = try noztr.nip29_relay_groups.group_build_role_tag(
            &built_tags[count],
            role.name,
            role.description,
        );
        count += 1;
    }
    return count;
}

fn buildGroupAndPreviousTags(
    group_id: []const u8,
    previous_refs: []const []const u8,
    tags_out: []noztr.nip01_event.EventTag,
    previous_items_out: [][2][]const u8,
    group_items_out: *[2][]const u8,
) GroupSessionError!usize {
    if (previous_refs.len > previous_items_out.len) return error.BufferTooSmall;
    if (previous_refs.len + 1 > tags_out.len) return error.BufferTooSmall;

    try validateGroupTag(group_id);
    group_items_out.* = .{ "h", group_id };
    tags_out[0] = .{ .items = group_items_out[0..2] };
    var count: usize = 1;
    for (previous_refs, 0..) |previous_ref, index| {
        try validatePreviousTag(previous_ref);
        previous_items_out[index] = .{ "previous", previous_ref };
        tags_out[count] = .{ .items = previous_items_out[index][0..2] };
        count += 1;
    }
    return count;
}

fn buildModerationTags(
    group_id: []const u8,
    target_pubkey: [32]u8,
    roles: []const []const u8,
    previous_refs: []const []const u8,
    tags_out: []noztr.nip01_event.EventTag,
    previous_items_out: [][2][]const u8,
    group_items_out: *[2][]const u8,
    user_items_out: *[noztr.limits.tag_items_max][]const u8,
) GroupSessionError!usize {
    if (previous_refs.len > previous_items_out.len) return error.BufferTooSmall;
    if (previous_refs.len + 2 > tags_out.len) return error.BufferTooSmall;

    const target_pubkey_hex = std.fmt.bytesToHex(target_pubkey, .lower);
    try validateGroupTag(group_id);
    try validateUserTag(target_pubkey_hex[0..], roles);

    group_items_out.* = .{ "h", group_id };
    tags_out[0] = .{ .items = group_items_out[0..2] };
    user_items_out[0] = "p";
    user_items_out[1] = target_pubkey_hex[0..];
    for (roles, 0..) |role, index| {
        user_items_out[index + 2] = role;
    }
    tags_out[1] = .{ .items = user_items_out[0 .. roles.len + 2] };

    var count: usize = 2;
    for (previous_refs, 0..) |previous_ref, index| {
        try validatePreviousTag(previous_ref);
        previous_items_out[index] = .{ "previous", previous_ref };
        tags_out[count] = .{ .items = previous_items_out[index][0..2] };
        count += 1;
    }
    return count;
}

fn validateGroupTag(group_id: []const u8) GroupSessionError!void {
    var built: noztr.nip29_relay_groups.BuiltTag = .{};
    _ = try noztr.nip29_relay_groups.group_build_group_tag(&built, group_id);
}

fn validateCodeTag(code: []const u8) GroupSessionError!void {
    var built: noztr.nip29_relay_groups.BuiltTag = .{};
    _ = try noztr.nip29_relay_groups.group_build_code_tag(&built, code);
}

fn validatePreviousTag(previous_ref: []const u8) GroupSessionError!void {
    var built: noztr.nip29_relay_groups.BuiltTag = .{};
    _ = try noztr.nip29_relay_groups.group_build_previous_tag(&built, previous_ref);
}

fn validateUserTag(pubkey_hex: []const u8, roles: []const []const u8) GroupSessionError!void {
    var built: noztr.nip29_relay_groups.BuiltTag = .{};
    _ = try noztr.nip29_relay_groups.group_build_user_tag(&built, pubkey_hex, roles);
}

test "group session applies one typed snapshot into reduced group state" {
    var users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    var admin_event: TestEventFixture = undefined;
    var member_event: TestEventFixture = undefined;
    var put_user_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    try buildAdminEvent(&admin_event, "pizza-lovers");
    try buildMemberEvent(&member_event, "pizza-lovers");
    try buildPutUserEvent(&put_user_event, "pizza-lovers");
    const snapshot = [_]*const noztr.nip01_event.Event{
        &metadata_event.event,
        &admin_event.event,
        &member_event.event,
        &put_user_event.event,
    };

    try session.applySnapshotEvents(snapshot[0..]);
    try std.testing.expectEqualStrings("pizza-lovers", session.groupState().metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Lovers", session.groupState().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), session.groupState().users.len);
    try std.testing.expect(session.groupState().users[0].is_member);
    try std.testing.expectEqualStrings("vip", session.groupState().users[0].label.?);
    try std.testing.expectEqual(@as(usize, 1), session.groupState().users[0].roles.len);
    try std.testing.expectEqualStrings("moderator", session.groupState().users[0].roles[0]);
}

test "group session exposes named storage and a stable view surface" {
    var users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    const storage = GroupSessionStorage.init(users[0..], roles[0..], user_roles[0..]);
    const capacity = storage.capacity();
    try std.testing.expectEqual(@as(usize, 2), capacity.users);
    try std.testing.expectEqual(@as(usize, 1), capacity.supported_roles);

    var session = try GroupSession.init(.{
        .reference_text = test_group_reference,
        .relay_url = test_group_relay_url,
        .storage = storage,
    });
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);

    const view = session.view();
    try std.testing.expectEqualStrings("pizza-lovers", view.reference.id);
    try std.testing.expectEqualStrings("wss://relay.one", view.relay_url);
    try std.testing.expect(view.relay_ready);
    try std.testing.expectEqualStrings("Pizza Lovers", view.metadata.name.?);
}

test "group session builds signed join request json that intake paths accept" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);

    var selected_previous: [1][]const u8 = undefined;
    const previous_refs = session.selectPreviousRefs(null, selected_previous[0..]);
    var outbound_buffer = OutboundBuffer{};
    const author_secret = [_]u8{0x21} ** 32;
    const outbound = try session.beginJoinRequest(
        PublishContext.init(42, &author_secret, &outbound_buffer),
        &.{
            .invite_code = "invite-123",
            .reason = "please let me in",
            .previous_refs = previous_refs,
        },
    );
    try std.testing.expectEqualStrings("wss://relay.one", outbound.relay_url);

    var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer parse_arena.deinit();
    const parsed = try noztr.nip01_event.event_parse_json(outbound.event_json, parse_arena.allocator());
    try noztr.nip01_event.event_verify(&parsed);
    try std.testing.expectEqual(noztr.nip29_relay_groups.group_join_request_kind, parsed.kind);

    var previous_storage: [1][]const u8 = undefined;
    const info = try session.acceptJoinRequestEventJson(
        outbound.event_json,
        previous_storage[0..],
        parse_arena.allocator(),
    );
    try std.testing.expectEqualStrings("pizza-lovers", info.group_id);
    try std.testing.expectEqualStrings("invite-123", info.invite_code.?);
    try std.testing.expectEqualStrings("please let me in", info.reason.?);
}

test "group session builds authored state snapshot json that another session replays" {
    var sender_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var sender_roles: [2]noztr.nip29_relay_groups.GroupRole = undefined;
    var sender_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var receiver_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var receiver_roles: [2]noztr.nip29_relay_groups.GroupRole = undefined;
    var receiver_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var sender = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        sender_users[0..],
        sender_roles[0..],
        sender_user_roles[0..],
    );
    var receiver = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        receiver_users[0..],
        receiver_roles[0..],
        receiver_user_roles[0..],
    );
    sender.markCurrentRelayConnected();
    receiver.markCurrentRelayConnected();

    var metadata_buffer = OutboundBuffer{};
    var roles_buffer = OutboundBuffer{};
    var members_buffer = OutboundBuffer{};
    var admins_buffer = OutboundBuffer{};
    const author_secret = [_]u8{0x20} ** 32;
    const metadata = try sender.beginMetadataSnapshot(
        PublishContext.init(10, &author_secret, &metadata_buffer),
        &.{
            .name = "Pizza Lovers",
            .about = "Pizza only",
            .is_private = true,
        },
    );
    const roles = try sender.beginRolesSnapshot(
        PublishContext.init(11, &author_secret, &roles_buffer),
        &.{
            .roles = &.{
                .{
                    .name = "moderator",
                    .description = "Can moderate the room",
                },
            },
        },
    );
    const members = try sender.beginMembersSnapshot(
        PublishContext.init(12, &author_secret, &members_buffer),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "vip",
                },
            },
        },
    );
    const admins = try sender.beginAdminsSnapshot(
        PublishContext.init(13, &author_secret, &admins_buffer),
        &.{
            .admins = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "vip",
                    .roles = &.{"moderator"},
                },
            },
        },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const snapshot = [_][]const u8{
        metadata.event_json,
        roles.event_json,
        members.event_json,
        admins.event_json,
    };
    try receiver.applySnapshotEventJsons(snapshot[0..], arena.allocator());

    const view = receiver.view();
    try std.testing.expectEqualStrings("Pizza Lovers", view.metadata.name.?);
    try std.testing.expectEqualStrings("Pizza only", view.metadata.about.?);
    try std.testing.expect(view.metadata.is_private);
    try std.testing.expectEqualStrings("moderator", view.supported_roles[0].name);
    try std.testing.expectEqualStrings("vip", view.users[0].label.?);
    try std.testing.expectEqualStrings("moderator", view.users[0].roles[0]);
}

test "group session builds signed leave request json that intake paths accept" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);

    var selected_previous: [1][]const u8 = undefined;
    const previous_refs = session.selectPreviousRefs(null, selected_previous[0..]);
    var outbound_buffer = OutboundBuffer{};
    const author_secret = [_]u8{0x22} ** 32;
    const outbound = try session.beginLeaveRequest(
        PublishContext.init(43, &author_secret, &outbound_buffer),
        &.{
            .reason = "goodbye",
            .previous_refs = previous_refs,
        },
    );

    var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer parse_arena.deinit();
    const parsed = try noztr.nip01_event.event_parse_json(outbound.event_json, parse_arena.allocator());
    try noztr.nip01_event.event_verify(&parsed);
    try std.testing.expectEqual(noztr.nip29_relay_groups.group_leave_request_kind, parsed.kind);

    var previous_storage: [1][]const u8 = undefined;
    const info = try session.acceptLeaveRequestEventJson(
        outbound.event_json,
        previous_storage[0..],
        parse_arena.allocator(),
    );
    try std.testing.expectEqualStrings("pizza-lovers", info.group_id);
    try std.testing.expectEqualStrings("goodbye", info.reason.?);
}

test "group session builds put-user moderation json that another session replays" {
    var sender_users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var sender_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var sender_user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var receiver_users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var receiver_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var receiver_user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var sender = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        sender_users[0..],
        sender_roles[0..],
        sender_user_roles[0..],
    );
    var receiver = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        receiver_users[0..],
        receiver_roles[0..],
        receiver_user_roles[0..],
    );
    sender.markCurrentRelayConnected();
    receiver.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    var role_event: TestEventFixture = undefined;
    var member_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    try buildRoleEvent(&role_event, "pizza-lovers", "moderator", "Can moderate the room");
    try buildMemberEvent(&member_event, "pizza-lovers");
    const snapshot = [_]*const noztr.nip01_event.Event{
        &metadata_event.event,
        &role_event.event,
        &member_event.event,
    };
    try sender.applySnapshotEvents(snapshot[0..]);
    try receiver.applySnapshotEvents(snapshot[0..]);

    var selected_previous: [1][]const u8 = undefined;
    const previous_refs = sender.selectPreviousRefs(null, selected_previous[0..]);
    var outbound_buffer = OutboundBuffer{};
    const author_secret = [_]u8{0x23} ** 32;
    const outbound = try sender.beginPutUser(
        PublishContext.init(44, &author_secret, &outbound_buffer),
        &.{
            .pubkey = [_]u8{0xaa} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote",
            .previous_refs = previous_refs,
        },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqual(
        .put_user,
        try receiver.applyIncrementalStateEventJson(outbound.event_json, arena.allocator()),
    );
    try std.testing.expectEqualStrings("moderator", receiver.groupState().users[0].roles[0]);
}

test "group session rejects unknown previous refs before outbound moderation publish" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);

    var outbound_buffer = OutboundBuffer{};
    const author_secret = [_]u8{0x24} ** 32;
    try std.testing.expectError(
        error.UnknownPreviousReference,
        session.beginPutUser(
            PublishContext.init(45, &author_secret, &outbound_buffer),
            &.{
                .pubkey = [_]u8{0xaa} ** 32,
                .roles = &.{"moderator"},
                .reason = "promote",
                .previous_refs = &.{"deadbeef"},
            },
        ),
    );
}

test "group session blocks outbound publish helpers while relay auth is required" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var outbound_buffer = OutboundBuffer{};
    const author_secret = [_]u8{0x25} ** 32;
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.beginJoinRequest(
            PublishContext.init(46, &author_secret, &outbound_buffer),
            &.{ .reason = "please let me in" },
        ),
    );
}

test "group session rejects malformed state event json" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidField,
        session.applyIncrementalStateEventJson("{\"kind\":\"39000\"}", arena.allocator()),
    );
}

test "group session rejects relay host mismatch at init" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;

    try std.testing.expectError(
        error.GroupRelayHostMismatch,
        initTestSession(
            "groups.example'pizza-lovers",
            "wss://other.example",
            users[0..],
            roles[0..],
            user_roles[0..],
        ),
    );
}

test "group session propagates invalid relay urls before host-mismatch checks" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;

    try std.testing.expectError(
        error.InvalidRelayUrl,
        initTestSession(
            "relay.one'pizza-lovers",
            "https://relay.one",
            users[0..],
            roles[0..],
            user_roles[0..],
        ),
    );
}

test "group session accepts explicit default port in group reference host" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;

    var session = try initTestSession(
        "relay.one:443'pizza-lovers",
        "wss://relay.one",
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    try std.testing.expectEqualStrings("relay.one:443", session.groupReference().host);
}

test "group session rejects invalid signed state events before mutation" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var event: TestEventFixture = undefined;
    try buildMetadataEvent(&event, "pizza-lovers", "Pizza Lovers");
    event.event.sig[0] ^= 1;

    try std.testing.expectError(error.InvalidSignature, session.applyIncrementalStateEvent(&event.event));
    try std.testing.expectEqualStrings("", session.groupState().metadata.group_id);
}

test "group session rejects wrong-group events before mutation" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var event: TestEventFixture = undefined;
    try buildMetadataEvent(&event, "other-group", "Elsewhere");
    try std.testing.expectError(error.EventGroupMismatch, session.applyIncrementalStateEvent(&event.event));
    try std.testing.expectEqualStrings("", session.groupState().metadata.group_id);
}

test "group session rejects unsupported non-state NIP-29 kinds explicitly" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var join_event: TestEventFixture = undefined;
    try buildJoinRequestEvent(&join_event, "pizza-lovers");
    try std.testing.expectError(
        error.UnsupportedGroupEventKind,
        session.applyIncrementalStateEvent(&join_event.event),
    );
}

test "group session blocks incremental state intake while auth is required and resumes after auth" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.applyIncrementalStateEvent(&metadata_event.event),
    );

    const auth_event_json =
        \\{"id":"3dc7a38754fee63558d2020588ad38b8baac483969944a6b144735cf415acaa8","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","challenge-1"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    var auth_scratch_storage: [4096]u8 = undefined;
    var auth_scratch = std.heap.FixedBufferAllocator.init(&auth_scratch_storage);
    try session.acceptCurrentRelayAuthEventJson(
        auth_event_json,
        1_773_533_654,
        60,
        auth_scratch.allocator(),
    );

    try std.testing.expectEqual(.metadata, try session.applyIncrementalStateEvent(&metadata_event.event));
}

test "group session blocks incremental state intake after disconnect until reconnection" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();
    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");

    session.noteCurrentRelayDisconnected();
    try std.testing.expectError(
        error.RelayDisconnected,
        session.applyIncrementalStateEvent(&metadata_event.event),
    );

    session.markCurrentRelayConnected();
    try std.testing.expectEqual(.metadata, try session.applyIncrementalStateEvent(&metadata_event.event));
}

test "group session applies incremental event after a snapshot" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();
    var first_event: TestEventFixture = undefined;
    var second_event: TestEventFixture = undefined;
    try buildMetadataEvent(&first_event, "pizza-lovers", "Pizza Lovers");
    try buildMetadataEvent(&second_event, "pizza-lovers", "Pizza Again");

    const snapshot = [_]*const noztr.nip01_event.Event{&first_event.event};
    try session.applySnapshotEvents(snapshot[0..]);
    try std.testing.expectEqualStrings("Pizza Lovers", session.groupState().metadata.name.?);
    _ = try session.applyIncrementalStateEvent(&second_event.event);
    try std.testing.expectEqualStrings("pizza-lovers", session.groupState().metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Again", session.groupState().metadata.name.?);
}

test "group session reset clears reduced state and allows clean replay" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();
    var first_event: TestEventFixture = undefined;
    var second_event: TestEventFixture = undefined;
    try buildMetadataEvent(&first_event, "pizza-lovers", "Pizza Lovers");
    try buildMetadataEvent(&second_event, "pizza-lovers", "Pizza Again");

    _ = try session.applyIncrementalStateEvent(&first_event.event);
    try std.testing.expectEqualStrings("Pizza Lovers", session.groupState().metadata.name.?);
    session.resetState();
    try std.testing.expectEqualStrings("", session.groupState().metadata.group_id);
    _ = try session.applyIncrementalStateEvent(&second_event.event);
    try std.testing.expectEqualStrings("pizza-lovers", session.groupState().metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Again", session.groupState().metadata.name.?);
}

test "group session snapshot replacement keeps kernel snapshot semantics" {
    var users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var first_admins: TestEventFixture = undefined;
    var second_admins: TestEventFixture = undefined;
    try buildAdminSnapshotEvent(
        &first_admins,
        "pizza-lovers",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "ceo",
    );
    try buildAdminSnapshotEvent(
        &second_admins,
        "pizza-lovers",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "gardener",
    );
    const first_snapshot = [_]*const noztr.nip01_event.Event{&first_admins.event};
    const second_snapshot = [_]*const noztr.nip01_event.Event{&second_admins.event};
    try session.applySnapshotEvents(first_snapshot[0..]);
    try session.applySnapshotEvents(second_snapshot[0..]);

    try std.testing.expectEqual(@as(usize, 1), session.groupState().users.len);
    try std.testing.expectEqualStrings("gardener", session.groupState().users[0].roles[0]);
}

test "group session accepts incremental moderation replay with previous tags after snapshot" {
    var users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    var role_event: TestEventFixture = undefined;
    var member_event: TestEventFixture = undefined;
    var put_user_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    try buildRoleEvent(&role_event, "pizza-lovers", "moderator", "Can moderate the room");
    try buildMemberEvent(&member_event, "pizza-lovers");
    try buildPutUserEventWithPrevious(&put_user_event, "pizza-lovers", "deadbeef");

    const snapshot = [_]*const noztr.nip01_event.Event{
        &metadata_event.event,
        &role_event.event,
        &member_event.event,
    };
    try session.applySnapshotEvents(snapshot[0..]);
    var previous_refs_output: [1][]const u8 = undefined;
    const previous_refs = session.selectPreviousRefs(null, previous_refs_output[0..]);
    try std.testing.expectEqual(@as(usize, 1), previous_refs.len);
    try buildPutUserEventWithPrevious(&put_user_event, "pizza-lovers", previous_refs[0]);
    try std.testing.expectEqual(.put_user, try session.applyIncrementalStateEvent(&put_user_event.event));
    try std.testing.expectEqualStrings("moderator", session.groupState().users[0].roles[0]);
}

test "group session snapshot failure clears partial replay state" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var good_event: TestEventFixture = undefined;
    var wrong_event: TestEventFixture = undefined;
    try buildMetadataEvent(&good_event, "pizza-lovers", "Pizza Lovers");
    try buildMetadataEvent(&wrong_event, "other-group", "Elsewhere");
    const snapshot = [_]*const noztr.nip01_event.Event{
        &good_event.event,
        &wrong_event.event,
    };

    try std.testing.expectError(error.EventGroupMismatch, session.applySnapshotEvents(snapshot[0..]));
    try std.testing.expectEqualStrings("", session.groupState().metadata.group_id);
}

test "group session typed and json replay entrypoints share gating and mutation rules" {
    var typed_users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var typed_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var typed_user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var json_users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var json_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var json_user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var typed_session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        typed_users[0..],
        typed_roles[0..],
        typed_user_roles[0..],
    );
    var json_session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        json_users[0..],
        json_roles[0..],
        json_user_roles[0..],
    );
    var first_event: TestEventFixture = undefined;
    try buildMetadataEvent(&first_event, "pizza-lovers", "Pizza Lovers");
    var first_json_storage: [1024]u8 = undefined;
    const first_json = try buildMetadataEventJson(
        first_json_storage[0..],
        "pizza-lovers",
        "Pizza Lovers",
    );
    const snapshot = [_]*const noztr.nip01_event.Event{&first_event.event};
    const snapshot_jsons = [_][]const u8{first_json};

    try std.testing.expectError(error.RelayDisconnected, typed_session.applySnapshotEvents(snapshot[0..]));
    var typed_disconnected_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer typed_disconnected_arena.deinit();
    try std.testing.expectError(
        error.RelayDisconnected,
        json_session.applySnapshotEventJsons(snapshot_jsons[0..], typed_disconnected_arena.allocator()),
    );

    typed_session.markCurrentRelayConnected();
    json_session.markCurrentRelayConnected();
    try typed_session.applySnapshotEvents(snapshot[0..]);
    var json_snapshot_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer json_snapshot_arena.deinit();
    try json_session.applySnapshotEventJsons(snapshot_jsons[0..], json_snapshot_arena.allocator());

    var second_event: TestEventFixture = undefined;
    try buildMetadataEvent(&second_event, "pizza-lovers", "Pizza Again");
    var second_json_storage: [1024]u8 = undefined;
    const second_json = try buildMetadataEventJson(
        second_json_storage[0..],
        "pizza-lovers",
        "Pizza Again",
    );

    try typed_session.noteCurrentRelayAuthChallenge("challenge-1");
    try json_session.noteCurrentRelayAuthChallenge("challenge-1");
    try std.testing.expectError(
        error.RelayAuthRequired,
        typed_session.applyIncrementalStateEvent(&second_event.event),
    );
    var json_incremental_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer json_incremental_arena.deinit();
    try std.testing.expectError(
        error.RelayAuthRequired,
        json_session.applyIncrementalStateEventJson(second_json, json_incremental_arena.allocator()),
    );

    typed_session.noteCurrentRelayDisconnected();
    json_session.noteCurrentRelayDisconnected();
    typed_session.markCurrentRelayConnected();
    json_session.markCurrentRelayConnected();
    _ = try typed_session.applyIncrementalStateEvent(&second_event.event);
    var json_replay_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer json_replay_arena.deinit();
    _ = try json_session.applyIncrementalStateEventJson(second_json, json_replay_arena.allocator());

    try std.testing.expectEqualStrings(
        typed_session.groupState().metadata.name.?,
        json_session.groupState().metadata.name.?,
    );
}

test "group session accepts join request with known previous refs and records it" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);
    var selected_previous: [2][]const u8 = undefined;
    const previous_refs = session.selectPreviousRefs(null, selected_previous[0..]);
    try std.testing.expectEqual(@as(usize, 1), previous_refs.len);

    var join_event: TestEventFixture = undefined;
    try buildJoinRequestEventWithPrevious(&join_event, "pizza-lovers", previous_refs[0]);
    var join_previous: [2][]const u8 = undefined;
    const info = try session.acceptJoinRequestEvent(&join_event.event, join_previous[0..]);

    try std.testing.expectEqualStrings("pizza-lovers", info.group_id);
    try std.testing.expectEqualStrings("invite-123", info.invite_code.?);
    try std.testing.expectEqualStrings("please", info.reason.?);
    try std.testing.expectEqual(@as(usize, 1), info.previous_refs.len);
}

test "group session rejects join request with unknown previous refs" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var join_event: TestEventFixture = undefined;
    try buildJoinRequestEventWithPrevious(&join_event, "pizza-lovers", "deadbeef");
    var join_previous: [2][]const u8 = undefined;
    try std.testing.expectError(
        error.UnknownPreviousReference,
        session.acceptJoinRequestEvent(&join_event.event, join_previous[0..]),
    );
}

test "group session accepts leave request json with known previous refs" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);
    var selected_previous: [2][]const u8 = undefined;
    const previous_refs = session.selectPreviousRefs(null, selected_previous[0..]);
    try std.testing.expectEqual(@as(usize, 1), previous_refs.len);

    var leave_json_storage: [1024]u8 = undefined;
    const leave_json = try buildLeaveRequestEventJson(
        leave_json_storage[0..],
        "pizza-lovers",
        previous_refs[0],
    );
    var previous_storage: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const info = try session.acceptLeaveRequestEventJson(
        leave_json,
        previous_storage[0..],
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("pizza-lovers", info.group_id);
    try std.testing.expectEqualStrings("bye", info.reason.?);
    try std.testing.expectEqual(@as(usize, 1), info.previous_refs.len);
}

test "group session observes generic group event and records selectable previous refs" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try initTestSession(
        test_group_reference,
        test_group_relay_url,
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    session.markCurrentRelayConnected();

    var metadata_event: TestEventFixture = undefined;
    try buildMetadataEvent(&metadata_event, "pizza-lovers", "Pizza Lovers");
    _ = try session.applyIncrementalStateEvent(&metadata_event.event);
    var selected_previous: [2][]const u8 = undefined;
    const previous_refs = session.selectPreviousRefs(null, selected_previous[0..]);
    try std.testing.expectEqual(@as(usize, 1), previous_refs.len);

    var generic_event: TestEventFixture = undefined;
    try buildGenericGroupEventWithPrevious(&generic_event, "pizza-lovers", previous_refs[0]);
    var observe_previous: [2][]const u8 = undefined;
    try std.testing.expectEqual(
        GroupObservedEventKind.generic,
        try session.observeGroupEvent(&generic_event.event, observe_previous[0..]),
    );

    var no_self_previous: [2][]const u8 = undefined;
    const selected_without_author = session.selectPreviousRefs(&generic_event.event.pubkey, no_self_previous[0..]);
    try std.testing.expectEqual(@as(usize, 0), selected_without_author.len);
    const selected_any = session.selectPreviousRefs(null, no_self_previous[0..]);
    try std.testing.expect(selected_any.len >= 1);
}

const test_group_reference = "relay.one'pizza-lovers";
const test_group_relay_url = "wss://relay.one";
const test_group_signer_secret = [_]u8{0} ** 31 ++ [_]u8{9};

fn initTestSession(
    reference_text: []const u8,
    relay_url: []const u8,
    users: []noztr.nip29_relay_groups.GroupStateUser,
    roles: []noztr.nip29_relay_groups.GroupRole,
    user_roles: [][]const u8,
) GroupSessionError!GroupSession {
    return GroupSession.init(.{
        .reference_text = reference_text,
        .relay_url = relay_url,
        .storage = GroupSessionStorage.init(users, roles, user_roles),
    });
}

const TestEventFixture = struct {
    tag0_items: [3][]const u8 = undefined,
    tag1_items: [4][]const u8 = undefined,
    tag2_items: [3][]const u8 = undefined,
    tags: [3]noztr.nip01_event.EventTag = undefined,
    event: noztr.nip01_event.Event = undefined,
};

fn buildMetadataEventJson(output: []u8, group_id: []const u8, name: []const u8) ![]const u8 {
    var fixture: TestEventFixture = undefined;
    try buildMetadataEvent(&fixture, group_id, name);
    const id_hex = std.fmt.bytesToHex(fixture.event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(fixture.event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(fixture.event.sig, .lower);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":{d}," ++
            "\"tags\":[[\"d\",\"{s}\"],[\"name\",\"{s}\"],[\"public\"]]," ++
            "\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            id_hex[0..],
            pubkey_hex[0..],
            fixture.event.created_at,
            fixture.event.kind,
            group_id,
            name,
            sig_hex[0..],
        },
    ) catch error.BufferTooSmall;
}

fn buildMetadataEvent(output: *TestEventFixture, group_id: []const u8, name: []const u8) !void {
    output.tag0_items = .{ "d", group_id, undefined };
    output.tag1_items = .{ "name", name, undefined, undefined };
    output.tag2_items = .{ "public", undefined, undefined };
    output.tags = .{
        .{ .items = output.tag0_items[0..2] },
        .{ .items = output.tag1_items[0..2] },
        .{ .items = output.tag2_items[0..1] },
    };
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_metadata_kind,
        output.tags[0..3],
        "",
    );
}

fn buildAdminEvent(output: *TestEventFixture, group_id: []const u8) !void {
    return buildAdminSnapshotEvent(
        output,
        group_id,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "moderator",
    );
}

fn buildAdminSnapshotEvent(
    output: *TestEventFixture,
    group_id: []const u8,
    pubkey_hex: []const u8,
    role_name: []const u8,
) !void {
    output.tag0_items = .{ "d", group_id, undefined };
    output.tag1_items = .{ "p", pubkey_hex, role_name, undefined };
    output.tags = .{
        .{ .items = output.tag0_items[0..2] },
        .{ .items = output.tag1_items[0..3] },
        .{ .items = &.{} },
    };
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_admins_kind,
        output.tags[0..2],
        "",
    );
}

fn buildMemberEvent(output: *TestEventFixture, group_id: []const u8) !void {
    output.tag0_items = .{ "d", group_id, undefined };
    output.tag1_items = .{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "vip",
        undefined,
    };
    output.tags = .{
        .{ .items = output.tag0_items[0..2] },
        .{ .items = output.tag1_items[0..3] },
        .{ .items = &.{} },
    };
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_members_kind,
        output.tags[0..2],
        "",
    );
}

fn buildRoleEvent(
    output: *TestEventFixture,
    group_id: []const u8,
    role_name: []const u8,
    description: []const u8,
) !void {
    output.tag0_items = .{ "d", group_id, undefined };
    output.tag1_items = .{ "role", role_name, description, undefined };
    output.tags = .{
        .{ .items = output.tag0_items[0..2] },
        .{ .items = output.tag1_items[0..3] },
        .{ .items = &.{} },
    };
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_roles_kind,
        output.tags[0..2],
        "",
    );
}

fn buildPutUserEvent(output: *TestEventFixture, group_id: []const u8) !void {
    return buildPutUserEventWithPrevious(output, group_id, null);
}

fn buildPutUserEventWithPrevious(
    output: *TestEventFixture,
    group_id: []const u8,
    previous_ref: ?[]const u8,
) !void {
    output.tag0_items = .{ "h", group_id, undefined };
    output.tag1_items = .{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "moderator",
        undefined,
    };
    if (previous_ref) |value| {
        output.tag2_items = .{ "previous", value, undefined };
        output.tags = .{
            .{ .items = output.tag0_items[0..2] },
            .{ .items = output.tag1_items[0..3] },
            .{ .items = output.tag2_items[0..2] },
        };
    } else {
        output.tags = .{
            .{ .items = output.tag0_items[0..2] },
            .{ .items = output.tag1_items[0..3] },
            .{ .items = &.{} },
        };
    }
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_put_user_kind,
        if (previous_ref != null) output.tags[0..3] else output.tags[0..2],
        "promote",
    );
}

fn buildJoinRequestEvent(output: *TestEventFixture, group_id: []const u8) !void {
    return buildJoinRequestEventWithPrevious(output, group_id, null);
}

fn buildJoinRequestEventWithPrevious(
    output: *TestEventFixture,
    group_id: []const u8,
    previous_ref: ?[]const u8,
) !void {
    output.tag0_items = .{ "h", group_id, undefined };
    output.tag1_items = .{ "code", "invite-123", undefined, undefined };
    if (previous_ref) |value| {
        output.tag2_items = .{ "previous", value, undefined };
        output.tags = .{
            .{ .items = output.tag0_items[0..2] },
            .{ .items = output.tag1_items[0..2] },
            .{ .items = output.tag2_items[0..2] },
        };
    } else {
        output.tags = .{
            .{ .items = output.tag0_items[0..2] },
            .{ .items = output.tag1_items[0..2] },
            .{ .items = &.{} },
        };
    }
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_join_request_kind,
        if (previous_ref != null) output.tags[0..3] else output.tags[0..2],
        "please",
    );
}

fn buildLeaveRequestEvent(output: *TestEventFixture, group_id: []const u8, previous_ref: []const u8) !void {
    output.tag0_items = .{ "h", group_id, undefined };
    output.tag1_items = .{ "previous", previous_ref, undefined, undefined };
    output.tags = .{
        .{ .items = output.tag0_items[0..2] },
        .{ .items = output.tag1_items[0..2] },
        .{ .items = &.{} },
    };
    try finalizeTestEvent(
        output,
        noztr.nip29_relay_groups.group_leave_request_kind,
        output.tags[0..2],
        "bye",
    );
}

fn buildLeaveRequestEventJson(output: []u8, group_id: []const u8, previous_ref: []const u8) ![]const u8 {
    var fixture: TestEventFixture = undefined;
    try buildLeaveRequestEvent(&fixture, group_id, previous_ref);
    const id_hex = std.fmt.bytesToHex(fixture.event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(fixture.event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(fixture.event.sig, .lower);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":{d}," ++
            "\"tags\":[[\"h\",\"{s}\"],[\"previous\",\"{s}\"]]," ++
            "\"content\":\"bye\",\"sig\":\"{s}\"}}",
        .{
            id_hex[0..],
            pubkey_hex[0..],
            fixture.event.created_at,
            fixture.event.kind,
            group_id,
            previous_ref,
            sig_hex[0..],
        },
    ) catch error.BufferTooSmall;
}

fn buildGenericGroupEventWithPrevious(
    output: *TestEventFixture,
    group_id: []const u8,
    previous_ref: []const u8,
) !void {
    output.tag0_items = .{ "h", group_id, undefined };
    output.tag1_items = .{ "previous", previous_ref, undefined, undefined };
    output.tags = .{
        .{ .items = output.tag0_items[0..2] },
        .{ .items = output.tag1_items[0..2] },
        .{ .items = &.{} },
    };
    try finalizeTestEvent(output, 1, output.tags[0..2], "hello group");
}

fn finalizeTestEvent(
    fixture: *TestEventFixture,
    kind: u32,
    tags: []const noztr.nip01_event.EventTag,
    content: []const u8,
) !void {
    fixture.event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = try noztr.nostr_keys.nostr_derive_public_key(&test_group_signer_secret),
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 1_710_100_000,
        .content = content,
        .tags = tags,
    };
    try noztr.nostr_keys.nostr_sign_event(&test_group_signer_secret, &fixture.event);
}
