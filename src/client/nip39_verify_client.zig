const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflows = @import("../workflows/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const Nip39VerifyClientError = workflows.IdentityRememberedProfileVerificationError;

pub const Nip39VerifyClientConfig = struct {};

pub const Nip39VerifyClientStorage = struct {
    claims: []noztr.nip39_external_identities.IdentityClaim,
    verification: []workflows.IdentityVerificationStorage,
    results: []workflows.IdentityClaimVerification,

    pub fn init(
        claims: []noztr.nip39_external_identities.IdentityClaim,
        verification: []workflows.IdentityVerificationStorage,
        results: []workflows.IdentityClaimVerification,
    ) Nip39VerifyClientStorage {
        return .{
            .claims = claims,
            .verification = verification,
            .results = results,
        };
    }

    pub fn asWorkflowStorage(
        self: *const Nip39VerifyClientStorage,
    ) workflows.IdentityProfileVerificationStorage {
        return workflows.IdentityProfileVerificationStorage.init(
            self.claims,
            self.verification,
            self.results,
        );
    }
};

pub const Nip39VerifyJob = workflows.IdentityProfileVerificationRequest;
pub const Nip39VerifySummary = workflows.IdentityProfileVerificationSummary;
pub const Nip39VerifyJobResult = workflows.IdentityRememberedProfileVerification;

pub const Nip39VerifyClient = struct {
    config: Nip39VerifyClientConfig,

    pub fn init(config: Nip39VerifyClientConfig) Nip39VerifyClient {
        return .{ .config = config };
    }

    pub fn prepareVerifyJob(
        self: *const Nip39VerifyClient,
        storage: *const Nip39VerifyClientStorage,
        event: *const noztr.nip01_event.Event,
        pubkey: *const [32]u8,
    ) Nip39VerifyJob {
        _ = self;
        return .{
            .event = event,
            .pubkey = pubkey,
            .storage = storage.asWorkflowStorage(),
        };
    }

    pub fn verifyProfile(
        self: *const Nip39VerifyClient,
        http_client: transport.HttpClient,
        job: Nip39VerifyJob,
    ) Nip39VerifyClientError!Nip39VerifySummary {
        _ = self;
        return workflows.IdentityVerifier.verifyProfile(http_client, job);
    }

    pub fn verifyProfileCached(
        self: *const Nip39VerifyClient,
        http_client: transport.HttpClient,
        cache: workflows.IdentityVerificationCache,
        job: Nip39VerifyJob,
    ) Nip39VerifyClientError!Nip39VerifySummary {
        _ = self;
        return workflows.IdentityVerifier.verifyProfileCached(http_client, cache, job);
    }

    pub fn verifyProfileCachedAndRemember(
        self: *const Nip39VerifyClient,
        http_client: transport.HttpClient,
        cache: workflows.IdentityVerificationCache,
        store: workflows.IdentityProfileStore,
        job: Nip39VerifyJob,
    ) Nip39VerifyClientError!Nip39VerifyJobResult {
        _ = self;
        return workflows.IdentityVerifier.verifyProfileCachedAndRemember(
            http_client,
            cache,
            store,
            job,
        );
    }
};

test "nip39 verify client exposes caller-owned profile verification storage" {
    var claims: [2]noztr.nip39_external_identities.IdentityClaim = undefined;
    var verification: [2]workflows.IdentityVerificationStorage = undefined;
    var results: [2]workflows.IdentityClaimVerification = undefined;
    const storage = Nip39VerifyClientStorage.init(
        claims[0..],
        verification[0..],
        results[0..],
    );
    const client = Nip39VerifyClient.init(.{});
    _ = client;

    const workflow_storage = storage.asWorkflowStorage();
    try std.testing.expectEqual(@as(usize, 2), workflow_storage.claims.len);
    try std.testing.expectEqual(@as(usize, 2), workflow_storage.verification.len);
    try std.testing.expectEqual(@as(usize, 2), workflow_storage.results.len);
}

test "nip39 verify client drives cached remembered profile verification through one command-ready surface" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "alice",
        .proof = "gist-id",
    };
    const signer_secret = [_]u8{0x7a} ** 32;
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(&signer_secret);

    var expected_text_buffer: [256]u8 = undefined;
    const expected_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0..],
        &claim,
        &pubkey,
    );
    var body_storage: [384]u8 = undefined;
    const body = try std.fmt.bufPrint(body_storage[0..], "<pre>{s}</pre>", .{expected_text});
    var fake_http = workflow_testing.FakeHttp.init(
        "https://gist.github.com/alice/gist-id",
        body,
    );

    var built_tag: noztr.nip39_external_identities.BuiltTag = undefined;
    const tag = try noztr.nip39_external_identities.identity_claim_build_tag(&built_tag, &claim);
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = (&[_]noztr.nip01_event.EventTag{tag})[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &event);

    var claims: [1]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [1][256]u8 = undefined;
    var expected_buffers: [1][256]u8 = undefined;
    var body_buffers: [1][512]u8 = undefined;
    var verification: [1]workflows.IdentityVerificationStorage = undefined;
    verification[0] = workflows.IdentityVerificationStorage.init(
        url_buffers[0][0..],
        expected_buffers[0][0..],
        body_buffers[0][0..],
    );
    var results: [1]workflows.IdentityClaimVerification = undefined;
    var cache_records: [1]workflows.IdentityVerificationCacheRecord = undefined;
    var cache = workflows.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [1]workflows.IdentityProfileRecord = undefined;
    var profile_store = workflows.MemoryIdentityProfileStore.init(profile_records[0..]);

    var storage = Nip39VerifyClientStorage.init(
        claims[0..],
        verification[0..],
        results[0..],
    );
    const client = Nip39VerifyClient.init(.{});
    const job = client.prepareVerifyJob(&storage, &event, &pubkey);
    const remembered = try client.verifyProfileCachedAndRemember(
        fake_http.client(),
        cache.asCache(),
        profile_store.asStore(),
        job,
    );

    try std.testing.expectEqual(@as(usize, 1), remembered.summary.claims.len);
    try std.testing.expectEqual(@as(usize, 1), remembered.summary.verified_count);
    try std.testing.expectEqual(@as(usize, 1), remembered.summary.network_fetch_count);
    try std.testing.expectEqual(@as(usize, 0), remembered.summary.cache_hit_count);
    try std.testing.expectEqual(
        workflows.IdentityProfileStorePutOutcome.stored,
        remembered.store_outcome,
    );

    const cached = try client.verifyProfileCached(
        fake_http.client(),
        cache.asCache(),
        job,
    );
    try std.testing.expectEqual(@as(usize, 1), cached.verified_count);
    try std.testing.expectEqual(@as(usize, 1), cached.cache_hit_count);
    try std.testing.expectEqual(@as(usize, 0), cached.network_fetch_count);
}
