const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay response client validates transcript count ok notice and auth intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response_client = noztr_sdk.client.RelayResponseClient.init(.{});
    var transcript = noztr_sdk.client.RelaySubscriptionTranscriptStorage{};
    try response_client.beginSubscriptionTranscript(&transcript, "feed");

    const secret_key = [_]u8{0x11} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 7,
        .tags = &.{},
        .content = "hello relay response recipe",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .event = .{ .subscription_id = "feed", .event = event } },
    );
    const event_outcome = try response_client.acceptSubscriptionMessageJson(
        &transcript,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(event_outcome == .event);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    const eose_outcome = try response_client.acceptSubscriptionMessageJson(
        &transcript,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(eose_outcome == .eose);

    const count_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .count = .{ .subscription_id = "feed", .count = 42 } },
    );
    const count_outcome = try response_client.acceptCountMessageJson(
        "feed",
        count_json,
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u64, 42), count_outcome.count);

    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .ok = .{ .event_id = event.id, .accepted = true, .status = "" } },
    );
    const ok_outcome = try response_client.acceptPublishOkJson(
        &event.id,
        ok_json,
        arena.allocator(),
    );
    try std.testing.expect(ok_outcome.accepted);

    const notice_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .notice = .{ .message = "heads up" } },
    );
    const notice = try response_client.acceptNoticeJson(notice_json, arena.allocator());
    try std.testing.expectEqualStrings("heads up", notice.message);

    const auth_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .auth = .{ .challenge = "challenge-1" } },
    );
    const auth = try response_client.acceptAuthChallengeJson(auth_json, arena.allocator());
    try std.testing.expectEqualStrings("challenge-1", auth.challenge);
}
