const std = @import("std");
const archive = @import("archive.zig");
const client = @import("client_traits.zig");
const relay_checkpoint = @import("relay_checkpoint.zig");
const relay_url = @import("../relay/url.zig");

pub const relay_local_scope_max_bytes: u8 = relay_checkpoint.checkpoint_scope_max_bytes;

pub const RelayLocalArchiveTargetError = error{
    InvalidCheckpointScope,
    CheckpointScopeTooLong,
    InvalidRelayUrl,
    RelayUrlTooLong,
};

pub const RelayLocalArchiveError = archive.EventArchiveError || RelayLocalArchiveTargetError;

pub const RelayLocalArchiveReplayPlan = struct {
    query: client.ClientQuery,
    restored_cursor: ?client.EventCursor = null,

    pub fn hasRestoredCursor(self: *const RelayLocalArchiveReplayPlan) bool {
        return self.restored_cursor != null;
    }
};

pub const RelayLocalArchiveTarget = struct {
    scope: [relay_local_scope_max_bytes]u8 = [_]u8{0} ** relay_local_scope_max_bytes,
    scope_len: u8 = 0,
    relay_url: [relay_url.relay_url_max_bytes]u8 = [_]u8{0} ** relay_url.relay_url_max_bytes,
    relay_url_len: u16 = 0,

    pub fn init(
        scope_text: []const u8,
        relay_url_text: []const u8,
    ) RelayLocalArchiveTargetError!RelayLocalArchiveTarget {
        if (scope_text.len == 0) return error.InvalidCheckpointScope;
        if (scope_text.len > relay_local_scope_max_bytes) return error.CheckpointScopeTooLong;
        if (relay_url_text.len > relay_url.relay_url_max_bytes) return error.RelayUrlTooLong;
        try relay_url.relayUrlValidate(relay_url_text);

        var target = RelayLocalArchiveTarget{};
        @memcpy(target.scope[0..scope_text.len], scope_text);
        target.scope_len = @intCast(scope_text.len);
        @memcpy(target.relay_url[0..relay_url_text.len], relay_url_text);
        target.relay_url_len = @intCast(relay_url_text.len);
        return target;
    }

    pub fn scopeText(self: *const RelayLocalArchiveTarget) []const u8 {
        std.debug.assert(self.scope_len <= relay_local_scope_max_bytes);
        return self.scope[0..self.scope_len];
    }

    pub fn relayUrl(self: *const RelayLocalArchiveTarget) []const u8 {
        std.debug.assert(self.relay_url_len <= relay_url.relay_url_max_bytes);
        return self.relay_url[0..self.relay_url_len];
    }
};

pub const RelayLocalArchive = struct {
    archive: archive.EventArchive,
    target: RelayLocalArchiveTarget,

    pub fn init(
        store: client.ClientStore,
        scope_text: []const u8,
        relay_url_text: []const u8,
    ) RelayLocalArchiveTargetError!RelayLocalArchive {
        return .{
            .archive = archive.EventArchive.init(store),
            .target = try RelayLocalArchiveTarget.init(scope_text, relay_url_text),
        };
    }

    pub fn initTarget(store: client.ClientStore, target: RelayLocalArchiveTarget) RelayLocalArchive {
        return .{
            .archive = archive.EventArchive.init(store),
            .target = target,
        };
    }

    pub fn ingestEventJson(
        self: RelayLocalArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayLocalArchiveError!void {
        return self.archive.ingestEventJson(event_json, scratch);
    }

    pub fn getEventById(
        self: RelayLocalArchive,
        event_id_hex: []const u8,
    ) RelayLocalArchiveError!?client.ClientEventRecord {
        return self.archive.getEventById(event_id_hex);
    }

    pub fn query(
        self: RelayLocalArchive,
        request: *const client.ClientQuery,
        page: *client.EventQueryResultPage,
    ) RelayLocalArchiveError!void {
        return self.archive.query(request, page);
    }

    pub fn saveCursor(
        self: RelayLocalArchive,
        cursor: client.EventCursor,
    ) RelayLocalArchiveError!void {
        var checkpoint_name: [client.checkpoint_name_max_bytes]u8 = undefined;
        const name = try self.checkpointName(checkpoint_name[0..]);
        return self.archive.saveCheckpoint(name, cursor);
    }

    pub fn loadCursor(self: RelayLocalArchive) RelayLocalArchiveError!?client.EventCursor {
        var checkpoint_name: [client.checkpoint_name_max_bytes]u8 = undefined;
        const name = try self.checkpointName(checkpoint_name[0..]);
        const checkpoint = try self.archive.loadCheckpoint(name);
        if (checkpoint) |record| return record.cursor;
        return null;
    }

    pub fn planReplayQuery(
        self: RelayLocalArchive,
        base_query: *const client.ClientQuery,
    ) RelayLocalArchiveError!RelayLocalArchiveReplayPlan {
        const restored_cursor = try self.loadCursor();
        var replay_query = base_query.*;
        replay_query.cursor = restored_cursor;
        replay_query.index_selection = .checkpoint_replay;
        return .{
            .query = replay_query,
            .restored_cursor = restored_cursor,
        };
    }

    pub fn saveNextCursor(
        self: RelayLocalArchive,
        next_cursor: ?client.EventCursor,
    ) RelayLocalArchiveError!bool {
        if (next_cursor) |cursor| {
            try self.saveCursor(cursor);
            return true;
        }
        return false;
    }

    pub fn saveCursorFromPage(
        self: RelayLocalArchive,
        page: *const client.EventQueryResultPage,
    ) RelayLocalArchiveError!bool {
        return self.saveNextCursor(page.next_cursor);
    }

    pub fn checkpointName(
        self: RelayLocalArchive,
        output: []u8,
    ) RelayLocalArchiveError![]const u8 {
        return relay_checkpoint.checkpoint_name_for_relay(
            self.target.scopeText(),
            self.target.relayUrl(),
            output,
        );
    }
};

test "relay local archive ingests queries and reloads one scoped cursor" {
    var backing_store = @import("client_memory.zig").MemoryClientStore{};
    const archive_view = try RelayLocalArchive.init(
        backing_store.asClientStore(),
        "relay-session",
        "wss://relay.one",
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const first_json =
        \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":10,"kind":1,"tags":[],"content":"first","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
    ;
    const second_json =
        \\{"id":"2222222222222222222222222222222222222222222222222222222222222222","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":20,"kind":1,"tags":[],"content":"second","sig":"44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"}
    ;

    try archive_view.ingestEventJson(first_json, arena.allocator());
    try archive_view.ingestEventJson(second_json, arena.allocator());

    const authors = [_]client.EventPubkeyHex{
        try client.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    var page_storage: [1]client.ClientEventRecord = undefined;
    var page = client.EventQueryResultPage.init(page_storage[0..]);
    try archive_view.query(&.{
        .authors = authors[0..],
        .limit = 1,
    }, &page);
    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expect(page.next_cursor != null);

    try archive_view.saveCursor(page.next_cursor.?);
    const restored = try archive_view.loadCursor();
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 1), restored.?.offset);
}

test "relay local archive target copies bounded scope and relay url" {
    const target = try RelayLocalArchiveTarget.init("server", "wss://relay.one/path");
    try std.testing.expectEqualStrings("server", target.scopeText());
    try std.testing.expectEqualStrings("wss://relay.one/path", target.relayUrl());
}

test "relay local archive replay planning restores one saved cursor and forces checkpoint replay" {
    var backing_store = @import("client_memory.zig").MemoryClientStore{};
    const archive_view = try RelayLocalArchive.init(
        backing_store.asClientStore(),
        "relay-session",
        "wss://relay.one",
    );
    try archive_view.saveCursor(.{ .offset = 7 });

    const plan = try archive_view.planReplayQuery(&.{ .limit = 4 });
    try std.testing.expect(plan.hasRestoredCursor());
    try std.testing.expectEqual(@as(?client.EventCursor, .{ .offset = 7 }), plan.restored_cursor);
    try std.testing.expectEqual(client.IndexSelection.checkpoint_replay, plan.query.index_selection);
    try std.testing.expectEqual(@as(?client.EventCursor, .{ .offset = 7 }), plan.query.cursor);
}

test "relay local archive save cursor helpers keep null next cursor explicit" {
    var backing_store = @import("client_memory.zig").MemoryClientStore{};
    const archive_view = try RelayLocalArchive.init(
        backing_store.asClientStore(),
        "relay-session",
        "wss://relay.one",
    );

    var empty_storage: [1]client.ClientEventRecord = undefined;
    var page = client.EventQueryResultPage.init(empty_storage[0..]);
    try std.testing.expect(!try archive_view.saveCursorFromPage(&page));
    try std.testing.expect((try archive_view.loadCursor()) == null);
}

test "relay local archive rejects invalid target inputs" {
    try std.testing.expectError(
        error.InvalidCheckpointScope,
        RelayLocalArchiveTarget.init("", "wss://relay.one"),
    );
    try std.testing.expectError(
        error.InvalidRelayUrl,
        RelayLocalArchiveTarget.init("server", "https://relay.one"),
    );
}
