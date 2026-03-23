const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Step one bounded legacy-DM sync runtime explicitly, inspect one broader DM orchestration helper
// above that runtime plus one caller-owned replay-refresh cadence helper, then drive durable
// resume export/restore, explicit reconnect, subscribe, and live receive posture.
test "recipe: legacy dm sync runtime client inspects dm cadence before live resubscribe" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var storage = noztr_sdk.client.dm.legacy.sync_runtime.Storage{};
    var client = noztr_sdk.client.dm.legacy.sync_runtime.Client.init(.{
        .owner_private_key = recipient_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("legacy-dm", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "legacy-dm",
            .query = .{ .limit = 8 },
        },
    };
    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[4]}",
        arena.allocator(),
    );
    const subscription_specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "legacy-live", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var orchestration_storage = noztr_sdk.client.dm.legacy.sync_runtime.OrchestrationStorage{};
    const first_policy = try client.inspectOrchestration(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(first_policy.needs_auth_progress);
    try std.testing.expect(first_policy.nextStep() == .authenticate);

    var auth_storage = noztr_sdk.client.dm.legacy.sync_runtime.AuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const prepared_auth = try client.prepareAuthEvent(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &first_policy.nextStep().authenticate,
        70,
    );
    _ = try client.acceptPreparedAuthEvent(&prepared_auth, 71, 60);

    const sender = noztr_sdk.workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    var outbound = noztr_sdk.workflows.dm.legacy.LegacyDmOutboundStorage{};
    const replay_event = try sender.buildDirectMessageEvent(&outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy replay runtime",
        .created_at = 72,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });

    const replay_policy = try client.inspectOrchestration(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(replay_policy.needs_replay_catchup);
    try std.testing.expect(replay_policy.nextStep() == .replay_resume);

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_request = try client.beginReplayTurn(
        checkpoint_store,
        request_output[0..],
        "legacy-replay",
        replay_specs[0..],
    );
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-replay", .event = replay_event.event } },
    );
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const replay_intake = try client.acceptReplayMessageJson(
        &replay_request,
        replay_event_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    try std.testing.expect(replay_intake.message != null);
    try std.testing.expectEqualStrings("legacy replay runtime", replay_intake.message.?.plaintext);

    const replay_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "legacy-replay" } },
    );
    _ = try client.acceptReplayMessageJson(
        &replay_request,
        replay_eose_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    const replay_result = try client.completeReplayTurn(request_output[0..], &replay_request);
    try std.testing.expect(replay_result == .replayed);
    try client.saveReplayTurnResult(checkpoint_archive, &replay_result.replayed);
    client.markReplayCatchupComplete();

    var resume_storage = noztr_sdk.client.dm.legacy.sync_runtime.ResumeStorage{};
    const resume_state = try client.exportResumeState(&resume_storage);

    var resumed_storage = noztr_sdk.client.dm.legacy.sync_runtime.Storage{};
    var resumed = noztr_sdk.client.dm.legacy.sync_runtime.Client.init(.{
        .owner_private_key = recipient_secret,
    }, &resumed_storage);
    try resumed.restoreResumeState(&resume_state);

    const reconnect_policy = try resumed.inspectOrchestration(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(reconnect_policy.needs_connect_progress);
    try std.testing.expect(reconnect_policy.nextStep() == .reconnect);
    try resumed.markRelayConnected(reconnect_policy.nextStep().reconnect.entry.descriptor.relay_index);

    var cadence_storage = noztr_sdk.client.dm.legacy.sync_runtime.CadenceStorage{};
    const refresh_policy = try resumed.inspectCadence(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        .{
            .now_unix_seconds = 120,
            .replay_refresh_not_before_unix_seconds = 110,
        },
        &cadence_storage,
    );
    try std.testing.expect(refresh_policy.replay_refresh_due);
    try std.testing.expect(refresh_policy.nextStep() == .reopen_replay_catchup);
    resumed.resetReplayCatchup();

    const replay_resume_policy = try resumed.inspectOrchestration(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(replay_resume_policy.needs_replay_catchup);
    try std.testing.expect(replay_resume_policy.nextStep() == .replay_resume);
    resumed.markReplayCatchupComplete();

    const subscribe_policy = try resumed.inspectOrchestration(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(subscribe_policy.needs_live_subscription);
    try std.testing.expect(subscribe_policy.nextStep() == .subscribe_resume);

    const live_request = try resumed.beginSubscriptionTurn(
        request_output[0..],
        subscription_specs[0..],
    );
    try std.testing.expect(resumed.liveSubscriptionActive());

    const receive_policy = try resumed.inspectOrchestration(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(receive_policy.can_receive_live);
    try std.testing.expect(receive_policy.nextStep() == .receive);

    const live_event = try sender.buildDirectMessageEvent(&outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy live runtime",
        .created_at = 73,
        .iv = [_]u8{0x66} ** noztr.limits.nip04_iv_bytes,
    });
    const live_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-live", .event = live_event.event } },
    );
    const live_intake = try resumed.acceptSubscriptionMessageJson(
        &live_request,
        live_event_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    try std.testing.expect(live_intake.message != null);
    try std.testing.expectEqualStrings("legacy live runtime", live_intake.message.?.plaintext);

    const live_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "legacy-live" } },
    );
    _ = try resumed.acceptSubscriptionMessageJson(
        &live_request,
        live_eose_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    const live_result = try resumed.completeSubscriptionTurn(request_output[0..], &live_request);
    try std.testing.expect(live_result == .subscribed);
    try std.testing.expectEqual(.eose, live_result.subscribed.completion);
    try std.testing.expect(!resumed.liveSubscriptionActive());
}
