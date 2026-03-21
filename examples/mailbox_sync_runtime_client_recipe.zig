const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Plan a bounded mailbox sync runtime explicitly, inspect one broader DM orchestration helper
// above the bounded runtime, export durable resume state after replay catch-up, restore it into a
// fresh client, inspect one caller-owned reconnect backoff window, reconnect explicitly, then
// resume one live mailbox subscription.
test "recipe: mailbox sync runtime client inspects dm cadence before live resubscribe" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = noztr_sdk.store.MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = noztr_sdk.store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    var client_storage = noztr_sdk.client.MailboxSyncRuntimeClientStorage{};
    var client = noztr_sdk.client.MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &client_storage);

    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    try client.noteRelayAuthChallenge(0, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 7 });

    var sender_session = noztr_sdk.workflows.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var replay_outbound_buffer = noztr_sdk.workflows.MailboxOutboundBuffer{};
    const replay_outbound = try sender_session.beginDirectMessage(
        &replay_outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "sync runtime replay payload",
            .created_at = 41,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var live_outbound_buffer = noztr_sdk.workflows.MailboxOutboundBuffer{};
    const live_outbound = try sender_session.beginDirectMessage(
        &live_outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "sync runtime live payload",
            .created_at = 42,
            .wrap_signer_private_key = [_]u8{0x23} ** 32,
            .seal_nonce = [_]u8{0x46} ** 32,
            .wrap_nonce = [_]u8{0x57} ** 32,
        },
        arena.allocator(),
    );

    const replay_specs = [_]noztr_sdk.runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };
    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1059]}",
        arena.allocator(),
    );
    const subscription_specs = [_]noztr_sdk.runtime.RelaySubscriptionSpec{
        .{ .subscription_id = "mailbox-feed", .filters = (&[_]noztr.nip01_filter.Filter{filter})[0..] },
    };

    var orchestration_storage = noztr_sdk.client.MailboxDmOrchestrationStorage{};
    const auth_policy = try client.inspectDmOrchestration(
        checkpoint_store,
        replay_specs[0..],
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(auth_policy.needs_auth_progress);
    try std.testing.expect(auth_policy.nextStep() == .authenticate);

    var auth_storage = noztr_sdk.client.MailboxSyncRuntimeAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const auth_event = try client.prepareAuthEvent(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &auth_policy.nextStep().authenticate,
        90,
    );
    _ = try client.acceptPreparedAuthEvent(&auth_event, 95, 60);

    const replay_policy = try client.inspectDmOrchestration(
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
        "mailbox-replay",
        replay_specs[0..],
    );
    const replay_wrap_event = try noztr.nip01_event.event_parse_json(
        replay_outbound.wrap_event_json,
        arena.allocator(),
    );
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-replay", .event = replay_wrap_event } },
    );
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    _ = try client.acceptReplayMessageJson(
        &replay_request,
        replay_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    const replay_eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-replay" } },
    );
    _ = try client.acceptReplayMessageJson(
        &replay_request,
        replay_eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    const replay_result = try client.completeReplayTurn(request_output[0..], &replay_request);
    try client.saveReplayTurnResult(checkpoint_archive, &replay_result.replayed);
    client.markReplayCatchupComplete();

    var resume_storage = noztr_sdk.client.MailboxSyncRuntimeResumeStorage{};
    const resume_state = client.exportResumeState(&resume_storage);

    var resumed_storage = noztr_sdk.client.MailboxSyncRuntimeClientStorage{};
    var resumed = noztr_sdk.client.MailboxSyncRuntimeClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &resumed_storage);
    try resumed.restoreResumeState(&resume_state);

    var cadence_storage = noztr_sdk.client.MailboxDmRuntimeCadenceStorage{};
    const reconnect_wait = try resumed.inspectDmRuntimeCadence(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        .{
            .now_unix_seconds = 99,
            .reconnect_not_before_unix_seconds = 120,
        },
        &cadence_storage,
    );
    try std.testing.expect(reconnect_wait.blocked_by_reconnect_backoff);
    try std.testing.expect(reconnect_wait.nextStep() == .wait);
    try std.testing.expectEqual(
        noztr_sdk.client.MailboxDmRuntimeCadenceWaitReason.reconnect_backoff,
        reconnect_wait.nextStep().wait.reason,
    );

    const reconnect_policy = try resumed.inspectDmRuntimeCadence(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        .{
            .now_unix_seconds = 120,
            .reconnect_not_before_unix_seconds = 120,
        },
        &cadence_storage,
    );
    try std.testing.expect(reconnect_policy.needs_connect_progress);
    try std.testing.expect(reconnect_policy.nextStep() == .reconnect);
    try resumed.markRelayConnected(reconnect_policy.nextStep().reconnect.entry.descriptor.relay_index);

    const subscribe_policy = try resumed.inspectDmOrchestration(
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
    const receive_policy = try resumed.inspectDmOrchestration(
        checkpoint_store,
        &.{},
        subscription_specs[0..],
        &orchestration_storage,
    );
    try std.testing.expect(receive_policy.can_receive_live);
    try std.testing.expect(receive_policy.nextStep() == .receive);
    const live_wrap_event = try noztr.nip01_event.event_parse_json(
        live_outbound.wrap_event_json,
        arena.allocator(),
    );
    const live_event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-feed", .event = live_wrap_event } },
    );
    const live_intake = try resumed.acceptSubscriptionMessageJson(
        &live_request,
        live_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(live_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "sync runtime live payload",
        live_intake.envelope.?.direct_message.message.content,
    );
}

fn buildRelayListEventJson(
    output: []u8,
    relay_text: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try common.derivePublicKey(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_text } },
    };
    var event = common.simpleEvent(
        noztr.nip17_private_messages.dm_relays_kind,
        relay_list_author_pubkey,
        created_at,
        "",
        tags[0..],
    );
    try common.signEvent(signer_secret_key, &event);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":10050," ++
            "\"tags\":[[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_text,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
