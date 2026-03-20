const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: publish job client authenticates when needed then returns one command-ready publish request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.PublishJobClientStorage{};
    var client = noztr_sdk.client.PublishJobClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const secret_key = [_]u8{0x26} ** 32;
    const draft = noztr_sdk.client.LocalEventDraft{
        .kind = 1,
        .created_at = 91,
        .content = "hello publish job recipe",
    };

    var auth_storage = noztr_sdk.client.PublishJobAuthEventStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        event_json_output[0..],
        message_output[0..],
        &secret_key,
        &draft,
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        event_json_output[0..],
        message_output[0..],
        &secret_key,
        &draft,
        90,
    );
    try std.testing.expect(second_ready == .publish);

    var reply_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .ok = .{ .event_id = second_ready.publish.event.id, .accepted = true, .status = "" } },
    );
    const publish_result = try client.acceptPublishOkJson(
        &second_ready.publish,
        ok_json,
        arena.allocator(),
    );
    try std.testing.expect(publish_result == .published);
    try std.testing.expect(publish_result.published.accepted);
}
