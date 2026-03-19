const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Persist one relay-local `NIP-29` snapshot into the shared event store seam, then restore that
// same group state into a fresh client in explicit oldest-to-newest replay order.
test "recipe: relay-local group archive restores one group snapshot over shared storage" {
    var store = noztr_sdk.store.MemoryClientStore{};
    const archive = try noztr_sdk.store.RelayLocalGroupArchive.init(
        store.asClientStore(),
        "relay.one'pizza-lovers",
    );

    var sender_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var sender_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var sender_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var sender_previous_refs: [8][]const u8 = undefined;
    var sender = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(sender_users[0..], sender_roles[0..], sender_user_roles[0..]),
            sender_previous_refs[0..],
        ),
    });
    sender.markCurrentRelayConnected();

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    var roles_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    var members_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const metadata = try sender.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );
    const roles = try sender.beginRolesSnapshot(
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
    const members = try sender.beginMembersSnapshot(
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

    var sender_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer sender_arena.deinit();
    _ = try archive.ingestStateEventJson(metadata.event_json, sender_arena.allocator());
    _ = try archive.ingestStateEventJson(roles.event_json, sender_arena.allocator());
    _ = try archive.ingestStateEventJson(members.event_json, sender_arena.allocator());

    var receiver_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var receiver_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var receiver_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var receiver_previous_refs: [8][]const u8 = undefined;
    var receiver = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(receiver_users[0..], receiver_roles[0..], receiver_user_roles[0..]),
            receiver_previous_refs[0..],
        ),
    });
    receiver.markCurrentRelayConnected();

    var replay_records: [4]noztr_sdk.store.ClientEventRecord = undefined;
    var receiver_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer receiver_arena.deinit();
    const restored = try archive.restoreSnapshot(
        &receiver,
        replay_records[0..],
        receiver_arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 3), restored);
    try std.testing.expectEqualStrings("Pizza Lovers", receiver.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), receiver.view().users.len);
    try std.testing.expectEqualStrings("moderator", receiver.view().supported_roles[0].name);
}
