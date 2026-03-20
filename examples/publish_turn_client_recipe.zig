const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: publish turn client closes one bounded publish turn with explicit ok validation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.PublishTurnClientStorage{};
    var client = noztr_sdk.client.PublishTurnClient.init(.{}, &storage);
    const ready = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(ready.relay_index);

    const secret_key = [_]u8{0x15} ** 32;
    const draft = noztr_sdk.client.LocalEventDraft{
        .kind = 1,
        .created_at = 73,
        .content = "hello publish turn recipe",
    };

    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(
        event_json_output[0..],
        event_message_output[0..],
        &secret_key,
        &draft,
    );

    var reply_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .ok = .{ .event_id = request.event.id, .accepted = true, .status = "" } },
    );
    const result = try client.acceptPublishOkJson(&request, ok_json, arena.allocator());

    try std.testing.expect(result.accepted);
    try std.testing.expectEqualStrings("wss://relay.one", result.request.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, result.request.event_message_json, "[\"EVENT\","));
}
