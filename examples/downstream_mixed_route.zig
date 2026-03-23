const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Prove the mixed downstream route explicitly: keep deterministic arbitrary-kind event and tag
// shaping in `noztr`, then hand the signed kernel event into `noztr-sdk` publish/session
// composition without rebuilding a parallel relay/runtime layer locally.
test "recipe: downstream mixed route hands one kernel event into sdk publish and relay session composition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const secret_key = [_]u8{0x55} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "m", "welcome" } },
        .{ .items = &.{ "relay", "wss://relay.one" } },
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 443,
        .created_at = 123,
        .tags = tags[0..],
        .content = "{\"key_package\":\"opaque\"}",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var publish_storage = noztr_sdk.client.relay.publish.PublishClientStorage{};
    var publish_client = noztr_sdk.client.relay.publish.PublishClient.init(.{}, &publish_storage);
    const publish_relay = try publish_client.addRelay("wss://relay.one");
    try publish_client.markRelayConnected(publish_relay.relay_index);

    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try publish_client.prepareExistingSignedEvent(event_json_output[0..], &event);

    var publish_plan_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = publish_client.inspectPublish(&publish_plan_storage);
    const publish_step = publish_plan.nextStep().?;

    var publish_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_publish = try publish_client.composeTargetedPublish(
        publish_message_output[0..],
        &publish_step,
        &prepared,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_publish.relay.relay_url);
    try std.testing.expect(std.mem.indexOf(u8, targeted_publish.event_json, "\"kind\":443") != null);
    try std.testing.expect(std.mem.indexOf(u8, targeted_publish.event_json, "\"m\",\"welcome\"") != null);

    var session_storage = noztr_sdk.client.relay.session.RelaySessionClientStorage{};
    var session_client = noztr_sdk.client.relay.session.RelaySessionClient.init(.{}, &session_storage);
    const session_relay = try session_client.addRelay("wss://relay.one");
    try session_client.markRelayConnected(session_relay.relay_index);

    var runtime_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const runtime_plan = session_client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[443]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{
            .subscription_id = "marmot-feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var subscription_storage = noztr_sdk.runtime.RelayPoolSubscriptionStorage{};
    const subscription_plan = try session_client.inspectSubscriptions(
        specs[0..],
        &subscription_storage,
    );
    const subscription_step = subscription_plan.nextStep().?;

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_request = try session_client.composeTargetedSubscriptionRequest(
        request_output[0..],
        &subscription_step,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_request.relay.relay_url);
    try std.testing.expect(std.mem.indexOf(u8, targeted_request.request_json, "443") != null);
}
