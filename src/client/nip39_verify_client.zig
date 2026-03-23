const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflows = @import("../workflows/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const Nip39VerifyClientError =
    workflows.identity.verify.IdentityRememberedProfileVerificationError ||
    workflows.identity.verify.IdentityRememberedIdentityPlanningError ||
    workflows.identity.verify.IdentityStoredProfileDiscoveryError ||
    workflows.identity.verify.IdentityStoredWatchedTargetTurnPolicyError ||
    workflows.identity.verify.IdentityStoredWatchedTargetOrchestrationError;

pub const Nip39VerifyClientConfig = struct {};

pub const Nip39VerifyClientStorage = struct {
    claims: []noztr.nip39_external_identities.IdentityClaim,
    verification: []workflows.identity.verify.IdentityVerificationStorage,
    results: []workflows.identity.verify.IdentityClaimVerification,

    pub fn init(
        claims: []noztr.nip39_external_identities.IdentityClaim,
        verification: []workflows.identity.verify.IdentityVerificationStorage,
        results: []workflows.identity.verify.IdentityClaimVerification,
    ) Nip39VerifyClientStorage {
        return .{
            .claims = claims,
            .verification = verification,
            .results = results,
        };
    }

    pub fn asWorkflowStorage(
        self: *const Nip39VerifyClientStorage,
    ) workflows.identity.verify.IdentityProfileVerificationStorage {
        return workflows.identity.verify.IdentityProfileVerificationStorage.init(
            self.claims,
            self.verification,
            self.results,
        );
    }
};

pub const Nip39VerifyJob = workflows.identity.verify.IdentityProfileVerificationRequest;
pub const Nip39VerifySummary = workflows.identity.verify.IdentityProfileVerificationSummary;
pub const Nip39VerifyJobResult = workflows.identity.verify.IdentityRememberedProfileVerification;

pub const Planning = workflows.identity.verify.Planning;

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
        return workflows.identity.verify.IdentityVerifier.verifyProfile(http_client, job);
    }

    pub fn verifyProfileCached(
        self: *const Nip39VerifyClient,
        http_client: transport.HttpClient,
        cache: workflows.identity.verify.IdentityVerificationCache,
        job: Nip39VerifyJob,
    ) Nip39VerifyClientError!Nip39VerifySummary {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.verifyProfileCached(http_client, cache, job);
    }

    pub fn verifyProfileCachedAndRemember(
        self: *const Nip39VerifyClient,
        http_client: transport.HttpClient,
        cache: workflows.identity.verify.IdentityVerificationCache,
        store: workflows.identity.verify.IdentityProfileStore,
        job: Nip39VerifyJob,
    ) Nip39VerifyClientError!Nip39VerifyJobResult {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.verifyProfileCachedAndRemember(
            http_client,
            cache,
            store,
            job,
        );
    }

    pub fn discoverTargets(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetDiscoveryRequest,
    ) Nip39VerifyClientError![]const Planning.TargetDiscoveryGroup {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.discoverStoredProfileEntriesForTargets(store, request);
    }

    pub fn discoverTargetsWithFreshness(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetDiscoveryFreshnessRequest,
    ) Nip39VerifyClientError![]const Planning.TargetDiscoveryFreshnessGroup {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.discoverStoredProfileEntriesWithFreshnessForTargets(
            store,
            request,
        );
    }

    pub fn inspectTargetLatest(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetLatestRequest,
    ) Nip39VerifyClientError!Planning.TargetLatestPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectLatestStoredProfileFreshnessForTargets(
            store,
            request,
        );
    }

    pub fn inspectRememberedLatest(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.RememberedLatestRequest,
    ) Nip39VerifyClientError!Planning.RememberedLatestPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectRememberedIdentityLatestFreshness(store, request);
    }

    pub fn getPreferredForTargets(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.PreferredTargetSelectionRequest,
    ) Nip39VerifyClientError![]const Planning.PreferredTargetEntry {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.getPreferredStoredProfilesForTargets(store, request);
    }

    pub fn getPreferredTarget(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.PreferredTargetRequest,
    ) Nip39VerifyClientError!?Planning.PreferredTarget {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.getPreferredStoredProfileForTargets(store, request);
    }

    pub fn planTargetRefresh(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetRefreshRequest,
    ) Nip39VerifyClientError!Planning.TargetRefreshPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.planStoredProfileRefreshForTargets(store, request);
    }

    pub fn inspectTargetRuntime(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetRuntimeRequest,
    ) Nip39VerifyClientError!Planning.TargetRuntimePlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredProfileRuntimeForTargets(store, request);
    }

    pub fn inspectTargetPolicy(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetPolicyRequest,
    ) Nip39VerifyClientError!Planning.TargetPolicyPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredProfilePolicyForTargets(store, request);
    }

    pub fn inspectTargetCadence(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetCadenceRequest,
    ) Nip39VerifyClientError!Planning.TargetCadencePlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
            store,
            request,
        );
    }

    pub fn inspectTargetBatch(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetBatchRequest,
    ) Nip39VerifyClientError!Planning.TargetBatchPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
            store,
            request,
        );
    }

    pub fn inspectTargetTurnPolicy(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.TargetTurnPolicyRequest,
    ) Nip39VerifyClientError!Planning.TargetTurnPolicyPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(store, request);
    }

    pub fn inspectWatchedPolicy(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        watched_target_store: workflows.identity.verify.IdentityWatchedTargetStore,
        request: Planning.WatchedPolicyRequest,
    ) Nip39VerifyClientError!Planning.WatchedPolicyPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredWatchedTargetPolicy(
            store,
            watched_target_store,
            request,
        );
    }

    pub fn inspectWatchedCadence(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        watched_target_store: workflows.identity.verify.IdentityWatchedTargetStore,
        request: Planning.WatchedCadenceRequest,
    ) Nip39VerifyClientError!Planning.WatchedCadencePlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredWatchedTargetRefreshCadence(
            store,
            watched_target_store,
            request,
        );
    }

    pub fn inspectRememberedCadence(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.RememberedCadenceRequest,
    ) Nip39VerifyClientError!Planning.RememberedCadencePlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectRememberedIdentityRefreshCadence(store, request);
    }

    pub fn inspectWatchedBatch(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        watched_target_store: workflows.identity.verify.IdentityWatchedTargetStore,
        request: Planning.WatchedBatchRequest,
    ) Nip39VerifyClientError!Planning.WatchedBatchPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredWatchedTargetRefreshBatch(
            store,
            watched_target_store,
            request,
        );
    }

    pub fn inspectRememberedBatch(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        request: Planning.RememberedBatchRequest,
    ) Nip39VerifyClientError!Planning.RememberedBatchPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectRememberedIdentityRefreshBatch(store, request);
    }

    pub fn inspectWatchedTurnPolicy(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        watched_target_store: workflows.identity.verify.IdentityWatchedTargetStore,
        request: Planning.WatchedTurnPolicyRequest,
    ) Nip39VerifyClientError!Planning.WatchedTurnPolicyPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredWatchedTargetTurnPolicy(
            store,
            watched_target_store,
            request,
        );
    }

    pub fn inspectWatchedOrchestration(
        self: *const Nip39VerifyClient,
        store: workflows.identity.verify.IdentityProfileStore,
        watched_target_store: workflows.identity.verify.IdentityWatchedTargetStore,
        request: Planning.WatchedOrchestrationRequest,
    ) Nip39VerifyClientError!Planning.WatchedOrchestrationPlan {
        _ = self;
        return workflows.identity.verify.IdentityVerifier.inspectStoredWatchedTargetOrchestration(
            store,
            watched_target_store,
            request,
        );
    }
};

test "nip39 verify client exposes caller-owned profile verification storage" {
    var claims: [2]noztr.nip39_external_identities.IdentityClaim = undefined;
    var verification: [2]workflows.identity.verify.IdentityVerificationStorage = undefined;
    var results: [2]workflows.identity.verify.IdentityClaimVerification = undefined;
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

    var built_tag: noztr.nip39_external_identities.TagBuilder = undefined;
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
    var verification: [1]workflows.identity.verify.IdentityVerificationStorage = undefined;
    verification[0] = workflows.identity.verify.IdentityVerificationStorage.init(
        url_buffers[0][0..],
        expected_buffers[0][0..],
        body_buffers[0][0..],
    );
    var results: [1]workflows.identity.verify.IdentityClaimVerification = undefined;
    var cache_records: [1]workflows.identity.verify.IdentityVerificationCacheRecord = undefined;
    var cache = workflows.identity.verify.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [1]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);

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
        workflows.identity.verify.IdentityProfileStorePutOutcome.stored,
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
    const stable_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
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
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
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

    var profile_records: [2]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &alice_pubkey,
        45,
        &stable_summary,
    );
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &stale_pubkey,
        5,
        &stale_summary,
    );

    const targets = [_]Planning.Target{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches: [2]Planning.ProfileMatch = undefined;
    var latest_entries: [3]Planning.TargetLatestEntry = undefined;
    var policy_entries: [3]Planning.TargetPolicyEntry = undefined;
    var policy_groups: [4]Planning.TargetPolicyGroup = undefined;
    var cadence_entries: [3]Planning.TargetCadenceEntry = undefined;
    var cadence_groups: [5]Planning.TargetCadenceGroup = undefined;
    var entries: [3]Planning.TargetTurnPolicyEntry = undefined;
    var groups: [4]Planning.TargetTurnPolicyGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectTargetTurnPolicy(
        profile_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 31,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 10,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.TargetTurnPolicyStorage.init(
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

test "nip39 verify client inspects stored watched target turn policy through the client surface" {
    const stable_pubkey = [_]u8{0xc1} ** 32;
    const stale_pubkey = [_]u8{0xc2} ** 32;
    const stable_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-alice" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-alice",
                    .expected_text = "npub-alice",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-bob" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-bob",
                    .expected_text = "npub-bob",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [2]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &stable_pubkey,
        45,
        &stable_summary,
    );
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &stale_pubkey,
        5,
        &stale_summary,
    );

    var watched_records: [4]workflows.identity.verify.IdentityWatchedTargetRecord = undefined;
    var watched_store = workflows.identity.verify.MemoryIdentityWatchedTargetStore.init(watched_records[0..]);
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "bob" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "alice" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "dave" });

    var listed_records: [4]Planning.WatchedTargetRecord = undefined;
    var targets: [4]Planning.Target = undefined;
    var matches: [2]Planning.ProfileMatch = undefined;
    var latest_entries: [4]Planning.TargetLatestEntry = undefined;
    var policy_entries: [4]Planning.TargetPolicyEntry = undefined;
    var policy_groups: [4]Planning.TargetPolicyGroup = undefined;
    var cadence_entries: [4]Planning.TargetCadenceEntry = undefined;
    var cadence_groups: [5]Planning.TargetCadenceGroup = undefined;
    var turn_entries: [4]Planning.TargetTurnPolicyEntry = undefined;
    var turn_groups: [4]Planning.TargetTurnPolicyGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectWatchedTurnPolicy(
        profile_store.asStore(),
        watched_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 3,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.WatchedTurnPolicyStorage.init(
                listed_records[0..],
                targets[0..],
                Planning.TargetTurnPolicyStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    policy_entries[0..],
                    policy_groups[0..],
                    cadence_entries[0..],
                    cadence_groups[0..],
                    turn_entries[0..],
                    turn_groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 4), plan.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), plan.turn_policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.turn_policy.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.turn_policy.use_cached_count);
    try std.testing.expectEqual(@as(u32, 0), plan.turn_policy.defer_refresh_count);
    try std.testing.expectEqualStrings("carol", plan.verifyNowEntries()[0].target.identity);
    try std.testing.expectEqualStrings("dave", plan.verifyNowEntries()[1].target.identity);
    try std.testing.expectEqualStrings("bob", plan.refreshSelectedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("alice", plan.useCachedEntries()[0].target.identity);
}

test "nip39 verify client inspects stored watched target policy through the client surface" {
    const fresh_pubkey = [_]u8{0xb1} ** 32;
    const stale_pubkey = [_]u8{0xb2} ** 32;
    const fresh_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-fresh" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-fresh",
                    .expected_text = "npub-fresh",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [2]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &fresh_pubkey, 45, &fresh_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stale_pubkey, 5, &stale_summary);

    var watched_records: [3]workflows.identity.verify.IdentityWatchedTargetRecord = undefined;
    var watched_store = workflows.identity.verify.MemoryIdentityWatchedTargetStore.init(watched_records[0..]);
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "alice" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "bob" });

    var listed_records: [3]Planning.WatchedTargetRecord = undefined;
    var targets: [3]Planning.Target = undefined;
    var matches: [1]Planning.ProfileMatch = undefined;
    var latest_entries: [3]Planning.TargetLatestEntry = undefined;
    var policy_entries: [3]Planning.TargetPolicyEntry = undefined;
    var groups: [4]Planning.TargetPolicyGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectWatchedPolicy(
        profile_store.asStore(),
        watched_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = Planning.WatchedPolicyStorage.init(
                listed_records[0..],
                targets[0..],
                Planning.TargetPolicyStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    policy_entries[0..],
                    groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 3), plan.watched_target_count);
    try std.testing.expectEqual(@as(u32, 1), plan.policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.policy.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), plan.policy.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 0), plan.policy.refresh_existing_count);
    try std.testing.expectEqualStrings("carol", plan.verifyNowEntries()[0].target.identity);
    try std.testing.expectEqualStrings("alice", plan.usablePreferredEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.usablePreferredEntries()[1].target.identity);
    try std.testing.expectEqualStrings("bob", plan.refreshNeededEntries()[0].target.identity);
}

test "nip39 verify client inspects stored watched target refresh cadence through the client surface" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stable_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const soon_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [3]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stale_pubkey, 5, &stale_summary);

    var watched_records: [4]workflows.identity.verify.IdentityWatchedTargetRecord = undefined;
    var watched_store = workflows.identity.verify.MemoryIdentityWatchedTargetStore.init(watched_records[0..]);
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "dave" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "bob" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "alice" });

    var listed_records: [4]Planning.WatchedTargetRecord = undefined;
    var targets: [4]Planning.Target = undefined;
    var matches: [1]Planning.ProfileMatch = undefined;
    var latest_entries: [4]Planning.TargetLatestEntry = undefined;
    var cadence_entries: [4]Planning.TargetCadenceEntry = undefined;
    var groups: [5]Planning.TargetCadenceGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectWatchedCadence(
        profile_store.asStore(),
        watched_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.WatchedCadenceStorage.init(
                listed_records[0..],
                targets[0..],
                Planning.TargetCadenceStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    cadence_entries[0..],
                    groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 4), plan.watched_target_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), plan.cadence.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.stable_count);
    try std.testing.expectEqualStrings("dave", plan.nextDueEntry().?.target.identity);
    try std.testing.expectEqualStrings("carol", plan.usableWhileRefreshingEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.refreshSoonEntries()[0].target.identity);
}

test "nip39 verify client inspects stored watched target refresh batch through the client surface" {
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const soon_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [2]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stale_pubkey, 5, &stale_summary);

    var watched_records: [3]workflows.identity.verify.IdentityWatchedTargetRecord = undefined;
    var watched_store = workflows.identity.verify.MemoryIdentityWatchedTargetStore.init(watched_records[0..]);
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "dave" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "bob" });

    var listed_records: [3]Planning.WatchedTargetRecord = undefined;
    var targets: [3]Planning.Target = undefined;
    var matches: [1]Planning.ProfileMatch = undefined;
    var latest_entries: [3]Planning.TargetLatestEntry = undefined;
    var cadence_entries: [3]Planning.TargetCadenceEntry = undefined;
    var cadence_groups: [5]Planning.TargetCadenceGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const batch = try client.inspectWatchedBatch(
        profile_store.asStore(),
        watched_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.WatchedBatchStorage.init(
                listed_records[0..],
                targets[0..],
                Planning.TargetBatchStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    cadence_entries[0..],
                    cadence_groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 3), batch.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), batch.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), batch.batch.deferred_count);
    try std.testing.expectEqualStrings("dave", batch.selectedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("carol", batch.selectedEntries()[1].target.identity);
    try std.testing.expectEqualStrings("bob", batch.deferredEntries()[0].target.identity);
}

test "nip39 verify client inspects stored watched target orchestration through the client surface" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stable_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const soon_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [3]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stale_pubkey, 5, &stale_summary);

    var watched_records: [4]workflows.identity.verify.IdentityWatchedTargetRecord = undefined;
    var watched_store = workflows.identity.verify.MemoryIdentityWatchedTargetStore.init(watched_records[0..]);
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "dave" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "bob" });
    _ = try watched_store.rememberTarget(.{ .provider = .github, .identity = "alice" });

    var listed_records: [4]Planning.WatchedTargetRecord = undefined;
    var targets: [4]Planning.Target = undefined;

    var policy_matches: [1]Planning.ProfileMatch = undefined;
    var policy_latest_entries: [4]Planning.TargetLatestEntry = undefined;
    var policy_entries: [4]Planning.TargetPolicyEntry = undefined;
    var policy_groups: [4]Planning.TargetPolicyGroup = undefined;

    var cadence_matches: [1]Planning.ProfileMatch = undefined;
    var cadence_latest_entries: [4]Planning.TargetLatestEntry = undefined;
    var cadence_entries: [4]Planning.TargetCadenceEntry = undefined;
    var cadence_groups: [5]Planning.TargetCadenceGroup = undefined;

    var batch_matches: [1]Planning.ProfileMatch = undefined;
    var batch_latest_entries: [4]Planning.TargetLatestEntry = undefined;
    var batch_cadence_entries: [4]Planning.TargetCadenceEntry = undefined;
    var batch_cadence_groups: [5]Planning.TargetCadenceGroup = undefined;

    var turn_matches: [1]Planning.ProfileMatch = undefined;
    var turn_latest_entries: [4]Planning.TargetLatestEntry = undefined;
    var turn_policy_entries: [4]Planning.TargetPolicyEntry = undefined;
    var turn_policy_groups: [4]Planning.TargetPolicyGroup = undefined;
    var turn_cadence_entries: [4]Planning.TargetCadenceEntry = undefined;
    var turn_cadence_groups: [5]Planning.TargetCadenceGroup = undefined;
    var turn_entries: [4]Planning.TargetTurnPolicyEntry = undefined;
    var turn_groups: [4]Planning.TargetTurnPolicyGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectWatchedOrchestration(
        profile_store.asStore(),
        watched_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.WatchedOrchestrationStorage.init(
                listed_records[0..],
                targets[0..],
                Planning.TargetPolicyStorage.init(
                    policy_matches[0..],
                    policy_latest_entries[0..],
                    policy_entries[0..],
                    policy_groups[0..],
                ),
                Planning.TargetCadenceStorage.init(
                    cadence_matches[0..],
                    cadence_latest_entries[0..],
                    cadence_entries[0..],
                    cadence_groups[0..],
                ),
                Planning.TargetBatchStorage.init(
                    batch_matches[0..],
                    batch_latest_entries[0..],
                    batch_cadence_entries[0..],
                    batch_cadence_groups[0..],
                ),
                Planning.TargetTurnPolicyStorage.init(
                    turn_matches[0..],
                    turn_latest_entries[0..],
                    turn_policy_entries[0..],
                    turn_policy_groups[0..],
                    turn_cadence_entries[0..],
                    turn_cadence_groups[0..],
                    turn_entries[0..],
                    turn_groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 4), plan.watched_target_count);
    try std.testing.expectEqual(@as(u32, 1), plan.policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 2), plan.policy.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), plan.policy.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.stable_count);
    try std.testing.expectEqual(@as(u32, 2), plan.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.batch.deferred_count);
    try std.testing.expectEqual(@as(u32, 1), plan.turn.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.turn.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.turn.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), plan.turn.defer_refresh_count);
    try std.testing.expectEqualStrings("dave", plan.nextDueStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("dave", plan.nextRefreshBatchStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("dave", plan.nextWorkStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("alice", plan.useCachedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.deferredEntries()[0].target.identity);
}

test "nip39 verify client inspects remembered identity latest freshness through the client surface" {
    const alice_pubkey_a = [_]u8{0xf1} ** 32;
    const alice_pubkey_b = [_]u8{0xf2} ** 32;
    const bob_pubkey = [_]u8{0xf3} ** 32;
    const alice_stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-alice-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-alice-stale",
                    .expected_text = "npub-alice-stale",
                } },
            },
        },
        .verified_count = 1,
    };
    const alice_fresh_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-alice-fresh" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-alice-fresh",
                    .expected_text = "npub-alice-fresh",
                } },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-bob" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-bob",
                    .expected_text = "npub-bob",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [3]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &alice_pubkey_a, 10, &alice_stale_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &alice_pubkey_b, 45, &alice_fresh_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &bob_pubkey, 5, &bob_summary);

    var remembered_records: [2]Planning.RememberedIdentityRecord = undefined;
    var targets: [2]Planning.Target = undefined;
    var matches: [2]Planning.ProfileMatch = undefined;
    var entries: [2]Planning.TargetLatestEntry = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectRememberedLatest(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                remembered_records[0..],
                targets[0..],
                .init(matches[0..], entries[0..]),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 2), plan.remembered_identity_count);
    try std.testing.expectEqual(@as(u32, 1), plan.freshness.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), plan.freshness.stale_count);
    try std.testing.expectEqual(@as(u32, 0), plan.freshness.missing_count);
    try std.testing.expectEqualStrings("bob", plan.nextEntry().?.target.identity);
    try std.testing.expectEqualStrings("bob", plan.nextStep().?.entry.target.identity);
}

test "nip39 verify client inspects remembered identity refresh cadence through the client surface" {
    const stable_pubkey = [_]u8{0xf6} ** 32;
    const soon_pubkey = [_]u8{0xf7} ** 32;
    const stale_pubkey = [_]u8{0xf8} ** 32;
    const stable_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const soon_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [3]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stale_pubkey, 5, &stale_summary);

    var remembered_records: [3]Planning.RememberedIdentityRecord = undefined;
    var targets: [3]Planning.Target = undefined;
    var matches: [1]Planning.ProfileMatch = undefined;
    var latest_entries: [3]Planning.TargetLatestEntry = undefined;
    var cadence_entries: [3]Planning.TargetCadenceEntry = undefined;
    var groups: [5]Planning.TargetCadenceGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const plan = try client.inspectRememberedCadence(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                remembered_records[0..],
                targets[0..],
                Planning.TargetCadenceStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    cadence_entries[0..],
                    groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 3), plan.remembered_identity_count);
    try std.testing.expectEqual(@as(u32, 0), plan.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), plan.cadence.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), plan.cadence.stable_count);
    try std.testing.expectEqualStrings("carol", plan.nextDueEntry().?.target.identity);
    try std.testing.expectEqualStrings("carol", plan.usableWhileRefreshingEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.refreshSoonEntries()[0].target.identity);
}

test "nip39 verify client inspects remembered identity refresh batch through the client surface" {
    const soon_pubkey = [_]u8{0xf9} ** 32;
    const stale_pubkey = [_]u8{0xfa} ** 32;
    const soon_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]workflows.identity.verify.IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var profile_records: [2]workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try workflows.identity.verify.IdentityVerifier.rememberProfileSummary(profile_store.asStore(), &stale_pubkey, 5, &stale_summary);

    var remembered_records: [2]Planning.RememberedIdentityRecord = undefined;
    var targets: [2]Planning.Target = undefined;
    var matches: [1]Planning.ProfileMatch = undefined;
    var latest_entries: [2]Planning.TargetLatestEntry = undefined;
    var cadence_entries: [2]Planning.TargetCadenceEntry = undefined;
    var cadence_groups: [5]Planning.TargetCadenceGroup = undefined;

    const client = Nip39VerifyClient.init(.{});
    const batch = try client.inspectRememberedBatch(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                remembered_records[0..],
                targets[0..],
                Planning.TargetBatchStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    cadence_entries[0..],
                    cadence_groups[0..],
                ),
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 2), batch.remembered_identity_count);
    try std.testing.expectEqual(@as(u32, 1), batch.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), batch.batch.deferred_count);
    try std.testing.expectEqualStrings("carol", batch.selectedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", batch.deferredEntries()[0].target.identity);
    try std.testing.expectEqualStrings("carol", batch.nextBatchEntry().?.target.identity);
}
