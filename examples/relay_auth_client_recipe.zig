const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay auth client composes one auth event and returns the relay to ready" {
    var storage = noztr_sdk.client.relay.auth.RelayAuthClientStorage{};
    var client = noztr_sdk.client.relay.auth.RelayAuthClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_plan_storage = noztr_sdk.runtime.RelayPoolAuthStorage{};
    const auth_plan = client.inspectAuth(&auth_plan_storage);
    try std.testing.expectEqual(@as(u8, 1), auth_plan.authenticate_count);
    const step = auth_plan.nextStep().?;
    try std.testing.expectEqualStrings("challenge-1", step.entry.challenge);

    const secret_key = [_]u8{0x51} ** 32;
    var event_storage = noztr_sdk.client.relay.auth.RelayAuthEventStorage{};
    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared = try client.prepareAuthEvent(
        &event_storage,
        event_json_buffer[0..],
        auth_message_buffer[0..],
        &step,
        &secret_key,
        42,
    );

    try std.testing.expectEqualStrings("wss://relay.one", prepared.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, prepared.auth_message_json, "[\"AUTH\","));
    try noztr.nip42_auth.auth_validate_event(
        &prepared.event,
        prepared.relay.relay_url,
        prepared.challenge,
        45,
        60,
    );

    _ = try client.acceptPreparedAuthEvent(&prepared, 45, 60);

    var runtime_storage = noztr_sdk.runtime.RelayPoolPlanStorage{};
    const runtime_plan = client.inspectRelayRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);
    try std.testing.expectEqual(
        noztr_sdk.runtime.RelayPoolAction.ready,
        runtime_plan.entry(relay.relay_index).?.action,
    );
}
