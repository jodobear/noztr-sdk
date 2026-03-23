const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay exchange client composes publish count and subscription exchanges explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.relay.exchange.RelayExchangeClientStorage{};
    var client = noztr_sdk.client.relay.exchange.RelayExchangeClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const secret_key = [_]u8{0x11} ** 32;
    const publish_draft = noztr_sdk.client.local.operator.LocalEventDraft{
        .kind = 1,
        .created_at = 7,
        .content = "hello relay exchange",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const publish_request = try client.beginPublish(
        event_json_output[0..],
        event_message_output[0..],
        &secret_key,
        &publish_draft,
    );

    var relay_json_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const publish_ok_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_json_output[0..],
        &.{ .ok = .{ .event_id = publish_request.event.id, .accepted = true, .status = "" } },
    );
    const publish_outcome = try client.acceptPublishOkJson(
        &publish_request,
        publish_ok_json,
        arena.allocator(),
    );
    try std.testing.expect(publish_outcome.accepted);

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const count_specs = [_]noztr_sdk.runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const count_request = try client.beginCount(request_output[0..], count_specs[0..]);
    const count_reply_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_json_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 42 } },
    );
    const count_outcome = try client.acceptCountMessageJson(
        &count_request,
        count_reply_json,
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u64, 42), count_outcome.count);

    const subscription_specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };
    var transcript = noztr_sdk.client.relay.response.RelaySubscriptionTranscriptStorage{};
    const subscription_request = try client.beginSubscription(
        &transcript,
        request_output[0..],
        subscription_specs[0..],
    );
    const event_reply_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_json_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = publish_request.event } },
    );
    const subscription_outcome = try client.acceptSubscriptionMessageJson(
        &subscription_request,
        &transcript,
        event_reply_json,
        arena.allocator(),
    );
    try std.testing.expect(subscription_outcome.message == .event);

    const close_request = try client.composeClose(request_output[0..], &subscription_request);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", close_request.request_json);
}
