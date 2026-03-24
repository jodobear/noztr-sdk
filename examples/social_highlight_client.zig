const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social highlight client composes one highlight route and one archive-backed stored page explicitly" {
    var storage = noztr_sdk.client.social.highlight.SocialHighlightClientStorage{};
    var client = noztr_sdk.client.social.highlight.SocialHighlightClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x82} ** 32;
    const source_id = [_]u8{0x84} ** 32;
    const author = [_]u8{0x85} ** 32;
    var builders: [4]noztr.nip84_highlights.TagBuilder = undefined;
    var tags: [4]noztr.nip01_event.EventTag = undefined;
    var pubkey_hex: [1]noztr_sdk.store.EventPubkeyHex = undefined;
    var draft_storage = noztr_sdk.client.social.highlight.HighlightDraftStorage.init(
        builders[0..],
        tags[0..],
        pubkey_hex[0..],
    );
    var event_json: [1024]u8 = undefined;
    const prepared = try client.prepareHighlightPublish(
        event_json[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .content = "quoted",
            .source = .{ .event = .{ .event_id = source_id } },
            .attributions = &.{.{ .pubkey = author }},
            .context = "chapter 1",
        },
    );

    var attributions: [1]noztr.nip84_highlights.HighlightAttribution = undefined;
    var refs: [1]noztr.nip84_highlights.UrlRef = undefined;
    _ = try client.inspectHighlightEvent(&prepared.event, attributions[0..], refs[0..]);
}
