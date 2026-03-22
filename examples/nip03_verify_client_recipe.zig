const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70,
    0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84,
    0xe8, 0x92, 0x94,
};
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

// Prepare one command-ready NIP-03 detached-proof verify job, run it over the explicit HTTP,
// proof-store, and remembered-verification seams, then inspect bounded remembered-proof runtime,
// grouped target policy, refresh cadence, refresh-batch selection, refresh readiness over the
// explicit archive seam, turn-policy, and refresh planning through the client route.
test "recipe: nip03 verify client prepares, remembers, and inspects proof planning" {
    const signer_secret = [_]u8{0x13} ** 32;
    const signer_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&signer_secret);
    var target = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = signer_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "hello",
        .tags = &.{},
    };
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &target);

    var proof_bytes: [96]u8 = undefined;
    const proof = buildLocalBitcoinProof(proof_bytes[0..], &target.id);
    var proof_b64: [256]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(proof_b64[0..], proof);
    const event_id_hex = std.fmt.bytesToHex(target.id, .lower);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", event_id_hex[0..] } },
        .{ .items = &.{ "k", "1" } },
    };
    const attestation_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x33} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1040,
        .created_at = 45,
        .content = encoded,
        .tags = tags[0..],
    };

    var http = http_fake.ExampleHttp.init("https://proof.example/hello.ots", proof);
    var fetched_proof: [128]u8 = undefined;
    var storage = noztr_sdk.client.proof.nip03.Nip03VerifyClientStorage.init(fetched_proof[0..]);
    var proof_store_records: [1]noztr_sdk.workflows.proof.nip03.OpenTimestampsProofRecord =
        [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsProofRecord{.{}} ** 1;
    var proof_store =
        noztr_sdk.workflows.proof.nip03.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [2]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRecord =
        [_]noztr_sdk.workflows.proof.nip03.OpenTimestampsStoredVerificationRecord{.{}} ** 2;
    var verification_store =
        noztr_sdk.workflows.proof.nip03.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const client = noztr_sdk.client.proof.nip03.Nip03VerifyClient.init(.{});
    const job = client.prepareVerifyJob(
        &storage,
        &target,
        &attestation_event,
        "https://proof.example/hello.ots",
    );
    const result = try client.verifyRemoteCachedAndRemember(
        http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &job,
    );

    try std.testing.expect(result == .verified);
    try std.testing.expectEqual(
        noztr_sdk.workflows.proof.nip03.OpenTimestampsVerificationStorePutOutcome.stored,
        result.verified.store_outcome,
    );

    const stale_target = try buildSignedTextEvent(0x44, 2, "stale");
    var stale_proof_bytes: [96]u8 = undefined;
    const stale_proof = buildLocalBitcoinProof(stale_proof_bytes[0..], &stale_target.id);
    try rememberVerificationForTarget(
        verification_store.asStore(),
        &stale_target,
        5,
        "https://proof.example/stale.ots",
        stale_proof,
    );

    var runtime_matches: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Match = undefined;
    var runtime_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.DiscoveryFreshnessEntry = undefined;
    const runtime = try client.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.RuntimeStorage.init(
                runtime_matches[0..],
                runtime_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(
        noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.RuntimeAction.use_preferred,
        runtime.action,
    );

    const targets = [_]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Target{
        .{ .target_event_id = target.id },
        .{ .target_event_id = stale_target.id },
    };
    var target_matches: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Match = undefined;
    var target_latest_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var policy_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetPolicyEntry = undefined;
    var policy_groups: [4]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetPolicyGroup = undefined;
    const policy_plan = try client.inspectStoredVerificationPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetPolicyStorage.init(
                target_matches[0..],
                target_latest_entries[0..],
                policy_entries[0..],
                policy_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 0), policy_plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), policy_plan.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), policy_plan.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 0), policy_plan.refresh_existing_count);
    try std.testing.expectEqualSlices(
        u8,
        target.id[0..],
        policy_plan.usablePreferredEntries()[0].target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        policy_plan.usablePreferredEntries()[1].target.target_event_id[0..],
    );

    var cadence_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceEntry = undefined;
    var cadence_groups: [5]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceGroup = undefined;
    const cadence_plan = try client.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceStorage.init(
                target_matches[0..],
                target_latest_entries[0..],
                cadence_entries[0..],
                cadence_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), cadence_plan.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 1), cadence_plan.stable_count);
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        cadence_plan.nextDueStep().?.entry.target.target_event_id[0..],
    );

    var batch_target_matches: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Match = undefined;
    var batch_target_latest_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var batch_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceEntry = undefined;
    var batch_groups: [5]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceGroup = undefined;
    const batch_plan = try client.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshBatchStorage.init(
                batch_target_matches[0..],
                batch_target_latest_entries[0..],
                batch_entries[0..],
                batch_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), batch_plan.selected_count);
    try std.testing.expectEqual(@as(u32, 0), batch_plan.deferred_count);
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        batch_plan.nextBatchStep().?.entry.target.target_event_id[0..],
    );

    var turn_policy_matches: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Match = undefined;
    var turn_policy_latest_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var turn_policy_cadence_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceEntry = undefined;
    var turn_policy_cadence_groups: [5]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshCadenceGroup = undefined;
    var turn_policy_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetTurnPolicyEntry = undefined;
    var turn_policy_groups: [4]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetTurnPolicyGroup = undefined;
    const turn_policy_plan = try client.inspectStoredVerificationTurnPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetTurnPolicyStorage.init(
                turn_policy_matches[0..],
                turn_policy_latest_entries[0..],
                turn_policy_cadence_entries[0..],
                turn_policy_cadence_groups[0..],
                turn_policy_entries[0..],
                turn_policy_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 0), turn_policy_plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), turn_policy_plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), turn_policy_plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 0), turn_policy_plan.defer_refresh_count);
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        turn_policy_plan.nextWorkStep().?.entry.target.target_event_id[0..],
    );

    var refresh_target_matches: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Match = undefined;
    var refresh_target_latest_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var refresh_entries: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.RefreshEntry = undefined;
    var refresh_targets: [2]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshEntry = undefined;
    const refresh_plan = try client.planStoredVerificationRefreshForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshStorage.init(
                refresh_target_matches[0..],
                refresh_target_latest_entries[0..],
                refresh_entries[0..],
                refresh_targets[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), refresh_plan.entries.len);
    try std.testing.expectEqualSlices(u8, stale_target.id[0..], refresh_plan.nextStep().?.entry.target.target_event_id[0..]);

    var archive_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(archive_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var target_json_storage: [512]u8 = undefined;
    const target_json = try noztr.nip01_event.event_serialize_json_object(
        target_json_storage[0..],
        &target,
    );
    try archive.ingestEventJson(target_json, arena.allocator());

    var attestation_archive_event = attestation_event;
    attestation_archive_event.tags = &.{};
    attestation_archive_event.content = "archive";
    var attestation_json_storage: [1024]u8 = undefined;
    const attestation_json = try noztr.nip01_event.event_serialize_json_object(
        attestation_json_storage[0..],
        &attestation_archive_event,
    );
    try archive.ingestEventJson(attestation_json, arena.allocator());

    const refresh_readiness_targets = [_]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Target{
        .{ .target_event_id = target.id },
    };
    var readiness_matches: [1]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.Match = undefined;
    var readiness_latest_entries: [1]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    const readiness_refresh_entries = [_]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.RefreshEntry{};
    var readiness_target_refresh_entries: [1]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshEntry = undefined;
    var readiness_target_records: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var readiness_attestation_records: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var readiness_entries: [1]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshReadinessEntry = undefined;
    var readiness_groups: [4]noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshReadinessGroup = undefined;
    const readiness_plan = try client.inspectStoredVerificationRefreshReadinessForTargets(
        verification_store.asStore(),
        archive,
        .{
            .targets = refresh_readiness_targets[0..],
            .now_unix_seconds = 200,
            .max_age_seconds = 20,
            .storage = noztr_sdk.client.proof.nip03.Nip03StoredVerificationPlanning.TargetRefreshReadinessStorage.init(
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
    try std.testing.expectEqual(@as(u32, 1), readiness_plan.ready_count);
    try std.testing.expectEqualSlices(
        u8,
        target.id[0..],
        readiness_plan.nextReadyStep().?.entry.target.target_event_id[0..],
    );
}

fn buildSignedTextEvent(secret_byte: u8, created_at: u64, content: []const u8) !noztr.nip01_event.Event {
    const signer_secret = [_]u8{secret_byte} ** 32;
    const signer_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&signer_secret);
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = signer_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = created_at,
        .content = content,
        .tags = &.{},
    };
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &event);
    return event;
}

fn rememberVerificationForTarget(
    verification_store: noztr_sdk.workflows.proof.nip03.OpenTimestampsVerificationStore,
    target_event: *const noztr.nip01_event.Event,
    attestation_created_at: u64,
    proof_url: []const u8,
    proof: []const u8,
) !void {
    var proof_b64_storage: [256]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(proof_b64_storage[0..], proof);
    const event_id_hex = std.fmt.bytesToHex(target_event.id, .lower);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", event_id_hex[0..] } },
        .{ .items = &.{ "k", "1" } },
    };
    const attestation_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x33} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1040,
        .created_at = attestation_created_at,
        .content = encoded,
        .tags = tags[0..],
    };
    var stored_attestation = attestation_event;
    stored_attestation.id[30] = @as(u8, @truncate(attestation_created_at));
    stored_attestation.id[31] = @as(u8, @truncate(proof_url.len));
    var proof_buffer: [128]u8 = undefined;
    const local = try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.verifyLocal(
        target_event,
        &stored_attestation,
        proof_buffer[0..],
    );
    try std.testing.expect(local == .verified);
    _ = try noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store,
        target_event,
        &stored_attestation,
        &.{ .proof_url = proof_url, .verification = local.verified },
    );
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
