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
// drive one grouped remembered-target policy pass, then recover the latest remembered verification
// for the same target event.
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
    var proof_store_records: [2]noztr_sdk.workflows.OpenTimestampsProofRecord =
        [_]noztr_sdk.workflows.OpenTimestampsProofRecord{ .{}, .{} };
    var proof_store =
        noztr_sdk.workflows.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationRecord =
        [_]noztr_sdk.workflows.OpenTimestampsStoredVerificationRecord{ .{}, .{} };
    var verification_store =
        noztr_sdk.workflows.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var http = http_fake.ExampleHttp.init("https://proof.example/hello.ots", proof);

    const outcome = try noztr_sdk.workflows.OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
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

    const cached = try noztr_sdk.workflows.OpenTimestampsVerifier.verifyRemoteCached(
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

    var latest_matches: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    const latest = (try noztr_sdk.workflows.OpenTimestampsVerifier.getLatestStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .matches = latest_matches[0..],
        },
    )).?;
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", latest.proofUrl());

    var latest_freshness_matches: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    const latest_freshness =
        (try noztr_sdk.workflows.OpenTimestampsVerifier.getLatestStoredVerificationFreshness(
            verification_store.asStore(),
            .{
                .target_event_id = &target.id,
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .matches = latest_freshness_matches[0..],
            },
        )).?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.OpenTimestampsStoredVerificationFreshness.fresh,
        latest_freshness.freshness,
    );
    try std.testing.expectEqual(@as(u64, 60), latest_freshness.age_seconds);

    var preferred_matches: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var preferred_entries: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    const preferred = (try noztr_sdk.workflows.OpenTimestampsVerifier.getPreferredStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .now_unix_seconds = 62,
            .max_age_seconds = 120,
            .storage = noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage.init(
                preferred_matches[0..],
                preferred_entries[0..],
            ),
            .fallback_policy = .require_fresh,
        },
    )).?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.OpenTimestampsStoredVerificationFreshness.fresh,
        preferred.freshness,
    );
    try std.testing.expectEqual(@as(u64, 60), preferred.age_seconds);

    var freshness_matches: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var freshness_entries: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    const discovered_with_freshness =
        try noztr_sdk.workflows.OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(
            verification_store.asStore(),
            .{
                .target_event_id = &target.id,
                .now_unix_seconds = 62,
                .max_age_seconds = 120,
                .storage = noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage.init(
                    freshness_matches[0..],
                    freshness_entries[0..],
                ),
            },
        );
    try std.testing.expectEqual(@as(usize, 1), discovered_with_freshness.len);
    try std.testing.expectEqual(
        noztr_sdk.workflows.OpenTimestampsStoredVerificationFreshness.fresh,
        discovered_with_freshness[0].freshness,
    );
    try std.testing.expectEqual(@as(u64, 60), discovered_with_freshness[0].age_seconds);

    var runtime_matches: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var runtime_entries: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    const runtime = try noztr_sdk.workflows.OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target.id,
            .now_unix_seconds = 62,
            .max_age_seconds = 120,
            .storage = noztr_sdk.workflows.OpenTimestampsStoredVerificationRuntimeStorage.init(
                runtime_matches[0..],
                runtime_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(
        noztr_sdk.workflows.OpenTimestampsStoredVerificationRuntimeAction.use_preferred,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(
        noztr_sdk.workflows.OpenTimestampsStoredVerificationRuntimeAction.use_preferred,
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

    var refresh_matches: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var refresh_freshness_entries: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [2]noztr_sdk.workflows.OpenTimestampsStoredVerificationRefreshEntry = undefined;
    const refresh_plan = try noztr_sdk.workflows.OpenTimestampsVerifier.planStoredVerificationRefresh(
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

    const grouped_targets = [_]noztr_sdk.workflows.OpenTimestampsStoredVerificationTarget{
        .{ .target_event_id = target.id },
        .{ .target_event_id = [_]u8{0x99} ** 32 },
    };
    var grouped_matches: [1]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_latest_entries: [2]noztr_sdk.workflows.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    const grouped_latest =
        try noztr_sdk.workflows.OpenTimestampsVerifier.discoverLatestStoredVerificationFreshnessForTargets(
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
        noztr_sdk.workflows.OpenTimestampsStoredVerificationFreshness.fresh,
        grouped_latest[0].latest.?.freshness,
    );
    try std.testing.expect(grouped_latest[1].latest == null);

    var grouped_preferred_matches: [1]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_preferred_freshness: [1]noztr_sdk.workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    var grouped_preferred_entries: [2]noztr_sdk.workflows.OpenTimestampsPreferredStoredVerificationTargetEntry = undefined;
    const grouped_preferred =
        (try noztr_sdk.workflows.OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
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

    var grouped_refresh_matches: [1]noztr_sdk.workflows.OpenTimestampsStoredVerificationMatch = undefined;
    var grouped_refresh_freshness: [2]noztr_sdk.workflows.OpenTimestampsLatestStoredVerificationTargetEntry = undefined;
    const grouped_refresh_entries = [_]noztr_sdk.workflows.OpenTimestampsStoredVerificationRefreshEntry{};
    var grouped_refresh_targets: [1]noztr_sdk.workflows.OpenTimestampsStoredVerificationTargetRefreshEntry = undefined;
    const grouped_refresh =
        try noztr_sdk.workflows.OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(
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
