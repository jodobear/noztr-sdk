const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

pub const Nip05ResolverError = noztr.nip05_identity.IdentityError;

pub const Nip05Resolution = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    profile: noztr.nip05_identity.Profile,
};

pub const Nip05LookupStorage = struct {
    lookup_url_buffer: []u8,
    body_buffer: []u8,

    pub fn init(lookup_url_buffer: []u8, body_buffer: []u8) Nip05LookupStorage {
        return .{
            .lookup_url_buffer = lookup_url_buffer,
            .body_buffer = body_buffer,
        };
    }
};

pub const Nip05LookupRequest = struct {
    address_text: []const u8,
    storage: Nip05LookupStorage,
    scratch: std.mem.Allocator,
};

pub const Nip05FetchFailure = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    cause: transport.HttpError,
};

pub const Nip05VerificationMismatch = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    expected_pubkey: [32]u8,
    profile: ?noztr.nip05_identity.Profile = null,
};

pub const Nip05LookupOutcome = union(enum) {
    resolved: Nip05Resolution,
    fetch_failed: Nip05FetchFailure,
};

pub const Nip05VerificationOutcome = union(enum) {
    verified: Nip05Resolution,
    mismatch: Nip05VerificationMismatch,
    fetch_failed: Nip05FetchFailure,
};

pub const nip05_remembered_resolution_address_max_bytes: u16 =
    noztr.limits.tag_item_bytes_max + 2;
pub const nip05_remembered_resolution_lookup_url_max_bytes: u16 =
    noztr.limits.nip05_identifier_bytes_max + 64;

const StorePutOutcome = enum {
    stored,
    updated,
    ignored_stale,
};

const StoreError = error{
    AddressTooLong,
    LookupUrlTooLong,
    StoreFull,
};

const StoreRecord = struct {
    address_text: [nip05_remembered_resolution_address_max_bytes]u8 =
        [_]u8{0} ** nip05_remembered_resolution_address_max_bytes,
    address_text_len: u16 = 0,
    lookup_url: [nip05_remembered_resolution_lookup_url_max_bytes]u8 =
        [_]u8{0} ** nip05_remembered_resolution_lookup_url_max_bytes,
    lookup_url_len: u16 = 0,
    public_key: [32]u8 = [_]u8{0} ** 32,
    relay_count: u8 = 0,
    nip46_relay_count: u8 = 0,
    resolved_at: u64 = 0,
    occupied: bool = false,

    pub fn addressText(self: *const StoreRecord) []const u8 {
        return self.address_text[0..self.address_text_len];
    }

    pub fn lookupUrl(self: *const StoreRecord) []const u8 {
        return self.lookup_url[0..self.lookup_url_len];
    }
};

const StoreVTable = struct {
    put_resolution: *const fn (
        ctx: *anyopaque,
        record: *const StoreRecord,
    ) StoreError!StorePutOutcome,
    get_resolution: *const fn (
        ctx: *anyopaque,
        address_text: []const u8,
    ) StoreError!?StoreRecord,
};

const StoreBackend = struct {
    ctx: *anyopaque,
    vtable: *const StoreVTable,

    pub fn putResolution(
        self: StoreBackend,
        record: *const StoreRecord,
    ) StoreError!StorePutOutcome {
        return self.vtable.put_resolution(self.ctx, record);
    }

    pub fn getResolution(
        self: StoreBackend,
        address_text: []const u8,
    ) StoreError!?StoreRecord {
        return self.vtable.get_resolution(self.ctx, address_text);
    }
};

const MemoryStore = struct {
    records: []StoreRecord,
    count: usize = 0,

    pub fn init(records: []StoreRecord) MemoryStore {
        return .{ .records = records };
    }

    pub fn asStore(self: *MemoryStore) StoreBackend {
        return .{
            .ctx = self,
            .vtable = &remembered_resolution_store_vtable,
        };
    }

    pub fn putResolution(
        self: *MemoryStore,
        record: *const StoreRecord,
    ) StoreError!StorePutOutcome {
        if (record.address_text_len > nip05_remembered_resolution_address_max_bytes) {
            return error.AddressTooLong;
        }
        if (record.lookup_url_len > nip05_remembered_resolution_lookup_url_max_bytes) {
            return error.LookupUrlTooLong;
        }

        if (self.findIndex(record.addressText())) |index| {
            if (self.records[index].resolved_at > record.resolved_at) return .ignored_stale;
            self.records[index] = record.*;
            return .updated;
        }

        if (self.count == self.records.len) return error.StoreFull;
        self.records[self.count] = record.*;
        self.count += 1;
        return .stored;
    }

    pub fn getResolution(
        self: *MemoryStore,
        address_text: []const u8,
    ) StoreError!?StoreRecord {
        if (address_text.len > nip05_remembered_resolution_address_max_bytes) {
            return error.AddressTooLong;
        }
        const index = self.findIndex(address_text) orelse return null;
        return self.records[index];
    }

    fn findIndex(
        self: *const MemoryStore,
        address_text: []const u8,
    ) ?usize {
        for (self.records[0..self.count], 0..) |*record, index| {
            if (!record.occupied) continue;
            if (std.mem.eql(u8, record.addressText(), address_text)) return index;
        }
        return null;
    }
};

const TargetValue = struct {
    address_text: []const u8,
};

const LatestFreshness = enum {
    fresh,
    stale,
};

const LatestValue = struct {
    resolution: StoreRecord,
    freshness: LatestFreshness,
    age_seconds: u64,
};

const LatestEntry = struct {
    target: TargetValue,
    latest: ?LatestValue = null,
};

const LatestStorage = struct {
    entries: []LatestEntry,

    pub fn init(
        entries: []LatestEntry,
    ) LatestStorage {
        return .{ .entries = entries };
    }
};

const LatestRequest = struct {
    targets: []const TargetValue,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: LatestStorage,
    scratch: std.mem.Allocator,
};

const LatestPlan = struct {
    entries: []const LatestEntry,
    fresh_count: u32 = 0,
    stale_count: u32 = 0,
    missing_count: u32 = 0,

    pub fn nextEntry(self: *const LatestPlan) ?*const LatestEntry {
        for (self.entries) |*entry| {
            if (entry.latest == null) return entry;
            if (entry.latest.?.freshness != .fresh) return entry;
        }
        return null;
    }

    pub fn nextStep(self: *const LatestPlan) ?LatestStep {
        const entry = self.nextEntry() orelse return null;
        return .{ .entry = entry.* };
    }
};

const LatestStep = struct {
    entry: LatestEntry,
};

const RefreshAction = enum {
    lookup_now,
    refresh_now,
    stable,
};

const RefreshEntry = struct {
    target: TargetValue,
    action: RefreshAction,
    latest: ?LatestValue = null,
};

const RefreshStorage = struct {
    latest_entries: []LatestEntry,
    entries: []RefreshEntry,

    pub fn init(
        latest_entries: []LatestEntry,
        entries: []RefreshEntry,
    ) RefreshStorage {
        return .{
            .latest_entries = latest_entries,
            .entries = entries,
        };
    }
};

const RefreshRequest = struct {
    targets: []const TargetValue,
    now_unix_seconds: u64,
    max_age_seconds: u64,
    storage: RefreshStorage,
    scratch: std.mem.Allocator,
};

const RefreshPlan = struct {
    entries: []const RefreshEntry,
    lookup_now_count: u32 = 0,
    refresh_now_count: u32 = 0,
    stable_count: u32 = 0,

    pub fn nextEntry(self: *const RefreshPlan) ?*const RefreshEntry {
        for (self.entries) |*entry| {
            if (entry.action != .stable) return entry;
        }
        return null;
    }

    pub fn nextStep(self: *const RefreshPlan) ?RefreshStep {
        const entry = self.nextEntry() orelse return null;
        return .{
            .action = entry.action,
            .entry = entry.*,
        };
    }
};

const RefreshStep = struct {
    action: RefreshAction,
    entry: RefreshEntry,
};

pub const Planning = struct {
    pub const Store = struct {
        pub const Error = StoreError;
        pub const PutOutcome = StorePutOutcome;
        pub const Record = StoreRecord;
        pub const Backend = StoreBackend;
        pub const Memory = MemoryStore;
    };

    pub const Target = struct {
        pub const Value = TargetValue;

        pub const Latest = struct {
            pub const Freshness = LatestFreshness;
            pub const Value = LatestValue;
            pub const Entry = LatestEntry;
            pub const Storage = LatestStorage;
            pub const Request = LatestRequest;
            pub const Plan = LatestPlan;
            pub const Step = LatestStep;
        };

        pub const Refresh = struct {
            pub const Action = RefreshAction;
            pub const Entry = RefreshEntry;
            pub const Storage = RefreshStorage;
            pub const Request = RefreshRequest;
            pub const Plan = RefreshPlan;
            pub const Step = RefreshStep;
        };
    };
};

pub const Nip05VerificationRequest = struct {
    address_text: []const u8,
    expected_pubkey: *const [32]u8,
    storage: Nip05LookupStorage,
    scratch: std.mem.Allocator,
};

pub const Nip05Resolver = struct {
    pub fn lookup(
        http_client: transport.HttpClient,
        request: Nip05LookupRequest,
    ) Nip05ResolverError!Nip05LookupOutcome {
        const fetched = try fetchDocument(
            http_client,
            request.address_text,
            request.storage.lookup_url_buffer,
            request.storage.body_buffer,
            request.scratch,
        );
        return switch (fetched) {
            .fetch_failed => |failure| .{ .fetch_failed = failure },
            .fetched => |document| {
                const profile = try noztr.nip05_identity.profile_parse_json(
                    &document.address,
                    document.body,
                    request.scratch,
                );
                return .{
                    .resolved = .{
                        .address = document.address,
                        .lookup_url = document.lookup_url,
                        .profile = profile,
                    },
                };
            },
        };
    }

    pub fn verify(
        http_client: transport.HttpClient,
        request: Nip05VerificationRequest,
    ) Nip05ResolverError!Nip05VerificationOutcome {
        const fetched = try fetchDocument(
            http_client,
            request.address_text,
            request.storage.lookup_url_buffer,
            request.storage.body_buffer,
            request.scratch,
        );

        return switch (fetched) {
            .fetch_failed => |failure| .{ .fetch_failed = failure },
            .fetched => |document| {
                const verified = try noztr.nip05_identity.profile_verify_json(
                    request.expected_pubkey,
                    &document.address,
                    document.body,
                    request.scratch,
                );
                if (!verified) {
                    const profile = noztr.nip05_identity.profile_parse_json(
                        &document.address,
                        document.body,
                        request.scratch,
                    ) catch null;
                    return .{
                        .mismatch = .{
                            .address = document.address,
                            .lookup_url = document.lookup_url,
                            .expected_pubkey = request.expected_pubkey.*,
                            .profile = profile,
                        },
                    };
                }

                const profile = try noztr.nip05_identity.profile_parse_json(
                    &document.address,
                    document.body,
                    request.scratch,
                );
                return .{
                    .verified = .{
                        .address = document.address,
                        .lookup_url = document.lookup_url,
                        .profile = profile,
                    },
                };
            },
        };
    }

    pub fn rememberResolution(
        store: Planning.Store.Backend,
        resolution: *const Nip05Resolution,
        resolved_at: u64,
    ) Planning.Store.Error!Planning.Store.PutOutcome {
        var record = try rememberedResolutionRecordFromResolution(resolution, resolved_at);
        return store.putResolution(&record);
    }

    pub fn getRememberedResolution(
        store: Planning.Store.Backend,
        address_text: []const u8,
        scratch: std.mem.Allocator,
    ) (Nip05ResolverError || Planning.Store.Error)!?Planning.Store.Record {
        var canonical_address_buffer: [nip05_remembered_resolution_address_max_bytes]u8 = undefined;
        const canonical_address = try canonicalizeAddressText(
            canonical_address_buffer[0..],
            address_text,
            scratch,
        );
        return store.getResolution(canonical_address);
    }

    pub fn inspectLatestForTargets(
        store: Planning.Store.Backend,
        request: Planning.Target.Latest.Request,
    ) (Nip05ResolverError || Planning.Store.Error)!Planning.Target.Latest.Plan {
        if (request.storage.entries.len < request.targets.len) return error.BufferTooSmall;

        const entries = request.storage.entries[0..request.targets.len];
        var plan = Planning.Target.Latest.Plan{
            .entries = entries,
        };
        var canonical_arena = std.heap.ArenaAllocator.init(request.scratch);
        defer canonical_arena.deinit();

        for (request.targets, entries) |target, *entry| {
            entry.* = .{
                .target = target,
                .latest = null,
            };
            if (try getRememberedResolution(store, target.address_text, canonical_arena.allocator())) |record| {
                const age_seconds = if (request.now_unix_seconds > record.resolved_at)
                    request.now_unix_seconds - record.resolved_at
                else
                    0;
                const freshness: Planning.Target.Latest.Freshness = if (age_seconds <= request.max_age_seconds)
                    .fresh
                else
                    .stale;
                entry.latest = .{
                    .resolution = record,
                    .freshness = freshness,
                    .age_seconds = age_seconds,
                };
                switch (freshness) {
                    .fresh => plan.fresh_count += 1,
                    .stale => plan.stale_count += 1,
                }
            } else {
                plan.missing_count += 1;
            }
        }

        return plan;
    }

    pub fn planRefreshForTargets(
        store: Planning.Store.Backend,
        request: Planning.Target.Refresh.Request,
    ) (Nip05ResolverError || Planning.Store.Error)!Planning.Target.Refresh.Plan {
        if (request.storage.latest_entries.len < request.targets.len) return error.BufferTooSmall;
        if (request.storage.entries.len < request.targets.len) return error.BufferTooSmall;

        const latest_plan = try inspectLatestForTargets(
            store,
            .{
                .targets = request.targets,
                .now_unix_seconds = request.now_unix_seconds,
                .max_age_seconds = request.max_age_seconds,
                .storage = Planning.Target.Latest.Storage.init(request.storage.latest_entries),
                .scratch = request.scratch,
            },
        );

        const entries = request.storage.entries[0..request.targets.len];
        var plan = Planning.Target.Refresh.Plan{
            .entries = entries,
        };
        for (latest_plan.entries, entries) |latest_entry, *entry| {
            const action: Planning.Target.Refresh.Action = if (latest_entry.latest == null)
                .lookup_now
            else if (latest_entry.latest.?.freshness == .stale)
                .refresh_now
            else
                .stable;
            entry.* = .{
                .target = latest_entry.target,
                .action = action,
                .latest = latest_entry.latest,
            };
            switch (action) {
                .lookup_now => plan.lookup_now_count += 1,
                .refresh_now => plan.refresh_now_count += 1,
                .stable => plan.stable_count += 1,
            }
        }

        return plan;
    }
};

const FetchedDocument = struct {
    address: noztr.nip05_identity.Address,
    lookup_url: []const u8,
    body: []const u8,
};

const FetchDocumentResult = union(enum) {
    fetched: FetchedDocument,
    fetch_failed: Nip05FetchFailure,
};

fn fetchDocument(
    http_client: transport.HttpClient,
    address_text: []const u8,
    lookup_url_buffer: []u8,
    body_buffer: []u8,
    scratch: std.mem.Allocator,
) Nip05ResolverError!FetchDocumentResult {
    const address = try noztr.nip05_identity.address_parse(address_text, scratch);
    const lookup_url = try noztr.nip05_identity.address_compose_well_known_url(
        lookup_url_buffer,
        &address,
    );
    const body = http_client.get(
        .{
            .url = lookup_url,
            .accept = "application/json",
        },
        body_buffer,
    ) catch |err| {
        return .{
            .fetch_failed = .{
                .address = address,
                .lookup_url = lookup_url,
                .cause = err,
            },
        };
    };

    return .{
        .fetched = .{
            .address = address,
            .lookup_url = lookup_url,
            .body = body,
        },
    };
}

fn rememberedResolutionRecordFromResolution(
    resolution: *const Nip05Resolution,
    resolved_at: u64,
) Planning.Store.Error!Planning.Store.Record {
    var record = Planning.Store.Record{
        .public_key = resolution.profile.public_key,
        .relay_count = @intCast(resolution.profile.relays.len),
        .nip46_relay_count = @intCast(resolution.profile.nip46_relays.len),
        .resolved_at = resolved_at,
        .occupied = true,
    };
    var canonical_address_buffer: [nip05_remembered_resolution_address_max_bytes]u8 = undefined;
    const rendered_address = noztr.nip05_identity.address_format(
        canonical_address_buffer[0..],
        &resolution.address,
    ) catch return error.AddressTooLong;
    const canonical_address = canonical_address_buffer[0..rendered_address.len];
    lowercaseAsciiInPlace(canonical_address);
    if (canonical_address.len > record.address_text.len) return error.AddressTooLong;
    if (resolution.lookup_url.len > record.lookup_url.len) return error.LookupUrlTooLong;
    @memcpy(record.address_text[0..canonical_address.len], canonical_address);
    record.address_text_len = @intCast(canonical_address.len);
    @memcpy(record.lookup_url[0..resolution.lookup_url.len], resolution.lookup_url);
    record.lookup_url_len = @intCast(resolution.lookup_url.len);
    return record;
}

fn canonicalizeAddressText(
    output: []u8,
    address_text: []const u8,
    scratch: std.mem.Allocator,
) Nip05ResolverError![]const u8 {
    const address = try noztr.nip05_identity.address_parse(address_text, scratch);
    const rendered = try noztr.nip05_identity.address_format(output, &address);
    const canonical = output[0..rendered.len];
    lowercaseAsciiInPlace(canonical);
    return canonical;
}

fn rememberedResolutionStorePut(
    ctx: *anyopaque,
    record: *const Planning.Store.Record,
) Planning.Store.Error!Planning.Store.PutOutcome {
    const self: *MemoryStore = @ptrCast(@alignCast(ctx));
    return self.putResolution(record);
}

fn rememberedResolutionStoreGet(
    ctx: *anyopaque,
    address_text: []const u8,
) Planning.Store.Error!?Planning.Store.Record {
    const self: *MemoryStore = @ptrCast(@alignCast(ctx));
    return self.getResolution(address_text);
}

const remembered_resolution_store_vtable = StoreVTable{
    .put_resolution = rememberedResolutionStorePut,
    .get_resolution = rememberedResolutionStoreGet,
};

fn lowercaseAsciiInPlace(text: []u8) void {
    for (text) |*byte| {
        if (byte.* >= 'A' and byte.* <= 'Z') byte.* += 'a' - 'A';
    }
}

test "nip05 resolver lookup returns parsed profile relays and bunker relays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"wss://relay.example.com\",\"wss://relay2.example.com\"]}," ++
        "\"nip46\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"wss://bunker.example.com\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [512]u8 = undefined;

    const outcome = try Nip05Resolver.lookup(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .resolved);
    try std.testing.expectEqualStrings("alice", outcome.resolved.address.name);
    try std.testing.expectEqualStrings("example.com", outcome.resolved.address.domain);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        outcome.resolved.lookup_url,
    );
    try std.testing.expectEqual(@as(usize, 2), outcome.resolved.profile.relays.len);
    try std.testing.expectEqualStrings("wss://relay.example.com", outcome.resolved.profile.relays[0]);
    try std.testing.expectEqual(@as(usize, 1), outcome.resolved.profile.nip46_relays.len);
    try std.testing.expectEqualStrings(
        "wss://bunker.example.com",
        outcome.resolved.profile.nip46_relays[0],
    );
}

test "nip05 resolver verify returns verified on matching pubkey" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );
    var address_buffer: [128]u8 = undefined;
    const formatted = try noztr.nip05_identity.address_format(
        address_buffer[0..],
        &outcome.verified.address,
    );

    try std.testing.expect(outcome == .verified);
    try std.testing.expectEqualStrings("alice@example.com", formatted);
}

test "nip05 resolver verify classifies pubkey mismatches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expect(outcome.mismatch.profile != null);
    try std.testing.expectEqualSlices(
        u8,
        expected_pubkey[0..],
        outcome.mismatch.expected_pubkey[0..],
    );
}

test "nip05 resolver verify treats missing names as mismatch instead of kernel error" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "{\"names\":{}}",
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [128]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expect(outcome.mismatch.profile == null);
    try std.testing.expectEqualStrings("alice", outcome.mismatch.address.name);
}

test "nip05 resolver verify keeps mismatch semantics when relay maps are malformed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const expected_pubkey = try parsePubkey(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[\"https://relay.bad\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .mismatch);
    try std.testing.expect(outcome.mismatch.profile == null);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        outcome.mismatch.lookup_url,
    );
}

test "nip05 resolver verify does not require scratch for a second parse" {
    const expected_pubkey = try parsePubkey(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    );
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}}",
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [256]u8 = undefined;
    var scratch_storage: [1536]u8 = undefined;
    var scratch = std.heap.FixedBufferAllocator.init(&scratch_storage);

    const outcome = try Nip05Resolver.verify(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .expected_pubkey = &expected_pubkey,
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = scratch.allocator(),
        },
    );

    try std.testing.expect(outcome == .verified);
}

test "nip05 resolver returns fetch failures as typed outcomes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        "",
    );
    fake_http.expected_accept = "application/json";
    fake_http.fail_with = error.TransportUnavailable;
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [64]u8 = undefined;

    const outcome = try Nip05Resolver.lookup(
        fake_http.client(),
        .{
            .address_text = "alice@example.com",
            .storage = Nip05LookupStorage.init(
                lookup_url_buffer[0..],
                body_buffer[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expect(outcome == .fetch_failed);
    try std.testing.expectEqual(error.TransportUnavailable, outcome.fetch_failed.cause);
    try std.testing.expectEqualStrings("alice", outcome.fetch_failed.address.name);
}

test "nip05 resolver propagates malformed documents from noztr" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const document =
        "{\"names\":{\"alice\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"https://not-a-websocket.example.com\"]}}";
    var fake_http = workflow_testing.FakeHttp.init(
        "https://example.com/.well-known/nostr.json?name=alice",
        document,
    );
    fake_http.expected_accept = "application/json";
    var lookup_url_buffer: [128]u8 = undefined;
    var body_buffer: [512]u8 = undefined;

    try std.testing.expectError(
        error.InvalidRelayUrl,
        Nip05Resolver.lookup(
            fake_http.client(),
            .{
                .address_text = "alice@example.com",
                .storage = Nip05LookupStorage.init(
                    lookup_url_buffer[0..],
                    body_buffer[0..],
                ),
                .scratch = arena.allocator(),
            },
        ),
    );
}

test "nip05 resolver remembers canonical successful resolutions" {
    var records: [2]Planning.Store.Record = undefined;
    var store = Planning.Store.Memory.init(records[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse("Alice@Example.com", arena.allocator());
    const resolution = Nip05Resolution{
        .address = address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=alice",
        .profile = .{
            .public_key = try parsePubkey(
                "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
            ),
            .relays = &.{"wss://relay.one"},
            .nip46_relays = &.{"wss://bunker.one"},
        },
    };

    const outcome = try Nip05Resolver.rememberResolution(store.asStore(), &resolution, 123);
    try std.testing.expectEqual(.stored, outcome);

    const restored = try Nip05Resolver.getRememberedResolution(
        store.asStore(),
        "alice@example.com",
        arena.allocator(),
    );
    try std.testing.expect(restored != null);
    try std.testing.expectEqualStrings("alice@example.com", restored.?.addressText());
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        restored.?.lookupUrl(),
    );
    try std.testing.expectEqual(@as(u8, 1), restored.?.relay_count);
    try std.testing.expectEqual(@as(u8, 1), restored.?.nip46_relay_count);
    try std.testing.expectEqual(@as(u64, 123), restored.?.resolved_at);
}

test "nip05 resolver ignores stale remembered resolution updates" {
    var records: [1]Planning.Store.Record = undefined;
    var store = Planning.Store.Memory.init(records[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse("alice@example.com", arena.allocator());
    const latest = Nip05Resolution{
        .address = address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=alice",
        .profile = .{
            .public_key = [_]u8{0x11} ** 32,
        },
    };
    const stale = Nip05Resolution{
        .address = address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=alice",
        .profile = .{
            .public_key = [_]u8{0x22} ** 32,
        },
    };

    try std.testing.expectEqual(
        Planning.Store.PutOutcome.stored,
        try Nip05Resolver.rememberResolution(store.asStore(), &latest, 50),
    );
    try std.testing.expectEqual(
        Planning.Store.PutOutcome.ignored_stale,
        try Nip05Resolver.rememberResolution(store.asStore(), &stale, 49),
    );

    const restored = try Nip05Resolver.getRememberedResolution(
        store.asStore(),
        "alice@example.com",
        arena.allocator(),
    );
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u8, 0x11), restored.?.public_key[0]);
    try std.testing.expectEqual(@as(u64, 50), restored.?.resolved_at);
}

test "nip05 resolver inspects latest remembered resolution freshness for targets" {
    var records: [2]Planning.Store.Record = undefined;
    var store = Planning.Store.Memory.init(records[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse("alice@example.com", arena.allocator());
    const resolution = Nip05Resolution{
        .address = address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=alice",
        .profile = .{
            .public_key = [_]u8{0x11} ** 32,
        },
    };
    const second_address = try noztr.nip05_identity.address_parse("bob@example.com", arena.allocator());
    const second_resolution = Nip05Resolution{
        .address = second_address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=bob",
        .profile = .{
            .public_key = [_]u8{0x22} ** 32,
        },
    };
    _ = try Nip05Resolver.rememberResolution(store.asStore(), &resolution, 90);
    _ = try Nip05Resolver.rememberResolution(store.asStore(), &second_resolution, 10);

    const targets = [_]Planning.Target.Value{
        .{ .address_text = "alice@example.com" },
        .{ .address_text = "bob@example.com" },
        .{ .address_text = "carol@example.com" },
    };
    var latest_entries: [3]Planning.Target.Latest.Entry = undefined;

    const plan = try Nip05Resolver.inspectLatestForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 100,
            .max_age_seconds = 20,
            .storage = Planning.Target.Latest.Storage.init(latest_entries[0..]),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.fresh_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stale_count);
    try std.testing.expectEqual(@as(u32, 1), plan.missing_count);
    try std.testing.expect(plan.entries[0].latest != null);
    try std.testing.expectEqual(.fresh, plan.entries[0].latest.?.freshness);
    try std.testing.expect(plan.entries[1].latest != null);
    try std.testing.expectEqual(.stale, plan.entries[1].latest.?.freshness);
    try std.testing.expect(plan.entries[2].latest == null);
    try std.testing.expectEqualStrings("bob@example.com", plan.nextStep().?.entry.target.address_text);
}

test "nip05 resolver plans remembered resolution refresh work for missing and stale targets" {
    var records: [2]Planning.Store.Record = undefined;
    var store = Planning.Store.Memory.init(records[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse("alice@example.com", arena.allocator());
    const resolution = Nip05Resolution{
        .address = address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=alice",
        .profile = .{
            .public_key = [_]u8{0x11} ** 32,
        },
    };
    const second_address = try noztr.nip05_identity.address_parse("bob@example.com", arena.allocator());
    const second_resolution = Nip05Resolution{
        .address = second_address,
        .lookup_url = "https://example.com/.well-known/nostr.json?name=bob",
        .profile = .{
            .public_key = [_]u8{0x22} ** 32,
        },
    };
    _ = try Nip05Resolver.rememberResolution(store.asStore(), &resolution, 95);
    _ = try Nip05Resolver.rememberResolution(store.asStore(), &second_resolution, 10);

    const targets = [_]Planning.Target.Value{
        .{ .address_text = "carol@example.com" },
        .{ .address_text = "bob@example.com" },
        .{ .address_text = "alice@example.com" },
    };
    var latest_entries: [3]Planning.Target.Latest.Entry = undefined;
    var refresh_entries: [3]Planning.Target.Refresh.Entry = undefined;

    const plan = try Nip05Resolver.planRefreshForTargets(
        store.asStore(),
        .{
            .targets = targets[0..],
            .now_unix_seconds = 100,
            .max_age_seconds = 20,
            .storage = Planning.Target.Refresh.Storage.init(
                latest_entries[0..],
                refresh_entries[0..],
            ),
            .scratch = arena.allocator(),
        },
    );

    try std.testing.expectEqual(@as(u32, 1), plan.lookup_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.refresh_now_count);
    try std.testing.expectEqual(@as(u32, 1), plan.stable_count);
    try std.testing.expectEqual(.lookup_now, plan.entries[0].action);
    try std.testing.expectEqual(.refresh_now, plan.entries[1].action);
    try std.testing.expectEqual(.stable, plan.entries[2].action);
    try std.testing.expectEqual(.lookup_now, plan.nextStep().?.action);
}

fn parsePubkey(text: []const u8) ![32]u8 {
    var pubkey: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&pubkey, text);
    return pubkey;
}
