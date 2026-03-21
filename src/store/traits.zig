const std = @import("std");
const noztr = @import("noztr");
const relay_url = @import("../relay/url.zig");

pub const StoreError = error{
    InvalidRelayUrl,
    RelayUrlTooLong,
    FieldTooLong,
    TooManySupportedNips,
    StoreFull,
};

pub const relay_url_max_bytes: u16 = relay_url.relay_url_max_bytes;
pub const relay_name_max_bytes: u8 = 64;
pub const supported_nips_max: u16 = noztr.limits.nip11_supported_nips_max;

pub const RelayInfoRecord = struct {
    relay_url: [relay_url_max_bytes]u8 = [_]u8{0} ** relay_url_max_bytes,
    relay_url_len: u16 = 0,
    name: [relay_name_max_bytes]u8 = [_]u8{0} ** relay_name_max_bytes,
    name_len: u8 = 0,
    pubkey: [64]u8 = [_]u8{0} ** 64,
    has_pubkey: bool = false,
    supported_nips: [supported_nips_max]u32 = [_]u32{0} ** supported_nips_max,
    supported_nips_count: u16 = 0,

    pub fn relayUrl(self: *const RelayInfoRecord) []const u8 {
        std.debug.assert(self.relay_url_len <= relay_url_max_bytes);
        return self.relay_url[0..self.relay_url_len];
    }

    pub fn nameSlice(self: *const RelayInfoRecord) []const u8 {
        std.debug.assert(self.name_len <= relay_name_max_bytes);
        return self.name[0..self.name_len];
    }

    pub fn pubkeySlice(self: *const RelayInfoRecord) ?[]const u8 {
        if (!self.has_pubkey) return null;
        return self.pubkey[0..];
    }
};

pub const RelayInfoResultPage = struct {
    items: []RelayInfoRecord,
    count: usize = 0,
    truncated: bool = false,

    pub fn init(storage: []RelayInfoRecord) RelayInfoResultPage {
        return .{ .items = storage };
    }

    pub fn reset(self: *RelayInfoResultPage) void {
        self.count = 0;
        self.truncated = false;
    }

    pub fn slice(self: *const RelayInfoResultPage) []const RelayInfoRecord {
        std.debug.assert(self.count <= self.items.len);
        return self.items[0..self.count];
    }
};

pub fn relay_info_record_from_url(relay_url_text: []const u8) StoreError!RelayInfoRecord {
    var record = RelayInfoRecord{};
    if (relay_url_text.len > relay_url_max_bytes) return error.RelayUrlTooLong;
    try relay_url.relayUrlValidate(relay_url_text);
    try copy_bounded(record.relay_url[0..], &record.relay_url_len, relay_url_text);
    return record;
}

pub fn relay_info_record_from_document(
    relay_url_text: []const u8,
    doc: *const noztr.nip11.RelayInformationDocument,
) StoreError!RelayInfoRecord {
    std.debug.assert(@intFromPtr(doc) != 0);

    var record = RelayInfoRecord{};
    if (relay_url_text.len > relay_url_max_bytes) return error.RelayUrlTooLong;
    try relay_url.relayUrlValidate(relay_url_text);
    try copy_bounded(record.relay_url[0..], &record.relay_url_len, relay_url_text);
    if (doc.name) |name| {
        try copy_bounded(record.name[0..], &record.name_len, name);
    }
    if (doc.pubkey) |pubkey| {
        if (pubkey.len != record.pubkey.len) return error.FieldTooLong;
        @memcpy(record.pubkey[0..], pubkey);
        record.has_pubkey = true;
    }
    if (doc.supported_nips.len > supported_nips_max) {
        return error.TooManySupportedNips;
    }

    var index: usize = 0;
    while (index < doc.supported_nips.len) : (index += 1) {
        record.supported_nips[index] = doc.supported_nips[index];
    }
    record.supported_nips_count = @intCast(doc.supported_nips.len);
    return record;
}

fn copy_bounded(dest: []u8, len_out: anytype, input: []const u8) StoreError!void {
    std.debug.assert(dest.len <= std.math.maxInt(@TypeOf(len_out.*)));

    if (input.len > dest.len) return error.FieldTooLong;
    @memset(dest, 0);
    @memcpy(dest[0..input.len], input);
    len_out.* = @intCast(input.len);
}

pub const RelayInfoStoreVTable = struct {
    put_relay_info: *const fn (ctx: *anyopaque, record: *const RelayInfoRecord) StoreError!void,
    get_relay_info:
        *const fn (ctx: *anyopaque, relay_url: []const u8) StoreError!?RelayInfoRecord,
    list_relay_info: *const fn (ctx: *anyopaque, page: *RelayInfoResultPage) StoreError!void,
};

pub const RelayInfoStore = struct {
    ctx: *anyopaque,
    vtable: *const RelayInfoStoreVTable,

    pub fn putRelayInfo(self: RelayInfoStore, record: *const RelayInfoRecord) StoreError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.put_relay_info(self.ctx, record);
    }

    pub fn getRelayInfo(
        self: RelayInfoStore,
        relay_url_text: []const u8,
    ) StoreError!?RelayInfoRecord {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.get_relay_info(self.ctx, relay_url_text);
    }

    pub fn listRelayInfo(
        self: RelayInfoStore,
        page: *RelayInfoResultPage,
    ) StoreError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.list_relay_info(self.ctx, page);
    }
};

test "relay info record from url keeps bounded relay identity without metadata" {
    const record = try relay_info_record_from_url("wss://relay.test");
    try std.testing.expectEqualStrings("wss://relay.test", record.relayUrl());
    try std.testing.expectEqual(@as(u8, 0), record.name_len);
    try std.testing.expect(!record.has_pubkey);
    try std.testing.expectEqual(@as(u16, 0), record.supported_nips_count);
}
