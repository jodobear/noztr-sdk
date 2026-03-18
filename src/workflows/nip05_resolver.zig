const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const Nip05ResolverError = noztr.nip05_identity.Nip05Error;

pub const Nip05Resolution = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    profile: noztr.nip05_identity.Profile,
};

pub const Nip05LookupStorage = struct {
    lookup_url_buffer: []u8,
    body_buffer: []u8,

    pub fn init(lookup_url_buffer: []u8, body_buffer: []u8) Nip05LookupStorage {
        return .{
            .lookup_url_buffer = lookup_url_buffer,
            .body_buffer = body_buffer,
        };
    }
};

pub const Nip05LookupRequest = struct {
    address_text: []const u8,
    storage: Nip05LookupStorage,
    scratch: std.mem.Allocator,
};

pub const Nip05FetchFailure = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    cause: transport.HttpError,
};

pub const Nip05VerificationMismatch = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    expected_pubkey: [32]u8,
    profile: ?noztr.nip05_identity.Profile = null,
};

pub const Nip05LookupOutcome = union(enum) {
    resolved: Nip05Resolution,
    fetch_failed: Nip05FetchFailure,
};

pub const Nip05VerificationOutcome = union(enum) {
    verified: Nip05Resolution,
    mismatch: Nip05VerificationMismatch,
    fetch_failed: Nip05FetchFailure,
};

pub const Nip05VerificationRequest = struct {
    address_text: []const u8,
    expected_pubkey: *const [32]u8,
    storage: Nip05LookupStorage,
    scratch: std.mem.Allocator,
};

pub const Nip05Resolver = struct {
    pub fn lookup(
        http_client: transport.HttpClient,
        request: Nip05LookupRequest,
    ) Nip05ResolverError!Nip05LookupOutcome {
        const fetched = try fetchDocument(
            http_client,
            request.address_text,
            request.storage.lookup_url_buffer,
            request.storage.body_buffer,
            request.scratch,
        );
        return switch (fetched) {
            .fetch_failed => |failure| .{ .fetch_failed = failure },
            .fetched => |document| {
                const profile = try noztr.nip05_identity.profile_parse_json(
                    &document.address,
                    document.body,
                    request.scratch,
                );
                return .{
                    .resolved = .{
                        .address = document.address,
                        .lookup_url = document.lookup_url,
                        .profile = profile,
                    },
                };
            },
        };
    }

    pub fn verify(
        http_client: transport.HttpClient,
        request: Nip05VerificationRequest,
    ) Nip05ResolverError!Nip05VerificationOutcome {
        const fetched = try fetchDocument(
            http_client,
            request.address_text,
            request.storage.lookup_url_buffer,
            request.storage.body_buffer,
            request.scratch,
        );

        return switch (fetched) {
            .fetch_failed => |failure| .{ .fetch_failed = failure },
            .fetched => |document| {
                const verified = try noztr.nip05_identity.profile_verify_json(
                    request.expected_pubkey,
                    &document.address,
                    document.body,
                    request.scratch,
                );
                if (!verified) {
                    const profile = noztr.nip05_identity.profile_parse_json(
                        &document.address,
                        document.body,
                        request.scratch,
                    ) catch null;
                    return .{
                        .mismatch = .{
                            .address = document.address,
                            .lookup_url = document.lookup_url,
                            .expected_pubkey = request.expected_pubkey.*,
                            .profile = profile,
                        },
                    };
                }

                const profile = try noztr.nip05_identity.profile_parse_json(
                    &document.address,
                    document.body,
                    request.scratch,
                );
                return .{
                    .verified = .{
                        .address = document.address,
                        .lookup_url = document.lookup_url,
                        .profile = profile,
                    },
                };
            },
        };
    }
};

const FetchedDocument = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    body: []const u8,
};

const FetchDocumentResult = union(enum) {
    fetched: FetchedDocument,
    fetch_failed: Nip05FetchFailure,
};

fn fetchDocument(
    http_client: transport.HttpClient,
    address_text: []const u8,
    lookup_url_buffer: []u8,
    body_buffer: []u8,
    scratch: std.mem.Allocator,
) Nip05ResolverError!FetchDocumentResult {
    const address = try noztr.nip05_identity.address_parse(address_text, scratch);
    const lookup_url = try noztr.nip05_identity.address_compose_well_known_url(
        lookup_url_buffer,
        &address,
    );
    const body = http_client.get(
        .{
            .url = lookup_url,
            .accept = "application/json",
        },
        body_buffer,
    ) catch |err| {
        return .{
            .fetch_failed = .{
                .address = address,
                .lookup_url = lookup_url,
                .cause = err,
            },
        };
    };

    return .{
        .fetched = .{
            .address = address,
            .lookup_url = lookup_url,
            .body = body,
        },
    };
}

test "nip05 resolver lookup returns parsed profile relays and bunker relays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"wss://relay.example.com\",\"wss://relay2.example.com\"]}," ++
        "\"nip46\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"wss://bunker.example.com\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [512]u8 = undefined;

    const outcome = try Nip05Resolver.lookup(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .resolved);
    try std.testing.expectEqualStrings("alice", outcome.resolved.address.name);
    try std.testing.expectEqualStrings("example.com", outcome.resolved.address.domain);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        outcome.resolved.lookup_url,
    );
    try std.testing.expectEqual(@as(usize, 2), outcome.resolved.profile.relays.len);
    try std.testing.expectEqualStrings("wss://relay.example.com", outcome.resolved.profile.relays[0]);
    try std.testing.expectEqual(@as(usize, 1), outcome.resolved.profile.nip46_relays.len);
    try std.testing.expectEqualStrings(
        "wss://bunker.example.com",
        outcome.resolved.profile.nip46_relays[0],
    );
}

test "nip05 resolver verify returns verified on matching pubkey" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );
    var address_buffer: [128]u8 = undefined;
    const formatted = try noztr.nip05_identity.address_format(
        address_buffer[0..],
        &outcome.verified.address,
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqualStrings("alice@example.com", formatted);
}

test "nip05 resolver verify classifies pubkey mismatches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expect(outcome.mismatch.profile != null);
    try std.testing.expectEqualSlices(
        u8,
        expected_pubkey[0..],
        outcome.mismatch.expected_pubkey[0..],
    );
}

test "nip05 resolver verify treats missing names as mismatch instead of kernel error" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "{\"names\":{}}",
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [128]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expect(outcome.mismatch.profile == null);
    try std.testing.expectEqualStrings("alice", outcome.mismatch.address.name);
}

test "nip05 resolver verify keeps mismatch semantics when relay maps are malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[\"https://relay.bad\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expect(outcome.mismatch.profile == null);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        outcome.mismatch.lookup_url,
    );
}

test "nip05 resolver verify does not require scratch for a second parse" {
    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}}",
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;
    var scratch_storage: [1536]u8 = undefined;
    var scratch = std.heap.FixedBufferAllocator.init(&scratch_storage);

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = scratch.allocator(),
        },
    );

    try std.testing.expect(outcome == .verified);
}

test "nip05 resolver returns fetch failures as typed outcomes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "",
    );
    fake_http.expected_accept = "application/json";
    fake_http.fail_with = error.TransportUnavailable;
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [64]u8 = undefined;

    const outcome = try Nip05Resolver.lookup(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .fetch_failed);
    try std.testing.expectEqual(error.TransportUnavailable, outcome.fetch_failed.cause);
    try std.testing.expectEqualStrings("alice", outcome.fetch_failed.address.name);
}

test "nip05 resolver propagates malformed documents from noztr" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"https://not-a-websocket.example.com\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [512]u8 = undefined;

    try std.testing.expectError(
        error.InvalidRelayUrl,
        Nip05Resolver.lookup(
            fake_http.client(),
            .{
                .address_text = "alice@example.com",
                .storage = Nip05LookupStorage.init(
                    lookup_url_buffer[0..],
                    body_buffer[0..],
                ),
                .scratch = arena.allocator(),
            },
        ),
    );
}

fn parsePubkey(text: []const u8) ![32]u8 {
    var pubkey: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&pubkey, text);
    return pubkey;
}
