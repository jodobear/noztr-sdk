const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: auth subscription turn client authenticates then resumes one bounded subscription turn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.relay.auth_subscription_turn.AuthSubscriptionTurnClientStorage{};
    var client = noztr_sdk.client.relay.auth_subscription_turn.AuthSubscriptionTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1]}",
        arena.allocator(),
    );
    const specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var auth_plan_storage = noztr_sdk.runtime.RelayPoolAuthStorage{};
    var subscription_plan_storage = noztr_sdk.runtime.RelayPoolSubscriptionStorage{};
    const auth_step = (try client.nextStep(
        &auth_plan_storage,
        specs[0..],
        &subscription_plan_storage,
    )).?.authenticate;

    const secret_key = [_]u8{0x51} ** 32;
    var auth_event_storage = noztr_sdk.client.relay.auth_subscription_turn.AuthSubscriptionEventStorage{};
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

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginSubscriptionTurn(&storage, request_output[0..], specs[0..]);

    var reply_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        reply_output[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    const intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(intake.complete);

    const result = try client.completeSubscriptionTurn(&storage, request_output[0..], &request);
    try std.testing.expect(result == .subscribed);
    try std.testing.expectEqual(.eose, result.subscribed.completion);
}
