const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: mixed dm client normalizes mailbox and legacy intake and keeps reply selection explicit" {
    var storage = noztr_sdk.client.dm.mixed.MixedDmClientStorage{};
    const client = noztr_sdk.client.dm.mixed.MixedDmClient.init(.{}, &storage);

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var capability_storage = noztr_sdk.client.dm.capability.DmCapabilityClientStorage{};
    const capability = noztr_sdk.client.dm.capability.DmCapabilityClient.init(.{}, &capability_storage);
    var relay_tags: [1]noztr.nip01_event.EventTag = undefined;
    var built_tags: [1]noztr.nip17_private_messages.BuiltTag = undefined;
    var relay_list_storage = noztr_sdk.client.dm.capability.MailboxRelayListDraftStorage.init(
        relay_tags[0..],
        built_tags[0..],
    );
    var relay_list_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const relay_list = try capability.prepareMailboxRelayListPublish(
        relay_list_json_output[0..],
        &relay_list_storage,
        &recipient_secret,
        &.{ .created_at = 79, .relays = &.{"wss://dm.one"} },
    );

    var mailbox_buffer = noztr_sdk.workflows.dm.mailbox.MailboxOutboundBuffer{};
    var mailbox_delivery_storage = noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage{};
    var mailbox_sender = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    const mailbox_delivery = try mailbox_sender.planDirectMessageDelivery(
        &mailbox_buffer,
        &mailbox_delivery_storage,
        relay_list.event_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "mailbox hello",
            .created_at = 80,
            .wrap_signer_private_key = sender_secret,
            .seal_nonce = [_]u8{0x33} ** 32,
            .wrap_nonce = [_]u8{0x44} ** 32,
        },
        arena.allocator(),
    );

    var mailbox_recipient = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&recipient_secret);
    _ = try mailbox_recipient.hydrateRelayListEventJson(relay_list.event_json, arena.allocator());
    try mailbox_recipient.markCurrentRelayConnected();
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const mailbox_envelope = try mailbox_recipient.acceptWrappedEnvelopeJson(
        mailbox_delivery.wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );
    const mailbox_observation = try client.observeMailboxEnvelope(&mailbox_envelope);
    try std.testing.expectEqual(.mailbox, mailbox_observation.protocol());

    var legacy_outbound = noztr_sdk.workflows.dm.legacy.LegacyDmOutboundStorage{};
    const legacy_sender = noztr_sdk.workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    const legacy_event = try legacy_sender.buildDirectMessageEvent(&legacy_outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy hello",
        .created_at = 81,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });
    var plaintext_output: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const legacy_recipient = noztr_sdk.workflows.dm.legacy.LegacyDmSession.init(&recipient_secret);
    const legacy_message = try legacy_recipient.acceptDirectMessageEvent(
        &legacy_event.event,
        plaintext_output[0..],
    );
    const legacy_observation = client.observeLegacyMessage(&legacy_message);
    try std.testing.expectEqual(.legacy, legacy_observation.protocol());

    const mirrored_mailbox = try client.selectReplyRouteForObservation(
        &mailbox_observation,
        .sender_protocol,
        true,
    );
    try std.testing.expectEqual(.mailbox, mirrored_mailbox.protocol);

    const explicit_fallback = try client.selectReplyRouteForObservation(
        &legacy_observation,
        .prefer_mailbox,
        false,
    );
    try std.testing.expectEqual(.legacy, explicit_fallback.protocol);
}
