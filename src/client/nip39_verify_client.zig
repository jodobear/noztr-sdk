const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflows = @import("../workflows/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const Nip39VerifyClientError =
    workflows.IdentityRememberedProfileVerificationError ||
    workflows.IdentityStoredProfileDiscoveryError;

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

pub const Nip39StoredProfilePlanning = struct {
    pub const ProfileMatch = workflows.IdentityProfileMatch;
    pub const StoredProfileDiscoveryEntry = workflows.IdentityStoredProfileDiscoveryEntry;
    pub const StoredProfileFreshness = workflows.IdentityStoredProfileFreshness;
    pub const StoredProfileFallbackPolicy = workflows.IdentityStoredProfileFallbackPolicy;
    pub const StoredProfileDiscoveryFreshnessEntry =
        workflows.IdentityStoredProfileDiscoveryFreshnessEntry;
    pub const Target = workflows.IdentityStoredProfileTarget;
    pub const TargetDiscoveryGroup = workflows.IdentityStoredProfileTargetDiscoveryGroup;
    pub const TargetDiscoveryStorage = workflows.IdentityStoredProfileTargetDiscoveryStorage;
    pub const TargetDiscoveryRequest = workflows.IdentityStoredProfileTargetDiscoveryRequest;
    pub const TargetDiscoveryFreshnessGroup =
        workflows.IdentityStoredProfileTargetDiscoveryFreshnessGroup;
    pub const TargetDiscoveryFreshnessStorage =
        workflows.IdentityStoredProfileTargetDiscoveryFreshnessStorage;
    pub const TargetDiscoveryFreshnessRequest =
        workflows.IdentityStoredProfileTargetDiscoveryFreshnessRequest;
    pub const PreferredTargetEntry = workflows.IdentityPreferredStoredProfileTargetEntry;
    pub const PreferredTargetStorage = workflows.IdentityPreferredStoredProfileTargetStorage;
    pub const PreferredTargetSelectionRequest =
        workflows.IdentityPreferredStoredProfileTargetSelectionRequest;
    pub const TargetLatestFreshnessEntry =
        workflows.IdentityStoredProfileTargetLatestFreshnessEntry;
    pub const TargetLatestFreshnessStorage =
        workflows.IdentityStoredProfileTargetLatestFreshnessStorage;
    pub const TargetLatestFreshnessRequest =
        workflows.IdentityStoredProfileTargetLatestFreshnessRequest;
    pub const PreferredTargetRequest = workflows.IdentityPreferredStoredProfileTargetRequest;
    pub const PreferredTarget = workflows.IdentityPreferredStoredProfileTarget;
    pub const TargetRefreshEntry = workflows.IdentityStoredProfileTargetRefreshEntry;
    pub const TargetRefreshStorage = workflows.IdentityStoredProfileTargetRefreshStorage;
    pub const TargetRefreshRequest = workflows.IdentityStoredProfileTargetRefreshRequest;
    pub const TargetRefreshPlan = workflows.IdentityStoredProfileTargetRefreshPlan;
    pub const TargetRefreshStep = workflows.IdentityStoredProfileTargetRefreshStep;
    pub const TargetRuntimeAction = workflows.IdentityStoredProfileTargetRuntimeAction;
    pub const TargetRuntimeRequest = workflows.IdentityStoredProfileTargetRuntimeRequest;
    pub const TargetRuntimePlan = workflows.IdentityStoredProfileTargetRuntimePlan;
    pub const TargetRuntimeStep = workflows.IdentityStoredProfileTargetRuntimeStep;
    pub const TargetPolicyEntry = workflows.IdentityStoredProfileTargetPolicyEntry;
    pub const TargetPolicyGroup = workflows.IdentityStoredProfileTargetPolicyGroup;
    pub const TargetPolicyStorage = workflows.IdentityStoredProfileTargetPolicyStorage;
    pub const TargetPolicyRequest = workflows.IdentityStoredProfileTargetPolicyRequest;
    pub const TargetPolicyPlan = workflows.IdentityStoredProfileTargetPolicyPlan;
    pub const TargetRefreshCadenceAction =
        workflows.IdentityStoredProfileTargetRefreshCadenceAction;
    pub const TargetRefreshCadenceEntry =
        workflows.IdentityStoredProfileTargetRefreshCadenceEntry;
    pub const TargetRefreshCadenceGroup =
        workflows.IdentityStoredProfileTargetRefreshCadenceGroup;
    pub const TargetRefreshCadenceStorage =
        workflows.IdentityStoredProfileTargetRefreshCadenceStorage;
    pub const TargetRefreshCadenceRequest =
        workflows.IdentityStoredProfileTargetRefreshCadenceRequest;
    pub const TargetRefreshCadencePlan =
        workflows.IdentityStoredProfileTargetRefreshCadencePlan;
    pub const TargetRefreshCadenceStep =
        workflows.IdentityStoredProfileTargetRefreshCadenceStep;
    pub const TargetRefreshBatchStorage = workflows.IdentityStoredProfileTargetRefreshBatchStorage;
    pub const TargetRefreshBatchRequest = workflows.IdentityStoredProfileTargetRefreshBatchRequest;
    pub const TargetRefreshBatchPlan = workflows.IdentityStoredProfileTargetRefreshBatchPlan;
    pub const TargetRefreshBatchStep = workflows.IdentityStoredProfileTargetRefreshBatchStep;
    pub const TargetTurnPolicyAction = workflows.IdentityStoredProfileTargetTurnPolicyAction;
    pub const TargetTurnPolicyEntry = workflows.IdentityStoredProfileTargetTurnPolicyEntry;
    pub const TargetTurnPolicyGroup = workflows.IdentityStoredProfileTargetTurnPolicyGroup;
    pub const TargetTurnPolicyStorage = workflows.IdentityStoredProfileTargetTurnPolicyStorage;
    pub const TargetTurnPolicyRequest = workflows.IdentityStoredProfileTargetTurnPolicyRequest;
    pub const TargetTurnPolicyPlan = workflows.IdentityStoredProfileTargetTurnPolicyPlan;
    pub const TargetTurnPolicyStep = workflows.IdentityStoredProfileTargetTurnPolicyStep;
};

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

    pub fn discoverStoredProfileEntriesForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetDiscoveryRequest,
    ) Nip39VerifyClientError![]const Nip39StoredProfilePlanning.TargetDiscoveryGroup {
        _ = self;
        return workflows.IdentityVerifier.discoverStoredProfileEntriesForTargets(store, request);
    }

    pub fn discoverStoredProfileEntriesWithFreshnessForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetDiscoveryFreshnessRequest,
    ) Nip39VerifyClientError![]const Nip39StoredProfilePlanning.TargetDiscoveryFreshnessGroup {
        _ = self;
        return workflows.IdentityVerifier.discoverStoredProfileEntriesWithFreshnessForTargets(
            store,
            request,
        );
    }

    pub fn inspectLatestStoredProfileFreshnessForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetLatestFreshnessRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetLatestFreshnessPlan {
        _ = self;
        return workflows.IdentityVerifier.inspectLatestStoredProfileFreshnessForTargets(
            store,
            request,
        );
    }

    pub fn getPreferredStoredProfilesForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.PreferredTargetSelectionRequest,
    ) Nip39VerifyClientError![]const Nip39StoredProfilePlanning.PreferredTargetEntry {
        _ = self;
        return workflows.IdentityVerifier.getPreferredStoredProfilesForTargets(store, request);
    }

    pub fn getPreferredStoredProfileForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.PreferredTargetRequest,
    ) Nip39VerifyClientError!?Nip39StoredProfilePlanning.PreferredTarget {
        _ = self;
        return workflows.IdentityVerifier.getPreferredStoredProfileForTargets(store, request);
    }

    pub fn planStoredProfileRefreshForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetRefreshRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetRefreshPlan {
        _ = self;
        return workflows.IdentityVerifier.planStoredProfileRefreshForTargets(store, request);
    }

    pub fn inspectStoredProfileRuntimeForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetRuntimeRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetRuntimePlan {
        _ = self;
        return workflows.IdentityVerifier.inspectStoredProfileRuntimeForTargets(store, request);
    }

    pub fn inspectStoredProfilePolicyForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetPolicyRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetPolicyPlan {
        _ = self;
        return workflows.IdentityVerifier.inspectStoredProfilePolicyForTargets(store, request);
    }

    pub fn inspectStoredProfileRefreshCadenceForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetRefreshCadenceRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetRefreshCadencePlan {
        _ = self;
        return workflows.IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
            store,
            request,
        );
    }

    pub fn inspectStoredProfileRefreshBatchForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetRefreshBatchRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetRefreshBatchPlan {
        _ = self;
        return workflows.IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
            store,
            request,
        );
    }

    pub fn inspectStoredProfileTurnPolicyForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.IdentityProfileStore,
        request: Nip39StoredProfilePlanning.TargetTurnPolicyRequest,
    ) Nip39VerifyClientError!Nip39StoredProfilePlanning.TargetTurnPolicyPlan {
        _ = self;
        return workflows.IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(store, request);
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

test "nip39 verify client lifts remembered target turn policy into the client surface" {
    const alice_pubkey = [_]u8{0xc1} ** 32;
    const stale_pubkey = [_]u8{0xc2} ** 32;
    const stable_summary = workflows.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-bob",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-bob",
                        .expected_text = "npub-bob",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [2]workflows.IdentityProfileRecord = undefined;
    var profile_store = workflows.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &alice_pubkey,
        45,
        &stable_summary,
    );
    _ = try workflows.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &stale_pubkey,
        5,
        &stale_summary,
    );

    const targets = [_]Nip39StoredProfilePlanning.Target{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches: [2]Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var latest_entries: [3]Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var policy_entries: [3]Nip39StoredProfilePlanning.TargetPolicyEntry = undefined;
    var policy_groups: [4]Nip39StoredProfilePlanning.TargetPolicyGroup = undefined;
    var cadence_entries: [3]Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var cadence_groups: [5]Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var entries: [3]Nip39StoredProfilePlanning.TargetTurnPolicyEntry = undefined;
    var groups: [4]Nip39StoredProfilePlanning.TargetTurnPolicyGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectStoredProfileTurnPolicyForTargets(
        profile_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 31,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 10,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip39StoredProfilePlanning.TargetTurnPolicyStorage.init(
                matches[0..],
                latest_entries[0..],
                policy_entries[0..],
                policy_groups[0..],
                cadence_entries[0..],
                cadence_groups[0..],
                entries[0..],
                groups[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), plan.defer_refresh_count);
    try std.testing.expectEqualStrings("carol", plan.nextWorkStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("alice", plan.useCachedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.deferredEntries()[0].target.identity);
}
