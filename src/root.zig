const std = @import("std");

/// Stable workflow namespace.
pub const workflows = @import("workflows/mod.zig");
/// Stable store/query reference namespace.
pub const store = @import("store/mod.zig");
/// Stable relay-pool/runtime reference namespace.
pub const runtime = @import("runtime/mod.zig");
/// Explicit HTTP seam for the current HTTP-backed workflow slices.
pub const transport = @import("transport/mod.zig");

test "root module exposes workflows store runtime plus the explicit http seam" {
    try std.testing.expect(!@hasDecl(@This(), "noztr"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(@TypeOf(store) == type);
    try std.testing.expect(@TypeOf(store.ClientStore) == type);
    try std.testing.expect(@TypeOf(store.ClientEventRecord) == type);
    try std.testing.expect(@TypeOf(store.ClientCheckpointRecord) == type);
    try std.testing.expect(@TypeOf(store.ClientQuery) == type);
    try std.testing.expect(@TypeOf(store.QueryResultPage(store.ClientEventRecord)) == type);
    try std.testing.expect(@TypeOf(store.EventCursor) == type);
    try std.testing.expect(@TypeOf(store.IndexSelection) == type);
    try std.testing.expect(@TypeOf(store.MemoryClientStore) == type);
    try std.testing.expect(@TypeOf(store.EventArchive) == type);
    try std.testing.expect(@TypeOf(store.RelayCheckpointArchive) == type);
    try std.testing.expect(@TypeOf(store.RelayLocalGroupArchive) == type);
    try std.testing.expect(@TypeOf(runtime) == type);
    try std.testing.expect(@TypeOf(runtime.RelayPoolStorage) == type);
    try std.testing.expect(@TypeOf(runtime.RelayPoolPlanStorage) == type);
    try std.testing.expect(@TypeOf(runtime.RelayPool) == type);
    try std.testing.expect(@TypeOf(runtime.RelayPoolPlan) == type);
    try std.testing.expect(@TypeOf(runtime.RelayPoolStep) == type);
    try std.testing.expect(@TypeOf(transport) == type);
    try std.testing.expect(@TypeOf(transport.HttpClient) == type);
    try std.testing.expect(@TypeOf(transport.HttpError) == type);
    try std.testing.expect(@TypeOf(transport.HttpRequest) == type);
    try std.testing.expect(!@hasDecl(@This(), "relay"));
    try std.testing.expect(@TypeOf(workflows) == type);
    try std.testing.expect(!@hasDecl(@This(), "policy"));
    try std.testing.expect(!@hasDecl(@This(), "sync"));
    try std.testing.expect(!@hasDecl(@This(), "Config"));
    try std.testing.expect(!@hasDecl(@This(), "testing"));
}

test "root smoke uses noztr stable helper" {
    const noztr = @import("noztr");
    const parsed_method = try noztr.nip46_remote_signing.method_parse("connect");
    try std.testing.expectEqual(.connect, parsed_method);
}

test "root smoke pins hardened noztr nip46 direct-helper typed errors" {
    const noztr = @import("noztr");

    var overlong_token: [noztr.limits.tag_item_bytes_max + 1]u8 = undefined;
    @memset(overlong_token[0..], 'a');
    try std.testing.expectError(
        error.InvalidMethod,
        noztr.nip46_remote_signing.method_parse(overlong_token[0..]),
    );

    overlong_token[0] = 'p';
    overlong_token[1] = ':';
    try std.testing.expectError(
        error.InvalidPermission,
        noztr.nip46_remote_signing.permission_parse(overlong_token[0..]),
    );
}

test "phase3 relay directory fetches nip11 over explicit seams" {
    const sdk_store = @import("store/mod.zig");
    const relay_directory = @import("relay/directory.zig");
    const testing = @import("testing/mod.zig");
    const json =
        \\{"name":"alpha","pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","supported_nips":[11,42]}
    ;
    var fake_http = testing.FakeHttp.init("https://relay.test", json);
    var memory_store = sdk_store.MemoryStore{};
    var directory = relay_directory.RelayDirectory.init(memory_store.asRelayInfoStore());
    var url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;

    const record = try directory.refresh(
        fake_http.client(),
        "wss://relay.test",
        &url_buffer,
        &response_buffer,
        &parse_scratch,
    );
    try std.testing.expectEqualStrings("wss://relay.test", record.relayUrl());
    try std.testing.expectEqualStrings("alpha", record.nameSlice());
}

test "phase3 session helpers stay internal and explicit" {
    const testing = @import("testing/mod.zig");
    const relay_pool = @import("relay/pool.zig");
    var pool = relay_pool.Pool.init();
    const relay_index = try pool.addRelay("wss://relay.one");
    const relay_session = pool.getRelay(relay_index) orelse unreachable;
    const fake_relay = testing.FakeRelay{
        .relay_url = "wss://relay.one",
        .challenge = "challenge-1",
    };
    try fake_relay.requireAuth(relay_session);
    try std.testing.expect(!relay_session.canSendRequests());
}

test "phase4 exposes the remote signer workflow surface" {
    try std.testing.expect(@TypeOf(workflows.RemoteSignerSession) == type);
    try std.testing.expect(@TypeOf(workflows.RemoteSignerPubkeyTextRequest) == type);
    try std.testing.expect(@TypeOf(workflows.RemoteSignerRequestContext) == type);
    try std.testing.expect(@TypeOf(workflows.RemoteSignerTextResponse) == type);
}

test "phase5 exposes the mailbox workflow surface" {
    try std.testing.expect(@TypeOf(workflows.MailboxSession) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxOutboundBuffer) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxFileMessageOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxEnvelopeOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxFileDimensions) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxDeliveryStorage) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxDeliveryRole) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxDeliveryPlan) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxDeliveryStep) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxRuntimeAction) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxRuntimeEntry) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxRuntimeStep) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxWorkflowAction) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxWorkflowEntry) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxWorkflowStep) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxWorkflowStorage) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxWorkflowRequest) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxWorkflowPlan) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxRuntimeStorage) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxRuntimePlan) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxDirectMessageRequest) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxFileMessageRequest) == type);
    try std.testing.expect(@TypeOf(workflows.MailboxOutboundMessage) == type);
}

test "phase6 exposes the identity verifier workflow surface" {
    try std.testing.expect(@TypeOf(workflows.IdentityVerifier) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityVerificationCacheResult) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityVerificationCacheRecord) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityVerificationCacheError) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityVerificationCache) == type);
    try std.testing.expect(@TypeOf(workflows.MemoryIdentityVerificationCache) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileStorePutOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileStoreError) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredClaim) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileRecord) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileMatch) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileDiscoveryRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityLatestStoredProfileRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileFreshness) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileFallbackPolicy) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityLatestStoredProfileFreshnessRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityLatestStoredProfileFreshness) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfileRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfile) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryFreshnessEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryFreshnessStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryFreshnessRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTarget) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetDiscoveryGroup) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetDiscoveryStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetDiscoveryRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetDiscoveryFreshnessGroup) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetDiscoveryFreshnessStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetDiscoveryFreshnessRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityLatestStoredProfileTargetEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityLatestStoredProfileTargetStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityLatestStoredProfileTargetRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfileTargetEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfileTargetStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfileTargetSelectionRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetLatestFreshnessEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetLatestFreshnessStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetLatestFreshnessRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfileTargetRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityPreferredStoredProfileTarget) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshPlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRuntimeAction) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRuntimeRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRuntimePlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRuntimeStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetPolicyEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetPolicyGroup) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetPolicyStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetPolicyRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetPolicyPlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadenceAction) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadenceEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadenceGroup) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadenceStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadenceRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadencePlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshCadenceStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshBatchStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshBatchRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshBatchPlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetRefreshBatchStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyAction) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyGroup) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyPlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetTurnPolicyStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetLatestFreshnessPlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileTargetLatestFreshnessStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRuntimeAction) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRuntimeStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRuntimeRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRuntimePlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRuntimeStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRefreshEntry) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRefreshStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRefreshRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRefreshPlan) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileRefreshStep) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileStore) == type);
    try std.testing.expect(@TypeOf(workflows.MemoryIdentityProfileStore) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityVerificationStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityVerificationRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProviderDetails) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityClaimVerificationOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityClaimVerification) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileVerificationStorage) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileVerificationRequest) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityProfileVerificationSummary) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityRememberedProfileVerification) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityRememberedProfileVerificationError) == type);
    try std.testing.expect(@TypeOf(workflows.IdentityStoredProfileDiscoveryError) == type);
}

test "phase7 exposes the opentimestamps verifier workflow surface" {
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsVerifier) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsProofStoreError) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsProofRecord) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsProofStore) == type);
    try std.testing.expect(@TypeOf(workflows.MemoryOpenTimestampsProofStore) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsVerificationStorePutOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsVerificationStoreError) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRecord) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationMatch) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsVerificationDiscoveryRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryEntry) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsLatestStoredVerificationRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationFreshness) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsLatestStoredVerificationFreshnessRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsLatestStoredVerificationFreshness) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessEntry) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryFreshnessRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationTarget) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsLatestStoredVerificationTargetEntry) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsLatestStoredVerificationTargetStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsLatestStoredVerificationTargetRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationFallbackPolicy) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsPreferredStoredVerificationRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsPreferredStoredVerification) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsPreferredStoredVerificationTargetEntry) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsPreferredStoredVerificationTargetStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsPreferredStoredVerificationTargetRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRuntimeAction) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRuntimeStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRuntimeRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRuntimePlan) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRuntimeStep) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRefreshEntry) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRefreshStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRefreshRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRefreshPlan) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationRefreshStep) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationTargetRefreshEntry) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationTargetRefreshStorage) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationTargetRefreshRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationTargetRefreshPlan) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationTargetRefreshStep) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsVerificationStore) == type);
    try std.testing.expect(@TypeOf(workflows.MemoryOpenTimestampsVerificationStore) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsRemoteProofRequest) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsRemoteVerification) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsRememberedRemoteVerification) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsRememberedRemoteVerificationError) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsStoredVerificationDiscoveryError) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsFetchFailure) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsRemoteVerificationOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.OpenTimestampsRememberedRemoteVerificationOutcome) == type);
}

test "phase8 exposes the nip05 resolver workflow surface" {
    try std.testing.expect(@TypeOf(workflows.Nip05Resolver) == type);
    try std.testing.expect(@TypeOf(workflows.Nip05LookupStorage) == type);
    try std.testing.expect(@TypeOf(workflows.Nip05LookupRequest) == type);
    try std.testing.expect(@TypeOf(workflows.Nip05VerificationRequest) == type);
}

test "phase9 exposes the group session workflow surface" {
    try std.testing.expect(@TypeOf(workflows.GroupClient) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleet) == type);
    try std.testing.expect(@TypeOf(workflows.GroupRelayState) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRelayStatus) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRuntimeAction) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBackgroundAction) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBackgroundEntry) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBackgroundRuntimeStep) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBackgroundRuntimeStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBackgroundRuntimeRequest) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBackgroundRuntimePlan) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRuntimeEntry) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRuntimeStep) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRuntimeStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRuntimePlan) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetEventOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetBatchOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRelayDivergence) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetConsistencyReport) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetConsistencyStep) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetReconcileOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetTargetReconcileOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetPublishStep) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetMergeSelection) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetMergedCheckpoint) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetMergeApplyOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetMergeStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointContext) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetMergeContext) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointSet) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointStorePutOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointStoreError) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointRecord) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetCheckpointStore) == type);
    try std.testing.expect(@TypeOf(workflows.MemoryGroupFleetCheckpointStore) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetStorePersistOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetStoreRestoreOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetPublishStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetPublishContext) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetPutUserDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupFleetRemoveUserDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupCheckpointBuffers) == type);
    try std.testing.expect(@TypeOf(workflows.GroupCheckpointContext) == type);
    try std.testing.expect(@TypeOf(workflows.GroupCheckpoint) == type);
    try std.testing.expect(@TypeOf(workflows.GroupClientStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupClientConfig) == type);
    try std.testing.expect(@TypeOf(workflows.GroupClientView) == type);
    try std.testing.expect(@TypeOf(workflows.GroupClientEventOutcome) == type);
    try std.testing.expect(@TypeOf(workflows.GroupClientBatchSummary) == type);
    try std.testing.expect(@TypeOf(workflows.GroupSession) == type);
    try std.testing.expect(@TypeOf(workflows.GroupSessionStorage) == type);
    try std.testing.expect(@TypeOf(workflows.GroupSessionConfig) == type);
    try std.testing.expect(@TypeOf(workflows.GroupSessionView) == type);
    try std.testing.expect(@TypeOf(workflows.GroupOutboundBuffer) == type);
    try std.testing.expect(@TypeOf(workflows.GroupPublishContext) == type);
    try std.testing.expect(@TypeOf(workflows.GroupOutboundEvent) == type);
    try std.testing.expect(@TypeOf(workflows.GroupMetadataDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupAdminsDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupMembersDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupRolesDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupJoinRequestDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupLeaveRequestDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupPutUserDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupRemoveUserDraft) == type);
    try std.testing.expect(@TypeOf(workflows.GroupObservedEventKind) == type);
    try std.testing.expect(@TypeOf(workflows.GroupJoinRequestInfo) == type);
    try std.testing.expect(@TypeOf(workflows.GroupLeaveRequestInfo) == type);
}
