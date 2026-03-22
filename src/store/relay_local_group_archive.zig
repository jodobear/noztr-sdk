const std = @import("std");
const noztr = @import("noztr");
const client = @import("client_traits.zig");
const archive = @import("archive.zig");
const workflows = @import("../workflows/mod.zig");

pub const RelayLocalGroupArchiveError = archive.EventArchiveError || workflows.GroupClientError || error{
    BufferTooSmall,
};

pub const RelayLocalGroupArchive = struct {
    archive: archive.EventArchive,
    reference: noztr.nip29_relay_groups.GroupReference,

    pub fn init(
        store: client.ClientStore,
        reference_text: []const u8,
    ) noztr.nip29_relay_groups.GroupError!RelayLocalGroupArchive {
        return .{
            .archive = archive.EventArchive.init(store),
            .reference = try noztr.nip29_relay_groups.group_reference_parse(reference_text),
        };
    }

    pub fn ingestStateEventJson(
        self: RelayLocalGroupArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayLocalGroupArchiveError!workflows.GroupStateEventKind {
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        try noztr.nip01_event.event_verify(&event);

        const event_kind = try classifyStateEventKind(event.kind);
        try requireReferenceMatch(&self.reference, &event);
        try self.archive.ingestEventJson(event_json, scratch);
        return event_kind;
    }

    pub fn restoreSnapshot(
        self: RelayLocalGroupArchive,
        group: *workflows.GroupClient,
        event_storage: []client.ClientEventRecord,
        scratch: std.mem.Allocator,
    ) RelayLocalGroupArchiveError!usize {
        if (!std.mem.eql(u8, group.groupReference().id, self.reference.id)) {
            return error.EventGroupMismatch;
        }

        const state_kinds = [_]u32{
            noztr.nip29_relay_groups.group_metadata_kind,
            noztr.nip29_relay_groups.group_admins_kind,
            noztr.nip29_relay_groups.group_members_kind,
            noztr.nip29_relay_groups.group_roles_kind,
            noztr.nip29_relay_groups.group_put_user_kind,
            noztr.nip29_relay_groups.group_remove_user_kind,
        };
        var page = client.EventQueryResultPage.init(event_storage);
        try self.archive.query(&.{
            .kinds = state_kinds[0..],
            .limit = event_storage.len,
            .index_selection = .checkpoint_replay,
        }, &page);
        if (page.truncated) return error.BufferTooSmall;

        const replay_jsons = try scratch.alloc([]const u8, page.count);
        var replay_count: usize = 0;
        var index = page.count;
        while (index > 0) {
            index -= 1;
            const record = &page.slice()[index];
            const event = try noztr.nip01_event.event_parse_json(record.eventJson(), scratch);
            try noztr.nip01_event.event_verify(&event);
            _ = try classifyStateEventKind(event.kind);
            try requireReferenceMatch(&self.reference, &event);
            replay_jsons[replay_count] = record.eventJson();
            replay_count += 1;
        }

        try group.applySnapshotEventJsons(replay_jsons[0..replay_count], scratch);
        return replay_count;
    }
};

fn classifyStateEventKind(kind: u32) RelayLocalGroupArchiveError!workflows.GroupStateEventKind {
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

fn requireReferenceMatch(
    reference: *const noztr.nip29_relay_groups.GroupReference,
    event: *const noztr.nip01_event.Event,
) RelayLocalGroupArchiveError!void {
    var users: [noztr.limits.tags_max]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [noztr.limits.tags_max]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [noztr.limits.tags_max * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var state = noztr.nip29_relay_groups.GroupState.init(
        users[0..],
        roles[0..],
        user_roles[0..],
    );
    try noztr.nip29_relay_groups.group_state_apply_event(&state, event);
    if (std.mem.eql(u8, state.metadata.group_id, reference.id)) return;
    return error.EventGroupMismatch;
}

test "relay-local group archive restores one stored group snapshot through the shared event seam" {
    var store = @import("client_memory.zig").MemoryClientStore{};
    const group_archive = try RelayLocalGroupArchive.init(
        store.asClientStore(),
        "relay.one'pizza-lovers",
    );

    var sender_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var sender_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var sender_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var sender_previous_refs: [8][]const u8 = undefined;
    var sender = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(sender_users[0..], sender_roles[0..], sender_user_roles[0..]),
            sender_previous_refs[0..],
        ),
    });
    sender.markCurrentRelayConnected();

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = workflows.GroupOutboundBuffer{};
    var roles_buffer = workflows.GroupOutboundBuffer{};
    var members_buffer = workflows.GroupOutboundBuffer{};
    const metadata_event = try sender.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );
    const roles_event = try sender.beginRolesSnapshot(
        .init(2, &author_secret, &roles_buffer),
        &.{
            .roles = &.{
                .{
                    .name = "moderator",
                    .description = "Can moderate the room",
                },
            },
        },
    );
    const members_event = try sender.beginMembersSnapshot(
        .init(3, &author_secret, &members_buffer),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "vip",
                },
            },
        },
    );

    var ingest_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer ingest_arena.deinit();
    _ = try group_archive.ingestStateEventJson(metadata_event.event_json, ingest_arena.allocator());
    _ = try group_archive.ingestStateEventJson(roles_event.event_json, ingest_arena.allocator());
    _ = try group_archive.ingestStateEventJson(members_event.event_json, ingest_arena.allocator());

    var receiver_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var receiver_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var receiver_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var receiver_previous_refs: [8][]const u8 = undefined;
    var receiver = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(receiver_users[0..], receiver_roles[0..], receiver_user_roles[0..]),
            receiver_previous_refs[0..],
        ),
    });
    receiver.markCurrentRelayConnected();

    var replay_records: [4]client.ClientEventRecord = undefined;
    var restore_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer restore_arena.deinit();
    const restored = try group_archive.restoreSnapshot(
        &receiver,
        replay_records[0..],
        restore_arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 3), restored);
    try std.testing.expectEqualStrings("Pizza Lovers", receiver.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), receiver.view().users.len);
    try std.testing.expectEqualStrings("moderator", receiver.view().supported_roles[0].name);
}

test "relay-local group archive rejects state events for another group" {
    var store = @import("client_memory.zig").MemoryClientStore{};
    const group_archive = try RelayLocalGroupArchive.init(
        store.asClientStore(),
        "relay.one'pizza-lovers",
    );

    var fixture = workflows.GroupOutboundBuffer{};
    const author_secret = [_]u8{0x09} ** 32;
    var client_users: [0]noztr.nip29_relay_groups.GroupStateUser = .{};
    var client_roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var client_user_roles: [0][]const u8 = .{};
    var previous_refs: [0][]const u8 = .{};
    var client_group = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'other-group",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(client_users[0..], client_roles[0..], client_user_roles[0..]),
            previous_refs[0..],
        ),
    });
    client_group.markCurrentRelayConnected();
    const metadata = try client_group.beginMetadataSnapshot(
        .init(1, &author_secret, &fixture),
        &.{ .name = "Other Group" },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(
        error.EventGroupMismatch,
        group_archive.ingestStateEventJson(metadata.event_json, arena.allocator()),
    );
}
