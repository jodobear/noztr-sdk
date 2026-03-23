const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const store = @import("../store/mod.zig");
const transport = @import("../transport/mod.zig");
const workflows = @import("../workflows/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70,
    0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84,
    0xe8, 0x92, 0x94,
};
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

pub const Nip03VerifyClientError =
    workflows.proof.nip03.OpenTimestampsRememberedRemoteVerificationError ||
    workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryError;
pub const Nip03StoredVerificationRefreshReadinessError =
    workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessError;

pub const Nip03VerifyClientConfig = struct {};

pub const Nip03VerifyClientStorage = struct {
    proof_buffer: []u8,
    accept: ?[]const u8 = null,

    pub fn init(proof_buffer: []u8) Nip03VerifyClientStorage {
        return .{
            .proof_buffer = proof_buffer,
            .accept = null,
        };
    }
};

pub const Nip03VerifyJob = workflows.proof.nip03.OpenTimestampsRemoteProofRequest;
pub const Nip03VerifyCachedResult = workflows.proof.nip03.OpenTimestampsRemoteVerificationOutcome;
pub const Nip03VerifyJobResult = workflows.proof.nip03.OpenTimestampsRememberedRemoteVerificationOutcome;

pub const Planning = struct {
    pub const Match = workflows.proof.nip03.OpenTimestampsStoredVerificationMatch;
    pub const DiscoveryEntry = workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryEntry;
    pub const Freshness = workflows.proof.nip03.OpenTimestampsStoredVerificationFreshness;
    pub const LatestFreshness = workflows.proof.nip03.OpenTimestampsLatestStoredVerificationFreshness;
    pub const DiscoveryFreshnessEntry = workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry;
    pub const DiscoveryFreshnessStorage = workflows.proof.nip03.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage;
    pub const LatestFreshnessRequest = workflows.proof.nip03.OpenTimestampsLatestStoredVerificationFreshnessRequest;
    pub const Target = workflows.proof.nip03.OpenTimestampsStoredVerificationTarget;
    pub const LatestTargetEntry = workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetEntry;
    pub const LatestTargetStorage = workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetStorage;
    pub const LatestTargetRequest = workflows.proof.nip03.OpenTimestampsLatestStoredVerificationTargetRequest;
    pub const FallbackPolicy = workflows.proof.nip03.OpenTimestampsStoredVerificationFallbackPolicy;
    pub const PreferredRequest = workflows.proof.nip03.OpenTimestampsPreferredStoredVerificationRequest;
    pub const Preferred = workflows.proof.nip03.OpenTimestampsPreferredStoredVerification;
    pub const PreferredTargetEntry = workflows.proof.nip03.OpenTimestampsPreferredStoredVerificationTargetEntry;
    pub const PreferredTargetStorage = workflows.proof.nip03.OpenTimestampsPreferredStoredVerificationTargetStorage;
    pub const PreferredTargetRequest = workflows.proof.nip03.OpenTimestampsPreferredStoredVerificationTargetRequest;
    pub const RuntimeAction = workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeAction;
    pub const RuntimeStorage = workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeStorage;
    pub const RuntimeRequest = workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeRequest;
    pub const RuntimePlan = workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimePlan;
    pub const RuntimeStep = workflows.proof.nip03.OpenTimestampsStoredVerificationRuntimeStep;
    pub const RefreshEntry = workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshEntry;
    pub const RefreshStorage = workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshStorage;
    pub const RefreshRequest = workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshRequest;
    pub const RefreshPlan = workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshPlan;
    pub const RefreshStep = workflows.proof.nip03.OpenTimestampsStoredVerificationRefreshStep;
    pub const TargetRefreshEntry = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshEntry;
    pub const TargetRefreshStorage = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshStorage;
    pub const TargetRefreshRequest = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshRequest;
    pub const TargetRefreshPlan = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshPlan;
    pub const TargetRefreshStep = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshStep;
    pub const TargetReadinessAction =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessAction;
    pub const TargetReadinessEntry =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessEntry;
    pub const TargetReadinessGroup =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessGroup;
    pub const TargetReadinessStorage =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessStorage;
    pub const TargetReadinessRequest =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessRequest;
    pub const TargetReadinessPlan =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessPlan;
    pub const TargetReadinessStep =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshReadinessStep;
    pub const TargetPolicyEntry = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyEntry;
    pub const TargetPolicyGroup = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyGroup;
    pub const TargetPolicyStorage = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyStorage;
    pub const TargetPolicyRequest = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyRequest;
    pub const TargetPolicyPlan = workflows.proof.nip03.OpenTimestampsStoredVerificationTargetPolicyPlan;
    pub const TargetCadenceAction =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceAction;
    pub const TargetCadenceEntry =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceEntry;
    pub const TargetCadenceGroup =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceGroup;
    pub const TargetCadenceStorage =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceStorage;
    pub const TargetCadenceRequest =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceRequest;
    pub const TargetCadencePlan =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadencePlan;
    pub const TargetCadenceStep =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshCadenceStep;
    pub const TargetBatchStorage =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshBatchStorage;
    pub const TargetBatchRequest =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshBatchRequest;
    pub const TargetBatchPlan =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshBatchPlan;
    pub const TargetBatchStep =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetRefreshBatchStep;
    pub const TargetTurnPolicyAction =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyAction;
    pub const TargetTurnPolicyEntry =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyEntry;
    pub const TargetTurnPolicyGroup =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyGroup;
    pub const TargetTurnPolicyStorage =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyStorage;
    pub const TargetTurnPolicyRequest =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyRequest;
    pub const TargetTurnPolicyPlan =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyPlan;
    pub const TargetTurnPolicyStep =
        workflows.proof.nip03.OpenTimestampsStoredVerificationTargetTurnPolicyStep;
};

pub const Nip03VerifyClient = struct {
    config: Nip03VerifyClientConfig,

    pub fn init(config: Nip03VerifyClientConfig) Nip03VerifyClient {
        return .{ .config = config };
    }

    pub fn prepareVerifyJob(
        self: *const Nip03VerifyClient,
        storage: *const Nip03VerifyClientStorage,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        proof_url: []const u8,
    ) Nip03VerifyJob {
        _ = self;
        return .{
            .target_event = target_event,
            .attestation_event = attestation_event,
            .proof_url = proof_url,
            .proof_buffer = storage.proof_buffer,
            .accept = storage.accept,
        };
    }

    pub fn verifyRemote(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyCachedResult {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.verifyRemote(http_client, job);
    }

    pub fn verifyRemoteCached(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        proof_store: workflows.proof.nip03.OpenTimestampsProofStore,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyCachedResult {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.verifyRemoteCached(http_client, proof_store, job);
    }

    pub fn verifyRemoteCachedAndRemember(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        proof_store: workflows.proof.nip03.OpenTimestampsProofStore,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyJobResult {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
            http_client,
            proof_store,
            verification_store,
            job,
        );
    }

    pub fn getLatestFreshness(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.LatestFreshnessRequest,
    ) Nip03VerifyClientError!?Planning.LatestFreshness {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.getLatestStoredVerificationFreshness(
            verification_store,
            request,
        );
    }

    pub fn discoverLatestForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.LatestTargetRequest,
    ) Nip03VerifyClientError![]const Planning.LatestTargetEntry {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.discoverLatestStoredVerificationFreshnessForTargets(
            verification_store,
            request,
        );
    }

    pub fn getPreferred(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.PreferredRequest,
    ) Nip03VerifyClientError!?Planning.Preferred {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.getPreferredStoredVerification(
            verification_store,
            request,
        );
    }

    pub fn getPreferredForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.PreferredTargetRequest,
    ) Nip03VerifyClientError!?Planning.PreferredTargetEntry {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectRuntime(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.RuntimeRequest,
    ) Nip03VerifyClientError!Planning.RuntimePlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRuntime(
            verification_store,
            request,
        );
    }

    pub fn planRefresh(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.RefreshRequest,
    ) Nip03VerifyClientError!Planning.RefreshPlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.planStoredVerificationRefresh(
            verification_store,
            request,
        );
    }

    pub fn planTargetRefresh(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.TargetRefreshRequest,
    ) Nip03VerifyClientError!Planning.TargetRefreshPlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectTargetReadiness(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        event_archive: store.EventArchive,
        request: Planning.TargetReadinessRequest,
    ) Nip03StoredVerificationRefreshReadinessError!Planning.TargetReadinessPlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRefreshReadinessForTargets(
            verification_store,
            event_archive,
            request,
        );
    }

    pub fn inspectTargetPolicy(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.TargetPolicyRequest,
    ) Nip03VerifyClientError!Planning.TargetPolicyPlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectTargetCadence(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.TargetCadenceRequest,
    ) Nip03VerifyClientError!Planning.TargetCadencePlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectTargetBatch(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.TargetBatchRequest,
    ) Nip03VerifyClientError!Planning.TargetBatchPlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectTargetTurnPolicy(
        self: *const Nip03VerifyClient,
        verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
        request: Planning.TargetTurnPolicyRequest,
    ) Nip03VerifyClientError!Planning.TargetTurnPolicyPlan {
        _ = self;
        return workflows.proof.nip03.OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
            verification_store,
            request,
        );
    }
};

test "nip03 verify client exposes caller-owned remote-proof storage" {
    var proof_buffer: [256]u8 = undefined;
    var storage = Nip03VerifyClientStorage.init(proof_buffer[0..]);
    storage.accept = "application/octet-stream";
    const client = Nip03VerifyClient.init(.{});
    _ = client;

    try std.testing.expectEqual(@as(usize, 256), storage.proof_buffer.len);
    try std.testing.expectEqualStrings("application/octet-stream", storage.accept.?);
}

test "nip03 verify client drives remembered remote verification through one command-ready surface" {
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
        .created_at = 2,
        .content = encoded,
        .tags = tags[0..],
    };

    var fake_http = workflow_testing.FakeHttp.init("https://proof.example/hello.ots", proof);
    var fetched_proof: [128]u8 = undefined;
    var storage = Nip03VerifyClientStorage.init(fetched_proof[0..]);
    var proof_store_records: [1]workflows.proof.nip03.OpenTimestampsProofRecord =
        [_]workflows.proof.nip03.OpenTimestampsProofRecord{.{}} ** 1;
    var proof_store = workflows.proof.nip03.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [1]workflows.proof.nip03.OpenTimestampsStoredVerificationRecord =
        [_]workflows.proof.nip03.OpenTimestampsStoredVerificationRecord{.{}} ** 1;
    var verification_store =
        workflows.proof.nip03.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const client = Nip03VerifyClient.init(.{});
    const job = client.prepareVerifyJob(
        &storage,
        &target,
        &attestation_event,
        "https://proof.example/hello.ots",
    );
    const remembered = try client.verifyRemoteCachedAndRemember(
        fake_http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &job,
    );
    try std.testing.expect(remembered == .verified);
    try std.testing.expectEqual(
        workflows.proof.nip03.OpenTimestampsVerificationStorePutOutcome.stored,
        remembered.verified.store_outcome,
    );

    const cached = try client.verifyRemoteCached(
        fake_http.client(),
        proof_store.asStore(),
        &job,
    );
    try std.testing.expect(cached == .verified);
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        cached.verified.proof_url,
    );
}

test "nip03 verify client lifts remembered proof planning into the client surface" {
    const fresh_target = try buildSignedTextEvent(0x21, 1, "fresh");
    const stale_target = try buildSignedTextEvent(0x22, 2, "stale");
    const missing_target = Planning.Target{
        .target_event_id = [_]u8{0x99} ** 32,
    };

    var verification_store_records: [2]workflows.proof.nip03.OpenTimestampsStoredVerificationRecord =
        [_]workflows.proof.nip03.OpenTimestampsStoredVerificationRecord{.{}} ** 2;
    var verification_store =
        workflows.proof.nip03.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    var fresh_proof_bytes: [96]u8 = undefined;
    const fresh_proof = buildLocalBitcoinProof(fresh_proof_bytes[0..], &fresh_target.id);
    try rememberVerificationForTarget(
        verification_store.asStore(),
        &fresh_target,
        45,
        "https://proof.example/fresh.ots",
        fresh_proof,
    );

    var stale_proof_bytes: [96]u8 = undefined;
    const stale_proof = buildLocalBitcoinProof(stale_proof_bytes[0..], &stale_target.id);
    try rememberVerificationForTarget(
        verification_store.asStore(),
        &stale_target,
        5,
        "https://proof.example/stale.ots",
        stale_proof,
    );

    const client = Nip03VerifyClient.init(.{});

    var fresh_matches: [2]Planning.Match = undefined;
    const latest_fresh = (try client.getLatestFreshness(
        verification_store.asStore(),
        .{
            .target_event_id = &fresh_target.id,
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .matches = fresh_matches[0..],
        },
    )).?;
    try std.testing.expectEqual(Planning.Freshness.fresh, latest_fresh.freshness);

    var runtime_matches: [2]Planning.Match = undefined;
    var runtime_entries: [2]Planning.DiscoveryFreshnessEntry = undefined;
    const runtime = try client.inspectRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &fresh_target.id,
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.RuntimeStorage.init(
                runtime_matches[0..],
                runtime_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(Planning.RuntimeAction.use_preferred, runtime.action);
    try std.testing.expectEqualStrings(
        "https://proof.example/fresh.ots",
        runtime.nextStep().entry.?.entry.verification.proofUrl(),
    );

    const targets = [_]Planning.Target{
        .{ .target_event_id = fresh_target.id },
        .{ .target_event_id = stale_target.id },
        missing_target,
    };
    var target_matches: [2]Planning.Match = undefined;
    var target_latest_entries: [3]Planning.LatestTargetEntry = undefined;
    const latest_entries = try client.discoverLatestForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .storage = Planning.LatestTargetStorage.init(
                target_matches[0..],
                target_latest_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(Planning.Freshness.fresh, latest_entries[0].latest.?.freshness);
    try std.testing.expectEqual(Planning.Freshness.stale, latest_entries[1].latest.?.freshness);
    try std.testing.expect(latest_entries[2].latest == null);

    var preferred_matches: [2]Planning.Match = undefined;
    var preferred_freshness_entries: [2]Planning.DiscoveryFreshnessEntry = undefined;
    var preferred_entries: [3]Planning.PreferredTargetEntry = undefined;
    const preferred = (try client.getPreferredForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.PreferredTargetStorage.init(
                preferred_matches[0..],
                preferred_freshness_entries[0..],
                preferred_entries[0..],
            ),
        },
    )).?;
    try std.testing.expectEqualSlices(u8, fresh_target.id[0..], preferred.target.target_event_id[0..]);

    var policy_target_matches: [2]Planning.Match = undefined;
    var policy_target_latest_entries: [3]Planning.LatestTargetEntry = undefined;
    var policy_entries: [3]Planning.TargetPolicyEntry = undefined;
    var policy_groups: [4]Planning.TargetPolicyGroup = undefined;
    const policy_plan = try client.inspectTargetPolicy(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.TargetPolicyStorage.init(
                policy_target_matches[0..],
                policy_target_latest_entries[0..],
                policy_entries[0..],
                policy_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), policy_plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), policy_plan.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), policy_plan.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 0), policy_plan.refresh_existing_count);
    try std.testing.expectEqualSlices(
        u8,
        missing_target.target_event_id[0..],
        policy_plan.verifyNowEntries()[0].target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        fresh_target.id[0..],
        policy_plan.usablePreferredEntries()[0].target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        policy_plan.usablePreferredEntries()[1].target.target_event_id[0..],
    );

    var refresh_target_matches: [2]Planning.Match = undefined;
    var refresh_target_latest_entries: [3]Planning.LatestTargetEntry = undefined;
    var refresh_entries: [3]Planning.RefreshEntry = undefined;
    var refresh_targets: [3]Planning.TargetRefreshEntry = undefined;
    const refresh_plan = try client.planTargetRefresh(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .storage = Planning.TargetRefreshStorage.init(
                refresh_target_matches[0..],
                refresh_target_latest_entries[0..],
                refresh_entries[0..],
                refresh_targets[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), refresh_plan.entries.len);
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        refresh_plan.nextStep().?.entry.target.target_event_id[0..],
    );

    var cadence_target_matches: [2]Planning.Match = undefined;
    var cadence_target_latest_entries: [3]Planning.LatestTargetEntry = undefined;
    var cadence_entries: [3]Planning.TargetCadenceEntry = undefined;
    var cadence_groups: [5]Planning.TargetCadenceGroup = undefined;
    const cadence_plan = try client.inspectTargetCadence(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.TargetCadenceStorage.init(
                cadence_target_matches[0..],
                cadence_target_latest_entries[0..],
                cadence_entries[0..],
                cadence_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), cadence_plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), cadence_plan.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 0), cadence_plan.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 0), cadence_plan.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), cadence_plan.stable_count);
    try std.testing.expectEqualSlices(
        u8,
        missing_target.target_event_id[0..],
        cadence_plan.nextDueStep().?.entry.target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        cadence_plan.usableWhileRefreshingEntries()[0].target.target_event_id[0..],
    );

    var batch_target_matches: [2]Planning.Match = undefined;
    var batch_target_latest_entries: [3]Planning.LatestTargetEntry = undefined;
    var batch_entries: [3]Planning.TargetCadenceEntry = undefined;
    var batch_groups: [5]Planning.TargetCadenceGroup = undefined;
    const batch_plan = try client.inspectTargetBatch(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.TargetBatchStorage.init(
                batch_target_matches[0..],
                batch_target_latest_entries[0..],
                batch_entries[0..],
                batch_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), batch_plan.selected_count);
    try std.testing.expectEqual(@as(u32, 1), batch_plan.deferred_count);
    try std.testing.expectEqualSlices(
        u8,
        missing_target.target_event_id[0..],
        batch_plan.nextBatchStep().?.entry.target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        batch_plan.deferredEntries()[0].target.target_event_id[0..],
    );

    var turn_policy_matches: [2]Planning.Match = undefined;
    var turn_policy_latest_entries: [3]Planning.LatestTargetEntry = undefined;
    var turn_policy_cadence_entries: [3]Planning.TargetCadenceEntry = undefined;
    var turn_policy_cadence_groups: [5]Planning.TargetCadenceGroup = undefined;
    var turn_policy_entries: [3]Planning.TargetTurnPolicyEntry = undefined;
    var turn_policy_groups: [4]Planning.TargetTurnPolicyGroup = undefined;
    const turn_policy_plan = try client.inspectTargetTurnPolicy(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Planning.TargetTurnPolicyStorage.init(
                turn_policy_matches[0..],
                turn_policy_latest_entries[0..],
                turn_policy_cadence_entries[0..],
                turn_policy_cadence_groups[0..],
                turn_policy_entries[0..],
                turn_policy_groups[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(u32, 1), turn_policy_plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), turn_policy_plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), turn_policy_plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), turn_policy_plan.defer_refresh_count);
    try std.testing.expectEqualSlices(
        u8,
        missing_target.target_event_id[0..],
        turn_policy_plan.nextWorkStep().?.entry.target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        fresh_target.id[0..],
        turn_policy_plan.useCachedEntries()[0].target.target_event_id[0..],
    );
    try std.testing.expectEqualSlices(
        u8,
        stale_target.id[0..],
        turn_policy_plan.deferredEntries()[0].target.target_event_id[0..],
    );
}

test "nip03 verify client lifts stored verification refresh readiness into the client surface" {
    const ready_target = try buildSignedTextEvent(0x31, 1, "ready");
    const blocked_target = try buildSignedTextEvent(0x32, 2, "blocked");

    var verification_store_records: [2]workflows.proof.nip03.OpenTimestampsStoredVerificationRecord =
        [_]workflows.proof.nip03.OpenTimestampsStoredVerificationRecord{ .{}, .{} };
    var verification_store =
        workflows.proof.nip03.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    var ready_proof_bytes: [96]u8 = undefined;
    const ready_proof = buildLocalBitcoinProof(ready_proof_bytes[0..], &ready_target.id);
    const ready_attestation = try rememberVerificationForTargetAndReturnAttestation(
        verification_store.asStore(),
        &ready_target,
        30,
        "https://proof.example/ready.ots",
        ready_proof,
    );

    var blocked_proof_bytes: [96]u8 = undefined;
    const blocked_proof = buildLocalBitcoinProof(blocked_proof_bytes[0..], &blocked_target.id);
    _ = try rememberVerificationForTargetAndReturnAttestation(
        verification_store.asStore(),
        &blocked_target,
        20,
        "https://proof.example/blocked.ots",
        blocked_proof,
    );

    var backing_store = store.MemoryClientStore{};
    const archive = store.EventArchive.init(backing_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var ready_target_json_storage: [512]u8 = undefined;
    const ready_target_json = try noztr.nip01_event.event_serialize_json_object(
        ready_target_json_storage[0..],
        &ready_target,
    );
    try archive.ingestEventJson(ready_target_json, arena.allocator());

    var ready_attestation_archive_event = ready_attestation;
    ready_attestation_archive_event.tags = &.{};
    ready_attestation_archive_event.content = "archive";
    var ready_attestation_json_storage: [1024]u8 = undefined;
    const ready_attestation_json = try noztr.nip01_event.event_serialize_json_object(
        ready_attestation_json_storage[0..],
        &ready_attestation_archive_event,
    );
    try archive.ingestEventJson(ready_attestation_json, arena.allocator());

    const client = Nip03VerifyClient.init(.{});
    const targets = [_]Planning.Target{
        .{ .target_event_id = ready_target.id },
        .{ .target_event_id = blocked_target.id },
    };
    var matches: [1]Planning.Match = undefined;
    var latest_entries: [2]Planning.LatestTargetEntry = undefined;
    const refresh_entries = [_]Planning.RefreshEntry{};
    var target_refresh_entries: [2]Planning.TargetRefreshEntry = undefined;
    var target_records: [1]store.ClientEventRecord = undefined;
    var attestation_records: [1]store.ClientEventRecord = undefined;
    var readiness_entries: [2]Planning.TargetReadinessEntry = undefined;
    var readiness_groups: [4]Planning.TargetReadinessGroup = undefined;
    const plan = try client.inspectTargetReadiness(
        verification_store.asStore(),
        archive,
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 10,
            .storage = Planning.TargetReadinessStorage.init(
                matches[0..],
                latest_entries[0..],
                refresh_entries[0..],
                target_refresh_entries[0..],
                target_records[0..],
                attestation_records[0..],
                readiness_entries[0..],
                readiness_groups[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.ready_count);
    try std.testing.expectEqual(@as(u32, 0), plan.missing_target_event_count);
    try std.testing.expectEqual(@as(u32, 0), plan.missing_attestation_event_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_events_count);
    try std.testing.expectEqualSlices(
        u8,
        ready_target.id[0..],
        plan.nextReadyStep().?.entry.target.target_event_id[0..],
    );
    try std.testing.expect(plan.targetRecord(plan.nextReadyEntry().?) != null);
    try std.testing.expect(plan.attestationRecord(plan.nextReadyEntry().?) != null);
    try std.testing.expectEqual(@as(usize, 1), plan.blockedEntries().len);
    try std.testing.expectEqual(
        Planning.TargetReadinessAction.missing_events,
        plan.blockedEntries()[0].action,
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

fn rememberVerificationForTargetAndReturnAttestation(
    verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
    target_event: *const noztr.nip01_event.Event,
    attestation_created_at: u64,
    proof_url: []const u8,
    proof: []const u8,
) !noztr.nip01_event.Event {
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
    const local = try workflows.proof.nip03.OpenTimestampsVerifier.verifyLocal(
        target_event,
        &stored_attestation,
        proof_buffer[0..],
    );
    try std.testing.expect(local == .verified);
    _ = try workflows.proof.nip03.OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store,
        target_event,
        &stored_attestation,
        &.{ .proof_url = proof_url, .verification = local.verified },
    );
    return stored_attestation;
}

fn rememberVerificationForTarget(
    verification_store: workflows.proof.nip03.OpenTimestampsVerificationStore,
    target_event: *const noztr.nip01_event.Event,
    attestation_created_at: u64,
    proof_url: []const u8,
    proof: []const u8,
) !void {
    _ = try rememberVerificationForTargetAndReturnAttestation(
        verification_store,
        target_event,
        attestation_created_at,
        proof_url,
        proof,
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
