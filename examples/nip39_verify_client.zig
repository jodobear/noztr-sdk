const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

const identity_client = noztr_sdk.client.identity.nip39;
const identity_workflow = noztr_sdk.workflows.identity.verify;
const Planning = identity_client.Planning;

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

    var built_tag: noztr.nip39_external_identities.TagBuilder = undefined;
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
    var verification: [1]identity_workflow.IdentityVerificationStorage = undefined;
    verification[0] = identity_workflow.IdentityVerificationStorage.init(
        url_buffers[0][0..],
        expected_buffers[0][0..],
        body_buffers[0][0..],
    );
    var results: [1]identity_workflow.IdentityClaimVerification = undefined;
    var cache_records: [1]identity_workflow.IdentityVerificationCacheRecord = undefined;
    var cache = identity_workflow.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [2]identity_workflow.IdentityProfileRecord = undefined;
    var profile_store = identity_workflow.MemoryIdentityProfileStore.init(profile_records[0..]);

    const client = identity_client.Nip39VerifyClient.init(.{});
    var storage = identity_client.Nip39VerifyClientStorage.init(
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
        identity_workflow.IdentityProfileStorePutOutcome.stored,
        result.store_outcome,
    );

    const stale_pubkey = [_]u8{0x44} ** 32;
    const stale_summary = identity_workflow.IdentityProfileVerificationSummary{
        .claims = &[_]identity_workflow.IdentityClaimVerification{
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
    _ = try identity_workflow.IdentityVerifier.rememberProfileSummary(
        profile_store.asStore(),
        &stale_pubkey,
        5,
        &stale_summary,
    );

    var watched_target_records: [4]identity_workflow.IdentityWatchedTargetRecord = undefined;
    var watched_target_store = identity_workflow.MemoryIdentityWatchedTargetStore.init(
        watched_target_records[0..],
    );
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "carol" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "bob" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "alice" });
    _ = try watched_target_store.rememberTarget(.{ .provider = .github, .identity = "dave" });

    var listed_records: [4]Planning.Record.Watched = undefined;
    var targets: [4]Planning.Target.Value = undefined;
    var matches: [2]Planning.Match = undefined;
    var latest_entries: [4]Planning.Target.Latest.Entry = undefined;
    var policy_entries: [4]Planning.Target.Policy.Entry = undefined;
    var policy_groups: [4]Planning.Target.Policy.Group = undefined;
    var cadence_entries: [4]Planning.Target.Cadence.Entry = undefined;
    var cadence_groups: [5]Planning.Target.Cadence.Group = undefined;
    var batch_latest_entries: [4]Planning.Target.Latest.Entry = undefined;
    var batch_cadence_entries: [4]Planning.Target.Cadence.Entry = undefined;
    var batch_cadence_groups: [5]Planning.Target.Cadence.Group = undefined;
    var runtime_policy_matches: [2]Planning.Match = undefined;
    var runtime_policy_latest_entries: [4]Planning.Target.Latest.Entry = undefined;
    var runtime_policy_entries: [4]Planning.Target.Policy.Entry = undefined;
    var runtime_policy_groups: [4]Planning.Target.Policy.Group = undefined;
    var runtime_cadence_matches: [2]Planning.Match = undefined;
    var runtime_cadence_latest_entries: [4]Planning.Target.Latest.Entry = undefined;
    var runtime_cadence_entries: [4]Planning.Target.Cadence.Entry = undefined;
    var runtime_cadence_groups: [5]Planning.Target.Cadence.Group = undefined;
    var runtime_batch_matches: [2]Planning.Match = undefined;
    var runtime_batch_latest_entries: [4]Planning.Target.Latest.Entry = undefined;
    var runtime_batch_cadence_entries: [4]Planning.Target.Cadence.Entry = undefined;
    var runtime_batch_cadence_groups: [5]Planning.Target.Cadence.Group = undefined;
    var runtime_turn_matches: [2]Planning.Match = undefined;
    var runtime_turn_latest_entries: [4]Planning.Target.Latest.Entry = undefined;
    var runtime_turn_policy_entries: [4]Planning.Target.Policy.Entry = undefined;
    var runtime_turn_policy_groups: [4]Planning.Target.Policy.Group = undefined;
    var runtime_turn_cadence_entries: [4]Planning.Target.Cadence.Entry = undefined;
    var runtime_turn_cadence_groups: [5]Planning.Target.Cadence.Group = undefined;
    var turn_entries: [4]Planning.Target.Turn.Entry = undefined;
    var turn_groups: [4]Planning.Target.Turn.Group = undefined;
    var runtime_turn_entries: [4]Planning.Target.Turn.Entry = undefined;
    var runtime_turn_groups: [4]Planning.Target.Turn.Group = undefined;

    const cadence = try client.inspectWatchedCadence(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.Watched.Cadence.Storage.init(
                listed_records[0..],
                targets[0..],
                Planning.Target.Cadence.Storage.init(
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

    const batch = try client.inspectWatchedBatch(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.Watched.Batch.Storage.init(
                listed_records[0..],
                targets[0..],
                Planning.Target.Batch.Storage.init(
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

    const turn_policy = try client.inspectWatchedTurnPolicy(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 3,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.Watched.Turn.Storage.init(
                listed_records[0..],
                targets[0..],
                Planning.Target.Turn.Storage.init(
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

    const runtime = try client.inspectWatchedRuntime(
        profile_store.asStore(),
        watched_target_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.Watched.Runtime.Storage.init(
                listed_records[0..],
                targets[0..],
                Planning.Target.Policy.Storage.init(
                    runtime_policy_matches[0..],
                    runtime_policy_latest_entries[0..],
                    runtime_policy_entries[0..],
                    runtime_policy_groups[0..],
                ),
                Planning.Target.Cadence.Storage.init(
                    runtime_cadence_matches[0..],
                    runtime_cadence_latest_entries[0..],
                    runtime_cadence_entries[0..],
                    runtime_cadence_groups[0..],
                ),
                Planning.Target.Batch.Storage.init(
                    runtime_batch_matches[0..],
                    runtime_batch_latest_entries[0..],
                    runtime_batch_cadence_entries[0..],
                    runtime_batch_cadence_groups[0..],
                ),
                Planning.Target.Turn.Storage.init(
                    runtime_turn_matches[0..],
                    runtime_turn_latest_entries[0..],
                    runtime_turn_policy_entries[0..],
                    runtime_turn_policy_groups[0..],
                    runtime_turn_cadence_entries[0..],
                    runtime_turn_cadence_groups[0..],
                    runtime_turn_entries[0..],
                    runtime_turn_groups[0..],
                ),
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 4), runtime.watched_target_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.policy.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.policy.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.cadence.stable_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.batch.deferred_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.turn.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.turn.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.turn.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.turn.defer_refresh_count);
    try std.testing.expectEqualStrings("carol", runtime.nextDueStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("carol", runtime.nextRefreshBatchStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("carol", runtime.nextWorkStep().?.entry.target.identity);
    try std.testing.expectEqualStrings("alice", runtime.useCachedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", runtime.deferredEntries()[0].target.identity);

    var remembered_records: [2]Planning.Record.Remembered = undefined;
    var remembered_targets: [2]Planning.Target.Value = undefined;
    var remembered_matches: [1]Planning.Match = undefined;
    var remembered_latest_entries: [2]Planning.Target.Latest.Entry = undefined;
    var remembered_cadence_entries: [2]Planning.Target.Cadence.Entry = undefined;
    var remembered_cadence_groups: [5]Planning.Target.Cadence.Group = undefined;

    const remembered_freshness = try client.inspectRememberedFreshness(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = Planning.Remembered.Freshness.Storage.init(
                remembered_records[0..],
                remembered_targets[0..],
                Planning.Target.Latest.Storage.init(
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

    const remembered_cadence = try client.inspectRememberedCadence(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.Remembered.Cadence.Storage.init(
                remembered_records[0..],
                remembered_targets[0..],
                Planning.Target.Cadence.Storage.init(
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

    const remembered_batch = try client.inspectRememberedBatch(
        profile_store.asStore(),
        .{
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.Remembered.Batch.Storage.init(
                remembered_records[0..],
                remembered_targets[0..],
                Planning.Target.Batch.Storage.init(
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
