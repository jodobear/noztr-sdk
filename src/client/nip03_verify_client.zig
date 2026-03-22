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
    workflows.OpenTimestampsRememberedRemoteVerificationError ||
    workflows.OpenTimestampsStoredVerificationDiscoveryError;
pub const Nip03StoredVerificationRefreshReadinessError =
    workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessError;

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

pub const Nip03VerifyJob = workflows.OpenTimestampsRemoteProofRequest;
pub const Nip03VerifyCachedResult = workflows.OpenTimestampsRemoteVerificationOutcome;
pub const Nip03VerifyJobResult = workflows.OpenTimestampsRememberedRemoteVerificationOutcome;

pub const Nip03StoredVerificationPlanning = struct {
    pub const Match = workflows.OpenTimestampsStoredVerificationMatch;
    pub const DiscoveryEntry = workflows.OpenTimestampsStoredVerificationDiscoveryEntry;
    pub const Freshness = workflows.OpenTimestampsStoredVerificationFreshness;
    pub const LatestFreshness = workflows.OpenTimestampsLatestStoredVerificationFreshness;
    pub const DiscoveryFreshnessEntry = workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry;
    pub const DiscoveryFreshnessStorage = workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage;
    pub const LatestFreshnessRequest = workflows.OpenTimestampsLatestStoredVerificationFreshnessRequest;
    pub const Target = workflows.OpenTimestampsStoredVerificationTarget;
    pub const LatestTargetEntry = workflows.OpenTimestampsLatestStoredVerificationTargetEntry;
    pub const LatestTargetStorage = workflows.OpenTimestampsLatestStoredVerificationTargetStorage;
    pub const LatestTargetRequest = workflows.OpenTimestampsLatestStoredVerificationTargetRequest;
    pub const FallbackPolicy = workflows.OpenTimestampsStoredVerificationFallbackPolicy;
    pub const PreferredRequest = workflows.OpenTimestampsPreferredStoredVerificationRequest;
    pub const Preferred = workflows.OpenTimestampsPreferredStoredVerification;
    pub const PreferredTargetEntry = workflows.OpenTimestampsPreferredStoredVerificationTargetEntry;
    pub const PreferredTargetStorage = workflows.OpenTimestampsPreferredStoredVerificationTargetStorage;
    pub const PreferredTargetRequest = workflows.OpenTimestampsPreferredStoredVerificationTargetRequest;
    pub const RuntimeAction = workflows.OpenTimestampsStoredVerificationRuntimeAction;
    pub const RuntimeStorage = workflows.OpenTimestampsStoredVerificationRuntimeStorage;
    pub const RuntimeRequest = workflows.OpenTimestampsStoredVerificationRuntimeRequest;
    pub const RuntimePlan = workflows.OpenTimestampsStoredVerificationRuntimePlan;
    pub const RuntimeStep = workflows.OpenTimestampsStoredVerificationRuntimeStep;
    pub const RefreshEntry = workflows.OpenTimestampsStoredVerificationRefreshEntry;
    pub const RefreshStorage = workflows.OpenTimestampsStoredVerificationRefreshStorage;
    pub const RefreshRequest = workflows.OpenTimestampsStoredVerificationRefreshRequest;
    pub const RefreshPlan = workflows.OpenTimestampsStoredVerificationRefreshPlan;
    pub const RefreshStep = workflows.OpenTimestampsStoredVerificationRefreshStep;
    pub const TargetRefreshEntry = workflows.OpenTimestampsStoredVerificationTargetRefreshEntry;
    pub const TargetRefreshStorage = workflows.OpenTimestampsStoredVerificationTargetRefreshStorage;
    pub const TargetRefreshRequest = workflows.OpenTimestampsStoredVerificationTargetRefreshRequest;
    pub const TargetRefreshPlan = workflows.OpenTimestampsStoredVerificationTargetRefreshPlan;
    pub const TargetRefreshStep = workflows.OpenTimestampsStoredVerificationTargetRefreshStep;
    pub const TargetRefreshReadinessAction =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessAction;
    pub const TargetRefreshReadinessEntry =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessEntry;
    pub const TargetRefreshReadinessGroup =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessGroup;
    pub const TargetRefreshReadinessStorage =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessStorage;
    pub const TargetRefreshReadinessRequest =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessRequest;
    pub const TargetRefreshReadinessPlan =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessPlan;
    pub const TargetRefreshReadinessStep =
        workflows.OpenTimestampsStoredVerificationTargetRefreshReadinessStep;
    pub const TargetPolicyEntry = workflows.OpenTimestampsStoredVerificationTargetPolicyEntry;
    pub const TargetPolicyGroup = workflows.OpenTimestampsStoredVerificationTargetPolicyGroup;
    pub const TargetPolicyStorage = workflows.OpenTimestampsStoredVerificationTargetPolicyStorage;
    pub const TargetPolicyRequest = workflows.OpenTimestampsStoredVerificationTargetPolicyRequest;
    pub const TargetPolicyPlan = workflows.OpenTimestampsStoredVerificationTargetPolicyPlan;
    pub const TargetRefreshCadenceAction =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadenceAction;
    pub const TargetRefreshCadenceEntry =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadenceEntry;
    pub const TargetRefreshCadenceGroup =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadenceGroup;
    pub const TargetRefreshCadenceStorage =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadenceStorage;
    pub const TargetRefreshCadenceRequest =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadenceRequest;
    pub const TargetRefreshCadencePlan =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadencePlan;
    pub const TargetRefreshCadenceStep =
        workflows.OpenTimestampsStoredVerificationTargetRefreshCadenceStep;
    pub const TargetRefreshBatchStorage =
        workflows.OpenTimestampsStoredVerificationTargetRefreshBatchStorage;
    pub const TargetRefreshBatchRequest =
        workflows.OpenTimestampsStoredVerificationTargetRefreshBatchRequest;
    pub const TargetRefreshBatchPlan =
        workflows.OpenTimestampsStoredVerificationTargetRefreshBatchPlan;
    pub const TargetRefreshBatchStep =
        workflows.OpenTimestampsStoredVerificationTargetRefreshBatchStep;
    pub const TargetTurnPolicyAction =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyAction;
    pub const TargetTurnPolicyEntry =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyEntry;
    pub const TargetTurnPolicyGroup =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyGroup;
    pub const TargetTurnPolicyStorage =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyStorage;
    pub const TargetTurnPolicyRequest =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyRequest;
    pub const TargetTurnPolicyPlan =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyPlan;
    pub const TargetTurnPolicyStep =
        workflows.OpenTimestampsStoredVerificationTargetTurnPolicyStep;
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
        return workflows.OpenTimestampsVerifier.verifyRemote(http_client, job);
    }

    pub fn verifyRemoteCached(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        proof_store: workflows.OpenTimestampsProofStore,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyCachedResult {
        _ = self;
        return workflows.OpenTimestampsVerifier.verifyRemoteCached(http_client, proof_store, job);
    }

    pub fn verifyRemoteCachedAndRemember(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        proof_store: workflows.OpenTimestampsProofStore,
        verification_store: workflows.OpenTimestampsVerificationStore,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyJobResult {
        _ = self;
        return workflows.OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
            http_client,
            proof_store,
            verification_store,
            job,
        );
    }

    pub fn getLatestStoredVerificationFreshness(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.LatestFreshnessRequest,
    ) Nip03VerifyClientError!?Nip03StoredVerificationPlanning.LatestFreshness {
        _ = self;
        return workflows.OpenTimestampsVerifier.getLatestStoredVerificationFreshness(
            verification_store,
            request,
        );
    }

    pub fn discoverLatestStoredVerificationFreshnessForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.LatestTargetRequest,
    ) Nip03VerifyClientError![]const Nip03StoredVerificationPlanning.LatestTargetEntry {
        _ = self;
        return workflows.OpenTimestampsVerifier.discoverLatestStoredVerificationFreshnessForTargets(
            verification_store,
            request,
        );
    }

    pub fn getPreferredStoredVerification(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.PreferredRequest,
    ) Nip03VerifyClientError!?Nip03StoredVerificationPlanning.Preferred {
        _ = self;
        return workflows.OpenTimestampsVerifier.getPreferredStoredVerification(
            verification_store,
            request,
        );
    }

    pub fn getPreferredStoredVerificationForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.PreferredTargetRequest,
    ) Nip03VerifyClientError!?Nip03StoredVerificationPlanning.PreferredTargetEntry {
        _ = self;
        return workflows.OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectStoredVerificationRuntime(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.RuntimeRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.RuntimePlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.inspectStoredVerificationRuntime(
            verification_store,
            request,
        );
    }

    pub fn planStoredVerificationRefresh(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.RefreshRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.RefreshPlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.planStoredVerificationRefresh(
            verification_store,
            request,
        );
    }

    pub fn planStoredVerificationRefreshForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.TargetRefreshRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.TargetRefreshPlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectStoredVerificationRefreshReadinessForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        event_archive: store.EventArchive,
        request: Nip03StoredVerificationPlanning.TargetRefreshReadinessRequest,
    ) Nip03StoredVerificationRefreshReadinessError!Nip03StoredVerificationPlanning.TargetRefreshReadinessPlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.inspectStoredVerificationRefreshReadinessForTargets(
            verification_store,
            event_archive,
            request,
        );
    }

    pub fn inspectStoredVerificationPolicyForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.TargetPolicyRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.TargetPolicyPlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectStoredVerificationRefreshCadenceForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.TargetRefreshCadenceRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.TargetRefreshCadencePlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectStoredVerificationRefreshBatchForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.TargetRefreshBatchRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.TargetRefreshBatchPlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
            verification_store,
            request,
        );
    }

    pub fn inspectStoredVerificationTurnPolicyForTargets(
        self: *const Nip03VerifyClient,
        verification_store: workflows.OpenTimestampsVerificationStore,
        request: Nip03StoredVerificationPlanning.TargetTurnPolicyRequest,
    ) Nip03VerifyClientError!Nip03StoredVerificationPlanning.TargetTurnPolicyPlan {
        _ = self;
        return workflows.OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
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
    var proof_store_records: [1]workflows.OpenTimestampsProofRecord =
        [_]workflows.OpenTimestampsProofRecord{.{}} ** 1;
    var proof_store = workflows.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [1]workflows.OpenTimestampsStoredVerificationRecord =
        [_]workflows.OpenTimestampsStoredVerificationRecord{.{}} ** 1;
    var verification_store =
        workflows.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

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
        workflows.OpenTimestampsVerificationStorePutOutcome.stored,
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
    const missing_target = Nip03StoredVerificationPlanning.Target{
        .target_event_id = [_]u8{0x99} ** 32,
    };

    var verification_store_records: [2]workflows.OpenTimestampsStoredVerificationRecord =
        [_]workflows.OpenTimestampsStoredVerificationRecord{.{}} ** 2;
    var verification_store =
        workflows.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

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

    var fresh_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    const latest_fresh = (try client.getLatestStoredVerificationFreshness(
        verification_store.asStore(),
        .{
            .target_event_id = &fresh_target.id,
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .matches = fresh_matches[0..],
        },
    )).?;
    try std.testing.expectEqual(Nip03StoredVerificationPlanning.Freshness.fresh, latest_fresh.freshness);

    var runtime_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var runtime_entries: [2]Nip03StoredVerificationPlanning.DiscoveryFreshnessEntry = undefined;
    const runtime = try client.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &fresh_target.id,
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip03StoredVerificationPlanning.RuntimeStorage.init(
                runtime_matches[0..],
                runtime_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(Nip03StoredVerificationPlanning.RuntimeAction.use_preferred, runtime.action);
    try std.testing.expectEqualStrings(
        "https://proof.example/fresh.ots",
        runtime.nextStep().entry.?.entry.verification.proofUrl(),
    );

    const targets = [_]Nip03StoredVerificationPlanning.Target{
        .{ .target_event_id = fresh_target.id },
        .{ .target_event_id = stale_target.id },
        missing_target,
    };
    var target_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var target_latest_entries: [3]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    const latest_entries = try client.discoverLatestStoredVerificationFreshnessForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .storage = Nip03StoredVerificationPlanning.LatestTargetStorage.init(
                target_matches[0..],
                target_latest_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(Nip03StoredVerificationPlanning.Freshness.fresh, latest_entries[0].latest.?.freshness);
    try std.testing.expectEqual(Nip03StoredVerificationPlanning.Freshness.stale, latest_entries[1].latest.?.freshness);
    try std.testing.expect(latest_entries[2].latest == null);

    var preferred_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var preferred_freshness_entries: [2]Nip03StoredVerificationPlanning.DiscoveryFreshnessEntry = undefined;
    var preferred_entries: [3]Nip03StoredVerificationPlanning.PreferredTargetEntry = undefined;
    const preferred = (try client.getPreferredStoredVerificationForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip03StoredVerificationPlanning.PreferredTargetStorage.init(
                preferred_matches[0..],
                preferred_freshness_entries[0..],
                preferred_entries[0..],
            ),
        },
    )).?;
    try std.testing.expectEqualSlices(u8, fresh_target.id[0..], preferred.target.target_event_id[0..]);

    var policy_target_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var policy_target_latest_entries: [3]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var policy_entries: [3]Nip03StoredVerificationPlanning.TargetPolicyEntry = undefined;
    var policy_groups: [4]Nip03StoredVerificationPlanning.TargetPolicyGroup = undefined;
    const policy_plan = try client.inspectStoredVerificationPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip03StoredVerificationPlanning.TargetPolicyStorage.init(
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

    var refresh_target_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var refresh_target_latest_entries: [3]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var refresh_entries: [3]Nip03StoredVerificationPlanning.RefreshEntry = undefined;
    var refresh_targets: [3]Nip03StoredVerificationPlanning.TargetRefreshEntry = undefined;
    const refresh_plan = try client.planStoredVerificationRefreshForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .storage = Nip03StoredVerificationPlanning.TargetRefreshStorage.init(
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

    var cadence_target_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var cadence_target_latest_entries: [3]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var cadence_entries: [3]Nip03StoredVerificationPlanning.TargetRefreshCadenceEntry = undefined;
    var cadence_groups: [5]Nip03StoredVerificationPlanning.TargetRefreshCadenceGroup = undefined;
    const cadence_plan = try client.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip03StoredVerificationPlanning.TargetRefreshCadenceStorage.init(
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

    var batch_target_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var batch_target_latest_entries: [3]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var batch_entries: [3]Nip03StoredVerificationPlanning.TargetRefreshCadenceEntry = undefined;
    var batch_groups: [5]Nip03StoredVerificationPlanning.TargetRefreshCadenceGroup = undefined;
    const batch_plan = try client.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip03StoredVerificationPlanning.TargetRefreshBatchStorage.init(
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

    var turn_policy_matches: [2]Nip03StoredVerificationPlanning.Match = undefined;
    var turn_policy_latest_entries: [3]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    var turn_policy_cadence_entries: [3]Nip03StoredVerificationPlanning.TargetRefreshCadenceEntry = undefined;
    var turn_policy_cadence_groups: [5]Nip03StoredVerificationPlanning.TargetRefreshCadenceGroup = undefined;
    var turn_policy_entries: [3]Nip03StoredVerificationPlanning.TargetTurnPolicyEntry = undefined;
    var turn_policy_groups: [4]Nip03StoredVerificationPlanning.TargetTurnPolicyGroup = undefined;
    const turn_policy_plan = try client.inspectStoredVerificationTurnPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = Nip03StoredVerificationPlanning.TargetTurnPolicyStorage.init(
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

    var verification_store_records: [2]workflows.OpenTimestampsStoredVerificationRecord =
        [_]workflows.OpenTimestampsStoredVerificationRecord{ .{}, .{} };
    var verification_store =
        workflows.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

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
    const targets = [_]Nip03StoredVerificationPlanning.Target{
        .{ .target_event_id = ready_target.id },
        .{ .target_event_id = blocked_target.id },
    };
    var matches: [1]Nip03StoredVerificationPlanning.Match = undefined;
    var latest_entries: [2]Nip03StoredVerificationPlanning.LatestTargetEntry = undefined;
    const refresh_entries = [_]Nip03StoredVerificationPlanning.RefreshEntry{};
    var target_refresh_entries: [2]Nip03StoredVerificationPlanning.TargetRefreshEntry = undefined;
    var target_records: [1]store.ClientEventRecord = undefined;
    var attestation_records: [1]store.ClientEventRecord = undefined;
    var readiness_entries: [2]Nip03StoredVerificationPlanning.TargetRefreshReadinessEntry = undefined;
    var readiness_groups: [4]Nip03StoredVerificationPlanning.TargetRefreshReadinessGroup = undefined;
    const plan = try client.inspectStoredVerificationRefreshReadinessForTargets(
        verification_store.asStore(),
        archive,
        .{
            .targets = targets[0..],
            .now_unix_seconds = 51,
            .max_age_seconds = 10,
            .storage = Nip03StoredVerificationPlanning.TargetRefreshReadinessStorage.init(
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
        Nip03StoredVerificationPlanning.TargetRefreshReadinessAction.missing_events,
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
    verification_store: workflows.OpenTimestampsVerificationStore,
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
    const local = try workflows.OpenTimestampsVerifier.verifyLocal(
        target_event,
        &stored_attestation,
        proof_buffer[0..],
    );
    try std.testing.expect(local == .verified);
    _ = try workflows.OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store,
        target_event,
        &stored_attestation,
        &.{ .proof_url = proof_url, .verification = local.verified },
    );
    return stored_attestation;
}

fn rememberVerificationForTarget(
    verification_store: workflows.OpenTimestampsVerificationStore,
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
