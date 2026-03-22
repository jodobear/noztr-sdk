const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Drive one auth-aware legacy DM publish path through one bounded job surface.
test "recipe: legacy dm publish job client keeps auth and publish explicit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x41} ** 32;
    const recipient_secret = [_]u8{0x52} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var storage = noztr_sdk.client.dm.legacy.publish_job.LegacyDmPublishJobClientStorage{};
    var client = noztr_sdk.client.dm.legacy.publish_job.LegacyDmPublishJobClient.init(.{
        .owner_private_key = sender_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    var auth_storage = noztr_sdk.client.dm.legacy.publish_job.LegacyDmPublishJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;

    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        event_json_output[0..],
        event_message_output[0..],
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "legacy publish recipe",
            .created_at = 55,
            .iv = [_]u8{0x66} ** noztr.limits.nip04_iv_bytes,
        },
        54,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 56, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        event_json_output[0..],
        event_message_output[0..],
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "legacy publish recipe",
            .created_at = 55,
            .iv = [_]u8{0x66} ** noztr.limits.nip04_iv_bytes,
        },
        54,
    );
    try std.testing.expect(second_ready == .publish);

    var ok_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        ok_output[0..],
        &.{ .ok = .{ .event_id = second_ready.publish.event.id, .accepted = true, .status = "" } },
    );
    const result = try client.acceptPublishOkJson(&second_ready.publish, ok_json, arena.allocator());
    try std.testing.expect(result == .published);
    try std.testing.expect(result.published.accepted);
}
