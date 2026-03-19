const std = @import("std");
const noztr = @import("noztr");

pub const ClientStoreError = error{
    InvalidEventId,
    InvalidEventPubkey,
    InvalidEventJson,
    EventJsonTooLong,
    EventRecordMismatch,
    InvalidCheckpointName,
    CheckpointNameTooLong,
    StoreFull,
};

pub const event_id_hex_bytes: u8 = 64;
pub const event_pubkey_hex_bytes: u8 = 64;
pub const event_json_max_bytes: u32 = noztr.limits.event_json_max;
pub const checkpoint_name_max_bytes: u8 = 64;

pub const EventIdHex = [event_id_hex_bytes]u8;
pub const EventPubkeyHex = [event_pubkey_hex_bytes]u8;

pub const IndexSelection = enum {
    automatic,
    id_lookup,
    author_time,
    kind_time,
    checkpoint_replay,
};

pub const EventCursor = struct {
    offset: u32 = 0,
};

pub const ClientEventRecord = struct {
    id_hex: EventIdHex = [_]u8{0} ** event_id_hex_bytes,
    pubkey_hex: EventPubkeyHex = [_]u8{0} ** event_pubkey_hex_bytes,
    kind: u32 = 0,
    created_at: u64 = 0,
    event_json: [event_json_max_bytes]u8 = [_]u8{0} ** event_json_max_bytes,
    event_json_len: u32 = 0,

    pub fn eventJson(self: *const ClientEventRecord) []const u8 {
        std.debug.assert(self.event_json_len <= event_json_max_bytes);
        return self.event_json[0..self.event_json_len];
    }

    pub fn matches(self: *const ClientEventRecord, query: *const ClientQuery) bool {
        if (query.ids.len > 0 and !event_id_in_query(self.id_hex, query.ids)) return false;
        if (query.authors.len > 0 and !event_pubkey_in_query(self.pubkey_hex, query.authors)) return false;
        if (query.kinds.len > 0 and !event_kind_in_query(self.kind, query.kinds)) return false;
        if (query.since) |since| {
            if (self.created_at < since) return false;
        }
        if (query.until) |until| {
            if (self.created_at > until) return false;
        }
        return true;
    }
};

pub const ClientCheckpointRecord = struct {
    name: [checkpoint_name_max_bytes]u8 = [_]u8{0} ** checkpoint_name_max_bytes,
    name_len: u8 = 0,
    cursor: EventCursor = .{},

    pub fn nameSlice(self: *const ClientCheckpointRecord) []const u8 {
        std.debug.assert(self.name_len <= checkpoint_name_max_bytes);
        return self.name[0..self.name_len];
    }
};

pub const ClientQuery = struct {
    ids: []const EventIdHex = &.{},
    authors: []const EventPubkeyHex = &.{},
    kinds: []const u32 = &.{},
    since: ?u64 = null,
    until: ?u64 = null,
    cursor: ?EventCursor = null,
    limit: usize = 0,
    index_selection: IndexSelection = .automatic,
};

pub fn QueryResultPage(comptime T: type) type {
    return struct {
        items: []T,
        count: usize = 0,
        next_cursor: ?EventCursor = null,
        truncated: bool = false,

        pub fn init(storage: []T) @This() {
            return .{ .items = storage };
        }

        pub fn reset(self: *@This()) void {
            self.count = 0;
            self.next_cursor = null;
            self.truncated = false;
        }

        pub fn slice(self: *const @This()) []const T {
            std.debug.assert(self.count <= self.items.len);
            return self.items[0..self.count];
        }
    };
}

pub const EventQueryResultPage = QueryResultPage(ClientEventRecord);

pub const ClientEventStoreVTable = struct {
    put_event: *const fn (ctx: *anyopaque, record: *const ClientEventRecord) ClientStoreError!void,
    get_event_by_id:
        *const fn (ctx: *anyopaque, event_id_hex: []const u8) ClientStoreError!?ClientEventRecord,
    query_events:
        *const fn (ctx: *anyopaque, query: *const ClientQuery, page: *EventQueryResultPage) ClientStoreError!void,
};

pub const ClientEventStore = struct {
    ctx: *anyopaque,
    vtable: *const ClientEventStoreVTable,

    pub fn putEvent(self: ClientEventStore, record: *const ClientEventRecord) ClientStoreError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.put_event(self.ctx, record);
    }

    pub fn getEventById(
        self: ClientEventStore,
        event_id_hex: []const u8,
    ) ClientStoreError!?ClientEventRecord {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.get_event_by_id(self.ctx, event_id_hex);
    }

    pub fn queryEvents(
        self: ClientEventStore,
        query: *const ClientQuery,
        page: *EventQueryResultPage,
    ) ClientStoreError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.query_events(self.ctx, query, page);
    }
};

pub const ClientCheckpointStoreVTable = struct {
    put_checkpoint:
        *const fn (ctx: *anyopaque, record: *const ClientCheckpointRecord) ClientStoreError!void,
    get_checkpoint:
        *const fn (ctx: *anyopaque, name: []const u8) ClientStoreError!?ClientCheckpointRecord,
};

pub const ClientCheckpointStore = struct {
    ctx: *anyopaque,
    vtable: *const ClientCheckpointStoreVTable,

    pub fn putCheckpoint(
        self: ClientCheckpointStore,
        record: *const ClientCheckpointRecord,
    ) ClientStoreError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.put_checkpoint(self.ctx, record);
    }

    pub fn getCheckpoint(
        self: ClientCheckpointStore,
        name: []const u8,
    ) ClientStoreError!?ClientCheckpointRecord {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.vtable.get_checkpoint(self.ctx, name);
    }
};

pub const ClientStore = struct {
    event_store: ?ClientEventStore = null,
    checkpoint_store: ?ClientCheckpointStore = null,

    pub fn init(event_store: ?ClientEventStore, checkpoint_store: ?ClientCheckpointStore) ClientStore {
        return .{
            .event_store = event_store,
            .checkpoint_store = checkpoint_store,
        };
    }
};

pub fn client_event_record_from_json(
    event_json: []const u8,
    scratch: std.mem.Allocator,
) ClientStoreError!ClientEventRecord {
    if (event_json.len > event_json_max_bytes) return error.EventJsonTooLong;
    const event = noztr.nip01_event.event_parse_json(event_json, scratch) catch {
        return error.InvalidEventJson;
    };

    var record = ClientEventRecord{};
    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    @memcpy(record.id_hex[0..], id_hex[0..]);
    @memcpy(record.pubkey_hex[0..], pubkey_hex[0..]);
    record.kind = event.kind;
    record.created_at = event.created_at;
    @memcpy(record.event_json[0..event_json.len], event_json);
    record.event_json_len = @intCast(event_json.len);
    return record;
}

pub fn client_checkpoint_record_from_name(
    name: []const u8,
    cursor: EventCursor,
) ClientStoreError!ClientCheckpointRecord {
    if (name.len == 0) return error.InvalidCheckpointName;
    if (name.len > checkpoint_name_max_bytes) return error.CheckpointNameTooLong;

    var record = ClientCheckpointRecord{ .cursor = cursor };
    @memcpy(record.name[0..name.len], name);
    record.name_len = @intCast(name.len);
    return record;
}

pub fn event_id_hex_from_text(text: []const u8) ClientStoreError!EventIdHex {
    if (!is_valid_hex_64(text)) return error.InvalidEventId;
    var value: EventIdHex = undefined;
    @memcpy(value[0..], text);
    return value;
}

pub fn event_pubkey_hex_from_text(text: []const u8) ClientStoreError!EventPubkeyHex {
    if (!is_valid_hex_64(text)) return error.InvalidEventPubkey;
    var value: EventPubkeyHex = undefined;
    @memcpy(value[0..], text);
    return value;
}

fn event_id_in_query(event_id: EventIdHex, ids: []const EventIdHex) bool {
    var index: usize = 0;
    while (index < ids.len) : (index += 1) {
        if (std.mem.eql(u8, &event_id, &ids[index])) return true;
    }
    return false;
}

fn event_pubkey_in_query(pubkey: EventPubkeyHex, authors: []const EventPubkeyHex) bool {
    var index: usize = 0;
    while (index < authors.len) : (index += 1) {
        if (std.mem.eql(u8, &pubkey, &authors[index])) return true;
    }
    return false;
}

fn event_kind_in_query(kind: u32, kinds: []const u32) bool {
    var index: usize = 0;
    while (index < kinds.len) : (index += 1) {
        if (kind == kinds[index]) return true;
    }
    return false;
}

fn is_valid_hex_64(text: []const u8) bool {
    if (text.len != event_id_hex_bytes) return false;

    var index: usize = 0;
    while (index < text.len) : (index += 1) {
        if (!std.ascii.isHex(text[index])) return false;
    }
    return true;
}

test "client event record helper parses valid event json into bounded metadata" {
    const event_json =
        \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"2222222222222222222222222222222222222222222222222222222222222222","created_at":42,"kind":1,"tags":[],"content":"hello","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const record = try client_event_record_from_json(event_json, arena.allocator());
    try std.testing.expectEqualStrings(
        "1111111111111111111111111111111111111111111111111111111111111111",
        &record.id_hex,
    );
    try std.testing.expectEqualStrings(
        "2222222222222222222222222222222222222222222222222222222222222222",
        &record.pubkey_hex,
    );
    try std.testing.expectEqual(@as(u32, 1), record.kind);
    try std.testing.expectEqual(@as(u64, 42), record.created_at);
}

test "checkpoint helper rejects empty names" {
    try std.testing.expectError(
        error.InvalidCheckpointName,
        client_checkpoint_record_from_name("", .{ .offset = 1 }),
    );
}
