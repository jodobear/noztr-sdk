const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: auth publish turn client authenticates then resumes one bounded publish turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.relay.auth_publish_turn.AuthPublishTurnClientStorage{};
    var client = noztr_sdk.client.relay.auth_publish_turn.AuthPublishTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = noztr_sdk.runtime.RelayPoolAuthStorage{};
    var publish_plan_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const auth_step = client.nextStep(&auth_plan_storage, &publish_plan_storage).?.authenticate;

    const secret_key = [_]u8{0x25} ** 32;
    var auth_event_storage = noztr_sdk.client.relay.auth_publish_turn.AuthPublishEventStorage{};
    var auth_event_json: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_event_storage,
        auth_event_json[0..],
        auth_message_json[0..],
        &auth_step,
        &secret_key,
        90,
    );
    const auth_result = try client.acceptPreparedAuthEvent(&prepared_auth, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const draft = noztr_sdk.client.local.operator.LocalEventDraft{
        .kind = 1,
        .created_at = 91,
        .content = "hello auth publish turn recipe",
    };
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const publish_request = try client.beginPublishTurn(
        event_json_output[0..],
        event_message_output[0..],
        &secret_key,
        &draft,
    );

    var reply_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .ok = .{ .event_id = publish_request.event.id, .accepted = true, .status = "" } },
    );
    const publish_result = try client.acceptPublishOkJson(
        &publish_request,
        ok_json,
        arena.allocator(),
    );
    try std.testing.expect(publish_result == .published);
    try std.testing.expect(publish_result.published.accepted);
}
