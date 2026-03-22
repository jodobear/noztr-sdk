const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Compose one explicit relay session above the shared relay runtime, relay auth, outbound request
// shaping, receive-side transcript validation, and bounded member/checkpoint export-restore
// without inventing hidden transport ownership.
test "recipe: relay session client composes explicit relay session foundation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.RelaySessionClientStorage{};
    var client = noztr_sdk.client.RelaySessionClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    const gated = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(ready.relay_index);
    try client.markRelayConnected(gated.relay_index);
    try client.noteRelayAuthChallenge(gated.relay_index, "challenge-1");

    var runtime_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);

    var auth_storage = noztr_sdk.runtime.RelayPoolAuthStorage{};
    const auth_plan = client.inspectAuth(&auth_storage);
    try std.testing.expectEqual(@as(u8, 1), auth_plan.authenticate_count);

    const secret_key = [_]u8{0x11} ** 32;
    var auth_event_storage = noztr_sdk.client.RelayAuthEventStorage{};
    var auth_event_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const auth_step = auth_plan.nextStep().?;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_output[0..],
        auth_message_output[0..],
        &auth_step,
        &secret_key,
        42,
    );
    _ = try client.acceptPreparedAuthEvent(&prepared_auth, 42, 120);
    try std.testing.expect(std.mem.startsWith(u8, prepared_auth.auth_message_json, "[\"AUTH\","));

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const subscription_specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{
            .subscription_id = "feed",
            .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..],
        },
    };
    var subscription_storage = noztr_sdk.runtime.RelayPoolSubscriptionStorage{};
    const subscription_plan = try client.inspectSubscriptions(
        subscription_specs[0..],
        &subscription_storage,
    );
    const subscription_step = subscription_plan.nextStep().?;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_request = try client.composeTargetedSubscriptionRequest(
        request_output[0..],
        &subscription_step,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_request.relay.relay_url);

    var transcript = noztr_sdk.client.RelaySubscriptionTranscriptStorage{};
    try client.beginSubscriptionTranscript(&transcript, targeted_request.subscription_id);

    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 42,
        .tags = &.{},
        .content = "hello relay session",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_message_output[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    const intake = try client.acceptSubscriptionMessageJson(
        &transcript,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(intake == .event);

    const close_request = try client.composeCloseRequest(
        request_output[0..],
        &targeted_request.relay,
        targeted_request.subscription_id,
    );
    try std.testing.expectEqualStrings("[\"CLOSE\",\"feed\"]", close_request.request_json);

    var member_storage = noztr_sdk.runtime.RelayPoolMemberStorage{};
    const members = try client.exportMembers(&member_storage);
    try std.testing.expectEqual(@as(u8, 2), members.relay_count);

    const cursors = [_]noztr_sdk.store.EventCursor{
        .{ .offset = 7 },
        .{ .offset = 9 },
    };
    var checkpoint_storage = noztr_sdk.runtime.RelayPoolCheckpointStorage{};
    const checkpoints = try client.exportCheckpoints(cursors[0..], &checkpoint_storage);
    try std.testing.expectEqual(@as(u8, 2), checkpoints.relay_count);

    var restored_members_storage = noztr_sdk.client.RelaySessionClientStorage{};
    var restored_members = noztr_sdk.client.RelaySessionClient.init(.{}, &restored_members_storage);
    try restored_members.restoreMembers(&members);
    try std.testing.expectEqual(@as(u8, 2), restored_members.relayCount());

    var restored_checkpoint_storage = noztr_sdk.client.RelaySessionClientStorage{};
    var restored_checkpoints = noztr_sdk.client.RelaySessionClient.init(
        .{},
        &restored_checkpoint_storage,
    );
    try restored_checkpoints.restoreCheckpoints(&checkpoints);
    try std.testing.expectEqual(@as(u8, 2), restored_checkpoints.relayCount());
}
