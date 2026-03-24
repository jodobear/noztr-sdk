const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social comment reply client composes note replies and NIP-22 comments explicitly" {
    var storage = noztr_sdk.client.social.comment_reply.SocialCommentReplyClientStorage{};
    var client = noztr_sdk.client.social.comment_reply.SocialCommentReplyClient.init(.{}, &storage);

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
            .root = .{ .external = .{
                .value = "https://example.com/root",
                .external_kind = "web",
                .author_pubkey = [_]u8{0x01} ** 32,
            } },
            .parent = .{ .external = .{
                .value = "https://example.com/parent",
                .external_kind = "web",
                .author_pubkey = [_]u8{0x02} ** 32,
            } },
        },
    );
    _ = try client.inspectCommentEvent(&comment.event);
}
