const std = @import("std");
const client = @import("client_traits.zig");

pub const EventArchiveError = client.ClientStoreError || error{
    MissingEventStore,
    MissingCheckpointStore,
};

pub const EventArchive = struct {
    store: client.ClientStore,

    pub fn init(store: client.ClientStore) EventArchive {
        return .{ .store = store };
    }

    pub fn ingestEventJson(
        self: EventArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) EventArchiveError!void {
        const event_store = try self.requireEventStore();
        const record = try client.client_event_record_from_json(event_json, scratch);
        return event_store.putEvent(&record);
    }

    pub fn getEventById(
        self: EventArchive,
        event_id_hex: []const u8,
    ) EventArchiveError!?client.ClientEventRecord {
        const event_store = try self.requireEventStore();
        return event_store.getEventById(event_id_hex);
    }

    pub fn query(
        self: EventArchive,
        request: *const client.ClientQuery,
        page: *client.EventQueryResultPage,
    ) EventArchiveError!void {
        const event_store = try self.requireEventStore();
        return event_store.queryEvents(request, page);
    }

    pub fn saveCheckpoint(
        self: EventArchive,
        name: []const u8,
        cursor: client.EventCursor,
    ) EventArchiveError!void {
        const checkpoint_store = try self.requireCheckpointStore();
        const record = try client.client_checkpoint_record_from_name(name, cursor);
        return checkpoint_store.putCheckpoint(&record);
    }

    pub fn loadCheckpoint(
        self: EventArchive,
        name: []const u8,
    ) EventArchiveError!?client.ClientCheckpointRecord {
        const checkpoint_store = try self.requireCheckpointStore();
        return checkpoint_store.getCheckpoint(name);
    }

    fn requireEventStore(self: EventArchive) EventArchiveError!client.ClientEventStore {
        if (self.store.event_store) |event_store| return event_store;
        return error.MissingEventStore;
    }

    fn requireCheckpointStore(self: EventArchive) EventArchiveError!client.ClientCheckpointStore {
        if (self.store.checkpoint_store) |checkpoint_store| return checkpoint_store;
        return error.MissingCheckpointStore;
    }
};

test "event archive ingests queries and restores checkpoints over the shared store seam" {
    var backing_store = @import("client_memory.zig").MemoryClientStore{};
    const archive = EventArchive.init(backing_store.asClientStore());

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const first_json =
        \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":10,"kind":1,"tags":[],"content":"first","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
    ;
    const second_json =
        \\{"id":"2222222222222222222222222222222222222222222222222222222222222222","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":20,"kind":1,"tags":[],"content":"second","sig":"44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"}
    ;

    try archive.ingestEventJson(first_json, arena.allocator());
    try archive.ingestEventJson(second_json, arena.allocator());

    const authors = [_]client.EventPubkeyHex{
        try client.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    var page_storage: [1]client.ClientEventRecord = undefined;
    var page = client.EventQueryResultPage.init(page_storage[0..]);
    try archive.query(&.{
        .authors = authors[0..],
        .limit = 1,
    }, &page);
    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expect(page.next_cursor != null);

    try archive.saveCheckpoint("recent", page.next_cursor.?);
    const checkpoint = try archive.loadCheckpoint("recent");
    try std.testing.expect(checkpoint != null);
    try std.testing.expectEqual(@as(u32, 1), checkpoint.?.cursor.offset);
}
