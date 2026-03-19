const std = @import("std");
const client = @import("client_traits.zig");

pub const default_event_capacity: u8 = 64;
pub const default_checkpoint_capacity: u8 = 16;

pub const MemoryClientStore = struct {
    events: [default_event_capacity]client.ClientEventRecord = [_]client.ClientEventRecord{.{}} **
        default_event_capacity,
    event_count: u8 = 0,
    checkpoints: [default_checkpoint_capacity]client.ClientCheckpointRecord =
        [_]client.ClientCheckpointRecord{.{}} ** default_checkpoint_capacity,
    checkpoint_count: u8 = 0,

    pub fn asClientStore(self: *MemoryClientStore) client.ClientStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .init(self.asEventStore(), self.asCheckpointStore());
    }

    pub fn asEventStore(self: *MemoryClientStore) client.ClientEventStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .{ .ctx = self, .vtable = &event_store_vtable };
    }

    pub fn asCheckpointStore(self: *MemoryClientStore) client.ClientCheckpointStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .{ .ctx = self, .vtable = &checkpoint_store_vtable };
    }

    pub fn putEvent(
        self: *MemoryClientStore,
        record: *const client.ClientEventRecord,
    ) client.ClientStoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        const existing = find_event_index(self, &record.id_hex);
        if (existing) |index| {
            self.events[index] = record.*;
            return;
        }
        if (self.event_count == default_event_capacity) return error.StoreFull;

        self.events[self.event_count] = record.*;
        self.event_count += 1;
    }

    pub fn getEventById(
        self: *MemoryClientStore,
        event_id_hex: []const u8,
    ) client.ClientStoreError!?client.ClientEventRecord {
        std.debug.assert(@intFromPtr(self) != 0);

        const parsed_id = try client.event_id_hex_from_text(event_id_hex);
        const existing = find_event_index(self, &parsed_id);
        if (existing) |index| return self.events[index];
        return null;
    }

    pub fn queryEvents(
        self: *MemoryClientStore,
        query: *const client.ClientQuery,
        page: *client.EventQueryResultPage,
    ) client.ClientStoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        var matching_indexes: [default_event_capacity]u8 = undefined;
        const match_count = collect_matching_indexes(self, query, matching_indexes[0..]);
        sort_matching_indexes(self, matching_indexes[0..match_count]);

        page.reset();
        const start = query.cursor orelse client.EventCursor{};
        if (start.offset >= match_count) return;

        const write_limit = result_limit(query, page.items.len);
        const available = match_count - start.offset;
        const write_count = @min(write_limit, available);

        var index: usize = 0;
        while (index < write_count) : (index += 1) {
            const match_index = matching_indexes[start.offset + index];
            page.items[index] = self.events[match_index];
        }

        page.count = write_count;
        page.truncated = write_count < available;
        if (page.truncated) {
            page.next_cursor = .{ .offset = @intCast(start.offset + write_count) };
        }
    }

    pub fn putCheckpoint(
        self: *MemoryClientStore,
        record: *const client.ClientCheckpointRecord,
    ) client.ClientStoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        const existing = find_checkpoint_index(self, record.nameSlice());
        if (existing) |index| {
            self.checkpoints[index] = record.*;
            return;
        }
        if (self.checkpoint_count == default_checkpoint_capacity) return error.StoreFull;

        self.checkpoints[self.checkpoint_count] = record.*;
        self.checkpoint_count += 1;
    }

    pub fn getCheckpoint(
        self: *MemoryClientStore,
        name: []const u8,
    ) client.ClientStoreError!?client.ClientCheckpointRecord {
        std.debug.assert(@intFromPtr(self) != 0);

        if (name.len == 0) return error.InvalidCheckpointName;
        if (name.len > client.checkpoint_name_max_bytes) return error.CheckpointNameTooLong;

        const existing = find_checkpoint_index(self, name);
        if (existing) |index| return self.checkpoints[index];
        return null;
    }
};

fn put_event(
    ctx: *anyopaque,
    record: *const client.ClientEventRecord,
) client.ClientStoreError!void {
    const self: *MemoryClientStore = @ptrCast(@alignCast(ctx));
    return self.putEvent(record);
}

fn get_event_by_id(
    ctx: *anyopaque,
    event_id_hex: []const u8,
) client.ClientStoreError!?client.ClientEventRecord {
    const self: *MemoryClientStore = @ptrCast(@alignCast(ctx));
    return self.getEventById(event_id_hex);
}

fn query_events(
    ctx: *anyopaque,
    query: *const client.ClientQuery,
    page: *client.EventQueryResultPage,
) client.ClientStoreError!void {
    const self: *MemoryClientStore = @ptrCast(@alignCast(ctx));
    return self.queryEvents(query, page);
}

fn put_checkpoint(
    ctx: *anyopaque,
    record: *const client.ClientCheckpointRecord,
) client.ClientStoreError!void {
    const self: *MemoryClientStore = @ptrCast(@alignCast(ctx));
    return self.putCheckpoint(record);
}

fn get_checkpoint(
    ctx: *anyopaque,
    name: []const u8,
) client.ClientStoreError!?client.ClientCheckpointRecord {
    const self: *MemoryClientStore = @ptrCast(@alignCast(ctx));
    return self.getCheckpoint(name);
}

const event_store_vtable = client.ClientEventStoreVTable{
    .put_event = put_event,
    .get_event_by_id = get_event_by_id,
    .query_events = query_events,
};

const checkpoint_store_vtable = client.ClientCheckpointStoreVTable{
    .put_checkpoint = put_checkpoint,
    .get_checkpoint = get_checkpoint,
};

fn find_event_index(self: *const MemoryClientStore, event_id_hex: *const client.EventIdHex) ?u8 {
    std.debug.assert(self.event_count <= default_event_capacity);

    var index: u8 = 0;
    while (index < self.event_count) : (index += 1) {
        if (std.mem.eql(u8, &self.events[index].id_hex, event_id_hex)) return index;
    }
    return null;
}

fn collect_matching_indexes(
    self: *const MemoryClientStore,
    query: *const client.ClientQuery,
    indexes: []u8,
) u32 {
    std.debug.assert(indexes.len >= self.event_count);

    var count: u32 = 0;
    var index: u8 = 0;
    while (index < self.event_count) : (index += 1) {
        if (!self.events[index].matches(query)) continue;
        indexes[count] = index;
        count += 1;
    }
    return count;
}

fn sort_matching_indexes(self: *const MemoryClientStore, indexes: []u8) void {
    var outer: usize = 1;
    while (outer < indexes.len) : (outer += 1) {
        const current = indexes[outer];
        var inner = outer;
        while (inner > 0) {
            const left = indexes[inner - 1];
            if (!event_precedes(&self.events[current], &self.events[left])) break;
            indexes[inner] = left;
            inner -= 1;
        }
        indexes[inner] = current;
    }
}

fn event_precedes(
    candidate: *const client.ClientEventRecord,
    current: *const client.ClientEventRecord,
) bool {
    if (candidate.created_at > current.created_at) return true;
    if (candidate.created_at < current.created_at) return false;
    return std.mem.order(u8, &candidate.id_hex, &current.id_hex) == .lt;
}

fn result_limit(query: *const client.ClientQuery, storage_len: usize) usize {
    if (query.limit == 0) return storage_len;
    return @min(query.limit, storage_len);
}

fn find_checkpoint_index(self: *const MemoryClientStore, name: []const u8) ?u8 {
    std.debug.assert(self.checkpoint_count <= default_checkpoint_capacity);

    var index: u8 = 0;
    while (index < self.checkpoint_count) : (index += 1) {
        if (std.mem.eql(u8, self.checkpoints[index].nameSlice(), name)) return index;
    }
    return null;
}

test "memory client store replays newest matching events with a cursor" {
    var store = MemoryClientStore{};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const older_json =
        \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":10,"kind":1,"tags":[],"content":"older","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
    ;
    const newer_json =
        \\{"id":"2222222222222222222222222222222222222222222222222222222222222222","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":20,"kind":1,"tags":[],"content":"newer","sig":"44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"}
    ;
    try store.putEvent(&(try client.client_event_record_from_json(older_json, arena.allocator())));
    try store.putEvent(&(try client.client_event_record_from_json(newer_json, arena.allocator())));

    const authors = [_]client.EventPubkeyHex{
        try client.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    var page_storage: [1]client.ClientEventRecord = undefined;
    var page = client.EventQueryResultPage.init(page_storage[0..]);
    try store.queryEvents(&.{
        .authors = authors[0..],
        .limit = 1,
    }, &page);
    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expectEqualStrings(
        "2222222222222222222222222222222222222222222222222222222222222222",
        &page.slice()[0].id_hex,
    );
    try std.testing.expect(page.next_cursor != null);

    var next_page_storage: [1]client.ClientEventRecord = undefined;
    var next_page = client.EventQueryResultPage.init(next_page_storage[0..]);
    try store.queryEvents(&.{
        .authors = authors[0..],
        .limit = 1,
        .cursor = page.next_cursor,
    }, &next_page);
    try std.testing.expectEqual(@as(usize, 1), next_page.count);
    try std.testing.expectEqualStrings(
        "1111111111111111111111111111111111111111111111111111111111111111",
        &next_page.slice()[0].id_hex,
    );
}

test "memory client store remembers checkpoints by name" {
    var store = MemoryClientStore{};

    const first = try client.client_checkpoint_record_from_name("mailbox", .{ .offset = 4 });
    const second = try client.client_checkpoint_record_from_name("mailbox", .{ .offset = 8 });
    try store.putCheckpoint(&first);
    try store.putCheckpoint(&second);

    const checkpoint = try store.getCheckpoint("mailbox");
    try std.testing.expect(checkpoint != null);
    try std.testing.expectEqual(@as(u32, 8), checkpoint.?.cursor.offset);
}
