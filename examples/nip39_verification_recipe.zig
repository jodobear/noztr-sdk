const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Verify all claims from one identity event over the public SDK HTTP seam, remember the verified
// profile through the explicit store seam, hydrate one stored discovery result directly, classify
// both discovered entries and the latest remembered profile for freshness, inspect one explicit
// watched identity set through the latest-freshness plan plus one typed next step, select one
// preferred remembered profile across that watched target set, plan refresh across that watched
// target set, then select one preferred remembered profile under an explicit fallback policy for
// one identity, inspect the remembered runtime action and typed next step for that identity, plan
// one typed refresh step for stale remembered profiles, then replay the same verification from an
// explicit caller-owned cache.
test "recipe: identity verifier verifies, remembers, discovers, inspects watched-target latest freshness, selects preferred remembered profile, inspects remembered runtime and refresh steps, and replays one profile event" {
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{
            .provider = .github,
            .identity = "alice",
            .proof = "gist-id",
        },
        .{
            .provider = .twitter,
            .identity = "alice_public",
            .proof = "1619358434134196225",
        },
    };
    const pubkey = [_]u8{0x42} ** 32;

    var expected_text_buffer: [2][256]u8 = undefined;
    const github_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0][0..],
        &claims[0],
        &pubkey,
    );
    const twitter_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[1][0..],
        &claims[1],
        &pubkey,
    );
    var github_body_storage: [384]u8 = undefined;
    const github_body = try std.fmt.bufPrint(github_body_storage[0..], "<pre>{s}</pre>", .{github_text});
    var twitter_body_storage: [384]u8 = undefined;
    const twitter_body = try std.fmt.bufPrint(
        twitter_body_storage[0..],
        "<div>{s}</div>",
        .{twitter_text},
    );
    var responses = [_]TestHttpResponse{
        .{
            .url = "https://gist.github.com/alice/gist-id",
            .body = github_body,
        },
        .{
            .url = "https://twitter.com/alice_public/status/1619358434134196225",
            .body = twitter_body,
        },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);

    var built_tags: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &built_tags[index],
            claim,
        );
    }
    const signer_secret = [_]u8{0x7a} ** 32;
    const signer_pubkey = try common.derivePublicKey(&signer_secret);
    var identity_event = common.simpleEvent(
        noztr.nip39_external_identities.identity_kind,
        signer_pubkey,
        1,
        "",
        tags[0..],
    );
    try common.signEvent(&signer_secret, &identity_event);

    var claims_buffer: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var verification_url_buffers: [4][256]u8 = undefined;
    var verification_text_buffers: [4][256]u8 = undefined;
    var verification_body_buffers: [4][512]u8 = undefined;
    var verification_storage: [4]noztr_sdk.workflows.IdentityVerificationStorage = undefined;
    for (&verification_storage, 0..) |*slot, index| {
        slot.* = noztr_sdk.workflows.IdentityVerificationStorage.init(
            verification_url_buffers[index][0..],
            verification_text_buffers[index][0..],
            verification_body_buffers[index][0..],
        );
    }
    var results: [4]noztr_sdk.workflows.IdentityClaimVerification = undefined;
    var cache_records: [4]noztr_sdk.workflows.IdentityVerificationCacheRecord = undefined;
    var cache = noztr_sdk.workflows.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [2]noztr_sdk.workflows.IdentityProfileRecord = undefined;
    var profile_store = noztr_sdk.workflows.MemoryIdentityProfileStore.init(profile_records[0..]);

    const remembered = try noztr_sdk.workflows.IdentityVerifier.verifyProfileCachedAndRemember(
        fake_http.client(),
        cache.asCache(),
        profile_store.asStore(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = noztr_sdk.workflows.IdentityProfileVerificationStorage.init(
                claims_buffer[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );
    const summary = remembered.summary;

    try std.testing.expectEqual(@as(usize, 2), summary.claims.len);
    try std.testing.expectEqual(@as(usize, 2), summary.verified_count);
    try std.testing.expectEqual(@as(usize, 2), summary.network_fetch_count);
    try std.testing.expectEqual(@as(usize, 0), summary.cache_hit_count);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityProfileStorePutOutcome.stored,
        remembered.store_outcome,
    );
    var verified: [2]*const noztr_sdk.workflows.IdentityClaimVerification = undefined;
    const verified_claims = summary.verifiedClaims(verified[0..]);
    try std.testing.expectEqual(@as(usize, 2), verified_claims.len);

    const github = try verified_claims[0].providerDetails();
    try std.testing.expect(github == .github);
    try std.testing.expectEqualStrings("alice", github.github.username);
    try std.testing.expectEqualStrings("gist-id", github.github.gist_id);
    try std.testing.expectEqualStrings(
        "https://gist.github.com/alice/gist-id",
        verified_claims[0].outcome.verified.proof_url,
    );

    const twitter = try verified_claims[1].providerDetails();
    try std.testing.expect(twitter == .twitter);
    try std.testing.expectEqualStrings("alice_public", twitter.twitter.handle);
    try std.testing.expectEqualStrings("1619358434134196225", twitter.twitter.status_id);
    try std.testing.expectEqualStrings(
        "https://twitter.com/alice_public/status/1619358434134196225",
        verified_claims[1].outcome.verified.proof_url,
    );

    var discovered_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    var discovered_entries: [2]noztr_sdk.workflows.IdentityStoredProfileDiscoveryEntry = undefined;
    const discovered = try noztr_sdk.workflows.IdentityVerifier.discoverStoredProfileEntries(
        profile_store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .storage = noztr_sdk.workflows.IdentityStoredProfileDiscoveryStorage.init(
                discovered_matches[0..],
                discovered_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), discovered.len);
    try std.testing.expectEqualSlices(u8, pubkey[0..], discovered[0].match.pubkey[0..]);
    try std.testing.expectEqualStrings("alice", discovered[0].matchedClaim().identitySlice());

    var discovered_freshness_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    var discovered_freshness_entries: [2]noztr_sdk.workflows.IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    const discovered_with_freshness =
        try noztr_sdk.workflows.IdentityVerifier.discoverStoredProfileEntriesWithFreshness(
            profile_store.asStore(),
            .{
                .provider = .github,
                .identity = "alice",
                .now_unix_seconds = 31,
                .max_age_seconds = 60,
                .storage = noztr_sdk.workflows.IdentityStoredProfileDiscoveryFreshnessStorage.init(
                    discovered_freshness_matches[0..],
                    discovered_freshness_entries[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(usize, 1), discovered_with_freshness.len);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileFreshness.fresh,
        discovered_with_freshness[0].freshness,
    );
    try std.testing.expectEqual(@as(u64, 30), discovered_with_freshness[0].age_seconds);
    try std.testing.expectEqualStrings("alice", discovered_with_freshness[0].matchedClaim().identitySlice());

    const bob_pubkey = [_]u8{0x43} ** 32;
    const bob_summary = noztr_sdk.workflows.IdentityProfileVerificationSummary{
        .claims = &[_]noztr_sdk.workflows.IdentityClaimVerification{
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
    _ = try noztr_sdk.workflows.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &bob_pubkey,
        5,
        &bob_summary,
    );

    const watched_targets = [_]noztr_sdk.workflows.IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var watched_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    var watched_entries: [3]noztr_sdk.workflows.IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const watched_latest = try noztr_sdk.workflows.IdentityVerifier.inspectLatestStoredProfileFreshnessForTargets(
        profile_store.asStore(),
        .{
            .targets = watched_targets[0..],
            .now_unix_seconds = 31,
            .max_age_seconds = 20,
            .storage = noztr_sdk.workflows.IdentityStoredProfileTargetLatestFreshnessStorage.init(
                watched_matches[0..],
                watched_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 3), watched_latest.entries.len);
    try std.testing.expectEqual(@as(u32, 0), watched_latest.fresh_count);
    try std.testing.expectEqual(@as(u32, 2), watched_latest.stale_count);
    try std.testing.expectEqual(@as(u32, 1), watched_latest.missing_count);
    try std.testing.expectEqualStrings("alice", watched_latest.entries[0].target.identity);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileFreshness.stale,
        watched_latest.entries[0].latest.?.freshness,
    );
    try std.testing.expectEqualStrings(
        "gist-id",
        watched_latest.entries[0].latest.?.latest.matchedClaim().proofSlice(),
    );
    try std.testing.expectEqualStrings("bob", watched_latest.entries[1].target.identity);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileFreshness.stale,
        watched_latest.entries[1].latest.?.freshness,
    );
    try std.testing.expectEqualStrings(
        "gist-bob",
        watched_latest.entries[1].latest.?.latest.matchedClaim().proofSlice(),
    );
    try std.testing.expectEqualStrings("carol", watched_latest.entries[2].target.identity);
    try std.testing.expect(watched_latest.entries[2].latest == null);
    try std.testing.expectEqualStrings("alice", watched_latest.nextEntry().?.target.identity);
    try std.testing.expectEqualStrings("alice", watched_latest.nextStep().?.entry.target.identity);
    const watched_preferred = (try noztr_sdk.workflows.IdentityVerifier.getPreferredStoredProfileForTargets(
        profile_store.asStore(),
        .{
            .targets = watched_targets[0..],
            .now_unix_seconds = 31,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.workflows.IdentityStoredProfileTargetLatestFreshnessStorage.init(
                watched_matches[0..],
                watched_entries[0..],
            ),
        },
    )).?;
    try std.testing.expectEqualStrings("bob", watched_preferred.target.identity);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileFreshness.stale,
        watched_preferred.latest.freshness,
    );
    try std.testing.expectEqualStrings(
        "gist-bob",
        watched_preferred.latest.latest.matchedClaim().proofSlice(),
    );
    var watched_refresh_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    var watched_refresh_freshness: [3]noztr_sdk.workflows.IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var watched_refresh_entries: [2]noztr_sdk.workflows.IdentityStoredProfileTargetRefreshEntry = undefined;
    const watched_refresh = try noztr_sdk.workflows.IdentityVerifier.planStoredProfileRefreshForTargets(
        profile_store.asStore(),
        .{
            .targets = watched_targets[0..],
            .now_unix_seconds = 31,
            .max_age_seconds = 20,
            .storage = noztr_sdk.workflows.IdentityStoredProfileTargetRefreshStorage.init(
                watched_refresh_matches[0..],
                watched_refresh_freshness[0..],
                watched_refresh_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), watched_refresh.entries.len);
    try std.testing.expectEqualStrings("bob", watched_refresh.entries[0].target.identity);
    try std.testing.expectEqualStrings("alice", watched_refresh.entries[1].target.identity);
    try std.testing.expectEqualStrings("bob", watched_refresh.nextEntry().?.target.identity);

    var preferred_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    const preferred = (try noztr_sdk.workflows.IdentityVerifier.getPreferredStoredProfile(
        profile_store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 31,
            .max_age_seconds = 60,
            .matches = preferred_matches[0..],
            .fallback_policy = .require_fresh,
        },
    )).?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileFreshness.fresh,
        preferred.freshness,
    );
    try std.testing.expectEqual(@as(u64, 30), preferred.age_seconds);
    try std.testing.expectEqualStrings("alice", preferred.entry.matchedClaim().identitySlice());

    var runtime_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    var runtime_entries: [2]noztr_sdk.workflows.IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    const runtime = try noztr_sdk.workflows.IdentityVerifier.inspectStoredProfileRuntime(
        profile_store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 31,
            .max_age_seconds = 60,
            .storage = noztr_sdk.workflows.IdentityStoredProfileRuntimeStorage.init(
                runtime_matches[0..],
                runtime_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileRuntimeAction.use_preferred,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityStoredProfileRuntimeAction.use_preferred,
        next_step.action,
    );
    const next_entry = next_step.entry.?;
    try std.testing.expectEqualStrings(
        "alice",
        next_entry.matchedClaim().identitySlice(),
    );
    try std.testing.expectEqualStrings(
        runtime.preferredEntry().?.matchedClaim().proofSlice(),
        next_entry.matchedClaim().proofSlice(),
    );
    try std.testing.expectEqualStrings(
        "alice",
        runtime.preferredEntry().?.matchedClaim().identitySlice(),
    );

    var refresh_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    var refresh_freshness_entries: [2]noztr_sdk.workflows.IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [2]noztr_sdk.workflows.IdentityStoredProfileRefreshEntry = undefined;
    const refresh_plan = try noztr_sdk.workflows.IdentityVerifier.planStoredProfileRefresh(
        profile_store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 100,
            .max_age_seconds = 60,
            .storage = noztr_sdk.workflows.IdentityStoredProfileRefreshStorage.init(
                refresh_matches[0..],
                refresh_freshness_entries[0..],
                refresh_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), refresh_plan.entries.len);
    const refresh_step = refresh_plan.nextStep().?;
    try std.testing.expectEqualStrings("alice", refresh_step.entry.matchedClaim().identitySlice());
    try std.testing.expectEqualStrings(
        "alice",
        refresh_plan.newestEntry().?.matchedClaim().identitySlice(),
    );

    var offline_responses = [_]TestHttpResponse{};
    var offline_http = TestMultiHttp.init(offline_responses[0..]);
    var claims_buffer_again: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var verification_url_buffers_again: [4][256]u8 = undefined;
    var verification_text_buffers_again: [4][256]u8 = undefined;
    var verification_body_buffers_again: [4][512]u8 = undefined;
    var verification_storage_again: [4]noztr_sdk.workflows.IdentityVerificationStorage = undefined;
    for (&verification_storage_again, 0..) |*slot, index| {
        slot.* = noztr_sdk.workflows.IdentityVerificationStorage.init(
            verification_url_buffers_again[index][0..],
            verification_text_buffers_again[index][0..],
            verification_body_buffers_again[index][0..],
        );
    }
    var results_again: [4]noztr_sdk.workflows.IdentityClaimVerification = undefined;
    const cached_summary = try noztr_sdk.workflows.IdentityVerifier.verifyProfileCached(
        offline_http.client(),
        cache.asCache(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = noztr_sdk.workflows.IdentityProfileVerificationStorage.init(
                claims_buffer_again[0..],
                verification_storage_again[0..],
                results_again[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), cached_summary.verified_count);
    try std.testing.expectEqual(@as(usize, 2), cached_summary.cache_hit_count);
    try std.testing.expectEqual(@as(usize, 0), cached_summary.network_fetch_count);

    var latest_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    const latest = (try noztr_sdk.workflows.IdentityVerifier.getLatestStoredProfile(
        profile_store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .matches = latest_matches[0..],
        },
    )).?;
    try std.testing.expectEqualSlices(u8, pubkey[0..], latest.match.pubkey[0..]);
    try std.testing.expectEqualStrings("alice", latest.matchedClaim().identitySlice());

    var freshness_matches: [2]noztr_sdk.workflows.IdentityProfileMatch = undefined;
    const freshness = (try noztr_sdk.workflows.IdentityVerifier.getLatestStoredProfileFreshness(
        profile_store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 31,
            .max_age_seconds = 60,
            .matches = freshness_matches[0..],
        },
    )).?;
    try std.testing.expectEqual(noztr_sdk.workflows.IdentityStoredProfileFreshness.fresh, freshness.freshness);
    try std.testing.expectEqual(@as(u64, 30), freshness.age_seconds);
    try std.testing.expectEqualStrings("alice", freshness.latest.matchedClaim().identitySlice());
}

const TestHttpResponse = struct {
    url: []const u8,
    body: []const u8,
};

const TestMultiHttp = struct {
    responses: []const TestHttpResponse,

    fn init(responses: []const TestHttpResponse) TestMultiHttp {
        return .{ .responses = responses };
    }

    fn client(self: *TestMultiHttp) noztr_sdk.transport.HttpClient {
        return .{
            .ctx = self,
            .get_fn = get,
        };
    }

    fn get(
        ctx: *anyopaque,
        request: noztr_sdk.transport.HttpRequest,
        out: []u8,
    ) noztr_sdk.transport.HttpError![]const u8 {
        const self: *TestMultiHttp = @ptrCast(@alignCast(ctx));
        for (self.responses) |response| {
            if (!std.mem.eql(u8, request.url, response.url)) continue;
            if (response.body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..response.body.len], response.body);
            return out[0..response.body.len];
        }
        return error.NotFound;
    }
};
