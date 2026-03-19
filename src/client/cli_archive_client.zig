const std = @import("std");
const store = @import("../store/mod.zig");
const runtime = @import("../runtime/mod.zig");

pub const CliArchiveClientError = store.EventArchiveError || store.RelayCheckpointArchiveError || runtime.RelayPoolError || runtime.RelayReplayError;

pub const CliArchiveClientConfig = struct {
    relay_checkpoint_scope: []const u8 = "cli",
};

pub const CliArchiveClientStorage = struct {
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const CliArchiveClient = struct {
    config: CliArchiveClientConfig,
    archive: store.EventArchive,
    relay_checkpoints: store.RelayCheckpointArchive,
    relay_pool: runtime.RelayPool,

    pub fn init(
        config: CliArchiveClientConfig,
        client_store: store.ClientStore,
        storage: *CliArchiveClientStorage,
    ) CliArchiveClient {
        storage.* = .{};
        return .{
            .config = config,
            .archive = store.EventArchive.init(client_store),
            .relay_checkpoints = store.RelayCheckpointArchive.init(client_store),
            .relay_pool = runtime.RelayPool.init(&storage.relay_pool),
        };
    }

    pub fn attach(
        config: CliArchiveClientConfig,
        client_store: store.ClientStore,
        storage: *CliArchiveClientStorage,
    ) CliArchiveClient {
        return .{
            .config = config,
            .archive = store.EventArchive.init(client_store),
            .relay_checkpoints = store.RelayCheckpointArchive.init(client_store),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
        };
    }

    pub fn ingestEventJson(
        self: CliArchiveClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) CliArchiveClientError!void {
        return self.archive.ingestEventJson(event_json, scratch);
    }

    pub fn queryEvents(
        self: CliArchiveClient,
        request: *const store.ClientQuery,
        page: *store.EventQueryResultPage,
    ) CliArchiveClientError!void {
        return self.archive.query(request, page);
    }

    pub fn saveCheckpoint(
        self: CliArchiveClient,
        name: []const u8,
        cursor: store.EventCursor,
    ) CliArchiveClientError!void {
        return self.archive.saveCheckpoint(name, cursor);
    }

    pub fn loadCheckpoint(
        self: CliArchiveClient,
        name: []const u8,
    ) CliArchiveClientError!?store.ClientCheckpointRecord {
        return self.archive.loadCheckpoint(name);
    }

    pub fn saveRelayCheckpoint(
        self: CliArchiveClient,
        relay_url_text: []const u8,
        cursor: store.EventCursor,
    ) CliArchiveClientError!void {
        return self.relay_checkpoints.saveRelayCheckpoint(
            self.config.relay_checkpoint_scope,
            relay_url_text,
            cursor,
        );
    }

    pub fn loadRelayCheckpoint(
        self: CliArchiveClient,
        relay_url_text: []const u8,
    ) CliArchiveClientError!?store.ClientCheckpointRecord {
        return self.relay_checkpoints.loadRelayCheckpoint(
            self.config.relay_checkpoint_scope,
            relay_url_text,
        );
    }

    pub fn addRelay(
        self: *CliArchiveClient,
        relay_url_text: []const u8,
    ) CliArchiveClientError!runtime.RelayDescriptor {
        return self.relay_pool.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *CliArchiveClient,
        relay_index: u8,
    ) CliArchiveClientError!void {
        return self.relay_pool.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *CliArchiveClient,
        relay_index: u8,
    ) CliArchiveClientError!void {
        return self.relay_pool.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *CliArchiveClient,
        relay_index: u8,
        challenge: []const u8,
    ) CliArchiveClientError!void {
        return self.relay_pool.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const CliArchiveClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.relay_pool.inspectRuntime(storage);
    }
};

test "cli archive client exposes caller-owned config and storage" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    var storage = CliArchiveClientStorage{};
    const client = CliArchiveClient.init(
        .{ .relay_checkpoint_scope = "tooling" },
        memory_store.asClientStore(),
        &storage,
    );

    try std.testing.expectEqualStrings("tooling", client.config.relay_checkpoint_scope);
    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "cli archive client composes query and checkpoint helpers over the shared store seam" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    var storage = CliArchiveClientStorage{};
    const client = CliArchiveClient.init(.{}, memory_store.asClientStore(), &storage);

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
    var page_storage: [1]store.ClientEventRecord = undefined;
    var page = store.EventQueryResultPage.init(page_storage[0..]);
    try client.queryEvents(&.{
        .authors = authors[0..],
        .limit = 1,
    }, &page);
    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expect(page.next_cursor != null);

    try client.saveCheckpoint("recent", page.next_cursor.?);
    const restored = try client.loadCheckpoint("recent");
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 1), restored.?.cursor.offset);
}

test "cli archive client uses its configured relay checkpoint scope" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    var storage = CliArchiveClientStorage{};
    const client = CliArchiveClient.init(
        .{ .relay_checkpoint_scope = "tooling" },
        memory_store.asClientStore(),
        &storage,
    );

    try client.saveRelayCheckpoint("wss://relay.one", .{ .offset = 7 });
    const restored = try client.loadRelayCheckpoint("wss://relay.one");
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 7), restored.?.cursor.offset);
}

test "cli archive client inspects shared relay runtime over its composed pool" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    var storage = CliArchiveClientStorage{};
    var client = CliArchiveClient.init(.{}, memory_store.asClientStore(), &storage);

    const first = try client.addRelay("wss://relay.one");
    _ = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(first.relay_index);
    try client.noteRelayAuthChallenge(first.relay_index, "challenge-1");

    var plan_storage = runtime.RelayPoolPlanStorage{};
    const plan = client.inspectRelayRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
    try std.testing.expectEqual(runtime.RelayPoolAction.authenticate, plan.nextStep().?.entry.action);
}
