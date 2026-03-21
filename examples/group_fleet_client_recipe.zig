const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Drive one bounded multi-relay groups client above the existing fleet workflow: inspect runtime,
// inspect consistency, inspect one explicit background-runtime step, reconcile one target relay
// from the chosen baseline, persist relay-local checkpoints through one explicit store seam, and
// restore a fresh client from that store without inventing hidden background ownership.
test "recipe: group fleet client inspects runtime reconciles one target relay and restores from store" {
    var source_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var source_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var source_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var source_previous_refs_a: [8][]const u8 = undefined;
    var relay_one = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(source_users_a[0..], source_roles_a[0..], source_user_roles_a[0..]),
            source_previous_refs_a[0..],
        ),
    });

    var source_users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var source_roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var source_user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var source_previous_refs_b: [8][]const u8 = undefined;
    var relay_two = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(source_users_b[0..], source_roles_b[0..], source_user_roles_b[0..]),
            source_previous_refs_b[0..],
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

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        first.event_json,
        arena.allocator(),
    );

    var storage = noztr_sdk.client.GroupFleetClientStorage{};
    const runtime = try groups.inspectRuntime(&storage, "wss://relay.one");
    try std.testing.expectEqual(@as(u8, 1), runtime.reconcile_count);
    const consistency = try groups.inspectConsistency(&storage, "wss://relay.one");
    try std.testing.expectEqual(@as(usize, 1), consistency.divergent_relays.len);

    const background = try groups.inspectBackgroundRuntime(&storage, .{
        .baseline_relay_url = "wss://relay.one",
    });
    const next_step = background.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetBackgroundAction.reconcile,
        next_step.entry.action,
    );
    try std.testing.expectEqualStrings("wss://relay.one:444", try groups.selectBackgroundRelay(next_step));

    var checkpoint_storage = noztr_sdk.client.GroupFleetClientCheckpointStorage{};
    const checkpoint_request = noztr_sdk.client.GroupFleetClientCheckpointRequest.init(10, &author_secret);
    const reconciled = try groups.reconcileRelayFromBaseline(
        &checkpoint_storage,
        &checkpoint_request,
        "wss://relay.one",
        "wss://relay.one:444",
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", reconciled.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", reconciled.target_relay_url);
    try std.testing.expectEqualStrings("Pizza Lovers", relay_two.view().metadata.name.?);

    var records: [2]noztr_sdk.workflows.GroupFleetCheckpointRecord =
        [_]noztr_sdk.workflows.GroupFleetCheckpointRecord{.{}, .{}};
    var memory_store = noztr_sdk.workflows.MemoryGroupFleetCheckpointStore.init(records[0..]);
    const persisted = try groups.persistCheckpointStore(
        &checkpoint_storage,
        &checkpoint_request,
        memory_store.asStore(),
    );
    try std.testing.expectEqual(@as(u8, 2), persisted.stored_relays);

    var restored_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var restored_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var restored_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var restored_previous_refs_a: [8][]const u8 = undefined;
    var restored_one = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(restored_users_a[0..], restored_roles_a[0..], restored_user_roles_a[0..]),
            restored_previous_refs_a[0..],
        ),
    });

    var restored_users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var restored_roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var restored_user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var restored_previous_refs_b: [8][]const u8 = undefined;
    var restored_two = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(restored_users_b[0..], restored_roles_b[0..], restored_user_roles_b[0..]),
            restored_previous_refs_b[0..],
        ),
    });

    var restored_members = [_]*noztr_sdk.workflows.GroupClient{ &restored_one, &restored_two };
    const restored_fleet = try noztr_sdk.workflows.GroupFleet.init(restored_members[0..]);
    var restored_groups = noztr_sdk.client.GroupFleetClient.init(.{}, restored_fleet);
    const restored = try restored_groups.restoreCheckpointStore(memory_store.asStore(), arena.allocator());
    try std.testing.expectEqual(@as(u8, 2), restored.restored_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", restored_one.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", restored_two.view().metadata.name.?);
}

// Drive one bounded merge-focused groups client path above the existing fleet workflow: build one
// merged checkpoint from explicit relay selection, surface one merge-apply background step, and
// apply that merged checkpoint explicitly without inventing hidden background ownership.
test "recipe: group fleet client builds and applies one merged checkpoint" {
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
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var metadata_buffer_one = noztr_sdk.workflows.GroupOutboundBuffer{};
    const metadata_one = try relay_one.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer_one),
        &.{ .name = "Pizza Lovers" },
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        metadata_one.event_json,
        arena.allocator(),
    );

    var members_buffer_one = noztr_sdk.workflows.GroupOutboundBuffer{};
    const members_one = try relay_one.beginMembersSnapshot(
        .init(2, &author_secret, &members_buffer_one),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "alpha",
                },
            },
        },
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        members_one.event_json,
        arena.allocator(),
    );

    var metadata_buffer_two = noztr_sdk.workflows.GroupOutboundBuffer{};
    const metadata_two = try relay_two.beginMetadataSnapshot(
        .init(3, &author_secret, &metadata_buffer_two),
        &.{ .name = "Pizza Lovers Relay Two" },
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one:444",
        metadata_two.event_json,
        arena.allocator(),
    );

    var members_buffer_two = noztr_sdk.workflows.GroupOutboundBuffer{};
    const members_two = try relay_two.beginMembersSnapshot(
        .init(4, &author_secret, &members_buffer_two),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xbb} ** 32,
                    .label = "beta",
                },
                .{
                    .pubkey = [_]u8{0xcc} ** 32,
                    .label = "gamma",
                },
            },
        },
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one:444",
        members_two.event_json,
        arena.allocator(),
    );

    var merge_storage = noztr_sdk.client.GroupFleetClientMergeStorage{};
    const merge_request = noztr_sdk.client.GroupFleetClientMergeRequest.init(20, &author_secret);
    const merged = try groups.buildMergedCheckpoint(
        &merge_storage,
        &merge_request,
        &.{
            .baseline_relay_url = "wss://relay.one",
            .members_relay_url = "wss://relay.one:444",
        },
    );

    var storage = noztr_sdk.client.GroupFleetClientStorage{};
    const background = try groups.inspectBackgroundRuntime(&storage, .{
        .baseline_relay_url = "wss://relay.one",
        .pending_merged_checkpoint = &merged,
    });
    const next_step = background.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetBackgroundAction.merge_apply,
        next_step.entry.action,
    );
    try std.testing.expectEqualStrings("wss://relay.one", try groups.selectBackgroundRelay(next_step));

    const applied = try groups.applyMergedCheckpointToAll(&merged, arena.allocator());
    try std.testing.expectEqual(@as(u8, 2), applied.applied_relays);
    try std.testing.expectEqualStrings("wss://relay.one:444", applied.members_source_relay_url);
    try std.testing.expectEqualStrings("Pizza Lovers", relay_one.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", relay_two.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 2), relay_one.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), relay_two.view().users.len);
}
