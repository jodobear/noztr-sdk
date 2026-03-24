const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social comment reply client composes note replies and coordinate-target NIP-22 comments explicitly" {
    var storage = noztr_sdk.client.social.comment_reply.Storage{};
    var client = noztr_sdk.client.social.comment_reply.Client.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x81} ** 32;
    const root_id = [_]u8{0x11} ** 32;
    const root_author = [_]u8{0xaa} ** 32;

    var reply_storage = noztr_sdk.client.social.comment_reply.ReplyDraftStorage{};
    var reply_json: [1024]u8 = undefined;
    const reply = try client.prepareReplyPublish(
        reply_json[0..],
        &reply_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .content = "reply",
            .root = .{ .event_id = root_id, .author_pubkey = root_author },
        },
    );
    var mentions: [1]noztr_sdk.client.social.comment_reply.ReplyReference = undefined;
    _ = try client.inspectReplyEvent(&reply.event, mentions[0..]);

    var comment_storage = noztr_sdk.client.social.comment_reply.CommentDraftStorage{};
    var comment_json: [1024]u8 = undefined;
    const comment = try client.prepareCommentPublish(
        comment_json[0..],
        &comment_storage,
        &secret_key,
        &.{
            .created_at = 101,
            .content = "comment",
            .root = .{ .coordinate = .{
                .kind = 30023,
                .pubkey = [_]u8{0x01} ** 32,
                .identifier = "article",
                .relay_hint = "wss://relay.root",
            } },
            .parent = .{ .coordinate = .{
                .kind = 30023,
                .pubkey = [_]u8{0x02} ** 32,
                .identifier = "section-1",
                .relay_hint = "wss://relay.parent",
            } },
        },
    );
    const parsed_comment = try client.inspectCommentEvent(&comment.event);
    try std.testing.expect(parsed_comment.root == .coordinate);
    try std.testing.expect(parsed_comment.parent == .coordinate);

    var archive_storage = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(archive_storage.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try client.storeInteractionEventJson(archive, reply.event_json, arena.allocator());
    try client.storeInteractionEventJson(archive, comment.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(comment.event.pubkey, .lower);
    const authors = [_]noztr_sdk.store.EventPubkeyHex{author_hex};
    var page_records: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var query_page = noztr_sdk.store.EventQueryResultPage.init(page_records[0..]);
    var comments: [1]noztr_sdk.client.social.comment_reply.CommentRecord = undefined;
    const stored_comments = try client.inspectCommentPage(
        archive,
        &.{ .query = .{ .authors = authors[0..], .limit = 1 } },
        &query_page,
        comments[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 1), stored_comments.comments.len);
}
