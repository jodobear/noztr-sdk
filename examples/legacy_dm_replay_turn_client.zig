const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Replay one checkpoint-backed legacy DM transcript explicitly, then decrypt kind-4 replay
// events through the bounded replay adapter.
test "recipe: legacy dm replay turn client classifies replay events through dm intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    const sender = noztr_sdk.workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    var outbound = noztr_sdk.workflows.dm.legacy.LegacyDmOutboundStorage{};
    const prepared = try sender.buildDirectMessageEvent(&outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy replay recipe",
        .created_at = 61,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });

    var storage = noztr_sdk.client.dm.legacy.replay_turn.Storage{};
    var client = noztr_sdk.client.dm.legacy.replay_turn.Client.init(.{
        .owner_private_key = recipient_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("legacy-dm", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "legacy-dm",
            .query = .{ .limit = 8 },
        },
    };
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(
        checkpoint_store,
        request_output[0..],
        "legacy-feed",
        replay_specs[0..],
    );

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-feed", .event = prepared.event } },
    );
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const intake = try client.acceptReplayMessageJson(
        &request,
        event_json,
        plaintext_output[0..],
        arena.allocator(),
    );

    try std.testing.expect(intake.message != null);
    try std.testing.expectEqualStrings("legacy replay recipe", intake.message.?.plaintext);
}
