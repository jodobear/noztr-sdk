const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay replay exchange client composes replay intake and close explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = noztr_sdk.client.relay.replay_exchange.RelayReplayExchangeClientStorage{};
    var client = noztr_sdk.client.relay.replay_exchange.RelayReplayExchangeClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var transcript = noztr_sdk.client.relay.response.RelaySubscriptionTranscriptStorage{};
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_request = try client.beginReplay(
        checkpoint_store,
        &transcript,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const secret_key = [_]u8{0x71} ** 32;
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var replay_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 20,
        .content = "replay exchange event",
        .tags = &.{},
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &replay_event);

    var relay_json_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_reply_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_json_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = replay_event } },
    );
    const replay_outcome = try client.acceptReplayMessageJson(
        &replay_request,
        &transcript,
        event_reply_json,
        arena.allocator(),
    );
    try std.testing.expect(replay_outcome.message == .event);

    const close_request = try client.composeClose(request_output[0..], &replay_request);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"replay-feed\"]", close_request.request_json);
}
