const std = @import("std");
const noztr = @import("noztr");
const store = @import("../store/mod.zig");
const transport = @import("../transport/mod.zig");
const relay_url = @import("url.zig");

pub const DirectoryError = transport.HttpError || store.StoreError || noztr.nip11.Nip11Error || error{
    InvalidRelayUrl,
    BufferTooSmall,
};

pub const RelayDirectory = struct {
    cache: store.RelayInfoStore,

    pub fn init(cache: store.RelayInfoStore) RelayDirectory {
        return .{ .cache = cache };
    }

    pub fn refresh(
        self: *RelayDirectory,
        client: transport.HttpClient,
        relay_url_text: []const u8,
        url_buffer: []u8,
        response_buffer: []u8,
        parse_scratch: []u8,
    ) DirectoryError!store.RelayInfoRecord {
        std.debug.assert(@intFromPtr(self) != 0);

        try relay_url.relayUrlValidate(relay_url_text);
        const lookup_url = try compose_lookup_url(relay_url_text, url_buffer);
        const body = try client.get(.{
            .url = lookup_url,
            .accept = "application/nostr+json",
        }, response_buffer);
        var fba = std.heap.FixedBufferAllocator.init(parse_scratch);
        const doc = try noztr.nip11.nip11_parse_document(body, fba.allocator());
        const record = try store.traits.relay_info_record_from_document(relay_url_text, &doc);
        try self.cache.putRelayInfo(&record);
        return record;
    }
};

fn compose_lookup_url(relay_url_text: []const u8, out: []u8) DirectoryError![]const u8 {
    std.debug.assert(relay_url_text.len > 0);

    const secure_prefix = "wss://";
    const plain_prefix = "ws://";
    if (std.mem.startsWith(u8, relay_url_text, secure_prefix)) {
        return compose_http_url("https://", relay_url_text[secure_prefix.len..], out);
    }
    if (std.mem.startsWith(u8, relay_url_text, plain_prefix)) {
        return compose_http_url("http://", relay_url_text[plain_prefix.len..], out);
    }
    return error.InvalidRelayUrl;
}

fn compose_http_url(prefix: []const u8, tail: []const u8, out: []u8) DirectoryError![]const u8 {
    const required = prefix.len + tail.len;
    if (required > out.len) return error.BufferTooSmall;

    @memcpy(out[0..prefix.len], prefix);
    @memcpy(out[prefix.len..required], tail);
    return out[0..required];
}

test "relay directory fetches nip11 and stores a bounded cache record" {
    const json =
        \\{"name":"alpha","pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","supported_nips":[11,42]}
    ;
    var fake_http = @import("../testing/fake_http.zig").FakeHttp.init("https://relay.test", json);
    fake_http.expected_accept = "application/nostr+json";
    var memory_store = store.MemoryStore{};
    var directory = RelayDirectory.init(memory_store.asRelayInfoStore());
    var url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;

    const record = try directory.refresh(
        fake_http.client(),
        "wss://relay.test",
        &url_buffer,
        &response_buffer,
        &parse_scratch,
    );
    try std.testing.expectEqualStrings("wss://relay.test", record.relayUrl());
    try std.testing.expectEqualStrings("alpha", record.nameSlice());
    try std.testing.expectEqual(@as(u16, 2), record.supported_nips_count);
}

test "relay directory rejects invalid relay urls before fetch" {
    var fake_http = @import("../testing/fake_http.zig").FakeHttp.init("https://relay.test", "{}");
    var memory_store = store.MemoryStore{};
    var directory = RelayDirectory.init(memory_store.asRelayInfoStore());
    var url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;

    try std.testing.expectError(
        error.InvalidRelayUrl,
        directory.refresh(
            fake_http.client(),
            "https://relay.test",
            &url_buffer,
            &response_buffer,
            &parse_scratch,
        ),
    );
}

test "relay directory propagates invalid nip11 documents" {
    var fake_http = @import("../testing/fake_http.zig").FakeHttp.init(
        "https://relay.test",
        "{\"supported_nips\":\"bad\"}",
    );
    fake_http.expected_accept = "application/nostr+json";
    var memory_store = store.MemoryStore{};
    var directory = RelayDirectory.init(memory_store.asRelayInfoStore());
    var url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;

    try std.testing.expectError(
        error.InvalidKnownFieldType,
        directory.refresh(
            fake_http.client(),
            "wss://relay.test",
            &url_buffer,
            &response_buffer,
            &parse_scratch,
        ),
    );
}
