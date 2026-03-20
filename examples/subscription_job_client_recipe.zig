const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: subscription job client authenticates when needed then returns one bounded subscription job" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = noztr_sdk.client.SubscriptionJobClientStorage{};
    var client = noztr_sdk.client.SubscriptionJobClient.init(.{}, &storage);
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

    const secret_key = [_]u8{0x32} ** 32;
    var auth_storage = noztr_sdk.client.SubscriptionJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        &secret_key,
        specs[0..],
        90,
    );
    try std.testing.expect(second_ready == .subscription);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        request_output[0..],
        &.{ .eose = .{ .subscription_id = "feed" } },
    );
    const intake = try client.acceptSubscriptionMessageJson(
        &storage,
        &second_ready.subscription,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(intake.complete);

    const result = try client.completeSubscriptionJob(
        &storage,
        request_output[0..],
        &second_ready.subscription,
    );
    try std.testing.expect(result == .subscribed);
    try std.testing.expectEqual(.eose, result.subscribed.completion);
}
