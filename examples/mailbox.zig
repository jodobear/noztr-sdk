const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Build one outbound direct message once, inspect mailbox workflow actions over pending delivery,
// inspect one shared relay-pool runtime step explicitly, then unwrap it through a recipient
// mailbox session.
test "recipe: mailbox session inspects workflow, inspects shared relay-pool runtime, plans sender-copy delivery, and unwraps one direct message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);
    var sender_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&sender_secret);

    var outbound_buffer = noztr_sdk.workflows.dm.mailbox.MailboxOutboundBuffer{};
    var delivery_storage = noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage{};
    var recipient_relay_list_storage: [4096]u8 = undefined;
    var sender_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJsonThree(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        "wss://relay.three",
        41,
        &recipient_secret,
    );
    const sender_relay_list_json = try buildRelayListEventJsonTwo(
        sender_relay_list_storage[0..],
        "wss://sender-copy",
        "wss://relay.two/inbox",
        42,
        &sender_secret,
    );
    const delivery = try sender_session.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        sender_relay_list_json,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.two/inbox",
            .content = "ciphertext payload",
            .created_at = 40,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u8, 4), delivery.relay_count);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", delivery.relayUrl(0).?);
    try std.testing.expect(delivery.deliversToRecipient(0));
    try std.testing.expect(delivery.deliversSenderCopy(0));
    try std.testing.expectEqualStrings("wss://relay.one", delivery.relayUrl(1).?);
    try std.testing.expect(delivery.deliversToRecipient(1));
    try std.testing.expect(!delivery.deliversSenderCopy(1));
    try std.testing.expectEqualStrings("wss://relay.three", delivery.relayUrl(2).?);
    try std.testing.expect(delivery.deliversToRecipient(2));
    try std.testing.expect(!delivery.deliversSenderCopy(2));
    try std.testing.expectEqualStrings("wss://sender-copy", delivery.relayUrl(3).?);
    try std.testing.expect(!delivery.deliversToRecipient(3));
    try std.testing.expect(delivery.deliversSenderCopy(3));
    try std.testing.expectEqual(@as(?u8, 0), delivery.nextRecipientRelayIndex());
    try std.testing.expectEqual(@as(?u8, 0), delivery.nextSenderCopyRelayIndex());
    const next_delivery = delivery.nextStep().?;
    const next_recipient_delivery = delivery.nextRecipientStep().?;
    const next_sender_copy_delivery = delivery.nextSenderCopyStep().?;
    try std.testing.expectEqual(@as(u8, 0), next_delivery.relay_index);
    try std.testing.expectEqualStrings("wss://relay.two/inbox", next_delivery.relay_url);
    try std.testing.expect(next_delivery.role.recipient);
    try std.testing.expect(next_delivery.role.sender_copy);
    try std.testing.expect(std.mem.eql(u8, &next_delivery.wrap_event_id, &delivery.wrap_event_id));
    try std.testing.expectEqualStrings(delivery.wrap_event_json, next_delivery.wrap_event_json);
    try std.testing.expectEqual(next_delivery.relay_index, next_recipient_delivery.relay_index);
    try std.testing.expectEqual(next_delivery.relay_index, next_sender_copy_delivery.relay_index);

    var sender_workflow_relay_list_storage: [4096]u8 = undefined;
    const sender_workflow_relay_list_json = try buildRelayListEventJsonFour(
        sender_workflow_relay_list_storage[0..],
        "wss://relay.one",
        "wss://relay.two/inbox",
        "wss://relay.three",
        "wss://sender-copy",
        43,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(
        sender_workflow_relay_list_json,
        arena.allocator(),
    );
    try sender_session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.two/inbox", try sender_session.advanceRelay());
    try sender_session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://relay.three", try sender_session.advanceRelay());
    try sender_session.markCurrentRelayConnected();
    try std.testing.expectEqualStrings("wss://sender-copy", try sender_session.advanceRelay());
    try sender_session.markCurrentRelayConnected();

    var sender_workflow_storage = noztr_sdk.workflows.dm.mailbox.MailboxWorkflowStorage{};
    const sender_workflow = try sender_session.inspectWorkflow(.{
        .pending_delivery = &delivery,
        .storage = &sender_workflow_storage,
    });
    try std.testing.expectEqual(@as(u8, 3), sender_workflow.publish_recipient_count);
    try std.testing.expectEqual(@as(u8, 1), sender_workflow.publish_sender_copy_count);
    const next_workflow = sender_workflow.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.dm.mailbox.MailboxWorkflowAction.publish_recipient,
        next_workflow.entry.action,
    );
    try std.testing.expectEqualStrings(
        "wss://relay.two/inbox",
        try sender_session.selectWorkflowRelay(next_workflow),
    );

    var recipient_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&recipient_secret);
    _ = try recipient_session.hydrateRelayListEventJson(
        recipient_relay_list_json,
        arena.allocator(),
    );
    try recipient_session.markCurrentRelayConnected();
    try recipient_session.noteCurrentRelayAuthChallenge("challenge-1");
    try std.testing.expectEqualStrings(
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        try recipient_session.selectRelay(1),
    );
    try recipient_session.markCurrentRelayConnected();

    var runtime_storage = noztr_sdk.workflows.dm.mailbox.MailboxRuntimeStorage{};
    const runtime = try recipient_session.inspectRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 3), runtime.relay_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.receive_count);
    try std.testing.expectEqual(@as(u8, 1), runtime.connect_count);
    try std.testing.expectEqual(noztr_sdk.workflows.dm.mailbox.MailboxRuntimeAction.authenticate, runtime.entry(0).?.action);
    try std.testing.expectEqual(noztr_sdk.workflows.dm.mailbox.MailboxRuntimeAction.receive, runtime.entry(1).?.action);
    try std.testing.expect(runtime.entry(1).?.is_current);
    const next_runtime = runtime.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.dm.mailbox.MailboxRuntimeAction.receive,
        next_runtime.entry.action,
    );
    try std.testing.expectEqualStrings(
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        next_runtime.entry.relay_url,
    );

    var relay_pool_runtime = noztr_sdk.workflows.dm.mailbox.MailboxRelayPoolRuntimeStorage{};
    const shared_plan = recipient_session.inspectRelayPoolRuntime(&relay_pool_runtime);
    try std.testing.expectEqual(@as(u8, 1), shared_plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), shared_plan.ready_count);
    try std.testing.expectEqual(@as(u8, 1), shared_plan.connect_count);
    const shared_step = shared_plan.nextStep().?;
    try std.testing.expectEqual(noztr_sdk.runtime.RelayPoolAction.authenticate, shared_step.entry.action);
    try std.testing.expectEqualStrings(
        "wss://relay.one",
        try recipient_session.selectRelayPoolStep(&shared_step),
    );
    try std.testing.expectEqualStrings(
        "WSS://RELAY.TWO:443/inbox?x=1#f",
        try recipient_session.selectRelay(1),
    );

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    const outcome = try recipient_session.acceptWrappedMessageJson(
        next_delivery.wrap_event_json,
        recipients[0..],
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("ciphertext payload", outcome.message.content);
    try std.testing.expectEqual(@as(usize, 1), outcome.message.recipients.len);
}

// Build one outbound file message once, inspect mailbox workflow actions over pending delivery,
// select the next workflow relay explicitly, and unwrap it.
test "recipe: mailbox session selects the next workflow relay, plans, and unwraps one file message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);
    var sender_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    var outbound_buffer = noztr_sdk.workflows.dm.mailbox.MailboxOutboundBuffer{};
    var delivery_storage = noztr_sdk.workflows.dm.mailbox.MailboxDeliveryStorage{};
    var recipient_relay_list_storage: [4096]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        43,
        &recipient_secret,
    );
    const delivery = try sender_session.planFileMessageRelayFanout(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .file_url = "https://cdn.example/file.enc",
            .file_type = "image/jpeg",
            .decryption_key = "secret-key",
            .decryption_nonce = "secret-nonce",
            .encrypted_file_hash = [_]u8{0x11} ** 32,
            .original_file_hash = [_]u8{0x22} ** 32,
            .size = 4096,
            .dimensions = .{ .width = 800, .height = 600 },
            .blurhash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
            .thumbs = &.{"https://cdn.example/thumb.jpg"},
            .fallbacks = &.{"https://cdn.example/fallback.jpg"},
            .created_at = 44,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u8, 1), delivery.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", delivery.relayUrl(0).?);
    try std.testing.expect(delivery.deliversToRecipient(0));
    try std.testing.expectEqual(@as(?u8, 0), delivery.nextRecipientRelayIndex());
    try std.testing.expect(delivery.nextSenderCopyRelayIndex() == null);
    const next_delivery = delivery.nextStep().?;
    const next_recipient_delivery = delivery.nextRecipientStep().?;
    try std.testing.expect(delivery.nextSenderCopyStep() == null);
    try std.testing.expectEqual(@as(u8, 0), next_delivery.relay_index);
    try std.testing.expectEqualStrings("wss://relay.one", next_delivery.relay_url);
    try std.testing.expect(next_delivery.role.recipient);
    try std.testing.expect(!next_delivery.role.sender_copy);
    try std.testing.expectEqual(next_delivery.relay_index, next_recipient_delivery.relay_index);

    var sender_workflow_relay_list_storage: [4096]u8 = undefined;
    const sender_workflow_relay_list_json = try buildRelayListEventJson(
        sender_workflow_relay_list_storage[0..],
        "wss://relay.one",
        44,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(
        sender_workflow_relay_list_json,
        arena.allocator(),
    );
    try sender_session.markCurrentRelayConnected();

    var sender_workflow_storage = noztr_sdk.workflows.dm.mailbox.MailboxWorkflowStorage{};
    const sender_workflow = try sender_session.inspectWorkflow(.{
        .pending_delivery = &delivery,
        .storage = &sender_workflow_storage,
    });
    const next_workflow = sender_workflow.nextStep().?;
    try std.testing.expectEqual(
        noztr_sdk.workflows.dm.mailbox.MailboxWorkflowAction.publish_recipient,
        next_workflow.entry.action,
    );
    try std.testing.expectEqualStrings(
        "wss://relay.one",
        try sender_session.selectWorkflowRelay(next_workflow),
    );

    var recipient_session = noztr_sdk.workflows.dm.mailbox.MailboxSession.init(&recipient_secret);
    _ = try recipient_session.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try recipient_session.markCurrentRelayConnected();

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const outcome = try recipient_session.acceptWrappedEnvelopeJson(
        next_delivery.wrap_event_json,
        recipients[0..],
        thumbs[0..],
        fallbacks[0..],
        arena.allocator(),
    );

    try std.testing.expect(outcome == .file_message);
    try std.testing.expectEqualStrings(
        "https://cdn.example/file.enc",
        outcome.file_message.file_message.file_url,
    );
    try std.testing.expectEqualStrings(
        "image/jpeg",
        outcome.file_message.file_message.file_type,
    );
    try std.testing.expectEqual(@as(usize, 1), outcome.file_message.file_message.thumbs.len);
}

fn buildRelayListEventJson(output: []u8, relay_text: []const u8, created_at: u64, signer_secret_key: *const [32]u8) ![]const u8 {
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

fn buildRelayListEventJsonTwo(
    output: []u8,
    relay_one: []const u8,
    relay_two: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try common.derivePublicKey(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_one } },
        .{ .items = &.{ "relay", relay_two } },
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
            "\"tags\":[[\"relay\",\"{s}\"],[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_one,
            relay_two,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}

fn buildRelayListEventJsonThree(
    output: []u8,
    relay_one: []const u8,
    relay_two: []const u8,
    relay_three: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try common.derivePublicKey(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_one } },
        .{ .items = &.{ "relay", relay_two } },
        .{ .items = &.{ "relay", relay_three } },
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
            "\"tags\":[[\"relay\",\"{s}\"],[\"relay\",\"{s}\"],[\"relay\",\"{s}\"]]," ++
            "\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_one,
            relay_two,
            relay_three,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}

fn buildRelayListEventJsonFour(
    output: []u8,
    relay_one: []const u8,
    relay_two: []const u8,
    relay_three: []const u8,
    relay_four: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try common.derivePublicKey(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_one } },
        .{ .items = &.{ "relay", relay_two } },
        .{ .items = &.{ "relay", relay_three } },
        .{ .items = &.{ "relay", relay_four } },
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
            "\"tags\":[[\"relay\",\"{s}\"],[\"relay\",\"{s}\"],[\"relay\",\"{s}\"],[\"relay\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            created_at,
            relay_one,
            relay_two,
            relay_three,
            relay_four,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
