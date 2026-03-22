const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: publish client signs one local draft and targets one ready relay explicitly" {
    var storage = noztr_sdk.client.relay.publish.PublishClientStorage{};
    var client = noztr_sdk.client.relay.publish.PublishClient.init(.{}, &storage);

    const ready = try client.addRelay("wss://relay.one");
    const gated = try client.addRelay("wss://relay.two");
    _ = try client.addRelay("wss://relay.three");
    try client.markRelayConnected(ready.relay_index);
    try client.markRelayConnected(gated.relay_index);
    try client.noteRelayAuthChallenge(gated.relay_index, "challenge-1");

    var publish_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    try std.testing.expectEqual(@as(u8, 1), publish_plan.publish_count);
    try std.testing.expectEqual(@as(u8, 1), publish_plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), publish_plan.connect_count);

    const secret_key = [_]u8{0x11} ** 32;
    const draft = noztr_sdk.client.local.operator.LocalEventDraft{
        .kind = 1,
        .created_at = 50,
        .content = "hello publish recipe",
    };

    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareSignedEvent(event_json_buffer[0..], &secret_key, &draft);
    try noztr.nip01_event.event_verify(&prepared.event);

    const publish_step = publish_plan.nextStep().?;
    var message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted = try client.composeTargetedPublish(
        message_buffer[0..],
        &publish_step,
        &prepared,
    );

    try std.testing.expectEqualStrings("wss://relay.one", targeted.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted.event_message_json, "[\"EVENT\","));
    try std.testing.expect(std.mem.indexOf(u8, targeted.event_json, "\"hello publish recipe\"") != null);
}
