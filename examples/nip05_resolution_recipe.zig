const std = @import("std");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

// Resolve and verify one NIP-05 address over the public SDK HTTP seam.
test "recipe: nip05 resolver uses the public http seam explicitly" {
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
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [384]u8 = undefined;

    const outcome = try noztr_sdk.workflows.Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = noztr_sdk.workflows.Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        outcome.verified.lookup_url,
    );
    try std.testing.expectEqual(@as(usize, 1), outcome.verified.profile.relays.len);
}

fn parsePubkey(hex: []const u8) ![32]u8 {
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(out[0..], hex);
    return out;
}
