const std = @import("std");
const common = @import("common.zig");
const noztr_sdk = @import("noztr_sdk");

test "recipe: store namespace persists events queries with a cursor and remembers checkpoints" {
    var memory_store = noztr_sdk.store.MemoryClientStore{};
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();

    const author_a = [_]u8{0x11} ** 32;
    const author_b = [_]u8{0x22} ** 32;

    var older_event = common.simpleEvent(1, author_a, 10, "older", &.{});
    var newer_event = common.simpleEvent(1, author_a, 20, "newer", &.{});
    var unrelated_event = common.simpleEvent(2, author_b, 15, "other", &.{});
    older_event.id = [_]u8{0x01} ** 32;
    newer_event.id = [_]u8{0x02} ** 32;
    unrelated_event.id = [_]u8{0x03} ** 32;

    var older_json_buffer: [1024]u8 = undefined;
    var newer_json_buffer: [1024]u8 = undefined;
    var unrelated_json_buffer: [1024]u8 = undefined;
    const older_json = try common.serializeEventJson(older_json_buffer[0..], &older_event);
    const newer_json = try common.serializeEventJson(newer_json_buffer[0..], &newer_event);
    const unrelated_json = try common.serializeEventJson(unrelated_json_buffer[0..], &unrelated_event);

    const older_record = try noztr_sdk.store.client_event_record_from_json(
        older_json,
        scratch_arena.allocator(),
    );
    const newer_record = try noztr_sdk.store.client_event_record_from_json(
        newer_json,
        scratch_arena.allocator(),
    );
    const unrelated_record = try noztr_sdk.store.client_event_record_from_json(
        unrelated_json,
        scratch_arena.allocator(),
    );

    try memory_store.putEvent(&older_record);
    try memory_store.putEvent(&newer_record);
    try memory_store.putEvent(&unrelated_record);

    const author_query = [_]noztr_sdk.store.EventPubkeyHex{
        try noztr_sdk.store.event_pubkey_hex_from_text(&newer_record.pubkey_hex),
    };
    const kind_query = [_]u32{1};
    var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
    try memory_store.queryEvents(&.{
        .authors = author_query[0..],
        .kinds = kind_query[0..],
        .limit = 1,
        .index_selection = .author_time,
    }, &page);

    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expectEqualStrings(&newer_record.id_hex, &page.slice()[0].id_hex);
    try std.testing.expect(page.next_cursor != null);

    const checkpoint = try noztr_sdk.store.client_checkpoint_record_from_name(
        "author-a-recent",
        page.next_cursor.?,
    );
    try memory_store.putCheckpoint(&checkpoint);

    const restored = try memory_store.getCheckpoint("author-a-recent");
    try std.testing.expect(restored != null);

    var next_page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var next_page = noztr_sdk.store.EventQueryResultPage.init(next_page_storage[0..]);
    try memory_store.queryEvents(&.{
        .authors = author_query[0..],
        .kinds = kind_query[0..],
        .limit = 1,
        .cursor = restored.?.cursor,
        .index_selection = .author_time,
    }, &next_page);

    try std.testing.expectEqual(@as(usize, 1), next_page.count);
    try std.testing.expectEqualStrings(&older_record.id_hex, &next_page.slice()[0].id_hex);
}
