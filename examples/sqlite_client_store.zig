const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Open one SQLite-backed client store, archive bounded event/checkpoint state through the shared
// store seam, persist one relay-local checkpoint, reopen the same store, and restore that state
// explicitly without leaking SQLite details into higher workflow routes.
test "recipe: sqlite client store persists archive and relay checkpoints across reopen" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const db_path = try std.fmt.bufPrint(
        path_buffer[0..],
        ".zig-cache/tmp/{s}/recipe.sqlite",
        .{&tmp_dir.sub_path},
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    {
        var sqlite_store = try noztr_sdk.store.SqliteClientStore.open(std.testing.allocator, db_path);
        defer sqlite_store.deinit();

        const archive = noztr_sdk.store.EventArchive.init(sqlite_store.asClientStore());
        const relay_checkpoints = noztr_sdk.store.RelayCheckpointArchive.init(sqlite_store.asClientStore());

        const first_json =
            \\{"id":"1111111111111111111111111111111111111111111111111111111111111111","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":10,"kind":1,"tags":[],"content":"first","sig":"33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333"}
        ;
        const second_json =
            \\{"id":"2222222222222222222222222222222222222222222222222222222222222222","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":20,"kind":1,"tags":[],"content":"second","sig":"44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"}
        ;
        try archive.ingestEventJson(first_json, arena.allocator());
        try archive.ingestEventJson(second_json, arena.allocator());

        const authors = [_]noztr_sdk.store.EventPubkeyHex{
            try noztr_sdk.store.event_pubkey_hex_from_text(
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            ),
        };
        var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
        var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
        try archive.query(&.{
            .authors = authors[0..],
            .limit = 1,
        }, &page);
        try std.testing.expectEqual(@as(usize, 1), page.count);
        try std.testing.expect(page.next_cursor != null);

        try archive.saveCheckpoint("recent", page.next_cursor.?);
        try relay_checkpoints.saveRelayCheckpoint("workspace", "wss://relay.one", .{ .offset = 7 });
    }

    {
        var sqlite_store = try noztr_sdk.store.SqliteClientStore.open(std.testing.allocator, db_path);
        defer sqlite_store.deinit();

        const archive = noztr_sdk.store.EventArchive.init(sqlite_store.asClientStore());
        const relay_checkpoints = noztr_sdk.store.RelayCheckpointArchive.init(sqlite_store.asClientStore());

        var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
        var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
        try archive.query(&.{
            .limit = 1,
        }, &page);
        try std.testing.expectEqual(@as(usize, 1), page.count);
        try std.testing.expectEqualStrings(
            "2222222222222222222222222222222222222222222222222222222222222222",
            &page.slice()[0].id_hex,
        );

        const checkpoint = try archive.loadCheckpoint("recent");
        try std.testing.expect(checkpoint != null);
        try std.testing.expectEqual(@as(u32, 1), checkpoint.?.cursor.offset);

        const relay_checkpoint = try relay_checkpoints.loadRelayCheckpoint("workspace", "wss://relay.one");
        try std.testing.expect(relay_checkpoint != null);
        try std.testing.expectEqual(@as(u32, 7), relay_checkpoint.?.cursor.offset);
    }
}
