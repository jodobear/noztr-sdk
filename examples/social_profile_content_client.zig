const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social profile content client composes social authoring, bounded subscription posture, and archive-backed reads explicitly" {
    var storage = noztr_sdk.client.social.profile_content.SocialProfileContentClientStorage{};
    var client = noztr_sdk.client.social.profile_content.SocialProfileContentClient.init(.{}, &storage);
    var backing_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.EventArchive.init(backing_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x17} ** 32;

    var profile_content: [256]u8 = undefined;
    var profile_storage = noztr_sdk.client.social.profile_content.SocialProfileDraftStorage.init(
        profile_content[0..],
    );
    var profile_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_profile = try client.prepareProfilePublish(
        profile_event_json[0..],
        &profile_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .extras = .{
                .display_name = "alice",
                .website = "https://example.com",
            },
        },
    );

    var publish_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_message: [1024]u8 = undefined;
    const targeted_publish = try client.composeTargetedPublish(
        publish_message[0..],
        &publish_step,
        &prepared_profile,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_publish.relay.relay_url);
    try client.storeSocialContentEventJson(archive, prepared_profile.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(prepared_profile.event.pubkey, .lower);
    const authors = [_]noztr_sdk.store.EventPubkeyHex{author_hex};
    var note_subscription_storage = noztr_sdk.client.social.profile_content.SocialSubscriptionPlanStorage{};
    const note_plan = try client.inspectNoteSubscription(
        &.{
            .subscription_id = "notes",
            .query = .{
                .authors = authors[0..],
                .limit = 20,
            },
        },
        &note_subscription_storage,
    );
    const note_step = note_plan.nextStep().?;
    var req_message: [1024]u8 = undefined;
    const targeted_req = try client.composeTargetedSubscriptionRequest(
        req_message[0..],
        &note_step,
    );
    try std.testing.expectEqualStrings("notes", targeted_req.subscription_id);

    var first_note_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const first_note = try client.prepareNotePublish(
        first_note_event_json[0..],
        &secret_key,
        &.{
            .created_at = 100,
            .content = "first",
        },
    );
    var second_note_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const second_note = try client.prepareNotePublish(
        second_note_event_json[0..],
        &secret_key,
        &.{
            .created_at = 101,
            .content = "second",
        },
    );
    try client.storeSocialContentEventJson(archive, first_note.event_json, arena.allocator());
    try client.storeSocialContentEventJson(archive, second_note.event_json, arena.allocator());

    var long_form_built_tags: [8]noztr.nip23_long_form.TagBuilder = undefined;
    var long_form_tags: [8]noztr.nip01_event.EventTag = undefined;
    var long_form_storage = noztr_sdk.client.social.profile_content.SocialLongFormDraftStorage.init(
        long_form_built_tags[0..],
        long_form_tags[0..],
    );
    var long_form_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_long_form = try client.prepareLongFormPublish(
        long_form_event_json[0..],
        &long_form_storage,
        &secret_key,
        &.{
            .created_at = 101,
            .content = "# hello world",
            .identifier = "hello-world",
            .title = "Hello World",
            .hashtags = &.{"zig"},
        },
    );
    var hashtags: [2][]const u8 = undefined;
    const long_form = try client.inspectLongFormEvent(&prepared_long_form.event, hashtags[0..]);
    try std.testing.expectEqualStrings("hello-world", long_form.identifier);
    try client.storeSocialContentEventJson(archive, prepared_long_form.event_json, arena.allocator());

    var profile_page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var profile_page = noztr_sdk.store.EventQueryResultPage.init(profile_page_storage[0..]);
    var reference_urls: [1][]const u8 = undefined;
    var profile_hashtags: [1][]const u8 = undefined;
    const latest_profile = try client.inspectLatestStoredProfile(
        archive,
        &.{ .author = author_hex },
        &profile_page,
        reference_urls[0..],
        profile_hashtags[0..],
        arena.allocator(),
    );
    try std.testing.expect(latest_profile.selection != null);

    var note_page_storage: [2]noztr_sdk.store.ClientEventRecord = undefined;
    var note_page = noztr_sdk.store.EventQueryResultPage.init(note_page_storage[0..]);
    var note_records: [2]noztr_sdk.client.social.profile_content.StoredSocialNoteRecord = undefined;
    const stored_notes = try client.inspectStoredNotePage(
        archive,
        &.{
            .query = .{
                .authors = authors[0..],
                .limit = 2,
            },
        },
        &note_page,
        note_records[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 2), stored_notes.notes.len);

    var long_form_page_storage: [1]noztr_sdk.store.ClientEventRecord = undefined;
    var long_form_page = noztr_sdk.store.EventQueryResultPage.init(long_form_page_storage[0..]);
    var stored_long_form_hashtags: [2][]const u8 = undefined;
    const latest_long_form = try client.inspectLatestStoredLongForm(
        archive,
        &.{
            .author = author_hex,
            .identifier = "hello-world",
        },
        &long_form_page,
        stored_long_form_hashtags[0..],
        arena.allocator(),
    );
    try std.testing.expect(latest_long_form.selection != null);
}
