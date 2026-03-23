const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social reaction list client composes one reaction route and one stored follow-set selection explicitly" {
    var storage = noztr_sdk.client.social.reaction_list.SocialReactionListClientStorage{};
    var client = noztr_sdk.client.social.reaction_list.SocialReactionListClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x27} ** 32;

    var reaction_storage = noztr_sdk.client.social.reaction_list.SocialReactionDraftStorage{};
    var reaction_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_reaction = try client.prepareReactionPublish(
        reaction_event_json[0..],
        &reaction_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .content = "+",
            .target_event_id = [_]u8{0x11} ** 32,
        },
    );
    const parsed_reaction = try client.inspectReactionEvent(&prepared_reaction.event);
    try std.testing.expectEqual(noztr.nip25_reactions.ReactionType.like, parsed_reaction.reaction_type);

    var publish_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    _ = try client.composeTargetedPublish(publish_message[0..], &publish_step, &prepared_reaction);

    const followed_pubkey = [_]u8{0x55} ** 32;
    const followed_pubkey_hex = std.fmt.bytesToHex(followed_pubkey, .lower);
    const follow_tag_items = [_][]const u8{ "p", followed_pubkey_hex[0..] };
    const follow_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = follow_tag_items[0..] },
    };
    var list_tags: [2]noztr.nip01_event.EventTag = undefined;
    var list_storage = noztr_sdk.client.social.reaction_list.SocialListDraftStorage.init(list_tags[0..]);
    var list_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_list = try client.prepareListPublish(
        list_event_json[0..],
        &list_storage,
        &secret_key,
        &.{
            .kind = .follow_set,
            .created_at = 101,
            .identifier = "friends",
            .tags = follow_tags[0..],
        },
    );

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(memory_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try client.storeListEventJson(archive, prepared_list.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(prepared_list.event.pubkey, .lower);
    var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
    var items: [2]noztr.nip51_lists.ListItem = undefined;
    const inspection = try client.inspectLatestStoredList(
        archive,
        &.{
            .author = author_hex,
            .kind = .follow_set,
            .identifier = "friends",
        },
        &page,
        items[0..],
        arena.allocator(),
    );
    try std.testing.expect(inspection.selection != null);
    try std.testing.expectEqualStrings("friends", inspection.selection.?.info.metadata.identifier.?);
}
