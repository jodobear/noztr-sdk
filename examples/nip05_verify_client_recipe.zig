const std = @import("std");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

// Prepare one command-ready NIP-05 verify job over caller-owned buffers, then run it over the
// explicit public HTTP seam.
test "recipe: nip05 verify client prepares and runs one command-ready verify job" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"wss://relay.example.com\"]}}";
    var fake_http = http_fake.ExampleHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";

    const client = noztr_sdk.client.Nip05VerifyClient.init(.{});
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [384]u8 = undefined;
    var storage = noztr_sdk.client.Nip05VerifyClientStorage.init(
        lookup_url_buffer[0..],
        body_buffer[0..],
    );
    const job = client.prepareVerifyJob(
        &storage,
        "alice@example.com",
        &expected_pubkey,
        arena.allocator(),
    );
    const result = try client.verify(fake_http.client(), job);

    try std.testing.expect(result == .verified);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        result.verified.lookup_url,
    );
    try std.testing.expectEqual(@as(usize, 1), result.verified.profile.relays.len);
}

fn parsePubkey(hex: []const u8) ![32]u8 {
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(out[0..], hex);
    return out;
}
