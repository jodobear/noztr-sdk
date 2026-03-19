const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const IdentityVerifierError =
    noztr.nip39_external_identities.Nip39Error ||
    error{UnsupportedProviderVerification};

pub const IdentityVerificationMatch = struct {
    proof_url: []const u8,
    expected_text: []const u8,
};

pub const IdentityVerificationStorage = struct {
    url_buffer: []u8,
    expected_text_buffer: []u8,
    body_buffer: []u8,

    pub fn init(
        url_buffer: []u8,
        expected_text_buffer: []u8,
        body_buffer: []u8,
    ) IdentityVerificationStorage {
        return .{
            .url_buffer = url_buffer,
            .expected_text_buffer = expected_text_buffer,
            .body_buffer = body_buffer,
        };
    }
};

pub const IdentityVerificationRequest = struct {
    claim: *const noztr.nip39_external_identities.IdentityClaim,
    pubkey: *const [32]u8,
    storage: IdentityVerificationStorage,
};

pub const IdentityVerificationFetchFailure = struct {
    verification: IdentityVerificationMatch,
    cause: transport.HttpError,
};

pub const verification_cache_url_max_bytes: u16 = 512;
pub const verification_cache_text_max_bytes: u16 = 512;

pub const IdentityVerificationCacheResult = enum {
    verified,
    mismatch,
    unsupported,
};

pub const IdentityVerificationCacheRecord = struct {
    proof_url: [verification_cache_url_max_bytes]u8 = [_]u8{0} ** verification_cache_url_max_bytes,
    proof_url_len: u16 = 0,
    expected_text: [verification_cache_text_max_bytes]u8 = [_]u8{0} **
        verification_cache_text_max_bytes,
    expected_text_len: u16 = 0,
    result: IdentityVerificationCacheResult = .mismatch,
    occupied: bool = false,

    pub fn proofUrl(self: *const IdentityVerificationCacheRecord) []const u8 {
        return self.proof_url[0..self.proof_url_len];
    }

    pub fn expectedText(self: *const IdentityVerificationCacheRecord) []const u8 {
        return self.expected_text[0..self.expected_text_len];
    }
};

pub const IdentityVerificationCacheError = error{
    ProofUrlTooLong,
    ExpectedTextTooLong,
    CacheFull,
};

pub const IdentityVerificationCacheVTable = struct {
    put_cached: *const fn (
        ctx: *anyopaque,
        verification: *const IdentityVerificationMatch,
        result: IdentityVerificationCacheResult,
    ) IdentityVerificationCacheError!void,
    get_cached: *const fn (
        ctx: *anyopaque,
        verification: *const IdentityVerificationMatch,
    ) IdentityVerificationCacheError!?IdentityVerificationCacheResult,
};

pub const IdentityVerificationCache = struct {
    ctx: *anyopaque,
    vtable: *const IdentityVerificationCacheVTable,

    pub fn putCached(
        self: IdentityVerificationCache,
        verification: *const IdentityVerificationMatch,
        result: IdentityVerificationCacheResult,
    ) IdentityVerificationCacheError!void {
        return self.vtable.put_cached(self.ctx, verification, result);
    }

    pub fn getCached(
        self: IdentityVerificationCache,
        verification: *const IdentityVerificationMatch,
    ) IdentityVerificationCacheError!?IdentityVerificationCacheResult {
        return self.vtable.get_cached(self.ctx, verification);
    }
};

pub const MemoryIdentityVerificationCache = struct {
    records: []IdentityVerificationCacheRecord,
    count: usize = 0,

    pub fn init(records: []IdentityVerificationCacheRecord) MemoryIdentityVerificationCache {
        return .{ .records = records };
    }

    pub fn asCache(self: *MemoryIdentityVerificationCache) IdentityVerificationCache {
        return .{
            .ctx = self,
            .vtable = &cache_vtable,
        };
    }

    pub fn putCached(
        self: *MemoryIdentityVerificationCache,
        verification: *const IdentityVerificationMatch,
        result: IdentityVerificationCacheResult,
    ) IdentityVerificationCacheError!void {
        if (verification.proof_url.len > verification_cache_url_max_bytes) {
            return error.ProofUrlTooLong;
        }
        if (verification.expected_text.len > verification_cache_text_max_bytes) {
            return error.ExpectedTextTooLong;
        }
        if (self.findIndex(verification)) |index| {
            self.writeRecord(index, verification, result);
            return;
        }
        if (self.count == self.records.len) return error.CacheFull;
        self.writeRecord(self.count, verification, result);
        self.count += 1;
    }

    pub fn getCached(
        self: *MemoryIdentityVerificationCache,
        verification: *const IdentityVerificationMatch,
    ) IdentityVerificationCacheError!?IdentityVerificationCacheResult {
        if (verification.proof_url.len > verification_cache_url_max_bytes) {
            return error.ProofUrlTooLong;
        }
        if (verification.expected_text.len > verification_cache_text_max_bytes) {
            return error.ExpectedTextTooLong;
        }
        const index = self.findIndex(verification) orelse return null;
        return self.records[index].result;
    }

    fn writeRecord(
        self: *MemoryIdentityVerificationCache,
        index: usize,
        verification: *const IdentityVerificationMatch,
        result: IdentityVerificationCacheResult,
    ) void {
        @memset(self.records[index].proof_url[0..], 0);
        @memcpy(
            self.records[index].proof_url[0..verification.proof_url.len],
            verification.proof_url,
        );
        self.records[index].proof_url_len = @intCast(verification.proof_url.len);
        @memset(self.records[index].expected_text[0..], 0);
        @memcpy(
            self.records[index].expected_text[0..verification.expected_text.len],
            verification.expected_text,
        );
        self.records[index].expected_text_len = @intCast(verification.expected_text.len);
        self.records[index].result = result;
        self.records[index].occupied = true;
    }

    fn findIndex(
        self: *const MemoryIdentityVerificationCache,
        verification: *const IdentityVerificationMatch,
    ) ?usize {
        for (self.records[0..self.count], 0..) |*record, index| {
            if (!record.occupied) continue;
            if (!std.mem.eql(u8, record.proofUrl(), verification.proof_url)) continue;
            if (!std.mem.eql(u8, record.expectedText(), verification.expected_text)) continue;
            return index;
        }
        return null;
    }
};

pub const identity_profile_store_identity_max_bytes: u16 = 512;
pub const identity_profile_store_proof_max_bytes: u16 = 512;
pub const identity_profile_store_verified_claims_max: u8 = 16;

pub const IdentityProfileStorePutOutcome = enum {
    stored,
    ignored_stale,
};

pub const IdentityProfileStoreError = error{
    IdentityTooLong,
    ProofTooLong,
    TooManyVerifiedClaims,
    StoreFull,
    InconsistentStoreData,
};

pub const IdentityStoredClaim = struct {
    provider: noztr.nip39_external_identities.IdentityProvider = .github,
    identity: [identity_profile_store_identity_max_bytes]u8 = [_]u8{0} **
        identity_profile_store_identity_max_bytes,
    identity_len: u16 = 0,
    proof: [identity_profile_store_proof_max_bytes]u8 = [_]u8{0} **
        identity_profile_store_proof_max_bytes,
    proof_len: u16 = 0,

    pub fn identitySlice(self: *const IdentityStoredClaim) []const u8 {
        return self.identity[0..self.identity_len];
    }

    pub fn proofSlice(self: *const IdentityStoredClaim) []const u8 {
        return self.proof[0..self.proof_len];
    }
};

pub const IdentityProfileRecord = struct {
    pubkey: [32]u8 = [_]u8{0} ** 32,
    created_at: u64 = 0,
    verified_claims: [identity_profile_store_verified_claims_max]IdentityStoredClaim =
        [_]IdentityStoredClaim{.{}} ** identity_profile_store_verified_claims_max,
    verified_claim_count: u8 = 0,
    verified_count: u16 = 0,
    mismatch_count: u16 = 0,
    fetch_failed_count: u16 = 0,
    unsupported_count: u16 = 0,
    occupied: bool = false,

    pub fn verifiedClaims(self: *const IdentityProfileRecord) []const IdentityStoredClaim {
        return self.verified_claims[0..self.verified_claim_count];
    }
};

pub const IdentityProfileMatch = struct {
    pubkey: [32]u8,
    created_at: u64,
};

pub const IdentityProfileDiscoveryRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    results: []IdentityProfileMatch,
};

pub const IdentityStoredProfileDiscoveryEntry = struct {
    match: IdentityProfileMatch,
    profile: IdentityProfileRecord,
    matched_claim_index: u8,

    pub fn matchedClaim(self: *const IdentityStoredProfileDiscoveryEntry) *const IdentityStoredClaim {
        return &self.profile.verifiedClaims()[self.matched_claim_index];
    }
};

pub const IdentityStoredProfileDiscoveryStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityStoredProfileDiscoveryEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityStoredProfileDiscoveryEntry,
    ) IdentityStoredProfileDiscoveryStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const IdentityStoredProfileDiscoveryRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    storage: IdentityStoredProfileDiscoveryStorage,
};

pub const IdentityLatestStoredProfileRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    matches: []IdentityProfileMatch,
};

pub const IdentityStoredProfileFreshness = enum {
    fresh,
    stale,
};

pub const IdentityStoredProfileFallbackPolicy = enum {
    require_fresh,
    allow_stale_latest,
};

pub const IdentityLatestStoredProfileFreshnessRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    matches: []IdentityProfileMatch,
};

pub const IdentityLatestStoredProfileFreshness = struct {
    latest: IdentityStoredProfileDiscoveryEntry,
    freshness: IdentityStoredProfileFreshness,
    age_seconds: u64,
};

pub const IdentityPreferredStoredProfileRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    matches: []IdentityProfileMatch,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
};

pub const IdentityPreferredStoredProfile = struct {
    entry: IdentityStoredProfileDiscoveryEntry,
    freshness: IdentityStoredProfileFreshness,
    age_seconds: u64,
};

pub const IdentityStoredProfileDiscoveryFreshnessEntry = struct {
    entry: IdentityStoredProfileDiscoveryEntry,
    freshness: IdentityStoredProfileFreshness,
    age_seconds: u64,

    pub fn matchedClaim(self: *const IdentityStoredProfileDiscoveryFreshnessEntry) *const IdentityStoredClaim {
        return self.entry.matchedClaim();
    }
};

pub const IdentityStoredProfileDiscoveryFreshnessStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityStoredProfileDiscoveryFreshnessEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityStoredProfileDiscoveryFreshnessEntry,
    ) IdentityStoredProfileDiscoveryFreshnessStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const IdentityStoredProfileDiscoveryFreshnessRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: IdentityStoredProfileDiscoveryFreshnessStorage,
};

pub const IdentityStoredProfileTarget = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
};

pub const IdentityStoredProfileTargetDiscoveryGroup = struct {
    target: IdentityStoredProfileTarget,
    entries: []const IdentityStoredProfileDiscoveryEntry,
};

pub const IdentityStoredProfileTargetDiscoveryStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityStoredProfileDiscoveryEntry,
    groups: []IdentityStoredProfileTargetDiscoveryGroup,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityStoredProfileDiscoveryEntry,
        groups: []IdentityStoredProfileTargetDiscoveryGroup,
    ) IdentityStoredProfileTargetDiscoveryStorage {
        return .{
            .matches = matches,
            .entries = entries,
            .groups = groups,
        };
    }
};

pub const IdentityStoredProfileTargetDiscoveryRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    storage: IdentityStoredProfileTargetDiscoveryStorage,
};

pub const IdentityStoredProfileTargetDiscoveryFreshnessGroup = struct {
    target: IdentityStoredProfileTarget,
    entries: []const IdentityStoredProfileDiscoveryFreshnessEntry,
};

pub const IdentityStoredProfileTargetDiscoveryFreshnessStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityStoredProfileDiscoveryFreshnessEntry,
    groups: []IdentityStoredProfileTargetDiscoveryFreshnessGroup,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityStoredProfileDiscoveryFreshnessEntry,
        groups: []IdentityStoredProfileTargetDiscoveryFreshnessGroup,
    ) IdentityStoredProfileTargetDiscoveryFreshnessStorage {
        return .{
            .matches = matches,
            .entries = entries,
            .groups = groups,
        };
    }
};

pub const IdentityStoredProfileTargetDiscoveryFreshnessRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: IdentityStoredProfileTargetDiscoveryFreshnessStorage,
};

pub const IdentityLatestStoredProfileTargetEntry = struct {
    target: IdentityStoredProfileTarget,
    latest: ?IdentityStoredProfileDiscoveryEntry = null,
};

pub const IdentityLatestStoredProfileTargetStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityLatestStoredProfileTargetEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityLatestStoredProfileTargetEntry,
    ) IdentityLatestStoredProfileTargetStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const IdentityLatestStoredProfileTargetRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    storage: IdentityLatestStoredProfileTargetStorage,
};

pub const IdentityPreferredStoredProfileTargetEntry = struct {
    target: IdentityStoredProfileTarget,
    preferred: ?IdentityPreferredStoredProfile = null,
};

pub const IdentityPreferredStoredProfileTargetStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityPreferredStoredProfileTargetEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityPreferredStoredProfileTargetEntry,
    ) IdentityPreferredStoredProfileTargetStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const IdentityPreferredStoredProfileTargetSelectionRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityPreferredStoredProfileTargetStorage,
};

pub const IdentityStoredProfileTargetLatestFreshnessEntry = struct {
    target: IdentityStoredProfileTarget,
    latest: ?IdentityLatestStoredProfileFreshness = null,
};

pub const IdentityStoredProfileTargetLatestFreshnessStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityStoredProfileTargetLatestFreshnessEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
    ) IdentityStoredProfileTargetLatestFreshnessStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const IdentityStoredProfileTargetLatestFreshnessRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: IdentityStoredProfileTargetLatestFreshnessStorage,
};

pub const IdentityPreferredStoredProfileTargetRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileTargetLatestFreshnessStorage,
};

pub const IdentityPreferredStoredProfileTarget = struct {
    target: IdentityStoredProfileTarget,
    latest: IdentityLatestStoredProfileFreshness,
};

pub const IdentityStoredProfileTargetRefreshEntry = struct {
    target: IdentityStoredProfileTarget,
    latest: IdentityLatestStoredProfileFreshness,

    pub fn matchedClaim(self: *const IdentityStoredProfileTargetRefreshEntry) *const IdentityStoredClaim {
        return self.latest.latest.matchedClaim();
    }
};

pub const IdentityStoredProfileTargetRefreshStorage = struct {
    matches: []IdentityProfileMatch,
    freshness_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
    entries: []IdentityStoredProfileTargetRefreshEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        freshness_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
        entries: []IdentityStoredProfileTargetRefreshEntry,
    ) IdentityStoredProfileTargetRefreshStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .entries = entries,
        };
    }
};

pub const IdentityStoredProfileTargetRefreshRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: IdentityStoredProfileTargetRefreshStorage,
};

pub const IdentityStoredProfileTargetRefreshPlan = struct {
    entries: []const IdentityStoredProfileTargetRefreshEntry,

    pub fn nextEntry(
        self: *const IdentityStoredProfileTargetRefreshPlan,
    ) ?*const IdentityStoredProfileTargetRefreshEntry {
        if (self.entries.len == 0) return null;
        return &self.entries[0];
    }

    pub fn nextStep(
        self: *const IdentityStoredProfileTargetRefreshPlan,
    ) ?IdentityStoredProfileTargetRefreshStep {
        const entry = self.nextEntry() orelse return null;
        return .{ .entry = entry.* };
    }
};

pub const IdentityStoredProfileTargetRefreshStep = struct {
    entry: IdentityStoredProfileTargetRefreshEntry,
};

pub const IdentityStoredProfileTargetRuntimeAction = enum {
    verify_now,
    refresh_existing,
    use_preferred,
    use_stale_and_refresh,
};

pub const IdentityStoredProfileTargetRuntimeRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileTargetLatestFreshnessStorage,
};

pub const IdentityStoredProfileTargetRuntimePlan = struct {
    action: IdentityStoredProfileTargetRuntimeAction,
    entries: []const IdentityStoredProfileTargetLatestFreshnessEntry,
    selected_index: ?u32 = null,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextEntry(
        self: *const IdentityStoredProfileTargetRuntimePlan,
    ) ?*const IdentityStoredProfileTargetLatestFreshnessEntry {
        const index = self.selected_index orelse return null;
        const usize_index: usize = @intCast(index);
        if (usize_index >= self.entries.len) return null;
        return &self.entries[usize_index];
    }

    pub fn nextStep(
        self: *const IdentityStoredProfileTargetRuntimePlan,
    ) IdentityStoredProfileTargetRuntimeStep {
        return .{
            .action = self.action,
            .entry = if (self.nextEntry()) |entry| entry.* else null,
        };
    }
};

pub const IdentityStoredProfileTargetRuntimeStep = struct {
    action: IdentityStoredProfileTargetRuntimeAction,
    entry: ?IdentityStoredProfileTargetLatestFreshnessEntry = null,
};

pub const IdentityStoredProfileTargetPolicyEntry = struct {
    target: IdentityStoredProfileTarget,
    action: IdentityStoredProfileTargetRuntimeAction,
    latest: ?IdentityLatestStoredProfileFreshness = null,
};

pub const IdentityStoredProfileTargetPolicyGroup = struct {
    action: IdentityStoredProfileTargetRuntimeAction,
    entries: []const IdentityStoredProfileTargetPolicyEntry,
};

pub const IdentityStoredProfileTargetPolicyStorage = struct {
    matches: []IdentityProfileMatch,
    latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
    entries: []IdentityStoredProfileTargetPolicyEntry,
    groups: []IdentityStoredProfileTargetPolicyGroup,

    pub fn init(
        matches: []IdentityProfileMatch,
        latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
        entries: []IdentityStoredProfileTargetPolicyEntry,
        groups: []IdentityStoredProfileTargetPolicyGroup,
    ) IdentityStoredProfileTargetPolicyStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .entries = entries,
            .groups = groups,
        };
    }
};

pub const IdentityStoredProfileTargetPolicyRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileTargetPolicyStorage,
};

pub const IdentityStoredProfileTargetPolicyPlan = struct {
    entries: []const IdentityStoredProfileTargetPolicyEntry,
    groups: []const IdentityStoredProfileTargetPolicyGroup,
    verify_now_count: u32 = 0,
    use_preferred_count: u32 = 0,
    use_stale_and_refresh_count: u32 = 0,
    refresh_existing_count: u32 = 0,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn usablePreferredEntries(
        self: *const IdentityStoredProfileTargetPolicyPlan,
    ) []const IdentityStoredProfileTargetPolicyEntry {
        const start: usize = @intCast(self.verify_now_count);
        const end = start + @as(usize, @intCast(self.use_preferred_count + self.use_stale_and_refresh_count));
        return self.entries[start..end];
    }

    pub fn verifyNowEntries(
        self: *const IdentityStoredProfileTargetPolicyPlan,
    ) []const IdentityStoredProfileTargetPolicyEntry {
        return self.entries[0..@as(usize, @intCast(self.verify_now_count))];
    }

    pub fn refreshNeededEntries(
        self: *const IdentityStoredProfileTargetPolicyPlan,
    ) []const IdentityStoredProfileTargetPolicyEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.use_preferred_count));
        return self.entries[start..];
    }
};

pub const IdentityStoredProfileTargetRefreshCadenceAction = enum {
    verify_now,
    refresh_now,
    usable_while_refreshing,
    refresh_soon,
    stable,
};

pub const IdentityStoredProfileTargetRefreshCadenceEntry = struct {
    target: IdentityStoredProfileTarget,
    action: IdentityStoredProfileTargetRefreshCadenceAction,
    latest: ?IdentityLatestStoredProfileFreshness = null,
};

pub const IdentityStoredProfileTargetRefreshCadenceGroup = struct {
    action: IdentityStoredProfileTargetRefreshCadenceAction,
    entries: []const IdentityStoredProfileTargetRefreshCadenceEntry,
};

pub const IdentityStoredProfileTargetRefreshCadenceStorage = struct {
    matches: []IdentityProfileMatch,
    latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
    entries: []IdentityStoredProfileTargetRefreshCadenceEntry,
    groups: []IdentityStoredProfileTargetRefreshCadenceGroup,

    pub fn init(
        matches: []IdentityProfileMatch,
        latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
        entries: []IdentityStoredProfileTargetRefreshCadenceEntry,
        groups: []IdentityStoredProfileTargetRefreshCadenceGroup,
    ) IdentityStoredProfileTargetRefreshCadenceStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .entries = entries,
            .groups = groups,
        };
    }
};

pub const IdentityStoredProfileTargetRefreshCadenceRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    refresh_soon_age_seconds: u64,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileTargetRefreshCadenceStorage,
};

pub const IdentityStoredProfileTargetRefreshCadencePlan = struct {
    entries: []const IdentityStoredProfileTargetRefreshCadenceEntry,
    groups: []const IdentityStoredProfileTargetRefreshCadenceGroup,
    verify_now_count: u32 = 0,
    refresh_now_count: u32 = 0,
    usable_while_refreshing_count: u32 = 0,
    refresh_soon_count: u32 = 0,
    stable_count: u32 = 0,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextDueEntry(
        self: *const IdentityStoredProfileTargetRefreshCadencePlan,
    ) ?*const IdentityStoredProfileTargetRefreshCadenceEntry {
        const due_count = self.verify_now_count +
            self.refresh_now_count +
            self.usable_while_refreshing_count +
            self.refresh_soon_count;
        if (due_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextDueStep(
        self: *const IdentityStoredProfileTargetRefreshCadencePlan,
    ) ?IdentityStoredProfileTargetRefreshCadenceStep {
        const entry = self.nextDueEntry() orelse return null;
        return .{
            .action = entry.action,
            .entry = entry.*,
        };
    }

    pub fn usableWhileRefreshingEntries(
        self: *const IdentityStoredProfileTargetRefreshCadencePlan,
    ) []const IdentityStoredProfileTargetRefreshCadenceEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.refresh_now_count));
        const end = start + @as(usize, @intCast(self.usable_while_refreshing_count));
        return self.entries[start..end];
    }

    pub fn refreshSoonEntries(
        self: *const IdentityStoredProfileTargetRefreshCadencePlan,
    ) []const IdentityStoredProfileTargetRefreshCadenceEntry {
        const start = @as(
            usize,
            @intCast(self.verify_now_count + self.refresh_now_count + self.usable_while_refreshing_count),
        );
        const end = start + @as(usize, @intCast(self.refresh_soon_count));
        return self.entries[start..end];
    }
};

pub const IdentityStoredProfileTargetRefreshCadenceStep = struct {
    action: IdentityStoredProfileTargetRefreshCadenceAction,
    entry: IdentityStoredProfileTargetRefreshCadenceEntry,
};

pub const IdentityStoredProfileTargetRefreshBatchStorage = struct {
    matches: []IdentityProfileMatch,
    latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
    cadence_entries: []IdentityStoredProfileTargetRefreshCadenceEntry,
    cadence_groups: []IdentityStoredProfileTargetRefreshCadenceGroup,

    pub fn init(
        matches: []IdentityProfileMatch,
        latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
        cadence_entries: []IdentityStoredProfileTargetRefreshCadenceEntry,
        cadence_groups: []IdentityStoredProfileTargetRefreshCadenceGroup,
    ) IdentityStoredProfileTargetRefreshBatchStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .cadence_entries = cadence_entries,
            .cadence_groups = cadence_groups,
        };
    }
};

pub const IdentityStoredProfileTargetRefreshBatchRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    refresh_soon_age_seconds: u64,
    max_selected: usize,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileTargetRefreshBatchStorage,
};

pub const IdentityStoredProfileTargetRefreshBatchPlan = struct {
    entries: []const IdentityStoredProfileTargetRefreshCadenceEntry,
    selected_count: u32 = 0,
    deferred_count: u32 = 0,

    pub fn nextBatchEntry(
        self: *const IdentityStoredProfileTargetRefreshBatchPlan,
    ) ?*const IdentityStoredProfileTargetRefreshCadenceEntry {
        if (self.selected_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextBatchStep(
        self: *const IdentityStoredProfileTargetRefreshBatchPlan,
    ) ?IdentityStoredProfileTargetRefreshBatchStep {
        const entry = self.nextBatchEntry() orelse return null;
        return .{ .entry = entry.* };
    }

    pub fn selectedEntries(
        self: *const IdentityStoredProfileTargetRefreshBatchPlan,
    ) []const IdentityStoredProfileTargetRefreshCadenceEntry {
        return self.entries[0..@as(usize, @intCast(self.selected_count))];
    }

    pub fn deferredEntries(
        self: *const IdentityStoredProfileTargetRefreshBatchPlan,
    ) []const IdentityStoredProfileTargetRefreshCadenceEntry {
        const start: usize = @intCast(self.selected_count);
        return self.entries[start..];
    }
};

pub const IdentityStoredProfileTargetRefreshBatchStep = struct {
    entry: IdentityStoredProfileTargetRefreshCadenceEntry,
};

pub const IdentityStoredProfileTargetTurnPolicyAction = enum {
    verify_now,
    refresh_selected,
    use_cached,
    defer_refresh,
};

pub const IdentityStoredProfileTargetTurnPolicyEntry = struct {
    target: IdentityStoredProfileTarget,
    action: IdentityStoredProfileTargetTurnPolicyAction,
    latest: ?IdentityLatestStoredProfileFreshness = null,
};

pub const IdentityStoredProfileTargetTurnPolicyGroup = struct {
    action: IdentityStoredProfileTargetTurnPolicyAction,
    entries: []const IdentityStoredProfileTargetTurnPolicyEntry,
};

pub const IdentityStoredProfileTargetTurnPolicyStorage = struct {
    matches: []IdentityProfileMatch,
    latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
    policy_entries: []IdentityStoredProfileTargetPolicyEntry,
    policy_groups: []IdentityStoredProfileTargetPolicyGroup,
    cadence_entries: []IdentityStoredProfileTargetRefreshCadenceEntry,
    cadence_groups: []IdentityStoredProfileTargetRefreshCadenceGroup,
    entries: []IdentityStoredProfileTargetTurnPolicyEntry,
    groups: []IdentityStoredProfileTargetTurnPolicyGroup,

    pub fn init(
        matches: []IdentityProfileMatch,
        latest_entries: []IdentityStoredProfileTargetLatestFreshnessEntry,
        policy_entries: []IdentityStoredProfileTargetPolicyEntry,
        policy_groups: []IdentityStoredProfileTargetPolicyGroup,
        cadence_entries: []IdentityStoredProfileTargetRefreshCadenceEntry,
        cadence_groups: []IdentityStoredProfileTargetRefreshCadenceGroup,
        entries: []IdentityStoredProfileTargetTurnPolicyEntry,
        groups: []IdentityStoredProfileTargetTurnPolicyGroup,
    ) IdentityStoredProfileTargetTurnPolicyStorage {
        return .{
            .matches = matches,
            .latest_entries = latest_entries,
            .policy_entries = policy_entries,
            .policy_groups = policy_groups,
            .cadence_entries = cadence_entries,
            .cadence_groups = cadence_groups,
            .entries = entries,
            .groups = groups,
        };
    }
};

pub const IdentityStoredProfileTargetTurnPolicyRequest = struct {
    targets: []const IdentityStoredProfileTarget,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    refresh_soon_age_seconds: u64,
    max_selected: usize,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileTargetTurnPolicyStorage,
};

pub const IdentityStoredProfileTargetTurnPolicyPlan = struct {
    entries: []const IdentityStoredProfileTargetTurnPolicyEntry,
    groups: []const IdentityStoredProfileTargetTurnPolicyGroup,
    verify_now_count: u32 = 0,
    refresh_selected_count: u32 = 0,
    use_cached_count: u32 = 0,
    defer_refresh_count: u32 = 0,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextWorkEntry(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) ?*const IdentityStoredProfileTargetTurnPolicyEntry {
        const work_count = self.verify_now_count + self.refresh_selected_count;
        if (work_count == 0) return null;
        return &self.entries[0];
    }

    pub fn nextWorkStep(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) ?IdentityStoredProfileTargetTurnPolicyStep {
        const entry = self.nextWorkEntry() orelse return null;
        return .{
            .action = entry.action,
            .entry = entry.*,
        };
    }

    pub fn verifyNowEntries(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) []const IdentityStoredProfileTargetTurnPolicyEntry {
        return self.entries[0..@as(usize, @intCast(self.verify_now_count))];
    }

    pub fn refreshSelectedEntries(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) []const IdentityStoredProfileTargetTurnPolicyEntry {
        const start: usize = @intCast(self.verify_now_count);
        const end = start + @as(usize, @intCast(self.refresh_selected_count));
        return self.entries[start..end];
    }

    pub fn workEntries(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) []const IdentityStoredProfileTargetTurnPolicyEntry {
        const end =
            @as(usize, @intCast(self.verify_now_count + self.refresh_selected_count));
        return self.entries[0..end];
    }

    pub fn useCachedEntries(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) []const IdentityStoredProfileTargetTurnPolicyEntry {
        const start =
            @as(usize, @intCast(self.verify_now_count + self.refresh_selected_count));
        const end = start + @as(usize, @intCast(self.use_cached_count));
        return self.entries[start..end];
    }

    pub fn deferredEntries(
        self: *const IdentityStoredProfileTargetTurnPolicyPlan,
    ) []const IdentityStoredProfileTargetTurnPolicyEntry {
        const start = @as(
            usize,
            @intCast(self.verify_now_count + self.refresh_selected_count + self.use_cached_count),
        );
        return self.entries[start..];
    }
};

pub const IdentityStoredProfileTargetTurnPolicyStep = struct {
    action: IdentityStoredProfileTargetTurnPolicyAction,
    entry: IdentityStoredProfileTargetTurnPolicyEntry,
};

pub const IdentityStoredProfileTargetLatestFreshnessPlan = struct {
    entries: []const IdentityStoredProfileTargetLatestFreshnessEntry,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextEntry(
        self: *const IdentityStoredProfileTargetLatestFreshnessPlan,
    ) ?*const IdentityStoredProfileTargetLatestFreshnessEntry {
        for (self.entries) |*entry| {
            const latest = entry.latest orelse return entry;
            if (latest.freshness != .fresh) return entry;
        }
        return null;
    }

    pub fn nextStep(
        self: *const IdentityStoredProfileTargetLatestFreshnessPlan,
    ) ?IdentityStoredProfileTargetLatestFreshnessStep {
        const entry = self.nextEntry() orelse return null;
        return .{ .entry = entry.* };
    }
};

pub const IdentityStoredProfileTargetLatestFreshnessStep = struct {
    entry: IdentityStoredProfileTargetLatestFreshnessEntry,
};

pub const IdentityStoredProfileRuntimeAction = enum {
    verify_now,
    refresh_existing,
    use_preferred,
    use_stale_and_refresh,
};

pub const IdentityStoredProfileRuntimeStorage = struct {
    matches: []IdentityProfileMatch,
    entries: []IdentityStoredProfileDiscoveryFreshnessEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        entries: []IdentityStoredProfileDiscoveryFreshnessEntry,
    ) IdentityStoredProfileRuntimeStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const IdentityStoredProfileRuntimeRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: IdentityStoredProfileFallbackPolicy = .allow_stale_latest,
    storage: IdentityStoredProfileRuntimeStorage,
};

pub const IdentityStoredProfileRuntimePlan = struct {
    action: IdentityStoredProfileRuntimeAction,
    entries: []const IdentityStoredProfileDiscoveryFreshnessEntry,
    preferred_index: ?u32 = null,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,

    pub fn preferredEntry(
        self: *const IdentityStoredProfileRuntimePlan,
    ) ?*const IdentityStoredProfileDiscoveryFreshnessEntry {
        const index = self.preferred_index orelse return null;
        const usize_index: usize = @intCast(index);
        if (usize_index >= self.entries.len) return null;
        return &self.entries[usize_index];
    }

    pub fn nextEntry(
        self: *const IdentityStoredProfileRuntimePlan,
    ) ?*const IdentityStoredProfileDiscoveryFreshnessEntry {
        return switch (self.action) {
            .verify_now => null,
            .refresh_existing, .use_preferred, .use_stale_and_refresh => self.preferredEntry(),
        };
    }

    pub fn nextStep(self: *const IdentityStoredProfileRuntimePlan) IdentityStoredProfileRuntimeStep {
        return .{
            .action = self.action,
            .entry = if (self.nextEntry()) |entry| entry.* else null,
        };
    }
};

pub const IdentityStoredProfileRuntimeStep = struct {
    action: IdentityStoredProfileRuntimeAction,
    entry: ?IdentityStoredProfileDiscoveryFreshnessEntry = null,
};

pub const IdentityStoredProfileRefreshEntry = struct {
    entry: IdentityStoredProfileDiscoveryFreshnessEntry,

    pub fn matchedClaim(self: *const IdentityStoredProfileRefreshEntry) *const IdentityStoredClaim {
        return self.entry.matchedClaim();
    }
};

pub const IdentityStoredProfileRefreshStorage = struct {
    matches: []IdentityProfileMatch,
    freshness_entries: []IdentityStoredProfileDiscoveryFreshnessEntry,
    entries: []IdentityStoredProfileRefreshEntry,

    pub fn init(
        matches: []IdentityProfileMatch,
        freshness_entries: []IdentityStoredProfileDiscoveryFreshnessEntry,
        entries: []IdentityStoredProfileRefreshEntry,
    ) IdentityStoredProfileRefreshStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .entries = entries,
        };
    }
};

pub const IdentityStoredProfileRefreshRequest = struct {
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: IdentityStoredProfileRefreshStorage,
};

pub const IdentityStoredProfileRefreshPlan = struct {
    entries: []const IdentityStoredProfileRefreshEntry,

    pub fn nextEntry(
        self: *const IdentityStoredProfileRefreshPlan,
    ) ?*const IdentityStoredProfileRefreshEntry {
        return self.newestEntry();
    }

    pub fn newestEntry(
        self: *const IdentityStoredProfileRefreshPlan,
    ) ?*const IdentityStoredProfileRefreshEntry {
        if (self.entries.len == 0) return null;
        return &self.entries[0];
    }

    pub fn nextStep(
        self: *const IdentityStoredProfileRefreshPlan,
    ) ?IdentityStoredProfileRefreshStep {
        const entry = self.nextEntry() orelse return null;
        return .{ .entry = entry.* };
    }
};

pub const IdentityStoredProfileRefreshStep = struct {
    entry: IdentityStoredProfileRefreshEntry,
};

pub const IdentityProfileStoreVTable = struct {
    put_profile_summary: *const fn (
        ctx: *anyopaque,
        pubkey: *const [32]u8,
        event_created_at: u64,
        summary: *const IdentityProfileVerificationSummary,
    ) IdentityProfileStoreError!IdentityProfileStorePutOutcome,
    get_profile: *const fn (
        ctx: *anyopaque,
        pubkey: *const [32]u8,
    ) IdentityProfileStoreError!?IdentityProfileRecord,
    find_profiles: *const fn (
        ctx: *anyopaque,
        provider: noztr.nip39_external_identities.IdentityProvider,
        identity: []const u8,
        out: []IdentityProfileMatch,
    ) IdentityProfileStoreError!usize,
};

pub const IdentityProfileStore = struct {
    ctx: *anyopaque,
    vtable: *const IdentityProfileStoreVTable,

    pub fn putProfileSummary(
        self: IdentityProfileStore,
        pubkey: *const [32]u8,
        event_created_at: u64,
        summary: *const IdentityProfileVerificationSummary,
    ) IdentityProfileStoreError!IdentityProfileStorePutOutcome {
        return self.vtable.put_profile_summary(self.ctx, pubkey, event_created_at, summary);
    }

    pub fn getProfile(
        self: IdentityProfileStore,
        pubkey: *const [32]u8,
    ) IdentityProfileStoreError!?IdentityProfileRecord {
        return self.vtable.get_profile(self.ctx, pubkey);
    }

    pub fn findProfiles(
        self: IdentityProfileStore,
        provider: noztr.nip39_external_identities.IdentityProvider,
        identity: []const u8,
        out: []IdentityProfileMatch,
    ) IdentityProfileStoreError![]const IdentityProfileMatch {
        const count = try self.vtable.find_profiles(self.ctx, provider, identity, out);
        return out[0..count];
    }
};

pub const MemoryIdentityProfileStore = struct {
    records: []IdentityProfileRecord,
    count: usize = 0,

    pub fn init(records: []IdentityProfileRecord) MemoryIdentityProfileStore {
        return .{ .records = records };
    }

    pub fn asStore(self: *MemoryIdentityProfileStore) IdentityProfileStore {
        return .{
            .ctx = self,
            .vtable = &profile_store_vtable,
        };
    }

    pub fn putProfileSummary(
        self: *MemoryIdentityProfileStore,
        pubkey: *const [32]u8,
        event_created_at: u64,
        summary: *const IdentityProfileVerificationSummary,
    ) IdentityProfileStoreError!IdentityProfileStorePutOutcome {
        const existing = self.findIndex(pubkey);
        if (existing) |index| {
            if (event_created_at < self.records[index].created_at) return .ignored_stale;
            try writeProfileRecord(&self.records[index], pubkey, event_created_at, summary);
            return .stored;
        }
        if (self.count == self.records.len) return error.StoreFull;
        try writeProfileRecord(&self.records[self.count], pubkey, event_created_at, summary);
        self.count += 1;
        return .stored;
    }

    pub fn getProfile(
        self: *MemoryIdentityProfileStore,
        pubkey: *const [32]u8,
    ) IdentityProfileStoreError!?IdentityProfileRecord {
        const index = self.findIndex(pubkey) orelse return null;
        return self.records[index];
    }

    pub fn findProfiles(
        self: *MemoryIdentityProfileStore,
        provider: noztr.nip39_external_identities.IdentityProvider,
        identity: []const u8,
        out: []IdentityProfileMatch,
    ) IdentityProfileStoreError![]const IdentityProfileMatch {
        if (identity.len > identity_profile_store_identity_max_bytes) return error.IdentityTooLong;

        var count: usize = 0;
        for (self.records[0..self.count]) |*record| {
            if (!record.occupied) continue;
            if (!recordContainsIdentity(record, provider, identity)) continue;
            if (count == out.len) break;
            out[count] = .{
                .pubkey = record.pubkey,
                .created_at = record.created_at,
            };
            count += 1;
        }
        return out[0..count];
    }

    fn findIndex(self: *const MemoryIdentityProfileStore, pubkey: *const [32]u8) ?usize {
        for (self.records[0..self.count], 0..) |*record, index| {
            if (!record.occupied) continue;
            if (std.mem.eql(u8, record.pubkey[0..], pubkey[0..])) return index;
        }
        return null;
    }
};

pub const IdentityVerificationOutcome = union(enum) {
    verified: IdentityVerificationMatch,
    mismatch: IdentityVerificationMatch,
    fetch_failed: IdentityVerificationFetchFailure,
};

pub const GithubIdentityDetails = struct {
    username: []const u8,
    gist_id: []const u8,
};

pub const TwitterIdentityDetails = struct {
    handle: []const u8,
    status_id: []const u8,
};

pub const MastodonIdentityDetails = struct {
    host: []const u8,
    handle: []const u8,
    status_id: []const u8,
};

pub const TelegramIdentityDetails = struct {
    user_id: []const u8,
    channel: []const u8,
    message_id: []const u8,
};

pub const IdentityProviderDetails = union(enum) {
    github: GithubIdentityDetails,
    twitter: TwitterIdentityDetails,
    mastodon: MastodonIdentityDetails,
    telegram: TelegramIdentityDetails,
};

pub const IdentityClaimVerificationOutcome = union(enum) {
    verified: IdentityVerificationMatch,
    mismatch: IdentityVerificationMatch,
    fetch_failed: IdentityVerificationFetchFailure,
    unsupported: IdentityVerificationMatch,
};

pub const IdentityClaimVerification = struct {
    claim: noztr.nip39_external_identities.IdentityClaim,
    outcome: IdentityClaimVerificationOutcome,

    pub fn providerDetails(
        self: *const IdentityClaimVerification,
    ) noztr.nip39_external_identities.Nip39Error!IdentityProviderDetails {
        return providerDetailsForClaim(&self.claim);
    }
};

pub const IdentityProfileVerificationStorage = struct {
    claims: []noztr.nip39_external_identities.IdentityClaim,
    verification: []IdentityVerificationStorage,
    results: []IdentityClaimVerification,

    pub fn init(
        claims: []noztr.nip39_external_identities.IdentityClaim,
        verification: []IdentityVerificationStorage,
        results: []IdentityClaimVerification,
    ) IdentityProfileVerificationStorage {
        return .{
            .claims = claims,
            .verification = verification,
            .results = results,
        };
    }
};

pub const IdentityProfileVerificationRequest = struct {
    event: *const noztr.nip01_event.Event,
    pubkey: *const [32]u8,
    storage: IdentityProfileVerificationStorage,
};

pub const IdentityProfileVerificationSummary = struct {
    claims: []const IdentityClaimVerification,
    verified_count: usize = 0,
    mismatch_count: usize = 0,
    fetch_failed_count: usize = 0,
    unsupported_count: usize = 0,
    cache_hit_count: usize = 0,
    network_fetch_count: usize = 0,

    pub fn verifiedClaims(
        self: *const IdentityProfileVerificationSummary,
        out: []*const IdentityClaimVerification,
    ) []const *const IdentityClaimVerification {
        var count: usize = 0;
        for (self.claims) |*claim| {
            if (claim.outcome != .verified) continue;
            if (count == out.len) break;
            out[count] = claim;
            count += 1;
        }
        return out[0..count];
    }
};

pub const IdentityRememberedProfileVerification = struct {
    summary: IdentityProfileVerificationSummary,
    store_outcome: IdentityProfileStorePutOutcome,
};

pub const IdentityRememberedProfileVerificationError =
    IdentityVerifierError || IdentityProfileStoreError;

pub const IdentityStoredProfileDiscoveryError = IdentityProfileStoreError || error{BufferTooSmall};

pub const IdentityVerifier = struct {
    fn hydrateStoredProfileEntry(
        store: IdentityProfileStore,
        match: IdentityProfileMatch,
        provider: noztr.nip39_external_identities.IdentityProvider,
        identity: []const u8,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileDiscoveryEntry {
        const profile = (try store.getProfile(&match.pubkey)) orelse return error.InconsistentStoreData;
        const matched_claim_index = findMatchedStoredClaimIndex(
            &profile,
            provider,
            identity,
        ) orelse return error.InconsistentStoreData;
        return .{
            .match = match,
            .profile = profile,
            .matched_claim_index = matched_claim_index,
        };
    }

    pub fn verify(
        http_client: transport.HttpClient,
        request: IdentityVerificationRequest,
    ) IdentityVerifierError!IdentityVerificationOutcome {
        const verification = try buildVerificationMatch(request.claim, request.pubkey, request.storage);
        if (request.claim.provider == .telegram) return error.UnsupportedProviderVerification;

        const body = http_client.get(
            .{ .url = verification.proof_url },
            request.storage.body_buffer,
        ) catch |err| {
            return .{
                .fetch_failed = .{
                    .verification = verification,
                    .cause = err,
                },
            };
        };

        if (std.mem.indexOf(u8, body, verification.expected_text) != null) {
            return .{ .verified = verification };
        }
        return .{ .mismatch = verification };
    }

    pub fn verifyProfile(
        http_client: transport.HttpClient,
        request: IdentityProfileVerificationRequest,
    ) IdentityVerifierError!IdentityProfileVerificationSummary {
        const claim_count = try noztr.nip39_external_identities.identity_claims_extract(
            request.event,
            request.storage.claims,
        );
        if (claim_count > request.storage.verification.len) return error.BufferTooSmall;
        if (claim_count > request.storage.results.len) return error.BufferTooSmall;

        var summary = IdentityProfileVerificationSummary{
            .claims = request.storage.results[0..claim_count],
        };
        for (request.storage.claims[0..claim_count], 0..) |*claim, index| {
            const outcome = try verifyClaimForProfile(
                http_client,
                claim,
                request.pubkey,
                request.storage.verification[index],
            );
            request.storage.results[index] = .{
                .claim = claim.*,
                .outcome = outcome,
            };
            switch (outcome) {
                .verified => summary.verified_count += 1,
                .mismatch => summary.mismatch_count += 1,
                .fetch_failed => summary.fetch_failed_count += 1,
                .unsupported => summary.unsupported_count += 1,
            }
        }
        return summary;
    }

    pub fn verifyProfileCached(
        http_client: transport.HttpClient,
        cache: IdentityVerificationCache,
        request: IdentityProfileVerificationRequest,
    ) IdentityVerifierError!IdentityProfileVerificationSummary {
        const claim_count = try noztr.nip39_external_identities.identity_claims_extract(
            request.event,
            request.storage.claims,
        );
        if (claim_count > request.storage.verification.len) return error.BufferTooSmall;
        if (claim_count > request.storage.results.len) return error.BufferTooSmall;

        var summary = IdentityProfileVerificationSummary{
            .claims = request.storage.results[0..claim_count],
        };
        for (request.storage.claims[0..claim_count], 0..) |*claim, index| {
            const verification = try verifyClaimForProfileCached(
                http_client,
                cache,
                claim,
                request.pubkey,
                request.storage.verification[index],
            );
            request.storage.results[index] = .{
                .claim = claim.*,
                .outcome = verification.outcome,
            };
            switch (verification.outcome) {
                .verified => summary.verified_count += 1,
                .mismatch => summary.mismatch_count += 1,
                .fetch_failed => summary.fetch_failed_count += 1,
                .unsupported => summary.unsupported_count += 1,
            }
            switch (verification.source) {
                .cache => summary.cache_hit_count += 1,
                .network => summary.network_fetch_count += 1,
                .none => {},
            }
        }
        return summary;
    }

    pub fn verifyProfileCachedAndRemember(
        http_client: transport.HttpClient,
        cache: IdentityVerificationCache,
        store: IdentityProfileStore,
        request: IdentityProfileVerificationRequest,
    ) IdentityRememberedProfileVerificationError!IdentityRememberedProfileVerification {
        const summary = try verifyProfileCached(http_client, cache, request);
        const store_outcome = try rememberProfileSummary(
            store,
            request.pubkey,
            request.event.created_at,
            &summary,
        );
        return .{
            .summary = summary,
            .store_outcome = store_outcome,
        };
    }

    pub fn rememberProfileSummary(
        store: IdentityProfileStore,
        pubkey: *const [32]u8,
        event_created_at: u64,
        summary: *const IdentityProfileVerificationSummary,
    ) IdentityProfileStoreError!IdentityProfileStorePutOutcome {
        return store.putProfileSummary(pubkey, event_created_at, summary);
    }

    pub fn getStoredProfile(
        store: IdentityProfileStore,
        pubkey: *const [32]u8,
    ) IdentityProfileStoreError!?IdentityProfileRecord {
        return store.getProfile(pubkey);
    }

    pub fn discoverStoredProfiles(
        store: IdentityProfileStore,
        request: IdentityProfileDiscoveryRequest,
    ) IdentityProfileStoreError![]const IdentityProfileMatch {
        return store.findProfiles(request.provider, request.identity, request.results);
    }

    pub fn discoverStoredProfileEntriesForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetDiscoveryRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityStoredProfileTargetDiscoveryGroup {
        if (request.targets.len > request.storage.groups.len) return error.BufferTooSmall;

        var total_entries: usize = 0;
        for (request.targets, 0..) |target, index| {
            const matches = try store.findProfiles(
                target.provider,
                target.identity,
                request.storage.matches,
            );
            if (total_entries + matches.len > request.storage.entries.len) return error.BufferTooSmall;

            const start = total_entries;
            for (matches, 0..) |match, match_index| {
                request.storage.entries[start + match_index] = try hydrateStoredProfileEntry(
                    store,
                    match,
                    target.provider,
                    target.identity,
                );
            }
            total_entries += matches.len;
            request.storage.groups[index] = .{
                .target = target,
                .entries = request.storage.entries[start..total_entries],
            };
        }

        return request.storage.groups[0..request.targets.len];
    }

    pub fn discoverStoredProfileEntries(
        store: IdentityProfileStore,
        request: IdentityStoredProfileDiscoveryRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityStoredProfileDiscoveryEntry {
        const matches = try store.findProfiles(
            request.provider,
            request.identity,
            request.storage.matches,
        );
        if (matches.len > request.storage.entries.len) return error.BufferTooSmall;

        for (matches, 0..) |match, index| {
            request.storage.entries[index] = try hydrateStoredProfileEntry(
                store,
                match,
                request.provider,
                request.identity,
            );
        }
        return request.storage.entries[0..matches.len];
    }

    pub fn discoverStoredProfileEntriesWithFreshnessForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetDiscoveryFreshnessRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityStoredProfileTargetDiscoveryFreshnessGroup {
        if (request.targets.len > request.storage.groups.len) return error.BufferTooSmall;

        var total_entries: usize = 0;
        for (request.targets, 0..) |target, index| {
            const matches = try store.findProfiles(
                target.provider,
                target.identity,
                request.storage.matches,
            );
            if (total_entries + matches.len > request.storage.entries.len) return error.BufferTooSmall;

            const start = total_entries;
            for (matches, 0..) |match, match_index| {
                const entry = try hydrateStoredProfileEntry(
                    store,
                    match,
                    target.provider,
                    target.identity,
                );
                const age_seconds = if (request.now_unix_seconds > match.created_at)
                    request.now_unix_seconds - match.created_at
                else
                    0;
                request.storage.entries[start + match_index] = .{
                    .entry = entry,
                    .freshness = if (age_seconds <= request.max_age_seconds) .fresh else .stale,
                    .age_seconds = age_seconds,
                };
            }
            total_entries += matches.len;
            request.storage.groups[index] = .{
                .target = target,
                .entries = request.storage.entries[start..total_entries],
            };
        }

        return request.storage.groups[0..request.targets.len];
    }

    pub fn getLatestStoredProfile(
        store: IdentityProfileStore,
        request: IdentityLatestStoredProfileRequest,
    ) IdentityStoredProfileDiscoveryError!?IdentityStoredProfileDiscoveryEntry {
        const matches = try store.findProfiles(request.provider, request.identity, request.matches);
        if (matches.len == 0) return null;

        var latest = matches[0];
        for (matches[1..]) |match| {
            if (match.created_at > latest.created_at) latest = match;
        }

        return try hydrateStoredProfileEntry(
            store,
            latest,
            request.provider,
            request.identity,
        );
    }

    pub fn getLatestStoredProfileFreshness(
        store: IdentityProfileStore,
        request: IdentityLatestStoredProfileFreshnessRequest,
    ) IdentityStoredProfileDiscoveryError!?IdentityLatestStoredProfileFreshness {
        const latest = (try getLatestStoredProfile(
            store,
            .{
                .provider = request.provider,
                .identity = request.identity,
                .matches = request.matches,
            },
        )) orelse return null;
        const age_seconds = if (request.now_unix_seconds > latest.match.created_at)
            request.now_unix_seconds - latest.match.created_at
        else
            0;
        return .{
            .latest = latest,
            .freshness = if (age_seconds <= request.max_age_seconds) .fresh else .stale,
            .age_seconds = age_seconds,
        };
    }

    pub fn getLatestStoredProfilesForTargets(
        store: IdentityProfileStore,
        request: IdentityLatestStoredProfileTargetRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityLatestStoredProfileTargetEntry {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;

        for (request.targets, 0..) |target, index| {
            request.storage.entries[index] = .{
                .target = target,
                .latest = try getLatestStoredProfile(
                    store,
                    .{
                        .provider = target.provider,
                        .identity = target.identity,
                        .matches = request.storage.matches,
                    },
                ),
            };
        }

        return request.storage.entries[0..request.targets.len];
    }

    pub fn discoverLatestStoredProfileFreshnessForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetLatestFreshnessRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityStoredProfileTargetLatestFreshnessEntry {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;

        for (request.targets, 0..) |target, index| {
            request.storage.entries[index] = .{
                .target = target,
                .latest = try getLatestStoredProfileFreshness(
                    store,
                    .{
                        .provider = target.provider,
                        .identity = target.identity,
                        .now_unix_seconds = request.now_unix_seconds,
                        .max_age_seconds = request.max_age_seconds,
                        .matches = request.storage.matches,
                    },
                ),
            };
        }

        return request.storage.entries[0..request.targets.len];
    }

    pub fn inspectLatestStoredProfileFreshnessForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetLatestFreshnessRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetLatestFreshnessPlan {
        const entries = try discoverLatestStoredProfileFreshnessForTargets(store, request);

        var plan: IdentityStoredProfileTargetLatestFreshnessPlan = .{
            .entries = entries,
        };
        for (entries) |entry| {
            const latest = entry.latest orelse {
                plan.missing_count += 1;
                continue;
            };
            switch (latest.freshness) {
                .fresh => plan.fresh_count += 1,
                .stale => plan.stale_count += 1,
            }
        }
        return plan;
    }

    pub fn getPreferredStoredProfileForTargets(
        store: IdentityProfileStore,
        request: IdentityPreferredStoredProfileTargetRequest,
    ) IdentityStoredProfileDiscoveryError!?IdentityPreferredStoredProfileTarget {
        const entries = try discoverLatestStoredProfileFreshnessForTargets(
            store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = request.storage,
            },
        );

        var best_fresh: ?IdentityPreferredStoredProfileTarget = null;
        var best_stale: ?IdentityPreferredStoredProfileTarget = null;
        for (entries) |entry| {
            const latest = entry.latest orelse continue;
            const candidate: IdentityPreferredStoredProfileTarget = .{
                .target = entry.target,
                .latest = latest,
            };
            switch (latest.freshness) {
                .fresh => {
                    if (best_fresh == null or
                        latest.latest.match.created_at > best_fresh.?.latest.latest.match.created_at)
                    {
                        best_fresh = candidate;
                    }
                },
                .stale => {
                    if (best_stale == null or
                        latest.latest.match.created_at > best_stale.?.latest.latest.match.created_at)
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

    pub fn planStoredProfileRefreshForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetRefreshRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetRefreshPlan {
        const freshness_entries = try discoverLatestStoredProfileFreshnessForTargets(
            store,
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

    pub fn inspectStoredProfileRuntimeForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetRuntimeRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetRuntimePlan {
        const entries = try discoverLatestStoredProfileFreshnessForTargets(
            store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = request.storage,
            },
        );

        var fresh_count: u32 = 0;
        var stale_count: u32 = 0;
        var missing_count: u32 = 0;
        var first_missing_index: ?u32 = null;
        var best_fresh_index: ?u32 = null;
        var best_stale_index: ?u32 = null;

        for (entries, 0..) |entry, index| {
            const entry_index: u32 = @intCast(index);
            const latest = entry.latest orelse {
                missing_count += 1;
                if (first_missing_index == null) first_missing_index = entry_index;
                continue;
            };
            switch (latest.freshness) {
                .fresh => {
                    fresh_count += 1;
                    if (best_fresh_index == null or
                        latest.latest.match.created_at >
                            entries[@intCast(best_fresh_index.?)].latest.?.latest.match.created_at)
                    {
                        best_fresh_index = entry_index;
                    }
                },
                .stale => {
                    stale_count += 1;
                    if (best_stale_index == null or
                        latest.latest.match.created_at >
                            entries[@intCast(best_stale_index.?)].latest.?.latest.match.created_at)
                    {
                        best_stale_index = entry_index;
                    }
                },
            }
        }

        if (first_missing_index) |selected_index| {
            return .{
                .action = .verify_now,
                .entries = entries,
                .selected_index = selected_index,
                .fresh_count = fresh_count,
                .stale_count = stale_count,
                .missing_count = missing_count,
            };
        }
        if (best_fresh_index) |selected_index| {
            return .{
                .action = .use_preferred,
                .entries = entries,
                .selected_index = selected_index,
                .fresh_count = fresh_count,
                .stale_count = stale_count,
                .missing_count = missing_count,
            };
        }
        if (best_stale_index) |selected_index| {
            return .{
                .action = switch (request.fallback_policy) {
                    .require_fresh => .refresh_existing,
                    .allow_stale_latest => .use_stale_and_refresh,
                },
                .entries = entries,
                .selected_index = selected_index,
                .fresh_count = fresh_count,
                .stale_count = stale_count,
                .missing_count = missing_count,
            };
        }
        return .{
            .action = .verify_now,
            .entries = entries,
            .fresh_count = 0,
            .stale_count = 0,
            .missing_count = 0,
        };
    }

    pub fn inspectStoredProfilePolicyForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetPolicyRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetPolicyPlan {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;
        if (request.storage.groups.len < 4) return error.BufferTooSmall;

        const latest_entries = try discoverLatestStoredProfileFreshnessForTargets(
            store,
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
            const action: IdentityStoredProfileTargetRuntimeAction = if (entry.latest) |latest|
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
            const action: IdentityStoredProfileTargetRuntimeAction = if (entry.latest) |latest|
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

    pub fn inspectStoredProfileRefreshCadenceForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetRefreshCadenceRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetRefreshCadencePlan {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;
        if (request.storage.groups.len < 5) return error.BufferTooSmall;

        const latest_entries = try discoverLatestStoredProfileFreshnessForTargets(
            store,
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
            const action: IdentityStoredProfileTargetRefreshCadenceAction = if (entry.latest) |latest|
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
            const action: IdentityStoredProfileTargetRefreshCadenceAction = if (entry.latest) |latest|
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

    pub fn inspectStoredProfileRefreshBatchForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetRefreshBatchRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetRefreshBatchPlan {
        const cadence = try inspectStoredProfileRefreshCadenceForTargets(
            store,
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

    pub fn inspectStoredProfileTurnPolicyForTargets(
        store: IdentityProfileStore,
        request: IdentityStoredProfileTargetTurnPolicyRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileTargetTurnPolicyPlan {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;
        if (request.storage.groups.len < 4) return error.BufferTooSmall;

        const policy = try inspectStoredProfilePolicyForTargets(
            store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .fallback_policy = request.fallback_policy,
                .storage = .init(
                    request.storage.matches,
                    request.storage.latest_entries,
                    request.storage.policy_entries,
                    request.storage.policy_groups,
                ),
            },
        );
        const batch = try inspectStoredProfileRefreshBatchForTargets(
            store,
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

        for (policy.entries) |policy_entry| {
            const action: IdentityStoredProfileTargetTurnPolicyAction =
                if (policy_entry.action == .verify_now)
                    .verify_now
                else if (containsTarget(batch.selectedEntries(), policy_entry.target))
                    .refresh_selected
                else if (containsTarget(batch.deferredEntries(), policy_entry.target))
                    .defer_refresh
                else
                    .use_cached;

            switch (action) {
                .verify_now => verify_now_count += 1,
                .refresh_selected => refresh_selected_count += 1,
                .use_cached => use_cached_count += 1,
                .defer_refresh => defer_refresh_count += 1,
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

        for (policy.entries) |policy_entry| {
            const action: IdentityStoredProfileTargetTurnPolicyAction =
                if (policy_entry.action == .verify_now)
                    .verify_now
                else if (containsTarget(batch.selectedEntries(), policy_entry.target))
                    .refresh_selected
                else if (containsTarget(batch.deferredEntries(), policy_entry.target))
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
                .target = policy_entry.target,
                .action = action,
                .latest = policy_entry.latest,
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
            .fresh_count = policy.fresh_count,
            .stale_count = policy.stale_count,
            .missing_count = policy.missing_count,
        };
    }

    pub fn discoverStoredProfileEntriesWithFreshness(
        store: IdentityProfileStore,
        request: IdentityStoredProfileDiscoveryFreshnessRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityStoredProfileDiscoveryFreshnessEntry {
        const matches = try store.findProfiles(
            request.provider,
            request.identity,
            request.storage.matches,
        );
        if (matches.len > request.storage.entries.len) return error.BufferTooSmall;

        for (matches, 0..) |match, index| {
            const entry = try hydrateStoredProfileEntry(
                store,
                match,
                request.provider,
                request.identity,
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

    pub fn getPreferredStoredProfile(
        store: IdentityProfileStore,
        request: IdentityPreferredStoredProfileRequest,
    ) IdentityStoredProfileDiscoveryError!?IdentityPreferredStoredProfile {
        const matches = try store.findProfiles(request.provider, request.identity, request.matches);
        if (matches.len == 0) return null;

        var latest_stale: ?IdentityPreferredStoredProfile = null;
        var best_fresh: ?IdentityPreferredStoredProfile = null;
        for (matches) |match| {
            const entry = try hydrateStoredProfileEntry(
                store,
                match,
                request.provider,
                request.identity,
            );
            const age_seconds = if (request.now_unix_seconds > match.created_at)
                request.now_unix_seconds - match.created_at
            else
                0;
            const candidate: IdentityPreferredStoredProfile = .{
                .entry = entry,
                .freshness = if (age_seconds <= request.max_age_seconds) .fresh else .stale,
                .age_seconds = age_seconds,
            };
            switch (candidate.freshness) {
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
        return switch (request.fallback_policy) {
            .require_fresh => null,
            .allow_stale_latest => latest_stale,
        };
    }

    pub fn getPreferredStoredProfilesForTargets(
        store: IdentityProfileStore,
        request: IdentityPreferredStoredProfileTargetSelectionRequest,
    ) IdentityStoredProfileDiscoveryError![]const IdentityPreferredStoredProfileTargetEntry {
        if (request.targets.len > request.storage.entries.len) return error.BufferTooSmall;

        for (request.targets, 0..) |target, index| {
            request.storage.entries[index] = .{
                .target = target,
                .preferred = try getPreferredStoredProfile(
                    store,
                    .{
                        .provider = target.provider,
                        .identity = target.identity,
                        .now_unix_seconds = request.now_unix_seconds,
                        .max_age_seconds = request.max_age_seconds,
                        .matches = request.storage.matches,
                        .fallback_policy = request.fallback_policy,
                    },
                ),
            };
        }

        return request.storage.entries[0..request.targets.len];
    }

    pub fn inspectStoredProfileRuntime(
        store: IdentityProfileStore,
        request: IdentityStoredProfileRuntimeRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileRuntimePlan {
        const entries = try discoverStoredProfileEntriesWithFreshness(
            store,
            .{
                .provider = request.provider,
                .identity = request.identity,
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

    pub fn planStoredProfileRefresh(
        store: IdentityProfileStore,
        request: IdentityStoredProfileRefreshRequest,
    ) IdentityStoredProfileDiscoveryError!IdentityStoredProfileRefreshPlan {
        const freshness_entries = try discoverStoredProfileEntriesWithFreshness(
            store,
            .{
                .provider = request.provider,
                .identity = request.identity,
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
};

fn containsTarget(
    entries: []const IdentityStoredProfileTargetRefreshCadenceEntry,
    target: IdentityStoredProfileTarget,
) bool {
    for (entries) |entry| {
        if (entry.target.provider != target.provider) continue;
        if (std.mem.eql(u8, entry.target.identity, target.identity)) return true;
    }
    return false;
}

fn buildVerificationMatch(
    claim: *const noztr.nip39_external_identities.IdentityClaim,
    pubkey: *const [32]u8,
    storage: IdentityVerificationStorage,
) IdentityVerifierError!IdentityVerificationMatch {
    const proof_url = try noztr.nip39_external_identities.identity_claim_build_proof_url(
        storage.url_buffer,
        claim,
    );
    const expected_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        storage.expected_text_buffer,
        claim,
        pubkey,
    );
    return .{
        .proof_url = proof_url,
        .expected_text = expected_text,
    };
}

fn verifyClaimForProfile(
    http_client: transport.HttpClient,
    claim: *const noztr.nip39_external_identities.IdentityClaim,
    pubkey: *const [32]u8,
    storage: IdentityVerificationStorage,
) IdentityVerifierError!IdentityClaimVerificationOutcome {
    const verification = try buildVerificationMatch(claim, pubkey, storage);
    if (claim.provider == .telegram) {
        return .{ .unsupported = verification };
    }
    const body = http_client.get(
        .{ .url = verification.proof_url },
        storage.body_buffer,
    ) catch |err| {
        return .{
            .fetch_failed = .{
                .verification = verification,
                .cause = err,
            },
        };
    };
    if (std.mem.indexOf(u8, body, verification.expected_text) != null) {
        return .{ .verified = verification };
    }
    return .{ .mismatch = verification };
}

const VerificationSource = enum {
    none,
    cache,
    network,
};

const CachedClaimVerification = struct {
    outcome: IdentityClaimVerificationOutcome,
    source: VerificationSource,
};

fn verifyClaimForProfileCached(
    http_client: transport.HttpClient,
    cache: IdentityVerificationCache,
    claim: *const noztr.nip39_external_identities.IdentityClaim,
    pubkey: *const [32]u8,
    storage: IdentityVerificationStorage,
) IdentityVerifierError!CachedClaimVerification {
    const verification = try buildVerificationMatch(claim, pubkey, storage);
    if (claim.provider == .telegram) {
        return .{
            .outcome = .{ .unsupported = verification },
            .source = .none,
        };
    }
    if (lookupCachedVerification(cache, &verification)) |cached| {
        return .{
            .outcome = cachedVerificationToOutcome(cached, verification),
            .source = .cache,
        };
    }

    const body = http_client.get(
        .{ .url = verification.proof_url },
        storage.body_buffer,
    ) catch |err| {
        return .{
            .outcome = .{
                .fetch_failed = .{
                    .verification = verification,
                    .cause = err,
                },
            },
            .source = .none,
        };
    };
    const result: IdentityVerificationCacheResult = if (std.mem.indexOf(u8, body, verification.expected_text) != null)
        .verified
    else
        .mismatch;
    rememberCachedVerification(cache, &verification, result);
    return .{
        .outcome = cachedVerificationToOutcome(result, verification),
        .source = .network,
    };
}

fn cachedVerificationToOutcome(
    result: IdentityVerificationCacheResult,
    verification: IdentityVerificationMatch,
) IdentityClaimVerificationOutcome {
    return switch (result) {
        .verified => .{ .verified = verification },
        .mismatch => .{ .mismatch = verification },
        .unsupported => .{ .unsupported = verification },
    };
}

fn lookupCachedVerification(
    cache: IdentityVerificationCache,
    verification: *const IdentityVerificationMatch,
) ?IdentityVerificationCacheResult {
    return cache.getCached(verification) catch null;
}

fn rememberCachedVerification(
    cache: IdentityVerificationCache,
    verification: *const IdentityVerificationMatch,
    result: IdentityVerificationCacheResult,
) void {
    cache.putCached(verification, result) catch {};
}

fn writeProfileRecord(
    record: *IdentityProfileRecord,
    pubkey: *const [32]u8,
    event_created_at: u64,
    summary: *const IdentityProfileVerificationSummary,
) IdentityProfileStoreError!void {
    const verified_claim_count = countVerifiedClaims(summary);
    if (verified_claim_count > identity_profile_store_verified_claims_max) {
        return error.TooManyVerifiedClaims;
    }

    record.* = .{};
    record.pubkey = pubkey.*;
    record.created_at = event_created_at;
    record.verified_count = @intCast(summary.verified_count);
    record.mismatch_count = @intCast(summary.mismatch_count);
    record.fetch_failed_count = @intCast(summary.fetch_failed_count);
    record.unsupported_count = @intCast(summary.unsupported_count);
    record.occupied = true;

    var cursor: u8 = 0;
    for (summary.claims) |*claim| {
        if (claim.outcome != .verified) continue;
        try copyStoredClaim(&record.verified_claims[cursor], &claim.claim);
        cursor += 1;
    }
    record.verified_claim_count = cursor;
}

fn countVerifiedClaims(summary: *const IdentityProfileVerificationSummary) u16 {
    var count: u16 = 0;
    for (summary.claims) |*claim| {
        if (claim.outcome == .verified) count += 1;
    }
    return count;
}

fn copyStoredClaim(
    out: *IdentityStoredClaim,
    claim: *const noztr.nip39_external_identities.IdentityClaim,
) IdentityProfileStoreError!void {
    if (claim.identity.len > identity_profile_store_identity_max_bytes) return error.IdentityTooLong;
    if (claim.proof.len > identity_profile_store_proof_max_bytes) return error.ProofTooLong;

    out.* = .{ .provider = claim.provider };
    @memcpy(out.identity[0..claim.identity.len], claim.identity);
    out.identity_len = @intCast(claim.identity.len);
    @memcpy(out.proof[0..claim.proof.len], claim.proof);
    out.proof_len = @intCast(claim.proof.len);
}

fn recordContainsIdentity(
    record: *const IdentityProfileRecord,
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
) bool {
    for (record.verifiedClaims()) |*claim| {
        if (claim.provider != provider) continue;
        if (std.mem.eql(u8, claim.identitySlice(), identity)) return true;
    }
    return false;
}

fn findMatchedStoredClaimIndex(
    record: *const IdentityProfileRecord,
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
) ?u8 {
    for (record.verifiedClaims(), 0..) |*claim, index| {
        if (claim.provider != provider) continue;
        if (!std.mem.eql(u8, claim.identitySlice(), identity)) continue;
        return @intCast(index);
    }
    return null;
}

fn cache_put(
    ctx: *anyopaque,
    verification: *const IdentityVerificationMatch,
    result: IdentityVerificationCacheResult,
) IdentityVerificationCacheError!void {
    const self: *MemoryIdentityVerificationCache = @ptrCast(@alignCast(ctx));
    return self.putCached(verification, result);
}

fn cache_get(
    ctx: *anyopaque,
    verification: *const IdentityVerificationMatch,
) IdentityVerificationCacheError!?IdentityVerificationCacheResult {
    const self: *MemoryIdentityVerificationCache = @ptrCast(@alignCast(ctx));
    return self.getCached(verification);
}

const cache_vtable = IdentityVerificationCacheVTable{
    .put_cached = cache_put,
    .get_cached = cache_get,
};

fn profile_store_put(
    ctx: *anyopaque,
    pubkey: *const [32]u8,
    event_created_at: u64,
    summary: *const IdentityProfileVerificationSummary,
) IdentityProfileStoreError!IdentityProfileStorePutOutcome {
    const self: *MemoryIdentityProfileStore = @ptrCast(@alignCast(ctx));
    return self.putProfileSummary(pubkey, event_created_at, summary);
}

fn profile_store_get(
    ctx: *anyopaque,
    pubkey: *const [32]u8,
) IdentityProfileStoreError!?IdentityProfileRecord {
    const self: *MemoryIdentityProfileStore = @ptrCast(@alignCast(ctx));
    return self.getProfile(pubkey);
}

fn profile_store_find(
    ctx: *anyopaque,
    provider: noztr.nip39_external_identities.IdentityProvider,
    identity: []const u8,
    out: []IdentityProfileMatch,
) IdentityProfileStoreError!usize {
    const self: *MemoryIdentityProfileStore = @ptrCast(@alignCast(ctx));
    const matches = try self.findProfiles(provider, identity, out);
    return matches.len;
}

const profile_store_vtable = IdentityProfileStoreVTable{
    .put_profile_summary = profile_store_put,
    .get_profile = profile_store_get,
    .find_profiles = profile_store_find,
};

fn providerDetailsForClaim(
    claim: *const noztr.nip39_external_identities.IdentityClaim,
) noztr.nip39_external_identities.Nip39Error!IdentityProviderDetails {
    try validateClaimForDetails(claim);
    return switch (claim.provider) {
        .github => .{
            .github = .{
                .username = claim.identity,
                .gist_id = claim.proof,
            },
        },
        .twitter => .{
            .twitter = .{
                .handle = claim.identity,
                .status_id = claim.proof,
            },
        },
        .mastodon => .{
            .mastodon = try parseMastodonDetails(claim),
        },
        .telegram => .{
            .telegram = try parseTelegramDetails(claim),
        },
    };
}

fn validateClaimForDetails(
    claim: *const noztr.nip39_external_identities.IdentityClaim,
) noztr.nip39_external_identities.Nip39Error!void {
    var proof_url_scratch: [256]u8 = undefined;
    var expected_text_scratch: [256]u8 = undefined;
    _ = try noztr.nip39_external_identities.identity_claim_build_proof_url(
        proof_url_scratch[0..],
        claim,
    );
    _ = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_scratch[0..],
        claim,
        &([_]u8{0} ** 32),
    );
}

fn parseMastodonDetails(
    claim: *const noztr.nip39_external_identities.IdentityClaim,
) noztr.nip39_external_identities.Nip39Error!MastodonIdentityDetails {
    const marker = std.mem.indexOf(u8, claim.identity, "/@") orelse return error.InvalidIdentity;
    const host = claim.identity[0..marker];
    const handle = claim.identity[marker + 2 ..];
    if (host.len == 0 or handle.len == 0) return error.InvalidIdentity;
    return .{
        .host = host,
        .handle = handle,
        .status_id = claim.proof,
    };
}

fn parseTelegramDetails(
    claim: *const noztr.nip39_external_identities.IdentityClaim,
) noztr.nip39_external_identities.Nip39Error!TelegramIdentityDetails {
    const separator = std.mem.indexOfScalar(u8, claim.proof, '/') orelse return error.InvalidProof;
    const channel = claim.proof[0..separator];
    const message_id = claim.proof[separator + 1 ..];
    if (channel.len == 0 or message_id.len == 0) return error.InvalidProof;
    return .{
        .user_id = claim.identity,
        .channel = channel,
        .message_id = message_id,
    };
}

test "identity verifier verifies github proof content over explicit http seam" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "alice",
        .proof = "gist-id",
    };
    const pubkey = [_]u8{0x39} ** 32;

    var expected_text_buffer: [256]u8 = undefined;
    const expected_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0..],
        &claim,
        &pubkey,
    );
    var body_storage: [384]u8 = undefined;
    const body = try std.fmt.bufPrint(
        body_storage[0..],
        "<html><body>{s}</body></html>",
        .{expected_text},
    );
    var fake_http = workflow_testing.FakeHttp.init("https://gist.github.com/alice/gist-id", body);
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;
    var response_buffer: [512]u8 = undefined;

    const outcome = try IdentityVerifier.verify(
        fake_http.client(),
        .{
            .claim = &claim,
            .pubkey = &pubkey,
            .storage = IdentityVerificationStorage.init(
                url_buffer[0..],
                text_buffer[0..],
                response_buffer[0..],
            ),
        },
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqualStrings(
        "https://gist.github.com/alice/gist-id",
        outcome.verified.proof_url,
    );
    try std.testing.expectEqualStrings(expected_text, outcome.verified.expected_text);
}

test "identity verifier classifies proof mismatch" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .twitter,
        .identity = "alice_public",
        .proof = "1619358434134196225",
    };
    const pubkey = [_]u8{0x55} ** 32;
    var fake_http = workflow_testing.FakeHttp.init(
        "https://twitter.com/alice_public/status/1619358434134196225",
        "proof page without the expected npub text",
    );
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;
    var response_buffer: [512]u8 = undefined;

    const outcome = try IdentityVerifier.verify(
        fake_http.client(),
        .{
            .claim = &claim,
            .pubkey = &pubkey,
            .storage = IdentityVerificationStorage.init(
                url_buffer[0..],
                text_buffer[0..],
                response_buffer[0..],
            ),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expectEqualStrings(
        "https://twitter.com/alice_public/status/1619358434134196225",
        outcome.mismatch.proof_url,
    );
    try std.testing.expect(std.mem.indexOf(u8, outcome.mismatch.expected_text, "npub") != null);
}

test "identity verifier returns fetch failures as typed outcomes" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .mastodon,
        .identity = "bitcoinhackers.org/@semisol",
        .proof = "109775066355589974",
    };
    const pubkey = [_]u8{0x22} ** 32;
    var fake_http = workflow_testing.FakeHttp.init(
        "https://bitcoinhackers.org/@semisol/109775066355589974",
        "",
    );
    fake_http.fail_with = error.TransportUnavailable;
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;
    var response_buffer: [128]u8 = undefined;

    const outcome = try IdentityVerifier.verify(
        fake_http.client(),
        .{
            .claim = &claim,
            .pubkey = &pubkey,
            .storage = IdentityVerificationStorage.init(
                url_buffer[0..],
                text_buffer[0..],
                response_buffer[0..],
            ),
        },
    );

    try std.testing.expect(outcome == .fetch_failed);
    try std.testing.expectEqual(error.TransportUnavailable, outcome.fetch_failed.cause);
    try std.testing.expectEqualStrings(
        "https://bitcoinhackers.org/@semisol/109775066355589974",
        outcome.fetch_failed.verification.proof_url,
    );
}

test "identity verifier propagates invalid claims from noztr" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .telegram,
        .identity = "1087295469",
        .proof = "nostrdirectory/not-a-number",
    };
    const pubkey = [_]u8{0x77} ** 32;
    var fake_http = workflow_testing.FakeHttp.init("https://t.me/nostrdirectory/not-a-number", "");
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;
    var response_buffer: [128]u8 = undefined;

    try std.testing.expectError(
        error.InvalidProof,
        IdentityVerifier.verify(
            fake_http.client(),
            .{
                .claim = &claim,
                .pubkey = &pubkey,
                .storage = IdentityVerificationStorage.init(
                    url_buffer[0..],
                    text_buffer[0..],
                    response_buffer[0..],
                ),
            },
        ),
    );
}

test "identity verifier rejects telegram until provider-specific identity checks exist" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .telegram,
        .identity = "1087295469",
        .proof = "nostrdirectory/770",
    };
    const pubkey = [_]u8{0x11} ** 32;
    var fake_http = workflow_testing.FakeHttp.init("https://t.me/nostrdirectory/770", "");
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;
    var response_buffer: [128]u8 = undefined;

    try std.testing.expectError(
        error.UnsupportedProviderVerification,
        IdentityVerifier.verify(
            fake_http.client(),
            .{
                .claim = &claim,
                .pubkey = &pubkey,
                .storage = IdentityVerificationStorage.init(
                    url_buffer[0..],
                    text_buffer[0..],
                    response_buffer[0..],
                ),
            },
        ),
    );
}

test "identity verifier extracts and verifies claims from a full identity event" {
    const pubkey = [_]u8{0x42} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .github, .identity = "alice", .proof = "gist-id" },
        .{ .provider = .twitter, .identity = "alice_public", .proof = "1619358434134196225" },
    };
    var tags_storage: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &tags_storage[index],
            claim,
        );
    }
    const author_secret = [_]u8{0x55} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var expected_text_buffer: [256]u8 = undefined;
    const expected_github = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0..],
        &claims[0],
        &pubkey,
    );
    var github_body_storage: [512]u8 = undefined;
    const github_body = try std.fmt.bufPrint(github_body_storage[0..], "<pre>{s}</pre>", .{expected_github});
    const twitter_body = "proof page without the expected text";
    var responses = [_]TestHttpResponse{
        .{ .url = "https://gist.github.com/alice/gist-id", .body = github_body },
        .{
            .url = "https://twitter.com/alice_public/status/1619358434134196225",
            .body = twitter_body,
        },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);

    var extracted_claims: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [4][256]u8 = undefined;
    var text_buffers: [4][256]u8 = undefined;
    var body_buffers: [4][512]u8 = undefined;
    var verification_storage: [4]IdentityVerificationStorage = undefined;
    for (&verification_storage, 0..) |*slot, index| {
        slot.* = IdentityVerificationStorage.init(
            url_buffers[index][0..],
            text_buffers[index][0..],
            body_buffers[index][0..],
        );
    }
    var results: [4]IdentityClaimVerification = undefined;

    const summary = try IdentityVerifier.verifyProfile(
        fake_http.client(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), summary.claims.len);
    try std.testing.expectEqual(@as(usize, 1), summary.verified_count);
    try std.testing.expectEqual(@as(usize, 1), summary.mismatch_count);
    try std.testing.expect(summary.claims[0].outcome == .verified);
    try std.testing.expect(summary.claims[1].outcome == .mismatch);
}

test "identity verifier classifies unsupported and fetch-failed claims during profile verification" {
    const pubkey = [_]u8{0x24} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .telegram, .identity = "1087295469", .proof = "nostrdirectory/770" },
        .{ .provider = .mastodon, .identity = "bitcoinhackers.org/@semisol", .proof = "109775066355589974" },
    };
    var tags_storage: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &tags_storage[index],
            claim,
        );
    }
    const author_secret = [_]u8{0x44} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var responses = [_]TestHttpResponse{
        .{
            .url = "https://bitcoinhackers.org/@semisol/109775066355589974",
            .fail_with = error.TransportUnavailable,
        },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);

    var extracted_claims: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var slot0_url: [256]u8 = undefined;
    var slot0_text: [256]u8 = undefined;
    var slot0_body: [512]u8 = undefined;
    var slot1_url: [256]u8 = undefined;
    var slot1_text: [256]u8 = undefined;
    var slot1_body: [512]u8 = undefined;
    var verification_storage = [_]IdentityVerificationStorage{
        IdentityVerificationStorage.init(slot0_url[0..], slot0_text[0..], slot0_body[0..]),
        IdentityVerificationStorage.init(slot1_url[0..], slot1_text[0..], slot1_body[0..]),
    };
    var results: [2]IdentityClaimVerification = undefined;

    const summary = try IdentityVerifier.verifyProfile(
        fake_http.client(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), summary.claims.len);
    try std.testing.expectEqual(@as(usize, 1), summary.unsupported_count);
    try std.testing.expectEqual(@as(usize, 1), summary.fetch_failed_count);
    try std.testing.expect(summary.claims[0].outcome == .unsupported);
    try std.testing.expect(summary.claims[1].outcome == .fetch_failed);
}

test "identity verifier exposes provider-specific details for verified profile claims" {
    const pubkey = [_]u8{0x42} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .github, .identity = "alice", .proof = "gist-id" },
        .{
            .provider = .mastodon,
            .identity = "bitcoinhackers.org/@semisol",
            .proof = "109775066355589974",
        },
    };
    var tags_storage: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &tags_storage[index],
            claim,
        );
    }

    const author_secret = [_]u8{0x66} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var github_text_buffer: [256]u8 = undefined;
    const github_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        github_text_buffer[0..],
        &claims[0],
        &pubkey,
    );
    var mastodon_text_buffer: [256]u8 = undefined;
    const mastodon_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        mastodon_text_buffer[0..],
        &claims[1],
        &pubkey,
    );
    var github_body_storage: [384]u8 = undefined;
    const github_body = try std.fmt.bufPrint(github_body_storage[0..], "<pre>{s}</pre>", .{github_text});
    var mastodon_body_storage: [384]u8 = undefined;
    const mastodon_body = try std.fmt.bufPrint(
        mastodon_body_storage[0..],
        "<div>{s}</div>",
        .{mastodon_text},
    );
    var responses = [_]TestHttpResponse{
        .{ .url = "https://gist.github.com/alice/gist-id", .body = github_body },
        .{
            .url = "https://bitcoinhackers.org/@semisol/109775066355589974",
            .body = mastodon_body,
        },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);

    var extracted_claims: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [4][256]u8 = undefined;
    var text_buffers: [4][256]u8 = undefined;
    var body_buffers: [4][512]u8 = undefined;
    var verification_storage: [4]IdentityVerificationStorage = undefined;
    for (&verification_storage, 0..) |*slot, index| {
        slot.* = IdentityVerificationStorage.init(
            url_buffers[index][0..],
            text_buffers[index][0..],
            body_buffers[index][0..],
        );
    }
    var results: [4]IdentityClaimVerification = undefined;

    const summary = try IdentityVerifier.verifyProfile(
        fake_http.client(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );

    var verified: [2]*const IdentityClaimVerification = undefined;
    const verified_claims = summary.verifiedClaims(verified[0..]);
    try std.testing.expectEqual(@as(usize, 2), verified_claims.len);

    const github_details = try verified_claims[0].providerDetails();
    try std.testing.expect(github_details == .github);
    try std.testing.expectEqualStrings("alice", github_details.github.username);
    try std.testing.expectEqualStrings("gist-id", github_details.github.gist_id);

    const mastodon_details = try verified_claims[1].providerDetails();
    try std.testing.expect(mastodon_details == .mastodon);
    try std.testing.expectEqualStrings("bitcoinhackers.org", mastodon_details.mastodon.host);
    try std.testing.expectEqualStrings("semisol", mastodon_details.mastodon.handle);
    try std.testing.expectEqualStrings("109775066355589974", mastodon_details.mastodon.status_id);
}

test "identity verifier exposes telegram provider details from validated claims" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .telegram,
        .identity = "1087295469",
        .proof = "nostrdirectory/770",
    };
    const verification = IdentityClaimVerification{
        .claim = claim,
        .outcome = .{
            .unsupported = .{
                .proof_url = "https://t.me/nostrdirectory/770",
                .expected_text = "ignored",
            },
        },
    };

    const details = try verification.providerDetails();
    try std.testing.expect(details == .telegram);
    try std.testing.expectEqualStrings("1087295469", details.telegram.user_id);
    try std.testing.expectEqualStrings("nostrdirectory", details.telegram.channel);
    try std.testing.expectEqualStrings("770", details.telegram.message_id);
}

test "identity verifier reuses cached profile verification outcomes before fetching again" {
    const pubkey = [_]u8{0x42} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .github, .identity = "alice", .proof = "gist-id" },
        .{ .provider = .twitter, .identity = "alice_public", .proof = "1619358434134196225" },
    };
    var tags_storage: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &tags_storage[index],
            claim,
        );
    }

    const author_secret = [_]u8{0x55} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var expected_text_buffer: [2][256]u8 = undefined;
    const github_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0][0..],
        &claims[0],
        &pubkey,
    );
    const twitter_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[1][0..],
        &claims[1],
        &pubkey,
    );
    var github_body_storage: [512]u8 = undefined;
    const github_body = try std.fmt.bufPrint(github_body_storage[0..], "<pre>{s}</pre>", .{github_text});
    var twitter_body_storage: [512]u8 = undefined;
    const twitter_body = try std.fmt.bufPrint(twitter_body_storage[0..], "<div>{s}</div>", .{twitter_text});
    var responses = [_]TestHttpResponse{
        .{ .url = "https://gist.github.com/alice/gist-id", .body = github_body },
        .{
            .url = "https://twitter.com/alice_public/status/1619358434134196225",
            .body = twitter_body,
        },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);
    var cache_records: [4]IdentityVerificationCacheRecord = undefined;
    var cache = MemoryIdentityVerificationCache.init(cache_records[0..]);

    var extracted_claims: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [4][256]u8 = undefined;
    var text_buffers: [4][256]u8 = undefined;
    var body_buffers: [4][512]u8 = undefined;
    var verification_storage: [4]IdentityVerificationStorage = undefined;
    for (&verification_storage, 0..) |*slot, index| {
        slot.* = IdentityVerificationStorage.init(
            url_buffers[index][0..],
            text_buffers[index][0..],
            body_buffers[index][0..],
        );
    }
    var results: [4]IdentityClaimVerification = undefined;

    const first = try IdentityVerifier.verifyProfileCached(
        fake_http.client(),
        cache.asCache(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), first.verified_count);
    try std.testing.expectEqual(@as(usize, 0), first.cache_hit_count);
    try std.testing.expectEqual(@as(usize, 2), first.network_fetch_count);

    var offline_responses = [_]TestHttpResponse{};
    var offline_http = TestMultiHttp.init(offline_responses[0..]);
    var extracted_claims_again: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers_again: [4][256]u8 = undefined;
    var text_buffers_again: [4][256]u8 = undefined;
    var body_buffers_again: [4][512]u8 = undefined;
    var verification_storage_again: [4]IdentityVerificationStorage = undefined;
    for (&verification_storage_again, 0..) |*slot, index| {
        slot.* = IdentityVerificationStorage.init(
            url_buffers_again[index][0..],
            text_buffers_again[index][0..],
            body_buffers_again[index][0..],
        );
    }
    var results_again: [4]IdentityClaimVerification = undefined;

    const second = try IdentityVerifier.verifyProfileCached(
        offline_http.client(),
        cache.asCache(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims_again[0..],
                verification_storage_again[0..],
                results_again[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), second.verified_count);
    try std.testing.expectEqual(@as(usize, 2), second.cache_hit_count);
    try std.testing.expectEqual(@as(usize, 0), second.network_fetch_count);
}

test "identity verifier cached profile verification still classifies telegram as unsupported" {
    const pubkey = [_]u8{0x24} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .telegram, .identity = "1087295469", .proof = "nostrdirectory/770" },
    };
    var tags_storage: [1]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags = [_]noztr.nip01_event.EventTag{
        try noztr.nip39_external_identities.identity_claim_build_tag(&tags_storage[0], &claims[0]),
    };
    const author_secret = [_]u8{0x44} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var no_responses = [_]TestHttpResponse{};
    var fake_http = TestMultiHttp.init(no_responses[0..]);
    var cache_records: [1]IdentityVerificationCacheRecord = undefined;
    var cache = MemoryIdentityVerificationCache.init(cache_records[0..]);
    var extracted_claims: [1]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffer: [1][256]u8 = undefined;
    var text_buffer: [1][256]u8 = undefined;
    var body_buffer: [1][256]u8 = undefined;
    var verification_storage = [_]IdentityVerificationStorage{
        IdentityVerificationStorage.init(
            url_buffer[0][0..],
            text_buffer[0][0..],
            body_buffer[0][0..],
        ),
    };
    var results: [1]IdentityClaimVerification = undefined;

    const summary = try IdentityVerifier.verifyProfileCached(
        fake_http.client(),
        cache.asCache(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), summary.unsupported_count);
    try std.testing.expectEqual(@as(usize, 0), summary.cache_hit_count);
    try std.testing.expectEqual(@as(usize, 0), summary.network_fetch_count);
    try std.testing.expect(summary.claims[0].outcome == .unsupported);
}

test "identity verifier stores verified profile claims and discovers them by provider identity" {
    const pubkey = [_]u8{0x42} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .github, .identity = "alice", .proof = "gist-id" },
        .{ .provider = .twitter, .identity = "alice_public", .proof = "1619358434134196225" },
    };
    var tags_storage: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &tags_storage[index],
            claim,
        );
    }

    const author_secret = [_]u8{0x21} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 7,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var github_text_buffer: [256]u8 = undefined;
    const github_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        github_text_buffer[0..],
        &claims[0],
        &pubkey,
    );
    var github_body_storage: [384]u8 = undefined;
    const github_body = try std.fmt.bufPrint(github_body_storage[0..], "<pre>{s}</pre>", .{github_text});
    var responses = [_]TestHttpResponse{
        .{ .url = "https://gist.github.com/alice/gist-id", .body = github_body },
        .{
            .url = "https://twitter.com/alice_public/status/1619358434134196225",
            .body = "no npub here",
        },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);

    var extracted_claims: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [4][256]u8 = undefined;
    var text_buffers: [4][256]u8 = undefined;
    var body_buffers: [4][512]u8 = undefined;
    var verification_storage: [4]IdentityVerificationStorage = undefined;
    for (&verification_storage, 0..) |*slot, index| {
        slot.* = IdentityVerificationStorage.init(
            url_buffers[index][0..],
            text_buffers[index][0..],
            body_buffers[index][0..],
        );
    }
    var results: [4]IdentityClaimVerification = undefined;

    const summary = try IdentityVerifier.verifyProfile(
        fake_http.client(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    const put_outcome = try IdentityVerifier.rememberProfileSummary(
        store.asStore(),
        &pubkey,
        identity_event.created_at,
        &summary,
    );
    try std.testing.expectEqual(.stored, put_outcome);

    const stored = (try IdentityVerifier.getStoredProfile(store.asStore(), &pubkey)).?;
    try std.testing.expectEqual(@as(u64, 7), stored.created_at);
    try std.testing.expectEqual(@as(u8, 1), stored.verified_claim_count);
    try std.testing.expectEqualStrings("alice", stored.verifiedClaims()[0].identitySlice());
    try std.testing.expectEqual(@as(u16, 1), stored.mismatch_count);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    const matches = try IdentityVerifier.discoverStoredProfiles(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .results = matches_storage[0..],
        },
    );
    try std.testing.expectEqual(@as(usize, 1), matches.len);
    try std.testing.expectEqualSlices(u8, pubkey[0..], matches[0].pubkey[0..]);

    const missing = try IdentityVerifier.discoverStoredProfiles(
        store.asStore(),
        .{
            .provider = .twitter,
            .identity = "alice_public",
            .results = matches_storage[0..],
        },
    );
    try std.testing.expectEqual(@as(usize, 0), missing.len);
}

test "identity verifier ignores stale stored profile summaries for the same pubkey" {
    const pubkey = [_]u8{0x99} ** 32;
    const verified_claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "alice",
        .proof = "gist-id",
    };
    const newer_results = [_]IdentityClaimVerification{
        .{
            .claim = verified_claim,
            .outcome = .{
                .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-id",
                    .expected_text = "npub",
                },
            },
        },
    };
    const older_claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "bob",
        .proof = "gist-id-2",
    };
    const older_results = [_]IdentityClaimVerification{
        .{
            .claim = older_claim,
            .outcome = .{
                .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-id-2",
                    .expected_text = "npub",
                },
            },
        },
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = newer_results[0..],
        .verified_count = 1,
    };
    const older_summary = IdentityProfileVerificationSummary{
        .claims = older_results[0..],
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    try std.testing.expectEqual(
        IdentityProfileStorePutOutcome.stored,
        try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 20, &newer_summary),
    );
    try std.testing.expectEqual(
        IdentityProfileStorePutOutcome.ignored_stale,
        try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 10, &older_summary),
    );

    const stored = (try IdentityVerifier.getStoredProfile(store.asStore(), &pubkey)).?;
    try std.testing.expectEqual(@as(u64, 20), stored.created_at);
    try std.testing.expectEqualStrings("alice", stored.verifiedClaims()[0].identitySlice());
}

test "identity verifier profile store rejects summaries with too many verified claims" {
    var verified_results: [identity_profile_store_verified_claims_max + 1]IdentityClaimVerification = undefined;
    for (&verified_results, 0..) |*slot, index| {
        slot.* = .{
            .claim = .{
                .provider = .github,
                .identity = "alice",
                .proof = "gist-id",
            },
            .outcome = .{
                .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-id",
                    .expected_text = "npub",
                },
            },
        };
        _ = index;
    }
    const summary = IdentityProfileVerificationSummary{
        .claims = verified_results[0..],
        .verified_count = identity_profile_store_verified_claims_max + 1,
    };
    const pubkey = [_]u8{0x01} ** 32;
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);

    try std.testing.expectError(
        error.TooManyVerifiedClaims,
        IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 1, &summary),
    );
}

test "identity verifier verifies, remembers, and hydrates stored profile discovery" {
    const pubkey = [_]u8{0x61} ** 32;
    const claims = [_]noztr.nip39_external_identities.IdentityClaim{
        .{ .provider = .github, .identity = "alice", .proof = "gist-id" },
        .{ .provider = .mastodon, .identity = "nostr.example/@alice", .proof = "112233" },
    };
    var tags_storage: [2]noztr.nip39_external_identities.BuiltTag = undefined;
    var tags: [2]noztr.nip01_event.EventTag = undefined;
    for (&claims, 0..) |*claim, index| {
        tags[index] = try noztr.nip39_external_identities.identity_claim_build_tag(
            &tags_storage[index],
            claim,
        );
    }

    const author_secret = [_]u8{0x71} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    var identity_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 11,
        .content = "",
        .tags = tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&author_secret, &identity_event);

    var expected_text_buffer: [2][256]u8 = undefined;
    const github_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0][0..],
        &claims[0],
        &pubkey,
    );
    const mastodon_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[1][0..],
        &claims[1],
        &pubkey,
    );
    var github_body_storage: [384]u8 = undefined;
    const github_body = try std.fmt.bufPrint(github_body_storage[0..], "<pre>{s}</pre>", .{github_text});
    var mastodon_body_storage: [384]u8 = undefined;
    const mastodon_body = try std.fmt.bufPrint(
        mastodon_body_storage[0..],
        "<article>{s}</article>",
        .{mastodon_text},
    );
    var responses = [_]TestHttpResponse{
        .{ .url = "https://gist.github.com/alice/gist-id", .body = github_body },
        .{ .url = "https://nostr.example/@alice/112233", .body = mastodon_body },
    };
    var fake_http = TestMultiHttp.init(responses[0..]);

    var extracted_claims: [4]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [4][256]u8 = undefined;
    var text_buffers: [4][256]u8 = undefined;
    var body_buffers: [4][512]u8 = undefined;
    var verification_storage: [4]IdentityVerificationStorage = undefined;
    for (&verification_storage, 0..) |*slot, index| {
        slot.* = IdentityVerificationStorage.init(
            url_buffers[index][0..],
            text_buffers[index][0..],
            body_buffers[index][0..],
        );
    }
    var results: [4]IdentityClaimVerification = undefined;
    var cache_records: [4]IdentityVerificationCacheRecord = undefined;
    var cache = MemoryIdentityVerificationCache.init(cache_records[0..]);
    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);

    const remembered = try IdentityVerifier.verifyProfileCachedAndRemember(
        fake_http.client(),
        cache.asCache(),
        store.asStore(),
        .{
            .event = &identity_event,
            .pubkey = &pubkey,
            .storage = IdentityProfileVerificationStorage.init(
                extracted_claims[0..],
                verification_storage[0..],
                results[0..],
            ),
        },
    );
    try std.testing.expectEqual(IdentityProfileStorePutOutcome.stored, remembered.store_outcome);
    try std.testing.expectEqual(@as(usize, 2), remembered.summary.verified_count);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileDiscoveryEntry = undefined;
    const entries = try IdentityVerifier.discoverStoredProfileEntries(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .storage = IdentityStoredProfileDiscoveryStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqualSlices(u8, pubkey[0..], entries[0].match.pubkey[0..]);
    try std.testing.expectEqual(@as(u64, 11), entries[0].match.created_at);
    try std.testing.expectEqualStrings("alice", entries[0].matchedClaim().identitySlice());
    try std.testing.expectEqual(@as(u8, 2), entries[0].profile.verified_claim_count);
}

test "identity verifier returns the newest latest stored profile for a provider identity" {
    const older_pubkey = [_]u8{0x81} ** 32;
    const newer_pubkey = [_]u8{0x82} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 5, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 9, &newer_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    const latest = (try IdentityVerifier.getLatestStoredProfile(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .matches = matches_storage[0..],
        },
    )).?;
    try std.testing.expectEqualSlices(u8, newer_pubkey[0..], latest.match.pubkey[0..]);
    try std.testing.expectEqual(@as(u64, 9), latest.match.created_at);
    try std.testing.expectEqualStrings("gist-new", latest.matchedClaim().proofSlice());
}

test "identity verifier classifies latest stored profile freshness" {
    const pubkey = [_]u8{0x91} ** 32;
    const summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-id",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-id",
                        .expected_text = "npub",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 20, &summary);

    var matches_storage: [1]IdentityProfileMatch = undefined;
    const fresh = (try IdentityVerifier.getLatestStoredProfileFreshness(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 40,
            .matches = matches_storage[0..],
        },
    )).?;
    try std.testing.expectEqual(IdentityStoredProfileFreshness.fresh, fresh.freshness);
    try std.testing.expectEqual(@as(u64, 30), fresh.age_seconds);
    try std.testing.expectEqualSlices(u8, pubkey[0..], fresh.latest.match.pubkey[0..]);

    const stale = (try IdentityVerifier.getLatestStoredProfileFreshness(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 90,
            .max_age_seconds = 40,
            .matches = matches_storage[0..],
        },
    )).?;
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, stale.freshness);
    try std.testing.expectEqual(@as(u64, 70), stale.age_seconds);
}

test "identity verifier returns null freshness for missing stored profiles" {
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    var matches_storage: [1]IdentityProfileMatch = undefined;

    const missing = try IdentityVerifier.getLatestStoredProfileFreshness(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 10,
            .max_age_seconds = 5,
            .matches = matches_storage[0..],
        },
    );
    try std.testing.expect(missing == null);
}

test "identity verifier classifies all remembered discovery entries by freshness" {
    const older_pubkey = [_]u8{0xa1} ** 32;
    const newer_pubkey = [_]u8{0xa2} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 5, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 35, &newer_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    const entries = try IdentityVerifier.discoverStoredProfileEntriesWithFreshness(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = IdentityStoredProfileDiscoveryFreshnessStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualSlices(u8, older_pubkey[0..], entries[0].entry.match.pubkey[0..]);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, entries[0].freshness);
    try std.testing.expectEqual(@as(u64, 45), entries[0].age_seconds);
    try std.testing.expectEqualStrings("gist-old", entries[0].matchedClaim().proofSlice());
    try std.testing.expectEqualSlices(u8, newer_pubkey[0..], entries[1].entry.match.pubkey[0..]);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.fresh, entries[1].freshness);
    try std.testing.expectEqual(@as(u64, 15), entries[1].age_seconds);
    try std.testing.expectEqualStrings("gist-new", entries[1].matchedClaim().proofSlice());
}

test "identity verifier returns empty freshness discovery for missing stored profiles" {
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [1]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;

    const entries = try IdentityVerifier.discoverStoredProfileEntriesWithFreshness(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 10,
            .max_age_seconds = 5,
            .storage = IdentityStoredProfileDiscoveryFreshnessStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 0), entries.len);
}

test "identity verifier discovers remembered profile entries for watched target set in caller order" {
    const alice_old_pubkey = [_]u8{0xb1} ** 32;
    const alice_new_pubkey = [_]u8{0xb2} ** 32;
    const bob_pubkey = [_]u8{0xb3} ** 32;
    const alice_old_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice-old",
                        .expected_text = "npub-alice-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const alice_new_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice-new",
                        .expected_text = "npub-alice-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_old_pubkey, 4, &alice_old_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_new_pubkey, 10, &alice_new_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 7, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [2]IdentityProfileMatch = undefined;
    var target_entries: [3]IdentityStoredProfileDiscoveryEntry = undefined;
    var groups_storage: [3]IdentityStoredProfileTargetDiscoveryGroup = undefined;
    const groups = try IdentityVerifier.discoverStoredProfileEntriesForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .storage = IdentityStoredProfileTargetDiscoveryStorage.init(
                matches_storage[0..],
                target_entries[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), groups.len);
    try std.testing.expectEqualStrings("bob", groups[0].target.identity);
    try std.testing.expectEqual(@as(usize, 1), groups[0].entries.len);
    try std.testing.expectEqualStrings("gist-bob", groups[0].entries[0].matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("alice", groups[1].target.identity);
    try std.testing.expectEqual(@as(usize, 2), groups[1].entries.len);
    try std.testing.expectEqualStrings("gist-alice-old", groups[1].entries[0].matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("gist-alice-new", groups[1].entries[1].matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("carol", groups[2].target.identity);
    try std.testing.expectEqual(@as(usize, 0), groups[2].entries.len);
}

test "identity verifier target discovery stays bounded by caller-owned entry storage" {
    const alice_pubkey = [_]u8{0xb1} ** 32;
    const bob_pubkey = [_]u8{0xb2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 4, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 5, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var target_entries: [1]IdentityStoredProfileDiscoveryEntry = undefined;
    var groups_storage: [2]IdentityStoredProfileTargetDiscoveryGroup = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        IdentityVerifier.discoverStoredProfileEntriesForTargets(
            store.asStore(),
            .{
                .targets = targets[0..],
                .storage = IdentityStoredProfileTargetDiscoveryStorage.init(
                    matches_storage[0..],
                    target_entries[0..],
                    groups_storage[0..],
                ),
            },
        ),
    );
}

test "identity verifier discovers freshness-classified remembered entries for watched target set in caller order" {
    const alice_old_pubkey = [_]u8{0xb1} ** 32;
    const alice_new_pubkey = [_]u8{0xb2} ** 32;
    const bob_pubkey = [_]u8{0xb3} ** 32;
    const alice_old_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice-old",
                        .expected_text = "npub-alice-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const alice_new_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice-new",
                        .expected_text = "npub-alice-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_old_pubkey, 4, &alice_old_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_new_pubkey, 10, &alice_new_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 7, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [2]IdentityProfileMatch = undefined;
    var target_entries: [3]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    var groups_storage: [3]IdentityStoredProfileTargetDiscoveryFreshnessGroup = undefined;
    const groups = try IdentityVerifier.discoverStoredProfileEntriesWithFreshnessForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 20,
            .max_age_seconds = 8,
            .storage = IdentityStoredProfileTargetDiscoveryFreshnessStorage.init(
                matches_storage[0..],
                target_entries[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), groups.len);
    try std.testing.expectEqualStrings("alice", groups[0].target.identity);
    try std.testing.expectEqual(@as(usize, 2), groups[0].entries.len);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, groups[0].entries[0].freshness);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, groups[0].entries[1].freshness);
    try std.testing.expectEqualStrings("bob", groups[1].target.identity);
    try std.testing.expectEqual(@as(usize, 1), groups[1].entries.len);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, groups[1].entries[0].freshness);
    try std.testing.expectEqualStrings("carol", groups[2].target.identity);
    try std.testing.expectEqual(@as(usize, 0), groups[2].entries.len);
}

test "identity verifier grouped freshness discovery returns empty groups for missing targets" {
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var target_entries: [1]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    var groups_storage: [2]IdentityStoredProfileTargetDiscoveryFreshnessGroup = undefined;
    const groups = try IdentityVerifier.discoverStoredProfileEntriesWithFreshnessForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 5,
            .max_age_seconds = 5,
            .storage = IdentityStoredProfileTargetDiscoveryFreshnessStorage.init(
                matches_storage[0..],
                target_entries[0..],
                groups_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), groups.len);
    try std.testing.expectEqual(@as(usize, 0), groups[0].entries.len);
    try std.testing.expectEqual(@as(usize, 0), groups[1].entries.len);
}

test "identity verifier gets latest remembered profile per watched target in caller order" {
    const alice_old_pubkey = [_]u8{0xb1} ** 32;
    const alice_new_pubkey = [_]u8{0xb2} ** 32;
    const bob_pubkey = [_]u8{0xb3} ** 32;
    const alice_old_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice-old",
                        .expected_text = "npub-alice-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const alice_new_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice-new",
                        .expected_text = "npub-alice-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_old_pubkey, 4, &alice_old_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_new_pubkey, 10, &alice_new_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 7, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [2]IdentityProfileMatch = undefined;
    var latest_entries: [3]IdentityLatestStoredProfileTargetEntry = undefined;
    const latest = try IdentityVerifier.getLatestStoredProfilesForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .storage = IdentityLatestStoredProfileTargetStorage.init(
                matches_storage[0..],
                latest_entries[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), latest.len);
    try std.testing.expectEqualStrings("bob", latest[0].target.identity);
    try std.testing.expectEqualStrings("gist-bob", latest[0].latest.?.matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("alice", latest[1].target.identity);
    try std.testing.expectEqualStrings("gist-alice-new", latest[1].latest.?.matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("carol", latest[2].target.identity);
    try std.testing.expect(latest[2].latest == null);
}

test "identity verifier latest per-target helper stays bounded by caller-owned target storage" {
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries: [0]IdentityLatestStoredProfileTargetEntry = .{};
    try std.testing.expectError(
        error.BufferTooSmall,
        IdentityVerifier.getLatestStoredProfilesForTargets(
            store.asStore(),
            .{
                .targets = targets[0..],
                .storage = IdentityLatestStoredProfileTargetStorage.init(
                    matches_storage[0..],
                    latest_entries[0..],
                ),
            },
        ),
    );
}

test "identity verifier gets preferred remembered profile per watched target in caller order" {
    const alice_pubkey = [_]u8{0xb1} ** 32;
    const bob_pubkey = [_]u8{0xb2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 10, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 5, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var preferred_entries: [3]IdentityPreferredStoredProfileTargetEntry = undefined;
    const preferred = try IdentityVerifier.getPreferredStoredProfilesForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 20,
            .max_age_seconds = 8,
            .fallback_policy = .allow_stale_latest,
            .storage = IdentityPreferredStoredProfileTargetStorage.init(
                matches_storage[0..],
                preferred_entries[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), preferred.len);
    try std.testing.expectEqualStrings("alice", preferred[0].target.identity);
    try std.testing.expectEqualStrings("gist-alice", preferred[0].preferred.?.entry.matchedClaim().proofSlice());
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, preferred[0].preferred.?.freshness);
    try std.testing.expectEqualStrings("bob", preferred[1].target.identity);
    try std.testing.expectEqualStrings("gist-bob", preferred[1].preferred.?.entry.matchedClaim().proofSlice());
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, preferred[1].preferred.?.freshness);
    try std.testing.expectEqualStrings("carol", preferred[2].target.identity);
    try std.testing.expect(preferred[2].preferred == null);
}

test "identity verifier preferred per-target helper respects require-fresh policy" {
    const alice_pubkey = [_]u8{0xb1} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 1, &alice_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var preferred_entries: [1]IdentityPreferredStoredProfileTargetEntry = undefined;
    const preferred = try IdentityVerifier.getPreferredStoredProfilesForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 20,
            .max_age_seconds = 5,
            .fallback_policy = .require_fresh,
            .storage = IdentityPreferredStoredProfileTargetStorage.init(
                matches_storage[0..],
                preferred_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 1), preferred.len);
    try std.testing.expect(preferred[0].preferred == null);
}

test "identity verifier groups watched-target policy entries by action in stable caller order" {
    const fresh_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const fresh_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-fresh",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-fresh",
                        .expected_text = "npub-fresh",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-stale",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-stale",
                        .expected_text = "npub-stale",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &fresh_pubkey, 45, &fresh_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfilePolicyForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                policy_entries_storage[0..],
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
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, plan.groups[0].action);
    try std.testing.expectEqual(@as(usize, 1), plan.groups[0].entries.len);
    try std.testing.expectEqualStrings("carol", plan.groups[0].entries[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.use_preferred, plan.groups[1].action);
    try std.testing.expectEqual(@as(usize, 1), plan.groups[1].entries.len);
    try std.testing.expectEqualStrings("alice", plan.groups[1].entries[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.use_stale_and_refresh, plan.groups[2].action);
    try std.testing.expectEqual(@as(usize, 1), plan.groups[2].entries.len);
    try std.testing.expectEqualStrings("bob", plan.groups[2].entries[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.refresh_existing, plan.groups[3].action);
    try std.testing.expectEqual(@as(usize, 0), plan.groups[3].entries.len);
}

test "identity verifier target policy inspection stays bounded by caller-owned grouped storage" {
    var store_records: [0]IdentityProfileRecord = .{};
    var store = MemoryIdentityProfileStore.init(store_records[0..]);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [0]IdentityProfileMatch = .{};
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [1]IdentityStoredProfileTargetPolicyEntry = undefined;
    var groups_storage: [3]IdentityStoredProfileTargetPolicyGroup = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        IdentityVerifier.inspectStoredProfilePolicyForTargets(
            store.asStore(),
            .{
                .targets = targets[0..],
                .now_unix_seconds = 50,
                .max_age_seconds = 20,
                .storage = .init(
                    matches_storage[0..],
                    latest_entries_storage[0..],
                    policy_entries_storage[0..],
                    groups_storage[0..],
                ),
            },
        ),
    );
}

test "identity verifier target policy exposes usable preferred targets in stable order" {
    const fresh_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const fresh_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-fresh" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-fresh",
                    .expected_text = "npub-fresh",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &fresh_pubkey, 45, &fresh_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfilePolicyForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                policy_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    const usable = plan.usablePreferredEntries();
    try std.testing.expectEqual(@as(usize, 2), usable.len);
    try std.testing.expectEqualStrings("alice", usable[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.use_preferred, usable[0].action);
    try std.testing.expectEqualStrings("bob", usable[1].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.use_stale_and_refresh, usable[1].action);
}

test "identity verifier target policy exposes verify-now targets in stable caller order" {
    const fresh_pubkey = [_]u8{0xa1} ** 32;
    const fresh_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-fresh" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-fresh",
                    .expected_text = "npub-fresh",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &fresh_pubkey, 45, &fresh_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "dave" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfilePolicyForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                policy_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    const verify_now = plan.verifyNowEntries();
    try std.testing.expectEqual(@as(usize, 2), verify_now.len);
    try std.testing.expectEqualStrings("carol", verify_now[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, verify_now[0].action);
    try std.testing.expectEqualStrings("dave", verify_now[1].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, verify_now[1].action);
}

test "identity verifier target policy exposes refresh-needed targets under explicit fallback policy" {
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [2]IdentityStoredProfileTargetPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfilePolicyForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .fallback_policy = .require_fresh,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                policy_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    const refresh_needed = plan.refreshNeededEntries();
    try std.testing.expectEqual(@as(usize, 1), refresh_needed.len);
    try std.testing.expectEqualStrings("bob", refresh_needed[0].target.identity);
    try std.testing.expectEqual(
        IdentityStoredProfileTargetRuntimeAction.refresh_existing,
        refresh_needed[0].action,
    );
}

test "identity verifier groups watched-target refresh cadence entries by action in stable caller order" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [4]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [4]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
        store.asStore(),
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
    try std.testing.expectEqual(IdentityStoredProfileTargetRefreshCadenceAction.verify_now, plan.groups[0].action);
    try std.testing.expectEqualStrings("dave", plan.groups[0].entries[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRefreshCadenceAction.usable_while_refreshing, plan.groups[2].action);
    try std.testing.expectEqualStrings("carol", plan.groups[2].entries[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRefreshCadenceAction.refresh_soon, plan.groups[3].action);
    try std.testing.expectEqualStrings("bob", plan.groups[3].entries[0].target.identity);
    try std.testing.expectEqual(IdentityStoredProfileTargetRefreshCadenceAction.stable, plan.groups[4].action);
    try std.testing.expectEqualStrings("alice", plan.groups[4].entries[0].target.identity);
}

test "identity verifier refresh cadence inspection stays bounded by caller-owned grouped storage" {
    var store_records: [0]IdentityProfileRecord = .{};
    var store = MemoryIdentityProfileStore.init(store_records[0..]);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [0]IdentityProfileMatch = .{};
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [1]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
            store.asStore(),
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

test "identity verifier refresh cadence next-due selector prefers missing then stale then soon" {
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
        store.asStore(),
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

    try std.testing.expectEqualStrings("dave", plan.nextDueEntry().?.target.identity);

    const due_targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
    };
    var due_latest_entries: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var due_cadence_entries: [2]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var due_groups: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const due_plan = try IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
        store.asStore(),
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
    try std.testing.expectEqualStrings("carol", due_plan.nextDueEntry().?.target.identity);
}

test "identity verifier refresh cadence next-due selector returns null when all targets are stable" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [1]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                cadence_entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );
    try std.testing.expect(plan.nextDueEntry() == null);
}

test "identity verifier refresh cadence exposes typed next-due step" {
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [1]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
        store.asStore(),
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
    try std.testing.expectEqual(IdentityStoredProfileTargetRefreshCadenceAction.refresh_now, step.action);
    try std.testing.expectEqualStrings("carol", step.entry.target.identity);
}

test "identity verifier refresh cadence exposes usable-while-refreshing and refresh-soon views" {
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [2]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(
        store.asStore(),
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
    try std.testing.expectEqualStrings("carol", plan.usableWhileRefreshingEntries()[0].target.identity);
    try std.testing.expectEqual(
        IdentityStoredProfileTargetRefreshCadenceAction.usable_while_refreshing,
        plan.usableWhileRefreshingEntries()[0].action,
    );
    try std.testing.expectEqual(@as(usize, 1), plan.refreshSoonEntries().len);
    try std.testing.expectEqualStrings("bob", plan.refreshSoonEntries()[0].target.identity);
    try std.testing.expectEqual(
        IdentityStoredProfileTargetRefreshCadenceAction.refresh_soon,
        plan.refreshSoonEntries()[0].action,
    );
}

test "identity verifier selects a bounded refresh batch from due watched targets" {
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const batch = try IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
        store.asStore(),
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
    try std.testing.expectEqualStrings("dave", batch.entries[0].target.identity);
    try std.testing.expectEqualStrings("carol", batch.entries[1].target.identity);
    try std.testing.expectEqualStrings("bob", batch.entries[2].target.identity);
}

test "identity verifier refresh batch selection allows zero selected entries" {
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [1]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const batch = try IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
        store.asStore(),
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

test "identity verifier refresh batch exposes next selected entry" {
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const batch = try IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
        store.asStore(),
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

    try std.testing.expectEqualStrings("dave", batch.nextBatchEntry().?.target.identity);
}

test "identity verifier refresh batch exposes typed next selected step" {
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [1]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const batch = try IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
        store.asStore(),
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
    try std.testing.expectEqualStrings("carol", step.entry.target.identity);
}

test "identity verifier refresh batch exposes selected and deferred views" {
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    const batch = try IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(
        store.asStore(),
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
    try std.testing.expectEqualStrings("dave", batch.selectedEntries()[0].target.identity);
    try std.testing.expectEqualStrings("carol", batch.selectedEntries()[1].target.identity);
    try std.testing.expectEqual(@as(usize, 1), batch.deferredEntries().len);
    try std.testing.expectEqualStrings("bob", batch.deferredEntries()[0].target.identity);
}

test "identity verifier inspects watched-target turn policy with mixed actions" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "dave" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [4]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [4]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [4]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [4]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .refresh_soon_age_seconds = 12,
            .max_selected = 3,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(
                matches_storage[0..],
                latest_entries_storage[0..],
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 2), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 0), plan.defer_refresh_count);
    try std.testing.expectEqualStrings("carol", plan.groups[0].entries[0].target.identity);
    try std.testing.expectEqualStrings("dave", plan.groups[0].entries[1].target.identity);
    try std.testing.expectEqualStrings("bob", plan.groups[1].entries[0].target.identity);
    try std.testing.expectEqualStrings("alice", plan.groups[2].entries[0].target.identity);
}

test "identity verifier turn policy tracks deferred refresh entries when selection is bounded" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [4]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [4]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [4]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [4]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.verify_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.refresh_selected_count);
    try std.testing.expectEqual(@as(u32, 1), plan.use_cached_count);
    try std.testing.expectEqual(@as(u32, 1), plan.defer_refresh_count);
    try std.testing.expectEqualStrings("dave", plan.groups[0].entries[0].target.identity);
    try std.testing.expectEqualStrings("carol", plan.groups[1].entries[0].target.identity);
    try std.testing.expectEqualStrings("alice", plan.groups[2].entries[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.groups[3].entries[0].target.identity);
}

test "identity verifier turn policy exposes next work entry" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqualStrings("carol", plan.nextWorkEntry().?.target.identity);
}

test "identity verifier turn policy exposes typed next work step" {
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [1]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [1]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [1]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    const step = plan.nextWorkStep().?;
    try std.testing.expectEqual(IdentityStoredProfileTargetTurnPolicyAction.refresh_selected, step.action);
    try std.testing.expectEqualStrings("bob", step.entry.target.identity);
}

test "identity verifier turn policy exposes verify-now view" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), plan.verifyNowEntries().len);
    try std.testing.expectEqualStrings("carol", plan.verifyNowEntries()[0].target.identity);
    try std.testing.expectEqualStrings("dave", plan.verifyNowEntries()[1].target.identity);
}

test "identity verifier turn policy exposes refresh-selected view" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), plan.refreshSelectedEntries().len);
    try std.testing.expectEqualStrings("bob", plan.refreshSelectedEntries()[0].target.identity);
}

test "identity verifier turn policy exposes work view" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [3]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [3]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), plan.workEntries().len);
    try std.testing.expectEqualStrings("carol", plan.workEntries()[0].target.identity);
    try std.testing.expectEqualStrings("bob", plan.workEntries()[1].target.identity);
}

test "identity verifier turn policy exposes cached and deferred views" {
    const stable_pubkey = [_]u8{0xa1} ** 32;
    const soon_pubkey = [_]u8{0xa2} ** 32;
    const stale_pubkey = [_]u8{0xa3} ** 32;
    const stable_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "alice", .proof = "gist-stable" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/alice/gist-stable",
                    .expected_text = "npub-stable",
                } },
            },
        },
        .verified_count = 1,
    };
    const soon_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "bob", .proof = "gist-soon" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/bob/gist-soon",
                    .expected_text = "npub-soon",
                } },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{ .provider = .github, .identity = "carol", .proof = "gist-stale" },
                .outcome = .{ .verified = .{
                    .proof_url = "https://gist.github.com/carol/gist-stale",
                    .expected_text = "npub-stale",
                } },
            },
        },
        .verified_count = 1,
    };

    var store_records: [3]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stable_pubkey, 45, &stable_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &soon_pubkey, 35, &soon_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "dave" },
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var latest_entries_storage: [4]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var policy_entries_storage: [4]IdentityStoredProfileTargetPolicyEntry = undefined;
    var policy_groups_storage: [4]IdentityStoredProfileTargetPolicyGroup = undefined;
    var cadence_entries_storage: [4]IdentityStoredProfileTargetRefreshCadenceEntry = undefined;
    var cadence_groups_storage: [5]IdentityStoredProfileTargetRefreshCadenceGroup = undefined;
    var entries_storage: [4]IdentityStoredProfileTargetTurnPolicyEntry = undefined;
    var groups_storage: [4]IdentityStoredProfileTargetTurnPolicyGroup = undefined;
    const plan = try IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(
        store.asStore(),
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
                policy_entries_storage[0..],
                policy_groups_storage[0..],
                cadence_entries_storage[0..],
                cadence_groups_storage[0..],
                entries_storage[0..],
                groups_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 1), plan.useCachedEntries().len);
    try std.testing.expectEqualStrings("alice", plan.useCachedEntries()[0].target.identity);
    try std.testing.expectEqual(@as(usize, 1), plan.deferredEntries().len);
    try std.testing.expectEqualStrings("bob", plan.deferredEntries()[0].target.identity);
}

test "identity verifier discovers latest remembered freshness for watched target set in caller order" {
    const alice_pubkey = [_]u8{0xb1} ** 32;
    const bob_pubkey = [_]u8{0xb2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 40, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 5, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const entries = try IdentityVerifier.discoverLatestStoredProfileFreshnessForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = IdentityStoredProfileTargetLatestFreshnessStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );

    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqualStrings("alice", entries[0].target.identity);
    try std.testing.expectEqual(
        IdentityStoredProfileFreshness.fresh,
        entries[0].latest.?.freshness,
    );
    try std.testing.expectEqual(@as(u64, 10), entries[0].latest.?.age_seconds);
    try std.testing.expectEqualStrings(
        "gist-alice",
        entries[0].latest.?.latest.matchedClaim().proofSlice(),
    );

    try std.testing.expectEqualStrings("bob", entries[1].target.identity);
    try std.testing.expectEqual(
        IdentityStoredProfileFreshness.stale,
        entries[1].latest.?.freshness,
    );
    try std.testing.expectEqual(@as(u64, 45), entries[1].latest.?.age_seconds);
    try std.testing.expectEqualStrings(
        "gist-bob",
        entries[1].latest.?.latest.matchedClaim().proofSlice(),
    );

    try std.testing.expectEqualStrings("carol", entries[2].target.identity);
    try std.testing.expect(entries[2].latest == null);
}

test "identity verifier target-set latest freshness preserves caller-owned capacity" {
    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        IdentityVerifier.discoverLatestStoredProfileFreshnessForTargets(
            store.asStore(),
            .{
                .targets = targets[0..],
                .now_unix_seconds = 10,
                .max_age_seconds = 5,
                .storage = IdentityStoredProfileTargetLatestFreshnessStorage.init(
                    matches_storage[0..],
                    entries_storage[0..],
                ),
            },
        ),
    );
}

test "identity verifier target-set latest freshness plan selects first non-fresh watched target in caller order" {
    const alice_pubkey = [_]u8{0xc1} ** 32;
    const bob_pubkey = [_]u8{0xc2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 45, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 5, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const plan = try IdentityVerifier.inspectLatestStoredProfileFreshnessForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stale_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_count);
    const next = plan.nextEntry().?;
    try std.testing.expectEqualStrings("bob", next.target.identity);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, next.latest.?.freshness);
    const next_step = plan.nextStep().?;
    try std.testing.expectEqualStrings("bob", next_step.entry.target.identity);
    try std.testing.expectEqual(
        IdentityStoredProfileFreshness.stale,
        next_step.entry.latest.?.freshness,
    );
}

test "identity verifier target-set latest freshness plan returns null when all watched targets are fresh" {
    const alice_pubkey = [_]u8{0xd1} ** 32;
    const bob_pubkey = [_]u8{0xd2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 45, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 44, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const plan = try IdentityVerifier.inspectLatestStoredProfileFreshnessForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(@as(u32, 2), plan.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), plan.stale_count);
    try std.testing.expectEqual(@as(u32, 0), plan.missing_count);
    try std.testing.expect(plan.nextEntry() == null);
    try std.testing.expect(plan.nextStep() == null);
}

test "identity verifier selects preferred remembered profile across watched targets" {
    const alice_pubkey = [_]u8{0xe1} ** 32;
    const bob_pubkey = [_]u8{0xe2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-alice",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-alice",
                        .expected_text = "npub-alice",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
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

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 45, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 10, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const preferred = (try IdentityVerifier.getPreferredStoredProfileForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    )).?;

    try std.testing.expectEqualStrings("alice", preferred.target.identity);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.fresh, preferred.latest.freshness);
    try std.testing.expectEqualStrings(
        "gist-alice",
        preferred.latest.latest.matchedClaim().proofSlice(),
    );
}

test "identity verifier can fall back to newest stale preferred remembered target" {
    const alice_pubkey = [_]u8{0xf1} ** 32;
    const bob_pubkey = [_]u8{0xf2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 5, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 15, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const preferred = (try IdentityVerifier.getPreferredStoredProfileForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .fallback_policy = .allow_stale_latest,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    )).?;

    try std.testing.expectEqualStrings("bob", preferred.target.identity);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, preferred.latest.freshness);
    try std.testing.expectEqualStrings(
        "gist-new",
        preferred.latest.latest.matchedClaim().proofSlice(),
    );
}

test "identity verifier returns null when watched-target preferred selection requires freshness" {
    const pubkey = [_]u8{0xa1} ** 32;
    const summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-id",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-id",
                        .expected_text = "npub",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 10, &summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const preferred = try IdentityVerifier.getPreferredStoredProfileForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .fallback_policy = .require_fresh,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );
    try std.testing.expect(preferred == null);
}

test "identity verifier target-set refresh plan returns stale watched targets newest first" {
    const alice_pubkey = [_]u8{0xb1} ** 32;
    const bob_pubkey = [_]u8{0xb2} ** 32;
    const alice_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const bob_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &alice_pubkey, 5, &alice_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &bob_pubkey, 15, &bob_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var freshness_entries: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var refresh_entries: [2]IdentityStoredProfileTargetRefreshEntry = undefined;
    const plan = try IdentityVerifier.planStoredProfileRefreshForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .storage = .init(matches_storage[0..], freshness_entries[0..], refresh_entries[0..]),
        },
    );

    try std.testing.expectEqual(@as(usize, 2), plan.entries.len);
    try std.testing.expectEqualStrings("bob", plan.entries[0].target.identity);
    try std.testing.expectEqualStrings("alice", plan.entries[1].target.identity);
    try std.testing.expectEqualStrings("gist-new", plan.entries[0].matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("gist-old", plan.entries[1].matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("bob", plan.nextEntry().?.target.identity);
    try std.testing.expectEqualStrings("bob", plan.nextStep().?.entry.target.identity);
}

test "identity verifier target-set refresh plan returns empty for fresh or missing watched targets" {
    const pubkey = [_]u8{0xc1} ** 32;
    const summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-fresh",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-fresh",
                        .expected_text = "npub-fresh",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 45, &summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "carol" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var freshness_entries: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    var refresh_entries: [1]IdentityStoredProfileTargetRefreshEntry = undefined;
    const plan = try IdentityVerifier.planStoredProfileRefreshForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], freshness_entries[0..], refresh_entries[0..]),
        },
    );

    try std.testing.expectEqual(@as(usize, 0), plan.entries.len);
    try std.testing.expect(plan.nextEntry() == null);
    try std.testing.expect(plan.nextStep() == null);
}

test "identity verifier watched-target runtime prefers verifying the first missing target" {
    const fresh_pubkey = [_]u8{0xa1} ** 32;
    const stale_pubkey = [_]u8{0xa2} ** 32;
    const fresh_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-fresh",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-fresh",
                        .expected_text = "npub-fresh",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-stale",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-stale",
                        .expected_text = "npub-stale",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &fresh_pubkey, 45, &fresh_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "carol" },
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [3]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const runtime = try IdentityVerifier.inspectStoredProfileRuntimeForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, runtime.action);
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.missing_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.selected_index.?);
    try std.testing.expectEqualStrings("carol", runtime.entries[runtime.selected_index.?].target.identity);
    try std.testing.expectEqualStrings("carol", runtime.nextEntry().?.target.identity);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, next_step.action);
    try std.testing.expectEqualStrings("carol", next_step.entry.?.target.identity);
}

test "identity verifier watched-target runtime can prefer the freshest remembered target" {
    const older_pubkey = [_]u8{0xb1} ** 32;
    const newer_pubkey = [_]u8{0xb2} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 40, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 45, &newer_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const runtime = try IdentityVerifier.inspectStoredProfileRuntimeForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.use_preferred, runtime.action);
    try std.testing.expectEqual(@as(u32, 2), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.missing_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.selected_index.?);
    try std.testing.expectEqualStrings("bob", runtime.entries[runtime.selected_index.?].target.identity);
    try std.testing.expectEqualStrings("bob", runtime.nextEntry().?.target.identity);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.use_preferred, next_step.action);
    try std.testing.expectEqualStrings("bob", next_step.entry.?.target.identity);
}

test "identity verifier watched-target runtime can require refresh for stale targets" {
    const older_pubkey = [_]u8{0xc1} ** 32;
    const newer_pubkey = [_]u8{0xc2} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "bob",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/bob/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 5, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 15, &newer_summary);

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
        .{ .provider = .github, .identity = "bob" },
    };
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    const runtime = try IdentityVerifier.inspectStoredProfileRuntimeForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .fallback_policy = .require_fresh,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.refresh_existing, runtime.action);
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.stale_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.missing_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.selected_index.?);
    try std.testing.expectEqualStrings("bob", runtime.entries[runtime.selected_index.?].target.identity);
    try std.testing.expectEqualStrings("bob", runtime.nextEntry().?.target.identity);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(
        IdentityStoredProfileTargetRuntimeAction.refresh_existing,
        next_step.action,
    );
    try std.testing.expectEqualStrings("bob", next_step.entry.?.target.identity);
}

test "identity verifier watched-target runtime handles an empty watched set" {
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    const targets = [_]IdentityStoredProfileTarget{};
    var matches_storage: [0]IdentityProfileMatch = .{};
    var entries_storage: [0]IdentityStoredProfileTargetLatestFreshnessEntry = .{};
    const runtime = try IdentityVerifier.inspectStoredProfileRuntimeForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = .init(matches_storage[0..], entries_storage[0..]),
        },
    );

    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, runtime.action);
    try std.testing.expectEqual(@as(usize, 0), runtime.entries.len);
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.missing_count);
    try std.testing.expect(runtime.nextEntry() == null);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileTargetRuntimeAction.verify_now, next_step.action);
    try std.testing.expect(next_step.entry == null);
}

test "identity verifier selects the newest fresh preferred stored profile" {
    const stale_pubkey = [_]u8{0xb1} ** 32;
    const fresh_pubkey = [_]u8{0xb2} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-stale",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-stale",
                        .expected_text = "npub-stale",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const fresh_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-fresh",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-fresh",
                        .expected_text = "npub-fresh",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &fresh_pubkey, 35, &fresh_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    const preferred = (try IdentityVerifier.getPreferredStoredProfile(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .matches = matches_storage[0..],
        },
    )).?;
    try std.testing.expectEqualSlices(u8, fresh_pubkey[0..], preferred.entry.match.pubkey[0..]);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.fresh, preferred.freshness);
    try std.testing.expectEqual(@as(u64, 15), preferred.age_seconds);
    try std.testing.expectEqualStrings("gist-fresh", preferred.entry.matchedClaim().proofSlice());
}

test "identity verifier can fall back to the newest stale preferred stored profile" {
    const older_pubkey = [_]u8{0xc1} ** 32;
    const newer_pubkey = [_]u8{0xc2} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 5, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 15, &newer_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    const preferred = (try IdentityVerifier.getPreferredStoredProfile(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .matches = matches_storage[0..],
            .fallback_policy = .allow_stale_latest,
        },
    )).?;
    try std.testing.expectEqualSlices(u8, newer_pubkey[0..], preferred.entry.match.pubkey[0..]);
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@as(u64, 35), preferred.age_seconds);
}

test "identity verifier returns null when preferred stored profile requires freshness" {
    const pubkey = [_]u8{0xd1} ** 32;
    const summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-id",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-id",
                        .expected_text = "npub",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 10, &summary);

    var matches_storage: [1]IdentityProfileMatch = undefined;
    const preferred = try IdentityVerifier.getPreferredStoredProfile(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .matches = matches_storage[0..],
            .fallback_policy = .require_fresh,
        },
    );
    try std.testing.expect(preferred == null);
}

test "identity verifier runtime policy requests verification when no remembered profile exists" {
    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [1]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;

    const runtime = try IdentityVerifier.inspectStoredProfileRuntime(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = IdentityStoredProfileRuntimeStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(IdentityStoredProfileRuntimeAction.verify_now, runtime.action);
    try std.testing.expectEqual(@as(usize, 0), runtime.entries.len);
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    try std.testing.expect(runtime.preferredEntry() == null);
    try std.testing.expect(runtime.nextEntry() == null);
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileRuntimeAction.verify_now, next_step.action);
    try std.testing.expect(next_step.entry == null);
}

test "identity verifier runtime policy prefers a fresh remembered profile" {
    const stale_pubkey = [_]u8{0xe1} ** 32;
    const fresh_pubkey = [_]u8{0xe2} ** 32;
    const stale_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-stale",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-stale",
                        .expected_text = "npub-stale",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const fresh_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-fresh",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-fresh",
                        .expected_text = "npub-fresh",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &stale_pubkey, 5, &stale_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &fresh_pubkey, 35, &fresh_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    const runtime = try IdentityVerifier.inspectStoredProfileRuntime(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = IdentityStoredProfileRuntimeStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(IdentityStoredProfileRuntimeAction.use_preferred, runtime.action);
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileFreshness.fresh, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqual(IdentityStoredProfileRuntimeAction.use_preferred, next_step.action);
    try std.testing.expectEqual(
        IdentityStoredProfileFreshness.fresh,
        next_step.entry.?.freshness,
    );
    try std.testing.expectEqualSlices(u8, fresh_pubkey[0..], preferred.entry.match.pubkey[0..]);
    try std.testing.expectEqualStrings("gist-fresh", preferred.matchedClaim().proofSlice());
}

test "identity verifier runtime policy can use stale profile and refresh" {
    const older_pubkey = [_]u8{0xf1} ** 32;
    const newer_pubkey = [_]u8{0xf2} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 5, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 15, &newer_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    var entries_storage: [2]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    const runtime = try IdentityVerifier.inspectStoredProfileRuntime(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .fallback_policy = .allow_stale_latest,
            .storage = IdentityStoredProfileRuntimeStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(
        IdentityStoredProfileRuntimeAction.use_stale_and_refresh,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqual(
        IdentityStoredProfileRuntimeAction.use_stale_and_refresh,
        next_step.action,
    );
    try std.testing.expectEqual(
        IdentityStoredProfileFreshness.stale,
        next_step.entry.?.freshness,
    );
    try std.testing.expectEqualSlices(u8, newer_pubkey[0..], preferred.entry.match.pubkey[0..]);
}

test "identity verifier runtime policy can require refresh for stale remembered profiles" {
    const pubkey = [_]u8{0xa1} ** 32;
    const summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-id",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-id",
                        .expected_text = "npub",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 10, &summary);

    var matches_storage: [1]IdentityProfileMatch = undefined;
    var entries_storage: [1]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    const runtime = try IdentityVerifier.inspectStoredProfileRuntime(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .fallback_policy = .require_fresh,
            .storage = IdentityStoredProfileRuntimeStorage.init(
                matches_storage[0..],
                entries_storage[0..],
            ),
        },
    );
    try std.testing.expectEqual(
        IdentityStoredProfileRuntimeAction.refresh_existing,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    const next_step = runtime.nextStep();
    try std.testing.expectEqual(IdentityStoredProfileFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqual(
        IdentityStoredProfileRuntimeAction.refresh_existing,
        next_step.action,
    );
    try std.testing.expectEqual(
        IdentityStoredProfileFreshness.stale,
        next_step.entry.?.freshness,
    );
    try std.testing.expectEqualStrings("gist-id", preferred.matchedClaim().proofSlice());
}

test "identity verifier refresh plan returns stale remembered profiles newest first" {
    const older_pubkey = [_]u8{0xc1} ** 32;
    const newer_pubkey = [_]u8{0xc2} ** 32;
    const older_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-old",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-old",
                        .expected_text = "npub-old",
                    },
                },
            },
        },
        .verified_count = 1,
    };
    const newer_summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-new",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-new",
                        .expected_text = "npub-new",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [2]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &older_pubkey, 5, &older_summary);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &newer_pubkey, 15, &newer_summary);

    var matches_storage: [2]IdentityProfileMatch = undefined;
    var freshness_storage: [2]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [2]IdentityStoredProfileRefreshEntry = undefined;
    const plan = try IdentityVerifier.planStoredProfileRefresh(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 10,
            .storage = IdentityStoredProfileRefreshStorage.init(
                matches_storage[0..],
                freshness_storage[0..],
                refresh_entries[0..],
            ),
        },
    );
    try std.testing.expectEqual(@as(usize, 2), plan.entries.len);
    try std.testing.expectEqualStrings("gist-new", plan.entries[0].matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("gist-old", plan.entries[1].matchedClaim().proofSlice());
    try std.testing.expectEqual(@as(u64, 35), plan.entries[0].entry.age_seconds);
    try std.testing.expectEqual(@as(u64, 45), plan.entries[1].entry.age_seconds);
    try std.testing.expectEqualStrings("gist-new", plan.nextEntry().?.matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("gist-new", plan.newestEntry().?.matchedClaim().proofSlice());
    try std.testing.expectEqualStrings("gist-new", plan.nextStep().?.entry.matchedClaim().proofSlice());
}

test "identity verifier refresh plan returns empty when remembered profiles are fresh" {
    const pubkey = [_]u8{0xd1} ** 32;
    const summary = IdentityProfileVerificationSummary{
        .claims = &[_]IdentityClaimVerification{
            .{
                .claim = .{
                    .provider = .github,
                    .identity = "alice",
                    .proof = "gist-fresh",
                },
                .outcome = .{
                    .verified = .{
                        .proof_url = "https://gist.github.com/alice/gist-fresh",
                        .expected_text = "npub-fresh",
                    },
                },
            },
        },
        .verified_count = 1,
    };

    var store_records: [1]IdentityProfileRecord = undefined;
    var store = MemoryIdentityProfileStore.init(store_records[0..]);
    _ = try IdentityVerifier.rememberProfileSummary(store.asStore(), &pubkey, 40, &summary);

    var matches_storage: [1]IdentityProfileMatch = undefined;
    var freshness_storage: [1]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [1]IdentityStoredProfileRefreshEntry = undefined;
    const plan = try IdentityVerifier.planStoredProfileRefresh(
        store.asStore(),
        .{
            .provider = .github,
            .identity = "alice",
            .now_unix_seconds = 50,
            .max_age_seconds = 20,
            .storage = IdentityStoredProfileRefreshStorage.init(
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

test "identity verifier returns typed error for inconsistent remembered profile store" {
    const InconsistentIdentityStore = struct {
        fn asStore(self: *@This()) IdentityProfileStore {
            return .{ .ctx = self, .vtable = &vtable };
        }

        fn put(
            _: *anyopaque,
            _: *const [32]u8,
            _: u64,
            _: *const IdentityProfileVerificationSummary,
        ) IdentityProfileStoreError!IdentityProfileStorePutOutcome {
            return .stored;
        }

        fn get(
            _: *anyopaque,
            _: *const [32]u8,
        ) IdentityProfileStoreError!?IdentityProfileRecord {
            return null;
        }

        fn find(
            _: *anyopaque,
            _: noztr.nip39_external_identities.IdentityProvider,
            _: []const u8,
            out: []IdentityProfileMatch,
        ) IdentityProfileStoreError!usize {
            out[0] = .{
                .pubkey = [_]u8{0x92} ** 32,
                .created_at = 7,
            };
            return 1;
        }

        const vtable = IdentityProfileStoreVTable{
            .put_profile_summary = put,
            .get_profile = get,
            .find_profiles = find,
        };
    };

    var store = InconsistentIdentityStore{};
    var matches: [1]IdentityProfileMatch = undefined;
    var entries: [1]IdentityStoredProfileDiscoveryFreshnessEntry = undefined;
    try std.testing.expectError(
        error.InconsistentStoreData,
        IdentityVerifier.discoverStoredProfileEntriesWithFreshness(
            store.asStore(),
            .{
                .provider = .github,
                .identity = "alice",
                .now_unix_seconds = 9,
                .max_age_seconds = 5,
                .storage = .init(matches[0..], entries[0..]),
            },
        ),
    );

    const targets = [_]IdentityStoredProfileTarget{
        .{ .provider = .github, .identity = "alice" },
    };
    var target_entries: [1]IdentityStoredProfileTargetLatestFreshnessEntry = undefined;
    try std.testing.expectError(
        error.InconsistentStoreData,
        IdentityVerifier.discoverLatestStoredProfileFreshnessForTargets(
            store.asStore(),
            .{
                .targets = targets[0..],
                .now_unix_seconds = 9,
                .max_age_seconds = 5,
                .storage = .init(matches[0..], target_entries[0..]),
            },
        ),
    );
}

const TestHttpResponse = struct {
    url: []const u8,
    body: []const u8 = "",
    fail_with: ?transport.HttpError = null,
};

const TestMultiHttp = struct {
    responses: []const TestHttpResponse,

    fn init(responses: []const TestHttpResponse) TestMultiHttp {
        return .{ .responses = responses };
    }

    fn client(self: *TestMultiHttp) transport.HttpClient {
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
        const self: *TestMultiHttp = @ptrCast(@alignCast(ctx));
        for (self.responses) |response| {
            if (!std.mem.eql(u8, request.url, response.url)) continue;
            if (response.fail_with) |failure| return failure;
            if (response.body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..response.body.len], response.body);
            return out[0..response.body.len];
        }
        return error.NotFound;
    }
};
