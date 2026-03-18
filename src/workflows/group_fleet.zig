const std = @import("std");
const noztr = @import("noztr");
const relay_pool = @import("../relay/pool.zig");
const relay_url = @import("../relay/url.zig");
const group_client = @import("group_client.zig");
const group_session = @import("group_session.zig");

pub const GroupFleetError = group_client.GroupClientError || error{
    NoClients,
    DuplicateRelayUrl,
    GroupReferenceMismatch,
    UnknownRelayUrl,
    CannotReconcileBaselineRelay,
};

pub const GroupFleetRelayStatus = struct {
    relay_url: []const u8,
    relay_ready: bool,
};

pub const GroupFleetRuntimeAction = enum {
    connect,
    authenticate,
    reconcile,
    ready,
};

pub const GroupFleetRuntimeEntry = struct {
    relay_url: []const u8,
    relay_state: group_client.GroupRelayState,
    action: GroupFleetRuntimeAction,
    is_baseline: bool,
    metadata_divergent: bool = false,
    users_divergent: bool = false,
    roles_divergent: bool = false,

    pub fn anyDivergence(self: GroupFleetRuntimeEntry) bool {
        return self.metadata_divergent or self.users_divergent or self.roles_divergent;
    }
};

pub const GroupFleetRuntimeStorage = struct {
    relay_states: [relay_pool.pool_capacity]group_client.GroupRelayState =
        [_]group_client.GroupRelayState{.disconnected} ** relay_pool.pool_capacity,
    actions: [relay_pool.pool_capacity]GroupFleetRuntimeAction =
        [_]GroupFleetRuntimeAction{.connect} ** relay_pool.pool_capacity,
    baseline_flags: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,
    metadata_divergent: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,
    users_divergent: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,
    roles_divergent: [relay_pool.pool_capacity]bool = [_]bool{false} ** relay_pool.pool_capacity,

    pub fn clear(self: *GroupFleetRuntimeStorage) void {
        self.relay_states = [_]group_client.GroupRelayState{.disconnected} ** relay_pool.pool_capacity;
        self.actions = [_]GroupFleetRuntimeAction{.connect} ** relay_pool.pool_capacity;
        self.baseline_flags = [_]bool{false} ** relay_pool.pool_capacity;
        self.metadata_divergent = [_]bool{false} ** relay_pool.pool_capacity;
        self.users_divergent = [_]bool{false} ** relay_pool.pool_capacity;
        self.roles_divergent = [_]bool{false} ** relay_pool.pool_capacity;
    }
};

pub const GroupFleetRuntimePlan = struct {
    baseline_relay_url: []const u8,
    relay_count: u8,
    connect_count: u8 = 0,
    authenticate_count: u8 = 0,
    reconcile_count: u8 = 0,
    ready_count: u8 = 0,
    _fleet: *const GroupFleet,
    _storage: *const GroupFleetRuntimeStorage,

    pub fn entry(self: *const GroupFleetRuntimePlan, index: u8) ?GroupFleetRuntimeEntry {
        if (index >= self.relay_count) return null;
        const client = self._fleet._clients[index];
        return .{
            .relay_url = client.currentRelayUrl(),
            .relay_state = self._storage.relay_states[index],
            .action = self._storage.actions[index],
            .is_baseline = self._storage.baseline_flags[index],
            .metadata_divergent = self._storage.metadata_divergent[index],
            .users_divergent = self._storage.users_divergent[index],
            .roles_divergent = self._storage.roles_divergent[index],
        };
    }
};

pub const GroupFleetEventOutcome = struct {
    relay_url: []const u8,
    outcome: group_client.GroupClientEventOutcome,
};

pub const GroupFleetBatchOutcome = struct {
    relay_url: []const u8,
    summary: group_client.GroupClientBatchSummary,
};

pub const GroupFleetRelayDivergence = struct {
    relay_url: []const u8,
    metadata: bool = false,
    users: bool = false,
    roles: bool = false,

    pub fn any(self: GroupFleetRelayDivergence) bool {
        return self.metadata or self.users or self.roles;
    }
};

pub const GroupFleetConsistencyReport = struct {
    baseline_relay_url: []const u8,
    total_relays: u8,
    matching_relays: u8,
    divergent_relays: []const GroupFleetRelayDivergence,
};

pub const GroupFleetReconcileOutcome = struct {
    source_relay_url: []const u8,
    reconciled_relays: u8,
};

pub const GroupFleetTargetReconcileOutcome = struct {
    baseline_relay_url: []const u8,
    target_relay_url: []const u8,
};

pub const GroupFleetMergeSelection = struct {
    baseline_relay_url: ?[]const u8 = null,
    metadata_relay_url: ?[]const u8 = null,
    admins_relay_url: ?[]const u8 = null,
    members_relay_url: ?[]const u8 = null,
    roles_relay_url: ?[]const u8 = null,
};

pub const GroupFleetMergedCheckpoint = struct {
    baseline_relay_url: []const u8,
    metadata_source_relay_url: []const u8,
    admins_source_relay_url: []const u8,
    members_source_relay_url: []const u8,
    roles_source_relay_url: []const u8,
    checkpoint: group_client.GroupCheckpoint,
};

pub const GroupFleetMergeApplyOutcome = struct {
    applied_relays: u8,
    baseline_relay_url: []const u8,
    metadata_source_relay_url: []const u8,
    admins_source_relay_url: []const u8,
    members_source_relay_url: []const u8,
    roles_source_relay_url: []const u8,
};

pub const GroupFleetCheckpointStorage = struct {
    relay_urls: [relay_pool.pool_capacity][relay_url.relay_url_max_bytes]u8 =
        [_][relay_url.relay_url_max_bytes]u8{[_]u8{0} ** relay_url.relay_url_max_bytes} **
        relay_pool.pool_capacity,
    relay_url_lens: [relay_pool.pool_capacity]u16 = [_]u16{0} ** relay_pool.pool_capacity,
    checkpoint_buffers: [relay_pool.pool_capacity]group_client.GroupCheckpointBuffers =
        [_]group_client.GroupCheckpointBuffers{.{}} ** relay_pool.pool_capacity,
    metadata_lens: [relay_pool.pool_capacity]u16 = [_]u16{0} ** relay_pool.pool_capacity,
    admins_lens: [relay_pool.pool_capacity]u16 = [_]u16{0} ** relay_pool.pool_capacity,
    members_lens: [relay_pool.pool_capacity]u16 = [_]u16{0} ** relay_pool.pool_capacity,
    roles_lens: [relay_pool.pool_capacity]u16 = [_]u16{0} ** relay_pool.pool_capacity,

    pub fn clear(self: *GroupFleetCheckpointStorage) void {
        self.relay_url_lens = [_]u16{0} ** relay_pool.pool_capacity;
        self.metadata_lens = [_]u16{0} ** relay_pool.pool_capacity;
        self.admins_lens = [_]u16{0} ** relay_pool.pool_capacity;
        self.members_lens = [_]u16{0} ** relay_pool.pool_capacity;
        self.roles_lens = [_]u16{0} ** relay_pool.pool_capacity;
    }

    fn storeCheckpoint(
        self: *GroupFleetCheckpointStorage,
        index: u8,
        value: *const group_client.GroupCheckpoint,
    ) void {
        const relay_index: usize = index;
        @memset(self.relay_urls[relay_index][0..], 0);
        std.mem.copyForwards(
            u8,
            self.relay_urls[relay_index][0..value.relay_url.len],
            value.relay_url,
        );
        self.relay_url_lens[relay_index] = @intCast(value.relay_url.len);
        self.metadata_lens[relay_index] = @intCast(value.metadata_event_json.len);
        self.admins_lens[relay_index] = @intCast(value.admins_event_json.len);
        self.members_lens[relay_index] = @intCast(value.members_event_json.len);
        self.roles_lens[relay_index] = @intCast(value.roles_event_json.len);
    }

    fn relayUrl(self: *const GroupFleetCheckpointStorage, index: u8) []const u8 {
        return self.relay_urls[index][0..self.relay_url_lens[index]];
    }

    fn checkpoint(self: *const GroupFleetCheckpointStorage, index: u8) group_client.GroupCheckpoint {
        const relay_index: usize = index;
        return .{
            .relay_url = self.relayUrl(index),
            .metadata_event_json = self.checkpoint_buffers[relay_index].metadata.storage[0..self.metadata_lens[relay_index]],
            .admins_event_json = self.checkpoint_buffers[relay_index].admins.storage[0..self.admins_lens[relay_index]],
            .members_event_json = self.checkpoint_buffers[relay_index].members.storage[0..self.members_lens[relay_index]],
            .roles_event_json = self.checkpoint_buffers[relay_index].roles.storage[0..self.roles_lens[relay_index]],
        };
    }
};

pub const GroupFleetMergeStorage = struct {
    working_buffers: group_client.GroupCheckpointBuffers = .{},
    merged_buffers: group_client.GroupCheckpointBuffers = .{},
    baseline_relay_url: [relay_url.relay_url_max_bytes]u8 =
        [_]u8{0} ** relay_url.relay_url_max_bytes,
    baseline_relay_url_len: u16 = 0,
    metadata_source_relay_url: [relay_url.relay_url_max_bytes]u8 =
        [_]u8{0} ** relay_url.relay_url_max_bytes,
    metadata_source_relay_url_len: u16 = 0,
    admins_source_relay_url: [relay_url.relay_url_max_bytes]u8 =
        [_]u8{0} ** relay_url.relay_url_max_bytes,
    admins_source_relay_url_len: u16 = 0,
    members_source_relay_url: [relay_url.relay_url_max_bytes]u8 =
        [_]u8{0} ** relay_url.relay_url_max_bytes,
    members_source_relay_url_len: u16 = 0,
    roles_source_relay_url: [relay_url.relay_url_max_bytes]u8 =
        [_]u8{0} ** relay_url.relay_url_max_bytes,
    roles_source_relay_url_len: u16 = 0,
    metadata_event_json_len: u32 = 0,
    admins_event_json_len: u32 = 0,
    members_event_json_len: u32 = 0,
    roles_event_json_len: u32 = 0,

    pub fn clear(self: *GroupFleetMergeStorage) void {
        self.baseline_relay_url_len = 0;
        self.metadata_source_relay_url_len = 0;
        self.admins_source_relay_url_len = 0;
        self.members_source_relay_url_len = 0;
        self.roles_source_relay_url_len = 0;
        self.metadata_event_json_len = 0;
        self.admins_event_json_len = 0;
        self.members_event_json_len = 0;
        self.roles_event_json_len = 0;
    }

    fn mergedCheckpoint(self: *const GroupFleetMergeStorage) GroupFleetMergedCheckpoint {
        return .{
            .baseline_relay_url = self.baselineRelayUrl(),
            .metadata_source_relay_url = self.metadataSourceRelayUrl(),
            .admins_source_relay_url = self.adminsSourceRelayUrl(),
            .members_source_relay_url = self.membersSourceRelayUrl(),
            .roles_source_relay_url = self.rolesSourceRelayUrl(),
            .checkpoint = .{
                .relay_url = self.baselineRelayUrl(),
                .metadata_event_json = self.merged_buffers.metadata.storage[0..self.metadata_event_json_len],
                .admins_event_json = self.merged_buffers.admins.storage[0..self.admins_event_json_len],
                .members_event_json = self.merged_buffers.members.storage[0..self.members_event_json_len],
                .roles_event_json = self.merged_buffers.roles.storage[0..self.roles_event_json_len],
            },
        };
    }

    fn baselineRelayUrl(self: *const GroupFleetMergeStorage) []const u8 {
        return self.baseline_relay_url[0..self.baseline_relay_url_len];
    }

    fn metadataSourceRelayUrl(self: *const GroupFleetMergeStorage) []const u8 {
        return self.metadata_source_relay_url[0..self.metadata_source_relay_url_len];
    }

    fn adminsSourceRelayUrl(self: *const GroupFleetMergeStorage) []const u8 {
        return self.admins_source_relay_url[0..self.admins_source_relay_url_len];
    }

    fn membersSourceRelayUrl(self: *const GroupFleetMergeStorage) []const u8 {
        return self.members_source_relay_url[0..self.members_source_relay_url_len];
    }

    fn rolesSourceRelayUrl(self: *const GroupFleetMergeStorage) []const u8 {
        return self.roles_source_relay_url[0..self.roles_source_relay_url_len];
    }
};

pub const GroupFleetCheckpointContext = struct {
    created_at_base: u64,
    created_at_stride: u32 = 10,
    author_secret_key: [32]u8,
    storage: *GroupFleetCheckpointStorage,

    pub fn init(
        created_at_base: u64,
        author_secret_key: *const [32]u8,
        storage: *GroupFleetCheckpointStorage,
    ) GroupFleetCheckpointContext {
        return .{
            .created_at_base = created_at_base,
            .author_secret_key = author_secret_key.*,
            .storage = storage,
        };
    }

    fn checkpointContext(
        self: *GroupFleetCheckpointContext,
        index: u8,
    ) group_client.GroupCheckpointContext {
        return .init(
            self.created_at_base + (@as(u64, index) * self.created_at_stride),
            &self.author_secret_key,
            &self.storage.checkpoint_buffers[index],
        );
    }
};

pub const GroupFleetMergeContext = struct {
    created_at_base: u64,
    author_secret_key: [32]u8,
    storage: *GroupFleetMergeStorage,

    pub fn init(
        created_at_base: u64,
        author_secret_key: *const [32]u8,
        storage: *GroupFleetMergeStorage,
    ) GroupFleetMergeContext {
        return .{
            .created_at_base = created_at_base,
            .author_secret_key = author_secret_key.*,
            .storage = storage,
        };
    }

    fn checkpointContext(self: *GroupFleetMergeContext) group_client.GroupCheckpointContext {
        return .init(self.created_at_base, &self.author_secret_key, &self.storage.working_buffers);
    }
};

pub const GroupFleetCheckpointSet = struct {
    relay_count: u8,
    _storage: *const GroupFleetCheckpointStorage,

    pub fn relayUrl(self: *const GroupFleetCheckpointSet, index: u8) ?[]const u8 {
        if (index >= self.relay_count) return null;
        return self._storage.relayUrl(index);
    }

    pub fn checkpoint(self: *const GroupFleetCheckpointSet, index: u8) ?group_client.GroupCheckpoint {
        if (index >= self.relay_count) return null;
        return self._storage.checkpoint(index);
    }
};

pub const fleet_checkpoint_event_json_max: u32 = noztr.limits.event_json_max;

pub const GroupFleetCheckpointStorePutOutcome = enum {
    stored,
    replaced,
};

pub const GroupFleetCheckpointStoreError = error{
    InvalidRelayUrl,
    RelayUrlTooLong,
    MetadataEventTooLong,
    AdminsEventTooLong,
    MembersEventTooLong,
    RolesEventTooLong,
    StoreFull,
};

pub const GroupFleetCheckpointRecord = struct {
    relay_url: [relay_url.relay_url_max_bytes]u8 = [_]u8{0} ** relay_url.relay_url_max_bytes,
    relay_url_len: u16 = 0,
    metadata_event_json: [fleet_checkpoint_event_json_max]u8 = [_]u8{0} ** fleet_checkpoint_event_json_max,
    metadata_event_json_len: u32 = 0,
    admins_event_json: [fleet_checkpoint_event_json_max]u8 = [_]u8{0} ** fleet_checkpoint_event_json_max,
    admins_event_json_len: u32 = 0,
    members_event_json: [fleet_checkpoint_event_json_max]u8 = [_]u8{0} ** fleet_checkpoint_event_json_max,
    members_event_json_len: u32 = 0,
    roles_event_json: [fleet_checkpoint_event_json_max]u8 = [_]u8{0} ** fleet_checkpoint_event_json_max,
    roles_event_json_len: u32 = 0,
    occupied: bool = false,

    pub fn relayUrl(self: *const GroupFleetCheckpointRecord) []const u8 {
        return self.relay_url[0..self.relay_url_len];
    }

    pub fn checkpoint(self: *const GroupFleetCheckpointRecord) group_client.GroupCheckpoint {
        return .{
            .relay_url = self.relayUrl(),
            .metadata_event_json = self.metadata_event_json[0..self.metadata_event_json_len],
            .admins_event_json = self.admins_event_json[0..self.admins_event_json_len],
            .members_event_json = self.members_event_json[0..self.members_event_json_len],
            .roles_event_json = self.roles_event_json[0..self.roles_event_json_len],
        };
    }
};

pub const GroupFleetCheckpointStoreVTable = struct {
    put_checkpoint: *const fn (
        ctx: *anyopaque,
        checkpoint: *const group_client.GroupCheckpoint,
    ) GroupFleetCheckpointStoreError!GroupFleetCheckpointStorePutOutcome,
    get_checkpoint: *const fn (
        ctx: *anyopaque,
        relay_url_text: []const u8,
    ) GroupFleetCheckpointStoreError!?group_client.GroupCheckpoint,
};

pub const GroupFleetCheckpointStore = struct {
    ctx: *anyopaque,
    vtable: *const GroupFleetCheckpointStoreVTable,

    pub fn putCheckpoint(
        self: GroupFleetCheckpointStore,
        checkpoint: *const group_client.GroupCheckpoint,
    ) GroupFleetCheckpointStoreError!GroupFleetCheckpointStorePutOutcome {
        return self.vtable.put_checkpoint(self.ctx, checkpoint);
    }

    pub fn getCheckpoint(
        self: GroupFleetCheckpointStore,
        relay_url_text: []const u8,
    ) GroupFleetCheckpointStoreError!?group_client.GroupCheckpoint {
        return self.vtable.get_checkpoint(self.ctx, relay_url_text);
    }
};

pub const MemoryGroupFleetCheckpointStore = struct {
    records: []GroupFleetCheckpointRecord,
    count: usize = 0,

    pub fn init(records: []GroupFleetCheckpointRecord) MemoryGroupFleetCheckpointStore {
        return .{ .records = records };
    }

    pub fn asStore(self: *MemoryGroupFleetCheckpointStore) GroupFleetCheckpointStore {
        return .{
            .ctx = self,
            .vtable = &group_fleet_checkpoint_store_vtable,
        };
    }

    pub fn putCheckpoint(
        self: *MemoryGroupFleetCheckpointStore,
        checkpoint: *const group_client.GroupCheckpoint,
    ) GroupFleetCheckpointStoreError!GroupFleetCheckpointStorePutOutcome {
        try validateCheckpointForStore(checkpoint);

        if (self.findIndex(checkpoint.relay_url)) |index| {
            writeCheckpointRecord(&self.records[index], checkpoint);
            return .replaced;
        }
        if (self.count == self.records.len) return error.StoreFull;
        writeCheckpointRecord(&self.records[self.count], checkpoint);
        self.count += 1;
        return .stored;
    }

    pub fn getCheckpoint(
        self: *MemoryGroupFleetCheckpointStore,
        relay_url_text: []const u8,
    ) GroupFleetCheckpointStoreError!?group_client.GroupCheckpoint {
        try validateStoreRelayUrl(relay_url_text);
        const index = self.findIndex(relay_url_text) orelse return null;
        return self.records[index].checkpoint();
    }

    fn findIndex(self: *const MemoryGroupFleetCheckpointStore, relay_url_text: []const u8) ?usize {
        for (self.records[0..self.count], 0..) |*record, index| {
            if (!record.occupied) continue;
            if (!relay_url.relayUrlsEquivalent(record.relayUrl(), relay_url_text)) continue;
            return index;
        }
        return null;
    }
};

pub const GroupFleetStorePersistOutcome = struct {
    stored_relays: u8 = 0,
    replaced_relays: u8 = 0,
};

pub const GroupFleetStoreRestoreOutcome = struct {
    restored_relays: u8 = 0,
    missing_relays: u8 = 0,
};

pub const GroupFleetPublishStorage = struct {
    buffers: []group_session.OutboundBuffer,
    previous_refs: [][][]const u8,
    events: []group_session.OutboundEvent,

    pub fn init(
        buffers: []group_session.OutboundBuffer,
        previous_refs: [][][]const u8,
        events: []group_session.OutboundEvent,
    ) GroupFleetPublishStorage {
        return .{
            .buffers = buffers,
            .previous_refs = previous_refs,
            .events = events,
        };
    }
};

pub const GroupFleetPublishContext = struct {
    created_at_base: u64,
    created_at_stride: u32 = 1,
    author_secret_key: [32]u8,
    storage: *GroupFleetPublishStorage,

    pub fn init(
        created_at_base: u64,
        author_secret_key: *const [32]u8,
        storage: *GroupFleetPublishStorage,
    ) GroupFleetPublishContext {
        return .{
            .created_at_base = created_at_base,
            .author_secret_key = author_secret_key.*,
            .storage = storage,
        };
    }

    fn publishContext(
        self: *GroupFleetPublishContext,
        index: u8,
    ) group_session.PublishContext {
        return .init(
            self.created_at_base + (@as(u64, index) * self.created_at_stride),
            &self.author_secret_key,
            &self.storage.buffers[index],
        );
    }
};

pub const GroupFleetPutUserDraft = struct {
    pubkey: [32]u8,
    roles: []const []const u8,
    reason: ?[]const u8 = null,
};

pub const GroupFleetRemoveUserDraft = struct {
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const GroupFleet = struct {
    _clients: []*group_client.GroupClient,
    _reference: noztr.nip29_relay_groups.GroupReference,

    pub fn init(clients: []*group_client.GroupClient) GroupFleetError!GroupFleet {
        if (clients.len == 0) return error.NoClients;

        const reference = clients[0].groupReference();
        for (clients, 0..) |client, index| {
            const client_reference = client.groupReference();
            if (!std.mem.eql(u8, reference.host, client_reference.host) or
                !std.mem.eql(u8, reference.id, client_reference.id))
            {
                return error.GroupReferenceMismatch;
            }
            var compare_index: usize = 0;
            while (compare_index < index) : (compare_index += 1) {
                if (relay_url.relayUrlsEquivalent(
                    clients[compare_index].currentRelayUrl(),
                    client.currentRelayUrl(),
                )) return error.DuplicateRelayUrl;
            }
        }

        return .{
            ._clients = clients,
            ._reference = reference,
        };
    }

    pub fn groupReference(self: *const GroupFleet) noztr.nip29_relay_groups.GroupReference {
        return self._reference;
    }

    pub fn relayCount(self: *const GroupFleet) usize {
        return self._clients.len;
    }

    pub fn relayStatuses(
        self: *const GroupFleet,
        out: []GroupFleetRelayStatus,
    ) []const GroupFleetRelayStatus {
        var count: usize = 0;
        for (self._clients) |client| {
            if (count == out.len) break;
            out[count] = .{
                .relay_url = client.currentRelayUrl(),
                .relay_ready = client.currentRelayCanReceive(),
            };
            count += 1;
        }
        return out[0..count];
    }

    pub fn inspectRuntime(
        self: *const GroupFleet,
        baseline_relay_url: ?[]const u8,
        storage: *GroupFleetRuntimeStorage,
    ) GroupFleetError!GroupFleetRuntimePlan {
        if (self._clients.len == 0) return error.NoClients;

        const baseline_index = if (baseline_relay_url) |relay_url_text|
            try self.findRelayIndex(relay_url_text)
        else
            0;
        storage.clear();

        const baseline_client = self._clients[baseline_index];
        const baseline_view = baseline_client.view();
        var connect_count: u8 = 0;
        var authenticate_count: u8 = 0;
        var reconcile_count: u8 = 0;
        var ready_count: u8 = 0;

        for (self._clients, 0..) |client, index| {
            const relay_index: u8 = @intCast(index);
            const view = client.view();
            const relay_state = client.currentRelayState();
            const metadata_divergent = !metadataEql(baseline_view.metadata, view.metadata);
            const users_divergent = !usersEql(baseline_view.users, view.users);
            const roles_divergent = !rolesEql(baseline_view.supported_roles, view.supported_roles);
            const any_divergence = metadata_divergent or users_divergent or roles_divergent;
            storage.relay_states[relay_index] = relay_state;
            storage.baseline_flags[relay_index] = index == baseline_index;
            storage.metadata_divergent[relay_index] = metadata_divergent;
            storage.users_divergent[relay_index] = users_divergent;
            storage.roles_divergent[relay_index] = roles_divergent;
            storage.actions[relay_index] = switch (relay_state) {
                .disconnected => blk: {
                    connect_count += 1;
                    break :blk .connect;
                },
                .auth_required => blk: {
                    authenticate_count += 1;
                    break :blk .authenticate;
                },
                .connected => blk: {
                    if (any_divergence) {
                        reconcile_count += 1;
                        break :blk .reconcile;
                    }
                    ready_count += 1;
                    break :blk .ready;
                },
            };
        }

        return .{
            .baseline_relay_url = baseline_client.currentRelayUrl(),
            .relay_count = @intCast(self._clients.len),
            .connect_count = connect_count,
            .authenticate_count = authenticate_count,
            .reconcile_count = reconcile_count,
            .ready_count = ready_count,
            ._fleet = self,
            ._storage = storage,
        };
    }

    pub fn inspectConsistency(
        self: *const GroupFleet,
        baseline_relay_url: ?[]const u8,
        out: []GroupFleetRelayDivergence,
    ) GroupFleetError!GroupFleetConsistencyReport {
        if (self._clients.len == 0) return error.NoClients;

        const baseline_index = if (baseline_relay_url) |relay_url_text|
            try self.findRelayIndex(relay_url_text)
        else
            0;
        if (self._clients.len - 1 > out.len) return error.BufferTooSmall;

        const baseline_client = self._clients[baseline_index];
        const baseline_view = baseline_client.view();
        var divergence_count: usize = 0;
        var matching_relays: u8 = 1;
        for (self._clients, 0..) |client, index| {
            if (index == baseline_index) continue;
            const view = client.view();
            const divergence = GroupFleetRelayDivergence{
                .relay_url = client.currentRelayUrl(),
                .metadata = !metadataEql(baseline_view.metadata, view.metadata),
                .users = !usersEql(baseline_view.users, view.users),
                .roles = !rolesEql(baseline_view.supported_roles, view.supported_roles),
            };
            if (divergence.any()) {
                out[divergence_count] = divergence;
                divergence_count += 1;
            } else {
                matching_relays += 1;
            }
        }

        return .{
            .baseline_relay_url = baseline_client.currentRelayUrl(),
            .total_relays = @intCast(self._clients.len),
            .matching_relays = matching_relays,
            .divergent_relays = out[0..divergence_count],
        };
    }

    pub fn clientForRelay(
        self: *GroupFleet,
        relay_url_text: []const u8,
    ) GroupFleetError!*group_client.GroupClient {
        const index = try self.findRelayIndex(relay_url_text);
        return self._clients[index];
    }

    pub fn clientForRelayConst(
        self: *const GroupFleet,
        relay_url_text: []const u8,
    ) GroupFleetError!*const group_client.GroupClient {
        const index = try self.findRelayIndex(relay_url_text);
        return self._clients[index];
    }

    pub fn consumeRelayEventJson(
        self: *GroupFleet,
        relay_url_text: []const u8,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) GroupFleetError!GroupFleetEventOutcome {
        const client = try self.clientForRelay(relay_url_text);
        return .{
            .relay_url = client.currentRelayUrl(),
            .outcome = try client.consumeEventJson(event_json, scratch),
        };
    }

    pub fn consumeRelayEvent(
        self: *GroupFleet,
        relay_url_text: []const u8,
        event: *const noztr.nip01_event.Event,
    ) GroupFleetError!GroupFleetEventOutcome {
        const client = try self.clientForRelay(relay_url_text);
        return .{
            .relay_url = client.currentRelayUrl(),
            .outcome = try client.consumeEvent(event),
        };
    }

    pub fn consumeRelayEventJsons(
        self: *GroupFleet,
        relay_url_text: []const u8,
        event_jsons: []const []const u8,
        scratch: std.mem.Allocator,
    ) GroupFleetError!GroupFleetBatchOutcome {
        const client = try self.clientForRelay(relay_url_text);
        return .{
            .relay_url = client.currentRelayUrl(),
            .summary = try client.consumeEventJsons(event_jsons, scratch),
        };
    }

    pub fn exportRelayCheckpoint(
        self: *GroupFleet,
        relay_url_text: []const u8,
        context: group_client.GroupCheckpointContext,
    ) GroupFleetError!group_client.GroupCheckpoint {
        const client = try self.clientForRelay(relay_url_text);
        return client.exportCheckpoint(context);
    }

    pub fn restoreRelayCheckpoint(
        self: *GroupFleet,
        relay_url_text: []const u8,
        checkpoint: *const group_client.GroupCheckpoint,
        scratch: std.mem.Allocator,
    ) GroupFleetError!void {
        const client = try self.clientForRelay(relay_url_text);
        try client.restoreCheckpoint(checkpoint, scratch);
    }

    pub fn reconcileAllFromRelay(
        self: *GroupFleet,
        source_relay_url: []const u8,
        context: *GroupFleetCheckpointContext,
        scratch: std.mem.Allocator,
    ) GroupFleetError!GroupFleetReconcileOutcome {
        const source_index = try self.findRelayIndex(source_relay_url);
        const source_client = self._clients[source_index];
        const checkpoint = try source_client.exportCheckpoint(
            context.checkpointContext(@intCast(source_index)),
        );

        var reconciled_relays: u8 = 0;
        for (self._clients, 0..) |client, index| {
            if (index == source_index) continue;
            try client.restoreCheckpoint(&checkpoint, scratch);
            reconciled_relays += 1;
        }
        return .{
            .source_relay_url = source_client.currentRelayUrl(),
            .reconciled_relays = reconciled_relays,
        };
    }

    pub fn reconcileRelayFromBaseline(
        self: *GroupFleet,
        baseline_relay_url: ?[]const u8,
        target_relay_url: []const u8,
        context: *GroupFleetCheckpointContext,
        scratch: std.mem.Allocator,
    ) GroupFleetError!GroupFleetTargetReconcileOutcome {
        const baseline_index = if (baseline_relay_url) |relay_url_text|
            try self.findRelayIndex(relay_url_text)
        else
            0;
        const target_index = try self.findRelayIndex(target_relay_url);
        if (baseline_index == target_index) return error.CannotReconcileBaselineRelay;

        const baseline_client = self._clients[baseline_index];
        const checkpoint = try baseline_client.exportCheckpoint(
            context.checkpointContext(@intCast(baseline_index)),
        );
        try self._clients[target_index].restoreCheckpoint(&checkpoint, scratch);
        return .{
            .baseline_relay_url = baseline_client.currentRelayUrl(),
            .target_relay_url = self._clients[target_index].currentRelayUrl(),
        };
    }

    pub fn buildMergedCheckpoint(
        self: *const GroupFleet,
        selection: *const GroupFleetMergeSelection,
        context: *GroupFleetMergeContext,
    ) GroupFleetError!GroupFleetMergedCheckpoint {
        const baseline_index = if (selection.baseline_relay_url) |relay_url_text|
            try self.findRelayIndex(relay_url_text)
        else
            0;
        context.storage.clear();
        storeRelayUrlText(
            context.storage.baseline_relay_url[0..],
            &context.storage.baseline_relay_url_len,
            self._clients[baseline_index].currentRelayUrl(),
        );

        try self.copyMergedCheckpointComponent(
            .metadata,
            if (selection.metadata_relay_url) |relay_url_text|
                try self.findRelayIndex(relay_url_text)
            else
                baseline_index,
            context,
        );
        try self.copyMergedCheckpointComponent(
            .admins,
            if (selection.admins_relay_url) |relay_url_text|
                try self.findRelayIndex(relay_url_text)
            else
                baseline_index,
            context,
        );
        try self.copyMergedCheckpointComponent(
            .members,
            if (selection.members_relay_url) |relay_url_text|
                try self.findRelayIndex(relay_url_text)
            else
                baseline_index,
            context,
        );
        try self.copyMergedCheckpointComponent(
            .roles,
            if (selection.roles_relay_url) |relay_url_text|
                try self.findRelayIndex(relay_url_text)
            else
                baseline_index,
            context,
        );

        return context.storage.mergedCheckpoint();
    }

    pub fn applyMergedCheckpointToAll(
        self: *GroupFleet,
        merged_checkpoint: *const GroupFleetMergedCheckpoint,
        scratch: std.mem.Allocator,
    ) GroupFleetError!GroupFleetMergeApplyOutcome {
        var applied_relays: u8 = 0;
        for (self._clients) |client| {
            try client.restoreCheckpoint(&merged_checkpoint.checkpoint, scratch);
            applied_relays += 1;
        }
        return .{
            .applied_relays = applied_relays,
            .baseline_relay_url = merged_checkpoint.baseline_relay_url,
            .metadata_source_relay_url = merged_checkpoint.metadata_source_relay_url,
            .admins_source_relay_url = merged_checkpoint.admins_source_relay_url,
            .members_source_relay_url = merged_checkpoint.members_source_relay_url,
            .roles_source_relay_url = merged_checkpoint.roles_source_relay_url,
        };
    }

    pub fn exportCheckpointSet(
        self: *GroupFleet,
        context: *GroupFleetCheckpointContext,
    ) GroupFleetError!GroupFleetCheckpointSet {
        context.storage.clear();
        for (self._clients, 0..) |client, index| {
            const relay_index: u8 = @intCast(index);
            const checkpoint = try client.exportCheckpoint(context.checkpointContext(relay_index));
            context.storage.storeCheckpoint(relay_index, &checkpoint);
        }
        return .{
            .relay_count = @intCast(self._clients.len),
            ._storage = context.storage,
        };
    }

    pub fn restoreCheckpointSet(
        self: *GroupFleet,
        checkpoint_set: *const GroupFleetCheckpointSet,
        scratch: std.mem.Allocator,
    ) GroupFleetError!void {
        var index: u8 = 0;
        while (index < checkpoint_set.relay_count) : (index += 1) {
            const relay_url_text = checkpoint_set.relayUrl(index) orelse unreachable;
            const checkpoint = checkpoint_set.checkpoint(index) orelse unreachable;
            try self.restoreRelayCheckpoint(relay_url_text, &checkpoint, scratch);
        }
    }

    pub fn persistCheckpointStore(
        self: *GroupFleet,
        store: GroupFleetCheckpointStore,
        context: *GroupFleetCheckpointContext,
    ) (GroupFleetError || GroupFleetCheckpointStoreError)!GroupFleetStorePersistOutcome {
        var outcome: GroupFleetStorePersistOutcome = .{};
        for (self._clients, 0..) |client, index| {
            const relay_index: u8 = @intCast(index);
            const checkpoint = try client.exportCheckpoint(context.checkpointContext(relay_index));
            switch (try store.putCheckpoint(&checkpoint)) {
                .stored => outcome.stored_relays += 1,
                .replaced => outcome.replaced_relays += 1,
            }
        }
        return outcome;
    }

    pub fn restoreCheckpointStore(
        self: *GroupFleet,
        store: GroupFleetCheckpointStore,
        scratch: std.mem.Allocator,
    ) (GroupFleetError || GroupFleetCheckpointStoreError)!GroupFleetStoreRestoreOutcome {
        var outcome: GroupFleetStoreRestoreOutcome = .{};
        for (self._clients) |client| {
            if (try store.getCheckpoint(client.currentRelayUrl())) |checkpoint| {
                try client.restoreCheckpoint(&checkpoint, scratch);
                outcome.restored_relays += 1;
            } else {
                outcome.missing_relays += 1;
            }
        }
        return outcome;
    }

    pub fn beginPutUserForAll(
        self: *const GroupFleet,
        context: *GroupFleetPublishContext,
        request: *const GroupFleetPutUserDraft,
    ) GroupFleetError![]const group_session.OutboundEvent {
        try validatePublishStorage(self, context);
        const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&context.author_secret_key);
        var count: usize = 0;
        for (self._clients, 0..) |client, index| {
            const relay_index: u8 = @intCast(index);
            const selected_previous =
                client.selectPreviousRefs(&author_pubkey, context.storage.previous_refs[index]);
            context.storage.events[index] = try client.beginPutUser(
                context.publishContext(relay_index),
                &.{
                    .pubkey = request.pubkey,
                    .roles = request.roles,
                    .reason = request.reason,
                    .previous_refs = selected_previous,
                },
            );
            count += 1;
        }
        return context.storage.events[0..count];
    }

    pub fn beginRemoveUserForAll(
        self: *const GroupFleet,
        context: *GroupFleetPublishContext,
        request: *const GroupFleetRemoveUserDraft,
    ) GroupFleetError![]const group_session.OutboundEvent {
        try validatePublishStorage(self, context);
        const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&context.author_secret_key);
        var count: usize = 0;
        for (self._clients, 0..) |client, index| {
            const relay_index: u8 = @intCast(index);
            const selected_previous =
                client.selectPreviousRefs(&author_pubkey, context.storage.previous_refs[index]);
            context.storage.events[index] = try client.beginRemoveUser(
                context.publishContext(relay_index),
                &.{
                    .pubkey = request.pubkey,
                    .reason = request.reason,
                    .previous_refs = selected_previous,
                },
            );
            count += 1;
        }
        return context.storage.events[0..count];
    }

    fn findRelayIndex(
        self: *const GroupFleet,
        relay_url_text: []const u8,
    ) GroupFleetError!usize {
        for (self._clients, 0..) |client, index| {
            if (relay_url.relayUrlsEquivalent(client.currentRelayUrl(), relay_url_text)) {
                return index;
            }
        }
        return error.UnknownRelayUrl;
    }

    fn copyMergedCheckpointComponent(
        self: *const GroupFleet,
        component: MergeComponent,
        source_index: usize,
        context: *GroupFleetMergeContext,
    ) GroupFleetError!void {
        const source_client = self._clients[source_index];
        const checkpoint = try source_client.exportCheckpoint(context.checkpointContext());
        switch (component) {
            .metadata => {
                copyCheckpointField(
                    context.storage.merged_buffers.metadata.storage[0..],
                    &context.storage.metadata_event_json_len,
                    checkpoint.metadata_event_json,
                );
                storeRelayUrlText(
                    context.storage.metadata_source_relay_url[0..],
                    &context.storage.metadata_source_relay_url_len,
                    source_client.currentRelayUrl(),
                );
            },
            .admins => {
                copyCheckpointField(
                    context.storage.merged_buffers.admins.storage[0..],
                    &context.storage.admins_event_json_len,
                    checkpoint.admins_event_json,
                );
                storeRelayUrlText(
                    context.storage.admins_source_relay_url[0..],
                    &context.storage.admins_source_relay_url_len,
                    source_client.currentRelayUrl(),
                );
            },
            .members => {
                copyCheckpointField(
                    context.storage.merged_buffers.members.storage[0..],
                    &context.storage.members_event_json_len,
                    checkpoint.members_event_json,
                );
                storeRelayUrlText(
                    context.storage.members_source_relay_url[0..],
                    &context.storage.members_source_relay_url_len,
                    source_client.currentRelayUrl(),
                );
            },
            .roles => {
                copyCheckpointField(
                    context.storage.merged_buffers.roles.storage[0..],
                    &context.storage.roles_event_json_len,
                    checkpoint.roles_event_json,
                );
                storeRelayUrlText(
                    context.storage.roles_source_relay_url[0..],
                    &context.storage.roles_source_relay_url_len,
                    source_client.currentRelayUrl(),
                );
            },
        }
    }
};

const MergeComponent = enum {
    metadata,
    admins,
    members,
    roles,
};

fn validatePublishStorage(
    self: *const GroupFleet,
    context: *const GroupFleetPublishContext,
) GroupFleetError!void {
    if (self._clients.len > context.storage.buffers.len) return error.BufferTooSmall;
    if (self._clients.len > context.storage.previous_refs.len) return error.BufferTooSmall;
    if (self._clients.len > context.storage.events.len) return error.BufferTooSmall;
}

fn validateStoreRelayUrl(relay_url_text: []const u8) GroupFleetCheckpointStoreError!void {
    if (relay_url_text.len > relay_url.relay_url_max_bytes) return error.RelayUrlTooLong;
    try relay_url.relayUrlValidate(relay_url_text);
}

fn validateCheckpointForStore(
    checkpoint: *const group_client.GroupCheckpoint,
) GroupFleetCheckpointStoreError!void {
    try validateStoreRelayUrl(checkpoint.relay_url);
    if (checkpoint.metadata_event_json.len > fleet_checkpoint_event_json_max) {
        return error.MetadataEventTooLong;
    }
    if (checkpoint.admins_event_json.len > fleet_checkpoint_event_json_max) {
        return error.AdminsEventTooLong;
    }
    if (checkpoint.members_event_json.len > fleet_checkpoint_event_json_max) {
        return error.MembersEventTooLong;
    }
    if (checkpoint.roles_event_json.len > fleet_checkpoint_event_json_max) {
        return error.RolesEventTooLong;
    }
}

fn writeCheckpointRecord(
    record: *GroupFleetCheckpointRecord,
    checkpoint: *const group_client.GroupCheckpoint,
) void {
    @memset(record.relay_url[0..], 0);
    @memcpy(record.relay_url[0..checkpoint.relay_url.len], checkpoint.relay_url);
    record.relay_url_len = @intCast(checkpoint.relay_url.len);
    copyCheckpointField(
        record.metadata_event_json[0..],
        &record.metadata_event_json_len,
        checkpoint.metadata_event_json,
    );
    copyCheckpointField(
        record.admins_event_json[0..],
        &record.admins_event_json_len,
        checkpoint.admins_event_json,
    );
    copyCheckpointField(
        record.members_event_json[0..],
        &record.members_event_json_len,
        checkpoint.members_event_json,
    );
    copyCheckpointField(
        record.roles_event_json[0..],
        &record.roles_event_json_len,
        checkpoint.roles_event_json,
    );
    record.occupied = true;
}

fn copyCheckpointField(dest: []u8, len_out: *u32, input: []const u8) void {
    @memset(dest, 0);
    @memcpy(dest[0..input.len], input);
    len_out.* = @intCast(input.len);
}

fn storeRelayUrlText(dest: []u8, len_out: *u16, input: []const u8) void {
    @memset(dest, 0);
    @memcpy(dest[0..input.len], input);
    len_out.* = @intCast(input.len);
}

fn groupFleetCheckpointStorePut(
    ctx: *anyopaque,
    checkpoint: *const group_client.GroupCheckpoint,
) GroupFleetCheckpointStoreError!GroupFleetCheckpointStorePutOutcome {
    const self: *MemoryGroupFleetCheckpointStore = @ptrCast(@alignCast(ctx));
    return self.putCheckpoint(checkpoint);
}

fn groupFleetCheckpointStoreGet(
    ctx: *anyopaque,
    relay_url_text: []const u8,
) GroupFleetCheckpointStoreError!?group_client.GroupCheckpoint {
    const self: *MemoryGroupFleetCheckpointStore = @ptrCast(@alignCast(ctx));
    return self.getCheckpoint(relay_url_text);
}

const group_fleet_checkpoint_store_vtable = GroupFleetCheckpointStoreVTable{
    .put_checkpoint = groupFleetCheckpointStorePut,
    .get_checkpoint = groupFleetCheckpointStoreGet,
};

fn metadataEql(left: noztr.nip29_relay_groups.GroupMetadata, right: noztr.nip29_relay_groups.GroupMetadata) bool {
    return std.mem.eql(u8, left.group_id, right.group_id) and
        optionalTextEql(left.name, right.name) and
        optionalTextEql(left.picture, right.picture) and
        optionalTextEql(left.about, right.about) and
        left.is_private == right.is_private and
        left.is_restricted == right.is_restricted and
        left.is_hidden == right.is_hidden and
        left.is_closed == right.is_closed;
}

fn usersEql(
    left: []const noztr.nip29_relay_groups.GroupStateUser,
    right: []const noztr.nip29_relay_groups.GroupStateUser,
) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_user, right_user| {
        if (!std.mem.eql(u8, &left_user.pubkey, &right_user.pubkey)) return false;
        if (!optionalTextEql(left_user.label, right_user.label)) return false;
        if (left_user.is_member != right_user.is_member) return false;
        if (!textSliceSliceEql(left_user.roles, right_user.roles)) return false;
    }
    return true;
}

fn rolesEql(
    left: []const noztr.nip29_relay_groups.GroupRole,
    right: []const noztr.nip29_relay_groups.GroupRole,
) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_role, right_role| {
        if (!std.mem.eql(u8, left_role.name, right_role.name)) return false;
        if (!optionalTextEql(left_role.description, right_role.description)) return false;
    }
    return true;
}

fn optionalTextEql(left: ?[]const u8, right: ?[]const u8) bool {
    if (left == null and right == null) return true;
    if (left == null or right == null) return false;
    return std.mem.eql(u8, left.?, right.?);
}

fn textSliceSliceEql(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_text, right_text| {
        if (!std.mem.eql(u8, left_text, right_text)) return false;
    }
    return true;
}

test "group fleet routes relay-local event intake to the matching client" {
    storage_count = 0;
    serialize_buffer_index = 0;
    const fleet_storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = fleet_storage_a,
    });
    client_a.markCurrentRelayConnected();

    const fleet_storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = fleet_storage_b,
    });
    client_b.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    var fleet = try GroupFleet.init(clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    var snapshot_jsons = [_][]const u8{
        try serializeEvent(snapshot_events[0]),
        try serializeEvent(snapshot_events[1]),
        try serializeEvent(snapshot_events[2]),
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const routed = try fleet.consumeRelayEventJsons(
        "wss://relay.one",
        snapshot_jsons[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", routed.relay_url);
    try std.testing.expectEqual(@as(usize, 3), routed.summary.total);

    try std.testing.expectEqualStrings("Pizza Lovers", client_a.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 0), client_b.view().users.len);
}

test "group fleet exports and restores checkpoints by relay route" {
    storage_count = 0;
    const sender_storage = testStorage();
    var sender = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = sender_storage,
    });
    sender.markCurrentRelayConnected();

    const receiver_storage = testStorage();
    var receiver = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = receiver_storage,
    });

    var clients = [_]*group_client.GroupClient{ &sender, &receiver };
    var fleet = try GroupFleet.init(clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try sender.applySnapshotEvents(snapshot_events[0..]);

    var checkpoint_buffers = group_client.GroupCheckpointBuffers{};
    const checkpoint = try fleet.exportRelayCheckpoint(
        "wss://relay.one",
        .init(10, &test_author_secret, &checkpoint_buffers),
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try fleet.restoreRelayCheckpoint("wss://relay.one:444", &checkpoint, arena.allocator());
    try std.testing.expectEqualStrings("Pizza Lovers", receiver.view().metadata.name.?);
}

test "group fleet rejects duplicate relay urls and mismatched group references" {
    storage_count = 0;
    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "WSS://RELAY.ONE:443",
        .storage = storage_b,
    });
    var duplicate_clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    try std.testing.expectError(error.DuplicateRelayUrl, GroupFleet.init(duplicate_clients[0..]));

    const storage_c = testStorage();
    var client_c = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'cats",
        .relay_url = "wss://relay.one:444",
        .storage = storage_c,
    });
    var mismatched_clients = [_]*group_client.GroupClient{ &client_a, &client_c };
    try std.testing.expectError(error.GroupReferenceMismatch, GroupFleet.init(mismatched_clients[0..]));
}

test "group fleet runtime inspection classifies connect authenticate reconcile and ready actions" {
    storage_count = 0;
    serialize_buffer_index = 0;
    var baseline = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = testStorage(),
    });
    var auth_required = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = testStorage(),
    });
    var disconnected = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:555",
        .storage = testStorage(),
    });
    var divergent = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:666",
        .storage = testStorage(),
    });

    baseline.markCurrentRelayConnected();
    auth_required.markCurrentRelayConnected();
    disconnected.markCurrentRelayConnected();
    divergent.markCurrentRelayConnected();

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try baseline.applySnapshotEvents(snapshot_events[0..]);
    try auth_required.applySnapshotEvents(snapshot_events[0..]);
    try disconnected.applySnapshotEvents(snapshot_events[0..]);
    try divergent.applySnapshotEvents(snapshot_events[0..]);
    disconnected.noteCurrentRelayDisconnected();
    try auth_required.noteCurrentRelayAuthChallenge("challenge-1");

    var member_buffer = group_session.OutboundBuffer{};
    const extra_member = try divergent.beginMembersSnapshot(
        .init(30, &test_author_secret, &member_buffer),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "vip",
                },
                .{
                    .pubkey = [_]u8{0xbb} ** 32,
                    .label = "ops",
                },
            },
        },
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try divergent.consumeEventJson(extra_member.event_json, arena.allocator());

    var clients = [_]*group_client.GroupClient{
        &baseline,
        &auth_required,
        &disconnected,
        &divergent,
    };
    const fleet = try GroupFleet.init(clients[0..]);
    var runtime_storage = GroupFleetRuntimeStorage{};
    const runtime = try fleet.inspectRuntime("wss://relay.one", &runtime_storage);

    try std.testing.expectEqual(@as(u8, 4), runtime.relay_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.ready_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.connect_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.reconcile_count);
    try std.testing.expectEqualStrings("wss://relay.one", runtime.baseline_relay_url);

    const first = runtime.entry(0).?;
    try std.testing.expect(first.is_baseline);
    try std.testing.expectEqual(group_client.GroupRelayState.connected, first.relay_state);
    try std.testing.expectEqual(GroupFleetRuntimeAction.ready, first.action);
    try std.testing.expect(!first.anyDivergence());

    const second = runtime.entry(1).?;
    try std.testing.expectEqual(group_client.GroupRelayState.auth_required, second.relay_state);
    try std.testing.expectEqual(GroupFleetRuntimeAction.authenticate, second.action);

    const third = runtime.entry(2).?;
    try std.testing.expectEqual(group_client.GroupRelayState.disconnected, third.relay_state);
    try std.testing.expectEqual(GroupFleetRuntimeAction.connect, third.action);

    const fourth = runtime.entry(3).?;
    try std.testing.expectEqual(group_client.GroupRelayState.connected, fourth.relay_state);
    try std.testing.expectEqual(GroupFleetRuntimeAction.reconcile, fourth.action);
    try std.testing.expect(fourth.users_divergent);
}

test "group fleet runtime inspection rejects unknown baseline relay urls" {
    storage_count = 0;
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = testStorage(),
    });
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = testStorage(),
    });
    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    const fleet = try GroupFleet.init(clients[0..]);
    var runtime_storage = GroupFleetRuntimeStorage{};
    try std.testing.expectError(
        error.UnknownRelayUrl,
        fleet.inspectRuntime("wss://missing", &runtime_storage),
    );
}

test "group fleet exports and restores a full checkpoint set across relay-local clients" {
    storage_count = 0;
    serialize_buffer_index = 0;
    const source_storage_a = testStorage();
    var source_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = source_storage_a,
    });
    source_a.markCurrentRelayConnected();

    const source_storage_b = testStorage();
    var source_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = source_storage_b,
    });
    source_b.markCurrentRelayConnected();

    var source_clients = [_]*group_client.GroupClient{ &source_a, &source_b };
    var source_fleet = try GroupFleet.init(source_clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try source_a.applySnapshotEvents(snapshot_events[0..]);
    try source_b.applySnapshotEvents(snapshot_events[0..]);

    var previous_refs: [1][]const u8 = undefined;
    const selected = source_b.selectPreviousRefs(null, previous_refs[0..]);
    var outbound_buffer = group_session.OutboundBuffer{};
    const put_user_event = try source_b.beginPutUser(
        .init(5, &test_author_secret, &outbound_buffer),
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote second relay",
            .previous_refs = selected,
        },
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try source_b.consumeEventJson(put_user_event.event_json, arena.allocator());

    var checkpoint_storage = GroupFleetCheckpointStorage{};
    var checkpoint_context = GroupFleetCheckpointContext.init(
        20,
        &test_author_secret,
        &checkpoint_storage,
    );
    const checkpoint_set = try source_fleet.exportCheckpointSet(&checkpoint_context);
    try std.testing.expectEqual(@as(u8, 2), checkpoint_set.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", checkpoint_set.relayUrl(0).?);
    try std.testing.expectEqualStrings("wss://relay.one:444", checkpoint_set.relayUrl(1).?);

    const target_storage_a = testStorage();
    var target_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = target_storage_a,
    });
    const target_storage_b = testStorage();
    var target_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = target_storage_b,
    });
    var target_clients = [_]*group_client.GroupClient{ &target_a, &target_b };
    var target_fleet = try GroupFleet.init(target_clients[0..]);
    try target_fleet.restoreCheckpointSet(&checkpoint_set, arena.allocator());

    try std.testing.expectEqualStrings("Pizza Lovers", target_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", target_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), target_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), target_b.view().users.len);
}

test "group fleet reports divergence and reconciles all relays from an explicit source" {
    storage_count = 0;
    serialize_buffer_index = 0;
    const source_storage = testStorage();
    var source = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = source_storage,
    });
    source.markCurrentRelayConnected();

    const stale_storage = testStorage();
    var stale = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = stale_storage,
    });
    stale.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &source, &stale };
    var fleet = try GroupFleet.init(clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try source.applySnapshotEvents(snapshot_events[0..]);

    var divergences: [2]GroupFleetRelayDivergence = undefined;
    const before = try fleet.inspectConsistency(null, divergences[0..]);
    try std.testing.expectEqualStrings("wss://relay.one", before.baseline_relay_url);
    try std.testing.expectEqual(@as(u8, 2), before.total_relays);
    try std.testing.expectEqual(@as(u8, 1), before.matching_relays);
    try std.testing.expectEqual(@as(usize, 1), before.divergent_relays.len);
    try std.testing.expectEqualStrings("wss://relay.one:444", before.divergent_relays[0].relay_url);
    try std.testing.expect(before.divergent_relays[0].metadata);

    var checkpoint_storage = GroupFleetCheckpointStorage{};
    var checkpoint_context = GroupFleetCheckpointContext.init(
        40,
        &test_author_secret,
        &checkpoint_storage,
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const reconciled = try fleet.reconcileAllFromRelay(
        "wss://relay.one",
        &checkpoint_context,
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", reconciled.source_relay_url);
    try std.testing.expectEqual(@as(u8, 1), reconciled.reconciled_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", stale.view().metadata.name.?);

    const after = try fleet.inspectConsistency("wss://relay.one", divergences[0..]);
    try std.testing.expectEqual(@as(u8, 2), after.matching_relays);
    try std.testing.expectEqual(@as(usize, 0), after.divergent_relays.len);
}

test "group fleet rejects unknown baseline and source relay urls during reconciliation work" {
    storage_count = 0;
    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    var fleet = try GroupFleet.init(clients[0..]);

    var divergences: [2]GroupFleetRelayDivergence = undefined;
    try std.testing.expectError(
        error.UnknownRelayUrl,
        fleet.inspectConsistency("wss://missing", divergences[0..]),
    );

    var checkpoint_storage = GroupFleetCheckpointStorage{};
    var checkpoint_context = GroupFleetCheckpointContext.init(
        60,
        &test_author_secret,
        &checkpoint_storage,
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(
        error.UnknownRelayUrl,
        fleet.reconcileAllFromRelay("wss://missing", &checkpoint_context, arena.allocator()),
    );
    try std.testing.expectError(
        error.UnknownRelayUrl,
        fleet.reconcileRelayFromBaseline(
            "wss://relay.one",
            "wss://missing",
            &checkpoint_context,
            arena.allocator(),
        ),
    );
}

test "group fleet can reconcile one target relay from an explicit baseline" {
    storage_count = 0;
    serialize_buffer_index = 0;

    const baseline_storage = testStorage();
    var baseline = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = baseline_storage,
    });
    baseline.markCurrentRelayConnected();

    const target_storage = testStorage();
    var target = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = target_storage,
    });
    target.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &baseline, &target };
    var fleet = try GroupFleet.init(clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try baseline.applySnapshotEvents(snapshot_events[0..]);

    var runtime_storage = GroupFleetRuntimeStorage{};
    const before = try fleet.inspectRuntime("wss://relay.one", &runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), before.reconcile_count);
    try std.testing.expectEqual(GroupFleetRuntimeAction.reconcile, before.entry(1).?.action);

    var checkpoint_storage = GroupFleetCheckpointStorage{};
    var checkpoint_context = GroupFleetCheckpointContext.init(
        70,
        &test_author_secret,
        &checkpoint_storage,
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const reconciled = try fleet.reconcileRelayFromBaseline(
        "wss://relay.one",
        "wss://relay.one:444",
        &checkpoint_context,
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("wss://relay.one", reconciled.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", reconciled.target_relay_url);
    try std.testing.expectEqualStrings("Pizza Lovers", target.view().metadata.name.?);

    const after = try fleet.inspectRuntime("wss://relay.one", &runtime_storage);
    try std.testing.expectEqual(@as(u8, 0), after.reconcile_count);
    try std.testing.expectEqual(@as(u8, 2), after.ready_count);
    try std.testing.expectEqual(GroupFleetRuntimeAction.ready, after.entry(0).?.action);
    try std.testing.expectEqual(GroupFleetRuntimeAction.ready, after.entry(1).?.action);
}

test "group fleet rejects targeted reconcile when the target relay is already the baseline" {
    storage_count = 0;
    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    var fleet = try GroupFleet.init(clients[0..]);

    var checkpoint_storage = GroupFleetCheckpointStorage{};
    var checkpoint_context = GroupFleetCheckpointContext.init(
        80,
        &test_author_secret,
        &checkpoint_storage,
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(
        error.CannotReconcileBaselineRelay,
        fleet.reconcileRelayFromBaseline(
            "wss://relay.one",
            "wss://relay.one",
            &checkpoint_context,
            arena.allocator(),
        ),
    );
}

test "group fleet persists checkpoints into a bounded store and restores them into a fresh fleet" {
    storage_count = 0;
    serialize_buffer_index = 0;

    const source_storage_a = testStorage();
    var source_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = source_storage_a,
    });
    source_a.markCurrentRelayConnected();

    const source_storage_b = testStorage();
    var source_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = source_storage_b,
    });
    source_b.markCurrentRelayConnected();

    var source_clients = [_]*group_client.GroupClient{ &source_a, &source_b };
    var source_fleet = try GroupFleet.init(source_clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try source_a.applySnapshotEvents(snapshot_events[0..]);
    try source_b.applySnapshotEvents(snapshot_events[0..]);

    var previous_refs: [1][]const u8 = undefined;
    const selected = source_b.selectPreviousRefs(null, previous_refs[0..]);
    var outbound_buffer = group_session.OutboundBuffer{};
    const put_user = try source_b.beginPutUser(
        .init(10, &test_author_secret, &outbound_buffer),
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .roles = &.{"moderator"},
            .reason = "promote relay two user",
            .previous_refs = selected,
        },
    );
    var source_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer source_arena.deinit();
    _ = try source_b.consumeEventJson(put_user.event_json, source_arena.allocator());

    var checkpoint_storage = GroupFleetCheckpointStorage{};
    var checkpoint_context = GroupFleetCheckpointContext.init(
        20,
        &test_author_secret,
        &checkpoint_storage,
    );
    var store_records: [2]GroupFleetCheckpointRecord = [_]GroupFleetCheckpointRecord{ .{}, .{} };
    var memory_store = MemoryGroupFleetCheckpointStore.init(store_records[0..]);
    const persisted = try source_fleet.persistCheckpointStore(
        memory_store.asStore(),
        &checkpoint_context,
    );
    try std.testing.expectEqual(@as(u8, 2), persisted.stored_relays);
    try std.testing.expectEqual(@as(u8, 0), persisted.replaced_relays);

    const target_storage_a = testStorage();
    var target_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = target_storage_a,
    });
    const target_storage_b = testStorage();
    var target_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = target_storage_b,
    });
    var target_clients = [_]*group_client.GroupClient{ &target_a, &target_b };
    var target_fleet = try GroupFleet.init(target_clients[0..]);

    var restore_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer restore_arena.deinit();
    const restored = try target_fleet.restoreCheckpointStore(
        memory_store.asStore(),
        restore_arena.allocator(),
    );
    try std.testing.expectEqual(@as(u8, 2), restored.restored_relays);
    try std.testing.expectEqual(@as(u8, 0), restored.missing_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", target_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", target_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), target_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), target_b.view().users.len);
}

test "memory group fleet checkpoint store replaces normalized relay entries and restore reports missing relays" {
    storage_count = 0;
    serialize_buffer_index = 0;

    const source_storage = testStorage();
    var source = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = source_storage,
    });
    source.markCurrentRelayConnected();
    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try source.applySnapshotEvents(snapshot_events[0..]);

    var first_buffers = group_client.GroupCheckpointBuffers{};
    const first_checkpoint = try source.exportCheckpoint(
        .init(30, &test_author_secret, &first_buffers),
    );

    const equivalent_storage = testStorage();
    var equivalent = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "WSS://RELAY.ONE:443",
        .storage = equivalent_storage,
    });
    equivalent.markCurrentRelayConnected();
    try equivalent.applySnapshotEvents(snapshot_events[0..]);

    var second_buffers = group_client.GroupCheckpointBuffers{};
    const second_checkpoint = try equivalent.exportCheckpoint(
        .init(40, &test_author_secret, &second_buffers),
    );

    var store_records: [1]GroupFleetCheckpointRecord = [_]GroupFleetCheckpointRecord{.{}} ** 1;
    var memory_store = MemoryGroupFleetCheckpointStore.init(store_records[0..]);
    try std.testing.expectEqual(
        GroupFleetCheckpointStorePutOutcome.stored,
        try memory_store.putCheckpoint(&first_checkpoint),
    );
    try std.testing.expectEqual(
        GroupFleetCheckpointStorePutOutcome.replaced,
        try memory_store.putCheckpoint(&second_checkpoint),
    );

    const cached = (try memory_store.getCheckpoint("wss://relay.one")) orelse unreachable;
    try std.testing.expect(std.mem.indexOf(u8, cached.metadata_event_json, "\"Pizza Lovers\"") != null);

    const target_storage_a = testStorage();
    var target_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = target_storage_a,
    });
    const target_storage_b = testStorage();
    var target_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:555",
        .storage = target_storage_b,
    });
    var target_clients = [_]*group_client.GroupClient{ &target_a, &target_b };
    var fleet = try GroupFleet.init(target_clients[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const restored = try fleet.restoreCheckpointStore(memory_store.asStore(), arena.allocator());
    try std.testing.expectEqual(@as(u8, 1), restored.restored_relays);
    try std.testing.expectEqual(@as(u8, 1), restored.missing_relays);
    try std.testing.expectEqualStrings("Pizza Lovers", target_a.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 0), target_b.view().users.len);
}

test "group fleet builds and replays one put-user publish across all relays" {
    storage_count = 0;
    serialize_buffer_index = 0;

    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    client_a.markCurrentRelayConnected();
    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    client_b.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    var fleet = try GroupFleet.init(clients[0..]);
    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try client_a.applySnapshotEvents(snapshot_events[0..]);
    try client_b.applySnapshotEvents(snapshot_events[0..]);

    var publish_buffers: [2]group_session.OutboundBuffer = .{ .{}, .{} };
    var previous_refs_a: [8][]const u8 = undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var previous_refs = [_][][]const u8{
        previous_refs_a[0..],
        previous_refs_b[0..],
    };
    var outbound_events: [2]group_session.OutboundEvent = undefined;
    var publish_storage = GroupFleetPublishStorage.init(
        publish_buffers[0..],
        previous_refs[0..],
        outbound_events[0..],
    );
    var publish_context = GroupFleetPublishContext.init(50, &test_author_secret, &publish_storage);

    const fanout = try fleet.beginPutUserForAll(
        &publish_context,
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .roles = &.{"moderator"},
            .reason = "fleet moderation",
        },
    );

    try std.testing.expectEqual(@as(usize, 2), fanout.len);
    try std.testing.expectEqualStrings("wss://relay.one", fanout[0].relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", fanout[1].relay_url);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for (fanout) |outbound| {
        _ = try fleet.consumeRelayEventJson(outbound.relay_url, outbound.event_json, arena.allocator());
    }

    try std.testing.expectEqual(@as(usize, 2), client_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), client_b.view().users.len);
}

test "group fleet builds and replays one remove-user publish across all relays" {
    storage_count = 0;
    serialize_buffer_index = 0;

    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    client_a.markCurrentRelayConnected();
    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    client_b.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    var fleet = try GroupFleet.init(clients[0..]);
    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try client_a.applySnapshotEvents(snapshot_events[0..]);
    try client_b.applySnapshotEvents(snapshot_events[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var seed_buffers: [2]group_session.OutboundBuffer = .{ .{}, .{} };
    var seed_previous_refs_a: [8][]const u8 = undefined;
    var seed_previous_refs_b: [8][]const u8 = undefined;
    var seed_previous_refs = [_][][]const u8{
        seed_previous_refs_a[0..],
        seed_previous_refs_b[0..],
    };
    var seed_events: [2]group_session.OutboundEvent = undefined;
    var seed_publish_storage = GroupFleetPublishStorage.init(
        seed_buffers[0..],
        seed_previous_refs[0..],
        seed_events[0..],
    );
    var seed_publish_context = GroupFleetPublishContext.init(60, &test_author_secret, &seed_publish_storage);
    const seeded = try fleet.beginPutUserForAll(
        &seed_publish_context,
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .roles = &.{"moderator"},
            .reason = "seed user",
        },
    );
    for (seeded) |outbound| {
        _ = try fleet.consumeRelayEventJson(outbound.relay_url, outbound.event_json, arena.allocator());
    }

    var publish_buffers: [2]group_session.OutboundBuffer = .{ .{}, .{} };
    var previous_refs_a: [8][]const u8 = undefined;
    var previous_refs_b: [8][]const u8 = undefined;
    var previous_refs = [_][][]const u8{
        previous_refs_a[0..],
        previous_refs_b[0..],
    };
    var outbound_events: [2]group_session.OutboundEvent = undefined;
    var publish_storage = GroupFleetPublishStorage.init(
        publish_buffers[0..],
        previous_refs[0..],
        outbound_events[0..],
    );
    var publish_context = GroupFleetPublishContext.init(70, &test_author_secret, &publish_storage);
    const fanout = try fleet.beginRemoveUserForAll(
        &publish_context,
        &.{
            .pubkey = [_]u8{0xbb} ** 32,
            .reason = "fleet cleanup",
        },
    );

    try std.testing.expectEqual(@as(usize, 2), fanout.len);
    for (fanout) |outbound| {
        _ = try fleet.consumeRelayEventJson(outbound.relay_url, outbound.event_json, arena.allocator());
    }

    try std.testing.expectEqual(@as(usize, 1), client_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 1), client_b.view().users.len);
}

test "group fleet publish fanout surfaces bounded storage pressure" {
    storage_count = 0;
    serialize_buffer_index = 0;

    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    client_a.markCurrentRelayConnected();
    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    client_b.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    const fleet = try GroupFleet.init(clients[0..]);
    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try client_a.applySnapshotEvents(snapshot_events[0..]);
    try client_b.applySnapshotEvents(snapshot_events[0..]);

    var publish_buffers: [1]group_session.OutboundBuffer = .{.{}};
    var previous_refs_a: [8][]const u8 = undefined;
    var previous_refs = [_][][]const u8{
        previous_refs_a[0..],
    };
    var outbound_events: [1]group_session.OutboundEvent = undefined;
    var publish_storage = GroupFleetPublishStorage.init(
        publish_buffers[0..],
        previous_refs[0..],
        outbound_events[0..],
    );
    var publish_context = GroupFleetPublishContext.init(80, &test_author_secret, &publish_storage);

    try std.testing.expectError(
        error.BufferTooSmall,
        fleet.beginPutUserForAll(
            &publish_context,
            &.{
                .pubkey = [_]u8{0xbb} ** 32,
                .roles = &.{"moderator"},
            },
        ),
    );
}

test "group fleet builds and applies a merged checkpoint from explicit component relay selection" {
    storage_count = 0;

    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    client_a.markCurrentRelayConnected();

    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    client_b.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    var fleet = try GroupFleet.init(clients[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var metadata_buffer_a = group_session.OutboundBuffer{};
    const metadata_event_a = try client_a.beginMetadataSnapshot(
        .init(1, &test_author_secret, &metadata_buffer_a),
        &.{ .name = "Pizza Lovers" },
    );
    _ = try fleet.consumeRelayEventJson("wss://relay.one", metadata_event_a.event_json, arena.allocator());

    var members_buffer_a = group_session.OutboundBuffer{};
    const members_event_a = try client_a.beginMembersSnapshot(
        .init(2, &test_author_secret, &members_buffer_a),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xaa} ** 32,
                    .label = "alpha",
                },
            },
        },
    );
    _ = try fleet.consumeRelayEventJson("wss://relay.one", members_event_a.event_json, arena.allocator());

    var metadata_buffer_b = group_session.OutboundBuffer{};
    const metadata_event_b = try client_b.beginMetadataSnapshot(
        .init(3, &test_author_secret, &metadata_buffer_b),
        &.{ .name = "Pizza Lovers Relay Two" },
    );
    _ = try fleet.consumeRelayEventJson("wss://relay.one:444", metadata_event_b.event_json, arena.allocator());

    var members_buffer_b = group_session.OutboundBuffer{};
    const members_event_b = try client_b.beginMembersSnapshot(
        .init(4, &test_author_secret, &members_buffer_b),
        &.{
            .members = &.{
                .{
                    .pubkey = [_]u8{0xbb} ** 32,
                    .label = "beta",
                },
                .{
                    .pubkey = [_]u8{0xcc} ** 32,
                    .label = "gamma",
                },
            },
        },
    );
    _ = try fleet.consumeRelayEventJson("wss://relay.one:444", members_event_b.event_json, arena.allocator());

    var merge_storage = GroupFleetMergeStorage{};
    var merge_context = GroupFleetMergeContext.init(20, &test_author_secret, &merge_storage);
    const merged = try fleet.buildMergedCheckpoint(
        &.{
            .baseline_relay_url = "wss://relay.one",
            .members_relay_url = "wss://relay.one:444",
        },
        &merge_context,
    );
    try std.testing.expectEqualStrings("wss://relay.one", merged.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", merged.metadata_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", merged.admins_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.members_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one", merged.roles_source_relay_url);

    const applied = try fleet.applyMergedCheckpointToAll(&merged, arena.allocator());
    try std.testing.expectEqual(@as(u8, 2), applied.applied_relays);
    try std.testing.expectEqualStrings("wss://relay.one:444", applied.members_source_relay_url);

    try std.testing.expectEqualStrings("Pizza Lovers", client_a.view().metadata.name.?);
    try std.testing.expectEqualStrings("Pizza Lovers", client_b.view().metadata.name.?);
    try std.testing.expectEqual(@as(usize, 2), client_a.view().users.len);
    try std.testing.expectEqual(@as(usize, 2), client_b.view().users.len);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xbb} ** 32), &client_a.view().users[0].pubkey);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xbb} ** 32), &client_b.view().users[0].pubkey);
}

test "group fleet merged checkpoint selection falls back to baseline and rejects unknown relay urls" {
    storage_count = 0;

    const storage_a = testStorage();
    var client_a = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = storage_a,
    });
    client_a.markCurrentRelayConnected();

    const storage_b = testStorage();
    var client_b = try group_client.GroupClient.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one:444",
        .storage = storage_b,
    });
    client_b.markCurrentRelayConnected();

    var clients = [_]*group_client.GroupClient{ &client_a, &client_b };
    const fleet = try GroupFleet.init(clients[0..]);

    const snapshot_events = try buildSnapshotEvents("pizza-lovers");
    try client_a.applySnapshotEvents(snapshot_events[0..]);
    try client_b.applySnapshotEvents(snapshot_events[0..]);

    var merge_storage = GroupFleetMergeStorage{};
    var merge_context = GroupFleetMergeContext.init(40, &test_author_secret, &merge_storage);
    const merged = try fleet.buildMergedCheckpoint(
        &.{ .baseline_relay_url = "wss://relay.one:444" },
        &merge_context,
    );
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.baseline_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.metadata_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.admins_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.members_source_relay_url);
    try std.testing.expectEqualStrings("wss://relay.one:444", merged.roles_source_relay_url);

    try std.testing.expectError(
        error.UnknownRelayUrl,
        fleet.buildMergedCheckpoint(
            &.{ .members_relay_url = "wss://relay.unknown" },
            &merge_context,
        ),
    );
}

const TestStorage = struct {
    users: [2]noztr.nip29_relay_groups.GroupStateUser = undefined,
    roles: [1]noztr.nip29_relay_groups.GroupRole = undefined,
    user_roles: [2 * noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined,
    previous_refs: [8][]const u8 = undefined,

    fn asStorage(self: *TestStorage) group_client.GroupClientStorage {
        return .init(
            .init(self.users[0..], self.roles[0..], self.user_roles[0..]),
            self.previous_refs[0..],
        );
    }
};

const test_author_secret = [_]u8{0x09} ** 32;

var storage_pool: [8]TestStorage = undefined;
var storage_count: usize = 0;
fn testStorage() group_client.GroupClientStorage {
    const index = storage_count;
    storage_count += 1;
    storage_pool[index] = .{};
    return storage_pool[index].asStorage();
}

fn buildSnapshotEvents(group_id: []const u8) ![3]*const noztr.nip01_event.Event {
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(&test_author_secret);

    snapshot_storage.metadata_group_items = .{ "d", group_id };
    snapshot_storage.metadata_name_items = .{ "name", "Pizza Lovers" };
    snapshot_storage.metadata_public_items = .{"public"};
    snapshot_storage.metadata_tags = .{
        .{ .items = snapshot_storage.metadata_group_items[0..] },
        .{ .items = snapshot_storage.metadata_name_items[0..] },
        .{ .items = snapshot_storage.metadata_public_items[0..] },
    };

    snapshot_storage.roles_group_items = .{ "d", group_id };
    snapshot_storage.roles_role_items = .{ "role", "moderator", "Can moderate" };
    snapshot_storage.roles_tags = .{
        .{ .items = snapshot_storage.roles_group_items[0..] },
        .{ .items = snapshot_storage.roles_role_items[0..] },
    };

    snapshot_storage.members_group_items = .{ "d", group_id };
    snapshot_storage.members_user_items = .{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "vip",
    };
    snapshot_storage.members_tags = .{
        .{ .items = snapshot_storage.members_group_items[0..] },
        .{ .items = snapshot_storage.members_user_items[0..] },
    };

    snapshot_storage.metadata = .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip29_relay_groups.group_metadata_kind,
        .created_at = 1,
        .content = "",
        .tags = snapshot_storage.metadata_tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&test_author_secret, &snapshot_storage.metadata);

    snapshot_storage.roles = .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip29_relay_groups.group_roles_kind,
        .created_at = 2,
        .content = "",
        .tags = snapshot_storage.roles_tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&test_author_secret, &snapshot_storage.roles);

    snapshot_storage.members = .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip29_relay_groups.group_members_kind,
        .created_at = 3,
        .content = "",
        .tags = snapshot_storage.members_tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&test_author_secret, &snapshot_storage.members);

    return .{
        &snapshot_storage.metadata,
        &snapshot_storage.roles,
        &snapshot_storage.members,
    };
}

var serialize_buffers: [3][noztr.limits.event_json_max]u8 = undefined;
var serialize_buffer_index: usize = 0;

fn serializeEvent(event: *const noztr.nip01_event.Event) ![]const u8 {
    const index = serialize_buffer_index;
    serialize_buffer_index += 1;
    return try noztr.nip01_event.event_serialize_json_object(serialize_buffers[index][0..], event);
}

var snapshot_storage: struct {
    metadata_group_items: [2][]const u8 = undefined,
    metadata_name_items: [2][]const u8 = undefined,
    metadata_public_items: [1][]const u8 = undefined,
    metadata_tags: [3]noztr.nip01_event.EventTag = undefined,
    roles_group_items: [2][]const u8 = undefined,
    roles_role_items: [3][]const u8 = undefined,
    roles_tags: [2]noztr.nip01_event.EventTag = undefined,
    members_group_items: [2][]const u8 = undefined,
    members_user_items: [3][]const u8 = undefined,
    members_tags: [2]noztr.nip01_event.EventTag = undefined,
    metadata: noztr.nip01_event.Event = undefined,
    roles: noztr.nip01_event.Event = undefined,
    members: noztr.nip01_event.Event = undefined,
} = undefined;
