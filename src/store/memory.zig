const std = @import("std");
const traits = @import("traits.zig");
const relay_url = @import("../relay/url.zig");

pub const default_capacity: u8 = 16;

pub const MemoryStore = struct {
    records: [default_capacity]traits.RelayInfoRecord = [_]traits.RelayInfoRecord{.{}} **
        default_capacity,
    count: u8 = 0,

    pub fn asRelayInfoStore(self: *MemoryStore) traits.RelayInfoStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .{
            .ctx = self,
            .vtable = &relay_info_store_vtable,
        };
    }

    pub fn putRelayInfo(self: *MemoryStore, record: *const traits.RelayInfoRecord) traits.StoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        const existing = find_record_index(self, record.relayUrl());
        if (existing) |index| {
            self.records[index] = record.*;
            return;
        }
        if (self.count == default_capacity) return error.StoreFull;

        self.records[self.count] = record.*;
        self.count += 1;
    }

    pub fn getRelayInfo(
        self: *MemoryStore,
        relay_url_text: []const u8,
    ) traits.StoreError!?traits.RelayInfoRecord {
        std.debug.assert(@intFromPtr(self) != 0);

        const existing = find_record_index(self, relay_url_text);
        if (existing) |index| return self.records[index];
        return null;
    }
};

fn put_relay_info(ctx: *anyopaque, record: *const traits.RelayInfoRecord) traits.StoreError!void {
    const self: *MemoryStore = @ptrCast(@alignCast(ctx));
    return self.putRelayInfo(record);
}

fn get_relay_info(
    ctx: *anyopaque,
    relay_url_text: []const u8,
) traits.StoreError!?traits.RelayInfoRecord {
    const self: *MemoryStore = @ptrCast(@alignCast(ctx));
    return self.getRelayInfo(relay_url_text);
}

const relay_info_store_vtable = traits.RelayInfoStoreVTable{
    .put_relay_info = put_relay_info,
    .get_relay_info = get_relay_info,
};

fn find_record_index(self: *const MemoryStore, relay_url_text: []const u8) ?u8 {
    std.debug.assert(self.count <= default_capacity);

    var index: u8 = 0;
    while (index < self.count) : (index += 1) {
        if (relay_url.relayUrlsEquivalent(self.records[index].relayUrl(), relay_url_text)) return index;
    }
    return null;
}

test "memory store overwrites by relay url and returns cached record" {
    var store = MemoryStore{};
    var record = traits.RelayInfoRecord{};
    record.relay_url_len = 11;
    @memcpy(record.relay_url[0..11], "wss://relay");
    record.name_len = 5;
    @memcpy(record.name[0..5], "alpha");
    try store.putRelayInfo(&record);

    const cached = try store.getRelayInfo("wss://relay");
    try std.testing.expect(cached != null);
    try std.testing.expectEqualStrings("alpha", cached.?.nameSlice());
}

test "memory store overwrites normalized-equivalent relay urls" {
    var store = MemoryStore{};

    var first = traits.RelayInfoRecord{};
    first.relay_url_len = 34;
    @memcpy(first.relay_url[0..34], "wss://relay.example.com/path/exact");
    first.name_len = 5;
    @memcpy(first.name[0..5], "alpha");
    try store.putRelayInfo(&first);

    var second = traits.RelayInfoRecord{};
    second.relay_url_len = 42;
    @memcpy(second.relay_url[0..42], "WSS://RELAY.EXAMPLE.COM:443/path/exact?x=1");
    second.name_len = 4;
    @memcpy(second.name[0..4], "beta");
    try store.putRelayInfo(&second);

    try std.testing.expectEqual(@as(u8, 1), store.count);
    const cached = try store.getRelayInfo("wss://relay.example.com/path/exact");
    try std.testing.expect(cached != null);
    try std.testing.expectEqualStrings("beta", cached.?.nameSlice());
}
