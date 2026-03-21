const std = @import("std");
const store = @import("mod.zig");

pub const RelayRegistryArchiveError = store.StoreError;

pub const RelayRegistryArchive = struct {
    relay_info_store: store.RelayInfoStore,

    pub fn init(relay_info_store: store.RelayInfoStore) RelayRegistryArchive {
        return .{ .relay_info_store = relay_info_store };
    }

    pub fn rememberRelay(
        self: RelayRegistryArchive,
        relay_url_text: []const u8,
    ) RelayRegistryArchiveError!store.RelayInfoRecord {
        const record = try store.relay_info_record_from_url(relay_url_text);
        try self.relay_info_store.putRelayInfo(&record);
        return record;
    }

    pub fn saveRelayInfo(
        self: RelayRegistryArchive,
        record: *const store.RelayInfoRecord,
    ) RelayRegistryArchiveError!void {
        return self.relay_info_store.putRelayInfo(record);
    }

    pub fn loadRelayInfo(
        self: RelayRegistryArchive,
        relay_url_text: []const u8,
    ) RelayRegistryArchiveError!?store.RelayInfoRecord {
        return self.relay_info_store.getRelayInfo(relay_url_text);
    }

    pub fn listRelayInfo(
        self: RelayRegistryArchive,
        page: *store.RelayInfoResultPage,
    ) RelayRegistryArchiveError!void {
        return self.relay_info_store.listRelayInfo(page);
    }
};

test "relay registry archive remembers and reloads one relay record" {
    var memory_store = store.MemoryRelayInfoStore{};
    const archive = RelayRegistryArchive.init(memory_store.asRelayInfoStore());

    const remembered = try archive.rememberRelay("wss://relay.one");
    try std.testing.expectEqualStrings("wss://relay.one", remembered.relayUrl());

    const restored = try archive.loadRelayInfo("wss://relay.one");
    try std.testing.expect(restored != null);
    try std.testing.expectEqualStrings("wss://relay.one", restored.?.relayUrl());
}

test "relay registry archive lists remembered relays in stable order" {
    var memory_store = store.MemoryRelayInfoStore{};
    const archive = RelayRegistryArchive.init(memory_store.asRelayInfoStore());
    _ = try archive.rememberRelay("wss://relay.one");
    _ = try archive.rememberRelay("wss://relay.two");

    var page_storage: [2]store.RelayInfoRecord = undefined;
    var page = store.RelayInfoResultPage.init(page_storage[0..]);
    try archive.listRelayInfo(&page);

    try std.testing.expectEqual(@as(usize, 2), page.count);
    try std.testing.expect(!page.truncated);
    try std.testing.expectEqualStrings("wss://relay.one", page.slice()[0].relayUrl());
    try std.testing.expectEqualStrings("wss://relay.two", page.slice()[1].relayUrl());
}
