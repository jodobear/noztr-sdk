const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const workflows = @import("../workflows/mod.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const MailboxJobClientError =
    workflows.dm.mailbox.MailboxError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        StaleAuthStep,
        RelayNotReady,
    };

pub const MailboxJobClientConfig = struct {
    recipient_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const MailboxJobClientStorage = struct {
    session: workflows.dm.mailbox.MailboxSession = undefined,
    sync: workflows.dm.mailbox.MailboxSyncTurnStorage = .{},
};

pub const MailboxJobAuthEventStorage = relay_auth.RelayAuthEventStorage;

pub const PreparedMailboxJobAuthEvent = struct {
    relay_index: u8,
    relay_url: []const u8,
    challenge: []const u8,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    auth_message_json: []const u8,
};

pub const MailboxJobReady = union(enum) {
    connect: workflows.dm.mailbox.MailboxWorkflowEntry,
    authenticate: PreparedMailboxJobAuthEvent,
    publish: workflows.dm.mailbox.MailboxDeliveryStep,
    receive: workflows.dm.mailbox.MailboxReceiveTurnRequest,
};

pub const MailboxJobResult = union(enum) {
    authenticated: workflows.dm.mailbox.MailboxWorkflowEntry,
    received: workflows.dm.mailbox.MailboxReceiveTurnResult,
};

pub const MailboxJobClient = struct {
    config: MailboxJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    storage: *MailboxJobClientStorage,

    pub fn init(
        config: MailboxJobClientConfig,
        storage: *MailboxJobClientStorage,
    ) MailboxJobClient {
        storage.* = .{
            .session = workflows.dm.mailbox.MailboxSession.init(&config.recipient_private_key),
        };
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .storage = storage,
        };
    }

    pub fn attach(
        config: MailboxJobClientConfig,
        storage: *MailboxJobClientStorage,
    ) MailboxJobClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .storage = storage,
        };
    }

    pub fn relayCount(self: *const MailboxJobClient) u8 {
        return self.storage.session.relayCount();
    }

    pub fn currentRelayUrl(self: *const MailboxJobClient) ?[]const u8 {
        return self.storage.session.currentRelayUrl();
    }

    pub fn currentRelayCanReceive(self: *const MailboxJobClient) bool {
        return self.storage.session.currentRelayCanReceive();
    }

    pub fn hydrateRelayListEventJson(
        self: *MailboxJobClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxJobClientError!u8 {
        return self.storage.session.hydrateRelayListEventJson(event_json, scratch);
    }

    pub fn markCurrentRelayConnected(self: *MailboxJobClient) MailboxJobClientError!void {
        return self.storage.session.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(self: *MailboxJobClient) MailboxJobClientError!void {
        return self.storage.session.noteCurrentRelayDisconnected();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *MailboxJobClient,
        challenge: []const u8,
    ) MailboxJobClientError!void {
        return self.storage.session.noteCurrentRelayAuthChallenge(challenge);
    }

    pub fn selectRelay(
        self: *MailboxJobClient,
        relay_index: u8,
    ) MailboxJobClientError![]const u8 {
        return self.storage.session.selectRelay(relay_index);
    }

    pub fn inspectRelayPoolRuntime(
        self: *const MailboxJobClient,
        storage: *workflows.dm.mailbox.MailboxRelayPoolRuntimeStorage,
    ) runtime.RelayPoolPlan {
        return self.storage.session.inspectRelayPoolRuntime(storage);
    }

    pub fn inspectRuntime(
        self: *const MailboxJobClient,
        storage: *workflows.dm.mailbox.MailboxRuntimeStorage,
    ) MailboxJobClientError!workflows.dm.mailbox.MailboxRuntimePlan {
        return self.storage.session.inspectRuntime(storage);
    }

    pub fn inspectWorkflow(
        self: *const MailboxJobClient,
        request: workflows.dm.mailbox.MailboxWorkflowRequest,
    ) MailboxJobClientError!workflows.dm.mailbox.MailboxWorkflowPlan {
        return self.storage.session.inspectWorkflow(request);
    }

    pub fn beginDirectMessage(
        self: *MailboxJobClient,
        buffer: *workflows.dm.mailbox.MailboxOutboundBuffer,
        request: *const workflows.dm.mailbox.MailboxDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxJobClientError!workflows.dm.mailbox.MailboxOutboundMessage {
        return self.storage.session.beginDirectMessage(buffer, request, scratch);
    }

    pub fn planDirectMessageDelivery(
        self: *MailboxJobClient,
        buffer: *workflows.dm.mailbox.MailboxOutboundBuffer,
        delivery_storage: *workflows.dm.mailbox.MailboxDeliveryStorage,
        recipient_relay_list_event_json: []const u8,
        sender_relay_list_event_json: ?[]const u8,
        request: *const workflows.dm.mailbox.MailboxDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxJobClientError!workflows.dm.mailbox.MailboxDeliveryPlan {
        return self.storage.session.planDirectMessageDelivery(
            buffer,
            delivery_storage,
            recipient_relay_list_event_json,
            sender_relay_list_event_json,
            request,
            scratch,
        );
    }

    pub fn prepareJob(
        self: *MailboxJobClient,
        auth_storage: *MailboxJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        pending_delivery: ?*const workflows.dm.mailbox.MailboxDeliveryPlan,
        created_at: u64,
    ) MailboxJobClientError!MailboxJobReady {
        const sync_request = try self.storage.session.beginSyncTurn(.{
            .pending_delivery = pending_delivery,
            .storage = &self.storage.sync.workflow,
        });
        return switch (sync_request) {
            .connect => |entry| .{ .connect = entry },
            .publish => |step| .{ .publish = step },
            .receive => |receive| .{ .receive = receive },
            .authenticate => |entry| .{
                .authenticate = try self.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &entry,
                    created_at,
                ),
            },
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *MailboxJobClient,
        prepared: *const PreparedMailboxJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) MailboxJobClientError!MailboxJobResult {
        const current_relay_url = self.storage.session.currentRelayUrl() orelse return error.StaleAuthStep;
        if (!std.mem.eql(u8, current_relay_url, prepared.relay_url)) return error.StaleAuthStep;
        const challenge = self.storage.session.currentRelayAuthChallenge() orelse return error.RelayNotReady;
        if (!std.mem.eql(u8, challenge, prepared.challenge)) return error.StaleAuthStep;

        try self.storage.session.acceptCurrentRelayAuthEvent(
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{
            .authenticated = .{
                .relay_index = prepared.relay_index,
                .relay_url = prepared.relay_url,
                .action = .authenticate,
                .is_current = true,
            },
        };
    }

    pub fn acceptReceiveEnvelopeJson(
        self: *MailboxJobClient,
        request: *const workflows.dm.mailbox.MailboxReceiveTurnRequest,
        wrap_event_json: []const u8,
        recipients_out: []noztr.nip17_private_messages.DmRecipient,
        thumbs_out: [][]const u8,
        fallbacks_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) MailboxJobClientError!MailboxJobResult {
        const result = try self.storage.session.acceptReceiveEnvelopeJson(
            request,
            wrap_event_json,
            recipients_out,
            thumbs_out,
            fallbacks_out,
            scratch,
        );
        return .{ .received = result };
    }

    fn prepareAuthEvent(
        self: *MailboxJobClient,
        auth_storage: *MailboxJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        entry: *const workflows.dm.mailbox.MailboxWorkflowEntry,
        created_at: u64,
    ) MailboxJobClientError!PreparedMailboxJobAuthEvent {
        if (entry.action != .authenticate) return error.RelayNotReady;

        const relay_url_text = self.storage.session.currentRelayUrl() orelse return error.StaleAuthStep;
        if (!std.mem.eql(u8, relay_url_text, entry.relay_url)) return error.StaleAuthStep;
        const challenge = self.storage.session.currentRelayAuthChallenge() orelse return error.RelayNotReady;

        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.local_operator,
            auth_storage,
            event_json_output,
            auth_message_output,
            &self.config.recipient_private_key,
            created_at,
            relay_url_text,
            challenge,
        );
        return .{
            .relay_index = entry.relay_index,
            .relay_url = auth_storage.relayUrl(),
            .challenge = auth_storage.challengeText(),
            .event = payload.event,
            .event_json = payload.event_json,
            .auth_message_json = payload.auth_message_json,
        };
    }
};

test "mailbox job client exposes caller-owned config and storage" {
    var storage = MailboxJobClientStorage{};
    var client = MailboxJobClient.init(.{
        .recipient_private_key = [_]u8{0x33} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relayCount());
}

test "mailbox job client prepares auth and receive work through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage = MailboxJobClientStorage{};
    var client = MailboxJobClient.init(.{
        .recipient_private_key = recipient_secret,
    }, &storage);

    var relay_list_storage: [1024]u8 = undefined;
    const relay_list_json = try buildRelayListEventJson(
        relay_list_storage[0..],
        "wss://relay.one",
        41,
        &client.config.recipient_private_key,
    );
    _ = try client.hydrateRelayListEventJson(relay_list_json, arena.allocator());
    try client.markCurrentRelayConnected();
    try client.noteCurrentRelayAuthChallenge("challenge-1");

    var auth_storage = MailboxJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        null,
        90,
    );
    try std.testing.expect(first_ready == .authenticate);
    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 95, 60);
    try std.testing.expect(auth_result == .authenticated);

    var sender_session = workflows.dm.mailbox.MailboxSession.init(&sender_secret);
    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://sender.one",
        39,
        &sender_secret,
    );
    _ = try sender_session.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try sender_session.markCurrentRelayConnected();
    var outbound_buffer = workflows.dm.mailbox.MailboxOutboundBuffer{};
    const outbound = try sender_session.beginDirectMessage(
        &outbound_buffer,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "job client payload",
            .created_at = 91,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        null,
        90,
    );
    try std.testing.expect(second_ready == .receive);

    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var thumbs: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    const receive_result = try client.acceptReceiveEnvelopeJson(
        &second_ready.receive,
        outbound.wrap_event_json,
        recipients[0..],
        thumbs[0..0],
        fallbacks[0..0],
        arena.allocator(),
    );
    try std.testing.expect(receive_result == .received);
    try std.testing.expectEqualStrings(
        "job client payload",
        receive_result.received.envelope.direct_message.message.content,
    );
}

test "mailbox job client surfaces pending delivery as one publish job" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage = MailboxJobClientStorage{};
    var client = MailboxJobClient.init(.{
        .recipient_private_key = sender_secret,
    }, &storage);

    var sender_relay_list_storage: [1024]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_storage[0..],
        "wss://relay.one",
        40,
        &sender_secret,
    );
    _ = try client.hydrateRelayListEventJson(sender_relay_list_json, arena.allocator());
    try client.markCurrentRelayConnected();

    var recipient_relay_list_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_storage[0..],
        "wss://relay.one",
        41,
        &recipient_secret,
    );
    var outbound_buffer = workflows.dm.mailbox.MailboxOutboundBuffer{};
    var delivery_storage = workflows.dm.mailbox.MailboxDeliveryStorage{};
    const delivery = try client.planDirectMessageDelivery(
        &outbound_buffer,
        &delivery_storage,
        recipient_relay_list_json,
        null,
        &.{
            .recipient_pubkey = recipient_pubkey,
            .recipient_relay_hint = "wss://relay.one",
            .content = "publish job payload",
            .created_at = 42,
            .wrap_signer_private_key = [_]u8{0x22} ** 32,
            .seal_nonce = [_]u8{0x44} ** 32,
            .wrap_nonce = [_]u8{0x55} ** 32,
        },
        arena.allocator(),
    );

    var auth_storage = MailboxJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &delivery,
        90,
    );
    try std.testing.expect(ready == .publish);
    try std.testing.expectEqualStrings("wss://relay.one", ready.publish.relay_url);
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
        .content = "",
        .tags = tags[0..],
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
