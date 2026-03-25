const std = @import("std");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

// Prepare one command-ready NIP-05 verify job over caller-owned buffers, remember the verified
// resolution, then inspect one bounded refresh plan over explicit caller-owned state.
test "recipe: nip05 verify client remembers verified resolution and plans refresh explicitly" {
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

    const client = noztr_sdk.client.identity.nip05.Nip05VerifyClient.init(.{});
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [384]u8 = undefined;
    var storage = noztr_sdk.client.identity.nip05.Nip05VerifyClientStorage.init(
        lookup_url_buffer[0..],
        body_buffer[0..],
    );
    const workflow_planning = noztr_sdk.workflows.identity.nip05.Planning;
    var remembered_records: [2]workflow_planning.Store.Record = undefined;
    var remembered_store = workflow_planning.Store.Memory.init(
        remembered_records[0..],
    );
    const job = client.prepareVerifyJob(
        &storage,
        "alice@example.com",
        &expected_pubkey,
        arena.allocator(),
    );
    const result = try client.verify(fake_http.client(), job);

    try std.testing.expect(result == .verified);
    try std.testing.expectEqual(
        noztr_sdk.client.identity.nip05.Planning.Store.PutOutcome.stored,
        (try client.rememberVerifyOutcome(
            remembered_store.asStore(),
            &result,
            100,
        )).?,
    );
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        result.verified.lookup_url,
    );
    try std.testing.expectEqual(@as(usize, 1), result.verified.profile.relays.len);

    const targets = [_]noztr_sdk.client.identity.nip05.Planning.Target.Value{
        .{ .address_text = "alice@example.com" },
        .{ .address_text = "bob@example.com" },
    };
    var latest_entries: [2]noztr_sdk.client.identity.nip05.Planning.Target.Latest.Entry = undefined;
    var refresh_entries: [2]noztr_sdk.client.identity.nip05.Planning.Target.Refresh.Entry = undefined;
    const plan = try client.planRefreshForTargets(
        remembered_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 110,
            .max_age_seconds = 20,
            .storage = noztr_sdk.client.identity.nip05.Planning.Target.Refresh.Storage.init(
                latest_entries[0..],
                refresh_entries[0..],
            ),
            .scratch = arena.allocator(),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), plan.lookup_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stable_count);
    try std.testing.expectEqual(.lookup_now, plan.nextStep().?.action);
}

fn parsePubkey(hex: []const u8) ![32]u8 {
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(out[0..], hex);
    return out;
}
