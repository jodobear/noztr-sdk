const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social highlight client composes one address-source highlight route with multiple attributions and references plus one archive-backed stored page explicitly" {
    var storage = noztr_sdk.client.social.highlight.Storage{};
    var client = noztr_sdk.client.social.highlight.Client.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x82} ** 32;
    const source_pubkey = [_]u8{0x84} ** 32;
    const author = [_]u8{0x85} ** 32;
    const editor = [_]u8{0x86} ** 32;
    var builders: [7]noztr.nip84_highlights.TagBuilder = undefined;
    var tags: [7]noztr.nip01_event.EventTag = undefined;
    var pubkey_hex: [2]noztr_sdk.store.EventPubkeyHex = undefined;
    var draft_storage = noztr_sdk.client.social.highlight.HighlightDraftStorage.init(
        builders[0..],
        tags[0..],
        pubkey_hex[0..],
    );
    var event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareHighlightPublish(
        event_json[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .content = "quoted",
            .source = .{ .address = .{
                .kind = @intFromEnum(noztr.nip23_long_form.LongFormKind.article),
                .pubkey = source_pubkey,
                .identifier = "essay-1",
                .relay_hint = "wss://relay.article",
            } },
            .attributions = &.{
                .{ .pubkey = author, .relay_hint = "wss://relay.author", .role = "author" },
                .{ .pubkey = editor, .relay_hint = "wss://relay.editor", .role = "editor" },
            },
            .references = &.{
                .{ .url = "https://example.com/essay-1", .marker = "mention" },
                .{ .url = "https://example.com/essay-1/notes", .marker = "citation" },
            },
            .context = "chapter 1",
            .comment = "keep this passage handy",
        },
    );

    var attributions: [2]noztr.nip84_highlights.HighlightAttribution = undefined;
    var refs: [2]noztr.nip84_highlights.UrlRef = undefined;
    const highlight = try client.inspectHighlightEvent(&prepared.event, attributions[0..], refs[0..]);
    try std.testing.expect(highlight.source != null);
    try std.testing.expect(highlight.source.? == .address);
    try std.testing.expectEqualStrings("essay-1", highlight.source.?.address.identifier);
    try std.testing.expectEqual(@as(u16, 2), highlight.attribution_count);
    try std.testing.expectEqual(@as(u16, 2), highlight.url_reference_count);
    try std.testing.expectEqualStrings("author", attributions[0].role.?);
    try std.testing.expectEqualStrings("editor", attributions[1].role.?);
    try std.testing.expectEqualStrings("mention", refs[0].marker.?);
    try std.testing.expectEqualStrings("citation", refs[1].marker.?);

    var archive_storage = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(archive_storage.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try client.storeHighlightEventJson(archive, prepared.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(prepared.event.pubkey, .lower);
    const authors = [_]noztr_sdk.store.EventPubkeyHex{author_hex};
    var page_records: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var query_page = noztr_sdk.store.EventQueryResultPage.init(page_records[0..]);
    var highlights: [1]noztr_sdk.client.social.highlight.HighlightRecord = undefined;
    const stored_highlights = try client.inspectHighlightPage(
        archive,
        &.{ .query = .{ .authors = authors[0..], .limit = 1 } },
        &query_page,
        highlights[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 1), stored_highlights.highlights.len);

    var stored_attributions: [2]noztr.nip84_highlights.HighlightAttribution = undefined;
    var stored_refs: [2]noztr.nip84_highlights.UrlRef = undefined;
    const stored_highlight = try client.inspectHighlightEvent(
        &stored_highlights.highlights[0].event,
        stored_attributions[0..],
        stored_refs[0..],
    );
    try std.testing.expectEqual(@as(u16, 2), stored_highlight.attribution_count);
    try std.testing.expectEqual(@as(u16, 2), stored_highlight.url_reference_count);
    try std.testing.expectEqualStrings("mention", stored_refs[0].marker.?);
    try std.testing.expectEqualStrings("citation", stored_refs[1].marker.?);
}
