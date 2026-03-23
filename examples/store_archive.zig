const std = @import("std");
const common = @import("common.zig");
const noztr_sdk = @import("noztr_sdk");

test "recipe: event archive ingests event json replays a bounded query and restores one checkpoint" {
    var backing_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(backing_store.asClientStore());
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();

    const author = [_]u8{0x11} ** 32;

    var older_event = common.simpleEvent(1, author, 10, "older", &.{});
    var newer_event = common.simpleEvent(1, author, 20, "newer", &.{});
    older_event.id = [_]u8{0x01} ** 32;
    newer_event.id = [_]u8{0x02} ** 32;

    var older_json_buffer: [1024]u8 = undefined;
    var newer_json_buffer: [1024]u8 = undefined;
    const older_json = try common.serializeEventJson(older_json_buffer[0..], &older_event);
    const newer_json = try common.serializeEventJson(newer_json_buffer[0..], &newer_event);

    try archive.ingestEventJson(older_json, scratch_arena.allocator());
    try archive.ingestEventJson(newer_json, scratch_arena.allocator());

    const author_query = [_]noztr_sdk.store.EventPubkeyHex{
        try noztr_sdk.store.event_pubkey_hex_from_text(
            "1111111111111111111111111111111111111111111111111111111111111111",
        ),
    };
    var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
    try archive.query(&.{
        .authors = author_query[0..],
        .limit = 1,
        .index_selection = .author_time,
    }, &page);

    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expectEqualStrings(
        "0202020202020202020202020202020202020202020202020202020202020202",
        &page.slice()[0].id_hex,
    );
    try std.testing.expect(page.next_cursor != null);

    try archive.saveCheckpoint("author-recent", page.next_cursor.?);
    const restored = try archive.loadCheckpoint("author-recent");
    try std.testing.expect(restored != null);

    var next_page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var next_page = noztr_sdk.store.EventQueryResultPage.init(next_page_storage[0..]);
    try archive.query(&.{
        .authors = author_query[0..],
        .limit = 1,
        .cursor = restored.?.cursor,
        .index_selection = .author_time,
    }, &next_page);
    try std.testing.expectEqual(@as(usize, 1), next_page.count);
    try std.testing.expectEqualStrings(
        "0101010101010101010101010101010101010101010101010101010101010101",
        &next_page.slice()[0].id_hex,
    );
}
