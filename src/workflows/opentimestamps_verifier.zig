const std = @import("std");
const noztr = @import("noztr");
const store_archive = @import("../store/archive.zig");
const client_store = @import("../store/client_traits.zig");
const transport = @import("../transport/mod.zig");

pub const OpenTimestampsVerifierError = error{
    InvalidEventKind,
    InvalidEventTag,
    DuplicateEventTag,
    MissingEventTag,
    InvalidKindTag,
    DuplicateKindTag,
    MissingKindTag,
    InvalidEventId,
    InvalidRelayUrl,
    InvalidTargetKind,
    EmptyProof,
    InvalidBase64,
    BufferTooSmall,
};

pub const OpenTimestampsLocalProofError = error{
    InvalidProofHeader,
    UnsupportedProofVersion,
    InvalidProofOperation,
    InvalidProofStructure,
    MissingBitcoinAttestation,
};

pub const OpenTimestampsVerification = struct {
    attestation: noztr.nip03_opentimestamps.OpenTimestampsAttestation,
    proof: []const u8,
};

pub const OpenTimestampsRemoteProofRequest = struct {
    target_event: *const noztr.nip01_event.Event,
    attestation_event: *const noztr.nip01_event.Event,
    proof_url: []const u8,
    proof_buffer: []u8,
    accept: ?[]const u8 = null,
};

pub const proof_store_url_max_bytes: u16 = 512;
pub const proof_store_bytes_max: u32 = noztr.limits.content_bytes_max;

pub const OpenTimestampsProofStoreError = error{
    ProofUrlTooLong,
    ProofTooLong,
    StoreFull,
};

pub const opentimestamps_verification_store_url_max_bytes: u16 = 512;
pub const opentimestamps_verification_store_relay_max_bytes: u16 = 512;

pub const VerificationStorePutOutcome = enum {
    stored,
    updated,
};

pub const OpenTimestampsVerificationStoreError = error{
    ProofUrlTooLong,
    RelayUrlTooLong,
    StoreFull,
    InconsistentStoreData,
};

pub const OpenTimestampsProofRecord = struct {
    proof_url: [proof_store_url_max_bytes]u8 = [_]u8{0} ** proof_store_url_max_bytes,
    proof_url_len: u16 = 0,
    proof: [proof_store_bytes_max]u8 = [_]u8{0} ** proof_store_bytes_max,
    proof_len: u32 = 0,
    occupied: bool = false,

    pub fn proofUrl(self: *const OpenTimestampsProofRecord) []const u8 {
        return self.proof_url[0..self.proof_url_len];
    }

    pub fn proofBytes(self: *const OpenTimestampsProofRecord) []const u8 {
        return self.proof[0..self.proof_len];
    }
};

pub const OpenTimestampsProofStoreVTable = struct {
    put_proof: *const fn (
        ctx: *anyopaque,
        proof_url: []const u8,
        proof: []const u8,
    ) OpenTimestampsProofStoreError!void,
    get_proof: *const fn (
        ctx: *anyopaque,
        proof_url: []const u8,
    ) OpenTimestampsProofStoreError!?[]const u8,
};

pub const OpenTimestampsProofStore = struct {
    ctx: *anyopaque,
    vtable: *const OpenTimestampsProofStoreVTable,

    pub fn putProof(
        self: OpenTimestampsProofStore,
        proof_url: []const u8,
        proof: []const u8,
    ) OpenTimestampsProofStoreError!void {
        return self.vtable.put_proof(self.ctx, proof_url, proof);
    }

    pub fn getProof(
        self: OpenTimestampsProofStore,
        proof_url: []const u8,
    ) OpenTimestampsProofStoreError!?[]const u8 {
        return self.vtable.get_proof(self.ctx, proof_url);
    }
};

pub const StoredRecord = struct {
    target_event_id: [32]u8 = [_]u8{0} ** 32,
    attestation_event_id: [32]u8 = [_]u8{0} ** 32,
    attestation_created_at: u64 = 0,
    target_kind: u32 = 0,
    proof_url: [opentimestamps_verification_store_url_max_bytes]u8 =
        [_]u8{0} ** opentimestamps_verification_store_url_max_bytes,
    proof_url_len: u16 = 0,
    relay_url: [opentimestamps_verification_store_relay_max_bytes]u8 =
        [_]u8{0} ** opentimestamps_verification_store_relay_max_bytes,
    relay_url_len: u16 = 0,
    occupied: bool = false,

    pub fn proofUrl(self: *const StoredRecord) []const u8 {
        return self.proof_url[0..self.proof_url_len];
    }

    pub fn relayUrl(self: *const StoredRecord) ?[]const u8 {
        if (self.relay_url_len == 0) return null;
        return self.relay_url[0..self.relay_url_len];
    }
};

pub const StoredMatch = struct {
    attestation_event_id: [32]u8,
    created_at: u64,
};

const StoredMatchRequest = struct {
    target_event_id: *const [32]u8,
    results: []StoredMatch,
};

const StoredDiscoveryEntry = struct {
    match: StoredMatch,
    verification: StoredRecord,
};

const StoredDiscoveryStorage = struct {
    matches: []StoredMatch,
    entries: []StoredDiscoveryEntry,

    pub fn init(
        matches: []StoredMatch,
        entries: []StoredDiscoveryEntry,
    ) StoredDiscoveryStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

const StoredDiscoveryRequest = struct {
    target_event_id: *const [32]u8,
    storage: StoredDiscoveryStorage,
};

const StoredLatestRequest = struct {
    target_event_id: *const [32]u8,
    matches: []StoredMatch,
};

const StoredLatestFreshnessRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    matches: []StoredMatch,
};

const StoredTarget = struct {
    target_event_id: [32]u8,
};

const StoredFreshness = enum {
    fresh,
    stale,
};

const StoredLatestValue = struct {
    latest: StoredDiscoveryEntry,
    freshness: StoredFreshness,
    age_seconds: u64,
};

const StoredFreshEntry = struct {
    entry: StoredDiscoveryEntry,
    freshness: StoredFreshness,
    age_seconds: u64,
};

const StoredFreshStorage = struct {
    matches: []StoredMatch,
    entries: []StoredFreshEntry,

    pub fn init(
        matches: []StoredMatch,
        entries: []StoredFreshEntry,
    ) StoredFreshStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

const StoredFreshRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: StoredFreshStorage,
};

const TargetLatestEntry = struct {
    target: StoredTarget,
    latest: ?StoredLatestValue = null,
};

const TargetLatestStorage = struct {
    matches: []StoredMatch,
    entries: []TargetLatestEntry,

    pub fn init(
        matches: []StoredMatch,
        entries: []TargetLatestEntry,
    ) TargetLatestStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

const TargetLatestRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: TargetLatestStorage,
};

const StoredFallbackPolicy = enum {
    require_fresh,
    allow_stale_latest,
};

const TargetPreferredRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: StoredFreshStorage,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
};

const TargetPreferredValue = struct {
    entry: StoredDiscoveryEntry,
    freshness: StoredFreshness,
    age_seconds: u64,
};

const TargetPreferredEntry = struct {
    target: StoredTarget,
    preferred: ?TargetPreferredValue = null,
};

const TargetPreferredStorage = struct {
    matches: []StoredMatch,
    freshness_entries: []StoredFreshEntry,
    entries: []TargetPreferredEntry,

    pub fn init(
        matches: []StoredMatch,
        freshness_entries: []StoredFreshEntry,
        entries: []TargetPreferredEntry,
    ) TargetPreferredStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .entries = entries,
        };
    }
};

const TargetPreferredEntriesRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
    storage: TargetPreferredStorage,
};

const StoredRuntimeAction = enum {
    verify_now,
    refresh_existing,
    use_preferred,
    use_stale_and_refresh,
};

const StoredRuntimeStorage = struct {
    matches: []StoredMatch,
    entries: []StoredFreshEntry,

    pub fn init(
        matches: []StoredMatch,
        entries: []StoredFreshEntry,
    ) StoredRuntimeStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

const StoredRuntimeRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
    storage: StoredRuntimeStorage,
};

const StoredRuntimePlan = struct {
    action: StoredRuntimeAction,
    entries: []const StoredFreshEntry,
    preferred_index: ?u32 = null,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,

    pub fn preferredEntry(
        self: *const StoredRuntimePlan,
    ) ?*const StoredFreshEntry {
        const index = self.preferred_index orelse return null;
        const usize_index: usize = @intCast(index);
        if (usize_index >= self.entries.len) return null;
        return &self.entries[usize_index];
    }

    pub fn nextEntry(
        self: *const StoredRuntimePlan,
    ) ?*const StoredFreshEntry {
        return switch (self.action) {
            .verify_now => null,
            .refresh_existing, .use_preferred, .use_stale_and_refresh => self.preferredEntry(),
        };
    }

    pub fn nextStep(
        self: *const StoredRuntimePlan,
    ) StoredRuntimeStep {
        return .{
            .action = self.action,
            .entry = if (self.nextEntry()) |entry| entry.* else null,
        };
    }
};

const StoredRuntimeStep = struct {
    action: StoredRuntimeAction,
    entry: ?StoredFreshEntry = null,
};

const StoredRefreshEntry = struct {
    entry: StoredFreshEntry,
};

const StoredRefreshStorage = struct {
    matches: []StoredMatch,
    freshness_entries: []StoredFreshEntry,
    entries: []StoredRefreshEntry,

    pub fn init(
        matches: []StoredMatch,
        freshness_entries: []StoredFreshEntry,
        entries: []StoredRefreshEntry,
    ) StoredRefreshStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .entries = entries,
        };
    }
};

const StoredRefreshRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: StoredRefreshStorage,
};

const StoredRefreshPlan = struct {
    entries: []const StoredRefreshEntry,

    pub fn nextEntry(
        self: *const StoredRefreshPlan,
    ) ?*const StoredRefreshEntry {
        return self.newestEntry();
    }

    pub fn newestEntry(
        self: *const StoredRefreshPlan,
    ) ?*const StoredRefreshEntry {
        if (self.entries.len == 0) return null;
        return &self.entries[0];
    }

    pub fn nextStep(
        self: *const StoredRefreshPlan,
    ) ?StoredRefreshStep {
        const entry = self.nextEntry() orelse return null;
        return .{ .entry = entry.* };
    }
};

const StoredRefreshStep = struct {
    entry: StoredRefreshEntry,
};

const TargetRefreshEntry = struct {
    target: StoredTarget,
    latest: StoredLatestValue,
};

const TargetRefreshStorage = struct {
    matches: []StoredMatch,
    freshness_entries: []TargetLatestEntry,
    refresh_entries: []StoredRefreshEntry,
    entries: []TargetRefreshEntry,

    pub fn init(
        matches: []StoredMatch,
        freshness_entries: []TargetLatestEntry,
        refresh_entries: []StoredRefreshEntry,
        entries: []TargetRefreshEntry,
    ) TargetRefreshStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .refresh_entries = refresh_entries,
            .entries = entries,
        };
    }
};

const TargetRefreshRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: TargetRefreshStorage,
};

const TargetRefreshPlan = struct {
    entries: []const TargetRefreshEntry,

    pub fn nextEntry(
        self: *const TargetRefreshPlan,
    ) ?*const TargetRefreshEntry {
        if (self.entries.len == 0) return null;
        return &self.entries[0];
    }

    pub fn nextStep(
        self: *const TargetRefreshPlan,
    ) ?TargetRefreshStep {
        const entry = self.nextEntry() orelse return null;
        return .{ .entry = entry.* };
    }
};

const TargetRefreshStep = struct {
    entry: TargetRefreshEntry,
};

const TargetReadinessError =
    StoredDiscoveryError || store_archive.EventArchiveError;

const TargetReadinessAction = enum {
    ready_refresh,
    missing_target_event,
    missing_attestation_event,
    missing_events,
};

const TargetReadinessEntry = struct {
    target: StoredTarget,
    latest: StoredLatestValue,
    action: TargetReadinessAction,
    target_record_index: ?u32 = null,
    attestation_record_index: ?u32 = null,
};

const TargetReadinessGroup = struct {
    action: TargetReadinessAction,
    entries: []const TargetReadinessEntry,
};

const TargetReadinessStorage = struct {
    matches: []StoredMatch,
    freshness_entries: []TargetLatestEntry,
    refresh_entries: []StoredRefreshEntry,
    target_refresh_entries: []TargetRefreshEntry,
    target_records: []client_store.ClientEventRecord,
    attestation_records: []client_store.ClientEventRecord,
    entries: []TargetReadinessEntry,
    groups: []TargetReadinessGroup,

    pub fn init(
        matches: []StoredMatch,
        freshness_entries: []TargetLatestEntry,
        refresh_entries: []StoredRefreshEntry,
        target_refresh_entries: []TargetRefreshEntry,
        target_records: []client_store.ClientEventRecord,
        attestation_records: []client_store.ClientEventRecord,
        entries: []TargetReadinessEntry,
        groups: []TargetReadinessGroup,
    ) TargetReadinessStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .refresh_entries = refresh_entries,
            .target_refresh_entries = target_refresh_entries,
            .target_records = target_records,
            .attestation_records = attestation_records,
            .entries = entries,
            .groups = groups,
        };
    }
};

const TargetReadinessRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: TargetReadinessStorage,
};

const TargetReadinessPlan = struct {
    entries: []const TargetReadinessEntry,
    groups: []const TargetReadinessGroup,
    target_records: []const client_store.ClientEventRecord,
    attestation_records: []const client_store.ClientEventRecord,
    ready_count: u32 = 0,
    missing_target_event_count: u32 = 0,
    missing_attestation_event_count: u32 = 0,
    missing_events_count: u32 = 0,

    pub fn nextReadyEntry(
        self: *const TargetReadinessPlan,
    ) ?*const TargetReadinessEntry {
        if (self.ready_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextReadyStep(
        self: *const TargetReadinessPlan,
    ) ?TargetReadinessStep {
        const entry = self.nextReadyEntry() orelse return null;
        return .{
            .action = .ready_refresh,
            .entry = entry.*,
        };
    }

    pub fn readyEntries(
        self: *const TargetReadinessPlan,
    ) []const TargetReadinessEntry {
        return self.entries[0..@as(usize, @intCast(self.ready_count))];
    }

    pub fn blockedEntries(
        self: *const TargetReadinessPlan,
    ) []const TargetReadinessEntry {
        return self.entries[@as(usize, @intCast(self.ready_count))..];
    }

    pub fn targetRecord(
        self: *const TargetReadinessPlan,
        entry: *const TargetReadinessEntry,
    ) ?*const client_store.ClientEventRecord {
        const index = entry.target_record_index orelse return null;
        return &self.target_records[index];
    }

    pub fn attestationRecord(
        self: *const TargetReadinessPlan,
        entry: *const TargetReadinessEntry,
    ) ?*const client_store.ClientEventRecord {
        const index = entry.attestation_record_index orelse return null;
        return &self.attestation_records[index];
    }
};

const TargetReadinessStep = struct {
    action: TargetReadinessAction,
    entry: TargetReadinessEntry,
};

const TargetPolicyEntry = struct {
    target: StoredTarget,
    action: StoredRuntimeAction,
    latest: ?StoredLatestValue = null,
};

const TargetPolicyGroup = struct {
    action: StoredRuntimeAction,
    entries: []const TargetPolicyEntry,
};

const TargetPolicyStorage = struct {
    matches: []StoredMatch,
    latest_entries: []TargetLatestEntry,
    entries: []TargetPolicyEntry,
    groups: []TargetPolicyGroup,

    pub fn init(
        matches: []StoredMatch,
        latest_entries: []TargetLatestEntry,
        entries: []TargetPolicyEntry,
        groups: []TargetPolicyGroup,
    ) TargetPolicyStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .entries = entries,
            .groups = groups,
        };
    }
};

const TargetPolicyRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
    storage: TargetPolicyStorage,
};

const TargetPolicyPlan = struct {
    entries: []const TargetPolicyEntry,
    groups: []const TargetPolicyGroup,
    verify_now_count: u32 = 0,
    use_preferred_count: u32 = 0,
    use_stale_and_refresh_count: u32 = 0,
    refresh_existing_count: u32 = 0,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn usablePreferredEntries(
        self: *const TargetPolicyPlan,
    ) []const TargetPolicyEntry {
        const start: usize = @intCast(self.verify_now_count);
        const end =
            start + @as(usize, @intCast(self.use_preferred_count + self.use_stale_and_refresh_count));
        return self.entries[start..end];
    }

    pub fn verifyNowEntries(
        self: *const TargetPolicyPlan,
    ) []const TargetPolicyEntry {
        return self.entries[0..@as(usize, @intCast(self.verify_now_count))];
    }

    pub fn refreshNeededEntries(
        self: *const TargetPolicyPlan,
    ) []const TargetPolicyEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.use_preferred_count));
        return self.entries[start..];
    }
};

const TargetRefreshCadenceAction = enum {
    verify_now,
    refresh_now,
    usable_while_refreshing,
    refresh_soon,
    stable,
};

const TargetRefreshCadenceEntry = struct {
    target: StoredTarget,
    action: TargetRefreshCadenceAction,
    latest: ?StoredLatestValue = null,
};

const TargetRefreshCadenceGroup = struct {
    action: TargetRefreshCadenceAction,
    entries: []const TargetRefreshCadenceEntry,
};

const TargetRefreshCadenceStorage = struct {
    matches: []StoredMatch,
    latest_entries: []TargetLatestEntry,
    entries: []TargetRefreshCadenceEntry,
    groups: []TargetRefreshCadenceGroup,

    pub fn init(
        matches: []StoredMatch,
        latest_entries: []TargetLatestEntry,
        entries: []TargetRefreshCadenceEntry,
        groups: []TargetRefreshCadenceGroup,
    ) TargetRefreshCadenceStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .entries = entries,
            .groups = groups,
        };
    }
};

const TargetRefreshCadenceRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    refresh_soon_age_seconds: u64,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
    storage: TargetRefreshCadenceStorage,
};

const TargetRefreshCadencePlan = struct {
    entries: []const TargetRefreshCadenceEntry,
    groups: []const TargetRefreshCadenceGroup,
    verify_now_count: u32 = 0,
    refresh_now_count: u32 = 0,
    usable_while_refreshing_count: u32 = 0,
    refresh_soon_count: u32 = 0,
    stable_count: u32 = 0,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextDueEntry(
        self: *const TargetRefreshCadencePlan,
    ) ?*const TargetRefreshCadenceEntry {
        const due_count = self.verify_now_count +
            self.refresh_now_count +
            self.usable_while_refreshing_count +
            self.refresh_soon_count;
        if (due_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextDueStep(
        self: *const TargetRefreshCadencePlan,
    ) ?TargetRefreshCadenceStep {
        const entry = self.nextDueEntry() orelse return null;
        return .{
            .action = entry.action,
            .entry = entry.*,
        };
    }

    pub fn usableWhileRefreshingEntries(
        self: *const TargetRefreshCadencePlan,
    ) []const TargetRefreshCadenceEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.refresh_now_count));
        const end = start + @as(usize, @intCast(self.usable_while_refreshing_count));
        return self.entries[start..end];
    }

    pub fn refreshSoonEntries(
        self: *const TargetRefreshCadencePlan,
    ) []const TargetRefreshCadenceEntry {
        const start = @as(
            usize,
            @intCast(self.verify_now_count + self.refresh_now_count + self.usable_while_refreshing_count),
        );
        const end = start + @as(usize, @intCast(self.refresh_soon_count));
        return self.entries[start..end];
    }
};

const TargetRefreshCadenceStep = struct {
    action: TargetRefreshCadenceAction,
    entry: TargetRefreshCadenceEntry,
};

const TargetRefreshBatchStorage = struct {
    matches: []StoredMatch,
    latest_entries: []TargetLatestEntry,
    cadence_entries: []TargetRefreshCadenceEntry,
    cadence_groups: []TargetRefreshCadenceGroup,

    pub fn init(
        matches: []StoredMatch,
        latest_entries: []TargetLatestEntry,
        cadence_entries: []TargetRefreshCadenceEntry,
        cadence_groups: []TargetRefreshCadenceGroup,
    ) TargetRefreshBatchStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .cadence_entries = cadence_entries,
            .cadence_groups = cadence_groups,
        };
    }
};

const TargetRefreshBatchRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    refresh_soon_age_seconds: u64,
    max_selected: usize,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
    storage: TargetRefreshBatchStorage,
};

const TargetRefreshBatchPlan = struct {
    entries: []const TargetRefreshCadenceEntry,
    selected_count: u32 = 0,
    deferred_count: u32 = 0,

    pub fn nextBatchEntry(
        self: *const TargetRefreshBatchPlan,
    ) ?*const TargetRefreshCadenceEntry {
        if (self.selected_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextBatchStep(
        self: *const TargetRefreshBatchPlan,
    ) ?TargetRefreshBatchStep {
        const entry = self.nextBatchEntry() orelse return null;
        return .{ .entry = entry.* };
    }

    pub fn selectedEntries(
        self: *const TargetRefreshBatchPlan,
    ) []const TargetRefreshCadenceEntry {
        return self.entries[0..@as(usize, @intCast(self.selected_count))];
    }

    pub fn deferredEntries(
        self: *const TargetRefreshBatchPlan,
    ) []const TargetRefreshCadenceEntry {
        const start: usize = @intCast(self.selected_count);
        return self.entries[start..];
    }
};

const TargetRefreshBatchStep = struct {
    entry: TargetRefreshCadenceEntry,
};

const TargetTurnPolicyAction = enum {
    verify_now,
    refresh_selected,
    use_cached,
    defer_refresh,
};

const TargetTurnPolicyEntry = struct {
    target: StoredTarget,
    action: TargetTurnPolicyAction,
    latest: ?StoredLatestValue = null,
};

const TargetTurnPolicyGroup = struct {
    action: TargetTurnPolicyAction,
    entries: []const TargetTurnPolicyEntry,
};

const TargetTurnPolicyStorage = struct {
    matches: []StoredMatch,
    latest_entries: []TargetLatestEntry,
    cadence_entries: []TargetRefreshCadenceEntry,
    cadence_groups: []TargetRefreshCadenceGroup,
    entries: []TargetTurnPolicyEntry,
    groups: []TargetTurnPolicyGroup,

    pub fn init(
        matches: []StoredMatch,
        latest_entries: []TargetLatestEntry,
        cadence_entries: []TargetRefreshCadenceEntry,
        cadence_groups: []TargetRefreshCadenceGroup,
        entries: []TargetTurnPolicyEntry,
        groups: []TargetTurnPolicyGroup,
    ) TargetTurnPolicyStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .cadence_entries = cadence_entries,
            .cadence_groups = cadence_groups,
            .entries = entries,
            .groups = groups,
        };
    }
};

const TargetTurnPolicyRequest = struct {
    targets: []const StoredTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    refresh_soon_age_seconds: u64,
    max_selected: usize,
    fallback_policy: StoredFallbackPolicy = .allow_stale_latest,
    storage: TargetTurnPolicyStorage,
};

const TargetTurnPolicyPlan = struct {
    entries: []const TargetTurnPolicyEntry,
    groups: []const TargetTurnPolicyGroup,
    verify_now_count: u32 = 0,
    refresh_selected_count: u32 = 0,
    use_cached_count: u32 = 0,
    defer_refresh_count: u32 = 0,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextWorkEntry(
        self: *const TargetTurnPolicyPlan,
    ) ?*const TargetTurnPolicyEntry {
        const work_count = self.verify_now_count + self.refresh_selected_count;
        if (work_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextWorkStep(
        self: *const TargetTurnPolicyPlan,
    ) ?TargetTurnPolicyStep {
        const entry = self.nextWorkEntry() orelse return null;
        return .{
            .action = entry.action,
            .entry = entry.*,
        };
    }

    pub fn verifyNowEntries(
        self: *const TargetTurnPolicyPlan,
    ) []const TargetTurnPolicyEntry {
        return self.entries[0..@as(usize, @intCast(self.verify_now_count))];
    }

    pub fn refreshSelectedEntries(
        self: *const TargetTurnPolicyPlan,
    ) []const TargetTurnPolicyEntry {
        const start: usize = @intCast(self.verify_now_count);
        const end = start + @as(usize, @intCast(self.refresh_selected_count));
        return self.entries[start..end];
    }

    pub fn workEntries(
        self: *const TargetTurnPolicyPlan,
    ) []const TargetTurnPolicyEntry {
        const end =
            @as(usize, @intCast(self.verify_now_count + self.refresh_selected_count));
        return self.entries[0..end];
    }

    pub fn idleEntries(
        self: *const TargetTurnPolicyPlan,
    ) []const TargetTurnPolicyEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.refresh_selected_count));
        return self.entries[start..];
    }

    pub fn useCachedEntries(
        self: *const TargetTurnPolicyPlan,
    ) []const TargetTurnPolicyEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.refresh_selected_count));
        const end = start + @as(usize, @intCast(self.use_cached_count));
        return self.entries[start..end];
    }

    pub fn deferredEntries(
        self: *const TargetTurnPolicyPlan,
    ) []const TargetTurnPolicyEntry {
        const start = @as(
            usize,
            @intCast(self.verify_now_count + self.refresh_selected_count + self.use_cached_count),
        );
        return self.entries[start..];
    }
};

const TargetTurnPolicyStep = struct {
    action: TargetTurnPolicyAction,
    entry: TargetTurnPolicyEntry,
};

pub const OpenTimestampsVerificationStoreVTable = struct {
    put_remote_verification: *const fn (
        ctx: *anyopaque,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        verification: *const RemoteVerification,
    ) OpenTimestampsVerificationStoreError!VerificationStorePutOutcome,
    get_verification: *const fn (
        ctx: *anyopaque,
        attestation_event_id: *const [32]u8,
    ) OpenTimestampsVerificationStoreError!?StoredRecord,
    find_verifications: *const fn (
        ctx: *anyopaque,
        target_event_id: *const [32]u8,
        out: []StoredMatch,
    ) OpenTimestampsVerificationStoreError!usize,
};

pub const OpenTimestampsVerificationStore = struct {
    ctx: *anyopaque,
    vtable: *const OpenTimestampsVerificationStoreVTable,

    pub fn putRemoteVerification(
        self: OpenTimestampsVerificationStore,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        verification: *const RemoteVerification,
    ) OpenTimestampsVerificationStoreError!VerificationStorePutOutcome {
        return self.vtable.put_remote_verification(
            self.ctx,
            target_event,
            attestation_event,
            verification,
        );
    }

    pub fn getVerification(
        self: OpenTimestampsVerificationStore,
        attestation_event_id: *const [32]u8,
    ) OpenTimestampsVerificationStoreError!?StoredRecord {
        return self.vtable.get_verification(self.ctx, attestation_event_id);
    }

    pub fn findVerifications(
        self: OpenTimestampsVerificationStore,
        target_event_id: *const [32]u8,
        out: []StoredMatch,
    ) OpenTimestampsVerificationStoreError![]const StoredMatch {
        const count = try self.vtable.find_verifications(self.ctx, target_event_id, out);
        return out[0..count];
    }
};

pub const MemoryOpenTimestampsProofStore = struct {
    records: []OpenTimestampsProofRecord,
    count: usize = 0,

    pub fn init(records: []OpenTimestampsProofRecord) MemoryOpenTimestampsProofStore {
        return .{ .records = records };
    }

    pub fn asStore(self: *MemoryOpenTimestampsProofStore) OpenTimestampsProofStore {
        return .{
            .ctx = self,
            .vtable = &proof_store_vtable,
        };
    }

    pub fn putProof(
        self: *MemoryOpenTimestampsProofStore,
        proof_url: []const u8,
        proof: []const u8,
    ) OpenTimestampsProofStoreError!void {
        if (proof_url.len > proof_store_url_max_bytes) return error.ProofUrlTooLong;
        if (proof.len > proof_store_bytes_max) return error.ProofTooLong;

        if (self.findIndex(proof_url)) |index| {
            writeProofRecord(&self.records[index], proof_url, proof);
            return;
        }
        if (self.count == self.records.len) return error.StoreFull;
        writeProofRecord(&self.records[self.count], proof_url, proof);
        self.count += 1;
    }

    pub fn getProof(
        self: *MemoryOpenTimestampsProofStore,
        proof_url: []const u8,
    ) OpenTimestampsProofStoreError!?[]const u8 {
        if (proof_url.len > proof_store_url_max_bytes) return error.ProofUrlTooLong;
        const index = self.findIndex(proof_url) orelse return null;
        return self.records[index].proofBytes();
    }

    fn findIndex(self: *const MemoryOpenTimestampsProofStore, proof_url: []const u8) ?usize {
        for (self.records[0..self.count], 0..) |*record, index| {
            if (!record.occupied) continue;
            if (!std.mem.eql(u8, record.proofUrl(), proof_url)) continue;
            return index;
        }
        return null;
    }
};

pub const MemoryOpenTimestampsVerificationStore = struct {
    records: []StoredRecord,
    count: usize = 0,

    pub fn init(records: []StoredRecord) MemoryOpenTimestampsVerificationStore {
        return .{ .records = records };
    }

    pub fn asStore(self: *MemoryOpenTimestampsVerificationStore) OpenTimestampsVerificationStore {
        return .{
            .ctx = self,
            .vtable = &verification_store_vtable,
        };
    }

    pub fn putRemoteVerification(
        self: *MemoryOpenTimestampsVerificationStore,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        verification: *const RemoteVerification,
    ) OpenTimestampsVerificationStoreError!VerificationStorePutOutcome {
        if (verification.proof_url.len > opentimestamps_verification_store_url_max_bytes) {
            return error.ProofUrlTooLong;
        }
        if (verification.verification.attestation.relay_url) |relay_url| {
            if (relay_url.len > opentimestamps_verification_store_relay_max_bytes) {
                return error.RelayUrlTooLong;
            }
        }

        if (self.findIndex(&attestation_event.id)) |index| {
            writeStoredVerificationRecord(
                &self.records[index],
                target_event,
                attestation_event,
                verification,
            );
            return .updated;
        }
        if (self.count == self.records.len) return error.StoreFull;
        writeStoredVerificationRecord(
            &self.records[self.count],
            target_event,
            attestation_event,
            verification,
        );
        self.count += 1;
        return .stored;
    }

    pub fn getVerification(
        self: *MemoryOpenTimestampsVerificationStore,
        attestation_event_id: *const [32]u8,
    ) OpenTimestampsVerificationStoreError!?StoredRecord {
        const index = self.findIndex(attestation_event_id) orelse return null;
        return self.records[index];
    }

    pub fn findVerifications(
        self: *MemoryOpenTimestampsVerificationStore,
        target_event_id: *const [32]u8,
        out: []StoredMatch,
    ) OpenTimestampsVerificationStoreError![]const StoredMatch {
        var count: usize = 0;
        for (self.records[0..self.count]) |*record| {
            if (!record.occupied) continue;
            if (!std.mem.eql(u8, record.target_event_id[0..], target_event_id[0..])) continue;
            if (count == out.len) break;
            out[count] = .{
                .attestation_event_id = record.attestation_event_id,
                .created_at = record.attestation_created_at,
            };
            count += 1;
        }
        return out[0..count];
    }

    fn findIndex(self: *const MemoryOpenTimestampsVerificationStore, attestation_event_id: *const [32]u8) ?usize {
        for (self.records[0..self.count], 0..) |*record, index| {
            if (!record.occupied) continue;
            if (std.mem.eql(u8, record.attestation_event_id[0..], attestation_event_id[0..])) {
                return index;
            }
        }
        return null;
    }
};

pub const OpenTimestampsInvalidProof = struct {
    verification: OpenTimestampsVerification,
    cause: OpenTimestampsLocalProofError,
};

pub const OpenTimestampsInvalidAttestation = struct {
    verification: OpenTimestampsVerification,
};

pub const OpenTimestampsVerificationOutcome = union(enum) {
    verified: OpenTimestampsVerification,
    target_mismatch: OpenTimestampsVerification,
    invalid_attestation: OpenTimestampsInvalidAttestation,
    invalid_local_proof: OpenTimestampsInvalidProof,
};

pub const RemoteVerification = struct {
    proof_url: []const u8,
    verification: OpenTimestampsVerification,
};

pub const OpenTimestampsFetchFailure = struct {
    proof_url: []const u8,
    attestation: noztr.nip03_opentimestamps.OpenTimestampsAttestation,
    cause: transport.HttpError,
};

pub const RemoteInvalidProof = struct {
    proof_url: []const u8,
    invalid: OpenTimestampsInvalidProof,
};

pub const RemoteInvalidAttestation = struct {
    proof_url: []const u8,
    invalid: OpenTimestampsInvalidAttestation,
};

pub const RemoteVerificationOutcome = union(enum) {
    verified: RemoteVerification,
    target_mismatch: RemoteVerification,
    invalid_attestation: RemoteInvalidAttestation,
    invalid_local_proof: RemoteInvalidProof,
    fetch_failed: OpenTimestampsFetchFailure,
};

pub const RememberedRemoteVerification = struct {
    verification: RemoteVerification,
    store_outcome: VerificationStorePutOutcome,
};

pub const RememberedRemoteVerificationError =
    OpenTimestampsVerifierError ||
    OpenTimestampsProofStoreError ||
    OpenTimestampsVerificationStoreError;

pub const StoredDiscoveryError =
    OpenTimestampsVerificationStoreError || error{BufferTooSmall};

pub const RememberedRemoteVerificationOutcome = union(enum) {
    verified: RememberedRemoteVerification,
    target_mismatch: RemoteVerification,
    invalid_attestation: RemoteInvalidAttestation,
    invalid_local_proof: RemoteInvalidProof,
    fetch_failed: OpenTimestampsFetchFailure,
};

pub const Planning = struct {
    pub const Stored = struct {
        pub const Match = StoredMatch;
        pub const Entry = StoredDiscoveryEntry;
        pub const Freshness = StoredFreshness;
        pub const FallbackPolicy = StoredFallbackPolicy;
        pub const Fresh = struct {
            pub const Entry = StoredFreshEntry;
            pub const Storage = StoredFreshStorage;
            pub const Request = StoredFreshRequest;
        };

        pub const Latest = struct {
            pub const Value = StoredLatestValue;
            pub const Request = StoredLatestFreshnessRequest;
        };

        pub const Runtime = struct {
            pub const Action = StoredRuntimeAction;
            pub const Storage = StoredRuntimeStorage;
            pub const Request = StoredRuntimeRequest;
            pub const Plan = StoredRuntimePlan;
            pub const Step = StoredRuntimeStep;
        };

        pub const Refresh = struct {
            pub const Entry = StoredRefreshEntry;
            pub const Storage = StoredRefreshStorage;
            pub const Request = StoredRefreshRequest;
            pub const Plan = StoredRefreshPlan;
            pub const Step = StoredRefreshStep;
        };
    };

    pub const Target = struct {
        pub const Value = StoredTarget;

        pub const Latest = struct {
            pub const Entry = TargetLatestEntry;
            pub const Storage = TargetLatestStorage;
            pub const Request = TargetLatestRequest;
        };

        pub const Preferred = struct {
            pub const Request = TargetPreferredRequest;
            pub const Value = TargetPreferredValue;
            pub const Entry = TargetPreferredEntry;
            pub const Storage = TargetPreferredStorage;
            pub const EntriesRequest = TargetPreferredEntriesRequest;
        };

        pub const Refresh = struct {
            pub const Entry = TargetRefreshEntry;
            pub const Storage = TargetRefreshStorage;
            pub const Request = TargetRefreshRequest;
            pub const Plan = TargetRefreshPlan;
            pub const Step = TargetRefreshStep;
        };

        pub const Readiness = struct {
            pub const Error = TargetReadinessError;
            pub const Action = TargetReadinessAction;
            pub const Entry = TargetReadinessEntry;
            pub const Group = TargetReadinessGroup;
            pub const Storage = TargetReadinessStorage;
            pub const Request = TargetReadinessRequest;
            pub const Plan = TargetReadinessPlan;
            pub const Step = TargetReadinessStep;
        };

        pub const Policy = struct {
            pub const Entry = TargetPolicyEntry;
            pub const Group = TargetPolicyGroup;
            pub const Storage = TargetPolicyStorage;
            pub const Request = TargetPolicyRequest;
            pub const Plan = TargetPolicyPlan;
        };

        pub const Cadence = struct {
            pub const Action = TargetRefreshCadenceAction;
            pub const Entry = TargetRefreshCadenceEntry;
            pub const Group = TargetRefreshCadenceGroup;
            pub const Storage = TargetRefreshCadenceStorage;
            pub const Request = TargetRefreshCadenceRequest;
            pub const Plan = TargetRefreshCadencePlan;
            pub const Step = TargetRefreshCadenceStep;
        };

        pub const Batch = struct {
            pub const Storage = TargetRefreshBatchStorage;
            pub const Request = TargetRefreshBatchRequest;
            pub const Plan = TargetRefreshBatchPlan;
            pub const Step = TargetRefreshBatchStep;
        };

        pub const Turn = struct {
            pub const Action = TargetTurnPolicyAction;
            pub const Entry = TargetTurnPolicyEntry;
            pub const Group = TargetTurnPolicyGroup;
            pub const Storage = TargetTurnPolicyStorage;
            pub const Request = TargetTurnPolicyRequest;
            pub const Plan = TargetTurnPolicyPlan;
            pub const Step = TargetTurnPolicyStep;
        };
    };
};

pub const OpenTimestampsVerifier = struct {
    fn hydrateStoredVerificationEntry(
        verification_store: OpenTimestampsVerificationStore,
        match: StoredMatch,
    ) StoredDiscoveryError!StoredDiscoveryEntry {
        const verification =
            (try verification_store.getVerification(&match.attestation_event_id)) orelse
            return error.InconsistentStoreData;
        return .{
            .match = match,
            .verification = verification,
        };
    }

    pub fn verifyLocal(
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        proof_buffer: []u8,
    ) OpenTimestampsVerifierError!OpenTimestampsVerificationOutcome {
        const attestation = noztr.nip03_opentimestamps.opentimestamps_extract(
            proof_buffer,
            attestation_event,
        ) catch |err| return narrowVerifierError(err);
        const verification: OpenTimestampsVerification = .{
            .attestation = attestation,
            .proof = proof_buffer[0..attestation.proof_len],
        };

        noztr.nip03_opentimestamps.opentimestamps_validate_target_reference(
            &attestation,
            target_event,
        ) catch |err| switch (err) {
            error.TargetMismatch => return .{ .target_mismatch = verification },
            else => return narrowVerifierError(err),
        };

        noztr.nip03_opentimestamps.opentimestamps_validate_local_proof(
            &attestation,
            verification.proof,
        ) catch |err| switch (err) {
            error.TargetMismatch => {
                return .{
                    .invalid_attestation = .{
                        .verification = verification,
                    },
                };
            },
            error.InvalidProofHeader,
            error.UnsupportedProofVersion,
            error.InvalidProofOperation,
            error.InvalidProofStructure,
            error.MissingBitcoinAttestation,
            => {
                return .{
                    .invalid_local_proof = .{
                        .verification = verification,
                        .cause = narrowLocalProofError(err),
                    },
                };
            },
            else => return narrowVerifierError(err),
        };

        return .{ .verified = verification };
    }

    pub fn verifyRemote(
        http_client: transport.HttpClient,
        request: *const OpenTimestampsRemoteProofRequest,
    ) OpenTimestampsVerifierError!RemoteVerificationOutcome {
        const attestation = noztr.nip03_opentimestamps.opentimestamps_extract(
            request.proof_buffer,
            request.attestation_event,
        ) catch |err| return narrowVerifierError(err);

        noztr.nip03_opentimestamps.opentimestamps_validate_target_reference(
            &attestation,
            request.target_event,
        ) catch |err| switch (err) {
            error.TargetMismatch => {
                return .{
                    .target_mismatch = .{
                        .proof_url = request.proof_url,
                        .verification = .{
                            .attestation = attestation,
                            .proof = request.proof_buffer[0..attestation.proof_len],
                        },
                    },
                };
            },
            else => return narrowVerifierError(err),
        };

        const fetched_proof = http_client.get(
            .{
                .url = request.proof_url,
                .accept = request.accept,
            },
            request.proof_buffer,
        ) catch |cause| {
            return .{
                .fetch_failed = .{
                    .proof_url = request.proof_url,
                    .attestation = attestation,
                    .cause = cause,
                },
            };
        };
        const verification: OpenTimestampsVerification = .{
            .attestation = attestation,
            .proof = fetched_proof,
        };

        noztr.nip03_opentimestamps.opentimestamps_validate_local_proof(
            &attestation,
            fetched_proof,
        ) catch |err| switch (err) {
            error.TargetMismatch => {
                return .{
                    .invalid_attestation = .{
                        .proof_url = request.proof_url,
                        .invalid = .{
                            .verification = verification,
                        },
                    },
                };
            },
            error.InvalidProofHeader,
            error.UnsupportedProofVersion,
            error.InvalidProofOperation,
            error.InvalidProofStructure,
            error.MissingBitcoinAttestation,
            => {
                return .{
                    .invalid_local_proof = .{
                        .proof_url = request.proof_url,
                        .invalid = .{
                            .verification = verification,
                            .cause = narrowLocalProofError(err),
                        },
                    },
                };
            },
            else => return narrowVerifierError(err),
        };

        return .{
            .verified = .{
                .proof_url = request.proof_url,
                .verification = verification,
            },
        };
    }

    pub fn verifyRemoteCached(
        http_client: transport.HttpClient,
        proof_store: OpenTimestampsProofStore,
        request: *const OpenTimestampsRemoteProofRequest,
    ) (OpenTimestampsVerifierError || OpenTimestampsProofStoreError)!RemoteVerificationOutcome {
        const attestation = noztr.nip03_opentimestamps.opentimestamps_extract(
            request.proof_buffer,
            request.attestation_event,
        ) catch |err| return narrowVerifierError(err);

        noztr.nip03_opentimestamps.opentimestamps_validate_target_reference(
            &attestation,
            request.target_event,
        ) catch |err| switch (err) {
            error.TargetMismatch => {
                return .{
                    .target_mismatch = .{
                        .proof_url = request.proof_url,
                        .verification = .{
                            .attestation = attestation,
                            .proof = request.proof_buffer[0..attestation.proof_len],
                        },
                    },
                };
            },
            else => return narrowVerifierError(err),
        };

        const proof = if (try proof_store.getProof(request.proof_url)) |stored|
            stored
        else blk: {
            const fetched = http_client.get(
                .{
                    .url = request.proof_url,
                    .accept = request.accept,
                },
                request.proof_buffer,
            ) catch |cause| {
                return .{
                    .fetch_failed = .{
                        .proof_url = request.proof_url,
                        .attestation = attestation,
                        .cause = cause,
                    },
                };
            };
            try proof_store.putProof(request.proof_url, fetched);
            break :blk fetched;
        };

        return verifyFetchedProof(request.proof_url, attestation, proof);
    }

    pub fn verifyRemoteCachedAndRemember(
        http_client: transport.HttpClient,
        proof_store: OpenTimestampsProofStore,
        verification_store: OpenTimestampsVerificationStore,
        request: *const OpenTimestampsRemoteProofRequest,
    ) RememberedRemoteVerificationError!RememberedRemoteVerificationOutcome {
        const outcome = try verifyRemoteCached(http_client, proof_store, request);
        return switch (outcome) {
            .verified => |verification| .{
                .verified = .{
                    .verification = verification,
                    .store_outcome = try rememberRemoteVerification(
                        verification_store,
                        request.target_event,
                        request.attestation_event,
                        &verification,
                    ),
                },
            },
            .target_mismatch => |verification| .{ .target_mismatch = verification },
            .invalid_attestation => |invalid| .{ .invalid_attestation = invalid },
            .invalid_local_proof => |invalid| .{ .invalid_local_proof = invalid },
            .fetch_failed => |failure| .{ .fetch_failed = failure },
        };
    }

    pub fn rememberRemoteVerification(
        verification_store: OpenTimestampsVerificationStore,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        verification: *const RemoteVerification,
    ) OpenTimestampsVerificationStoreError!VerificationStorePutOutcome {
        return verification_store.putRemoteVerification(target_event, attestation_event, verification);
    }

    pub fn getStoredVerification(
        verification_store: OpenTimestampsVerificationStore,
        attestation_event_id: *const [32]u8,
    ) OpenTimestampsVerificationStoreError!?StoredRecord {
        return verification_store.getVerification(attestation_event_id);
    }

    pub fn discoverStoredVerifications(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredMatchRequest,
    ) OpenTimestampsVerificationStoreError![]const StoredMatch {
        return verification_store.findVerifications(request.target_event_id, request.results);
    }

    pub fn discoverStoredVerificationEntries(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredDiscoveryRequest,
    ) StoredDiscoveryError![]const StoredDiscoveryEntry {
        const matches = try verification_store.findVerifications(
            request.target_event_id,
            request.storage.matches,
        );
        if (matches.len > request.storage.entries.len) return error.BufferTooSmall;

        for (matches, 0..) |match, index| {
            request.storage.entries[index] = try hydrateStoredVerificationEntry(
                verification_store,
                match,
            );
        }
        return request.storage.entries[0..matches.len];
    }

    pub fn getLatestStoredVerification(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredLatestRequest,
    ) OpenTimestampsVerificationStoreError!?StoredRecord {
        const matches = try verification_store.findVerifications(request.target_event_id, request.matches);
        if (matches.len == 0) return null;

        var latest = matches[0];
        for (matches[1..]) |match| {
            if (match.created_at > latest.created_at) latest = match;
        }
        return (try verification_store.getVerification(&latest.attestation_event_id)) orelse
            return error.InconsistentStoreData;
    }

    pub fn getLatestStoredVerificationFreshness(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredLatestFreshnessRequest,
    ) OpenTimestampsVerificationStoreError!?StoredLatestValue {
        const matches = try verification_store.findVerifications(request.target_event_id, request.matches);
        if (matches.len == 0) return null;

        var latest = matches[0];
        for (matches[1..]) |match| {
            if (match.created_at > latest.created_at) latest = match;
        }

        const verification =
            (try verification_store.getVerification(&latest.attestation_event_id)) orelse
            return error.InconsistentStoreData;
        const age_seconds = if (request.now_unix_seconds > latest.created_at)
            request.now_unix_seconds - latest.created_at
        else
            0;
        return .{
            .latest = .{
                .match = latest,
                .verification = verification,
            },
            .freshness = if (age_seconds <= request.max_age_seconds) .fresh else .stale,
            .age_seconds = age_seconds,
        };
    }

    pub fn discoverLatestStoredVerificationFreshnessForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetLatestRequest,
    ) StoredDiscoveryError![]const TargetLatestEntry {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;

        for (request.targets, 0..) |target, index| {
            request.storage.entries[index] = .{
                .target = target,
                .latest = try getLatestStoredVerificationFreshness(
                    verification_store,
                    .{
                        .target_event_id = &target.target_event_id,
                        .now_unix_seconds = request.now_unix_seconds,
                        .max_age_seconds = request.max_age_seconds,
                        .matches = request.storage.matches,
                    },
                ),
            };
        }
        return request.storage.entries[0..request.targets.len];
    }

    pub fn getPreferredStoredVerification(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetPreferredRequest,
    ) StoredDiscoveryError!?TargetPreferredValue {
        const entries = try discoverStoredVerificationEntriesWithFreshness(
            verification_store,
            .{
                .target_event_id = request.target_event_id,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = request.storage,
            },
        );

        var latest_stale: ?TargetPreferredValue = null;
        var best_fresh: ?TargetPreferredValue = null;
        for (entries) |entry| {
            const candidate: TargetPreferredValue = .{
                .entry = entry.entry,
                .freshness = entry.freshness,
                .age_seconds = entry.age_seconds,
            };
            switch (entry.freshness) {
                .fresh => {
                    if (best_fresh == null or
                        candidate.entry.match.created_at > best_fresh.?.entry.match.created_at)
                    {
                        best_fresh = candidate;
                    }
                },
                .stale => {
                    if (latest_stale == null or
                        candidate.entry.match.created_at > latest_stale.?.entry.match.created_at)
                    {
                        latest_stale = candidate;
                    }
                },
            }
        }

        if (best_fresh) |preferred| return preferred;
        if (request.fallback_policy == .allow_stale_latest) return latest_stale;
        return null;
    }

    pub fn getPreferredStoredVerificationForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetPreferredEntriesRequest,
    ) StoredDiscoveryError!?TargetPreferredEntry {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;

        var best_fresh: ?TargetPreferredEntry = null;
        var best_stale: ?TargetPreferredEntry = null;
        for (request.targets) |target| {
            const preferred = try getPreferredStoredVerification(
                verification_store,
                .{
                    .target_event_id = &target.target_event_id,
                    .now_unix_seconds = request.now_unix_seconds,
                    .max_age_seconds = request.max_age_seconds,
                    .fallback_policy = request.fallback_policy,
                    .storage = .init(
                        request.storage.matches,
                        request.storage.freshness_entries,
                    ),
                },
            ) orelse continue;

            const candidate: TargetPreferredEntry = .{
                .target = target,
                .preferred = preferred,
            };
            switch (preferred.freshness) {
                .fresh => {
                    if (best_fresh == null or
                        preferred.entry.match.created_at > best_fresh.?.preferred.?.entry.match.created_at)
                    {
                        best_fresh = candidate;
                    }
                },
                .stale => {
                    if (best_stale == null or
                        preferred.entry.match.created_at > best_stale.?.preferred.?.entry.match.created_at)
                    {
                        best_stale = candidate;
                    }
                },
            }
        }

        if (best_fresh) |preferred| return preferred;
        return switch (request.fallback_policy) {
            .require_fresh => null,
            .allow_stale_latest => best_stale,
        };
    }

    pub fn discoverStoredVerificationEntriesWithFreshness(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredFreshRequest,
    ) StoredDiscoveryError![]const StoredFreshEntry {
        const matches = try verification_store.findVerifications(
            request.target_event_id,
            request.storage.matches,
        );
        if (matches.len > request.storage.entries.len) return error.BufferTooSmall;

        for (matches, 0..) |match, index| {
            const entry = try hydrateStoredVerificationEntry(
                verification_store,
                match,
            );
            const age_seconds = if (request.now_unix_seconds > match.created_at)
                request.now_unix_seconds - match.created_at
            else
                0;
            request.storage.entries[index] = .{
                .entry = entry,
                .freshness = if (age_seconds <= request.max_age_seconds) .fresh else .stale,
                .age_seconds = age_seconds,
            };
        }
        return request.storage.entries[0..matches.len];
    }

    pub fn inspectStoredVerificationRuntime(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredRuntimeRequest,
    ) StoredDiscoveryError!StoredRuntimePlan {
        const entries = try discoverStoredVerificationEntriesWithFreshness(
            verification_store,
            .{
                .target_event_id = request.target_event_id,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .{
                    .matches = request.storage.matches,
                    .entries = request.storage.entries,
                },
            },
        );

        var fresh_count: u32 = 0;
        var stale_count: u32 = 0;
        var best_fresh_index: ?u32 = null;
        var best_stale_index: ?u32 = null;

        for (entries, 0..) |entry, index| {
            const entry_index: u32 = @intCast(index);
            switch (entry.freshness) {
                .fresh => {
                    fresh_count += 1;
                    if (best_fresh_index == null or
                        entry.entry.match.created_at >
                            entries[@intCast(best_fresh_index.?)].entry.match.created_at)
                    {
                        best_fresh_index = entry_index;
                    }
                },
                .stale => {
                    stale_count += 1;
                    if (best_stale_index == null or
                        entry.entry.match.created_at >
                            entries[@intCast(best_stale_index.?)].entry.match.created_at)
                    {
                        best_stale_index = entry_index;
                    }
                },
            }
        }

        if (best_fresh_index) |preferred_index| {
            return .{
                .action = .use_preferred,
                .entries = entries,
                .preferred_index = preferred_index,
                .fresh_count = fresh_count,
                .stale_count = stale_count,
            };
        }
        if (best_stale_index) |preferred_index| {
            return .{
                .action = switch (request.fallback_policy) {
                    .require_fresh => .refresh_existing,
                    .allow_stale_latest => .use_stale_and_refresh,
                },
                .entries = entries,
                .preferred_index = preferred_index,
                .fresh_count = fresh_count,
                .stale_count = stale_count,
            };
        }
        return .{
            .action = .verify_now,
            .entries = entries,
            .fresh_count = 0,
            .stale_count = 0,
        };
    }

    pub fn planStoredVerificationRefresh(
        verification_store: OpenTimestampsVerificationStore,
        request: StoredRefreshRequest,
    ) StoredDiscoveryError!StoredRefreshPlan {
        const freshness_entries = try discoverStoredVerificationEntriesWithFreshness(
            verification_store,
            .{
                .target_event_id = request.target_event_id,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .{
                    .matches = request.storage.matches,
                    .entries = request.storage.freshness_entries,
                },
            },
        );

        var stale_count: usize = 0;
        for (freshness_entries) |freshness_entry| {
            if (freshness_entry.freshness != .stale) continue;
            if (stale_count == request.storage.entries.len) return error.BufferTooSmall;

            var insert_index = stale_count;
            while (insert_index > 0) : (insert_index -= 1) {
                const previous = request.storage.entries[insert_index - 1].entry.entry.match.created_at;
                if (previous >= freshness_entry.entry.match.created_at) break;
                request.storage.entries[insert_index] = request.storage.entries[insert_index - 1];
            }
            request.storage.entries[insert_index] = .{ .entry = freshness_entry };
            stale_count += 1;
        }

        return .{
            .entries = request.storage.entries[0..stale_count],
        };
    }

    pub fn planStoredVerificationRefreshForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetRefreshRequest,
    ) StoredDiscoveryError!TargetRefreshPlan {
        const freshness_entries = try discoverLatestStoredVerificationFreshnessForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .{
                    .matches = request.storage.matches,
                    .entries = request.storage.freshness_entries,
                },
            },
        );

        var stale_count: usize = 0;
        for (freshness_entries) |freshness_entry| {
            const latest = freshness_entry.latest orelse continue;
            if (latest.freshness != .stale) continue;
            if (stale_count == request.storage.entries.len) return error.BufferTooSmall;

            var insert_index = stale_count;
            while (insert_index > 0) : (insert_index -= 1) {
                const previous = request.storage.entries[insert_index - 1].latest.latest.match.created_at;
                if (previous >= latest.latest.match.created_at) break;
                request.storage.entries[insert_index] = request.storage.entries[insert_index - 1];
            }
            request.storage.entries[insert_index] = .{
                .target = freshness_entry.target,
                .latest = latest,
            };
            stale_count += 1;
        }

        return .{
            .entries = request.storage.entries[0..stale_count],
        };
    }

    pub fn inspectStoredVerificationPolicyForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetPolicyRequest,
    ) StoredDiscoveryError!TargetPolicyPlan {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;
        if (request.storage.groups.len < 4) return error.BufferTooSmall;

        const latest_entries = try discoverLatestStoredVerificationFreshnessForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .{
                    .matches = request.storage.matches,
                    .entries = request.storage.latest_entries,
                },
            },
        );

        var verify_now_count: usize = 0;
        var use_preferred_count: usize = 0;
        var use_stale_and_refresh_count: usize = 0;
        var refresh_existing_count: usize = 0;
        var fresh_count: u32 = 0;
        var stale_count: u32 = 0;
        var missing_count: u32 = 0;

        for (latest_entries) |entry| {
            const action: StoredRuntimeAction = if (entry.latest) |latest|
                switch (latest.freshness) {
                    .fresh => .use_preferred,
                    .stale => switch (request.fallback_policy) {
                        .require_fresh => .refresh_existing,
                        .allow_stale_latest => .use_stale_and_refresh,
                    },
                }
            else
                .verify_now;

            switch (action) {
                .verify_now => verify_now_count += 1,
                .use_preferred => use_preferred_count += 1,
                .use_stale_and_refresh => use_stale_and_refresh_count += 1,
                .refresh_existing => refresh_existing_count += 1,
            }

            if (entry.latest) |latest| {
                switch (latest.freshness) {
                    .fresh => fresh_count += 1,
                    .stale => stale_count += 1,
                }
            } else {
                missing_count += 1;
            }
        }

        const verify_now_start: usize = 0;
        const use_preferred_start = verify_now_start + verify_now_count;
        const use_stale_and_refresh_start = use_preferred_start + use_preferred_count;
        const refresh_existing_start = use_stale_and_refresh_start + use_stale_and_refresh_count;

        var next_verify_now = verify_now_start;
        var next_use_preferred = use_preferred_start;
        var next_use_stale_and_refresh = use_stale_and_refresh_start;
        var next_refresh_existing = refresh_existing_start;

        for (latest_entries) |entry| {
            const action: StoredRuntimeAction = if (entry.latest) |latest|
                switch (latest.freshness) {
                    .fresh => .use_preferred,
                    .stale => switch (request.fallback_policy) {
                        .require_fresh => .refresh_existing,
                        .allow_stale_latest => .use_stale_and_refresh,
                    },
                }
            else
                .verify_now;

            const insert_index = switch (action) {
                .verify_now => blk: {
                    defer next_verify_now += 1;
                    break :blk next_verify_now;
                },
                .use_preferred => blk: {
                    defer next_use_preferred += 1;
                    break :blk next_use_preferred;
                },
                .use_stale_and_refresh => blk: {
                    defer next_use_stale_and_refresh += 1;
                    break :blk next_use_stale_and_refresh;
                },
                .refresh_existing => blk: {
                    defer next_refresh_existing += 1;
                    break :blk next_refresh_existing;
                },
            };

            request.storage.entries[insert_index] = .{
                .target = entry.target,
                .action = action,
                .latest = entry.latest,
            };
        }

        const total_entries = request.targets.len;
        request.storage.groups[0] = .{
            .action = .verify_now,
            .entries = request.storage.entries[verify_now_start..use_preferred_start],
        };
        request.storage.groups[1] = .{
            .action = .use_preferred,
            .entries = request.storage.entries[use_preferred_start..use_stale_and_refresh_start],
        };
        request.storage.groups[2] = .{
            .action = .use_stale_and_refresh,
            .entries = request.storage.entries[use_stale_and_refresh_start..refresh_existing_start],
        };
        request.storage.groups[3] = .{
            .action = .refresh_existing,
            .entries = request.storage.entries[refresh_existing_start..total_entries],
        };

        return .{
            .entries = request.storage.entries[0..total_entries],
            .groups = request.storage.groups[0..4],
            .verify_now_count = @intCast(verify_now_count),
            .use_preferred_count = @intCast(use_preferred_count),
            .use_stale_and_refresh_count = @intCast(use_stale_and_refresh_count),
            .refresh_existing_count = @intCast(refresh_existing_count),
            .fresh_count = fresh_count,
            .stale_count = stale_count,
            .missing_count = missing_count,
        };
    }

    pub fn inspectStoredVerificationRefreshCadenceForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetRefreshCadenceRequest,
    ) StoredDiscoveryError!TargetRefreshCadencePlan {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;
        if (request.storage.groups.len < 5) return error.BufferTooSmall;

        const latest_entries = try discoverLatestStoredVerificationFreshnessForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .{
                    .matches = request.storage.matches,
                    .entries = request.storage.latest_entries,
                },
            },
        );

        var verify_now_count: usize = 0;
        var refresh_now_count: usize = 0;
        var usable_while_refreshing_count: usize = 0;
        var refresh_soon_count: usize = 0;
        var stable_count: usize = 0;
        var fresh_count: u32 = 0;
        var stale_count: u32 = 0;
        var missing_count: u32 = 0;

        for (latest_entries) |entry| {
            const action: TargetRefreshCadenceAction = if (entry.latest) |latest|
                switch (latest.freshness) {
                    .fresh => if (latest.age_seconds >= request.refresh_soon_age_seconds)
                        .refresh_soon
                    else
                        .stable,
                    .stale => switch (request.fallback_policy) {
                        .require_fresh => .refresh_now,
                        .allow_stale_latest => .usable_while_refreshing,
                    },
                }
            else
                .verify_now;

            switch (action) {
                .verify_now => verify_now_count += 1,
                .refresh_now => refresh_now_count += 1,
                .usable_while_refreshing => usable_while_refreshing_count += 1,
                .refresh_soon => refresh_soon_count += 1,
                .stable => stable_count += 1,
            }

            if (entry.latest) |latest| {
                switch (latest.freshness) {
                    .fresh => fresh_count += 1,
                    .stale => stale_count += 1,
                }
            } else {
                missing_count += 1;
            }
        }

        const verify_now_start: usize = 0;
        const refresh_now_start = verify_now_start + verify_now_count;
        const usable_while_refreshing_start = refresh_now_start + refresh_now_count;
        const refresh_soon_start = usable_while_refreshing_start + usable_while_refreshing_count;
        const stable_start = refresh_soon_start + refresh_soon_count;

        var next_verify_now = verify_now_start;
        var next_refresh_now = refresh_now_start;
        var next_usable_while_refreshing = usable_while_refreshing_start;
        var next_refresh_soon = refresh_soon_start;
        var next_stable = stable_start;

        for (latest_entries) |entry| {
            const action: TargetRefreshCadenceAction = if (entry.latest) |latest|
                switch (latest.freshness) {
                    .fresh => if (latest.age_seconds >= request.refresh_soon_age_seconds)
                        .refresh_soon
                    else
                        .stable,
                    .stale => switch (request.fallback_policy) {
                        .require_fresh => .refresh_now,
                        .allow_stale_latest => .usable_while_refreshing,
                    },
                }
            else
                .verify_now;

            const insert_index = switch (action) {
                .verify_now => blk: {
                    defer next_verify_now += 1;
                    break :blk next_verify_now;
                },
                .refresh_now => blk: {
                    defer next_refresh_now += 1;
                    break :blk next_refresh_now;
                },
                .usable_while_refreshing => blk: {
                    defer next_usable_while_refreshing += 1;
                    break :blk next_usable_while_refreshing;
                },
                .refresh_soon => blk: {
                    defer next_refresh_soon += 1;
                    break :blk next_refresh_soon;
                },
                .stable => blk: {
                    defer next_stable += 1;
                    break :blk next_stable;
                },
            };

            request.storage.entries[insert_index] = .{
                .target = entry.target,
                .action = action,
                .latest = entry.latest,
            };
        }

        const total_entries = request.targets.len;
        request.storage.groups[0] = .{
            .action = .verify_now,
            .entries = request.storage.entries[verify_now_start..refresh_now_start],
        };
        request.storage.groups[1] = .{
            .action = .refresh_now,
            .entries = request.storage.entries[refresh_now_start..usable_while_refreshing_start],
        };
        request.storage.groups[2] = .{
            .action = .usable_while_refreshing,
            .entries = request.storage.entries[usable_while_refreshing_start..refresh_soon_start],
        };
        request.storage.groups[3] = .{
            .action = .refresh_soon,
            .entries = request.storage.entries[refresh_soon_start..stable_start],
        };
        request.storage.groups[4] = .{
            .action = .stable,
            .entries = request.storage.entries[stable_start..total_entries],
        };

        return .{
            .entries = request.storage.entries[0..total_entries],
            .groups = request.storage.groups[0..5],
            .verify_now_count = @intCast(verify_now_count),
            .refresh_now_count = @intCast(refresh_now_count),
            .usable_while_refreshing_count = @intCast(usable_while_refreshing_count),
            .refresh_soon_count = @intCast(refresh_soon_count),
            .stable_count = @intCast(stable_count),
            .fresh_count = fresh_count,
            .stale_count = stale_count,
            .missing_count = missing_count,
        };
    }

    pub fn inspectStoredVerificationRefreshBatchForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetRefreshBatchRequest,
    ) StoredDiscoveryError!TargetRefreshBatchPlan {
        const cadence = try inspectStoredVerificationRefreshCadenceForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .refresh_soon_age_seconds = request.refresh_soon_age_seconds,
                .fallback_policy = request.fallback_policy,
                .storage = .init(
                    request.storage.matches,
                    request.storage.latest_entries,
                    request.storage.cadence_entries,
                    request.storage.cadence_groups,
                ),
            },
        );

        const due_count = cadence.verify_now_count +
            cadence.refresh_now_count +
            cadence.usable_while_refreshing_count +
            cadence.refresh_soon_count;
        const due_len: usize = @intCast(due_count);
        const selected_len = @min(request.max_selected, due_len);

        return .{
            .entries = cadence.entries[0..due_len],
            .selected_count = @intCast(selected_len),
            .deferred_count = @intCast(due_len - selected_len),
        };
    }

    pub fn inspectStoredVerificationTurnPolicyForTargets(
        verification_store: OpenTimestampsVerificationStore,
        request: TargetTurnPolicyRequest,
    ) StoredDiscoveryError!TargetTurnPolicyPlan {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;
        if (request.storage.groups.len < 4) return error.BufferTooSmall;

        const latest_entries = try discoverLatestStoredVerificationFreshnessForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .{
                    .matches = request.storage.matches,
                    .entries = request.storage.latest_entries,
                },
            },
        );
        const batch = try inspectStoredVerificationRefreshBatchForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .refresh_soon_age_seconds = request.refresh_soon_age_seconds,
                .max_selected = request.max_selected,
                .fallback_policy = request.fallback_policy,
                .storage = .init(
                    request.storage.matches,
                    request.storage.latest_entries,
                    request.storage.cadence_entries,
                    request.storage.cadence_groups,
                ),
            },
        );

        var verify_now_count: usize = 0;
        var refresh_selected_count: usize = 0;
        var use_cached_count: usize = 0;
        var defer_refresh_count: usize = 0;
        var fresh_count: u32 = 0;
        var stale_count: u32 = 0;
        var missing_count: u32 = 0;

        for (latest_entries) |latest_entry| {
            const action: TargetTurnPolicyAction =
                if (latest_entry.latest == null)
                    .verify_now
                else if (containsStoredVerificationTarget(batch.selectedEntries(), latest_entry.target))
                    .refresh_selected
                else if (containsStoredVerificationTarget(batch.deferredEntries(), latest_entry.target))
                    .defer_refresh
                else
                    .use_cached;

            switch (action) {
                .verify_now => verify_now_count += 1,
                .refresh_selected => refresh_selected_count += 1,
                .use_cached => use_cached_count += 1,
                .defer_refresh => defer_refresh_count += 1,
            }

            if (latest_entry.latest) |latest| {
                switch (latest.freshness) {
                    .fresh => fresh_count += 1,
                    .stale => stale_count += 1,
                }
            } else {
                missing_count += 1;
            }
        }

        const verify_now_start: usize = 0;
        const refresh_selected_start = verify_now_start + verify_now_count;
        const use_cached_start = refresh_selected_start + refresh_selected_count;
        const defer_refresh_start = use_cached_start + use_cached_count;

        var next_verify_now = verify_now_start;
        var next_refresh_selected = refresh_selected_start;
        var next_use_cached = use_cached_start;
        var next_defer_refresh = defer_refresh_start;

        for (latest_entries) |latest_entry| {
            const action: TargetTurnPolicyAction =
                if (latest_entry.latest == null)
                    .verify_now
                else if (containsStoredVerificationTarget(batch.selectedEntries(), latest_entry.target))
                    .refresh_selected
                else if (containsStoredVerificationTarget(batch.deferredEntries(), latest_entry.target))
                    .defer_refresh
                else
                    .use_cached;

            const insert_index = switch (action) {
                .verify_now => blk: {
                    defer next_verify_now += 1;
                    break :blk next_verify_now;
                },
                .refresh_selected => blk: {
                    defer next_refresh_selected += 1;
                    break :blk next_refresh_selected;
                },
                .use_cached => blk: {
                    defer next_use_cached += 1;
                    break :blk next_use_cached;
                },
                .defer_refresh => blk: {
                    defer next_defer_refresh += 1;
                    break :blk next_defer_refresh;
                },
            };

            request.storage.entries[insert_index] = .{
                .target = latest_entry.target,
                .action = action,
                .latest = latest_entry.latest,
            };
        }

        const total_entries = request.targets.len;
        request.storage.groups[0] = .{
            .action = .verify_now,
            .entries = request.storage.entries[verify_now_start..refresh_selected_start],
        };
        request.storage.groups[1] = .{
            .action = .refresh_selected,
            .entries = request.storage.entries[refresh_selected_start..use_cached_start],
        };
        request.storage.groups[2] = .{
            .action = .use_cached,
            .entries = request.storage.entries[use_cached_start..defer_refresh_start],
        };
        request.storage.groups[3] = .{
            .action = .defer_refresh,
            .entries = request.storage.entries[defer_refresh_start..total_entries],
        };

        return .{
            .entries = request.storage.entries[0..total_entries],
            .groups = request.storage.groups[0..4],
            .verify_now_count = @intCast(verify_now_count),
            .refresh_selected_count = @intCast(refresh_selected_count),
            .use_cached_count = @intCast(use_cached_count),
            .defer_refresh_count = @intCast(defer_refresh_count),
            .fresh_count = fresh_count,
            .stale_count = stale_count,
            .missing_count = missing_count,
        };
    }

    pub fn inspectStoredVerificationRefreshReadinessForTargets(
        verification_store: OpenTimestampsVerificationStore,
        event_archive: store_archive.EventArchive,
        request: TargetReadinessRequest,
    ) TargetReadinessError!TargetReadinessPlan {
        if (request.storage.groups.len < 4) return error.BufferTooSmall;

        const refresh = try planStoredVerificationRefreshForTargets(
            verification_store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = .init(
                    request.storage.matches,
                    request.storage.freshness_entries,
                    request.storage.refresh_entries,
                    request.storage.target_refresh_entries,
                ),
            },
        );

        var ready_count: usize = 0;
        var missing_target_event_count: usize = 0;
        var missing_attestation_event_count: usize = 0;
        var missing_events_count: usize = 0;

        for (refresh.entries) |entry| {
            const target_event_id_hex = std.fmt.bytesToHex(entry.target.target_event_id, .lower);
            const attestation_event_id_hex =
                std.fmt.bytesToHex(entry.latest.latest.match.attestation_event_id, .lower);
            const target_record = try event_archive.getEventById(target_event_id_hex[0..]);
            const attestation_record = try event_archive.getEventById(attestation_event_id_hex[0..]);
            const action = classifyStoredVerificationTargetRefreshReadiness(
                target_record != null,
                attestation_record != null,
            );

            switch (action) {
                .ready_refresh => ready_count += 1,
                .missing_target_event => missing_target_event_count += 1,
                .missing_attestation_event => missing_attestation_event_count += 1,
                .missing_events => missing_events_count += 1,
            }
        }

        const ready_start: usize = 0;
        const missing_target_event_start = ready_start + ready_count;
        const missing_attestation_event_start =
            missing_target_event_start + missing_target_event_count;
        const missing_events_start =
            missing_attestation_event_start + missing_attestation_event_count;

        var next_ready = ready_start;
        var next_missing_target_event = missing_target_event_start;
        var next_missing_attestation_event = missing_attestation_event_start;
        var next_missing_events = missing_events_start;
        var target_record_count: usize = 0;
        var attestation_record_count: usize = 0;

        for (refresh.entries) |entry| {
            const target_event_id_hex = std.fmt.bytesToHex(entry.target.target_event_id, .lower);
            const attestation_event_id_hex =
                std.fmt.bytesToHex(entry.latest.latest.match.attestation_event_id, .lower);
            const target_record = try event_archive.getEventById(target_event_id_hex[0..]);
            const attestation_record = try event_archive.getEventById(attestation_event_id_hex[0..]);
            const action = classifyStoredVerificationTargetRefreshReadiness(
                target_record != null,
                attestation_record != null,
            );

            const insert_index = switch (action) {
                .ready_refresh => blk: {
                    defer next_ready += 1;
                    break :blk next_ready;
                },
                .missing_target_event => blk: {
                    defer next_missing_target_event += 1;
                    break :blk next_missing_target_event;
                },
                .missing_attestation_event => blk: {
                    defer next_missing_attestation_event += 1;
                    break :blk next_missing_attestation_event;
                },
                .missing_events => blk: {
                    defer next_missing_events += 1;
                    break :blk next_missing_events;
                },
            };

            var readiness_entry = TargetReadinessEntry{
                .target = entry.target,
                .latest = entry.latest,
                .action = action,
            };
            if (target_record) |record| {
                if (target_record_count == request.storage.target_records.len) return error.BufferTooSmall;
                request.storage.target_records[target_record_count] = record;
                readiness_entry.target_record_index = @intCast(target_record_count);
                target_record_count += 1;
            }
            if (attestation_record) |record| {
                if (attestation_record_count == request.storage.attestation_records.len) return error.BufferTooSmall;
                request.storage.attestation_records[attestation_record_count] = record;
                readiness_entry.attestation_record_index = @intCast(attestation_record_count);
                attestation_record_count += 1;
            }
            request.storage.entries[insert_index] = readiness_entry;
        }

        const total_entries = refresh.entries.len;
        request.storage.groups[0] = .{
            .action = .ready_refresh,
            .entries = request.storage.entries[ready_start..missing_target_event_start],
        };
        request.storage.groups[1] = .{
            .action = .missing_target_event,
            .entries = request.storage.entries[missing_target_event_start..missing_attestation_event_start],
        };
        request.storage.groups[2] = .{
            .action = .missing_attestation_event,
            .entries = request.storage.entries[missing_attestation_event_start..missing_events_start],
        };
        request.storage.groups[3] = .{
            .action = .missing_events,
            .entries = request.storage.entries[missing_events_start..total_entries],
        };

        return .{
            .entries = request.storage.entries[0..total_entries],
            .groups = request.storage.groups[0..4],
            .target_records = request.storage.target_records[0..target_record_count],
            .attestation_records = request.storage.attestation_records[0..attestation_record_count],
            .ready_count = @intCast(ready_count),
            .missing_target_event_count = @intCast(missing_target_event_count),
            .missing_attestation_event_count = @intCast(missing_attestation_event_count),
            .missing_events_count = @intCast(missing_events_count),
        };
    }
};

fn containsStoredVerificationTarget(
    entries: []const TargetRefreshCadenceEntry,
    target: StoredTarget,
) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, &entry.target.target_event_id, &target.target_event_id)) return true;
    }
    return false;
}

fn classifyStoredVerificationTargetRefreshReadiness(
    has_target_event: bool,
    has_attestation_event: bool,
) TargetReadinessAction {
    if (has_target_event and has_attestation_event) return .ready_refresh;
    if (!has_target_event and has_attestation_event) return .missing_target_event;
    if (has_target_event and !has_attestation_event) return .missing_attestation_event;
    return .missing_events;
}

fn verifyFetchedProof(
    proof_url: []const u8,
    attestation: noztr.nip03_opentimestamps.OpenTimestampsAttestation,
    proof: []const u8,
) OpenTimestampsVerifierError!RemoteVerificationOutcome {
    const verification: OpenTimestampsVerification = .{
        .attestation = attestation,
        .proof = proof,
    };

    noztr.nip03_opentimestamps.opentimestamps_validate_local_proof(
        &attestation,
        proof,
    ) catch |err| switch (err) {
        error.TargetMismatch => {
            return .{
                .invalid_attestation = .{
                    .proof_url = proof_url,
                    .invalid = .{
                        .verification = verification,
                    },
                },
            };
        },
        error.InvalidProofHeader,
        error.UnsupportedProofVersion,
        error.InvalidProofOperation,
        error.InvalidProofStructure,
        error.MissingBitcoinAttestation,
        => {
            return .{
                .invalid_local_proof = .{
                    .proof_url = proof_url,
                    .invalid = .{
                        .verification = verification,
                        .cause = narrowLocalProofError(err),
                    },
                },
            };
        },
        else => return narrowVerifierError(err),
    };

    return .{
        .verified = .{
            .proof_url = proof_url,
            .verification = verification,
        },
    };
}

fn writeProofRecord(record: *OpenTimestampsProofRecord, proof_url: []const u8, proof: []const u8) void {
    @memset(record.proof_url[0..], 0);
    @memcpy(record.proof_url[0..proof_url.len], proof_url);
    record.proof_url_len = @intCast(proof_url.len);
    @memset(record.proof[0..], 0);
    @memcpy(record.proof[0..proof.len], proof);
    record.proof_len = @intCast(proof.len);
    record.occupied = true;
}

fn proofStorePut(
    ctx: *anyopaque,
    proof_url: []const u8,
    proof: []const u8,
) OpenTimestampsProofStoreError!void {
    const self: *MemoryOpenTimestampsProofStore = @ptrCast(@alignCast(ctx));
    return self.putProof(proof_url, proof);
}

fn proofStoreGet(
    ctx: *anyopaque,
    proof_url: []const u8,
) OpenTimestampsProofStoreError!?[]const u8 {
    const self: *MemoryOpenTimestampsProofStore = @ptrCast(@alignCast(ctx));
    return self.getProof(proof_url);
}

const proof_store_vtable = OpenTimestampsProofStoreVTable{
    .put_proof = proofStorePut,
    .get_proof = proofStoreGet,
};

fn writeStoredVerificationRecord(
    record: *StoredRecord,
    target_event: *const noztr.nip01_event.Event,
    attestation_event: *const noztr.nip01_event.Event,
    verification: *const RemoteVerification,
) void {
    record.target_event_id = target_event.id;
    record.attestation_event_id = attestation_event.id;
    record.attestation_created_at = attestation_event.created_at;
    record.target_kind = verification.verification.attestation.target_kind;
    @memset(record.proof_url[0..], 0);
    @memcpy(record.proof_url[0..verification.proof_url.len], verification.proof_url);
    record.proof_url_len = @intCast(verification.proof_url.len);
    @memset(record.relay_url[0..], 0);
    if (verification.verification.attestation.relay_url) |relay_url| {
        @memcpy(record.relay_url[0..relay_url.len], relay_url);
        record.relay_url_len = @intCast(relay_url.len);
    } else {
        record.relay_url_len = 0;
    }
    record.occupied = true;
}

fn verificationStorePut(
    ctx: *anyopaque,
    target_event: *const noztr.nip01_event.Event,
    attestation_event: *const noztr.nip01_event.Event,
    verification: *const RemoteVerification,
) OpenTimestampsVerificationStoreError!VerificationStorePutOutcome {
    const self: *MemoryOpenTimestampsVerificationStore = @ptrCast(@alignCast(ctx));
    return self.putRemoteVerification(target_event, attestation_event, verification);
}

fn verificationStoreGet(
    ctx: *anyopaque,
    attestation_event_id: *const [32]u8,
) OpenTimestampsVerificationStoreError!?StoredRecord {
    const self: *MemoryOpenTimestampsVerificationStore = @ptrCast(@alignCast(ctx));
    return self.getVerification(attestation_event_id);
}

fn verificationStoreFind(
    ctx: *anyopaque,
    target_event_id: *const [32]u8,
    out: []StoredMatch,
) OpenTimestampsVerificationStoreError!usize {
    const self: *MemoryOpenTimestampsVerificationStore = @ptrCast(@alignCast(ctx));
    const matches = try self.findVerifications(target_event_id, out);
    return matches.len;
}

const verification_store_vtable = OpenTimestampsVerificationStoreVTable{
    .put_remote_verification = verificationStorePut,
    .get_verification = verificationStoreGet,
    .find_verifications = verificationStoreFind,
};

fn narrowLocalProofError(
    err: noztr.nip03_opentimestamps.OpenTimestampsError,
) OpenTimestampsLocalProofError {
    return switch (err) {
        error.InvalidProofHeader => error.InvalidProofHeader,
        error.UnsupportedProofVersion => error.UnsupportedProofVersion,
        error.InvalidProofOperation => error.InvalidProofOperation,
        error.InvalidProofStructure => error.InvalidProofStructure,
        error.MissingBitcoinAttestation => error.MissingBitcoinAttestation,
        else => unreachable,
    };
}

fn narrowVerifierError(
    err: noztr.nip03_opentimestamps.OpenTimestampsError,
) OpenTimestampsVerifierError {
    return switch (err) {
        error.InvalidEventKind => error.InvalidEventKind,
        error.InvalidEventTag => error.InvalidEventTag,
        error.DuplicateEventTag => error.DuplicateEventTag,
        error.MissingEventTag => error.MissingEventTag,
        error.InvalidKindTag => error.InvalidKindTag,
        error.DuplicateKindTag => error.DuplicateKindTag,
        error.MissingKindTag => error.MissingKindTag,
        error.InvalidEventId => error.InvalidEventId,
        error.InvalidRelayUrl => error.InvalidRelayUrl,
        error.InvalidTargetKind => error.InvalidTargetKind,
        error.EmptyProof => error.EmptyProof,
        error.InvalidBase64 => error.InvalidBase64,
        error.BufferTooSmall => error.BufferTooSmall,
        error.InvalidProofHeader,
        error.UnsupportedProofVersion,
        error.InvalidProofOperation,
        error.InvalidProofStructure,
        error.MissingBitcoinAttestation,
        error.TargetMismatch,
        => unreachable,
    };
}

test "opentimestamps verifier accepts a valid local bitcoin-attested proof" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;

    const outcome = try OpenTimestampsVerifier.verifyLocal(
        &target_event,
        &attestation_fixture.event,
        decoded_proof[0..],
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqual(@as(u32, 1), outcome.verified.attestation.target_kind);
    try std.testing.expectEqualStrings("wss://relay.example", outcome.verified.attestation.relay_url.?);
    try std.testing.expectEqualSlices(u8, &target_event.id, &outcome.verified.attestation.target_event_id);
    try std.testing.expectEqualSlices(
        u8,
        proof[0..testLocalProofLen(1)],
        outcome.verified.proof,
    );
}

test "opentimestamps verifier classifies target mismatches" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const wrong_target = try testTargetEvent(2, "goodbye");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;

    const outcome = try OpenTimestampsVerifier.verifyLocal(
        &wrong_target,
        &attestation_fixture.event,
        decoded_proof[0..],
    );

    try std.testing.expect(outcome == .target_mismatch);
    try std.testing.expectEqual(@as(u32, 1), outcome.target_mismatch.attestation.target_kind);
}

test "opentimestamps verifier classifies invalid local proof without bitcoin attestation" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(
        target_event.id,
        .{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 },
        &.{},
    );
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(0),
    );
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;

    const outcome = try OpenTimestampsVerifier.verifyLocal(
        &target_event,
        &attestation_fixture.event,
        decoded_proof[0..],
    );

    try std.testing.expect(outcome == .invalid_local_proof);
    try std.testing.expectEqual(
        error.MissingBitcoinAttestation,
        outcome.invalid_local_proof.cause,
    );
}

test "opentimestamps verifier distinguishes malformed attestation proofs from caller target mismatch" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const wrong_digest = try parseEventId(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const proof = testLocalProof(wrong_digest, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;

    const outcome = try OpenTimestampsVerifier.verifyLocal(
        &target_event,
        &attestation_fixture.event,
        decoded_proof[0..],
    );

    try std.testing.expect(outcome == .invalid_attestation);
    try std.testing.expectEqual(@as(u32, 1), outcome.invalid_attestation.verification.attestation.target_kind);
}

test "opentimestamps verifier propagates malformed attestation errors from noztr" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "k", "1" } },
    };
    const malformed = noztr.nip01_event.Event{
        .id = [_]u8{0x03} ** 32,
        .pubkey = [_]u8{0x04} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1040,
        .created_at = 1,
        .content = "AQ==",
        .tags = tags[0..],
    };
    const target_event = try testTargetEvent(1, "hello");
    var decoded_proof: [32]u8 = undefined;

    try std.testing.expectError(
        error.MissingEventTag,
        OpenTimestampsVerifier.verifyLocal(&target_event, &malformed, decoded_proof[0..]),
    );
}

test "opentimestamps verifier keeps extraction parity with current noztr helpers" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;

    const outcome = try OpenTimestampsVerifier.verifyLocal(
        &target_event,
        &attestation_fixture.event,
        decoded_proof[0..],
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqual(@as(u32, 1040), attestation_fixture.event.kind);
    try std.testing.expectEqual(
        @as(u32, @intCast(testLocalProofLen(1))),
        outcome.verified.attestation.proof_len,
    );
    try std.testing.expectEqualStrings(attestation_fixture.event.content, outcome.verified.attestation.proof_base64);
}

test "opentimestamps verifier fetches and verifies one detached proof document" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var fake_http = TestHttp.init("https://proof.example/hello.ots", proof[0..testLocalProofLen(1)]);

    const outcome = try OpenTimestampsVerifier.verifyRemote(
        fake_http.client(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", outcome.verified.proof_url);
    try std.testing.expectEqualSlices(u8, proof[0..testLocalProofLen(1)], outcome.verified.verification.proof);
}

test "opentimestamps verifier classifies detached proof fetch failures" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var fake_http = TestHttp.initFailure(
        "https://proof.example/hello.ots",
        error.TransportUnavailable,
    );

    const outcome = try OpenTimestampsVerifier.verifyRemote(
        fake_http.client(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );

    try std.testing.expect(outcome == .fetch_failed);
    try std.testing.expectEqual(error.TransportUnavailable, outcome.fetch_failed.cause);
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", outcome.fetch_failed.proof_url);
}

test "opentimestamps verifier classifies malformed detached proof documents" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    const malformed_remote_proof = testLocalProof(
        target_event.id,
        .{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 },
        &.{},
    );
    var fake_http = TestHttp.init(
        "https://proof.example/hello.ots",
        malformed_remote_proof[0..testLocalProofLen(0)],
    );

    const outcome = try OpenTimestampsVerifier.verifyRemote(
        fake_http.client(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );

    try std.testing.expect(outcome == .invalid_local_proof);
    try std.testing.expectEqual(
        error.MissingBitcoinAttestation,
        outcome.invalid_local_proof.invalid.cause,
    );
}

test "opentimestamps verifier reuses a stored detached proof without a second network fetch" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var store_records: [2]OpenTimestampsProofRecord = [_]OpenTimestampsProofRecord{ .{}, .{} };
    var proof_store = MemoryOpenTimestampsProofStore.init(store_records[0..]);
    var fake_http = TestHttp.init("https://proof.example/hello.ots", proof[0..testLocalProofLen(1)]);

    const first = try OpenTimestampsVerifier.verifyRemoteCached(
        fake_http.client(),
        proof_store.asStore(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );
    try std.testing.expect(first == .verified);
    try std.testing.expectEqual(@as(usize, 1), fake_http.request_count);

    fake_http.failure = error.TransportUnavailable;
    const second = try OpenTimestampsVerifier.verifyRemoteCached(
        fake_http.client(),
        proof_store.asStore(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );
    try std.testing.expect(second == .verified);
    try std.testing.expectEqual(@as(usize, 1), fake_http.request_count);
}

test "opentimestamps verifier replays malformed stored detached proofs as typed invalid-proof outcomes" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const valid_attestation_proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        valid_attestation_proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    const malformed_proof = testLocalProof(
        target_event.id,
        .{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 },
        &.{},
    );
    var store_records: [1]OpenTimestampsProofRecord = [_]OpenTimestampsProofRecord{.{}} ** 1;
    var proof_store = MemoryOpenTimestampsProofStore.init(store_records[0..]);
    try proof_store.putProof(
        "https://proof.example/hello.ots",
        malformed_proof[0..testLocalProofLen(0)],
    );
    var fake_http = TestHttp.initFailure(
        "https://proof.example/hello.ots",
        error.TransportUnavailable,
    );

    const outcome = try OpenTimestampsVerifier.verifyRemoteCached(
        fake_http.client(),
        proof_store.asStore(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );

    try std.testing.expect(outcome == .invalid_local_proof);
    try std.testing.expectEqual(
        error.MissingBitcoinAttestation,
        outcome.invalid_local_proof.invalid.cause,
    );
    try std.testing.expectEqual(@as(usize, 0), fake_http.request_count);
}

test "opentimestamps verifier surfaces bounded proof-store errors in cached remote mode" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var empty_records: [0]OpenTimestampsProofRecord = .{};
    var proof_store = MemoryOpenTimestampsProofStore.init(empty_records[0..]);
    var fake_http = TestHttp.init("https://proof.example/hello.ots", proof[0..testLocalProofLen(1)]);

    try std.testing.expectError(
        error.StoreFull,
        OpenTimestampsVerifier.verifyRemoteCached(
            fake_http.client(),
            proof_store.asStore(),
            &.{
                .target_event = &target_event,
                .attestation_event = &attestation_fixture.event,
                .proof_url = "https://proof.example/hello.ots",
                .proof_buffer = remote_proof_storage[0..],
            },
        ),
    );
}

test "opentimestamps verifier remembers one verified detached proof result and hydrates stored discovery" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{0x41} ** 32;
    attestation_fixture.event.created_at = 3;
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var proof_store_records: [2]OpenTimestampsProofRecord =
        [_]OpenTimestampsProofRecord{ .{}, .{} };
    var proof_store = MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var fake_http = TestHttp.init("https://proof.example/hello.ots", proof[0..testLocalProofLen(1)]);

    const remembered = try OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
        fake_http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &.{
            .target_event = &target_event,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );

    try std.testing.expect(remembered == .verified);
    try std.testing.expectEqual(VerificationStorePutOutcome.stored, remembered.verified.store_outcome);
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        remembered.verified.verification.proof_url,
    );

    var discovery_matches: [2]StoredMatch = undefined;
    var discovery_entries: [2]StoredDiscoveryEntry = undefined;
    const entries = try OpenTimestampsVerifier.discoverStoredVerificationEntries(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .storage = .init(discovery_matches[0..], discovery_entries[0..]),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqualSlices(
        u8,
        &attestation_fixture.event.id,
        &entries[0].match.attestation_event_id,
    );
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", entries[0].verification.proofUrl());
    try std.testing.expectEqualStrings("wss://relay.example", entries[0].verification.relayUrl().?);

    var latest_matches: [2]StoredMatch = undefined;
    const latest = (try OpenTimestampsVerifier.getLatestStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .matches = latest_matches[0..],
        },
    )).?;
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", latest.proofUrl());

    var latest_freshness_matches: [2]StoredMatch = undefined;
    const latest_freshness = (try OpenTimestampsVerifier.getLatestStoredVerificationFreshness(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .matches = latest_freshness_matches[0..],
        },
    )).?;
    try std.testing.expectEqual(StoredFreshness.stale, latest_freshness.freshness);
    try std.testing.expectEqual(@as(u64, 9), latest_freshness.age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", latest_freshness.latest.verification.proofUrl());
}

test "opentimestamps verifier does not remember non-verified detached proof outcomes" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const wrong_target = try testTargetEvent(2, "goodbye");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{0x42} ** 32;
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var proof_store_records: [1]OpenTimestampsProofRecord = [_]OpenTimestampsProofRecord{.{}};
    var proof_store = MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var fake_http = TestHttp.init("https://proof.example/hello.ots", proof[0..testLocalProofLen(1)]);

    const remembered = try OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
        fake_http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &.{
            .target_event = &wrong_target,
            .attestation_event = &attestation_fixture.event,
            .proof_url = "https://proof.example/hello.ots",
            .proof_buffer = remote_proof_storage[0..],
        },
    );

    try std.testing.expect(remembered == .target_mismatch);
    try std.testing.expectEqual(@as(usize, 0), verification_store.count);
}

test "opentimestamps verifier surfaces bounded remembered-verification store errors" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{0x43} ** 32;
    attestation_fixture.fixup();
    var remote_proof_storage: [128]u8 = undefined;
    var proof_store_records: [1]OpenTimestampsProofRecord = [_]OpenTimestampsProofRecord{.{}};
    var proof_store = MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var empty_verification_store_records: [0]StoredRecord = .{};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(empty_verification_store_records[0..]);
    var fake_http = TestHttp.init("https://proof.example/hello.ots", proof[0..testLocalProofLen(1)]);

    try std.testing.expectError(
        error.StoreFull,
        OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
            fake_http.client(),
            proof_store.asStore(),
            verification_store.asStore(),
            &.{
                .target_event = &target_event,
                .attestation_event = &attestation_fixture.event,
                .proof_url = "https://proof.example/hello.ots",
                .proof_buffer = remote_proof_storage[0..],
            },
        ),
    );
}

test "opentimestamps verifier surfaces stored verification discovery buffer pressure" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var first_attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0x44} ** 32;
    first_attestation_fixture.event.created_at = 2;
    first_attestation_fixture.fixup();
    var second_proof_base64_storage: [128]u8 = undefined;
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0x45} ** 32;
    second_attestation_fixture.event.created_at = 5;
    second_attestation_fixture.fixup();

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var first_decoded_proof: [128]u8 = undefined;
    var second_decoded_proof: [128]u8 = undefined;
    const verification: RemoteVerification = .{
        .proof_url = "https://proof.example/hello.ots",
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                first_decoded_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
    };
    const second_verification: RemoteVerification = .{
        .proof_url = "https://proof.example/hello-2.ots",
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                second_decoded_proof[0..],
                &second_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
    };
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &first_attestation_fixture.event,
        &verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &second_attestation_fixture.event,
        &second_verification,
    );

    var discovery_matches: [2]StoredMatch = undefined;
    var discovery_entries: [1]StoredDiscoveryEntry = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        OpenTimestampsVerifier.discoverStoredVerificationEntries(
            verification_store.asStore(),
            .{
                .target_event_id = &target_event.id,
                .storage = .init(discovery_matches[0..], discovery_entries[0..]),
            },
        ),
    );
}

test "opentimestamps verifier classifies remembered discovery entries by freshness" {
    var proof_base64_storage: [128]u8 = undefined;
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var first_attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0x46} ** 32;
    first_attestation_fixture.event.created_at = 2;
    first_attestation_fixture.fixup();

    var second_proof_base64_storage: [128]u8 = undefined;
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0x47} ** 32;
    second_attestation_fixture.event.created_at = 9;
    second_attestation_fixture.fixup();

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var decoded_proof_a: [128]u8 = undefined;
    var decoded_proof_b: [128]u8 = undefined;
    const first_verification: RemoteVerification = .{
        .proof_url = "https://proof.example/old.ots",
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_a[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
    };
    const second_verification: RemoteVerification = .{
        .proof_url = "https://proof.example/new.ots",
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_b[0..],
                &second_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
    };
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &first_attestation_fixture.event,
        &first_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &second_attestation_fixture.event,
        &second_verification,
    );

    var discovery_matches: [2]StoredMatch = undefined;
    var freshness_entries: [2]StoredFreshEntry = undefined;
    const entries = try OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .storage = .init(discovery_matches[0..], freshness_entries[0..]),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualSlices(
        u8,
        &first_attestation_fixture.event.id,
        &entries[0].entry.match.attestation_event_id,
    );
    try std.testing.expectEqual(StoredFreshness.stale, entries[0].freshness);
    try std.testing.expectEqual(@as(u64, 10), entries[0].age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/old.ots", entries[0].entry.verification.proofUrl());
    try std.testing.expectEqualSlices(
        u8,
        &second_attestation_fixture.event.id,
        &entries[1].entry.match.attestation_event_id,
    );
    try std.testing.expectEqual(StoredFreshness.fresh, entries[1].freshness);
    try std.testing.expectEqual(@as(u64, 3), entries[1].age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/new.ots", entries[1].entry.verification.proofUrl());
}

test "opentimestamps verifier returns empty remembered freshness discovery for missing verifications" {
    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    const target_event = try testTargetEvent(1, "hello");
    var discovery_matches: [1]StoredMatch = undefined;
    var freshness_entries: [1]StoredFreshEntry = undefined;

    const entries = try OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .storage = .init(discovery_matches[0..], freshness_entries[0..]),
        },
    );
    try std.testing.expectEqual(@as(usize, 0), entries.len);
}

test "opentimestamps verifier runtime policy requests verification when no remembered verification exists" {
    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    const target_event = try testTargetEvent(1, "hello");
    var runtime_matches: [1]StoredMatch = undefined;
    var runtime_entries: [1]StoredFreshEntry = undefined;

    const runtime = try OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .storage = .init(runtime_matches[0..], runtime_entries[0..]),
        },
    );
    try std.testing.expectEqual(StoredRuntimeAction.verify_now, runtime.action);
    try std.testing.expectEqual(@as(usize, 0), runtime.entries.len);
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    try std.testing.expect(runtime.preferredEntry() == null);
    try std.testing.expect(runtime.nextEntry() == null);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(StoredRuntimeAction.verify_now, next_step.action);
    try std.testing.expect(next_step.entry == null);
}

test "opentimestamps verifier runtime policy prefers a fresh remembered verification" {
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var first_proof_base64_storage: [128]u8 = undefined;
    var second_proof_base64_storage: [128]u8 = undefined;
    var first_attestation_fixture = try testAttestationEvent(
        first_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0x61} ** 32;
    first_attestation_fixture.event.created_at = 2;
    first_attestation_fixture.fixup();
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0x62} ** 32;
    second_attestation_fixture.event.created_at = 9;
    second_attestation_fixture.fixup();
    var decoded_proof_a: [128]u8 = undefined;
    var decoded_proof_b: [128]u8 = undefined;
    const stale_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_a[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const fresh_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_b[0..],
                &second_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &first_attestation_fixture.event,
        &stale_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &second_attestation_fixture.event,
        &fresh_verification,
    );

    var runtime_matches: [2]StoredMatch = undefined;
    var runtime_entries: [2]StoredFreshEntry = undefined;
    const runtime = try OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .storage = .init(runtime_matches[0..], runtime_entries[0..]),
        },
    );
    try std.testing.expectEqual(
        StoredRuntimeAction.use_preferred,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(StoredFreshness.fresh, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqual(
        StoredRuntimeAction.use_preferred,
        next_step.action,
    );
    try std.testing.expectEqual(
        StoredFreshness.fresh,
        next_step.entry.?.freshness,
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        preferred.entry.verification.proofUrl(),
    );

    var preferred_matches: [2]StoredMatch = undefined;
    var preferred_entries: [2]StoredFreshEntry = undefined;
    const selected = (try OpenTimestampsVerifier.getPreferredStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .storage = .init(preferred_matches[0..], preferred_entries[0..]),
            .fallback_policy = .require_fresh,
        },
    )).?;
    try std.testing.expectEqual(StoredFreshness.fresh, selected.freshness);
    try std.testing.expectEqual(@as(u64, 3), selected.age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/new.ots", selected.entry.verification.proofUrl());
}

test "opentimestamps verifier runtime policy can use stale verification and refresh" {
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var older_proof_base64_storage: [128]u8 = undefined;
    var newer_proof_base64_storage: [128]u8 = undefined;
    var older_attestation_fixture = try testAttestationEvent(
        older_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    older_attestation_fixture.event.id = [_]u8{0x63} ** 32;
    older_attestation_fixture.event.created_at = 2;
    older_attestation_fixture.fixup();
    var newer_attestation_fixture = try testAttestationEvent(
        newer_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    newer_attestation_fixture.event.id = [_]u8{0x64} ** 32;
    newer_attestation_fixture.event.created_at = 9;
    newer_attestation_fixture.fixup();
    var older_decoded_proof: [128]u8 = undefined;
    var newer_decoded_proof: [128]u8 = undefined;
    const older_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                older_decoded_proof[0..],
                &older_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const newer_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                newer_decoded_proof[0..],
                &newer_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &older_attestation_fixture.event,
        &older_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &newer_attestation_fixture.event,
        &newer_verification,
    );

    var runtime_matches: [2]StoredMatch = undefined;
    var runtime_entries: [2]StoredFreshEntry = undefined;
    const runtime = try OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 20,
            .max_age_seconds = 5,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(runtime_matches[0..], runtime_entries[0..]),
        },
    );
    try std.testing.expectEqual(
        StoredRuntimeAction.use_stale_and_refresh,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(StoredFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqual(
        StoredRuntimeAction.use_stale_and_refresh,
        next_step.action,
    );
    try std.testing.expectEqual(
        StoredFreshness.stale,
        next_step.entry.?.freshness,
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        preferred.entry.verification.proofUrl(),
    );

    var preferred_matches: [2]StoredMatch = undefined;
    var preferred_entries: [2]StoredFreshEntry = undefined;
    const selected = (try OpenTimestampsVerifier.getPreferredStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 20,
            .max_age_seconds = 5,
            .storage = .init(preferred_matches[0..], preferred_entries[0..]),
            .fallback_policy = .allow_stale_latest,
        },
    )).?;
    try std.testing.expectEqual(StoredFreshness.stale, selected.freshness);
    try std.testing.expectEqual(@as(u64, 11), selected.age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/new.ots", selected.entry.verification.proofUrl());
}

test "opentimestamps verifier runtime policy can require refresh for stale remembered verification" {
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var proof_base64_storage: [128]u8 = undefined;
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{0x65} ** 32;
    attestation_fixture.event.created_at = 2;
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;
    const remembered_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof[0..],
                &attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &attestation_fixture.event,
        &remembered_verification,
    );

    var runtime_matches: [1]StoredMatch = undefined;
    var runtime_entries: [1]StoredFreshEntry = undefined;
    const runtime = try OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 20,
            .max_age_seconds = 5,
            .fallback_policy = .require_fresh,
            .storage = .init(runtime_matches[0..], runtime_entries[0..]),
        },
    );
    try std.testing.expectEqual(
        StoredRuntimeAction.refresh_existing,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(StoredFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqual(
        StoredRuntimeAction.refresh_existing,
        next_step.action,
    );
    try std.testing.expectEqual(
        StoredFreshness.stale,
        next_step.entry.?.freshness,
    );
}

test "opentimestamps verifier preferred selection uses caller-owned freshness storage" {
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var first_proof_base64_storage: [128]u8 = undefined;
    var second_proof_base64_storage: [128]u8 = undefined;
    var first_attestation_fixture = try testAttestationEvent(
        first_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0x81} ** 32;
    first_attestation_fixture.event.created_at = 2;
    first_attestation_fixture.fixup();
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0x82} ** 32;
    second_attestation_fixture.event.created_at = 9;
    second_attestation_fixture.fixup();

    var first_decoded_proof: [128]u8 = undefined;
    var second_decoded_proof: [128]u8 = undefined;
    const first_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                first_decoded_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const second_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                second_decoded_proof[0..],
                &second_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &first_attestation_fixture.event,
        &first_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &second_attestation_fixture.event,
        &second_verification,
    );

    var preferred_matches: [2]StoredMatch = undefined;
    var too_small_entries: [1]StoredFreshEntry = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        OpenTimestampsVerifier.getPreferredStoredVerification(
            verification_store.asStore(),
            .{
                .target_event_id = &target_event.id,
                .now_unix_seconds = 12,
                .max_age_seconds = 5,
                .storage = .init(preferred_matches[0..], too_small_entries[0..]),
                .fallback_policy = .require_fresh,
            },
        ),
    );
}

test "opentimestamps verifier returns typed error for inconsistent remembered verification store" {
    const InconsistentVerificationStore = struct {
        fn asStore(self: *@This()) OpenTimestampsVerificationStore {
            return .{ .ctx = self, .vtable = &vtable };
        }

        fn put(
            _: *anyopaque,
            _: *const noztr.nip01_event.Event,
            _: *const noztr.nip01_event.Event,
            _: *const RemoteVerification,
        ) OpenTimestampsVerificationStoreError!VerificationStorePutOutcome {
            return .stored;
        }

        fn get(
            _: *anyopaque,
            _: *const [32]u8,
        ) OpenTimestampsVerificationStoreError!?StoredRecord {
            return null;
        }

        fn find(
            _: *anyopaque,
            _: *const [32]u8,
            out: []StoredMatch,
        ) OpenTimestampsVerificationStoreError!usize {
            out[0] = .{
                .attestation_event_id = [_]u8{0x91} ** 32,
                .created_at = 7,
            };
            return 1;
        }

        const vtable = OpenTimestampsVerificationStoreVTable{
            .put_remote_verification = put,
            .get_verification = get,
            .find_verifications = find,
        };
    };

    var store = InconsistentVerificationStore{};
    const target_event = try testTargetEvent(1, "hello");
    var matches: [1]StoredMatch = undefined;
    var entries: [1]StoredFreshEntry = undefined;
    try std.testing.expectError(
        error.InconsistentStoreData,
        OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(
            store.asStore(),
            .{
                .target_event_id = &target_event.id,
                .now_unix_seconds = 9,
                .max_age_seconds = 5,
                .storage = .init(matches[0..], entries[0..]),
            },
        ),
    );
}

test "opentimestamps verifier refresh plan returns stale remembered verifications newest first" {
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var older_proof_base64_storage: [128]u8 = undefined;
    var newer_proof_base64_storage: [128]u8 = undefined;
    var older_attestation_fixture = try testAttestationEvent(
        older_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    older_attestation_fixture.event.id = [_]u8{0x73} ** 32;
    older_attestation_fixture.event.created_at = 2;
    older_attestation_fixture.fixup();
    var newer_attestation_fixture = try testAttestationEvent(
        newer_proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    newer_attestation_fixture.event.id = [_]u8{0x74} ** 32;
    newer_attestation_fixture.event.created_at = 9;
    newer_attestation_fixture.fixup();
    var older_decoded_proof: [128]u8 = undefined;
    var newer_decoded_proof: [128]u8 = undefined;
    const older_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                older_decoded_proof[0..],
                &older_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const newer_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                newer_decoded_proof[0..],
                &newer_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &older_attestation_fixture.event,
        &older_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &newer_attestation_fixture.event,
        &newer_verification,
    );

    var matches_storage: [2]StoredMatch = undefined;
    var freshness_storage: [2]StoredFreshEntry = undefined;
    var refresh_entries: [2]StoredRefreshEntry = undefined;
    const plan = try OpenTimestampsVerifier.planStoredVerificationRefresh(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 20,
            .max_age_seconds = 5,
            .storage = .init(
                matches_storage[0..],
                freshness_storage[0..],
                refresh_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), plan.entries.len);
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        plan.entries[0].entry.entry.verification.proofUrl(),
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/old.ots",
        plan.entries[1].entry.entry.verification.proofUrl(),
    );
    try std.testing.expectEqual(@as(u64, 11), plan.entries[0].entry.age_seconds);
    try std.testing.expectEqual(@as(u64, 18), plan.entries[1].entry.age_seconds);
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        plan.nextEntry().?.entry.entry.verification.proofUrl(),
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        plan.newestEntry().?.entry.entry.verification.proofUrl(),
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        plan.nextStep().?.entry.entry.entry.verification.proofUrl(),
    );
}

test "opentimestamps verifier refresh plan returns empty when remembered verifications are fresh" {
    const target_event = try testTargetEvent(1, "hello");
    const proof = testLocalProof(target_event.id, bitcoin_attestation_tag, &.{0x2a});
    var proof_base64_storage: [128]u8 = undefined;
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target_event,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{0x75} ** 32;
    attestation_fixture.event.created_at = 40;
    attestation_fixture.fixup();
    var decoded_proof: [128]u8 = undefined;
    const remembered_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof[0..],
                &attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/fresh.ots",
    };

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &attestation_fixture.event,
        &remembered_verification,
    );

    var matches_storage: [1]StoredMatch = undefined;
    var freshness_storage: [1]StoredFreshEntry = undefined;
    var refresh_entries: [1]StoredRefreshEntry = undefined;
    const plan = try OpenTimestampsVerifier.planStoredVerificationRefresh(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                freshness_storage[0..],
                refresh_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 0), plan.entries.len);
    try std.testing.expect(plan.nextEntry() == null);
    try std.testing.expect(plan.newestEntry() == null);
    try std.testing.expect(plan.nextStep() == null);
}

test "opentimestamps verifier discovers latest remembered freshness for grouped proof targets in caller order" {
    var first_target = try testTargetEvent(1, "hello");
    var second_target = try testTargetEvent(1, "world");
    first_target.id = [_]u8{0x81} ** 32;
    second_target.id = [_]u8{0x82} ** 32;

    const first_proof = testLocalProof(first_target.id, bitcoin_attestation_tag, &.{0x2a});
    const second_proof = testLocalProof(second_target.id, bitcoin_attestation_tag, &.{0x2b});

    var first_proof_base64_storage: [128]u8 = undefined;
    var first_attestation_fixture = try testAttestationEvent(
        first_proof_base64_storage[0..],
        &first_target,
        first_proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0x83} ** 32;
    first_attestation_fixture.event.created_at = 5;
    first_attestation_fixture.fixup();

    var second_proof_base64_storage: [128]u8 = undefined;
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &second_target,
        second_proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0x84} ** 32;
    second_attestation_fixture.event.created_at = 40;
    second_attestation_fixture.fixup();

    var decoded_first_proof: [128]u8 = undefined;
    var decoded_second_proof: [128]u8 = undefined;
    const first_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_first_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = first_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const second_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_second_proof[0..],
                &second_attestation_fixture.event,
            ),
            .proof = second_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/fresh.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &first_target,
        &first_attestation_fixture.event,
        &first_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &second_target,
        &second_attestation_fixture.event,
        &second_verification,
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = first_target.id },
        .{ .target_event_id = second_target.id },
        .{ .target_event_id = [_]u8{0x85} ** 32 },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var entries_storage: [3]TargetLatestEntry = undefined;
    const entries = try OpenTimestampsVerifier.discoverLatestStoredVerificationFreshnessForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqualSlices(u8, &first_target.id, &entries[0].target.target_event_id);
    try std.testing.expectEqual(StoredFreshness.stale, entries[0].latest.?.freshness);
    try std.testing.expectEqual(@as(u64, 45), entries[0].latest.?.age_seconds);
    try std.testing.expectEqualSlices(u8, &second_target.id, &entries[1].target.target_event_id);
    try std.testing.expectEqual(StoredFreshness.fresh, entries[1].latest.?.freshness);
    try std.testing.expectEqual(@as(u64, 10), entries[1].latest.?.age_seconds);
    try std.testing.expect(entries[2].latest == null);
}

test "opentimestamps verifier prefers the freshest grouped remembered proof target" {
    var first_target = try testTargetEvent(1, "hello");
    var second_target = try testTargetEvent(1, "world");
    first_target.id = [_]u8{0x91} ** 32;
    second_target.id = [_]u8{0x92} ** 32;

    const first_proof = testLocalProof(first_target.id, bitcoin_attestation_tag, &.{0x2c});
    const second_proof = testLocalProof(second_target.id, bitcoin_attestation_tag, &.{0x2d});

    var first_proof_base64_storage: [128]u8 = undefined;
    var first_attestation_fixture = try testAttestationEvent(
        first_proof_base64_storage[0..],
        &first_target,
        first_proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0x93} ** 32;
    first_attestation_fixture.event.created_at = 5;
    first_attestation_fixture.fixup();

    var second_proof_base64_storage: [128]u8 = undefined;
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &second_target,
        second_proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0x94} ** 32;
    second_attestation_fixture.event.created_at = 40;
    second_attestation_fixture.fixup();

    var decoded_first_proof: [128]u8 = undefined;
    var decoded_second_proof: [128]u8 = undefined;
    const first_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_first_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = first_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/stale.ots",
    };
    const second_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_second_proof[0..],
                &second_attestation_fixture.event,
            ),
            .proof = second_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/fresh.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &first_target,
        &first_attestation_fixture.event,
        &first_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &second_target,
        &second_attestation_fixture.event,
        &second_verification,
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = first_target.id },
        .{ .target_event_id = second_target.id },
        .{ .target_event_id = [_]u8{0x95} ** 32 },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [1]StoredFreshEntry = undefined;
    var entries_storage: [3]TargetPreferredEntry = undefined;
    const preferred = (try OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                entries_storage[0..],
            ),
        },
    )).?;

    try std.testing.expectEqualSlices(u8, &second_target.id, &preferred.target.target_event_id);
    try std.testing.expectEqual(StoredFreshness.fresh, preferred.preferred.?.freshness);
    try std.testing.expectEqualStrings(
        "https://proof.example/fresh.ots",
        preferred.preferred.?.entry.verification.proofUrl(),
    );
}

test "opentimestamps verifier grouped preferred helper can require fresh or fall back to stale latest" {
    var first_target = try testTargetEvent(1, "hello");
    var second_target = try testTargetEvent(1, "world");
    first_target.id = [_]u8{0xa1} ** 32;
    second_target.id = [_]u8{0xa2} ** 32;

    const first_proof = testLocalProof(first_target.id, bitcoin_attestation_tag, &.{0x2e});
    const second_proof = testLocalProof(second_target.id, bitcoin_attestation_tag, &.{0x2f});

    var first_proof_base64_storage: [128]u8 = undefined;
    var first_attestation_fixture = try testAttestationEvent(
        first_proof_base64_storage[0..],
        &first_target,
        first_proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0xa3} ** 32;
    first_attestation_fixture.event.created_at = 10;
    first_attestation_fixture.fixup();

    var second_proof_base64_storage: [128]u8 = undefined;
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &second_target,
        second_proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0xa4} ** 32;
    second_attestation_fixture.event.created_at = 20;
    second_attestation_fixture.fixup();

    var decoded_first_proof: [128]u8 = undefined;
    var decoded_second_proof: [128]u8 = undefined;
    const first_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_first_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = first_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/older.ots",
    };
    const second_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_second_proof[0..],
                &second_attestation_fixture.event,
            ),
            .proof = second_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/newer.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &first_target,
        &first_attestation_fixture.event,
        &first_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &second_target,
        &second_attestation_fixture.event,
        &second_verification,
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = first_target.id },
        .{ .target_event_id = second_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [1]StoredFreshEntry = undefined;
    var entries_storage: [2]TargetPreferredEntry = undefined;

    try std.testing.expect((try OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 5,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                entries_storage[0..],
            ),
        },
    )) == null);

    const preferred = (try OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 5,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                entries_storage[0..],
            ),
        },
    )).?;
    try std.testing.expectEqualSlices(u8, &second_target.id, &preferred.target.target_event_id);
    try std.testing.expectEqual(StoredFreshness.stale, preferred.preferred.?.freshness);
    try std.testing.expectEqualStrings(
        "https://proof.example/newer.ots",
        preferred.preferred.?.entry.verification.proofUrl(),
    );
}

test "opentimestamps verifier groups remembered-proof target policy entries by action in stable caller order" {
    var fresh_target = try testTargetEvent(1, "fresh");
    var stale_target = try testTargetEvent(1, "stale");
    fresh_target.id = [_]u8{0xc1} ** 32;
    stale_target.id = [_]u8{0xc2} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &fresh_target,
        0xc3,
        45,
        0x61,
        "https://proof.example/fresh.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xc4,
        5,
        0x62,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xc0} ** 32 },
        .{ .target_event_id = fresh_target.id },
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var entries_storage: [3]TargetPolicyEntry = undefined;
    var groups_storage: [4]TargetPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), plan.entries.len);
    try std.testing.expectEqual(@as(usize, 4), plan.groups.len);
    try std.testing.expectEqual(@as(u32, 1), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_preferred_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_stale_and_refresh_count);
    try std.testing.expectEqual(@as(u32, 0), plan.refresh_existing_count);
    try std.testing.expectEqual(@as(u32, 1), plan.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stale_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_count);
    try std.testing.expectEqual(StoredRuntimeAction.verify_now, plan.groups[0].action);
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &plan.groups[0].entries[0].target.target_event_id);
    try std.testing.expectEqual(StoredRuntimeAction.use_preferred, plan.groups[1].action);
    try std.testing.expectEqualSlices(u8, &fresh_target.id, &plan.groups[1].entries[0].target.target_event_id);
    try std.testing.expectEqual(StoredRuntimeAction.use_stale_and_refresh, plan.groups[2].action);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.groups[2].entries[0].target.target_event_id);
    try std.testing.expectEqual(StoredRuntimeAction.refresh_existing, plan.groups[3].action);
    try std.testing.expectEqual(@as(usize, 0), plan.groups[3].entries.len);
}

test "opentimestamps verifier target policy inspection stays bounded by caller-owned grouped storage" {
    var verification_store_records: [0]StoredRecord = .{};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xc5} ** 32 },
    };
    var matches_storage: [0]StoredMatch = .{};
    var latest_entries_storage: [1]TargetLatestEntry = undefined;
    var entries_storage: [1]TargetPolicyEntry = undefined;
    var groups_storage: [3]TargetPolicyGroup = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
            verification_store.asStore(),
            .{
                .targets = targets[0..],
                .now_unix_seconds = 50,
                .max_age_seconds = 20,
                .storage = .init(
                    matches_storage[0..],
                    latest_entries_storage[0..],
                    entries_storage[0..],
                    groups_storage[0..],
                ),
            },
        ),
    );
}

test "opentimestamps verifier target policy exposes usable preferred targets in stable caller order" {
    var fresh_target = try testTargetEvent(1, "fresh");
    var stale_target = try testTargetEvent(1, "stale");
    fresh_target.id = [_]u8{0xc6} ** 32;
    stale_target.id = [_]u8{0xc7} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(&verification_store, &fresh_target, 0xc8, 45, 0x63, "https://proof.example/fresh.ots");
    try rememberTestRemoteVerification(&verification_store, &stale_target, 0xc9, 5, 0x64, "https://proof.example/stale.ots");

    const targets = [_]StoredTarget{
        .{ .target_event_id = fresh_target.id },
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [2]TargetLatestEntry = undefined;
    var entries_storage: [2]TargetPolicyEntry = undefined;
    var groups_storage: [4]TargetPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), plan.usablePreferredEntries().len);
    try std.testing.expectEqualSlices(u8, &fresh_target.id, &plan.usablePreferredEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.usablePreferredEntries()[1].target.target_event_id);
}

test "opentimestamps verifier target policy exposes verify-now targets in stable caller order" {
    var verification_store_records: [0]StoredRecord = .{};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xca} ** 32 },
        .{ .target_event_id = [_]u8{0xcb} ** 32 },
    };
    var matches_storage: [0]StoredMatch = .{};
    var latest_entries_storage: [2]TargetLatestEntry = undefined;
    var entries_storage: [2]TargetPolicyEntry = undefined;
    var groups_storage: [4]TargetPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), plan.verifyNowEntries().len);
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &plan.verifyNowEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &targets[1].target_event_id, &plan.verifyNowEntries()[1].target.target_event_id);
}

test "opentimestamps verifier target policy exposes refresh-needed targets under explicit fallback policy" {
    var fresh_target = try testTargetEvent(1, "fresh");
    var stale_target = try testTargetEvent(1, "stale");
    fresh_target.id = [_]u8{0xcc} ** 32;
    stale_target.id = [_]u8{0xcd} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(&verification_store, &fresh_target, 0xce, 45, 0x65, "https://proof.example/fresh.ots");
    try rememberTestRemoteVerification(&verification_store, &stale_target, 0xcf, 5, 0x66, "https://proof.example/stale.ots");

    const targets = [_]StoredTarget{
        .{ .target_event_id = fresh_target.id },
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [2]TargetLatestEntry = undefined;
    var entries_storage: [2]TargetPolicyEntry = undefined;
    var groups_storage: [4]TargetPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), plan.refreshNeededEntries().len);
    try std.testing.expectEqual(StoredRuntimeAction.refresh_existing, plan.refreshNeededEntries()[0].action);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.refreshNeededEntries()[0].target.target_event_id);
}

test "opentimestamps verifier grouped refresh cadence classifies missing stale soon and stable targets" {
    var stable_target = try testTargetEvent(1, "stable");
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    stable_target.id = [_]u8{0xd1} ** 32;
    soon_target.id = [_]u8{0xd2} ** 32;
    stale_target.id = [_]u8{0xd3} ** 32;

    var verification_store_records: [3]StoredRecord =
        [_]StoredRecord{ .{}, .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &stable_target,
        0xd4,
        45,
        0x40,
        "https://proof.example/stable.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &soon_target,
        0xd5,
        35,
        0x41,
        "https://proof.example/soon.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xd6,
        5,
        0x42,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xd0} ** 32 },
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
        .{ .target_event_id = stable_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [4]TargetLatestEntry = undefined;
    var cadence_entries_storage: [4]TargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 4), plan.entries.len);
    try std.testing.expectEqual(@as(usize, 5), plan.groups.len);
    try std.testing.expectEqual(@as(u32, 1), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), plan.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.usable_while_refreshing_count);
    try std.testing.expectEqual(@as(u32, 1), plan.refresh_soon_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stable_count);
    try std.testing.expectEqual(@as(u32, 2), plan.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stale_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_count);
    try std.testing.expectEqual(TargetRefreshCadenceAction.verify_now, plan.groups[0].action);
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &plan.groups[0].entries[0].target.target_event_id);
    try std.testing.expectEqual(
        TargetRefreshCadenceAction.usable_while_refreshing,
        plan.groups[2].action,
    );
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.groups[2].entries[0].target.target_event_id);
    try std.testing.expectEqual(
        TargetRefreshCadenceAction.refresh_soon,
        plan.groups[3].action,
    );
    try std.testing.expectEqualSlices(u8, &soon_target.id, &plan.groups[3].entries[0].target.target_event_id);
    try std.testing.expectEqual(TargetRefreshCadenceAction.stable, plan.groups[4].action);
    try std.testing.expectEqualSlices(u8, &stable_target.id, &plan.groups[4].entries[0].target.target_event_id);
}

test "opentimestamps verifier grouped refresh cadence stays bounded by caller-owned grouped storage" {
    var verification_store_records: [0]StoredRecord = .{};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xe1} ** 32 },
    };
    var matches_storage: [0]StoredMatch = .{};
    var latest_entries_storage: [1]TargetLatestEntry = undefined;
    var cadence_entries_storage: [1]TargetRefreshCadenceEntry = undefined;
    var groups_storage: [4]TargetRefreshCadenceGroup = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
            verification_store.asStore(),
            .{
                .targets = targets[0..],
                .now_unix_seconds = 50,
                .max_age_seconds = 20,
                .refresh_soon_age_seconds = 10,
                .storage = .init(
                    matches_storage[0..],
                    latest_entries_storage[0..],
                    cadence_entries_storage[0..],
                    groups_storage[0..],
                ),
            },
        ),
    );
}

test "opentimestamps verifier grouped refresh cadence next-due selector prefers missing then stale then soon" {
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    soon_target.id = [_]u8{0xe2} ** 32;
    stale_target.id = [_]u8{0xe3} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &soon_target,
        0xe4,
        35,
        0x43,
        "https://proof.example/soon.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xe5,
        5,
        0x44,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xe6} ** 32 },
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &plan.nextDueEntry().?.target.target_event_id);

    const due_targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
    };
    var due_latest_entries: [2]TargetLatestEntry = undefined;
    var due_cadence_entries: [2]TargetRefreshCadenceEntry = undefined;
    var due_groups: [5]TargetRefreshCadenceGroup = undefined;
    const due_plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = due_targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                due_latest_entries[0..],
                due_cadence_entries[0..],
                due_groups[0..],
            ),
        },
    );
    try std.testing.expectEqualSlices(u8, &stale_target.id, &due_plan.nextDueEntry().?.target.target_event_id);
}

test "opentimestamps verifier grouped refresh cadence exposes typed next-due step" {
    var stale_target = try testTargetEvent(1, "stale");
    stale_target.id = [_]u8{0xe7} ** 32;

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xe8,
        5,
        0x45,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [1]TargetLatestEntry = undefined;
    var cadence_entries_storage: [1]TargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );
    const step = plan.nextDueStep().?;
    try std.testing.expectEqual(TargetRefreshCadenceAction.refresh_now, step.action);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &step.entry.target.target_event_id);
}

test "opentimestamps verifier grouped refresh cadence exposes usable-while-refreshing and refresh-soon views" {
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    soon_target.id = [_]u8{0xe9} ** 32;
    stale_target.id = [_]u8{0xea} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &soon_target,
        0xeb,
        35,
        0x46,
        "https://proof.example/soon.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xec,
        5,
        0x47,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [2]TargetLatestEntry = undefined;
    var cadence_entries_storage: [2]TargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshCadenceForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), plan.usableWhileRefreshingEntries().len);
    try std.testing.expectEqualSlices(
        u8,
        &stale_target.id,
        &plan.usableWhileRefreshingEntries()[0].target.target_event_id,
    );
    try std.testing.expectEqual(
        TargetRefreshCadenceAction.usable_while_refreshing,
        plan.usableWhileRefreshingEntries()[0].action,
    );
    try std.testing.expectEqual(@as(usize, 1), plan.refreshSoonEntries().len);
    try std.testing.expectEqualSlices(
        u8,
        &soon_target.id,
        &plan.refreshSoonEntries()[0].target.target_event_id,
    );
    try std.testing.expectEqual(
        TargetRefreshCadenceAction.refresh_soon,
        plan.refreshSoonEntries()[0].action,
    );
}

test "opentimestamps verifier selects a bounded refresh batch from due remembered proofs" {
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    soon_target.id = [_]u8{0xed} ** 32;
    stale_target.id = [_]u8{0xee} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &soon_target,
        0xef,
        35,
        0x48,
        "https://proof.example/soon.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xf0,
        5,
        0x49,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xf1} ** 32 },
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const batch = try OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), batch.entries.len);
    try std.testing.expectEqual(@as(u32, 2), batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), batch.deferred_count);
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &batch.entries[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &batch.entries[1].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &soon_target.id, &batch.entries[2].target.target_event_id);
}

test "opentimestamps verifier refresh batch selection allows zero selected entries" {
    var stale_target = try testTargetEvent(1, "stale");
    stale_target.id = [_]u8{0xf2} ** 32;

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xf3,
        5,
        0x4a,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [1]TargetLatestEntry = undefined;
    var cadence_entries_storage: [1]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const batch = try OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 0,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), batch.entries.len);
    try std.testing.expectEqual(@as(u32, 0), batch.selected_count);
    try std.testing.expectEqual(@as(u32, 1), batch.deferred_count);
}

test "opentimestamps verifier refresh batch exposes next selected entry" {
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    soon_target.id = [_]u8{0xf4} ** 32;
    stale_target.id = [_]u8{0xf5} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &soon_target,
        0xf6,
        35,
        0x4b,
        "https://proof.example/soon.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xf7,
        5,
        0x4c,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xf8} ** 32 },
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const batch = try OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &batch.nextBatchEntry().?.target.target_event_id);
}

test "opentimestamps verifier refresh batch exposes typed next selected step" {
    var stale_target = try testTargetEvent(1, "stale");
    stale_target.id = [_]u8{0xf9} ** 32;

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xfa,
        5,
        0x4d,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [1]TargetLatestEntry = undefined;
    var cadence_entries_storage: [1]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const batch = try OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
            ),
        },
    );
    const step = batch.nextBatchStep().?;
    try std.testing.expectEqualSlices(u8, &stale_target.id, &step.entry.target.target_event_id);
}

test "opentimestamps verifier refresh batch exposes selected and deferred views" {
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    soon_target.id = [_]u8{0xfb} ** 32;
    stale_target.id = [_]u8{0xfc} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &soon_target,
        0xfd,
        35,
        0x4e,
        "https://proof.example/soon.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        0xfe,
        5,
        0x4f,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xff} ** 32 },
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    const batch = try OpenTimestampsVerifier.inspectStoredVerificationRefreshBatchForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), batch.selectedEntries().len);
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &batch.selectedEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &batch.selectedEntries()[1].target.target_event_id);
    try std.testing.expectEqual(@as(usize, 1), batch.deferredEntries().len);
    try std.testing.expectEqualSlices(u8, &soon_target.id, &batch.deferredEntries()[0].target.target_event_id);
}

test "opentimestamps verifier turn policy classifies verify refresh cached and deferred work" {
    var stable_target = try testTargetEvent(1, "stable");
    var stale_target = try testTargetEvent(1, "stale");
    stable_target.id = [_]u8{0xa1} ** 32;
    stale_target.id = [_]u8{0xa2} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &stable_target,
        45,
        45,
        0x51,
        "https://proof.example/stable.ots",
    );
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        5,
        5,
        0x52,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = [_]u8{0xa3} ** 32 },
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = stable_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]TargetTurnPolicyEntry = undefined;
    var groups_storage: [4]TargetTurnPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 31,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 10,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 0), plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), plan.defer_refresh_count);
    try std.testing.expectEqualSlices(u8, &targets[0].target_event_id, &plan.nextWorkStep().?.entry.target.target_event_id);
    try std.testing.expectEqualSlices(u8, &stable_target.id, &plan.useCachedEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.deferredEntries()[0].target.target_event_id);
}

test "opentimestamps verifier turn policy tracks selected refresh entries when batch work is bounded" {
    var stable_target = try testTargetEvent(1, "stable");
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    stable_target.id = [_]u8{0xa4} ** 32;
    soon_target.id = [_]u8{0xa5} ** 32;
    stale_target.id = [_]u8{0xa6} ** 32;

    var verification_store_records: [3]StoredRecord =
        [_]StoredRecord{ .{}, .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(&verification_store, &stable_target, 0x53, 45, 0x53, "https://proof.example/stable.ots");
    try rememberTestRemoteVerification(&verification_store, &soon_target, 0x54, 35, 0x54, "https://proof.example/soon.ots");
    try rememberTestRemoteVerification(&verification_store, &stale_target, 0x55, 5, 0x55, "https://proof.example/stale.ots");

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
        .{ .target_event_id = stable_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]TargetTurnPolicyEntry = undefined;
    var groups_storage: [4]TargetTurnPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 2,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 0), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 2), plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 0), plan.defer_refresh_count);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.refreshSelectedEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &soon_target.id, &plan.refreshSelectedEntries()[1].target.target_event_id);
}

test "opentimestamps verifier turn policy exposes typed next work step" {
    var stale_target = try testTargetEvent(1, "stale");
    stale_target.id = [_]u8{0xa7} ** 32;

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(
        &verification_store,
        &stale_target,
        5,
        5,
        0x56,
        "https://proof.example/stale.ots",
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [1]TargetLatestEntry = undefined;
    var cadence_entries_storage: [1]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    var entries_storage: [1]TargetTurnPolicyEntry = undefined;
    var groups_storage: [4]TargetTurnPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );
    const step = plan.nextWorkStep().?;
    try std.testing.expectEqual(TargetTurnPolicyAction.refresh_selected, step.action);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &step.entry.target.target_event_id);
}

test "opentimestamps verifier turn policy exposes work idle cached and deferred views" {
    var stable_target = try testTargetEvent(1, "stable");
    var soon_target = try testTargetEvent(1, "soon");
    var stale_target = try testTargetEvent(1, "stale");
    stable_target.id = [_]u8{0xa8} ** 32;
    soon_target.id = [_]u8{0xa9} ** 32;
    stale_target.id = [_]u8{0xaa} ** 32;

    var verification_store_records: [3]StoredRecord =
        [_]StoredRecord{ .{}, .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    try rememberTestRemoteVerification(&verification_store, &stable_target, 0x57, 45, 0x57, "https://proof.example/stable.ots");
    try rememberTestRemoteVerification(&verification_store, &soon_target, 0x58, 35, 0x58, "https://proof.example/soon.ots");
    try rememberTestRemoteVerification(&verification_store, &stale_target, 0x59, 5, 0x59, "https://proof.example/stale.ots");

    const targets = [_]StoredTarget{
        .{ .target_event_id = stale_target.id },
        .{ .target_event_id = soon_target.id },
        .{ .target_event_id = stable_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var latest_entries_storage: [3]TargetLatestEntry = undefined;
    var cadence_entries_storage: [3]TargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]TargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]TargetTurnPolicyEntry = undefined;
    var groups_storage: [4]TargetTurnPolicyGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationTurnPolicyForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 1,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), plan.workEntries().len);
    try std.testing.expectEqual(@as(usize, 2), plan.idleEntries().len);
    try std.testing.expectEqual(@as(usize, 1), plan.useCachedEntries().len);
    try std.testing.expectEqual(@as(usize, 1), plan.deferredEntries().len);
    try std.testing.expectEqualSlices(u8, &stale_target.id, &plan.workEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &stable_target.id, &plan.useCachedEntries()[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &soon_target.id, &plan.deferredEntries()[0].target.target_event_id);
}

test "opentimestamps verifier target-set refresh plan returns stale remembered proofs newest first" {
    var first_target = try testTargetEvent(1, "hello");
    var second_target = try testTargetEvent(1, "world");
    first_target.id = [_]u8{0xb1} ** 32;
    second_target.id = [_]u8{0xb2} ** 32;

    const first_proof = testLocalProof(first_target.id, bitcoin_attestation_tag, &.{0x30});
    const second_proof = testLocalProof(second_target.id, bitcoin_attestation_tag, &.{0x31});

    var first_proof_base64_storage: [128]u8 = undefined;
    var first_attestation_fixture = try testAttestationEvent(
        first_proof_base64_storage[0..],
        &first_target,
        first_proof,
        testLocalProofLen(1),
    );
    first_attestation_fixture.event.id = [_]u8{0xb3} ** 32;
    first_attestation_fixture.event.created_at = 5;
    first_attestation_fixture.fixup();

    var second_proof_base64_storage: [128]u8 = undefined;
    var second_attestation_fixture = try testAttestationEvent(
        second_proof_base64_storage[0..],
        &second_target,
        second_proof,
        testLocalProofLen(1),
    );
    second_attestation_fixture.event.id = [_]u8{0xb4} ** 32;
    second_attestation_fixture.event.created_at = 20;
    second_attestation_fixture.fixup();

    var decoded_first_proof: [128]u8 = undefined;
    var decoded_second_proof: [128]u8 = undefined;
    const first_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_first_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = first_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const second_verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_second_proof[0..],
                &second_attestation_fixture.event,
            ),
            .proof = second_proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &first_target,
        &first_attestation_fixture.event,
        &first_verification,
    );
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &second_target,
        &second_attestation_fixture.event,
        &second_verification,
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = first_target.id },
        .{ .target_event_id = second_target.id },
        .{ .target_event_id = [_]u8{0xb5} ** 32 },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [3]TargetLatestEntry = undefined;
    const refresh_detail_entries = [_]StoredRefreshEntry{};
    var refresh_entries: [2]TargetRefreshEntry = undefined;
    const plan = try OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                refresh_detail_entries[0..],
                refresh_entries[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), plan.entries.len);
    try std.testing.expectEqualSlices(u8, &second_target.id, &plan.entries[0].target.target_event_id);
    try std.testing.expectEqualSlices(u8, &first_target.id, &plan.entries[1].target.target_event_id);
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        plan.entries[0].latest.latest.verification.proofUrl(),
    );
    try std.testing.expectEqualStrings(
        "https://proof.example/old.ots",
        plan.entries[1].latest.latest.verification.proofUrl(),
    );
    try std.testing.expectEqualSlices(u8, &second_target.id, &plan.nextEntry().?.target.target_event_id);
    try std.testing.expectEqualSlices(u8, &second_target.id, &plan.nextStep().?.entry.target.target_event_id);
}

test "opentimestamps verifier target-set refresh plan returns empty for fresh or missing targets" {
    var target = try testTargetEvent(1, "hello");
    target.id = [_]u8{0xc1} ** 32;

    const proof = testLocalProof(target.id, bitcoin_attestation_tag, &.{0x32});
    var proof_base64_storage: [128]u8 = undefined;
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        &target,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{0xc2} ** 32;
    attestation_fixture.event.created_at = 45;
    attestation_fixture.fixup();

    var decoded_proof: [128]u8 = undefined;
    const verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof[0..],
                &attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/fresh.ots",
    };

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target,
        &attestation_fixture.event,
        &verification,
    );

    const targets = [_]StoredTarget{
        .{ .target_event_id = target.id },
        .{ .target_event_id = [_]u8{0xc3} ** 32 },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [2]TargetLatestEntry = undefined;
    const refresh_detail_entries = [_]StoredRefreshEntry{};
    var refresh_entries: [1]TargetRefreshEntry = undefined;
    const plan = try OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(
        verification_store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                refresh_detail_entries[0..],
                refresh_entries[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 0), plan.entries.len);
    try std.testing.expect(plan.nextEntry() == null);
    try std.testing.expect(plan.nextStep() == null);
}

test "opentimestamps verifier refresh readiness groups stale targets by archive availability" {
    var ready_target = try testTargetEvent(1, "ready");
    ready_target.id = [_]u8{0xd1} ** 32;
    var missing_target_target = try testTargetEvent(1, "missing target");
    missing_target_target.id = [_]u8{0xd2} ** 32;
    var missing_attestation_target = try testTargetEvent(1, "missing attestation");
    missing_attestation_target.id = [_]u8{0xd3} ** 32;
    var missing_events_target = try testTargetEvent(1, "missing both");
    missing_events_target.id = [_]u8{0xd4} ** 32;

    var verification_store_records: [4]StoredRecord =
        [_]StoredRecord{.{}} ** 4;
    var verification_store =
        MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const ready_attestation = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &ready_target,
        0xe1,
        30,
        0x71,
        "https://proof.example/ready.ots",
    );
    const missing_target_attestation = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &missing_target_target,
        0xe2,
        25,
        0x72,
        "https://proof.example/missing-target.ots",
    );
    _ = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &missing_attestation_target,
        0xe3,
        20,
        0x73,
        "https://proof.example/missing-attestation.ots",
    );
    _ = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &missing_events_target,
        0xe4,
        15,
        0x74,
        "https://proof.example/missing-both.ots",
    );

    var archive_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const archive = store_archive.EventArchive.init(archive_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var ready_target_json_storage: [512]u8 = undefined;
    const ready_target_json = try noztr.nip01_event.event_serialize_json_object(
        ready_target_json_storage[0..],
        &ready_target,
    );
    try archive.ingestEventJson(ready_target_json, arena.allocator());

    var ready_attestation_json_storage: [1024]u8 = undefined;
    var ready_attestation_archive_event = ready_attestation.event;
    ready_attestation_archive_event.tags = &.{};
    ready_attestation_archive_event.content = "archive";
    const ready_attestation_json = try noztr.nip01_event.event_serialize_json_object(
        ready_attestation_json_storage[0..],
        &ready_attestation_archive_event,
    );
    try archive.ingestEventJson(ready_attestation_json, arena.allocator());

    var missing_target_attestation_json_storage: [1024]u8 = undefined;
    var missing_target_attestation_archive_event = missing_target_attestation.event;
    missing_target_attestation_archive_event.tags = &.{};
    missing_target_attestation_archive_event.content = "archive";
    const missing_target_attestation_json = try noztr.nip01_event.event_serialize_json_object(
        missing_target_attestation_json_storage[0..],
        &missing_target_attestation_archive_event,
    );
    try archive.ingestEventJson(missing_target_attestation_json, arena.allocator());

    var missing_attestation_target_json_storage: [512]u8 = undefined;
    const missing_attestation_target_json = try noztr.nip01_event.event_serialize_json_object(
        missing_attestation_target_json_storage[0..],
        &missing_attestation_target,
    );
    try archive.ingestEventJson(missing_attestation_target_json, arena.allocator());

    const targets = [_]StoredTarget{
        .{ .target_event_id = ready_target.id },
        .{ .target_event_id = missing_target_target.id },
        .{ .target_event_id = missing_attestation_target.id },
        .{ .target_event_id = missing_events_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [4]TargetLatestEntry = undefined;
    const refresh_detail_entries = [_]StoredRefreshEntry{};
    var target_refresh_entries: [4]TargetRefreshEntry = undefined;
    var target_records: [2]client_store.ClientEventRecord = undefined;
    var attestation_records: [2]client_store.ClientEventRecord = undefined;
    var readiness_entries: [4]TargetReadinessEntry = undefined;
    var readiness_groups: [4]TargetReadinessGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshReadinessForTargets(
        verification_store.asStore(),
        archive,
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                refresh_detail_entries[0..],
                target_refresh_entries[0..],
                target_records[0..],
                attestation_records[0..],
                readiness_entries[0..],
                readiness_groups[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.ready_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_target_event_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_attestation_event_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_events_count);
    try std.testing.expectEqual(@as(usize, 4), plan.entries.len);
    try std.testing.expectEqual(
        TargetReadinessAction.ready_refresh,
        plan.groups[0].action,
    );
    try std.testing.expectEqual(
        TargetReadinessAction.missing_target_event,
        plan.groups[1].action,
    );
    try std.testing.expectEqual(
        TargetReadinessAction.missing_attestation_event,
        plan.groups[2].action,
    );
    try std.testing.expectEqual(
        TargetReadinessAction.missing_events,
        plan.groups[3].action,
    );
    try std.testing.expectEqualSlices(
        u8,
        &ready_target.id,
        &plan.nextReadyEntry().?.target.target_event_id,
    );
    try std.testing.expectEqualSlices(
        u8,
        &ready_target.id,
        &plan.nextReadyStep().?.entry.target.target_event_id,
    );
    try std.testing.expectEqual(@as(usize, 1), plan.readyEntries().len);
    try std.testing.expectEqual(@as(usize, 3), plan.blockedEntries().len);
    try std.testing.expect(plan.targetRecord(plan.nextReadyEntry().?) != null);
    try std.testing.expect(plan.attestationRecord(plan.nextReadyEntry().?) != null);
    try std.testing.expect(plan.targetRecord(&plan.groups[1].entries[0]) == null);
    try std.testing.expect(plan.attestationRecord(&plan.groups[1].entries[0]) != null);
    try std.testing.expect(plan.targetRecord(&plan.groups[2].entries[0]) != null);
    try std.testing.expect(plan.attestationRecord(&plan.groups[2].entries[0]) == null);
    try std.testing.expect(plan.targetRecord(&plan.groups[3].entries[0]) == null);
    try std.testing.expect(plan.attestationRecord(&plan.groups[3].entries[0]) == null);
}

test "opentimestamps verifier refresh readiness stays bounded by caller-owned archive record storage" {
    var target = try testTargetEvent(1, "ready");
    target.id = [_]u8{0xd5} ** 32;

    var verification_store_records: [1]StoredRecord =
        [_]StoredRecord{.{}};
    var verification_store =
        MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    const attestation = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &target,
        0xe5,
        30,
        0x75,
        "https://proof.example/ready.ots",
    );

    var archive_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const archive = store_archive.EventArchive.init(archive_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var target_json_storage: [512]u8 = undefined;
    const target_json = try noztr.nip01_event.event_serialize_json_object(
        target_json_storage[0..],
        &target,
    );
    try archive.ingestEventJson(target_json, arena.allocator());

    var attestation_json_storage: [1024]u8 = undefined;
    var attestation_archive_event = attestation.event;
    attestation_archive_event.tags = &.{};
    attestation_archive_event.content = "archive";
    const attestation_json = try noztr.nip01_event.event_serialize_json_object(
        attestation_json_storage[0..],
        &attestation_archive_event,
    );
    try archive.ingestEventJson(attestation_json, arena.allocator());

    const targets = [_]StoredTarget{
        .{ .target_event_id = target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [1]TargetLatestEntry = undefined;
    const refresh_detail_entries = [_]StoredRefreshEntry{};
    var target_refresh_entries: [1]TargetRefreshEntry = undefined;
    const target_records = [_]client_store.ClientEventRecord{};
    var attestation_records: [1]client_store.ClientEventRecord = undefined;
    var readiness_entries: [1]TargetReadinessEntry = undefined;
    var readiness_groups: [4]TargetReadinessGroup = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        OpenTimestampsVerifier.inspectStoredVerificationRefreshReadinessForTargets(
            verification_store.asStore(),
            archive,
            .{
                .targets = targets[0..],
                .now_unix_seconds = 50,
                .max_age_seconds = 10,
                .storage = .init(
                    matches_storage[0..],
                    freshness_entries[0..],
                    refresh_detail_entries[0..],
                    target_refresh_entries[0..],
                    target_records[0..],
                    attestation_records[0..],
                    readiness_entries[0..],
                    readiness_groups[0..],
                ),
            },
        ),
    );
}

test "opentimestamps verifier refresh readiness exposes blocked stale targets explicitly" {
    var ready_target = try testTargetEvent(1, "ready");
    ready_target.id = [_]u8{0xd6} ** 32;
    var blocked_target = try testTargetEvent(1, "blocked");
    blocked_target.id = [_]u8{0xd7} ** 32;

    var verification_store_records: [2]StoredRecord =
        [_]StoredRecord{ .{}, .{} };
    var verification_store =
        MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    const ready_attestation = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &ready_target,
        0xe6,
        30,
        0x76,
        "https://proof.example/ready.ots",
    );
    _ = try rememberTestRemoteVerificationFixture(
        &verification_store,
        &blocked_target,
        0xe7,
        20,
        0x77,
        "https://proof.example/blocked.ots",
    );

    var archive_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const archive = store_archive.EventArchive.init(archive_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var ready_target_json_storage: [512]u8 = undefined;
    const ready_target_json = try noztr.nip01_event.event_serialize_json_object(
        ready_target_json_storage[0..],
        &ready_target,
    );
    try archive.ingestEventJson(ready_target_json, arena.allocator());

    var ready_attestation_json_storage: [1024]u8 = undefined;
    var ready_attestation_archive_event = ready_attestation.event;
    ready_attestation_archive_event.tags = &.{};
    ready_attestation_archive_event.content = "archive";
    const ready_attestation_json = try noztr.nip01_event.event_serialize_json_object(
        ready_attestation_json_storage[0..],
        &ready_attestation_archive_event,
    );
    try archive.ingestEventJson(ready_attestation_json, arena.allocator());

    const targets = [_]StoredTarget{
        .{ .target_event_id = ready_target.id },
        .{ .target_event_id = blocked_target.id },
    };
    var matches_storage: [1]StoredMatch = undefined;
    var freshness_entries: [2]TargetLatestEntry = undefined;
    const refresh_detail_entries = [_]StoredRefreshEntry{};
    var target_refresh_entries: [2]TargetRefreshEntry = undefined;
    var target_records: [1]client_store.ClientEventRecord = undefined;
    var attestation_records: [1]client_store.ClientEventRecord = undefined;
    var readiness_entries: [2]TargetReadinessEntry = undefined;
    var readiness_groups: [4]TargetReadinessGroup = undefined;
    const plan = try OpenTimestampsVerifier.inspectStoredVerificationRefreshReadinessForTargets(
        verification_store.asStore(),
        archive,
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .storage = .init(
                matches_storage[0..],
                freshness_entries[0..],
                refresh_detail_entries[0..],
                target_refresh_entries[0..],
                target_records[0..],
                attestation_records[0..],
                readiness_entries[0..],
                readiness_groups[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), plan.readyEntries().len);
    try std.testing.expectEqual(@as(usize, 1), plan.blockedEntries().len);
    try std.testing.expectEqual(
        TargetReadinessAction.missing_events,
        plan.blockedEntries()[0].action,
    );
}

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65,
    0x73, 0x74, 0x61, 0x6d, 0x70, 0x73, 0x00, 0x00, 0x50,
    0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8,
    0x84, 0xe8, 0x92, 0x94,
};
const ots_op_sha256: u8 = 0x08;
const ots_tag_attestation: u8 = 0x00;
const bitcoin_attestation_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

fn testTargetEvent(kind: u32, content: []const u8) !noztr.nip01_event.Event {
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x03} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 1,
        .content = content,
        .tags = &.{},
    };
    event.id = try noztr.nip01_event.event_compute_id_checked(&event);
    return event;
}

fn rememberTestRemoteVerificationFixture(
    verification_store: *MemoryOpenTimestampsVerificationStore,
    target: *const noztr.nip01_event.Event,
    attestation_id_fill: u8,
    attestation_created_at: u64,
    proof_marker: u8,
    proof_url: []const u8,
) !TestAttestationFixture {
    const proof = testLocalProof(target.id, bitcoin_attestation_tag, &.{proof_marker});
    var proof_base64_storage: [128]u8 = undefined;
    var attestation_fixture = try testAttestationEvent(
        proof_base64_storage[0..],
        target,
        proof,
        testLocalProofLen(1),
    );
    attestation_fixture.event.id = [_]u8{attestation_id_fill} ** 32;
    attestation_fixture.event.created_at = attestation_created_at;
    attestation_fixture.fixup();

    var decoded_proof: [128]u8 = undefined;
    const verification: RemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof[0..],
                &attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = proof_url,
    };

    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        target,
        &attestation_fixture.event,
        &verification,
    );
    return attestation_fixture;
}

fn rememberTestRemoteVerification(
    verification_store: *MemoryOpenTimestampsVerificationStore,
    target: *const noztr.nip01_event.Event,
    attestation_id_fill: u8,
    attestation_created_at: u64,
    proof_marker: u8,
    proof_url: []const u8,
) !void {
    _ = try rememberTestRemoteVerificationFixture(
        verification_store,
        target,
        attestation_id_fill,
        attestation_created_at,
        proof_marker,
        proof_url,
    );
}

const TestAttestationFixture = struct {
    target_id_hex: [64]u8,
    target_kind: u32,
    event_tag: noztr.nip03_opentimestamps.TagBuilder,
    kind_tag: noztr.nip03_opentimestamps.TagBuilder,
    tags: [2]noztr.nip01_event.EventTag,
    event: noztr.nip01_event.Event,

    fn fixup(self: *TestAttestationFixture) void {
        self.tags[0] = noztr.nip03_opentimestamps.opentimestamps_build_event_tag(
            &self.event_tag,
            self.target_id_hex[0..],
            "wss://relay.example",
        ) catch unreachable;
        self.tags[1] = noztr.nip03_opentimestamps.opentimestamps_build_kind_tag(
            &self.kind_tag,
            self.target_kind,
        ) catch unreachable;
        self.event.tags = self.tags[0..];
    }
};

fn testAttestationEvent(
    proof_base64_buffer: []u8,
    target_event: *const noztr.nip01_event.Event,
    proof: [96]u8,
    proof_len: usize,
) !TestAttestationFixture {
    var fixture: TestAttestationFixture = .{
        .target_id_hex = undefined,
        .target_kind = target_event.kind,
        .event_tag = .{},
        .kind_tag = .{},
        .tags = undefined,
        .event = undefined,
    };
    _ = std.fmt.bufPrint(
        fixture.target_id_hex[0..],
        "{s}",
        .{std.fmt.bytesToHex(target_event.id, .lower)},
    ) catch unreachable;
    const proof_base64 = try encodeProofBase64(proof_base64_buffer, proof[0..proof_len]);

    fixture.event = .{
        .id = [_]u8{0x04} ** 32,
        .pubkey = [_]u8{0x05} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1040,
        .created_at = 1,
        .content = proof_base64,
        .tags = &.{},
    };
    fixture.fixup();
    return fixture;
}

fn encodeProofBase64(output: []u8, proof: []const u8) ![]const u8 {
    const encoded_len = std.base64.standard.Encoder.calcSize(proof.len);
    if (encoded_len > output.len) return error.BufferTooSmall;
    return std.base64.standard.Encoder.encode(output[0..encoded_len], proof);
}

fn parseEventId(text: []const u8) ![32]u8 {
    var output: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&output, text);
    return output;
}

fn testLocalProof(
    digest: [32]u8,
    attestation_tag: [8]u8,
    payload: []const u8,
) [96]u8 {
    var output: [96]u8 = [_]u8{0} ** 96;
    var index: usize = 0;

    @memcpy(output[index .. index + ots_header_magic.len], ots_header_magic[0..]);
    index += ots_header_magic.len;
    output[index] = 0x01;
    output[index + 1] = ots_op_sha256;
    index += 2;
    @memcpy(output[index .. index + digest.len], digest[0..]);
    index += digest.len;
    output[index] = ots_tag_attestation;
    index += 1;
    @memcpy(output[index .. index + attestation_tag.len], attestation_tag[0..]);
    index += attestation_tag.len;
    output[index] = @intCast(payload.len);
    index += 1;
    @memcpy(output[index .. index + payload.len], payload);
    return output;
}

fn testLocalProofLen(payload_len: usize) usize {
    return ots_header_magic.len + 1 + 1 + 32 + 1 + 8 + 1 + payload_len;
}

const TestHttp = struct {
    url: []const u8,
    body: []const u8 = "",
    failure: ?transport.HttpError = null,
    request_count: usize = 0,

    fn init(url: []const u8, body: []const u8) TestHttp {
        return .{
            .url = url,
            .body = body,
        };
    }

    fn initFailure(url: []const u8, failure: transport.HttpError) TestHttp {
        return .{
            .url = url,
            .failure = failure,
        };
    }

    fn client(self: *TestHttp) transport.HttpClient {
        return .{
            .ctx = self,
            .get_fn = get,
        };
    }

    fn get(
        ctx: *anyopaque,
        request: transport.HttpRequest,
        out: []u8,
    ) transport.HttpError![]const u8 {
        const self: *TestHttp = @ptrCast(@alignCast(ctx));
        if (!std.mem.eql(u8, request.url, self.url)) return error.NotFound;
        self.request_count += 1;
        if (self.failure) |failure| return failure;
        if (out.len < self.body.len) return error.ResponseTooLarge;
        std.mem.copyForwards(u8, out[0..self.body.len], self.body);
        return out[0..self.body.len];
    }
};
