const std = @import("std");
const noztr = @import("noztr");
const relay_pool = @import("../relay/pool.zig");
const workflows = @import("../workflows/mod.zig");

pub const GroupFleetClientError = workflows.GroupFleetError;

pub const GroupFleetClientConfig = struct {};

pub const GroupFleetClientBackgroundRequest = struct {
    baseline_relay_url: ?[]const u8 = null,
    pending_merged_checkpoint: ?*const workflows.GroupFleetMergedCheckpoint = null,
    publish_events: []const workflows.GroupOutboundEvent = &.{},
};

pub const GroupFleetClientCheckpointStorage = workflows.GroupFleetCheckpointStorage;

pub const GroupFleetClientCheckpointRequest = struct {
    created_at_base: u64,
    created_at_stride: u32 = 10,
    author_secret_key: [32]u8,

    pub fn init(
        created_at_base: u64,
        author_secret_key: *const [32]u8,
    ) GroupFleetClientCheckpointRequest {
        return .{
            .created_at_base = created_at_base,
            .author_secret_key = author_secret_key.*,
        };
    }

    fn checkpointContext(
        self: *const GroupFleetClientCheckpointRequest,
        storage: *GroupFleetClientCheckpointStorage,
    ) workflows.GroupFleetCheckpointContext {
        return .{
            .created_at_base = self.created_at_base,
            .created_at_stride = self.created_at_stride,
            .author_secret_key = self.author_secret_key,
            .storage = storage,
        };
    }
};

pub const GroupFleetClientMergeSelection = workflows.GroupFleetMergeSelection;
pub const GroupFleetClientMergeStorage = workflows.GroupFleetMergeStorage;

pub const GroupFleetClientMergeRequest = struct {
    created_at_base: u64,
    author_secret_key: [32]u8,

    pub fn init(
        created_at_base: u64,
        author_secret_key: *const [32]u8,
    ) GroupFleetClientMergeRequest {
        return .{
            .created_at_base = created_at_base,
            .author_secret_key = author_secret_key.*,
        };
    }

    fn mergeContext(
        self: *const GroupFleetClientMergeRequest,
        storage: *GroupFleetClientMergeStorage,
    ) workflows.GroupFleetMergeContext {
        return .{
            .created_at_base = self.created_at_base,
            .author_secret_key = self.author_secret_key,
            .storage = storage,
        };
    }
};

pub const GroupFleetClientStorage = struct {
    runtime: workflows.GroupFleetRuntimeStorage = .{},
    background: workflows.GroupFleetBackgroundRuntimeStorage = .{},
    divergences: [relay_pool.pool_capacity]workflows.GroupFleetRelayDivergence =
        [_]workflows.GroupFleetRelayDivergence{.{ .relay_url = "" }} ** relay_pool.pool_capacity,
};

pub const GroupFleetClient = struct {
    config: GroupFleetClientConfig,
    fleet: workflows.GroupFleet,

    pub fn init(
        config: GroupFleetClientConfig,
        fleet: workflows.GroupFleet,
    ) GroupFleetClient {
        return .{
            .config = config,
            .fleet = fleet,
        };
    }

    pub fn groupReference(self: *const GroupFleetClient) @TypeOf(self.fleet.groupReference()) {
        return self.fleet.groupReference();
    }

    pub fn relayCount(self: *const GroupFleetClient) usize {
        return self.fleet.relayCount();
    }

    pub fn relayStatuses(
        self: *const GroupFleetClient,
        out: []workflows.GroupFleetRelayStatus,
    ) []const workflows.GroupFleetRelayStatus {
        return self.fleet.relayStatuses(out);
    }

    pub fn inspectRuntime(
        self: *const GroupFleetClient,
        storage: *GroupFleetClientStorage,
        baseline_relay_url: ?[]const u8,
    ) GroupFleetClientError!workflows.GroupFleetRuntimePlan {
        return self.fleet.inspectRuntime(baseline_relay_url, &storage.runtime);
    }

    pub fn inspectConsistency(
        self: *const GroupFleetClient,
        storage: *GroupFleetClientStorage,
        baseline_relay_url: ?[]const u8,
    ) GroupFleetClientError!workflows.GroupFleetConsistencyReport {
        const max_divergences = if (self.relayCount() == 0) 0 else self.relayCount() - 1;
        return self.fleet.inspectConsistency(
            baseline_relay_url,
            storage.divergences[0..max_divergences],
        );
    }

    pub fn inspectBackgroundRuntime(
        self: *const GroupFleetClient,
        storage: *GroupFleetClientStorage,
        request: GroupFleetClientBackgroundRequest,
    ) GroupFleetClientError!workflows.GroupFleetBackgroundRuntimePlan {
        return self.fleet.inspectBackgroundRuntime(.{
            .baseline_relay_url = request.baseline_relay_url,
            .pending_merged_checkpoint = request.pending_merged_checkpoint,
            .publish_events = request.publish_events,
            .storage = &storage.background,
        });
    }

    pub fn selectBackgroundRelay(
        self: *GroupFleetClient,
        step: workflows.GroupFleetBackgroundRuntimeStep,
    ) GroupFleetClientError![]const u8 {
        return self.fleet.selectBackgroundRelay(step);
    }

    pub fn consumeRelayEventJson(
        self: *GroupFleetClient,
        relay_url_text: []const u8,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupFleetClientError!workflows.GroupFleetEventOutcome {
        return self.fleet.consumeRelayEventJson(relay_url_text, event_json, scratch);
    }

    pub fn consumeRelayEventJsons(
        self: *GroupFleetClient,
        relay_url_text: []const u8,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupFleetClientError!workflows.GroupFleetBatchOutcome {
        return self.fleet.consumeRelayEventJsons(relay_url_text, event_jsons, scratch);
    }

    pub fn consumeRelayEvent(
        self: *GroupFleetClient,
        relay_url_text: []const u8,
        event: *const noztr.nip01_event.Event,
    ) GroupFleetClientError!workflows.GroupFleetEventOutcome {
        return self.fleet.consumeRelayEvent(relay_url_text, event);
    }

    pub fn persistCheckpointStore(
        self: *GroupFleetClient,
        checkpoint_storage: *GroupFleetClientCheckpointStorage,
        request: *const GroupFleetClientCheckpointRequest,
        store: workflows.GroupFleetCheckpointStore,
    ) (GroupFleetClientError || workflows.GroupFleetCheckpointStoreError)!workflows.GroupFleetStorePersistOutcome {
        var context = request.checkpointContext(checkpoint_storage);
        return self.fleet.persistCheckpointStore(store, &context);
    }

    pub fn restoreCheckpointStore(
        self: *GroupFleetClient,
        store: workflows.GroupFleetCheckpointStore,
        scratch: std.mem.Allocator,
    ) (GroupFleetClientError || workflows.GroupFleetCheckpointStoreError)!workflows.GroupFleetStoreRestoreOutcome {
        return self.fleet.restoreCheckpointStore(store, scratch);
    }

    pub fn reconcileRelayFromBaseline(
        self: *GroupFleetClient,
        checkpoint_storage: *GroupFleetClientCheckpointStorage,
        request: *const GroupFleetClientCheckpointRequest,
        baseline_relay_url: ?[]const u8,
        target_relay_url: []const u8,
        scratch: std.mem.Allocator,
    ) GroupFleetClientError!workflows.GroupFleetTargetReconcileOutcome {
        var context = request.checkpointContext(checkpoint_storage);
        return self.fleet.reconcileRelayFromBaseline(
            baseline_relay_url,
            target_relay_url,
            &context,
            scratch,
        );
    }

    pub fn buildMergedCheckpoint(
        self: *GroupFleetClient,
        merge_storage: *GroupFleetClientMergeStorage,
        request: *const GroupFleetClientMergeRequest,
        selection: *const GroupFleetClientMergeSelection,
    ) GroupFleetClientError!workflows.GroupFleetMergedCheckpoint {
        var context = request.mergeContext(merge_storage);
        return self.fleet.buildMergedCheckpoint(selection, &context);
    }

    pub fn applyMergedCheckpointToAll(
        self: *GroupFleetClient,
        merged_checkpoint: *const workflows.GroupFleetMergedCheckpoint,
        scratch: std.mem.Allocator,
    ) GroupFleetClientError!workflows.GroupFleetMergeApplyOutcome {
        return self.fleet.applyMergedCheckpointToAll(merged_checkpoint, scratch);
    }
};

test "group fleet client composes runtime consistency and background inspection over caller-owned storage" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var client_a = try workflows.GroupClient.init(.{
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
    var client_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });
    client_a.markCurrentRelayConnected();
    client_b.markCurrentRelayConnected();

    var fleet_clients = [_]*workflows.GroupClient{ &client_a, &client_b };
    const fleet = try workflows.GroupFleet.init(fleet_clients[0..]);
    var groups = GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = workflows.GroupOutboundBuffer{};
    const first = try client_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try groups.consumeRelayEventJson("wss://relay.one", first.event_json, arena.allocator());
    _ = try groups.consumeRelayEventJson("wss://relay.one:444", first.event_json, arena.allocator());

    var changed_buffer = workflows.GroupOutboundBuffer{};
    const changed = try client_a.beginMetadataSnapshot(
        .init(2, &author_secret, &changed_buffer),
        &.{ .name = "Updated Pizza Lovers" },
    );
    _ = try groups.consumeRelayEventJson("wss://relay.one", changed.event_json, arena.allocator());

    var storage = GroupFleetClientStorage{};
    const runtime = try groups.inspectRuntime(&storage, "wss://relay.one:444");
    try std.testing.expectEqual(@as(u8, 1), runtime.reconcile_count);
    try std.testing.expectEqual(
        workflows.GroupFleetRuntimeAction.reconcile,
        runtime.nextStep().?.entry.action,
    );

    const consistency = try groups.inspectConsistency(&storage, "wss://relay.one:444");
    try std.testing.expectEqual(@as(usize, 1), consistency.divergent_relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", consistency.nextStep().?.entry.relay_url);

    const background = try groups.inspectBackgroundRuntime(&storage, .{
        .baseline_relay_url = "wss://relay.one:444",
    });
    try std.testing.expectEqual(@as(u8, 1), background.reconcile_count);
    const next_background = background.nextStep().?;
    try std.testing.expectEqual(
        workflows.GroupFleetBackgroundAction.reconcile,
        next_background.entry.action,
    );
    try std.testing.expectEqualStrings(
        "wss://relay.one",
        try groups.selectBackgroundRelay(next_background),
    );
}

test "group fleet client reports relay statuses and routes batch intake through the fleet" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var client_a = try workflows.GroupClient.init(.{
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
    var client_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });
    client_a.markCurrentRelayConnected();

    var fleet_clients = [_]*workflows.GroupClient{ &client_a, &client_b };
    const fleet = try workflows.GroupFleet.init(fleet_clients[0..]);
    var groups = GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = workflows.GroupOutboundBuffer{};
    var roles_buffer = workflows.GroupOutboundBuffer{};
    const metadata = try client_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );
    const role = try client_a.beginRolesSnapshot(
        .init(2, &author_secret, &roles_buffer),
        &.{
            .roles = &.{
                .{
                    .name = "moderator",
                    .description = "Can moderate",
                },
            },
        },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const batch = try groups.consumeRelayEventJsons(
        "wss://relay.one",
        &.{ metadata.event_json, role.event_json },
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 2), batch.summary.total);
    try std.testing.expectEqual(@as(usize, 2), batch.summary.state_events);

    var statuses: [2]workflows.GroupFleetRelayStatus = undefined;
    const relay_statuses = groups.relayStatuses(statuses[0..]);
    try std.testing.expectEqual(@as(usize, 2), relay_statuses.len);
    try std.testing.expectEqualStrings("wss://relay.one", relay_statuses[0].relay_url);
    try std.testing.expect(relay_statuses[0].relay_ready);
    try std.testing.expectEqualStrings("wss://relay.one:444", relay_statuses[1].relay_url);
    try std.testing.expect(!relay_statuses[1].relay_ready);
}

test "group fleet client composes checkpoint-store persistence and restore through caller-owned storage" {
    var source_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var source_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var source_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var source_previous_refs_a: [8][]const u8 = undefined;
    var source_a = try workflows.GroupClient.init(.{
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
    var source_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(source_users_b[0..], source_roles_b[0..], source_user_roles_b[0..]),
            source_previous_refs_b[0..],
        ),
    });
    source_b.markCurrentRelayConnected();

    var source_members = [_]*workflows.GroupClient{ &source_a, &source_b };
    const source_fleet = try workflows.GroupFleet.init(source_members[0..]);
    var source_groups = GroupFleetClient.init(.{}, source_fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = workflows.GroupOutboundBuffer{};
    var role_buffer = workflows.GroupOutboundBuffer{};
    var member_buffer = workflows.GroupOutboundBuffer{};
    const metadata = try source_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );
    const roles = try source_a.beginRolesSnapshot(
        .init(2, &author_secret, &role_buffer),
        &.{
            .roles = &.{
                .{
                    .name = "moderator",
                    .description = "Can moderate",
                },
            },
        },
    );
    const members = try source_a.beginMembersSnapshot(
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

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try source_groups.consumeRelayEventJsons(
        "wss://relay.one",
        &.{ metadata.event_json, roles.event_json, members.event_json },
        arena.allocator(),
    );
    _ = try source_groups.consumeRelayEventJsons(
        "wss://relay.one:444",
        &.{ metadata.event_json, roles.event_json, members.event_json },
        arena.allocator(),
    );

    var previous_refs: [1][]const u8 = undefined;
    const selected = source_b.selectPreviousRefs(null, previous_refs[0..]);
    var put_user_buffer = workflows.GroupOutboundBuffer{};
    const put_user = try source_b.beginPutUser(
        .init(4, &author_secret, &put_user_buffer),
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote relay two user",
            .previous_refs = selected,
        },
    );
    _ = try source_groups.consumeRelayEventJson(
        "wss://relay.one:444",
        put_user.event_json,
        arena.allocator(),
    );

    var source_checkpoint_storage = GroupFleetClientCheckpointStorage{};
    const checkpoint_request = GroupFleetClientCheckpointRequest.init(10, &author_secret);
    var records: [2]workflows.GroupFleetCheckpointRecord =
        [_]workflows.GroupFleetCheckpointRecord{.{}, .{}};
    var memory_store = workflows.MemoryGroupFleetCheckpointStore.init(records[0..]);
    const persisted = try source_groups.persistCheckpointStore(
        &source_checkpoint_storage,
        &checkpoint_request,
        memory_store.asStore(),
    );
    try std.testing.expectEqual(@as(u8, 2), persisted.stored_relays);

    var target_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var target_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var target_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var target_previous_refs_a: [8][]const u8 = undefined;
    var target_a = try workflows.GroupClient.init(.{
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
    var target_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(target_users_b[0..], target_roles_b[0..], target_user_roles_b[0..]),
            target_previous_refs_b[0..],
        ),
    });

    var target_members = [_]*workflows.GroupClient{ &target_a, &target_b };
    const target_fleet = try workflows.GroupFleet.init(target_members[0..]);
    var target_groups = GroupFleetClient.init(.{}, target_fleet);

    const restored = try target_groups.restoreCheckpointStore(memory_store.asStore(), arena.allocator());
    try std.testing.expectEqual(@as(u8, 2), restored.restored_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", target_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", target_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), target_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), target_b.view().users.len);
}

test "group fleet client composes targeted reconcile from an explicit baseline relay" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var baseline = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users_a[0..], roles_a[0..], user_roles_a[0..]),
            previous_refs_a[0..],
        ),
    });
    baseline.markCurrentRelayConnected();

    var users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var target = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });
    target.markCurrentRelayConnected();

    var fleet_clients = [_]*workflows.GroupClient{ &baseline, &target };
    const fleet = try workflows.GroupFleet.init(fleet_clients[0..]);
    var groups = GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = workflows.GroupOutboundBuffer{};
    const first = try baseline.beginMetadataSnapshot(
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

    var storage = GroupFleetClientStorage{};
    const before = try groups.inspectRuntime(&storage, "wss://relay.one");
    try std.testing.expectEqual(@as(u8, 1), before.reconcile_count);
    try std.testing.expectEqual(workflows.GroupFleetRuntimeAction.reconcile, before.entry(1).?.action);

    var checkpoint_storage = GroupFleetClientCheckpointStorage{};
    const checkpoint_request = GroupFleetClientCheckpointRequest.init(20, &author_secret);
    const reconciled = try groups.reconcileRelayFromBaseline(
        &checkpoint_storage,
        &checkpoint_request,
        "wss://relay.one",
        "wss://relay.one:444",
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", reconciled.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", reconciled.target_relay_url);
    try std.testing.expectEqualStrings("Pizza Lovers", target.view().metadata.name.?);

    const after = try groups.inspectRuntime(&storage, "wss://relay.one");
    try std.testing.expectEqual(@as(u8, 0), after.reconcile_count);
    try std.testing.expectEqual(@as(u8, 2), after.ready_count);
    try std.testing.expectEqual(workflows.GroupFleetRuntimeAction.ready, after.entry(0).?.action);
    try std.testing.expectEqual(workflows.GroupFleetRuntimeAction.ready, after.entry(1).?.action);
}

test "group fleet client propagates targeted reconcile errors for invalid relay choices" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var baseline = try workflows.GroupClient.init(.{
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
    var target = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });

    var fleet_clients = [_]*workflows.GroupClient{ &baseline, &target };
    const fleet = try workflows.GroupFleet.init(fleet_clients[0..]);
    var groups = GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var checkpoint_storage = GroupFleetClientCheckpointStorage{};
    const checkpoint_request = GroupFleetClientCheckpointRequest.init(20, &author_secret);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.UnknownRelayUrl,
        groups.reconcileRelayFromBaseline(
            &checkpoint_storage,
            &checkpoint_request,
            "wss://relay.one",
            "wss://missing",
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.CannotReconcileBaselineRelay,
        groups.reconcileRelayFromBaseline(
            &checkpoint_storage,
            &checkpoint_request,
            "wss://relay.one",
            "wss://relay.one",
            arena.allocator(),
        ),
    );
}

test "group fleet client propagates store full and missing-relay checkpoint-store outcomes" {
    var source_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var source_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var source_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var source_previous_refs_a: [8][]const u8 = undefined;
    var source_a = try workflows.GroupClient.init(.{
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
    var source_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(source_users_b[0..], source_roles_b[0..], source_user_roles_b[0..]),
            source_previous_refs_b[0..],
        ),
    });
    source_b.markCurrentRelayConnected();

    var source_members = [_]*workflows.GroupClient{ &source_a, &source_b };
    const source_fleet = try workflows.GroupFleet.init(source_members[0..]);
    var source_groups = GroupFleetClient.init(.{}, source_fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer = workflows.GroupOutboundBuffer{};
    const metadata = try source_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer),
        &.{ .name = "Pizza Lovers" },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try source_groups.consumeRelayEventJson(
        "wss://relay.one",
        metadata.event_json,
        arena.allocator(),
    );
    _ = try source_groups.consumeRelayEventJson(
        "wss://relay.one:444",
        metadata.event_json,
        arena.allocator(),
    );

    var checkpoint_storage = GroupFleetClientCheckpointStorage{};
    const checkpoint_request = GroupFleetClientCheckpointRequest.init(30, &author_secret);
    var short_records: [1]workflows.GroupFleetCheckpointRecord = [_]workflows.GroupFleetCheckpointRecord{.{}} ** 1;
    var short_store = workflows.MemoryGroupFleetCheckpointStore.init(short_records[0..]);
    try std.testing.expectError(
        error.StoreFull,
        source_groups.persistCheckpointStore(
            &checkpoint_storage,
            &checkpoint_request,
            short_store.asStore(),
        ),
    );

    var full_records: [2]workflows.GroupFleetCheckpointRecord = [_]workflows.GroupFleetCheckpointRecord{.{}, .{}};
    var full_store = workflows.MemoryGroupFleetCheckpointStore.init(full_records[0..]);
    _ = try source_groups.persistCheckpointStore(
        &checkpoint_storage,
        &checkpoint_request,
        full_store.asStore(),
    );

    var target_users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var target_roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var target_user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var target_previous_refs_a: [8][]const u8 = undefined;
    var target_a = try workflows.GroupClient.init(.{
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
    var target_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(target_users_b[0..], target_roles_b[0..], target_user_roles_b[0..]),
            target_previous_refs_b[0..],
        ),
    });

    var target_members = [_]*workflows.GroupClient{ &target_a, &target_b };
    const target_fleet = try workflows.GroupFleet.init(target_members[0..]);
    var target_groups = GroupFleetClient.init(.{}, target_fleet);

    var one_records: [1]workflows.GroupFleetCheckpointRecord = [_]workflows.GroupFleetCheckpointRecord{.{}} ** 1;
    var one_store = workflows.MemoryGroupFleetCheckpointStore.init(one_records[0..]);
    var checkpoint_buffers = workflows.GroupCheckpointBuffers{};
    const source_checkpoint = try source_a.exportCheckpoint(
        workflows.GroupCheckpointContext.init(40, &author_secret, &checkpoint_buffers),
    );
    _ = try one_store.putCheckpoint(&source_checkpoint);

    const restored = try target_groups.restoreCheckpointStore(one_store.asStore(), arena.allocator());
    try std.testing.expectEqual(@as(u8, 1), restored.restored_relays);
    try std.testing.expectEqual(@as(u8, 1), restored.missing_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", target_a.view().metadata.name.?);
}

test "group fleet client composes merged checkpoint build and apply from explicit relay selection" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var client_a = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users_a[0..], roles_a[0..], user_roles_a[0..]),
            previous_refs_a[0..],
        ),
    });
    client_a.markCurrentRelayConnected();

    var users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var client_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });
    client_b.markCurrentRelayConnected();

    var fleet_clients = [_]*workflows.GroupClient{ &client_a, &client_b };
    const fleet = try workflows.GroupFleet.init(fleet_clients[0..]);
    var groups = GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var metadata_buffer_a = workflows.GroupOutboundBuffer{};
    const metadata_event_a = try client_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer_a),
        &.{ .name = "Pizza Lovers" },
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        metadata_event_a.event_json,
        arena.allocator(),
    );

    var members_buffer_a = workflows.GroupOutboundBuffer{};
    const members_event_a = try client_a.beginMembersSnapshot(
        .init(2, &author_secret, &members_buffer_a),
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
        members_event_a.event_json,
        arena.allocator(),
    );

    var metadata_buffer_b = workflows.GroupOutboundBuffer{};
    const metadata_event_b = try client_b.beginMetadataSnapshot(
        .init(3, &author_secret, &metadata_buffer_b),
        &.{ .name = "Pizza Lovers Relay Two" },
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one:444",
        metadata_event_b.event_json,
        arena.allocator(),
    );

    var members_buffer_b = workflows.GroupOutboundBuffer{};
    const members_event_b = try client_b.beginMembersSnapshot(
        .init(4, &author_secret, &members_buffer_b),
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
        members_event_b.event_json,
        arena.allocator(),
    );

    var merge_storage = GroupFleetClientMergeStorage{};
    const merge_request = GroupFleetClientMergeRequest.init(20, &author_secret);
    const merged = try groups.buildMergedCheckpoint(
        &merge_storage,
        &merge_request,
        &.{
            .baseline_relay_url = "wss://relay.one",
            .members_relay_url = "wss://relay.one:444",
        },
    );
    try std.testing.expectEqualStrings("wss://relay.one", merged.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", merged.metadata_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", merged.admins_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.members_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", merged.roles_source_relay_url);

    const applied = try groups.applyMergedCheckpointToAll(&merged, arena.allocator());
    try std.testing.expectEqual(@as(u8, 2), applied.applied_relays);
    try std.testing.expectEqualStrings("wss://relay.one:444", applied.members_source_relay_url);
    try std.testing.expectEqualStrings("Pizza Lovers", client_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", client_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 2), client_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), client_b.view().users.len);
}

test "group fleet client merge composition falls back to baseline and rejects unknown relay urls" {
    var users_a: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_a: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_a: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_a: [8][]const u8 = undefined;
    var client_a = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = .init(
            .init(users_a[0..], roles_a[0..], user_roles_a[0..]),
            previous_refs_a[0..],
        ),
    });
    client_a.markCurrentRelayConnected();

    var users_b: [2]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles_b: [1]noztr.nip29_relay_groups.GroupRole = undefined;
    var user_roles_b: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 =
        undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var client_b = try workflows.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = .init(
            .init(users_b[0..], roles_b[0..], user_roles_b[0..]),
            previous_refs_b[0..],
        ),
    });
    client_b.markCurrentRelayConnected();

    var fleet_clients = [_]*workflows.GroupClient{ &client_a, &client_b };
    const fleet = try workflows.GroupFleet.init(fleet_clients[0..]);
    var groups = GroupFleetClient.init(.{}, fleet);

    const author_secret = [_]u8{0x09} ** 32;
    var metadata_buffer_a = workflows.GroupOutboundBuffer{};
    const metadata_event_a = try client_a.beginMetadataSnapshot(
        .init(1, &author_secret, &metadata_buffer_a),
        &.{ .name = "Pizza Lovers" },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one",
        metadata_event_a.event_json,
        arena.allocator(),
    );
    _ = try groups.consumeRelayEventJson(
        "wss://relay.one:444",
        metadata_event_a.event_json,
        arena.allocator(),
    );

    var merge_storage = GroupFleetClientMergeStorage{};
    const merge_request = GroupFleetClientMergeRequest.init(40, &author_secret);
    const merged = try groups.buildMergedCheckpoint(
        &merge_storage,
        &merge_request,
        &.{ .baseline_relay_url = "wss://relay.one:444" },
    );
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.metadata_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.admins_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.members_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.roles_source_relay_url);

    try std.testing.expectError(
        error.UnknownRelayUrl,
        groups.buildMergedCheckpoint(
            &merge_storage,
            &merge_request,
            &.{ .members_relay_url = "wss://relay.unknown" },
        ),
    );
}
