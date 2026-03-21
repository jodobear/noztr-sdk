const std = @import("std");
const http_fake = @import("http_fake.zig");
const noztr_sdk = @import("noztr_sdk");

// Refresh one relay's `NIP-11` metadata over the explicit HTTP seam, then keep the remembered
// record in bounded local relay-registry storage.
test "recipe: relay directory job client refreshes one remembered relay metadata record" {
    const json =
        \\{"name":"alpha","pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","supported_nips":[11,42]}
    ;
    var fake_http = http_fake.ExampleHttp.init("https://relay.test", json);
    fake_http.expected_accept = "application/nostr+json";

    var relay_info_store = noztr_sdk.store.MemoryRelayInfoStore{};
    var client = noztr_sdk.client.RelayDirectoryJobClient.init(
        .{},
        relay_info_store.asRelayInfoStore(),
    );
    var lookup_url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;
    var storage = noztr_sdk.client.RelayDirectoryJobClientStorage.init(
        lookup_url_buffer[0..],
        response_buffer[0..],
        parse_scratch[0..],
    );

    const record = try client.refresh(
        fake_http.client(),
        &storage,
        client.prepareRefreshJob("wss://relay.test"),
    );
    try std.testing.expectEqualStrings("wss://relay.test", record.relayUrl());
    try std.testing.expectEqualStrings("alpha", record.nameSlice());

    const cached = try client.loadRelayInfo("wss://relay.test");
    try std.testing.expect(cached != null);
    try std.testing.expectEqual(@as(u16, 2), cached.?.supported_nips_count);
}
