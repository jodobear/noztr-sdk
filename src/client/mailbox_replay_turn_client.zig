const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const relay_replay_turn = @import("relay_replay_turn_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const workflows = @import("../workflows/mod.zig");

const mailbox_wrap_event_kind: u32 = 1059;

pub const MailboxReplayTurnClientError =
    relay_replay_turn.RelayReplayTurnClientError ||
    workflows.MailboxError;

pub const MailboxReplayTurnClientConfig = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    replay_turn: relay_replay_turn.RelayReplayTurnClientConfig = .{},
};

pub const MailboxReplayTurnClientStorage = struct {
    mailbox: workflows.MailboxSession = undefined,
    replay_turn: relay_replay_turn.RelayReplayTurnClientStorage = .{},
};

pub const MailboxReplayTurnRequest = relay_replay_turn.ReplayTurnRequest;
pub const MailboxReplayTurnResult = relay_replay_turn.ReplayTurnResult;

pub const MailboxReplayTurnIntake = struct {
    replay: relay_replay_turn.ReplayTurnIntake,
    envelope: ?workflows.MailboxEnvelopeOutcome,
};

pub const MailboxReplayTurnClient = struct {
    config: MailboxReplayTurnClientConfig,
    storage: *MailboxReplayTurnClientStorage,
    replay_turn: relay_replay_turn.RelayReplayTurnClient,

    pub fn init(
        config: MailboxReplayTurnClientConfig,
        storage: *MailboxReplayTurnClientStorage,
    ) MailboxReplayTurnClient {
        storage.* = .{
            .mailbox = workflows.MailboxSession.init(&config.recipient_private_key),
        };
        return .{
            .config = config,
            .storage = storage,
            .replay_turn = relay_replay_turn.RelayReplayTurnClient.attach(
                config.replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn attach(
        config: MailboxReplayTurnClientConfig,
        storage: *MailboxReplayTurnClientStorage,
    ) MailboxReplayTurnClient {
        return .{
            .config = config,
            .storage = storage,
            .replay_turn = relay_replay_turn.RelayReplayTurnClient.attach(
                config.replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn relayCount(self: *const MailboxReplayTurnClient) u8 {
        return self.storage.mailbox.relayCount();
    }

    pub fn currentRelayUrl(self: *const MailboxReplayTurnClient) ?[]const u8 {
        return self.storage.mailbox.currentRelayUrl();
    }

    pub fn currentRelayAuthChallenge(self: *const MailboxReplayTurnClient) ?[]const u8 {
        return self.storage.mailbox.currentRelayAuthChallenge();
    }

    pub fn hydrateRelayListEventJson(
        self: *MailboxReplayTurnClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxReplayTurnClientError!u8 {
        const relay_count = try self.storage.mailbox.hydrateRelayListEventJson(event_json, scratch);
        self.replay_turn = relay_replay_turn.RelayReplayTurnClient.init(
            self.config.replay_turn,
            &self.storage.replay_turn,
        );

        var relay_index: u8 = 0;
        while (relay_index < relay_count) : (relay_index += 1) {
            const relay_url_text = try self.storage.mailbox.selectRelay(relay_index);
            _ = try self.replay_turn.addRelay(relay_url_text);
        }
        if (relay_count > 0) {
            _ = try self.storage.mailbox.selectRelay(0);
        }
        return relay_count;
    }

    pub fn selectRelay(
        self: *MailboxReplayTurnClient,
        relay_index: u8,
    ) MailboxReplayTurnClientError![]const u8 {
        return self.storage.mailbox.selectRelay(relay_index);
    }

    pub fn markRelayConnected(
        self: *MailboxReplayTurnClient,
        relay_index: u8,
    ) MailboxReplayTurnClientError!void {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.markCurrentRelayConnected();
        try self.replay_turn.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *MailboxReplayTurnClient,
        relay_index: u8,
    ) MailboxReplayTurnClientError!void {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.noteCurrentRelayDisconnected();
        try self.replay_turn.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *MailboxReplayTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) MailboxReplayTurnClientError!void {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.noteCurrentRelayAuthChallenge(challenge);
        try self.replay_turn.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn acceptRelayAuthEvent(
        self: *MailboxReplayTurnClient,
        relay_index: u8,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) MailboxReplayTurnClientError!runtime.RelayDescriptor {
        _ = try self.storage.mailbox.selectRelay(relay_index);
        try self.storage.mailbox.acceptCurrentRelayAuthEvent(
            auth_event,
            now_unix_seconds,
            window_seconds,
        );
        try self.replay_turn.replay_exchange.replay.relay_pool.acceptRelayAuthEvent(
            relay_index,
            auth_event,
            now_unix_seconds,
            window_seconds,
        );
        return self.replay_turn.replay_exchange.replay.relay_pool.descriptor(relay_index) orelse {
            return error.InvalidRelayIndex;
        };
    }

    pub fn inspectRelayRuntime(
        self: *const MailboxReplayTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.replay_turn.inspectRelayRuntime(storage);
    }

    pub fn inspectAuth(
        self: *const MailboxReplayTurnClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.replay_turn.replay_exchange.replay.relay_pool.inspectAuth(storage);
    }

    pub fn inspectReplay(
        self: *const MailboxReplayTurnClient,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) MailboxReplayTurnClientError!runtime.RelayPoolReplayPlan {
        return self.replay_turn.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn beginTurn(
        self: *MailboxReplayTurnClient,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) MailboxReplayTurnClientError!MailboxReplayTurnRequest {
        const request = try self.replay_turn.beginTurn(
            &self.storage.replay_turn,
            checkpoint_store,
            output,
            subscription_id,
            specs,
        );
        _ = try self.storage.mailbox.selectRelay(request.replay.relay.relay_index);
        return request;
    }

    pub fn acceptReplayMessageJson(
        self: *MailboxReplayTurnClient,
        request: *const MailboxReplayTurnRequest,
        relay_message_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxReplayTurnClientError!MailboxReplayTurnIntake {
        const replay = try self.replay_turn.acceptReplayMessageJson(
            &self.storage.replay_turn,
            request,
            relay_message_json,
            scratch,
        );

        var envelope: ?workflows.MailboxEnvelopeOutcome = null;
        if (replay.replay.message == .event and
            replay.replay.message.event.event.kind == mailbox_wrap_event_kind)
        {
            envelope = try self.storage.mailbox.acceptWrappedEnvelopeEvent(
                &replay.replay.message.event.event,
                recipients_out,
                thumbs_out,
                fallbacks_out,
                scratch,
            );
        }

        return .{
            .replay = replay,
            .envelope = envelope,
        };
    }

    pub fn completeTurn(
        self: *const MailboxReplayTurnClient,
        output: []u8,
        request: *const MailboxReplayTurnRequest,
    ) MailboxReplayTurnClientError!MailboxReplayTurnResult {
        return self.replay_turn.completeTurn(&self.storage.replay_turn, output, request);
    }

    pub fn saveTurnResult(
        self: *const MailboxReplayTurnClient,
        archive: store.RelayCheckpointArchive,
        result: *const MailboxReplayTurnResult,
    ) MailboxReplayTurnClientError!void {
        return self.replay_turn.saveTurnResult(archive, result);
    }
};

test "mailbox replay turn client exposes caller-owned config and storage" {
    var storage = MailboxReplayTurnClientStorage{};
    var client = MailboxReplayTurnClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
}

test "mailbox replay turn client accepts replay transcript events through mailbox intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var client_storage = MailboxReplayTurnClientStorage{};
    var client = MailboxReplayTurnClient.init(.{
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
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 7 });

    var sender_session = workflows.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = workflows.MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "mailbox replay turn payload",
            .created_at = 41,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "mailbox",
            .query = .{ .limit = 16 },
        },
    };

    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.beginTurn(
        checkpoint_store,
        request_output[0..],
        "mailbox-feed",
        replay_specs[0..],
    );

    const wrap_event = try noztr.nip01_event.event_parse_json(
        outbound.wrap_event_json,
        arena.allocator(),
    );
    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "mailbox-feed", .event = wrap_event } },
    );

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const event_intake = try client.acceptReplayMessageJson(
        &request,
        event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(event_intake.replay.replay.message == .event);
    try std.testing.expect(event_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox replay turn payload",
        event_intake.envelope.?.direct_message.message.content,
    );
    try std.testing.expect(event_intake.replay.checkpoint_candidate == null);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    const eose_intake = try client.acceptReplayMessageJson(
        &request,
        eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(eose_intake.envelope == null);
    try std.testing.expect(eose_intake.replay.checkpoint_candidate != null);

    const result = try client.completeTurn(request_output[0..], &request);
    try std.testing.expectEqual(@as(u32, 8), result.checkpoint_candidate.cursor.offset);
    try client.saveTurnResult(checkpoint_archive, &result);
}

fn buildRelayListEventJson(
    output: []u8,
    relay_text: []const u8,
    created_at: u64,
    signer_secret_key: *const [32]u8,
) ![]const u8 {
    const relay_list_author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(signer_secret_key);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", relay_text } },
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = relay_list_author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .tags = tags[0..],
        .content = "",
    };
    try noztr.nostr_keys.nostr_sign_event(signer_secret_key, &event);
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
