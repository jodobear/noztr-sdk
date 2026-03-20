const std = @import("std");
const transport = @import("../transport/mod.zig");
const workflows = @import("../workflows/mod.zig");
const builtin = @import("builtin");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const Nip05VerifyClientError = workflows.Nip05ResolverError;

pub const Nip05VerifyClientConfig = struct {};

pub const Nip05VerifyClientStorage = struct {
    lookup_url_buffer: []u8,
    body_buffer: []u8,

    pub fn init(lookup_url_buffer: []u8, body_buffer: []u8) Nip05VerifyClientStorage {
        return .{
            .lookup_url_buffer = lookup_url_buffer,
            .body_buffer = body_buffer,
        };
    }

    pub fn asLookupStorage(self: *const Nip05VerifyClientStorage) workflows.Nip05LookupStorage {
        return workflows.Nip05LookupStorage.init(
            self.lookup_url_buffer,
            self.body_buffer,
        );
    }
};

pub const Nip05LookupJob = workflows.Nip05LookupRequest;
pub const Nip05VerifyJob = workflows.Nip05VerificationRequest;
pub const Nip05LookupJobResult = workflows.Nip05LookupOutcome;
pub const Nip05VerifyJobResult = workflows.Nip05VerificationOutcome;

pub const Nip05VerifyClient = struct {
    config: Nip05VerifyClientConfig,

    pub fn init(config: Nip05VerifyClientConfig) Nip05VerifyClient {
        return .{ .config = config };
    }

    pub fn prepareLookupJob(
        self: *const Nip05VerifyClient,
        storage: *const Nip05VerifyClientStorage,
        address_text: []const u8,
        scratch: std.mem.Allocator,
    ) Nip05LookupJob {
        _ = self;
        return .{
            .address_text = address_text,
            .storage = storage.asLookupStorage(),
            .scratch = scratch,
        };
    }

    pub fn lookup(
        self: *const Nip05VerifyClient,
        http_client: transport.HttpClient,
        job: Nip05LookupJob,
    ) Nip05VerifyClientError!Nip05LookupJobResult {
        _ = self;
        return workflows.Nip05Resolver.lookup(http_client, job);
    }

    pub fn prepareVerifyJob(
        self: *const Nip05VerifyClient,
        storage: *const Nip05VerifyClientStorage,
        address_text: []const u8,
        expected_pubkey: *const [32]u8,
        scratch: std.mem.Allocator,
    ) Nip05VerifyJob {
        _ = self;
        return .{
            .address_text = address_text,
            .expected_pubkey = expected_pubkey,
            .storage = storage.asLookupStorage(),
            .scratch = scratch,
        };
    }

    pub fn verify(
        self: *const Nip05VerifyClient,
        http_client: transport.HttpClient,
        job: Nip05VerifyJob,
    ) Nip05VerifyClientError!Nip05VerifyJobResult {
        _ = self;
        return workflows.Nip05Resolver.verify(http_client, job);
    }
};

test "nip05 verify client prepares lookup and verify jobs over caller-owned buffers" {
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [384]u8 = undefined;
    var storage = Nip05VerifyClientStorage.init(
        lookup_url_buffer[0..],
        body_buffer[0..],
    );
    const client = Nip05VerifyClient.init(.{});
    const scratch = std.testing.allocator;
    const pubkey = [_]u8{0x11} ** 32;

    const lookup = client.prepareLookupJob(&storage, "alice@example.com", scratch);
    try std.testing.expectEqualStrings("alice@example.com", lookup.address_text);
    try std.testing.expectEqual(@as(usize, lookup_url_buffer.len), lookup.storage.lookup_url_buffer.len);
    try std.testing.expectEqual(@as(usize, body_buffer.len), lookup.storage.body_buffer.len);

    const verify = client.prepareVerifyJob(&storage, "alice@example.com", &pubkey, scratch);
    try std.testing.expectEqualStrings("alice@example.com", verify.address_text);
    try std.testing.expectEqualSlices(u8, pubkey[0..], verify.expected_pubkey[0..]);
}

test "nip05 verify client runs lookup and verify through one command-ready surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"wss://relay.example.com\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";

    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [384]u8 = undefined;
    var storage = Nip05VerifyClientStorage.init(
        lookup_url_buffer[0..],
        body_buffer[0..],
    );
    const client = Nip05VerifyClient.init(.{});

    const lookup = client.prepareLookupJob(&storage, "alice@example.com", arena.allocator());
    const lookup_outcome = try client.lookup(fake_http.client(), lookup);
    try std.testing.expect(lookup_outcome == .resolved);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        lookup_outcome.resolved.lookup_url,
    );

    const verify = client.prepareVerifyJob(
        &storage,
        "alice@example.com",
        &expected_pubkey,
        arena.allocator(),
    );
    const verify_outcome = try client.verify(fake_http.client(), verify);
    try std.testing.expect(verify_outcome == .verified);
    try std.testing.expectEqual(@as(usize, 1), verify_outcome.verified.profile.relays.len);
}

test "nip05 verify client keeps typed fetch-failure posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const expected_pubkey = [_]u8{0x42} ** 32;
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "",
    );
    fake_http.fail_with = error.TransportUnavailable;
    fake_http.expected_accept = "application/json";

    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [128]u8 = undefined;
    var storage = Nip05VerifyClientStorage.init(
        lookup_url_buffer[0..],
        body_buffer[0..],
    );
    const client = Nip05VerifyClient.init(.{});
    const job = client.prepareVerifyJob(
        &storage,
        "alice@example.com",
        &expected_pubkey,
        arena.allocator(),
    );

    const outcome = try client.verify(fake_http.client(), job);
    try std.testing.expect(outcome == .fetch_failed);
    try std.testing.expectEqual(error.TransportUnavailable, outcome.fetch_failed.cause);
}

fn parsePubkey(hex: []const u8) ![32]u8 {
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(out[0..], hex);
    return out;
}
