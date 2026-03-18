const std = @import("std");
const noztr = @import("noztr");
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

pub const OpenTimestampsVerificationStorePutOutcome = enum {
    stored,
    updated,
};

pub const OpenTimestampsVerificationStoreError = error{
    ProofUrlTooLong,
    RelayUrlTooLong,
    StoreFull,
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

pub const OpenTimestampsStoredVerificationRecord = struct {
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

    pub fn proofUrl(self: *const OpenTimestampsStoredVerificationRecord) []const u8 {
        return self.proof_url[0..self.proof_url_len];
    }

    pub fn relayUrl(self: *const OpenTimestampsStoredVerificationRecord) ?[]const u8 {
        if (self.relay_url_len == 0) return null;
        return self.relay_url[0..self.relay_url_len];
    }
};

pub const OpenTimestampsStoredVerificationMatch = struct {
    attestation_event_id: [32]u8,
    created_at: u64,
};

pub const OpenTimestampsVerificationDiscoveryRequest = struct {
    target_event_id: *const [32]u8,
    results: []OpenTimestampsStoredVerificationMatch,
};

pub const OpenTimestampsStoredVerificationDiscoveryEntry = struct {
    match: OpenTimestampsStoredVerificationMatch,
    verification: OpenTimestampsStoredVerificationRecord,
};

pub const OpenTimestampsStoredVerificationDiscoveryStorage = struct {
    matches: []OpenTimestampsStoredVerificationMatch,
    entries: []OpenTimestampsStoredVerificationDiscoveryEntry,

    pub fn init(
        matches: []OpenTimestampsStoredVerificationMatch,
        entries: []OpenTimestampsStoredVerificationDiscoveryEntry,
    ) OpenTimestampsStoredVerificationDiscoveryStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const OpenTimestampsStoredVerificationDiscoveryRequest = struct {
    target_event_id: *const [32]u8,
    storage: OpenTimestampsStoredVerificationDiscoveryStorage,
};

pub const OpenTimestampsLatestStoredVerificationRequest = struct {
    target_event_id: *const [32]u8,
    matches: []OpenTimestampsStoredVerificationMatch,
};

pub const OpenTimestampsStoredVerificationFreshness = enum {
    fresh,
    stale,
};

pub const OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = struct {
    entry: OpenTimestampsStoredVerificationDiscoveryEntry,
    freshness: OpenTimestampsStoredVerificationFreshness,
    age_seconds: u64,
};

pub const OpenTimestampsStoredVerificationDiscoveryFreshnessStorage = struct {
    matches: []OpenTimestampsStoredVerificationMatch,
    entries: []OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,

    pub fn init(
        matches: []OpenTimestampsStoredVerificationMatch,
        entries: []OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,
    ) OpenTimestampsStoredVerificationDiscoveryFreshnessStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const OpenTimestampsStoredVerificationDiscoveryFreshnessRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: OpenTimestampsStoredVerificationDiscoveryFreshnessStorage,
};

pub const OpenTimestampsStoredVerificationFallbackPolicy = enum {
    require_fresh,
    allow_stale_latest,
};

pub const OpenTimestampsStoredVerificationRuntimeAction = enum {
    verify_now,
    refresh_existing,
    use_preferred,
    use_stale_and_refresh,
};

pub const OpenTimestampsStoredVerificationRuntimeStorage = struct {
    matches: []OpenTimestampsStoredVerificationMatch,
    entries: []OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,

    pub fn init(
        matches: []OpenTimestampsStoredVerificationMatch,
        entries: []OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,
    ) OpenTimestampsStoredVerificationRuntimeStorage {
        return .{
            .matches = matches,
            .entries = entries,
        };
    }
};

pub const OpenTimestampsStoredVerificationRuntimeRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    fallback_policy: OpenTimestampsStoredVerificationFallbackPolicy = .allow_stale_latest,
    storage: OpenTimestampsStoredVerificationRuntimeStorage,
};

pub const OpenTimestampsStoredVerificationRuntimePlan = struct {
    action: OpenTimestampsStoredVerificationRuntimeAction,
    entries: []const OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,
    preferred_index: ?u32 = null,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,

    pub fn preferredEntry(
        self: *const OpenTimestampsStoredVerificationRuntimePlan,
    ) ?*const OpenTimestampsStoredVerificationDiscoveryFreshnessEntry {
        const index = self.preferred_index orelse return null;
        const usize_index: usize = @intCast(index);
        if (usize_index >= self.entries.len) return null;
        return &self.entries[usize_index];
    }

    pub fn nextEntry(
        self: *const OpenTimestampsStoredVerificationRuntimePlan,
    ) ?*const OpenTimestampsStoredVerificationDiscoveryFreshnessEntry {
        return switch (self.action) {
            .verify_now => null,
            .refresh_existing, .use_preferred, .use_stale_and_refresh => self.preferredEntry(),
        };
    }
};

pub const OpenTimestampsStoredVerificationRefreshEntry = struct {
    entry: OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,
};

pub const OpenTimestampsStoredVerificationRefreshStorage = struct {
    matches: []OpenTimestampsStoredVerificationMatch,
    freshness_entries: []OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,
    entries: []OpenTimestampsStoredVerificationRefreshEntry,

    pub fn init(
        matches: []OpenTimestampsStoredVerificationMatch,
        freshness_entries: []OpenTimestampsStoredVerificationDiscoveryFreshnessEntry,
        entries: []OpenTimestampsStoredVerificationRefreshEntry,
    ) OpenTimestampsStoredVerificationRefreshStorage {
        return .{
            .matches = matches,
            .freshness_entries = freshness_entries,
            .entries = entries,
        };
    }
};

pub const OpenTimestampsStoredVerificationRefreshRequest = struct {
    target_event_id: *const [32]u8,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: OpenTimestampsStoredVerificationRefreshStorage,
};

pub const OpenTimestampsStoredVerificationRefreshPlan = struct {
    entries: []const OpenTimestampsStoredVerificationRefreshEntry,

    pub fn newestEntry(
        self: *const OpenTimestampsStoredVerificationRefreshPlan,
    ) ?*const OpenTimestampsStoredVerificationRefreshEntry {
        if (self.entries.len == 0) return null;
        return &self.entries[0];
    }
};

pub const OpenTimestampsVerificationStoreVTable = struct {
    put_remote_verification: *const fn (
        ctx: *anyopaque,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        verification: *const OpenTimestampsRemoteVerification,
    ) OpenTimestampsVerificationStoreError!OpenTimestampsVerificationStorePutOutcome,
    get_verification: *const fn (
        ctx: *anyopaque,
        attestation_event_id: *const [32]u8,
    ) OpenTimestampsVerificationStoreError!?OpenTimestampsStoredVerificationRecord,
    find_verifications: *const fn (
        ctx: *anyopaque,
        target_event_id: *const [32]u8,
        out: []OpenTimestampsStoredVerificationMatch,
    ) OpenTimestampsVerificationStoreError!usize,
};

pub const OpenTimestampsVerificationStore = struct {
    ctx: *anyopaque,
    vtable: *const OpenTimestampsVerificationStoreVTable,

    pub fn putRemoteVerification(
        self: OpenTimestampsVerificationStore,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        verification: *const OpenTimestampsRemoteVerification,
    ) OpenTimestampsVerificationStoreError!OpenTimestampsVerificationStorePutOutcome {
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
    ) OpenTimestampsVerificationStoreError!?OpenTimestampsStoredVerificationRecord {
        return self.vtable.get_verification(self.ctx, attestation_event_id);
    }

    pub fn findVerifications(
        self: OpenTimestampsVerificationStore,
        target_event_id: *const [32]u8,
        out: []OpenTimestampsStoredVerificationMatch,
    ) OpenTimestampsVerificationStoreError![]const OpenTimestampsStoredVerificationMatch {
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
    records: []OpenTimestampsStoredVerificationRecord,
    count: usize = 0,

    pub fn init(records: []OpenTimestampsStoredVerificationRecord) MemoryOpenTimestampsVerificationStore {
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
        verification: *const OpenTimestampsRemoteVerification,
    ) OpenTimestampsVerificationStoreError!OpenTimestampsVerificationStorePutOutcome {
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
    ) OpenTimestampsVerificationStoreError!?OpenTimestampsStoredVerificationRecord {
        const index = self.findIndex(attestation_event_id) orelse return null;
        return self.records[index];
    }

    pub fn findVerifications(
        self: *MemoryOpenTimestampsVerificationStore,
        target_event_id: *const [32]u8,
        out: []OpenTimestampsStoredVerificationMatch,
    ) OpenTimestampsVerificationStoreError![]const OpenTimestampsStoredVerificationMatch {
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

pub const OpenTimestampsRemoteVerification = struct {
    proof_url: []const u8,
    verification: OpenTimestampsVerification,
};

pub const OpenTimestampsFetchFailure = struct {
    proof_url: []const u8,
    attestation: noztr.nip03_opentimestamps.OpenTimestampsAttestation,
    cause: transport.HttpError,
};

pub const OpenTimestampsRemoteInvalidProof = struct {
    proof_url: []const u8,
    invalid: OpenTimestampsInvalidProof,
};

pub const OpenTimestampsRemoteInvalidAttestation = struct {
    proof_url: []const u8,
    invalid: OpenTimestampsInvalidAttestation,
};

pub const OpenTimestampsRemoteVerificationOutcome = union(enum) {
    verified: OpenTimestampsRemoteVerification,
    target_mismatch: OpenTimestampsRemoteVerification,
    invalid_attestation: OpenTimestampsRemoteInvalidAttestation,
    invalid_local_proof: OpenTimestampsRemoteInvalidProof,
    fetch_failed: OpenTimestampsFetchFailure,
};

pub const OpenTimestampsRememberedRemoteVerification = struct {
    verification: OpenTimestampsRemoteVerification,
    store_outcome: OpenTimestampsVerificationStorePutOutcome,
};

pub const OpenTimestampsRememberedRemoteVerificationError =
    OpenTimestampsVerifierError ||
    OpenTimestampsProofStoreError ||
    OpenTimestampsVerificationStoreError;

pub const OpenTimestampsStoredVerificationDiscoveryError =
    OpenTimestampsVerificationStoreError || error{BufferTooSmall};

pub const OpenTimestampsRememberedRemoteVerificationOutcome = union(enum) {
    verified: OpenTimestampsRememberedRemoteVerification,
    target_mismatch: OpenTimestampsRemoteVerification,
    invalid_attestation: OpenTimestampsRemoteInvalidAttestation,
    invalid_local_proof: OpenTimestampsRemoteInvalidProof,
    fetch_failed: OpenTimestampsFetchFailure,
};

pub const OpenTimestampsVerifier = struct {
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
    ) OpenTimestampsVerifierError!OpenTimestampsRemoteVerificationOutcome {
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
    ) (OpenTimestampsVerifierError || OpenTimestampsProofStoreError)!OpenTimestampsRemoteVerificationOutcome {
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
    ) OpenTimestampsRememberedRemoteVerificationError!OpenTimestampsRememberedRemoteVerificationOutcome {
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
        verification: *const OpenTimestampsRemoteVerification,
    ) OpenTimestampsVerificationStoreError!OpenTimestampsVerificationStorePutOutcome {
        return verification_store.putRemoteVerification(target_event, attestation_event, verification);
    }

    pub fn getStoredVerification(
        verification_store: OpenTimestampsVerificationStore,
        attestation_event_id: *const [32]u8,
    ) OpenTimestampsVerificationStoreError!?OpenTimestampsStoredVerificationRecord {
        return verification_store.getVerification(attestation_event_id);
    }

    pub fn discoverStoredVerifications(
        verification_store: OpenTimestampsVerificationStore,
        request: OpenTimestampsVerificationDiscoveryRequest,
    ) OpenTimestampsVerificationStoreError![]const OpenTimestampsStoredVerificationMatch {
        return verification_store.findVerifications(request.target_event_id, request.results);
    }

    pub fn discoverStoredVerificationEntries(
        verification_store: OpenTimestampsVerificationStore,
        request: OpenTimestampsStoredVerificationDiscoveryRequest,
    ) OpenTimestampsStoredVerificationDiscoveryError![]const OpenTimestampsStoredVerificationDiscoveryEntry {
        const matches = try verification_store.findVerifications(
            request.target_event_id,
            request.storage.matches,
        );
        if (matches.len > request.storage.entries.len) return error.BufferTooSmall;

        for (matches, 0..) |match, index| {
            const verification = (try verification_store.getVerification(&match.attestation_event_id)) orelse unreachable;
            request.storage.entries[index] = .{
                .match = match,
                .verification = verification,
            };
        }
        return request.storage.entries[0..matches.len];
    }

    pub fn getLatestStoredVerification(
        verification_store: OpenTimestampsVerificationStore,
        request: OpenTimestampsLatestStoredVerificationRequest,
    ) OpenTimestampsVerificationStoreError!?OpenTimestampsStoredVerificationRecord {
        const matches = try verification_store.findVerifications(request.target_event_id, request.matches);
        if (matches.len == 0) return null;

        var latest = matches[0];
        for (matches[1..]) |match| {
            if (match.created_at > latest.created_at) latest = match;
        }
        return verification_store.getVerification(&latest.attestation_event_id);
    }

    pub fn discoverStoredVerificationEntriesWithFreshness(
        verification_store: OpenTimestampsVerificationStore,
        request: OpenTimestampsStoredVerificationDiscoveryFreshnessRequest,
    ) OpenTimestampsStoredVerificationDiscoveryError![]const OpenTimestampsStoredVerificationDiscoveryFreshnessEntry {
        const matches = try verification_store.findVerifications(
            request.target_event_id,
            request.storage.matches,
        );
        if (matches.len > request.storage.entries.len) return error.BufferTooSmall;

        for (matches, 0..) |match, index| {
            const verification =
                (try verification_store.getVerification(&match.attestation_event_id)) orelse unreachable;
            const age_seconds = if (request.now_unix_seconds > match.created_at)
                request.now_unix_seconds - match.created_at
            else
                0;
            request.storage.entries[index] = .{
                .entry = .{
                    .match = match,
                    .verification = verification,
                },
                .freshness = if (age_seconds <= request.max_age_seconds) .fresh else .stale,
                .age_seconds = age_seconds,
            };
        }
        return request.storage.entries[0..matches.len];
    }

    pub fn inspectStoredVerificationRuntime(
        verification_store: OpenTimestampsVerificationStore,
        request: OpenTimestampsStoredVerificationRuntimeRequest,
    ) OpenTimestampsStoredVerificationDiscoveryError!OpenTimestampsStoredVerificationRuntimePlan {
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
        request: OpenTimestampsStoredVerificationRefreshRequest,
    ) OpenTimestampsStoredVerificationDiscoveryError!OpenTimestampsStoredVerificationRefreshPlan {
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
};

fn verifyFetchedProof(
    proof_url: []const u8,
    attestation: noztr.nip03_opentimestamps.OpenTimestampsAttestation,
    proof: []const u8,
) OpenTimestampsVerifierError!OpenTimestampsRemoteVerificationOutcome {
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
    record: *OpenTimestampsStoredVerificationRecord,
    target_event: *const noztr.nip01_event.Event,
    attestation_event: *const noztr.nip01_event.Event,
    verification: *const OpenTimestampsRemoteVerification,
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
    verification: *const OpenTimestampsRemoteVerification,
) OpenTimestampsVerificationStoreError!OpenTimestampsVerificationStorePutOutcome {
    const self: *MemoryOpenTimestampsVerificationStore = @ptrCast(@alignCast(ctx));
    return self.putRemoteVerification(target_event, attestation_event, verification);
}

fn verificationStoreGet(
    ctx: *anyopaque,
    attestation_event_id: *const [32]u8,
) OpenTimestampsVerificationStoreError!?OpenTimestampsStoredVerificationRecord {
    const self: *MemoryOpenTimestampsVerificationStore = @ptrCast(@alignCast(ctx));
    return self.getVerification(attestation_event_id);
}

fn verificationStoreFind(
    ctx: *anyopaque,
    target_event_id: *const [32]u8,
    out: []OpenTimestampsStoredVerificationMatch,
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
    var verification_store_records: [2]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{ .{}, .{} };
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
    try std.testing.expectEqual(OpenTimestampsVerificationStorePutOutcome.stored, remembered.verified.store_outcome);
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        remembered.verified.verification.proof_url,
    );

    var discovery_matches: [2]OpenTimestampsStoredVerificationMatch = undefined;
    var discovery_entries: [2]OpenTimestampsStoredVerificationDiscoveryEntry = undefined;
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

    var latest_matches: [2]OpenTimestampsStoredVerificationMatch = undefined;
    const latest = (try OpenTimestampsVerifier.getLatestStoredVerification(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .matches = latest_matches[0..],
        },
    )).?;
    try std.testing.expectEqualStrings("https://proof.example/hello.ots", latest.proofUrl());
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
    var verification_store_records: [1]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{.{}};
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
    var empty_verification_store_records: [0]OpenTimestampsStoredVerificationRecord = .{};
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

    var verification_store_records: [2]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var first_decoded_proof: [128]u8 = undefined;
    var second_decoded_proof: [128]u8 = undefined;
    const verification: OpenTimestampsRemoteVerification = .{
        .proof_url = "https://proof.example/hello.ots",
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                first_decoded_proof[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
    };
    const second_verification: OpenTimestampsRemoteVerification = .{
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

    var discovery_matches: [2]OpenTimestampsStoredVerificationMatch = undefined;
    var discovery_entries: [1]OpenTimestampsStoredVerificationDiscoveryEntry = undefined;
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

    var verification_store_records: [2]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{ .{}, .{} };
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    var decoded_proof_a: [128]u8 = undefined;
    var decoded_proof_b: [128]u8 = undefined;
    const first_verification: OpenTimestampsRemoteVerification = .{
        .proof_url = "https://proof.example/old.ots",
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_a[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
    };
    const second_verification: OpenTimestampsRemoteVerification = .{
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

    var discovery_matches: [2]OpenTimestampsStoredVerificationMatch = undefined;
    var freshness_entries: [2]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
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
    try std.testing.expectEqual(OpenTimestampsStoredVerificationFreshness.stale, entries[0].freshness);
    try std.testing.expectEqual(@as(u64, 10), entries[0].age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/old.ots", entries[0].entry.verification.proofUrl());
    try std.testing.expectEqualSlices(
        u8,
        &second_attestation_fixture.event.id,
        &entries[1].entry.match.attestation_event_id,
    );
    try std.testing.expectEqual(OpenTimestampsStoredVerificationFreshness.fresh, entries[1].freshness);
    try std.testing.expectEqual(@as(u64, 3), entries[1].age_seconds);
    try std.testing.expectEqualStrings("https://proof.example/new.ots", entries[1].entry.verification.proofUrl());
}

test "opentimestamps verifier returns empty remembered freshness discovery for missing verifications" {
    var verification_store_records: [1]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    const target_event = try testTargetEvent(1, "hello");
    var discovery_matches: [1]OpenTimestampsStoredVerificationMatch = undefined;
    var freshness_entries: [1]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;

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
    var verification_store_records: [1]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    const target_event = try testTargetEvent(1, "hello");
    var runtime_matches: [1]OpenTimestampsStoredVerificationMatch = undefined;
    var runtime_entries: [1]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;

    const runtime = try OpenTimestampsVerifier.inspectStoredVerificationRuntime(
        verification_store.asStore(),
        .{
            .target_event_id = &target_event.id,
            .now_unix_seconds = 12,
            .max_age_seconds = 5,
            .storage = .init(runtime_matches[0..], runtime_entries[0..]),
        },
    );
    try std.testing.expectEqual(OpenTimestampsStoredVerificationRuntimeAction.verify_now, runtime.action);
    try std.testing.expectEqual(@as(usize, 0), runtime.entries.len);
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 0), runtime.stale_count);
    try std.testing.expect(runtime.preferredEntry() == null);
    try std.testing.expect(runtime.nextEntry() == null);
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
    const stale_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_a[0..],
                &first_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const fresh_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof_b[0..],
                &second_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{ .{}, .{} };
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

    var runtime_matches: [2]OpenTimestampsStoredVerificationMatch = undefined;
    var runtime_entries: [2]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
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
        OpenTimestampsStoredVerificationRuntimeAction.use_preferred,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 1), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    try std.testing.expectEqual(OpenTimestampsStoredVerificationFreshness.fresh, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        preferred.entry.verification.proofUrl(),
    );
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
    const older_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                older_decoded_proof[0..],
                &older_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const newer_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                newer_decoded_proof[0..],
                &newer_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{ .{}, .{} };
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

    var runtime_matches: [2]OpenTimestampsStoredVerificationMatch = undefined;
    var runtime_entries: [2]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
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
        OpenTimestampsStoredVerificationRuntimeAction.use_stale_and_refresh,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 2), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    try std.testing.expectEqual(OpenTimestampsStoredVerificationFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
    try std.testing.expectEqualStrings(
        "https://proof.example/new.ots",
        preferred.entry.verification.proofUrl(),
    );
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
    const remembered_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof[0..],
                &attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };

    var verification_store_records: [1]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &attestation_fixture.event,
        &remembered_verification,
    );

    var runtime_matches: [1]OpenTimestampsStoredVerificationMatch = undefined;
    var runtime_entries: [1]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
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
        OpenTimestampsStoredVerificationRuntimeAction.refresh_existing,
        runtime.action,
    );
    try std.testing.expectEqual(@as(u32, 0), runtime.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), runtime.stale_count);
    const preferred = runtime.preferredEntry().?;
    const next = runtime.nextEntry().?;
    try std.testing.expectEqual(OpenTimestampsStoredVerificationFreshness.stale, preferred.freshness);
    try std.testing.expectEqual(@intFromPtr(preferred), @intFromPtr(next));
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
    const older_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                older_decoded_proof[0..],
                &older_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/old.ots",
    };
    const newer_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                newer_decoded_proof[0..],
                &newer_attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/new.ots",
    };

    var verification_store_records: [2]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{ .{}, .{} };
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

    var matches_storage: [2]OpenTimestampsStoredVerificationMatch = undefined;
    var freshness_storage: [2]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [2]OpenTimestampsStoredVerificationRefreshEntry = undefined;
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
        plan.newestEntry().?.entry.entry.verification.proofUrl(),
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
    const remembered_verification: OpenTimestampsRemoteVerification = .{
        .verification = .{
            .attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
                decoded_proof[0..],
                &attestation_fixture.event,
            ),
            .proof = proof[0..testLocalProofLen(1)],
        },
        .proof_url = "https://proof.example/fresh.ots",
    };

    var verification_store_records: [1]OpenTimestampsStoredVerificationRecord =
        [_]OpenTimestampsStoredVerificationRecord{.{}};
    var verification_store = MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);
    _ = try OpenTimestampsVerifier.rememberRemoteVerification(
        verification_store.asStore(),
        &target_event,
        &attestation_fixture.event,
        &remembered_verification,
    );

    var matches_storage: [1]OpenTimestampsStoredVerificationMatch = undefined;
    var freshness_storage: [1]OpenTimestampsStoredVerificationDiscoveryFreshnessEntry = undefined;
    var refresh_entries: [1]OpenTimestampsStoredVerificationRefreshEntry = undefined;
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
    try std.testing.expect(plan.newestEntry() == null);
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

const TestAttestationFixture = struct {
    target_id_hex: [64]u8,
    target_kind: u32,
    event_tag: noztr.nip03_opentimestamps.BuiltTag,
    kind_tag: noztr.nip03_opentimestamps.BuiltTag,
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
