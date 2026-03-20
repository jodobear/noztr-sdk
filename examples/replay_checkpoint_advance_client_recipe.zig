const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: replay checkpoint advance client derives and persists one replay checkpoint target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var exchange_storage = noztr_sdk.client.RelayReplayExchangeClientStorage{};
    var exchange_client = noztr_sdk.client.RelayReplayExchangeClient.init(.{}, &exchange_storage);
    const relay = try exchange_client.addRelay("wss://relay.one");
    try exchange_client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var transcript = noztr_sdk.client.RelaySubscriptionTranscriptStorage{};
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_request = try exchange_client.beginReplay(
        checkpoint_store,
        &transcript,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const advance_client = noztr_sdk.client.ReplayCheckpointAdvanceClient.init(.{});
    var advance_state = advance_client.beginAdvance(&replay_request);

    const secret_key = [_]u8{0x77} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 21,
        .tags = &.{},
        .content = "replay checkpoint advance recipe",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    const event_outcome = try exchange_client.acceptReplayMessageJson(
        &replay_request,
        &transcript,
        event_json,
        arena.allocator(),
    );
    try advance_client.acceptReplayOutcome(&advance_state, &event_outcome);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_buffer[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    const eose_outcome = try exchange_client.acceptReplayMessageJson(
        &replay_request,
        &transcript,
        eose_json,
        arena.allocator(),
    );
    try advance_client.acceptReplayOutcome(&advance_state, &eose_outcome);

    const save_target = try advance_client.composeSaveTarget(&advance_state);
    try advance_client.saveTarget(checkpoint_archive, &save_target);

    const restored = try checkpoint_archive.loadRelayCheckpoint("tooling", relay.relay_url);
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 8), restored.?.cursor.offset);
}
