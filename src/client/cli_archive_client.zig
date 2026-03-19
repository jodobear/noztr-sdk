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
