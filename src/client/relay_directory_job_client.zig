const std = @import("std");
const relay_directory = @import("../relay/directory.zig");
const store = @import("../store/mod.zig");
const transport = @import("../transport/mod.zig");

pub const RelayDirectoryJobClientError = relay_directory.DirectoryError;

pub const RelayDirectoryJobClientConfig = struct {};

pub const RelayDirectoryJobClientStorage = struct {
    lookup_url_buffer: []u8,
    response_buffer: []u8,
    parse_scratch: []u8,

    pub fn init(
        lookup_url_buffer: []u8,
        response_buffer: []u8,
        parse_scratch: []u8,
    ) RelayDirectoryJobClientStorage {
        return .{
            .lookup_url_buffer = lookup_url_buffer,
            .response_buffer = response_buffer,
            .parse_scratch = parse_scratch,
        };
    }
};

pub const RelayDirectoryRefreshJob = struct {
    relay_url_text: []const u8,
};

pub const RelayDirectoryRefreshJobResult = store.RelayInfoRecord;

pub const RelayDirectoryJobClient = struct {
    config: RelayDirectoryJobClientConfig,
    registry: store.RelayRegistryArchive,
    directory: relay_directory.RelayDirectory,

    pub fn init(
        config: RelayDirectoryJobClientConfig,
        relay_info_store: store.RelayInfoStore,
    ) RelayDirectoryJobClient {
        return .{
            .config = config,
            .registry = store.RelayRegistryArchive.init(relay_info_store),
            .directory = relay_directory.RelayDirectory.init(relay_info_store),
        };
    }

    pub fn prepareRefreshJob(
        self: *const RelayDirectoryJobClient,
        relay_url_text: []const u8,
    ) RelayDirectoryRefreshJob {
        _ = self;
        return .{ .relay_url_text = relay_url_text };
    }

    pub fn refresh(
        self: *RelayDirectoryJobClient,
        http_client: transport.HttpClient,
        storage: *RelayDirectoryJobClientStorage,
        job: RelayDirectoryRefreshJob,
    ) RelayDirectoryJobClientError!RelayDirectoryRefreshJobResult {
        return self.directory.refresh(
            http_client,
            job.relay_url_text,
            storage.lookup_url_buffer,
            storage.response_buffer,
            storage.parse_scratch,
        );
    }

    pub fn loadRelayInfo(
        self: *const RelayDirectoryJobClient,
        relay_url_text: []const u8,
    ) RelayDirectoryJobClientError!?store.RelayInfoRecord {
        return self.registry.loadRelayInfo(relay_url_text);
    }
};

test "relay directory job client exposes caller-owned buffer storage" {
    var relay_info_store = store.MemoryRelayInfoStore{};
    const client = RelayDirectoryJobClient.init(.{}, relay_info_store.asRelayInfoStore());
    _ = client;

    var lookup_url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;
    const storage = RelayDirectoryJobClientStorage.init(
        lookup_url_buffer[0..],
        response_buffer[0..],
        parse_scratch[0..],
    );

    try std.testing.expectEqual(@as(usize, 128), storage.lookup_url_buffer.len);
    try std.testing.expectEqual(@as(usize, 256), storage.response_buffer.len);
    try std.testing.expectEqual(@as(usize, 4096), storage.parse_scratch.len);
}

test "relay directory job client refreshes one relay metadata record through the registry seam" {
    const testing = @import("../testing/mod.zig");
    const json =
        \\{"name":"alpha","pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","supported_nips":[11,42]}
    ;
    var fake_http = testing.FakeHttp.init("https://relay.test", json);
    fake_http.expected_accept = "application/nostr+json";

    var relay_info_store = store.MemoryRelayInfoStore{};
    var client = RelayDirectoryJobClient.init(.{}, relay_info_store.asRelayInfoStore());
    var lookup_url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;
    var storage = RelayDirectoryJobClientStorage.init(
        lookup_url_buffer[0..],
        response_buffer[0..],
        parse_scratch[0..],
    );

    const job = client.prepareRefreshJob("wss://relay.test");
    const record = try client.refresh(fake_http.client(), &storage, job);
    try std.testing.expectEqualStrings("wss://relay.test", record.relayUrl());
    try std.testing.expectEqualStrings("alpha", record.nameSlice());
    try std.testing.expectEqual(@as(u16, 2), record.supported_nips_count);

    const cached = try client.loadRelayInfo("wss://relay.test");
    try std.testing.expect(cached != null);
    try std.testing.expectEqualStrings("alpha", cached.?.nameSlice());
}
