const std = @import("std");
const noztr = @import("noztr");
const group_session = @import("group_session.zig");

pub const GroupClientError = group_session.GroupSessionError;
pub const GroupRelayState = group_session.GroupRelayState;
pub const GroupClientView = group_session.GroupSessionView;
pub const GroupCheckpointBuffers = group_session.GroupCheckpointBuffers;
pub const GroupCheckpointContext = group_session.GroupCheckpointContext;
pub const GroupCheckpoint = group_session.GroupCheckpoint;
pub const GroupClientCapacity = struct {
    session: group_session.GroupSessionCapacity,
    previous_refs: usize,
};

pub const GroupClientStorage = struct {
    session: group_session.GroupSessionStorage,
    previous_refs: [][]const u8,

    pub fn init(
        session: group_session.GroupSessionStorage,
        previous_refs: [][]const u8,
    ) GroupClientStorage {
        return .{
            .session = session,
            .previous_refs = previous_refs,
        };
    }

    pub fn capacity(self: GroupClientStorage) GroupClientCapacity {
        return .{
            .session = self.session.capacity(),
            .previous_refs = self.previous_refs.len,
        };
    }
};

pub const GroupClientConfig = struct {
    reference_text: []const u8,
    relay_url: []const u8,
    storage: GroupClientStorage,
};

pub const GroupClientEventOutcome = union(enum) {
    state: group_session.GroupStateEventKind,
    join_request: group_session.GroupJoinRequestInfo,
    leave_request: group_session.GroupLeaveRequestInfo,
    generic: void,
};

pub const GroupClientBatchSummary = struct {
    total: usize = 0,
    state_events: usize = 0,
    join_requests: usize = 0,
    leave_requests: usize = 0,
    generic_events: usize = 0,

    fn record(self: *GroupClientBatchSummary, outcome: GroupClientEventOutcome) void {
        self.total += 1;
        switch (outcome) {
            .state => self.state_events += 1,
            .join_request => self.join_requests += 1,
            .leave_request => self.leave_requests += 1,
            .generic => self.generic_events += 1,
        }
    }
};

pub const GroupClient = struct {
    _session: group_session.GroupSession,
    _previous_refs: [][]const u8,

    pub fn init(config: GroupClientConfig) GroupClientError!GroupClient {
        return .{
            ._session = try group_session.GroupSession.init(.{
                .reference_text = config.reference_text,
                .relay_url = config.relay_url,
                .storage = config.storage.session,
            }),
            ._previous_refs = config.storage.previous_refs,
        };
    }

    pub fn session(self: *GroupClient) *group_session.GroupSession {
        return &self._session;
    }

    pub fn sessionConst(self: *const GroupClient) *const group_session.GroupSession {
        return &self._session;
    }

    pub fn view(self: *const GroupClient) GroupClientView {
        return self._session.view();
    }

    pub fn storageCapacity(self: *const GroupClient) GroupClientCapacity {
        return .{
            .session = self._session.groupState().capacity(),
            .previous_refs = self._previous_refs.len,
        };
    }

    pub fn groupReference(self: *const GroupClient) noztr.nip29_relay_groups.GroupReference {
        return self._session.groupReference();
    }

    pub fn currentRelayUrl(self: *const GroupClient) []const u8 {
        return self._session.currentRelayUrl();
    }

    pub fn currentRelayCanReceive(self: *const GroupClient) bool {
        return self._session.currentRelayCanReceive();
    }

    pub fn currentRelayState(self: *const GroupClient) GroupRelayState {
        return self._session.currentRelayState();
    }

    pub fn markCurrentRelayConnected(self: *GroupClient) void {
        self._session.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(self: *GroupClient) void {
        self._session.noteCurrentRelayDisconnected();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *GroupClient,
        challenge: []const u8,
    ) GroupClientError!void {
        try self._session.noteCurrentRelayAuthChallenge(challenge);
    }

    pub fn acceptCurrentRelayAuthEventJson(
        self: *GroupClient,
        auth_event_json: []const u8,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) GroupClientError!void {
        try self._session.acceptCurrentRelayAuthEventJson(
            auth_event_json,
            now_unix_seconds,
            window_seconds,
            scratch,
        );
    }

    pub fn resetState(self: *GroupClient) void {
        self._session.resetState();
    }

    pub fn applySnapshotEvents(
        self: *GroupClient,
        events: []const *const noztr.nip01_event.Event,
    ) GroupClientError!void {
        try self._session.applySnapshotEvents(events);
    }

    pub fn applySnapshotEventJsons(
        self: *GroupClient,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupClientError!void {
        try self._session.applySnapshotEventJsons(event_jsons, scratch);
    }

    pub fn selectPreviousRefs(
        self: *const GroupClient,
        author_pubkey: ?*const [32]u8,
        output: [][]const u8,
    ) []const []const u8 {
        return self._session.selectPreviousRefs(author_pubkey, output);
    }

    pub fn beginJoinRequest(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupJoinRequestDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginJoinRequest(context, request);
    }

    pub fn beginMetadataSnapshot(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupMetadataDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginMetadataSnapshot(context, request);
    }

    pub fn beginAdminsSnapshot(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupAdminsDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginAdminsSnapshot(context, request);
    }

    pub fn beginMembersSnapshot(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupMembersDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginMembersSnapshot(context, request);
    }

    pub fn beginRolesSnapshot(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupRolesDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginRolesSnapshot(context, request);
    }

    pub fn beginLeaveRequest(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupLeaveRequestDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginLeaveRequest(context, request);
    }

    pub fn beginPutUser(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupPutUserDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginPutUser(context, request);
    }

    pub fn beginRemoveUser(
        self: *const GroupClient,
        context: group_session.GroupPublishContext,
        request: *const group_session.GroupRemoveUserDraft,
    ) GroupClientError!group_session.GroupOutboundEvent {
        return self._session.beginRemoveUser(context, request);
    }

    pub fn exportCheckpoint(
        self: *const GroupClient,
        context: GroupCheckpointContext,
    ) GroupClientError!GroupCheckpoint {
        return self._session.exportCheckpoint(context);
    }

    pub fn restoreCheckpoint(
        self: *GroupClient,
        checkpoint: *const GroupCheckpoint,
        scratch: std.mem.Allocator,
    ) GroupClientError!void {
        var event_jsons: [4][]const u8 = undefined;
        try self._session.restoreCheckpointEventJsons(
            checkpoint.eventJsons(&event_jsons),
            scratch,
        );
    }

    pub fn consumeEventJson(
        self: *GroupClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupClientError!GroupClientEventOutcome {
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.consumeEvent(&event);
    }

    pub fn consumeEvent(
        self: *GroupClient,
        event: *const noztr.nip01_event.Event,
    ) GroupClientError!GroupClientEventOutcome {
        return switch (event.kind) {
            noztr.nip29_relay_groups.group_metadata_kind,
            noztr.nip29_relay_groups.group_admins_kind,
            noztr.nip29_relay_groups.group_members_kind,
            noztr.nip29_relay_groups.group_roles_kind,
            noztr.nip29_relay_groups.group_put_user_kind,
            noztr.nip29_relay_groups.group_remove_user_kind,
            => .{ .state = try self._session.applyIncrementalStateEvent(event) },
            noztr.nip29_relay_groups.group_join_request_kind => .{
                .join_request = try self._session.acceptJoinRequestEvent(
                    event,
                    self._previous_refs,
                ),
            },
            noztr.nip29_relay_groups.group_leave_request_kind => .{
                .leave_request = try self._session.acceptLeaveRequestEvent(
                    event,
                    self._previous_refs,
                ),
            },
            else => blk: {
                const observed = try self._session.observeGroupEvent(
                    event,
                    self._previous_refs,
                );
                std.debug.assert(observed == .generic);
                break :blk .{ .generic = {} };
            },
        };
    }

    pub fn consumeEventJsons(
        self: *GroupClient,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupClientError!GroupClientBatchSummary {
        var summary: GroupClientBatchSummary = .{};
        for (event_jsons) |event_json| {
            const outcome = try self.consumeEventJson(event_json, scratch);
            summary.record(outcome);
        }
        return summary;
    }

    pub fn consumeEvents(
        self: *GroupClient,
        events: []const *const noztr.nip01_event.Event,
    ) GroupClientError!GroupClientBatchSummary {
        var summary: GroupClientBatchSummary = .{};
        for (events) |event| {
            const outcome = try self.consumeEvent(event);
            summary.record(outcome);
        }
        return summary;
    }
};

test "group client consumes mixed event stream over owned previous-ref storage" {
    var users: [4]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [2]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [4 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var previous_refs: [8][]const u8 = undefined;
    var client = try GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users[0..], roles[0..], user_roles[0..]),
            previous_refs[0..],
        ),
    });
    client.markCurrentRelayConnected();

    const snapshot_events = try group_session_tests.buildSnapshotEvents("pizza-lovers");
    try client.applySnapshotEvents(snapshot_events[0..]);

    var prior_refs: [1][]const u8 = undefined;
    const previous = client.selectPreviousRefs(null, prior_refs[0..]);
    var join_buffer = group_session.GroupOutboundBuffer{};
    var leave_buffer = group_session.GroupOutboundBuffer{};
    const author_secret = [_]u8{0x09} ** 32;
    const join_event = try client.beginJoinRequest(
        .init(2, &author_secret, &join_buffer),
        &.{ .reason = "please let me in", .previous_refs = previous },
    );
    const leave_event = try client.beginLeaveRequest(
        .init(3, &author_secret, &leave_buffer),
        &.{ .reason = "done here", .previous_refs = previous },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const join_outcome = try client.consumeEventJson(join_event.event_json, arena.allocator());
    try std.testing.expect(join_outcome == .join_request);
    try std.testing.expectEqualStrings("pizza-lovers", join_outcome.join_request.group_id);

    const leave_outcome = try client.consumeEventJson(leave_event.event_json, arena.allocator());
    try std.testing.expect(leave_outcome == .leave_request);
    try std.testing.expectEqualStrings("pizza-lovers", leave_outcome.leave_request.group_id);
}

test "group client exports and restores one single-relay checkpoint without relay readiness" {
    var users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var previous_refs: [8][]const u8 = undefined;
    var sender = try GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users[0..], roles[0..], user_roles[0..]),
            previous_refs[0..],
        ),
    });
    sender.markCurrentRelayConnected();

    var snapshot = try group_session_tests.buildSnapshotEvents("pizza-lovers");
    try sender.applySnapshotEvents(snapshot[0..]);

    var prior_refs: [1][]const u8 = undefined;
    const known_previous = sender.selectPreviousRefs(null, prior_refs[0..]);
    var outbound_buffer = group_session.GroupOutboundBuffer{};
    _ = try sender.beginPutUser(
        .init(5, &group_session_tests.test_author_secret, &outbound_buffer),
        &.{
            .pubkey = [_]u8{0xaa} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote",
            .previous_refs = known_previous,
        },
    );

    sender.noteCurrentRelayDisconnected();
    var checkpoint_buffers = GroupCheckpointBuffers{};
    const checkpoint = try sender.exportCheckpoint(
        .init(100, &group_session_tests.test_author_secret, &checkpoint_buffers),
    );
    try std.testing.expectEqualStrings("wss://relay.one", checkpoint.relay_url);

    var receiver_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var receiver_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var receiver_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var receiver_previous_refs: [8][]const u8 = undefined;
    var receiver = try GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(
                receiver_users[0..],
                receiver_roles[0..],
                receiver_user_roles[0..],
            ),
            receiver_previous_refs[0..],
        ),
    });
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try receiver.restoreCheckpoint(&checkpoint, arena.allocator());

    const view = receiver.view();
    try std.testing.expectEqualStrings("pizza-lovers", view.metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Lovers", view.metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), view.users.len);
    try std.testing.expectEqual(@as(usize, 1), view.supported_roles.len);

    var restored_previous_out: [1][]const u8 = undefined;
    const restored_previous = receiver.selectPreviousRefs(null, restored_previous_out[0..]);
    try std.testing.expectEqual(@as(usize, 1), restored_previous.len);

    receiver.markCurrentRelayConnected();
    var restored_buffer = group_session.GroupOutboundBuffer{};
    const outbound = try receiver.beginPutUser(
        .init(200, &group_session_tests.test_author_secret, &restored_buffer),
        &.{
            .pubkey = [_]u8{0xaa} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote again",
            .previous_refs = restored_previous,
        },
    );
    try std.testing.expect(std.mem.indexOf(u8, outbound.event_json, "\"kind\":9000") != null);
}

test "group client summarizes mixed relay events" {
    var users: [4]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [2]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [4 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var previous_refs: [8][]const u8 = undefined;
    var client = try GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users[0..], roles[0..], user_roles[0..]),
            previous_refs[0..],
        ),
    });
    client.markCurrentRelayConnected();

    const snapshot_events = try group_session_tests.buildSnapshotEvents("pizza-lovers");
    try client.applySnapshotEvents(snapshot_events[0..]);

    var prior_refs: [1][]const u8 = undefined;
    const previous = client.selectPreviousRefs(null, prior_refs[0..]);
    var moderation_buffer = group_session.GroupOutboundBuffer{};
    var join_buffer = group_session.GroupOutboundBuffer{};
    const author_secret = [_]u8{0x09} ** 32;
    const put_user = try client.beginPutUser(
        .init(2, &author_secret, &moderation_buffer),
        &.{
            .pubkey = [_]u8{0xaa} ** 32,
            .roles = &.{"moderator"},
            .previous_refs = previous,
        },
    );
    const join_request = try client.beginJoinRequest(
        .init(3, &author_secret, &join_buffer),
        &.{ .reason = "join pls", .previous_refs = previous },
    );
    const events = [_][]const u8{
        put_user.event_json,
        join_request.event_json,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const summary = try client.consumeEventJsons(events[0..], arena.allocator());
    try std.testing.expectEqual(@as(usize, 2), summary.total);
    try std.testing.expectEqual(@as(usize, 1), summary.state_events);
    try std.testing.expectEqual(@as(usize, 1), summary.join_requests);
    try std.testing.expectEqual(@as(usize, 0), summary.leave_requests);
    try std.testing.expectEqual(@as(usize, 0), summary.generic_events);
}

const group_session_tests = struct {
    const test_author_secret = [_]u8{0x09} ** 32;

    fn buildSnapshotEvents(group_id: []const u8) ![3]*const noztr.nip01_event.Event {
        const secret = test_author_secret;
        const pubkey = try noztr.nostr_keys.nostr_derive_public_key(&secret);

        snapshot_storage.metadata_group_items = .{ "d", group_id };
        snapshot_storage.metadata_name_items = .{ "name", "Pizza Lovers" };
        snapshot_storage.metadata_public_items = .{ "public" };
        snapshot_storage.metadata_tags = .{
            .{ .items = snapshot_storage.metadata_group_items[0..] },
            .{ .items = snapshot_storage.metadata_name_items[0..] },
            .{ .items = snapshot_storage.metadata_public_items[0..] },
        };

        snapshot_storage.roles_group_items = .{ "d", group_id };
        snapshot_storage.roles_role_items = .{ "role", "moderator", "Can moderate" };
        snapshot_storage.roles_tags = .{
            .{ .items = snapshot_storage.roles_group_items[0..] },
            .{ .items = snapshot_storage.roles_role_items[0..] },
        };

        snapshot_storage.members_group_items = .{ "d", group_id };
        snapshot_storage.members_user_items = .{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "vip",
        };
        snapshot_storage.members_tags = .{
            .{ .items = snapshot_storage.members_group_items[0..] },
            .{ .items = snapshot_storage.members_user_items[0..] },
        };

        snapshot_storage.metadata = .{
            .id = [_]u8{0} ** 32,
            .pubkey = pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip29_relay_groups.group_metadata_kind,
            .created_at = 1,
            .content = "",
            .tags = snapshot_storage.metadata_tags[0..],
        };
        try noztr.nostr_keys.nostr_sign_event(&secret, &snapshot_storage.metadata);

        snapshot_storage.roles = .{
            .id = [_]u8{0} ** 32,
            .pubkey = pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip29_relay_groups.group_roles_kind,
            .created_at = 1,
            .content = "",
            .tags = snapshot_storage.roles_tags[0..],
        };
        try noztr.nostr_keys.nostr_sign_event(&secret, &snapshot_storage.roles);

        snapshot_storage.members = .{
            .id = [_]u8{0} ** 32,
            .pubkey = pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip29_relay_groups.group_members_kind,
            .created_at = 1,
            .content = "",
            .tags = snapshot_storage.members_tags[0..],
        };
        try noztr.nostr_keys.nostr_sign_event(&secret, &snapshot_storage.members);

        return .{
            &snapshot_storage.metadata,
            &snapshot_storage.roles,
            &snapshot_storage.members,
        };
    }

    var snapshot_storage: struct {
        metadata_group_items: [2][]const u8 = undefined,
        metadata_name_items: [2][]const u8 = undefined,
        metadata_public_items: [1][]const u8 = undefined,
        metadata_tags: [3]noztr.nip01_event.EventTag = undefined,
        roles_group_items: [2][]const u8 = undefined,
        roles_role_items: [3][]const u8 = undefined,
        roles_tags: [2]noztr.nip01_event.EventTag = undefined,
        members_group_items: [2][]const u8 = undefined,
        members_user_items: [3][]const u8 = undefined,
        members_tags: [2]noztr.nip01_event.EventTag = undefined,
        metadata: noztr.nip01_event.Event = undefined,
        roles: noztr.nip01_event.Event = undefined,
        members: noztr.nip01_event.Event = undefined,
    } = undefined;
};
