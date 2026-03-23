const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: dm capability client composes mailbox relay-list support and mixed reply posture" {
    var storage = noztr_sdk.client.dm.capability.DmCapabilityClientStorage{};
    var client = noztr_sdk.client.dm.capability.DmCapabilityClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x44} ** 32;
    var tag_storage: [2]noztr.nip01_event.EventTag = undefined;
    var built_tag_storage: [2]noztr.nip17_private_messages.TagBuilder = undefined;
    var draft_storage = noztr_sdk.client.dm.capability.MailboxRelayListDraftStorage.init(
        tag_storage[0..],
        built_tag_storage[0..],
    );
    var event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareMailboxRelayListPublish(
        event_json[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 50,
            .relays = &.{ "wss://dm.one", "wss://dm.two" },
        },
    );

    var publish_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    _ = try client.composeTargetedPublish(publish_message[0..], &publish_step, &prepared);

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(memory_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try client.storeMailboxRelayListEventJson(archive, prepared.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(prepared.event.pubkey, .lower);
    var page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var page = noztr_sdk.store.EventQueryResultPage.init(page_storage[0..]);
    var relay_urls: [4][]const u8 = undefined;
    const stored = try client.inspectLatestStoredMailboxRelayList(
        archive,
        &.{ .author = author_hex, .limit = 1 },
        &page,
        relay_urls[0..],
        arena.allocator(),
    );
    try std.testing.expect(stored.selection != null);
    try std.testing.expectEqualStrings("wss://dm.one", stored.selection.?.relays[0]);
    try std.testing.expectEqualStrings("wss://dm.two", stored.selection.?.relays[1]);

    const inbound_protocol = try client.inspectDmProtocolKind(noztr.nip04.dm_kind);
    const reply = try client.selectReplyProtocol(&.{
        .sender_protocol = inbound_protocol,
        .policy = .prefer_mailbox,
        .recipient_mailbox_available = true,
    });
    try std.testing.expectEqual(.mailbox, reply.protocol);
}
