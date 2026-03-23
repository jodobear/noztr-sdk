const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: auth count turn client authenticates then resumes one bounded count turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.relay.auth_count_turn.AuthCountTurnClientStorage{};
    var client = noztr_sdk.client.relay.auth_count_turn.AuthCountTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelayCountSpec{
        .{ .subscription_id = "count-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var auth_plan_storage = noztr_sdk.runtime.RelayPoolAuthStorage{};
    var count_plan_storage = noztr_sdk.runtime.RelayPoolCountStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &count_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x47} ** 32;
    var auth_event_storage = noztr_sdk.client.relay.auth_count_turn.AuthCountEventStorage{};
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

    const count_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &count_plan_storage,
    )).?.count;
    try std.testing.expectEqual(relay.relay_index, count_step.entry.descriptor.relay_index);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const count_request = try client.beginCountTurn(request_output[0..], specs[0..]);

    var reply_output: [128]u8 = undefined;
    const count_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .count = .{ .subscription_id = "count-feed", .count = 5 } },
    );
    const count_result = try client.acceptCountMessageJson(
        &count_request,
        count_json,
        arena.allocator(),
    );
    try std.testing.expect(count_result == .counted);
    try std.testing.expectEqual(@as(u64, 5), count_result.counted.count);
}
