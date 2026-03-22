const std = @import("std");
const cli_archive = @import("cli_archive_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const LocalStateClientError = store.RelayRegistryArchiveError || cli_archive.CliArchiveClientError || runtime.RelayPoolCheckpointError || error{
    RememberedRelayListTruncated,
    TooManyRememberedRelays,
};

pub const LocalStateClientConfig = struct {
    relay_checkpoint_scope: []const u8 = "local_state",
};

pub const LocalStateClientStorage = struct {
    archive: cli_archive.CliArchiveClientStorage = .{},
};

pub const LocalStateRestoreResult = runtime.RelayPoolCheckpointSet;

pub const LocalStateClient = struct {
    config: LocalStateClientConfig,
    registry: store.RelayRegistryArchive,
    archive: cli_archive.CliArchiveClient,

    pub fn init(
        config: LocalStateClientConfig,
        client_store: store.ClientStore,
        relay_info_store: store.RelayInfoStore,
        storage: *LocalStateClientStorage,
    ) LocalStateClient {
        storage.* = .{};
        return .{
            .config = config,
            .registry = store.RelayRegistryArchive.init(relay_info_store),
            .archive = cli_archive.CliArchiveClient.init(
                .{ .relay_checkpoint_scope = config.relay_checkpoint_scope },
                client_store,
                &storage.archive,
            ),
        };
    }

    pub fn attach(
        config: LocalStateClientConfig,
        client_store: store.ClientStore,
        relay_info_store: store.RelayInfoStore,
        storage: *LocalStateClientStorage,
    ) LocalStateClient {
        return .{
            .config = config,
            .registry = store.RelayRegistryArchive.init(relay_info_store),
            .archive = cli_archive.CliArchiveClient.attach(
                .{ .relay_checkpoint_scope = config.relay_checkpoint_scope },
                client_store,
                &storage.archive,
            ),
        };
    }

    pub fn ingestEventJson(
        self: LocalStateClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) LocalStateClientError!void {
        return self.archive.ingestEventJson(event_json, scratch);
    }

    pub fn queryEvents(
        self: LocalStateClient,
        request: *const store.ClientQuery,
        page: *store.EventQueryResultPage,
    ) LocalStateClientError!void {
        return self.archive.queryEvents(request, page);
    }

    pub fn saveCheckpoint(
        self: LocalStateClient,
        name: []const u8,
        cursor: store.EventCursor,
    ) LocalStateClientError!void {
        return self.archive.saveCheckpoint(name, cursor);
    }

    pub fn loadCheckpoint(
        self: LocalStateClient,
        name: []const u8,
    ) LocalStateClientError!?store.ClientCheckpointRecord {
        return self.archive.loadCheckpoint(name);
    }

    pub fn saveRelayCheckpoint(
        self: LocalStateClient,
        relay_url_text: []const u8,
        cursor: store.EventCursor,
    ) LocalStateClientError!void {
        return self.archive.saveRelayCheckpoint(relay_url_text, cursor);
    }

    pub fn loadRelayCheckpoint(
        self: LocalStateClient,
        relay_url_text: []const u8,
    ) LocalStateClientError!?store.ClientCheckpointRecord {
        return self.archive.loadRelayCheckpoint(relay_url_text);
    }

    pub fn rememberRelay(
        self: LocalStateClient,
        relay_url_text: []const u8,
    ) LocalStateClientError!store.RelayInfoRecord {
        return self.registry.rememberRelay(relay_url_text);
    }

    pub fn loadRememberedRelay(
        self: LocalStateClient,
        relay_url_text: []const u8,
    ) LocalStateClientError!?store.RelayInfoRecord {
        return self.registry.loadRelayInfo(relay_url_text);
    }

    pub fn listRememberedRelays(
        self: LocalStateClient,
        page: *store.RelayInfoResultPage,
    ) LocalStateClientError!void {
        return self.registry.listRelayInfo(page);
    }

    pub fn restoreRememberedRelays(
        self: *LocalStateClient,
        page: *store.RelayInfoResultPage,
        checkpoint_storage: *runtime.RelayPoolCheckpointStorage,
    ) LocalStateClientError!LocalStateRestoreResult {
        try self.listRememberedRelays(page);
        if (page.truncated) return error.RememberedRelayListTruncated;
        if (page.count > checkpoint_storage.records.len) return error.TooManyRememberedRelays;

        for (page.slice(), 0..) |record, index| {
            checkpoint_storage.records[index] = .{
                .relay_url_len = record.relay_url_len,
                .cursor = .{},
            };
            @memcpy(
                checkpoint_storage.records[index].relay_url[0..record.relay_url_len],
                record.relay_url[0..record.relay_url_len],
            );
        }

        const checkpoints = runtime.RelayPoolCheckpointSet{
            .records = checkpoint_storage.records[0..page.count],
            .relay_count = @intCast(page.count),
        };
        try self.archive.relay_pool.restoreCheckpoints(&checkpoints);
        return checkpoints;
    }

    pub fn addRelay(
        self: *LocalStateClient,
        relay_url_text: []const u8,
    ) LocalStateClientError!runtime.RelayDescriptor {
        return self.archive.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *LocalStateClient,
        relay_index: u8,
    ) LocalStateClientError!void {
        return self.archive.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LocalStateClient,
        relay_index: u8,
    ) LocalStateClientError!void {
        return self.archive.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *LocalStateClient,
        relay_index: u8,
        challenge: []const u8,
    ) LocalStateClientError!void {
        return self.archive.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const LocalStateClient,
        storage_: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.archive.inspectRelayRuntime(storage_);
    }

    pub fn inspectReplay(
        self: *const LocalStateClient,
        specs: []const runtime.RelayReplaySpec,
        storage_: *runtime.RelayPoolReplayStorage,
    ) LocalStateClientError!runtime.RelayPoolReplayPlan {
        return self.archive.inspectReplay(specs, storage_);
    }
};

test "local state client exposes caller-owned config and storage" {
    var client_store = store.MemoryClientStore{};
    var relay_info_store = store.MemoryRelayInfoStore{};
    var storage_ = LocalStateClientStorage{};
    const client = LocalStateClient.init(
        .{ .relay_checkpoint_scope = "workspace" },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage_,
    );

    try std.testing.expectEqualStrings("workspace", client.config.relay_checkpoint_scope);
    try std.testing.expectEqual(@as(u8, 0), client.archive.relay_pool.relayCount());
}

test "local state client composes archive queries with remembered relay restore" {
    var client_store = store.MemoryClientStore{};
    var relay_info_store = store.MemoryRelayInfoStore{};
    var storage_ = LocalStateClientStorage{};
    var client = LocalStateClient.init(
        .{ .relay_checkpoint_scope = "workspace" },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage_,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const first_json =
        \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":10,"kind":1,"tags":[],"content":"first","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
    ;
    const second_json =
        \\{"id":"2222222222222222222222222222222222222222222222222222222222222222","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":20,"kind":1,"tags":[],"content":"second","sig":"44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"}
    ;
    try client.ingestEventJson(first_json, arena.allocator());
    try client.ingestEventJson(second_json, arena.allocator());

    const authors = [_]store.EventPubkeyHex{
        try store.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    var event_page_storage: [1]store.ClientEventRecord = undefined;
    var event_page = store.EventQueryResultPage.init(event_page_storage[0..]);
    try client.queryEvents(&.{
        .authors = authors[0..],
        .limit = 1,
    }, &event_page);
    try std.testing.expectEqual(@as(usize, 1), event_page.count);
    try std.testing.expect(event_page.next_cursor != null);

    try client.saveCheckpoint("recent", event_page.next_cursor.?);
    const restored_checkpoint = try client.loadCheckpoint("recent");
    try std.testing.expect(restored_checkpoint != null);
    try std.testing.expectEqual(@as(u32, 1), restored_checkpoint.?.cursor.offset);

    _ = try client.rememberRelay("wss://relay.one");
    _ = try client.rememberRelay("wss://relay.two");
    try client.saveRelayCheckpoint("wss://relay.two", .{ .offset = 9 });

    var relay_page_storage: [2]store.RelayInfoRecord = undefined;
    var relay_page = store.RelayInfoResultPage.init(relay_page_storage[0..]);
    var checkpoint_storage = runtime.RelayPoolCheckpointStorage{};
    const restored = try client.restoreRememberedRelays(&relay_page, &checkpoint_storage);
    try std.testing.expectEqual(@as(u8, 2), restored.relay_count);

    const relay_checkpoint = try client.loadRelayCheckpoint("wss://relay.two");
    try std.testing.expect(relay_checkpoint != null);
    try std.testing.expectEqual(@as(u32, 9), relay_checkpoint.?.cursor.offset);
}

test "local state client inspects runtime and replay over restored remembered relays" {
    var client_store = store.MemoryClientStore{};
    var relay_info_store = store.MemoryRelayInfoStore{};
    var storage_ = LocalStateClientStorage{};
    var client = LocalStateClient.init(
        .{ .relay_checkpoint_scope = "workspace" },
        client_store.asClientStore(),
        relay_info_store.asRelayInfoStore(),
        &storage_,
    );

    _ = try client.rememberRelay("wss://relay.one");
    _ = try client.rememberRelay("wss://relay.two");
    try client.saveRelayCheckpoint("wss://relay.two", .{ .offset = 9 });

    var relay_page_storage: [2]store.RelayInfoRecord = undefined;
    var relay_page = store.RelayInfoResultPage.init(relay_page_storage[0..]);
    var checkpoint_storage = runtime.RelayPoolCheckpointStorage{};
    _ = try client.restoreRememberedRelays(&relay_page, &checkpoint_storage);

    try client.markRelayConnected(0);
    try client.markRelayConnected(1);

    var plan_storage = runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.ready_count);

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "workspace",
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
