const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Drive one bounded multi-relay groups client above the existing fleet workflow: inspect runtime,
// inspect consistency, inspect one explicit background-runtime step, and select the relay for that
// next step without inventing hidden background ownership.
test "recipe: group fleet client inspects runtime consistency and one next background relay" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var relay_one = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users_a[0..], roles_a[0..], user_roles_a[0..]),
            previous_refs_a[0..],
        ),
    });

    var users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var relay_two = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });
    relay_one.markCurrentRelayConnected();
    relay_two.markCurrentRelayConnected();

    var fleet_members = [_]*noztr_sdk.workflows.GroupClient{ &relay_one, &relay_two };
    const fleet = try noztr_sdk.workflows.GroupFleet.init(fleet_members[0..]);
    var groups = noztr_sdk.client.GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const first = try relay_one.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );
    var changed_metadata_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const changed = try relay_one.beginMetadataSnapshot(
        .init(2, &author_secret, &changed_metadata_buffer),
        &.{ .name = "Pizza Lovers Updated" },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        first.event_json,
        arena.allocator(),
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one:444",
        first.event_json,
        arena.allocator(),
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        changed.event_json,
        arena.allocator(),
    );

    var storage = noztr_sdk.client.GroupFleetClientStorage{};
    const runtime = try groups.inspectRuntime(&storage, "wss://relay.one:444");
    try std.testing.expectEqual(@as(u8, 1), runtime.reconcile_count);
    const consistency = try groups.inspectConsistency(&storage, "wss://relay.one:444");
    try std.testing.expectEqual(@as(usize, 1), consistency.divergent_relays.len);

    const background = try groups.inspectBackgroundRuntime(&storage, .{
        .baseline_relay_url = "wss://relay.one:444",
    });
    const next_step = background.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetBackgroundAction.reconcile,
        next_step.entry.action,
    );
    try std.testing.expectEqualStrings(
        "wss://relay.one",
        try groups.selectBackgroundRelay(next_step),
    );
}
