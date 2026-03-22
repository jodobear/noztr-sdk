const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

// Prepare one command-ready NIP-39 profile-verify job over caller-owned buffers, run it over the
// explicit public HTTP seam, then inspect one bounded stored watched-target turn policy through
// the client surface.
test "recipe: nip39 verify client verifies and inspects stored watched target policy" {
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
    var fake_http = http_fake.ExampleHttp.init(
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
        .created_at = 45,
        .content = "",
        .tags = (&[_]noztr.nip01_event.EventTag{tag})[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &event);

    var claims: [1]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [1][256]u8 = undefined;
    var expected_buffers: [1][256]u8 = undefined;
    var body_buffers: [1][512]u8 = undefined;
    var verification: [1]noztr_sdk.workflows.IdentityVerificationStorage = undefined;
    verification[0] = noztr_sdk.workflows.IdentityVerificationStorage.init(
        url_buffers[0][0..],
        expected_buffers[0][0..],
        body_buffers[0][0..],
    );
    var results: [1]noztr_sdk.workflows.IdentityClaimVerification = undefined;
    var cache_records: [1]noztr_sdk.workflows.IdentityVerificationCacheRecord = undefined;
    var cache = noztr_sdk.workflows.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [2]noztr_sdk.workflows.IdentityProfileRecord = undefined;
    var profile_store = noztr_sdk.workflows.MemoryIdentityProfileStore.init(profile_records[0..]);

    const client = noztr_sdk.client.Nip39VerifyClient.init(.{});
    var storage = noztr_sdk.client.Nip39VerifyClientStorage.init(
        claims[0..],
        verification[0..],
        results[0..],
    );
    const job = client.prepareVerifyJob(&storage, &event, &pubkey);
    const result = try client.verifyProfileCachedAndRemember(
        fake_http.client(),
        cache.asCache(),
        profile_store.asStore(),
        job,
    );

    try std.testing.expectEqual(@as(usize, 1), result.summary.verified_count);
    try std.testing.expectEqual(@as(usize, 1), result.summary.network_fetch_count);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityProfileStorePutOutcome.stored,
        result.store_outcome,
    );

    const stale_pubkey = [_]u8{0x44} ** 32;
    const stale_summary = noztr_sdk.workflows.IdentityProfileVerificationSummary{
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
        &stale_pubkey,
        5,
        &stale_summary,
    );

    var watched_target_records: [4]noztr_sdk.workflows.IdentityWatchedTargetRecord = undefined;
    var watched_target_store = noztr_sdk.workflows.MemoryIdentityWatchedTargetStore.init(
        watched_target_records[0..],
    );
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "bob" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "alice" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "dave" });

    var listed_records: [4]noztr_sdk.client.Nip39StoredProfilePlanning.WatchedTargetRecord = undefined;
    var targets: [4]noztr_sdk.client.Nip39StoredProfilePlanning.Target = undefined;
    var matches: [2]noztr_sdk.client.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var latest_entries: [4]noztr_sdk.client.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var policy_entries: [4]noztr_sdk.client.Nip39StoredProfilePlanning.TargetPolicyEntry = undefined;
    var policy_groups: [4]noztr_sdk.client.Nip39StoredProfilePlanning.TargetPolicyGroup = undefined;
    var cadence_entries: [4]noztr_sdk.client.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var cadence_groups: [5]noztr_sdk.client.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var turn_entries: [4]noztr_sdk.client.Nip39StoredProfilePlanning.TargetTurnPolicyEntry = undefined;
    var turn_groups: [4]noztr_sdk.client.Nip39StoredProfilePlanning.TargetTurnPolicyGroup = undefined;

    const turn_policy = try client.inspectStoredWatchedTargetTurnPolicy(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 3,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.Nip39StoredProfilePlanning.StoredWatchedTargetTurnPolicyStorage.init(
                listed_records[0..],
                targets[0..],
                noztr_sdk.client.Nip39StoredProfilePlanning.TargetTurnPolicyStorage.init(
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
    try std.testing.expectEqual(@as(u32, 4), turn_policy.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), turn_policy.turn_policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), turn_policy.turn_policy.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), turn_policy.turn_policy.use_cached_count);
    try std.testing.expectEqual(@as(u32, 0), turn_policy.turn_policy.defer_refresh_count);
    try std.testing.expectEqualStrings("carol", turn_policy.verifyNowEntries()[0].target.identity);
    try std.testing.expectEqualStrings("dave", turn_policy.verifyNowEntries()[1].target.identity);
    try std.testing.expectEqualStrings("bob", turn_policy.refreshSelectedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("alice", turn_policy.useCachedEntries()[0].target.identity);
}
