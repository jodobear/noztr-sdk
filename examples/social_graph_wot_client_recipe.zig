const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social graph wot client composes one contact route and one explicit starter-only WOT inspection over verified latest contact lists" {
    var storage = noztr_sdk.client.social.graph_wot.SocialGraphWotClientStorage{};
    var client = noztr_sdk.client.social.graph_wot.SocialGraphWotClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const root_secret_key = [_]u8{0x61} ** 32;
    const supporter_secret_key = [_]u8{0x71} ** 32;
    const candidate_pubkey = [_]u8{0x88} ** 32;
    const candidate_hex = std.fmt.bytesToHex(candidate_pubkey, .lower);

    var supporter_tags: [1]noztr.nip01_event.EventTag = undefined;
    var supporter_tag_items: [1]noztr_sdk.client.social.graph_wot.SocialContactTagStorage = undefined;
    var supporter_pubkeys: [1]noztr_sdk.store.EventPubkeyHex = undefined;
    var supporter_draft_storage = noztr_sdk.client.social.graph_wot.SocialContactDraftStorage.init(
        supporter_tags[0..],
        supporter_tag_items[0..],
        supporter_pubkeys[0..],
    );
    var supporter_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const supporter_prepared = try client.prepareContactListPublish(
        supporter_event_json[0..],
        &supporter_draft_storage,
        &supporter_secret_key,
        &.{
            .created_at = 10,
            .contacts = &.{.{ .pubkey = candidate_pubkey }},
        },
    );

    var root_tags: [2]noztr.nip01_event.EventTag = undefined;
    var root_tag_items: [2]noztr_sdk.client.social.graph_wot.SocialContactTagStorage = undefined;
    var root_pubkeys: [2]noztr_sdk.store.EventPubkeyHex = undefined;
    var root_draft_storage = noztr_sdk.client.social.graph_wot.SocialContactDraftStorage.init(
        root_tags[0..],
        root_tag_items[0..],
        root_pubkeys[0..],
    );
    var root_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const root_followed_pubkey = supporter_prepared.event.pubkey;
    const root_prepared = try client.prepareContactListPublish(
        root_event_json[0..],
        &root_draft_storage,
        &root_secret_key,
        &.{
            .created_at = 11,
            .contacts = &.{
                .{ .pubkey = candidate_pubkey },
                .{ .pubkey = root_followed_pubkey },
            },
        },
    );

    var inspect_contacts: [2]noztr.nip02_contacts.ContactEntry = undefined;
    const contact_inspection = try client.inspectContactEvent(&root_prepared.event, inspect_contacts[0..]);
    try std.testing.expectEqual(@as(u16, 2), contact_inspection.contact_count);

    var publish_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    _ = try client.composeTargetedPublish(publish_message[0..], &publish_step, &root_prepared);

    var subscription_storage = noztr_sdk.client.social.graph_wot.SocialSubscriptionPlanStorage{};
    const root_author_hex = std.fmt.bytesToHex(root_prepared.event.pubkey, .lower);
    const subscription_plan = try client.inspectContactSubscription(
        &.{
            .subscription_id = "contacts",
            .query = .{
                .authors = &.{root_author_hex},
                .limit = 1,
            },
        },
        &subscription_storage,
    );
    const subscription_step = subscription_plan.nextStep().?;
    var subscription_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    _ = try client.composeTargetedSubscriptionRequest(subscription_message[0..], &subscription_step);

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(memory_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // This helper verifies contact-list events before archive ingest. The starter-WoT route stays
    // a bounded heuristic over those verified latest contact lists instead of claiming a broader
    // trust engine.
    try client.storeContactEventJson(archive, supporter_prepared.event_json, arena.allocator());
    try client.storeContactEventJson(archive, root_prepared.event_json, arena.allocator());

    var root_page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var peer_page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var root_page = noztr_sdk.store.EventQueryResultPage.init(root_page_storage[0..]);
    var peer_page = noztr_sdk.store.EventQueryResultPage.init(peer_page_storage[0..]);
    var root_contacts_out: [2]noztr.nip02_contacts.ContactEntry = undefined;
    var peer_contacts_out: [1]noztr.nip02_contacts.ContactEntry = undefined;
    var supporters_out: [1]noztr_sdk.client.social.graph_wot.SocialStarterWotSupport = undefined;
    const wot = try client.inspectStarterWot(
        archive,
        &.{
            .root_author = root_author_hex,
            .candidate = candidate_hex,
        },
        &root_page,
        &peer_page,
        root_contacts_out[0..],
        peer_contacts_out[0..],
        supporters_out[0..],
        arena.allocator(),
    );
    try std.testing.expect(wot.direct_follow);
    try std.testing.expectEqual(@as(usize, 1), wot.support_count);
}
