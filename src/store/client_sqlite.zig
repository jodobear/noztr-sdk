const std = @import("std");
const client = @import("client_traits.zig");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const SqliteClientStoreInitError = std.mem.Allocator.Error || error{
    PathContainsNul,
    OpenFailed,
    SchemaInitFailed,
};

pub const SqliteClientStore = struct {
    db: *c.sqlite3,

    pub fn open(
        allocator: std.mem.Allocator,
        path: []const u8,
    ) SqliteClientStoreInitError!SqliteClientStore {
        const path_z = allocator.dupeZ(u8, path) catch return error.PathContainsNul;
        defer allocator.free(path_z);

        var db_opt: ?*c.sqlite3 = null;
        const open_flags = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE;
        if (c.sqlite3_open_v2(path_z.ptr, &db_opt, open_flags, null) != c.SQLITE_OK) {
            if (db_opt) |db| _ = c.sqlite3_close_v2(db);
            return error.OpenFailed;
        }
        const db = db_opt.?;
        errdefer _ = c.sqlite3_close_v2(db);

        if (c.sqlite3_exec(db, schema_sql.ptr, null, null, null) != c.SQLITE_OK) {
            return error.SchemaInitFailed;
        }

        return .{ .db = db };
    }

    pub fn deinit(self: *SqliteClientStore) void {
        std.debug.assert(@intFromPtr(self.db) != 0);
        _ = c.sqlite3_close_v2(self.db);
        self.* = undefined;
    }

    pub fn asClientStore(self: *SqliteClientStore) client.ClientStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .init(self.asEventStore(), self.asCheckpointStore());
    }

    pub fn asEventStore(self: *SqliteClientStore) client.ClientEventStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .{ .ctx = self, .vtable = &event_store_vtable };
    }

    pub fn asCheckpointStore(self: *SqliteClientStore) client.ClientCheckpointStore {
        std.debug.assert(@intFromPtr(self) != 0);
        return .{ .ctx = self, .vtable = &checkpoint_store_vtable };
    }

    pub fn putEvent(
        self: *SqliteClientStore,
        record: *const client.ClientEventRecord,
    ) client.ClientStoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        const stmt = try self.prepareStatement(sql_put_event);
        defer _ = c.sqlite3_finalize(stmt);

        try bind_text(stmt, 1, &record.id_hex);
        try bind_text(stmt, 2, &record.pubkey_hex);
        if (c.sqlite3_bind_int64(stmt, 3, record.kind) != c.SQLITE_OK) {
            return error.StoreUnavailable;
        }
        if (c.sqlite3_bind_int64(stmt, 4, @intCast(record.created_at)) != c.SQLITE_OK) {
            return error.StoreUnavailable;
        }
        try bind_text(stmt, 5, record.eventJson());

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.StoreUnavailable;
    }

    pub fn getEventById(
        self: *SqliteClientStore,
        event_id_hex: []const u8,
    ) client.ClientStoreError!?client.ClientEventRecord {
        std.debug.assert(@intFromPtr(self) != 0);

        const parsed_id = try client.event_id_hex_from_text(event_id_hex);
        const stmt = try self.prepareStatement(sql_get_event_by_id);
        defer _ = c.sqlite3_finalize(stmt);
        try bind_text(stmt, 1, &parsed_id);

        return switch (c.sqlite3_step(stmt)) {
            c.SQLITE_ROW => try event_record_from_row(stmt),
            c.SQLITE_DONE => null,
            else => error.StoreUnavailable,
        };
    }

    pub fn queryEvents(
        self: *SqliteClientStore,
        query: *const client.ClientQuery,
        page: *client.EventQueryResultPage,
    ) client.ClientStoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        const stmt = try self.prepareStatement(sql_query_events);
        defer _ = c.sqlite3_finalize(stmt);

        page.reset();
        const start_offset = if (query.cursor) |cursor| cursor.offset else 0;
        const write_limit = result_limit(query, page.items.len);

        var matched_count: u32 = 0;
        var written: usize = 0;
        var has_more = false;

        while (true) {
            switch (c.sqlite3_step(stmt)) {
                c.SQLITE_ROW => {
                    const record = try event_record_from_row(stmt);
                    if (!record.matches(query)) continue;

                    if (matched_count < start_offset) {
                        matched_count += 1;
                        continue;
                    }

                    if (written < write_limit) {
                        page.items[written] = record;
                        written += 1;
                        matched_count += 1;
                        continue;
                    }

                    has_more = true;
                    break;
                },
                c.SQLITE_DONE => break,
                else => return error.StoreUnavailable,
            }
        }

        page.count = written;
        page.truncated = has_more;
        if (has_more) {
            page.next_cursor = .{ .offset = start_offset + @as(u32, @intCast(written)) };
        }
    }

    pub fn putCheckpoint(
        self: *SqliteClientStore,
        record: *const client.ClientCheckpointRecord,
    ) client.ClientStoreError!void {
        std.debug.assert(@intFromPtr(self) != 0);

        const stmt = try self.prepareStatement(sql_put_checkpoint);
        defer _ = c.sqlite3_finalize(stmt);

        try bind_text(stmt, 1, record.nameSlice());
        if (c.sqlite3_bind_int64(stmt, 2, @intCast(record.cursor.offset)) != c.SQLITE_OK) {
            return error.StoreUnavailable;
        }

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.StoreUnavailable;
    }

    pub fn getCheckpoint(
        self: *SqliteClientStore,
        name: []const u8,
    ) client.ClientStoreError!?client.ClientCheckpointRecord {
        std.debug.assert(@intFromPtr(self) != 0);

        if (name.len == 0) return error.InvalidCheckpointName;
        if (name.len > client.checkpoint_name_max_bytes) return error.CheckpointNameTooLong;

        const stmt = try self.prepareStatement(sql_get_checkpoint);
        defer _ = c.sqlite3_finalize(stmt);
        try bind_text(stmt, 1, name);

        return switch (c.sqlite3_step(stmt)) {
            c.SQLITE_ROW => try checkpoint_record_from_row(stmt),
            c.SQLITE_DONE => null,
            else => error.StoreUnavailable,
        };
    }

    fn prepareStatement(
        self: *SqliteClientStore,
        sql: []const u8,
    ) client.ClientStoreError!*c.sqlite3_stmt {
        var stmt_opt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(
            self.db,
            sql.ptr,
            @intCast(sql.len),
            &stmt_opt,
            null,
        ) != c.SQLITE_OK) return error.StoreUnavailable;
        return stmt_opt orelse error.StoreUnavailable;
    }
};

fn put_event(
    ctx: *anyopaque,
    record: *const client.ClientEventRecord,
) client.ClientStoreError!void {
    const self: *SqliteClientStore = @ptrCast(@alignCast(ctx));
    return self.putEvent(record);
}

fn get_event_by_id(
    ctx: *anyopaque,
    event_id_hex: []const u8,
) client.ClientStoreError!?client.ClientEventRecord {
    const self: *SqliteClientStore = @ptrCast(@alignCast(ctx));
    return self.getEventById(event_id_hex);
}

fn query_events(
    ctx: *anyopaque,
    query: *const client.ClientQuery,
    page: *client.EventQueryResultPage,
) client.ClientStoreError!void {
    const self: *SqliteClientStore = @ptrCast(@alignCast(ctx));
    return self.queryEvents(query, page);
}

fn put_checkpoint(
    ctx: *anyopaque,
    record: *const client.ClientCheckpointRecord,
) client.ClientStoreError!void {
    const self: *SqliteClientStore = @ptrCast(@alignCast(ctx));
    return self.putCheckpoint(record);
}

fn get_checkpoint(
    ctx: *anyopaque,
    name: []const u8,
) client.ClientStoreError!?client.ClientCheckpointRecord {
    const self: *SqliteClientStore = @ptrCast(@alignCast(ctx));
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

const schema_sql =
    \\CREATE TABLE IF NOT EXISTS events (
    \\    id_hex TEXT PRIMARY KEY NOT NULL,
    \\    pubkey_hex TEXT NOT NULL,
    \\    kind INTEGER NOT NULL,
    \\    created_at INTEGER NOT NULL,
    \\    event_json TEXT NOT NULL
    \\);
    \\CREATE TABLE IF NOT EXISTS checkpoints (
    \\    name TEXT PRIMARY KEY NOT NULL,
    \\    cursor_offset INTEGER NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS events_created_id_idx
    \\    ON events(created_at DESC, id_hex ASC);
;

const sql_put_event =
    \\INSERT INTO events (id_hex, pubkey_hex, kind, created_at, event_json)
    \\VALUES (?1, ?2, ?3, ?4, ?5)
    \\ON CONFLICT(id_hex) DO UPDATE SET
    \\    pubkey_hex = excluded.pubkey_hex,
    \\    kind = excluded.kind,
    \\    created_at = excluded.created_at,
    \\    event_json = excluded.event_json;
;

const sql_get_event_by_id =
    \\SELECT id_hex, pubkey_hex, kind, created_at, event_json
    \\FROM events
    \\WHERE id_hex = ?1;
;

const sql_query_events =
    \\SELECT id_hex, pubkey_hex, kind, created_at, event_json
    \\FROM events
    \\ORDER BY created_at DESC, id_hex ASC;
;

const sql_put_checkpoint =
    \\INSERT INTO checkpoints (name, cursor_offset)
    \\VALUES (?1, ?2)
    \\ON CONFLICT(name) DO UPDATE SET
    \\    cursor_offset = excluded.cursor_offset;
;

const sql_get_checkpoint =
    \\SELECT name, cursor_offset
    \\FROM checkpoints
    \\WHERE name = ?1;
;

fn bind_text(
    stmt: *c.sqlite3_stmt,
    index: c_int,
    value: []const u8,
) client.ClientStoreError!void {
    const binding = if (value.len == 0) "" else value;
    if (c.sqlite3_bind_text(
        stmt,
        index,
        binding.ptr,
        @intCast(binding.len),
        null,
    ) != c.SQLITE_OK) return error.StoreUnavailable;
}

fn sqlite_text(stmt: *c.sqlite3_stmt, column: c_int) ?[]const u8 {
    const len_c = c.sqlite3_column_bytes(stmt, column);
    if (len_c < 0) return null;

    const text_ptr = c.sqlite3_column_text(stmt, column);
    const len: usize = @intCast(len_c);
    if (text_ptr == null) {
        if (len == 0) return "";
        return null;
    }
    const bytes: [*]const u8 = @ptrCast(text_ptr);
    return bytes[0..len];
}

fn event_record_from_row(stmt: *c.sqlite3_stmt) client.ClientStoreError!client.ClientEventRecord {
    const id_text = sqlite_text(stmt, 0) orelse return error.StoreCorrupt;
    const pubkey_text = sqlite_text(stmt, 1) orelse return error.StoreCorrupt;
    const kind_value = c.sqlite3_column_int64(stmt, 2);
    const created_at_value = c.sqlite3_column_int64(stmt, 3);
    const event_json = sqlite_text(stmt, 4) orelse return error.StoreCorrupt;

    const id_hex = client.event_id_hex_from_text(id_text) catch return error.StoreCorrupt;
    const pubkey_hex = client.event_pubkey_hex_from_text(pubkey_text) catch return error.StoreCorrupt;
    if (kind_value < 0 or kind_value > std.math.maxInt(u32)) return error.StoreCorrupt;
    if (created_at_value < 0) return error.StoreCorrupt;
    if (event_json.len > client.event_json_max_bytes) return error.StoreCorrupt;

    var record = client.ClientEventRecord{
        .id_hex = id_hex,
        .pubkey_hex = pubkey_hex,
        .kind = @intCast(kind_value),
        .created_at = @intCast(created_at_value),
    };
    @memcpy(record.event_json[0..event_json.len], event_json);
    record.event_json_len = @intCast(event_json.len);
    return record;
}

fn checkpoint_record_from_row(
    stmt: *c.sqlite3_stmt,
) client.ClientStoreError!client.ClientCheckpointRecord {
    const name = sqlite_text(stmt, 0) orelse return error.StoreCorrupt;
    const cursor_offset = c.sqlite3_column_int64(stmt, 1);
    if (cursor_offset < 0 or cursor_offset > std.math.maxInt(u32)) return error.StoreCorrupt;
    return client.client_checkpoint_record_from_name(
        name,
        .{ .offset = @intCast(cursor_offset) },
    ) catch error.StoreCorrupt;
}

fn result_limit(query: *const client.ClientQuery, storage_len: usize) usize {
    if (query.limit == 0) return storage_len;
    return @min(query.limit, storage_len);
}

fn testing_path(tmp_dir: *std.testing.TmpDir, file_name: []const u8, buffer: []u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, ".zig-cache/tmp/{s}/{s}", .{ &tmp_dir.sub_path, file_name });
}

test "sqlite client store persists events queries and checkpoints across reopen" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const db_path = try testing_path(&tmp_dir, "client_store.sqlite", path_buffer[0..]);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    {
        var store = try SqliteClientStore.open(std.testing.allocator, db_path);
        defer store.deinit();

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

        try store.putCheckpoint(&(try client.client_checkpoint_record_from_name(
            "recent",
            page.next_cursor.?,
        )));
    }

    {
        var store = try SqliteClientStore.open(std.testing.allocator, db_path);
        defer store.deinit();

        const restored = try store.getEventById(
            "1111111111111111111111111111111111111111111111111111111111111111",
        );
        try std.testing.expect(restored != null);
        try std.testing.expectEqual(@as(u64, 10), restored.?.created_at);

        const checkpoint = try store.getCheckpoint("recent");
        try std.testing.expect(checkpoint != null);
        try std.testing.expectEqual(@as(u32, 1), checkpoint.?.cursor.offset);
    }
}

test "sqlite client store surfaces corrupt persisted rows as typed store errors" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const db_path = try testing_path(&tmp_dir, "client_store_corrupt.sqlite", path_buffer[0..]);

    var store = try SqliteClientStore.open(std.testing.allocator, db_path);
    defer store.deinit();

    const corrupt_sql =
        \\INSERT INTO events (id_hex, pubkey_hex, kind, created_at, event_json)
        \\VALUES ('short', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 1, 10, '{}');
    ;
    try std.testing.expectEqual(@as(c_int, c.SQLITE_OK), c.sqlite3_exec(store.db, corrupt_sql.ptr, null, null, null));

    var page_storage: [1]client.ClientEventRecord = undefined;
    var page = client.EventQueryResultPage.init(page_storage[0..]);
    try std.testing.expectError(error.StoreCorrupt, store.queryEvents(&.{}, &page));
}
