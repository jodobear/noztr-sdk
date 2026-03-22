const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Build one canonical `NIP-29` snapshot through the higher-level group client, export one durable
// checkpoint, restore it into a second client, then build and replay one outbound moderation
// update.
test "recipe: group client exports and restores one checkpoint before moderation publish" {
    var users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var previous_refs_storage: [8][]const u8 = undefined;
    var sender = try noztr_sdk.workflows.groups.local.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users[0..], roles[0..], user_roles[0..]),
            previous_refs_storage[0..],
        ),
    });
    sender.markCurrentRelayConnected();

    var metadata_buffer = noztr_sdk.workflows.groups.session.GroupOutboundBuffer{};
    var role_buffer = noztr_sdk.workflows.groups.session.GroupOutboundBuffer{};
    var member_buffer = noztr_sdk.workflows.groups.session.GroupOutboundBuffer{};
    const author_secret = [_]u8{0x09} ** 32;
    const metadata_event = try sender.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{
            .name = "Pizza Lovers",
        },
    );
    const role_event = try sender.beginRolesSnapshot(
        .init(2, &author_secret, &role_buffer),
        &.{
            .roles = &.{
                .{
                    .name = "moderator",
                    .description = "Can moderate the room",
                },
            },
        },
    );
    const member_event = try sender.beginMembersSnapshot(
        .init(3, &author_secret, &member_buffer),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "vip",
                },
            },
        },
    );
    const snapshot = [_][]const u8{
        metadata_event.event_json,
        role_event.event_json,
        member_event.event_json,
    };
    var sender_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer sender_arena.deinit();
    try sender.applySnapshotEventJsons(snapshot[0..], sender_arena.allocator());

    var checkpoint_buffers = noztr_sdk.workflows.groups.local.GroupCheckpointBuffers{};
    const checkpoint = try sender.exportCheckpoint(
        .init(10, &author_secret, &checkpoint_buffers),
    );

    var receiver_users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var receiver_roles: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var receiver_user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var receiver_previous_refs: [8][]const u8 = undefined;
    var receiver = try noztr_sdk.workflows.groups.local.GroupClient.init(.{
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
    var receiver_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer receiver_arena.deinit();
    try receiver.restoreCheckpoint(&checkpoint, receiver_arena.allocator());

    var selected_previous: [1][]const u8 = undefined;
    const previous_refs = receiver.selectPreviousRefs(null, selected_previous[0..]);
    receiver.markCurrentRelayConnected();
    var outbound_buffer = noztr_sdk.workflows.groups.session.GroupOutboundBuffer{};
    const outbound = try receiver.beginPutUser(
        .init(4, &author_secret, &outbound_buffer),
        &.{
            .pubkey = [_]u8{0xaa} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote",
            .previous_refs = previous_refs,
        },
    );
    try std.testing.expectEqualStrings("wss://relay.one", outbound.relay_url);
    try std.testing.expect(std.mem.indexOf(u8, outbound.event_json, "\"kind\":9000") != null);
    const outcome = try receiver.consumeEventJson(outbound.event_json, receiver_arena.allocator());
    try std.testing.expect(outcome == .state);
    try std.testing.expectEqual(.put_user, outcome.state);

    const view = receiver.view();
    try std.testing.expectEqualStrings("pizza-lovers", view.metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Lovers", view.metadata.name.?);
    try std.testing.expectEqualStrings("moderator", view.users[0].roles[0]);
}
