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
