const std = @import("std");
const local_state = @import("local_state_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const RelayWorkspaceClientError = local_state.LocalStateClientError;

pub const RelayWorkspaceClientConfig = struct {
    local_state: local_state.LocalStateClientConfig = .{},
};

pub const RelayWorkspaceClientStorage = struct {
    local_state: local_state.LocalStateClientStorage = .{},
};

pub const RelayWorkspaceRestoreResult = local_state.LocalStateRestoreResult;

pub const RelayWorkspaceClient = struct {
    config: RelayWorkspaceClientConfig,
    local_state: local_state.LocalStateClient,

    pub fn init(
        config: RelayWorkspaceClientConfig,
        client_store: store.ClientStore,
        relay_info_store: store.RelayInfoStore,
        storage: *RelayWorkspaceClientStorage,
    ) RelayWorkspaceClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_state = local_state.LocalStateClient.init(
                config.local_state,
                client_store,
                relay_info_store,
                &storage.local_state,
            ),
        };
    }

    pub fn attach(
        config: RelayWorkspaceClientConfig,
        client_store: store.ClientStore,
        relay_info_store: store.RelayInfoStore,
        storage: *RelayWorkspaceClientStorage,
    ) RelayWorkspaceClient {
        return .{
            .config = config,
            .local_state = local_state.LocalStateClient.attach(
                config.local_state,
                client_store,
                relay_info_store,
                &storage.local_state,
            ),
        };
    }

    pub fn rememberRelay(
        self: RelayWorkspaceClient,
        relay_url_text: []const u8,
    ) RelayWorkspaceClientError!store.RelayInfoRecord {
        return self.local_state.rememberRelay(relay_url_text);
    }

    pub fn loadRememberedRelay(
        self: RelayWorkspaceClient,
        relay_url_text: []const u8,
    ) RelayWorkspaceClientError!?store.RelayInfoRecord {
        return self.local_state.loadRememberedRelay(relay_url_text);
    }

    pub fn listRememberedRelays(
        self: RelayWorkspaceClient,
        page: *store.RelayInfoResultPage,
    ) RelayWorkspaceClientError!void {
        return self.local_state.listRememberedRelays(page);
    }

    pub fn restoreRememberedRelays(
        self: *RelayWorkspaceClient,
        page: *store.RelayInfoResultPage,
        checkpoint_storage: *runtime.RelayPoolCheckpointStorage,
    ) RelayWorkspaceClientError!RelayWorkspaceRestoreResult {
        return self.local_state.restoreRememberedRelays(page, checkpoint_storage);
    }

    pub fn markRelayConnected(
        self: *RelayWorkspaceClient,
        relay_index: u8,
    ) RelayWorkspaceClientError!void {
        return self.local_state.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayWorkspaceClient,
        relay_index: u8,
    ) RelayWorkspaceClientError!void {
        return self.local_state.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayWorkspaceClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayWorkspaceClientError!void {
        return self.local_state.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const RelayWorkspaceClient,
        storage_: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.local_state.inspectRelayRuntime(storage_);
    }

    pub fn saveRelayCheckpoint(
        self: RelayWorkspaceClient,
        relay_url_text: []const u8,
        cursor: store.EventCursor,
    ) RelayWorkspaceClientError!void {
        return self.local_state.saveRelayCheckpoint(relay_url_text, cursor);
    }

    pub fn loadRelayCheckpoint(
        self: RelayWorkspaceClient,
        relay_url_text: []const u8,
    ) RelayWorkspaceClientError!?store.ClientCheckpointRecord {
        return self.local_state.loadRelayCheckpoint(relay_url_text);
    }

    pub fn inspectReplay(
        self: *const RelayWorkspaceClient,
        specs: []const runtime.RelayReplaySpec,
        storage_: *runtime.RelayPoolReplayStorage,
    ) RelayWorkspaceClientError!runtime.RelayPoolReplayPlan {
        return self.local_state.inspectReplay(specs, storage_);
    }
};

test "relay workspace client exposes caller-owned config and storage" {
    var client_store = store.MemoryClientStore{};
    var relay_info_store = store.MemoryRelayInfoStore{};
    var storage_ = RelayWorkspaceClientStorage{};
    const client = RelayWorkspaceClient.init(
        .{ .local_state = .{ .relay_checkpoint_scope = "tooling" } },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage_,
    );

    try std.testing.expectEqualStrings("tooling", client.config.local_state.relay_checkpoint_scope);
    try std.testing.expectEqual(@as(u8, 0), client.local_state.archive.relay_pool.relayCount());
}

test "relay workspace client remembers relays and restores runtime from remembered state" {
    var client_store = store.MemoryClientStore{};
    var relay_info_store = store.MemoryRelayInfoStore{};
    var storage_ = RelayWorkspaceClientStorage{};
    var client = RelayWorkspaceClient.init(
        .{ .local_state = .{ .relay_checkpoint_scope = "tooling" } },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage_,
    );

    _ = try client.rememberRelay("wss://relay.one");
    _ = try client.rememberRelay("wss://relay.two");
    try client.saveRelayCheckpoint("wss://relay.two", .{ .offset = 9 });

    var page_storage: [2]store.RelayInfoRecord = undefined;
    var page = store.RelayInfoResultPage.init(page_storage[0..]);
    var checkpoint_storage = runtime.RelayPoolCheckpointStorage{};
    const restored = try client.restoreRememberedRelays(&page, &checkpoint_storage);
    try std.testing.expectEqual(@as(u8, 2), restored.relay_count);

    try client.markRelayConnected(0);
    try client.markRelayConnected(1);

    var plan_storage = runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.ready_count);

    const restored_checkpoint = try client.loadRelayCheckpoint("wss://relay.two");
    try std.testing.expect(restored_checkpoint != null);
    try std.testing.expectEqual(@as(u32, 9), restored_checkpoint.?.cursor.offset);

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };
    var replay_storage = runtime.RelayPoolReplayStorage{};
    const replay_plan = try client.inspectReplay(replay_specs[0..], &replay_storage);
    try std.testing.expectEqual(@as(u8, 2), replay_plan.relay_count);
    const next_step = replay_plan.nextStep().?;
    try std.testing.expectEqualStrings("wss://relay.one", next_step.entry.descriptor.relay_url);
    try std.testing.expect(next_step.entry.query.cursor == null);
    try std.testing.expectEqual(@as(u32, 9), replay_plan.entry(1).?.query.cursor.?.offset);
}

test "relay workspace client rejects truncated remembered relay listings before restore" {
    var client_store = store.MemoryClientStore{};
    var relay_info_store = store.MemoryRelayInfoStore{};
    var storage_ = RelayWorkspaceClientStorage{};
    var client = RelayWorkspaceClient.init(
        .{},
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage_,
    );

    _ = try client.rememberRelay("wss://relay.one");
    _ = try client.rememberRelay("wss://relay.two");

    var page_storage: [1]store.RelayInfoRecord = undefined;
    var page = store.RelayInfoResultPage.init(page_storage[0..]);
    var checkpoint_storage = runtime.RelayPoolCheckpointStorage{};
    try std.testing.expectError(
        error.RememberedRelayListTruncated,
        client.restoreRememberedRelays(&page, &checkpoint_storage),
    );
}
