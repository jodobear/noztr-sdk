const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Persist one explicit multi-relay fleet into a caller-owned checkpoint store, restore that
// relay-local state into a fresh fleet, inspect fleet runtime actions plus one typed next
// runtime step, merge divergent relay-local components by explicit relay selection, run one
// explicit targeted baseline-to-target reconcile step, then select one typed next moderation publish
// relay and build one fanout across the reconciled relays without inventing hidden merge or
// runtime policy.
test "recipe: group fleet persists restores inspects runtime and one typed next step merges targets reconcile and selects one typed next moderation publish step" {
    var source_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var source_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var source_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var source_previous_refs_a: [8][]const u8 = undefined;
    var source_a = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(source_users_a[0..], source_roles_a[0..], source_user_roles_a[0..]),
            source_previous_refs_a[0..],
        ),
    });
    source_a.markCurrentRelayConnected();

    var source_users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var source_roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var source_user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var source_previous_refs_b: [8][]const u8 = undefined;
    var source_b = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(source_users_b[0..], source_roles_b[0..], source_user_roles_b[0..]),
            source_previous_refs_b[0..],
        ),
    });
    source_b.markCurrentRelayConnected();

    var source_clients = [_]*noztr_sdk.workflows.GroupClient{ &source_a, &source_b };
    var source_fleet = try noztr_sdk.workflows.GroupFleet.init(source_clients[0..]);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    var role_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    var member_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const metadata_event = try source_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );
    const role_event = try source_a.beginRolesSnapshot(
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
    const member_event = try source_a.beginMembersSnapshot(
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

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try source_fleet.consumeRelayEventJsons(
        "wss://relay.one",
        snapshot[0..],
        arena.allocator(),
    );
    _ = try source_fleet.consumeRelayEventJsons(
        "wss://relay.one:444",
        snapshot[0..],
        arena.allocator(),
    );

    var previous_refs: [1][]const u8 = undefined;
    const selected = source_b.selectPreviousRefs(null, previous_refs[0..]);
    var put_user_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const put_user = try source_b.beginPutUser(
        .init(4, &author_secret, &put_user_buffer),
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote relay two user",
            .previous_refs = selected,
        },
    );
    _ = try source_fleet.consumeRelayEventJson("wss://relay.one:444", put_user.event_json, arena.allocator());

    var checkpoint_storage = noztr_sdk.workflows.GroupFleetCheckpointStorage{};
    var checkpoint_context = noztr_sdk.workflows.GroupFleetCheckpointContext.init(
        20,
        &author_secret,
        &checkpoint_storage,
    );
    var store_records: [2]noztr_sdk.workflows.GroupFleetCheckpointRecord =
        [_]noztr_sdk.workflows.GroupFleetCheckpointRecord{ .{}, .{} };
    var checkpoint_store = noztr_sdk.workflows.MemoryGroupFleetCheckpointStore.init(store_records[0..]);
    const persisted = try source_fleet.persistCheckpointStore(
        checkpoint_store.asStore(),
        &checkpoint_context,
    );
    try std.testing.expectEqual(@as(u8, 2), persisted.stored_relays);
    try std.testing.expectEqual(@as(u8, 0), persisted.replaced_relays);

    var target_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var target_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var target_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var target_previous_refs_a: [8][]const u8 = undefined;
    var target_a = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(target_users_a[0..], target_roles_a[0..], target_user_roles_a[0..]),
            target_previous_refs_a[0..],
        ),
    });

    var target_users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var target_roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var target_user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var target_previous_refs_b: [8][]const u8 = undefined;
    var target_b = try noztr_sdk.workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(target_users_b[0..], target_roles_b[0..], target_user_roles_b[0..]),
            target_previous_refs_b[0..],
        ),
    });

    var target_clients = [_]*noztr_sdk.workflows.GroupClient{ &target_a, &target_b };
    var target_fleet = try noztr_sdk.workflows.GroupFleet.init(target_clients[0..]);
    const restored = try target_fleet.restoreCheckpointStore(
        checkpoint_store.asStore(),
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u8, 2), restored.restored_relays);
    try std.testing.expectEqual(@as(u8, 0), restored.missing_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", target_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", target_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), target_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), target_b.view().users.len);

    target_a.markCurrentRelayConnected();
    target_b.markCurrentRelayConnected();
    var merge_metadata_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const merged_metadata_event = try target_a.beginMetadataSnapshot(
        .init(30, &author_secret, &merge_metadata_buffer),
        &.{ .name = "Merged Pizza Lovers" },
    );
    _ = try target_fleet.consumeRelayEventJson(
        "wss://relay.one",
        merged_metadata_event.event_json,
        arena.allocator(),
    );

    var runtime_storage = noztr_sdk.workflows.GroupFleetRuntimeStorage{};
    const runtime = try target_fleet.inspectRuntime("wss://relay.one:444", &runtime_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime.relay_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.ready_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.reconcile_count);
    try std.testing.expectEqualStrings("wss://relay.one:444", runtime.baseline_relay_url);
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetRuntimeAction.reconcile,
        runtime.entry(0).?.action,
    );
    try std.testing.expect(runtime.entry(0).?.metadata_divergent);
    const next_runtime = runtime.nextStep().?;
    try std.testing.expectEqualStrings("wss://relay.one:444", next_runtime.baseline_relay_url);
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetRuntimeAction.reconcile,
        next_runtime.entry.action,
    );
    try std.testing.expectEqualStrings("wss://relay.one", next_runtime.entry.relay_url);
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetRuntimeAction.ready,
        runtime.entry(1).?.action,
    );
    try std.testing.expect(runtime.entry(1).?.is_baseline);

    var merge_storage = noztr_sdk.workflows.GroupFleetMergeStorage{};
    var merge_context = noztr_sdk.workflows.GroupFleetMergeContext.init(
        35,
        &author_secret,
        &merge_storage,
    );
    const merged_checkpoint = try target_fleet.buildMergedCheckpoint(
        &.{
            .baseline_relay_url = "wss://relay.one",
            .members_relay_url = "wss://relay.one:444",
        },
        &merge_context,
    );
    try std.testing.expectEqualStrings("wss://relay.one", merged_checkpoint.metadata_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged_checkpoint.members_source_relay_url);
    const merged_apply = try target_fleet.applyMergedCheckpointToAll(
        &merged_checkpoint,
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u8, 2), merged_apply.applied_relays);
    try std.testing.expectEqualStrings("Merged Pizza Lovers", target_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Merged Pizza Lovers", target_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 2), target_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), target_b.view().users.len);

    var targeted_metadata_buffer = noztr_sdk.workflows.GroupOutboundBuffer{};
    const targeted_metadata_event = try target_a.beginMetadataSnapshot(
        .init(40, &author_secret, &targeted_metadata_buffer),
        &.{ .name = "Needs Reconcile Again" },
    );
    _ = try target_fleet.consumeRelayEventJson(
        "wss://relay.one",
        targeted_metadata_event.event_json,
        arena.allocator(),
    );

    const targeted_runtime = try target_fleet.inspectRuntime("wss://relay.one:444", &runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), targeted_runtime.reconcile_count);
    try std.testing.expectEqual(
        noztr_sdk.workflows.GroupFleetRuntimeAction.reconcile,
        targeted_runtime.entry(0).?.action,
    );

    const targeted_reconcile = try target_fleet.reconcileRelayFromBaseline(
        "wss://relay.one:444",
        "wss://relay.one",
        &checkpoint_context,
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one:444", targeted_reconcile.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", targeted_reconcile.target_relay_url);
    try std.testing.expectEqualStrings("Merged Pizza Lovers", target_a.view().metadata.name.?);

    const ready_runtime = try target_fleet.inspectRuntime("wss://relay.one:444", &runtime_storage);
    try std.testing.expectEqual(@as(u8, 0), ready_runtime.reconcile_count);
    try std.testing.expectEqual(@as(u8, 2), ready_runtime.ready_count);

    var publish_buffers: [2]noztr_sdk.workflows.GroupOutboundBuffer = .{ .{}, .{} };
    var previous_refs_a: [8][]const u8 = undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var fanout_previous_refs = [_][][]const u8{
        previous_refs_a[0..],
        previous_refs_b[0..],
    };
    var fanout_events: [2]noztr_sdk.workflows.GroupOutboundEvent = undefined;
    var publish_storage = noztr_sdk.workflows.GroupFleetPublishStorage.init(
        publish_buffers[0..],
        fanout_previous_refs[0..],
        fanout_events[0..],
    );
    var publish_context =
        noztr_sdk.workflows.GroupFleetPublishContext.init(50, &author_secret, &publish_storage);
    const fanout = try target_fleet.beginPutUserForAll(
        &publish_context,
        &.{
            .pubkey = [_]u8{0xcc} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote across relays",
        },
    );
    try std.testing.expectEqual(@as(usize, 2), fanout.len);
    try std.testing.expectEqualStrings("wss://relay.one", fanout[0].relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", fanout[1].relay_url);
    const next_publish = noztr_sdk.workflows.GroupFleet.nextPublishStep(fanout).?;
    try std.testing.expectEqual(@as(usize, 2), next_publish.fanout_count);
    try std.testing.expectEqualStrings("wss://relay.one", next_publish.event.relay_url);
}
