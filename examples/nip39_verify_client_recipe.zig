const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

// Prepare one command-ready NIP-39 profile-verify job over caller-owned buffers, run it over the
// explicit public HTTP seam, then inspect both bounded remembered-identity strategy helpers and
// one stored watched-target long-lived planning route through the client surface.
test "recipe: nip39 verify client verifies and inspects remembered identity strategy plus stored watched target planning" {
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
    var verification: [1]noztr_sdk.workflows.identity.verify.IdentityVerificationStorage = undefined;
    verification[0] = noztr_sdk.workflows.identity.verify.IdentityVerificationStorage.init(
        url_buffers[0][0..],
        expected_buffers[0][0..],
        body_buffers[0][0..],
    );
    var results: [1]noztr_sdk.workflows.identity.verify.IdentityClaimVerification = undefined;
    var cache_records: [1]noztr_sdk.workflows.identity.verify.IdentityVerificationCacheRecord = undefined;
    var cache = noztr_sdk.workflows.identity.verify.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [2]noztr_sdk.workflows.identity.verify.IdentityProfileRecord = undefined;
    var profile_store = noztr_sdk.workflows.identity.verify.MemoryIdentityProfileStore.init(profile_records[0..]);

    const client = noztr_sdk.client.identity.nip39.Nip39VerifyClient.init(.{});
    var storage = noztr_sdk.client.identity.nip39.Nip39VerifyClientStorage.init(
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
        noztr_sdk.workflows.identity.verify.IdentityProfileStorePutOutcome.stored,
        result.store_outcome,
    );

    const stale_pubkey = [_]u8{0x44} ** 32;
    const stale_summary = noztr_sdk.workflows.identity.verify.IdentityProfileVerificationSummary{
        .claims = &[_]noztr_sdk.workflows.identity.verify.IdentityClaimVerification{
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
    _ = try noztr_sdk.workflows.identity.verify.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &stale_pubkey,
        5,
        &stale_summary,
    );

    var watched_target_records: [4]noztr_sdk.workflows.identity.verify.IdentityWatchedTargetRecord = undefined;
    var watched_target_store = noztr_sdk.workflows.identity.verify.MemoryIdentityWatchedTargetStore.init(
        watched_target_records[0..],
    );
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "bob" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "alice" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "dave" });

    var listed_records: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.WatchedTargetRecord = undefined;
    var targets: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.Target = undefined;
    var matches: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var latest_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var policy_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyEntry = undefined;
    var policy_groups: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyGroup = undefined;
    var cadence_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var cadence_groups: [5]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var batch_latest_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var batch_cadence_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var batch_cadence_groups: [5]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var orchestration_policy_matches: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var orchestration_policy_latest_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var orchestration_policy_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyEntry = undefined;
    var orchestration_policy_groups: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyGroup = undefined;
    var orchestration_cadence_matches: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var orchestration_cadence_latest_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var orchestration_cadence_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var orchestration_cadence_groups: [5]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var orchestration_batch_matches: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var orchestration_batch_latest_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var orchestration_batch_cadence_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var orchestration_batch_cadence_groups: [5]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var orchestration_turn_matches: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var orchestration_turn_latest_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var orchestration_turn_policy_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyEntry = undefined;
    var orchestration_turn_policy_groups: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyGroup = undefined;
    var orchestration_turn_cadence_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var orchestration_turn_cadence_groups: [5]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;
    var turn_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetTurnPolicyEntry = undefined;
    var turn_groups: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetTurnPolicyGroup = undefined;
    var orchestration_turn_entries: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetTurnPolicyEntry = undefined;
    var orchestration_turn_groups: [4]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetTurnPolicyGroup = undefined;

    const cadence = try client.inspectStoredWatchedTargetRefreshCadence(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.StoredWatchedTargetRefreshCadenceStorage.init(
                listed_records[0..],
                targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceStorage.init(
                    matches[0..],
                    latest_entries[0..],
                    cadence_entries[0..],
                    cadence_groups[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 4), cadence.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), cadence.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), cadence.cadence.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 1), cadence.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 0), cadence.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), cadence.cadence.stable_count);
    try std.testing.expectEqualStrings("carol", cadence.nextDueEntry().?.target.identity);

    const batch = try client.inspectStoredWatchedTargetRefreshBatch(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.StoredWatchedTargetRefreshBatchStorage.init(
                listed_records[0..],
                targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshBatchStorage.init(
                    matches[0..],
                    batch_latest_entries[0..],
                    batch_cadence_entries[0..],
                    batch_cadence_groups[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 4), batch.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), batch.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), batch.batch.deferred_count);
    try std.testing.expectEqualStrings("carol", batch.selectedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("dave", batch.selectedEntries()[1].target.identity);
    try std.testing.expectEqualStrings("bob", batch.deferredEntries()[0].target.identity);

    const turn_policy = try client.inspectStoredWatchedTargetTurnPolicy(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 3,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.StoredWatchedTargetTurnPolicyStorage.init(
                listed_records[0..],
                targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetTurnPolicyStorage.init(
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

    const orchestration = try client.inspectStoredWatchedTargetOrchestration(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.StoredWatchedTargetOrchestrationStorage.init(
                listed_records[0..],
                targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetPolicyStorage.init(
                    orchestration_policy_matches[0..],
                    orchestration_policy_latest_entries[0..],
                    orchestration_policy_entries[0..],
                    orchestration_policy_groups[0..],
                ),
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceStorage.init(
                    orchestration_cadence_matches[0..],
                    orchestration_cadence_latest_entries[0..],
                    orchestration_cadence_entries[0..],
                    orchestration_cadence_groups[0..],
                ),
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshBatchStorage.init(
                    orchestration_batch_matches[0..],
                    orchestration_batch_latest_entries[0..],
                    orchestration_batch_cadence_entries[0..],
                    orchestration_batch_cadence_groups[0..],
                ),
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetTurnPolicyStorage.init(
                    orchestration_turn_matches[0..],
                    orchestration_turn_latest_entries[0..],
                    orchestration_turn_policy_entries[0..],
                    orchestration_turn_policy_groups[0..],
                    orchestration_turn_cadence_entries[0..],
                    orchestration_turn_cadence_groups[0..],
                    orchestration_turn_entries[0..],
                    orchestration_turn_groups[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 4), orchestration.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), orchestration.policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.policy.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.policy.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 2), orchestration.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 0), orchestration.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.cadence.stable_count);
    try std.testing.expectEqual(@as(u32, 2), orchestration.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.batch.deferred_count);
    try std.testing.expectEqual(@as(u32, 2), orchestration.turn.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), orchestration.turn.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.turn.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), orchestration.turn.defer_refresh_count);
    try std.testing.expectEqualStrings("carol", orchestration.nextDueStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("carol", orchestration.nextRefreshBatchStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("carol", orchestration.nextWorkStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("alice", orchestration.useCachedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", orchestration.deferredEntries()[0].target.identity);

    var remembered_records: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.RememberedIdentityRecord = undefined;
    var remembered_targets: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.Target = undefined;
    var remembered_matches: [1]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.ProfileMatch = undefined;
    var remembered_latest_entries: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessEntry = undefined;
    var remembered_cadence_entries: [2]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceEntry = undefined;
    var remembered_cadence_groups: [5]noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceGroup = undefined;

    const remembered_freshness = try client.inspectRememberedIdentityLatestFreshness(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.RememberedIdentityLatestFreshnessStorage.init(
                remembered_records[0..],
                remembered_targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetLatestFreshnessStorage.init(
                    remembered_matches[0..],
                    remembered_latest_entries[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 2), remembered_freshness.remembered_identity_count);
    try std.testing.expectEqual(@as(u32, 1), remembered_freshness.freshness.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), remembered_freshness.freshness.stale_count);
    try std.testing.expectEqualStrings("bob", remembered_freshness.nextEntry().?.target.identity);

    const remembered_cadence = try client.inspectRememberedIdentityRefreshCadence(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.RememberedIdentityRefreshCadenceStorage.init(
                remembered_records[0..],
                remembered_targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshCadenceStorage.init(
                    remembered_matches[0..],
                    remembered_latest_entries[0..],
                    remembered_cadence_entries[0..],
                    remembered_cadence_groups[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 2), remembered_cadence.remembered_identity_count);
    try std.testing.expectEqual(@as(u32, 0), remembered_cadence.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), remembered_cadence.cadence.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 1), remembered_cadence.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 0), remembered_cadence.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), remembered_cadence.cadence.stable_count);
    try std.testing.expectEqualStrings("bob", remembered_cadence.nextDueEntry().?.target.identity);

    const remembered_batch = try client.inspectRememberedIdentityRefreshBatch(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.RememberedIdentityRefreshBatchStorage.init(
                remembered_records[0..],
                remembered_targets[0..],
                noztr_sdk.client.identity.nip39.Nip39StoredProfilePlanning.TargetRefreshBatchStorage.init(
                    remembered_matches[0..],
                    remembered_latest_entries[0..],
                    remembered_cadence_entries[0..],
                    remembered_cadence_groups[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 2), remembered_batch.remembered_identity_count);
    try std.testing.expectEqual(@as(u32, 1), remembered_batch.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 0), remembered_batch.batch.deferred_count);
    try std.testing.expectEqualStrings("bob", remembered_batch.selectedEntries()[0].target.identity);
}
