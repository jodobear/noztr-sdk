const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const mailbox_replay_turn = @import("mailbox_replay_turn_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const Error =
    mailbox_replay_turn.Error ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoReadyRelay,
        StaleAuthStep,
        RelayNotReady,
    };

pub const Config = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    replay_turn: mailbox_replay_turn.Config = undefined,
};

pub const Storage = struct {
    replay_turn: mailbox_replay_turn.Storage = .{},
};

pub const AuthStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const Request = mailbox_replay_turn.Request;
pub const Intake = mailbox_replay_turn.Intake;

pub const Ready = union(enum) {
    authenticate: PreparedAuthEvent,
    replay: Request,
};

pub const Result = union(enum) {
    authenticated: runtime.RelayDescriptor,
    replayed: mailbox_replay_turn.Result,
};

pub const Client = struct {
    config: Config,
    local_operator: local_operator.LocalOperatorClient,
    replay_turn: mailbox_replay_turn.Client,

    pub fn init(
        config: Config,
        storage: *Storage,
    ) Client {
        storage.* = .{};
        return .{
            .config = configWithReplayTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .replay_turn = mailbox_replay_turn.Client.init(
                configWithReplayTurn(config).replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn attach(
        config: Config,
        storage: *Storage,
    ) Client {
        return .{
            .config = configWithReplayTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .replay_turn = mailbox_replay_turn.Client.attach(
                configWithReplayTurn(config).replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn relayCount(self: *const Client) u8 {
        return self.replay_turn.relayCount();
    }

    pub fn currentRelayUrl(self: *const Client) ?[]const u8 {
        return self.replay_turn.currentRelayUrl();
    }

    pub fn currentRelayAuthChallenge(self: *const Client) ?[]const u8 {
        return self.replay_turn.currentRelayAuthChallenge();
    }

    pub fn hydrateRelayListEventJson(
        self: *Client,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!u8 {
        return self.replay_turn.hydrateRelayListEventJson(event_json, scratch);
    }

    pub fn selectRelay(
        self: *Client,
        relay_index: u8,
    ) Error![]const u8 {
        return self.replay_turn.selectRelay(relay_index);
    }

    pub fn markRelayConnected(
        self: *Client,
        relay_index: u8,
    ) Error!void {
        return relay_lifecycle_support.markRelayConnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *Client,
        relay_index: u8,
    ) Error!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *Client,
        relay_index: u8,
        challenge: []const u8,
    ) Error!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "replay_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const Client,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "replay_turn", storage);
    }

    pub fn prepareJob(
        self: *Client,
        auth_storage: *AuthStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        checkpoint_store: store.ClientCheckpointStore,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
        created_at: u64,
    ) Error!Ready {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const auth_plan = self.replay_turn.inspectAuth(&auth_storage_buf);
        if (auth_plan.nextStep()) |step| {
            return .{
                .authenticate = try self.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &step,
                    created_at,
                ),
            };
        }

        var replay_storage_buf = runtime.RelayPoolReplayStorage{};
        const replay_plan = try self.replay_turn.inspectReplay(
            checkpoint_store,
            specs,
            &replay_storage_buf,
        );
        _ = replay_plan.nextStep() orelse return error.NoReadyRelay;
        return .{
            .replay = try self.replay_turn.beginTurn(
                checkpoint_store,
                request_output,
                subscription_id,
                specs,
            ),
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *Client,
        prepared: *const PreparedAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) Error!Result {
        const descriptor = try self.replay_turn.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = descriptor };
    }

    pub fn acceptReplayMessageJson(
        self: *Client,
        request: *const Request,
        relay_message_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!Intake {
        return self.replay_turn.acceptReplayMessageJson(
            request,
            relay_message_json,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
    }

    pub fn completeReplayJob(
        self: *Client,
        output: []u8,
        request: *const Request,
    ) Error!Result {
        return .{ .replayed = try self.replay_turn.completeTurn(output, request) };
    }

    pub fn saveJobResult(
        self: *Client,
        archive: store.RelayCheckpointArchive,
        result: *const mailbox_replay_turn.Result,
    ) Error!void {
        return self.replay_turn.saveTurnResult(archive, result);
    }

    fn prepareAuthEvent(
        self: *Client,
        auth_storage: *AuthStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) Error!PreparedAuthEvent {
        const target = try self.selectAuthTarget(step);
        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.local_operator,
            auth_storage,
            event_json_output,
            auth_message_output,
            &self.config.recipient_private_key,
            created_at,
            target.relay.relay_url,
            target.challenge,
        );
        return .{
            .relay = target.relay,
            .challenge = auth_storage.challengeText(),
            .event = payload.event,
            .event_json = payload.event_json,
            .auth_message_json = payload.auth_message_json,
        };
    }

    fn selectAuthTarget(
        self: *const Client,
        step: *const runtime.RelayPoolAuthStep,
    ) Error!relay_auth_client.RelayAuthTarget {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const plan = self.replay_turn.inspectAuth(&auth_storage_buf);
        return relay_auth_support.selectAuthTarget(
            &self.replay_turn.replay_turn.replay_exchange.replay.relay_pool,
            plan,
            step,
        );
    }
};

fn configWithReplayTurn(config: Config) Config {
    var updated = config;
    updated.replay_turn = .{
        .recipient_private_key = config.recipient_private_key,
        .replay_turn = config.replay_turn.replay_turn,
    };
    return updated;
}

test "mailbox replay job client exposes caller-owned config and storage" {
    var storage = Storage{};
    var client = Client.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
}

test "mailbox replay job client drives auth-gated mailbox replay and checkpoint save" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage_buf = Storage{};
    var client = Client.init(.{
        .recipient_private_key = recipient_secret,
    }, &storage_buf);

    var relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        relay_list_storage[0..],
        "wss://relay.one",
        40,
        &recipient_secret,
    );
    _ = try client.hydrateRelayListEventJson(recipient_relay_list_json, arena.allocator());
    try client.markRelayConnected(0);
    try client.noteRelayAuthChallenge(0, "challenge-1");
    try checkpoint_archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 7 });

    var sender_session = @import("../workflows/mod.zig").dm.mailbox.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();

    var outbound_buffer = @import("../workflows/mod.zig").dm.mailbox.MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "mailbox replay job payload",
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

    var auth_storage = AuthStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        checkpoint_store,
        "mailbox-feed",
        replay_specs[0..],
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_output[0..],
        checkpoint_store,
        "mailbox-feed",
        replay_specs[0..],
        91,
    );
    try std.testing.expect(second_ready == .replay);

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
        &second_ready.replay,
        event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(event_intake.envelope != null);
    try std.testing.expectEqualStrings(
        "mailbox replay job payload",
        event_intake.envelope.?.direct_message.message.content,
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "mailbox-feed" } },
    );
    _ = try client.acceptReplayMessageJson(
        &second_ready.replay,
        eose_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );

    const result = try client.completeReplayJob(request_output[0..], &second_ready.replay);
    try std.testing.expect(result == .replayed);
    try std.testing.expectEqual(@as(u32, 8), result.replayed.checkpoint_candidate.cursor.offset);
    try client.saveJobResult(checkpoint_archive, &result.replayed);
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
