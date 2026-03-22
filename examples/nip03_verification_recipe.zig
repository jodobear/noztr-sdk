const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");
const http_fake = @import("http_fake.zig");

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70,
    0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84,
    0xe8, 0x92, 0x94,
};
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

// Verify one detached OpenTimestamps proof document, remember the verification summary explicitly,
// classify remembered discovery entries for freshness, inspect one typed remembered runtime step,
// drive grouped remembered-target policy, refresh cadence, bounded refresh-batch selection,
// refresh readiness over the explicit archive seam, turn-policy, and refresh policy passes, then
// recover the latest remembered verification for the same target event.
test "recipe: sdk opentimestamps verifier fetches, remembers, classifies freshness, inspects remembered typed runtime step, and drives grouped remembered proof policy" {
    const signer_secret = [_]u8{0x13} ** 32;
    const signer_pubkey = try common.derivePublicKey(&signer_secret);
    var target = common.simpleEvent(1, signer_pubkey, 1, "hello", &.{});
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &target);
    const event_id_hex = std.fmt.bytesToHex(target.id, .lower);
    var proof_bytes: [96]u8 = undefined;
    const proof = buildLocalBitcoinProof(proof_bytes[0..], &target.id);
    var proof_b64: [256]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(proof_b64[0..], proof);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", event_id_hex[0..] } },
        .{ .items = &.{ "k", "1" } },
    };
    const attestation_event = common.simpleEvent(1040, [_]u8{0x33} ** 32, 2, encoded, tags[0..]);
    var fetched_proof: [128]u8 = undefined;
    var proof_store_records: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsProofRecord =
        [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsProofRecord{ .{}, .{} };
    var proof_store =
        noztr_sdk.workflows.proof.nip03.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRecord =
        [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRecord{ .{}, .{} };
    var verification_store =
        noztr_sdk.workflows.proof.nip03.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var http = http_fake.ExampleHttp.init("https://proof.example/hello.ots", proof);

    const outcome = try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
        http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &.{
            .target_event = &target,
            .attestation_event = &attestation_event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = fetched_proof[0..],
        },
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqual(@as(u32, 1), outcome.verified.verification.verification.attestation.target_kind);
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", outcome.verified.verification.proof_url);

    const cached = try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.verifyRemoteCached(
        http.client(),
        proof_store.asStore(),
        &.{
            .target_event = &target,
            .attestation_event = &attestation_event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = fetched_proof[0..],
        },
    );
    try std.testing.expect(cached == .verified);

    var latest_matches: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    const latest = (try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.getLatestStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .matches = latest_matches[0..],
        },
    )).?;
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", latest.proofUrl());

    var latest_freshness_matches: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    const latest_freshness =
        (try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.getLatestStoredVerificationFreshness(
            verification_store.asStore(),
            .{
                .target_event_id = &target.id,
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .matches = latest_freshness_matches[0..],
            },
        )).?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationFreshness.fresh,
        latest_freshness.freshness,
    );
    try std.testing.expectEqual(@as(u64, 60), latest_freshness.age_seconds);

    var preferred_matches: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var preferred_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    const preferred = (try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.getPreferredStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .now_unix_seconds = 62,
            .max_age_seconds = 120,
            .storage = noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage.init(
                preferred_matches[0..],
                preferred_entries[0..],
            ),
            .fallback_policy = .require_fresh,
        },
    )).?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationFreshness.fresh,
        preferred.freshness,
    );
    try std.testing.expectEqual(@as(u64, 60), preferred.age_seconds);

    var freshness_matches: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var freshness_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    const discovered_with_freshness =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(
            verification_store.asStore(),
            .{
                .target_event_id = &target.id,
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .storage = noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage.init(
                    freshness_matches[0..],
                    freshness_entries[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(usize, 1), discovered_with_freshness.len);
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationFreshness.fresh,
        discovered_with_freshness[0].freshness,
    );
    try std.testing.expectEqual(@as(u64, 60), discovered_with_freshness[0].age_seconds);

    var runtime_matches: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var runtime_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    const runtime = try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .now_unix_seconds = 62,
            .max_age_seconds = 120,
            .storage = noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeStorage.init(
                runtime_matches[0..],
                runtime_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeAction.use_preferred,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeAction.use_preferred,
        next_step.action,
    );
    const next_entry = next_step.entry.?;
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        next_entry.entry.verification.proofUrl(),
    );
    try std.testing.expectEqualStrings(
        runtime.preferredEntry().?.entry.verification.proofUrl(),
        next_entry.entry.verification.proofUrl(),
    );

    var refresh_matches: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var refresh_freshness_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshEntry = undefined;
    const refresh_plan = try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.planStoredVerificationRefresh(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .now_unix_seconds = 200,
            .max_age_seconds = 120,
            .storage = .init(
                refresh_matches[0..],
                refresh_freshness_entries[0..],
                refresh_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), refresh_plan.entries.len);
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        refresh_plan.newestEntry().?.entry.entry.verification.proofUrl(),
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        refresh_plan.nextStep().?.entry.entry.entry.verification.proofUrl(),
    );

    const grouped_targets = [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTarget{
        .{ .target_event_id = target.id },
        .{ .target_event_id = [_]u8{0x99} ** 32 },
    };
    var grouped_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_latest_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    const grouped_latest =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.discoverLatestStoredVerificationFreshnessForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .storage = .init(grouped_matches[0..], grouped_latest_entries[0..]),
            },
        );
    try std.testing.expectEqual(@as(usize, 2), grouped_latest.len);
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationFreshness.fresh,
        grouped_latest[0].latest.?.freshness,
    );
    try std.testing.expect(grouped_latest[1].latest == null);

    var grouped_preferred_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_preferred_freshness: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    var grouped_preferred_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsPreferredStoredVerificationTargetEntry = undefined;
    const grouped_preferred =
        (try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .storage = .init(
                    grouped_preferred_matches[0..],
                    grouped_preferred_freshness[0..],
                    grouped_preferred_entries[0..],
                ),
            },
    )).?;
    try std.testing.expectEqualSlices(u8, &target.id, &grouped_preferred.target.target_event_id);

    var grouped_policy_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_policy_latest: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    var grouped_policy_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyEntry = undefined;
    var grouped_policy_groups: [4]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyGroup = undefined;
    const grouped_policy =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .storage = .init(
                    grouped_policy_matches[0..],
                    grouped_policy_latest[0..],
                    grouped_policy_entries[0..],
                    grouped_policy_groups[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(u32, 1), grouped_policy.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), grouped_policy.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_policy.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_policy.refresh_existing_count);
    try std.testing.expectEqualSlices(
        u8,
        &grouped_targets[1].target_event_id,
        &grouped_policy.verifyNowEntries()[0].target.target_event_id,
    );
    try std.testing.expectEqualSlices(
        u8,
        &target.id,
        &grouped_policy.usablePreferredEntries()[0].target.target_event_id,
    );

    var grouped_cadence_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_cadence_latest: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    var grouped_cadence_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceEntry = undefined;
    var grouped_cadence_groups: [5]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceGroup = undefined;
    const grouped_cadence =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .refresh_soon_age_seconds = 50,
                .storage = .init(
                    grouped_cadence_matches[0..],
                    grouped_cadence_latest[0..],
                    grouped_cadence_entries[0..],
                    grouped_cadence_groups[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(u32, 1), grouped_cadence.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), grouped_cadence.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_cadence.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_cadence.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_cadence.stable_count);
    try std.testing.expectEqualSlices(
        u8,
        &grouped_targets[1].target_event_id,
        &grouped_cadence.nextDueEntry().?.target.target_event_id,
    );
    try std.testing.expectEqualSlices(
        u8,
        &target.id,
        &grouped_cadence.refreshSoonEntries()[0].target.target_event_id,
    );

    var grouped_batch_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_batch_latest: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    var grouped_batch_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceEntry = undefined;
    var grouped_batch_groups: [5]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceGroup = undefined;
    const grouped_batch =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .refresh_soon_age_seconds = 50,
                .max_selected = 1,
                .storage = .init(
                    grouped_batch_matches[0..],
                    grouped_batch_latest[0..],
                    grouped_batch_entries[0..],
                    grouped_batch_groups[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(u32, 1), grouped_batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), grouped_batch.deferred_count);
    try std.testing.expectEqualSlices(
        u8,
        &grouped_targets[1].target_event_id,
        &grouped_batch.nextBatchEntry().?.target.target_event_id,
    );
    try std.testing.expectEqualSlices(
        u8,
        &target.id,
        &grouped_batch.deferredEntries()[0].target.target_event_id,
    );

    var grouped_turn_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_turn_latest: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    var grouped_turn_cadence_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceEntry = undefined;
    var grouped_turn_cadence_groups: [5]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceGroup = undefined;
    var grouped_turn_entries: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyEntry = undefined;
    var grouped_turn_groups: [4]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyGroup = undefined;
    const grouped_turn =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .refresh_soon_age_seconds = 50,
                .max_selected = 1,
                .storage = .init(
                    grouped_turn_matches[0..],
                    grouped_turn_latest[0..],
                    grouped_turn_cadence_entries[0..],
                    grouped_turn_cadence_groups[0..],
                    grouped_turn_entries[0..],
                    grouped_turn_groups[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(u32, 1), grouped_turn.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_turn.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 0), grouped_turn.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), grouped_turn.defer_refresh_count);
    try std.testing.expectEqualSlices(
        u8,
        &grouped_targets[1].target_event_id,
        &grouped_turn.nextWorkStep().?.entry.target.target_event_id,
    );

    var grouped_refresh_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_refresh_freshness: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    const grouped_refresh_entries = [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshEntry{};
    var grouped_refresh_targets: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshEntry = undefined;
    const grouped_refresh =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(
            verification_store.asStore(),
            .{
                .targets = grouped_targets[0..],
                .now_unix_seconds = 200,
                .max_age_seconds = 120,
                .storage = .init(
                    grouped_refresh_matches[0..],
                    grouped_refresh_freshness[0..],
                    grouped_refresh_entries[0..],
                    grouped_refresh_targets[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(usize, 1), grouped_refresh.entries.len);
    try std.testing.expectEqualSlices(u8, &target.id, &grouped_refresh.nextEntry().?.target.target_event_id);
    try std.testing.expectEqualSlices(u8, &target.id, &grouped_refresh.nextStep().?.entry.target.target_event_id);

    var archive_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(archive_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var target_json_storage: [512]u8 = undefined;
    const target_json = try common.serializeEventJson(target_json_storage[0..], &target);
    try archive.ingestEventJson(target_json, arena.allocator());

    var attestation_archive_event = attestation_event;
    attestation_archive_event.tags = &.{};
    attestation_archive_event.content = "archive";
    var attestation_json_storage: [1024]u8 = undefined;
    const attestation_json = try common.serializeEventJson(
        attestation_json_storage[0..],
        &attestation_archive_event,
    );
    try archive.ingestEventJson(attestation_json, arena.allocator());

    const readiness_targets = [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTarget{
        .{ .target_event_id = target.id },
    };
    var readiness_matches: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationMatch = undefined;
    var readiness_latest_entries: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    const readiness_refresh_entries = [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshEntry{};
    var readiness_target_refresh_entries: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshEntry = undefined;
    var readiness_target_records: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var readiness_attestation_records: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var readiness_entries: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessEntry = undefined;
    var readiness_groups: [4]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessGroup = undefined;
    const readiness =
        try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRefreshReadinessForTargets(
            verification_store.asStore(),
            archive,
            .{
                .targets = readiness_targets[0..],
                .now_unix_seconds = 200,
                .max_age_seconds = 120,
                .storage = .init(
                    readiness_matches[0..],
                    readiness_latest_entries[0..],
                    readiness_refresh_entries[0..],
                    readiness_target_refresh_entries[0..],
                    readiness_target_records[0..],
                    readiness_attestation_records[0..],
                    readiness_entries[0..],
                    readiness_groups[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(u32, 1), readiness.ready_count);
    try std.testing.expectEqualSlices(u8, &target.id, &readiness.nextReadyEntry().?.target.target_event_id);
}

fn buildLocalBitcoinProof(output: []u8, digest: *const [32]u8) []const u8 {
    var index: usize = 0;
    @memcpy(output[index .. index + ots_header_magic.len], ots_header_magic[0..]);
    index += ots_header_magic.len;
    output[index] = 0x01;
    output[index + 1] = 0x08;
    index += 2;
    @memcpy(output[index .. index + digest.len], digest[0..]);
    index += digest.len;
    output[index] = 0x00;
    index += 1;
    @memcpy(output[index .. index + ots_bitcoin_tag.len], ots_bitcoin_tag[0..]);
    index += ots_bitcoin_tag.len;
    output[index] = 0x01;
    output[index + 1] = 0x2a;
    return output[0 .. index + 2];
}
