const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: social profile content client composes profile publish, note subscription, and long-form inspection explicitly" {
    var storage = noztr_sdk.client.social.profile_content.SocialProfileContentClientStorage{};
    var client = noztr_sdk.client.social.profile_content.SocialProfileContentClient.init(.{}, &storage);

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

    var long_form_built_tags: [8]noztr.nip23_long_form.BuiltTag = undefined;
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
}
