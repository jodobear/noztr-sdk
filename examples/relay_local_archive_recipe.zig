const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay local archive restores one scoped cursor and derives one replay query" {
    var backing_store = noztr_sdk.store.MemoryClientStore{};
    const archive = try noztr_sdk.store.RelayLocalArchive.init(
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

    try archive.ingestEventJson(first_json, arena.allocator());
    try archive.ingestEventJson(second_json, arena.allocator());
    try archive.saveCursor(.{ .offset = 1 });

    const authors = [_]noztr_sdk.store.EventPubkeyHex{
        try noztr_sdk.store.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    const replay_plan = try archive.planReplayQuery(&.{
        .authors = authors[0..],
        .limit = 1,
    });
    try std.testing.expect(replay_plan.hasRestoredCursor());
    try std.testing.expectEqual(noztr_sdk.store.IndexSelection.checkpoint_replay, replay_plan.query.index_selection);
    try std.testing.expectEqual(@as(?noztr_sdk.store.EventCursor, .{ .offset = 1 }), replay_plan.query.cursor);

    var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
    try archive.query(&replay_plan.query, &page);
    try std.testing.expectEqual(@as(usize, 1), page.count);
    try std.testing.expectEqualStrings(first_json, page.slice()[0].eventJson());
    try std.testing.expect(!try archive.saveCursorFromPage(&page));
}
