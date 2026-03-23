const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const signer_client = @import("signer_client.zig");
const signer_job_support = @import("signer_job_support.zig");
const signer_runtime_support = @import("signer_runtime_support.zig");
const workflows = @import("../workflows/mod.zig");
const runtime = @import("../runtime/mod.zig");
const relay_url = @import("../relay/url.zig");
const noztr = @import("noztr");

pub const MailboxSignerJobClientError =
    signer_client.SignerClientError ||
    signer_job_support.SignerJobAuthError ||
    workflows.dm.mailbox.MailboxError ||
    noztr.nip01_event.EventSerializeError ||
    error{
        PendingDirectMessageResponse,
        UnexpectedSignerOutcome,
        MissingAuthorPubkey,
        InvalidReplyTag,
        InvalidSignedSealEvent,
        InvalidSignedWrapRecipientTag,
        InvalidSignedWrapAuthor,
    };

pub const MailboxSignerJobClientConfig = struct {
    signer: signer_client.SignerClientConfig = .{},
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

const DirectMessageStage = enum {
    idle,
    waiting_get_public_key,
    waiting_encrypt_rumor,
    need_sign_seal,
    waiting_sign_seal,
    need_encrypt_seal,
    waiting_encrypt_seal,
    need_sign_wrap,
    waiting_sign_wrap,
};

pub const MailboxSignerJobAuthEventStorage = signer_job_support.SignerJobAuthEventStorage;
pub const PreparedMailboxSignerJobAuthEvent = signer_job_support.PreparedSignerJobAuthEvent;

pub const MailboxSignerJobReady = union(enum) {
    authenticate: PreparedMailboxSignerJobAuthEvent,
    get_public_key: workflows.signer.remote.OutboundRequest,
    encrypt_rumor: workflows.signer.remote.OutboundRequest,
    sign_seal: workflows.signer.remote.OutboundRequest,
    encrypt_seal: workflows.signer.remote.OutboundRequest,
    sign_wrap: workflows.signer.remote.OutboundRequest,
};

pub const MailboxSignerDirectMessageRequest = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    reply_to: ?noztr.nip17_private_messages.DmReplyRef = null,
    recipient_relay_list_event_json: []const u8,
    sender_relay_list_event_json: ?[]const u8 = null,
    content: []const u8,
    created_at: u64,
    seal_nonce: [32]u8,
    wrap_nonce: [32]u8,
};

pub const MailboxSignerDirectMessageProgress = enum {
    got_public_key,
    encrypted_rumor,
    signed_seal,
    encrypted_seal,
};

pub const PreparedMailboxSignerDirectMessage = struct {
    wrap_event: noztr.nip01_event.Event,
    wrap_event_json: []const u8,
    delivery: workflows.dm.mailbox.MailboxDeliveryPlan,
};

pub const MailboxSignerDirectMessageResult = union(enum) {
    progressed: MailboxSignerDirectMessageProgress,
    ready: PreparedMailboxSignerDirectMessage,
};

const DirectMessageAuthoringStorage = struct {
    stage: DirectMessageStage = .idle,
    author_pubkey_known: bool = false,
    author_pubkey: [32]u8 = [_]u8{0} ** 32,
    seal_payload_storage: [noztr.limits.nip44_payload_base64_max_bytes]u8 =
        [_]u8{0} ** noztr.limits.nip44_payload_base64_max_bytes,
    seal_payload_len: u16 = 0,
    seal_json_storage: [noztr.limits.event_json_max]u8 = [_]u8{0} ** noztr.limits.event_json_max,
    seal_json_len: u16 = 0,
    wrap_payload_storage: [noztr.limits.nip44_payload_base64_max_bytes]u8 =
        [_]u8{0} ** noztr.limits.nip44_payload_base64_max_bytes,
    wrap_payload_len: u16 = 0,
    request_json_storage: [noztr.limits.event_json_max]u8 = [_]u8{0} ** noztr.limits.event_json_max,

    fn reset(self: *DirectMessageAuthoringStorage) void {
        const known_pubkey = self.author_pubkey_known;
        const author_pubkey = self.author_pubkey;
        self.* = .{};
        self.author_pubkey_known = known_pubkey;
        self.author_pubkey = author_pubkey;
    }

    fn rememberAuthorPubkey(self: *DirectMessageAuthoringStorage, pubkey: [32]u8) void {
        self.author_pubkey = pubkey;
        self.author_pubkey_known = true;
    }

    fn authorPubkey(self: *const DirectMessageAuthoringStorage) ?[32]u8 {
        if (!self.author_pubkey_known) return null;
        return self.author_pubkey;
    }

    fn requestJsonBuffer(self: *DirectMessageAuthoringStorage) []u8 {
        return self.request_json_storage[0..];
    }

    fn rememberSealPayload(
        self: *DirectMessageAuthoringStorage,
        payload: []const u8,
    ) MailboxSignerJobClientError!void {
        if (payload.len > self.seal_payload_storage.len) return error.BufferTooSmall;
        @memset(self.seal_payload_storage[0..], 0);
        @memcpy(self.seal_payload_storage[0..payload.len], payload);
        self.seal_payload_len = @intCast(payload.len);
    }

    fn sealPayload(self: *const DirectMessageAuthoringStorage) []const u8 {
        return self.seal_payload_storage[0..self.seal_payload_len];
    }

    fn rememberSealJson(
        self: *DirectMessageAuthoringStorage,
        json: []const u8,
    ) MailboxSignerJobClientError!void {
        if (json.len > self.seal_json_storage.len) return error.BufferTooSmall;
        @memset(self.seal_json_storage[0..], 0);
        @memcpy(self.seal_json_storage[0..json.len], json);
        self.seal_json_len = @intCast(json.len);
    }

    fn sealJson(self: *const DirectMessageAuthoringStorage) []const u8 {
        return self.seal_json_storage[0..self.seal_json_len];
    }

    fn rememberWrapPayload(
        self: *DirectMessageAuthoringStorage,
        payload: []const u8,
    ) MailboxSignerJobClientError!void {
        if (payload.len > self.wrap_payload_storage.len) return error.BufferTooSmall;
        @memset(self.wrap_payload_storage[0..], 0);
        @memcpy(self.wrap_payload_storage[0..payload.len], payload);
        self.wrap_payload_len = @intCast(payload.len);
    }

    fn wrapPayload(self: *const DirectMessageAuthoringStorage) []const u8 {
        return self.wrap_payload_storage[0..self.wrap_payload_len];
    }
};

pub const MailboxSignerJobClientStorage = struct {
    signer: signer_client.SignerClientStorage = .{},
    auth_state: signer_job_support.SignerJobAuthState = .{},
    direct_message: DirectMessageAuthoringStorage = .{},
};

pub const MailboxSignerJobClient = struct {
    config: MailboxSignerJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    signer: signer_client.SignerClient,

    pub fn init(
        config: MailboxSignerJobClientConfig,
        signer: signer_client.SignerClient,
        storage: *MailboxSignerJobClientStorage,
    ) MailboxSignerJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn initFromBunkerUriText(
        config: MailboxSignerJobClientConfig,
        storage: *MailboxSignerJobClientStorage,
        uri_text: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxSignerJobClientError!MailboxSignerJobClient {
        return .init(
            config,
            try signer_client.SignerClient.initFromBunkerUriText(config.signer, uri_text, scratch),
            storage,
        );
    }

    pub fn attach(
        config: MailboxSignerJobClientConfig,
        signer: signer_client.SignerClient,
        storage: *MailboxSignerJobClientStorage,
    ) MailboxSignerJobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn currentRelayUrl(self: *const MailboxSignerJobClient) []const u8 {
        return self.signer.currentRelayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const MailboxSignerJobClient) bool {
        return self.signer.currentRelayCanSendRequests();
    }

    pub fn isConnected(self: *const MailboxSignerJobClient) bool {
        return self.signer.isConnected();
    }

    pub fn lastSignerError(self: *const MailboxSignerJobClient) ?[]const u8 {
        return self.signer.lastSignerError();
    }

    pub fn markCurrentRelayConnected(self: *MailboxSignerJobClient) void {
        self.signer.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
    ) void {
        self.signer.noteCurrentRelayDisconnected();
        storage.auth_state.clear();
        storage.direct_message.reset();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        challenge: []const u8,
    ) MailboxSignerJobClientError!void {
        return signer_runtime_support.noteCurrentRelayAuthChallenge(
            &self.signer,
            &storage.auth_state,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
    ) runtime.RelayPoolPlan {
        return signer_runtime_support.inspectRelayRuntime(&self.signer, &storage.signer);
    }

    pub fn selectRelayRuntimeStep(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        step: *const runtime.RelayPoolStep,
    ) MailboxSignerJobClientError![]const u8 {
        return signer_runtime_support.selectRelayRuntimeStep(
            &self.signer,
            &storage.auth_state,
            step,
        );
    }

    pub fn advanceRelay(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
    ) MailboxSignerJobClientError![]const u8 {
        return signer_runtime_support.advanceRelay(&self.signer, &storage.auth_state);
    }

    pub fn beginConnect(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        scratch: std.mem.Allocator,
        requested_permissions: []const workflows.signer.remote.Permission,
    ) MailboxSignerJobClientError!workflows.signer.remote.OutboundRequest {
        return self.signer.beginConnect(&storage.signer, scratch, requested_permissions);
    }

    pub fn acceptConnectResponseJson(
        self: *MailboxSignerJobClient,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) MailboxSignerJobClientError!void {
        const outcome = try self.signer.acceptResponseJson(response_json, scratch);
        if (outcome != .connected) return error.UnexpectedSignerOutcome;
    }

    pub fn prepareAuthEvent(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        auth_storage: *MailboxSignerJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) MailboxSignerJobClientError!PreparedMailboxSignerJobAuthEvent {
        return signer_job_support.prepareAuthEvent(
            &self.local_operator,
            &storage.auth_state,
            auth_storage,
            event_json_output,
            auth_message_output,
            secret_key,
            created_at,
        );
    }

    pub fn acceptPreparedAuthEvent(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        prepared: *const PreparedMailboxSignerJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) MailboxSignerJobClientError![]const u8 {
        try signer_job_support.requireCurrentAuthState(
            &storage.auth_state,
            self.signer.currentRelayUrl(),
            prepared.challenge,
        );
        try self.signer.acceptCurrentRelayAuthEventJson(
            prepared.event_json,
            now_unix_seconds,
            window_seconds,
            scratch,
        );
        storage.auth_state.clear();
        return prepared.relay_url;
    }

    pub fn prepareDirectMessageJob(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        auth_storage: *MailboxSignerJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        auth_secret_key: *const [local_operator.secret_key_bytes]u8,
        auth_created_at: u64,
        request: *const MailboxSignerDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxSignerJobClientError!MailboxSignerJobReady {
        if (storage.auth_state.active and !self.signer.currentRelayCanSendRequests()) {
            return .{
                .authenticate = try self.prepareAuthEvent(
                    storage,
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    auth_secret_key,
                    auth_created_at,
                ),
            };
        }

        switch (storage.direct_message.stage) {
            .waiting_get_public_key,
            .waiting_encrypt_rumor,
            .waiting_sign_seal,
            .waiting_encrypt_seal,
            .waiting_sign_wrap,
            => return error.PendingDirectMessageResponse,
            .idle => {
                const author_pubkey = self.currentAuthorPubkey(storage);
                if (author_pubkey == null) {
                    storage.direct_message.stage = .waiting_get_public_key;
                    return .{
                        .get_public_key = try self.signer.beginGetPublicKey(
                            &storage.signer,
                            scratch,
                        ),
                    };
                }
                const rumor_json = try buildDirectMessageRumorJson(
                    storage.direct_message.requestJsonBuffer(),
                    author_pubkey.?,
                    request,
                );
                storage.direct_message.stage = .waiting_encrypt_rumor;
                return .{
                    .encrypt_rumor = try self.signer.beginNip44Encrypt(
                        &storage.signer,
                        scratch,
                        &.{
                            .pubkey = request.recipient_pubkey,
                            .text = rumor_json,
                        },
                    ),
                };
            },
            .need_sign_seal => {
                const author_pubkey = self.currentAuthorPubkey(storage) orelse return error.MissingAuthorPubkey;
                const unsigned_seal_json = try buildUnsignedSealJson(
                    storage.direct_message.requestJsonBuffer(),
                    author_pubkey,
                    request.created_at + 1,
                    storage.direct_message.sealPayload(),
                );
                storage.direct_message.stage = .waiting_sign_seal;
                return .{
                    .sign_seal = try self.signer.beginSignEvent(
                        &storage.signer,
                        scratch,
                        unsigned_seal_json,
                    ),
                };
            },
            .need_encrypt_seal => {
                storage.direct_message.stage = .waiting_encrypt_seal;
                return .{
                    .encrypt_seal = try self.signer.beginNip44Encrypt(
                        &storage.signer,
                        scratch,
                        &.{
                            .pubkey = request.recipient_pubkey,
                            .text = storage.direct_message.sealJson(),
                        },
                    ),
                };
            },
            .need_sign_wrap => {
                const author_pubkey = self.currentAuthorPubkey(storage) orelse return error.MissingAuthorPubkey;
                const unsigned_wrap_json = try buildUnsignedWrapJson(
                    storage.direct_message.requestJsonBuffer(),
                    author_pubkey,
                    &request.recipient_pubkey,
                    request.created_at + 2,
                    storage.direct_message.wrapPayload(),
                );
                storage.direct_message.stage = .waiting_sign_wrap;
                return .{
                    .sign_wrap = try self.signer.beginSignEvent(
                        &storage.signer,
                        scratch,
                        unsigned_wrap_json,
                    ),
                };
            },
        }
    }

    pub fn acceptDirectMessageResponseJson(
        self: *MailboxSignerJobClient,
        storage: *MailboxSignerJobClientStorage,
        response_json: []const u8,
        signed_wrap_json_output: []u8,
        delivery_storage: *workflows.dm.mailbox.MailboxDeliveryStorage,
        request: *const MailboxSignerDirectMessageRequest,
        scratch: std.mem.Allocator,
    ) MailboxSignerJobClientError!MailboxSignerDirectMessageResult {
        const outcome = try self.signer.acceptResponseJson(response_json, scratch);
        switch (storage.direct_message.stage) {
            .waiting_get_public_key => {
                if (outcome != .user_pubkey) return error.UnexpectedSignerOutcome;
                storage.direct_message.rememberAuthorPubkey(outcome.user_pubkey);
                storage.direct_message.stage = .idle;
                return .{ .progressed = .got_public_key };
            },
            .waiting_encrypt_rumor => {
                if (outcome != .text_response or outcome.text_response.method != .nip44_encrypt) {
                    return error.UnexpectedSignerOutcome;
                }
                try storage.direct_message.rememberSealPayload(outcome.text_response.text);
                storage.direct_message.stage = .need_sign_seal;
                return .{ .progressed = .encrypted_rumor };
            },
            .waiting_sign_seal => {
                if (outcome != .signed_event_json) return error.UnexpectedSignerOutcome;
                const signed_seal_json = outcome.signed_event_json;
                const seal_event = try self.local_operator.parseEventJson(signed_seal_json, scratch);
                try validateSignedSealEvent(
                    &seal_event,
                    self.currentAuthorPubkey(storage) orelse return error.MissingAuthorPubkey,
                );
                try storage.direct_message.rememberSealJson(signed_seal_json);
                storage.direct_message.stage = .need_encrypt_seal;
                return .{ .progressed = .signed_seal };
            },
            .waiting_encrypt_seal => {
                if (outcome != .text_response or outcome.text_response.method != .nip44_encrypt) {
                    return error.UnexpectedSignerOutcome;
                }
                try storage.direct_message.rememberWrapPayload(outcome.text_response.text);
                storage.direct_message.stage = .need_sign_wrap;
                return .{ .progressed = .encrypted_seal };
            },
            .waiting_sign_wrap => {
                if (outcome != .signed_event_json) return error.UnexpectedSignerOutcome;
                if (outcome.signed_event_json.len > signed_wrap_json_output.len) return error.BufferTooSmall;
                @memcpy(signed_wrap_json_output[0..outcome.signed_event_json.len], outcome.signed_event_json);
                const signed_wrap_json = signed_wrap_json_output[0..outcome.signed_event_json.len];
                const wrap_event = try self.local_operator.parseEventJson(signed_wrap_json, scratch);
                try validateSignedWrapEvent(
                    &wrap_event,
                    self.currentAuthorPubkey(storage) orelse return error.MissingAuthorPubkey,
                    &request.recipient_pubkey,
                );
                const delivery = try buildDeliveryPlan(
                    delivery_storage,
                    request.recipient_relay_list_event_json,
                    request.sender_relay_list_event_json,
                    &request.recipient_pubkey,
                    request.recipient_relay_hint,
                    self.currentAuthorPubkey(storage) orelse return error.MissingAuthorPubkey,
                    wrap_event.id,
                    signed_wrap_json,
                    scratch,
                );
                storage.direct_message.reset();
                return .{
                    .ready = .{
                        .wrap_event = wrap_event,
                        .wrap_event_json = signed_wrap_json,
                        .delivery = delivery,
                    },
                };
            },
            else => return error.PendingDirectMessageResponse,
        }
    }

    fn currentAuthorPubkey(
        self: *const MailboxSignerJobClient,
        storage: *const MailboxSignerJobClientStorage,
    ) ?[32]u8 {
        if (self.signer.getUserPubkey()) |pubkey| return pubkey;
        return storage.direct_message.authorPubkey();
    }
};

fn buildDirectMessageRumorJson(
    output: []u8,
    author_pubkey: [32]u8,
    request: *const MailboxSignerDirectMessageRequest,
) MailboxSignerJobClientError![]const u8 {
    var built_recipient_tag: noztr.nip17_private_messages.BuiltTag = .{};
    var reply_tag_storage: MailboxSignerReplyTagStorage = .{};
    const recipient_hex = std.fmt.bytesToHex(request.recipient_pubkey, .lower);
    const recipient_tag = try noztr.nip17_private_messages.nip17_build_recipient_tag(
        &built_recipient_tag,
        recipient_hex[0..],
        request.recipient_relay_hint,
    );
    var rumor_tags: [2]noztr.nip01_event.EventTag = undefined;
    rumor_tags[0] = recipient_tag;
    var rumor_tag_count: usize = 1;
    if (request.reply_to) |reply_to| {
        rumor_tags[1] = try buildReplyTag(&reply_tag_storage, &reply_to);
        rumor_tag_count = 2;
    }
    var rumor_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_kind,
        .created_at = request.created_at,
        .content = request.content,
        .tags = rumor_tags[0..rumor_tag_count],
    };
    rumor_event.id = try noztr.nip01_event.event_compute_id_checked(&rumor_event);
    return noztr.nip01_event.event_serialize_json_object_unsigned(output, &rumor_event);
}

fn buildUnsignedSealJson(
    output: []u8,
    author_pubkey: [32]u8,
    created_at: u64,
    seal_payload: []const u8,
) MailboxSignerJobClientError![]const u8 {
    const event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 13,
        .created_at = created_at,
        .content = seal_payload,
        .tags = &.{},
    };
    return noztr.nip01_event.event_serialize_json_object(output, &event);
}

fn buildUnsignedWrapJson(
    output: []u8,
    author_pubkey: [32]u8,
    recipient_pubkey: *const [32]u8,
    created_at: u64,
    wrap_payload: []const u8,
) MailboxSignerJobClientError![]const u8 {
    var built_recipient_tag: noztr.nip17_private_messages.BuiltTag = .{};
    const recipient_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    const recipient_tag = try noztr.nip17_private_messages.nip17_build_recipient_tag(
        &built_recipient_tag,
        recipient_hex[0..],
        null,
    );
    const wrap_tags = [_]noztr.nip01_event.EventTag{recipient_tag};
    const event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = author_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 1059,
        .created_at = created_at,
        .content = wrap_payload,
        .tags = wrap_tags[0..],
    };
    return noztr.nip01_event.event_serialize_json_object(output, &event);
}

const MailboxSignerReplyTagStorage = struct {
    event_id_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    relay_hint_storage: [noztr.limits.tag_item_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.tag_item_bytes_max,
    items: [4][]const u8 = undefined,
};

fn buildReplyTag(
    storage: *MailboxSignerReplyTagStorage,
    reply_to: *const noztr.nip17_private_messages.DmReplyRef,
) MailboxSignerJobClientError!noztr.nip01_event.EventTag {
    const event_id_hex = std.fmt.bytesToHex(reply_to.event_id, .lower);
    @memcpy(storage.event_id_hex[0..], event_id_hex[0..]);
    storage.items[0] = "e";
    storage.items[1] = storage.event_id_hex[0..];
    storage.items[2] = if (reply_to.relay_hint) |relay_hint| blk: {
        try relay_url.relayUrlValidate(relay_hint);
        if (relay_hint.len > storage.relay_hint_storage.len) return error.InvalidReplyTag;
        @memcpy(storage.relay_hint_storage[0..relay_hint.len], relay_hint);
        break :blk storage.relay_hint_storage[0..relay_hint.len];
    } else "";
    storage.items[3] = "reply";
    return .{ .items = storage.items[0..4] };
}

fn validateSignedSealEvent(
    event: *const noztr.nip01_event.Event,
    expected_author: [32]u8,
) MailboxSignerJobClientError!void {
    try noztr.nip01_event.event_verify(event);
    if (event.kind != 13) return error.InvalidSignedSealEvent;
    if (event.tags.len != 0) return error.InvalidSignedSealEvent;
    if (!std.mem.eql(u8, &event.pubkey, &expected_author)) return error.InvalidSignedSealEvent;
}

fn validateSignedWrapEvent(
    event: *const noztr.nip01_event.Event,
    expected_author: [32]u8,
    recipient_pubkey: *const [32]u8,
) MailboxSignerJobClientError!void {
    try noztr.nip59_wrap.nip59_validate_wrap_structure(event);
    if (!std.mem.eql(u8, &event.pubkey, &expected_author)) return error.InvalidSignedWrapAuthor;
    if (!wrapTargetsRecipient(event, recipient_pubkey)) return error.InvalidSignedWrapRecipientTag;
}

fn wrapTargetsRecipient(
    event: *const noztr.nip01_event.Event,
    recipient_pubkey: *const [32]u8,
) bool {
    const recipient_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    for (event.tags) |tag| {
        if (tag.items.len < 2) continue;
        if (!std.mem.eql(u8, tag.items[0], "p")) continue;
        if (std.mem.eql(u8, tag.items[1], recipient_hex[0..])) return true;
    }
    return false;
}

fn buildDeliveryPlan(
    delivery_storage: *workflows.dm.mailbox.MailboxDeliveryStorage,
    recipient_relay_list_event_json: []const u8,
    sender_relay_list_event_json: ?[]const u8,
    recipient_pubkey: *const [32]u8,
    recipient_relay_hint: ?[]const u8,
    author_pubkey: [32]u8,
    wrap_event_id: [32]u8,
    wrap_event_json: []const u8,
    scratch: std.mem.Allocator,
) MailboxSignerJobClientError!workflows.dm.mailbox.MailboxDeliveryPlan {
    const relay_list_event = try noztr.nip01_event.event_parse_json(
        recipient_relay_list_event_json,
        scratch,
    );
    try noztr.nip01_event.event_verify(&relay_list_event);
    if (!std.mem.eql(u8, &relay_list_event.pubkey, recipient_pubkey)) {
        return error.RelayListRecipientMismatch;
    }

    var extracted_relays: [runtime.pool_capacity][]const u8 = undefined;
    const extracted_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
        &relay_list_event,
        extracted_relays[0..],
    );
    delivery_storage.relay_url_lens = [_]u16{0} ** runtime.pool_capacity;
    delivery_storage.recipient_targets = [_]bool{false} ** runtime.pool_capacity;
    delivery_storage.sender_copy_targets = [_]bool{false} ** runtime.pool_capacity;

    if (recipient_relay_hint) |hint| {
        if (relayListContainsEquivalent(extracted_relays[0..extracted_count], hint)) {
            const hint_index = try rememberPublishRelay(delivery_storage, hint);
            delivery_storage.recipient_targets[hint_index] = true;
        }
    }

    var index: u16 = 0;
    while (index < extracted_count) : (index += 1) {
        const relay_index = try rememberPublishRelay(delivery_storage, extracted_relays[index]);
        delivery_storage.recipient_targets[relay_index] = true;
    }

    if (sender_relay_list_event_json) |sender_relay_list_json| {
        const sender_relay_list_event = try noztr.nip01_event.event_parse_json(
            sender_relay_list_json,
            scratch,
        );
        try noztr.nip01_event.event_verify(&sender_relay_list_event);
        if (!std.mem.eql(u8, &sender_relay_list_event.pubkey, &author_pubkey)) {
            return error.SenderRelayListAuthorMismatch;
        }

        var sender_relays: [runtime.pool_capacity][]const u8 = undefined;
        const sender_relay_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
            &sender_relay_list_event,
            sender_relays[0..],
        );
        var sender_index: u16 = 0;
        while (sender_index < sender_relay_count) : (sender_index += 1) {
            const relay_index = try rememberPublishRelay(delivery_storage, sender_relays[sender_index]);
            delivery_storage.sender_copy_targets[relay_index] = true;
        }
    }

    var relay_count: u8 = 0;
    while (relay_count < runtime.pool_capacity and delivery_storage.relay_url_lens[relay_count] != 0) {
        relay_count += 1;
    }

    return .{
        .wrap_event_id = wrap_event_id,
        .wrap_event_json = wrap_event_json,
        .relay_count = relay_count,
        ._storage = delivery_storage,
    };
}

fn relayListContainsEquivalent(relays: []const []const u8, candidate: []const u8) bool {
    for (relays) |relay| {
        if (relay_url.relayUrlsEquivalent(relay, candidate)) return true;
    }
    return false;
}

fn rememberPublishRelay(
    storage: *workflows.dm.mailbox.MailboxDeliveryStorage,
    relay: []const u8,
) MailboxSignerJobClientError!u8 {
    var used: u8 = 0;
    while (used < runtime.pool_capacity and storage.relay_url_lens[used] != 0) : (used += 1) {
        const existing = storage.relay_urls[used][0..storage.relay_url_lens[used]];
        if (relay_url.relayUrlsEquivalent(existing, relay)) return used;
    }
    if (used == runtime.pool_capacity) return error.PoolFull;
    if (relay.len > relay_url.relay_url_max_bytes) return error.RelayUrlTooLong;

    @memset(storage.relay_urls[used][0..], 0);
    std.mem.copyForwards(u8, storage.relay_urls[used][0..relay.len], relay);
    storage.relay_url_lens[used] = @intCast(relay.len);
    return used;
}

test "mailbox signer job client drives signer-backed mailbox direct-message authoring to a delivery plan" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = MailboxSignerJobClientStorage{};
    var client = try MailboxSignerJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    client.markCurrentRelayConnected();

    var connect_scratch_bytes: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_bytes);
    _ = try client.beginConnect(&storage, connect_scratch.allocator(), &.{});

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var connect_response_scratch_bytes: [2048]u8 = undefined;
    var connect_response_scratch = std.heap.FixedBufferAllocator.init(&connect_response_scratch_bytes);
    try client.acceptConnectResponseJson(
        try serializeResponseJson(connect_response_json[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = "secret" } },
        }),
        connect_response_scratch.allocator(),
    );

    const author_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    const author_pubkey_hex = std.fmt.bytesToHex(author_pubkey, .lower);
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);
    var recipient_relay_list_json_storage: [2048]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_json_storage[0..],
        &recipient_secret,
        &.{"wss://relay.recipient","wss://relay.shared"},
        100,
    );
    var sender_relay_list_json_storage: [2048]u8 = undefined;
    const sender_relay_list_json = try buildRelayListEventJson(
        sender_relay_list_json_storage[0..],
        &author_secret,
        &.{"wss://relay.shared","wss://relay.sender"},
        101,
    );

    const request = MailboxSignerDirectMessageRequest{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_hint = "wss://relay.shared",
        .reply_to = .{
            .event_id = [_]u8{0x77} ** 32,
            .relay_hint = "wss://thread.example",
        },
        .recipient_relay_list_event_json = recipient_relay_list_json,
        .sender_relay_list_event_json = sender_relay_list_json,
        .content = "hello signer mailbox",
        .created_at = 500,
        .seal_nonce = [_]u8{0x33} ** 32,
        .wrap_nonce = [_]u8{0x44} ** 32,
    };

    var auth_storage = MailboxSignerJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;

    const first_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(first_ready == .get_public_key);

    var pubkey_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var noop_delivery_storage = workflows.dm.mailbox.MailboxDeliveryStorage{};
    const pubkey_result = try client.acceptDirectMessageResponseJson(
        &storage,
        try textResponse(pubkey_response_json[0..], "signer-2", author_pubkey_hex[0..]),
        auth_message_output[0..],
        &noop_delivery_storage,
        &request,
        arena.allocator(),
    );
    try std.testing.expectEqual(.got_public_key, pubkey_result.progressed);

    const second_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(second_ready == .encrypt_rumor);

    var seal_payload_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const encrypt_rumor_result = try client.acceptDirectMessageResponseJson(
        &storage,
        try textResponse(seal_payload_response_json[0..], "signer-3", "seal-payload"),
        auth_message_output[0..],
        &noop_delivery_storage,
        &request,
        arena.allocator(),
    );
    try std.testing.expectEqual(.encrypted_rumor, encrypt_rumor_result.progressed);

    const third_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(third_ready == .sign_seal);

    var signed_seal_json_storage: [noztr.limits.event_json_max]u8 = undefined;
    const signed_seal_json = try buildSignedEventJson(
        signed_seal_json_storage[0..],
        &author_secret,
        13,
        501,
        "seal-payload",
        &.{},
    );
    var sign_seal_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const sign_seal_result = try client.acceptDirectMessageResponseJson(
        &storage,
        try textResponse(sign_seal_response_json[0..], "signer-4", signed_seal_json),
        auth_message_output[0..],
        &noop_delivery_storage,
        &request,
        arena.allocator(),
    );
    try std.testing.expectEqual(.signed_seal, sign_seal_result.progressed);

    const fourth_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(fourth_ready == .encrypt_seal);

    var wrap_payload_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const encrypt_seal_result = try client.acceptDirectMessageResponseJson(
        &storage,
        try textResponse(wrap_payload_response_json[0..], "signer-5", "wrap-payload"),
        auth_message_output[0..],
        &noop_delivery_storage,
        &request,
        arena.allocator(),
    );
    try std.testing.expectEqual(.encrypted_seal, encrypt_seal_result.progressed);

    const fifth_ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        600,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(fifth_ready == .sign_wrap);

    const recipient_pubkey_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    var wrap_tag_items = [_][]const u8{ "p", recipient_pubkey_hex[0..] };
    const wrap_tags = [_]noztr.nip01_event.EventTag{.{ .items = wrap_tag_items[0..] }};
    var signed_wrap_json_storage: [noztr.limits.event_json_max]u8 = undefined;
    const signed_wrap_json = try buildSignedEventJson(
        signed_wrap_json_storage[0..],
        &author_secret,
        1059,
        502,
        "wrap-payload",
        wrap_tags[0..],
    );
    var sign_wrap_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var final_wrap_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var delivery_storage = workflows.dm.mailbox.MailboxDeliveryStorage{};
    const final_result = try client.acceptDirectMessageResponseJson(
        &storage,
        try textResponse(sign_wrap_response_json[0..], "signer-6", signed_wrap_json),
        final_wrap_json_output[0..],
        &delivery_storage,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(final_result == .ready);
    try std.testing.expectEqualStrings("wrap-payload", final_result.ready.wrap_event.content);
    try std.testing.expectEqual(@as(u8, 3), final_result.ready.delivery.relay_count);
    try std.testing.expectEqualStrings("wss://relay.shared", final_result.ready.delivery.nextStep().?.relay_url);
    try std.testing.expect(final_result.ready.delivery.deliversToRecipient(0));
    try std.testing.expect(final_result.ready.delivery.deliversSenderCopy(0));
    try std.testing.expect(final_result.ready.delivery.deliversToRecipient(1));
    try std.testing.expect(final_result.ready.delivery.deliversSenderCopy(2));
}

test "mailbox signer job rumor builder keeps reply refs in the rumor event shape" {
    const author_secret = [_]u8{0x11} ** 32;
    const author_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&author_secret);
    const recipient_pubkey = [_]u8{0x22} ** 32;
    const reply_event_id = [_]u8{0x77} ** 32;

    var rumor_json_storage: [noztr.limits.event_json_max]u8 = undefined;
    const rumor_json = try buildDirectMessageRumorJson(rumor_json_storage[0..], author_pubkey, &.{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_hint = "wss://relay.shared",
        .reply_to = .{
            .event_id = reply_event_id,
            .relay_hint = "wss://thread.example",
        },
        .recipient_relay_list_event_json = "unused",
        .content = "hello",
        .created_at = 100,
        .seal_nonce = [_]u8{0x33} ** 32,
        .wrap_nonce = [_]u8{0x44} ** 32,
    });

    try std.testing.expect(std.mem.indexOf(u8, rumor_json, "\"kind\":14") != null);
    try std.testing.expect(std.mem.indexOf(u8, rumor_json, "thread.example") != null);
    try std.testing.expect(std.mem.indexOf(u8, rumor_json, "\"reply\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rumor_json, "7777777777777777777777777777777777777777777777777777777777777777") != null);
}

test "mailbox signer job client prefers auth event over direct-message step when relay challenge is active" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    const author_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage = MailboxSignerJobClientStorage{};
    var client = try MailboxSignerJobClient.initFromBunkerUriText(.{}, &storage, bunker_uri, arena.allocator());
    client.markCurrentRelayConnected();

    var connect_scratch_bytes: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_bytes);
    _ = try client.beginConnect(&storage, connect_scratch.allocator(), &.{});

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var connect_response_scratch_bytes: [2048]u8 = undefined;
    var connect_response_scratch = std.heap.FixedBufferAllocator.init(&connect_response_scratch_bytes);
    try client.acceptConnectResponseJson(
        try serializeResponseJson(connect_response_json[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = "secret" } },
        }),
        connect_response_scratch.allocator(),
    );

    try client.noteCurrentRelayAuthChallenge(&storage, "auth-challenge");

    var recipient_relay_list_json_storage: [1024]u8 = undefined;
    const recipient_relay_list_json = try buildRelayListEventJson(
        recipient_relay_list_json_storage[0..],
        &recipient_secret,
        &.{"wss://relay.recipient"},
        100,
    );
    const request = MailboxSignerDirectMessageRequest{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_list_event_json = recipient_relay_list_json,
        .content = "hello auth",
        .created_at = 500,
        .seal_nonce = [_]u8{0x33} ** 32,
        .wrap_nonce = [_]u8{0x44} ** 32,
    };

    var auth_storage = MailboxSignerJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareDirectMessageJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        &author_secret,
        700,
        &request,
        arena.allocator(),
    );
    try std.testing.expect(ready == .authenticate);
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) workflows.signer.remote.Error![]const u8 {
    return serializeResponseJson(output, .{
        .id = id,
        .result = .{ .value = .{ .text = text } },
    });
}

fn serializeResponseJson(
    output: []u8,
    response: noztr.nip46_remote_signing.Response,
) workflows.signer.remote.Error![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(output, .{ .response = response });
}

fn buildRelayListEventJson(
    output: []u8,
    secret_key: *const [32]u8,
    relays: []const []const u8,
    created_at: u64,
) MailboxSignerJobClientError![]const u8 {
    var operator = local_operator.LocalOperatorClient.init(.{});
    const public_key = try operator.derivePublicKey(secret_key);
    var built_tags: [8]noztr.nip17_private_messages.BuiltTag = undefined;
    var tags: [8]noztr.nip01_event.EventTag = undefined;
    var count: usize = 0;
    while (count < relays.len) : (count += 1) {
        tags[count] = try noztr.nip17_private_messages.nip17_build_relay_tag(&built_tags[count], relays[count]);
    }
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip17_private_messages.dm_relays_kind,
        .created_at = created_at,
        .content = "",
        .tags = tags[0..relays.len],
    };
    try operator.signEvent(secret_key, &event);
    return operator.serializeEventJson(output, &event);
}

fn buildSignedEventJson(
    output: []u8,
    secret_key: *const [32]u8,
    kind: u32,
    created_at: u64,
    content: []const u8,
    tags: []const noztr.nip01_event.EventTag,
) MailboxSignerJobClientError![]const u8 {
    var operator = local_operator.LocalOperatorClient.init(.{});
    const draft = local_operator.LocalEventDraft{
        .kind = kind,
        .created_at = created_at,
        .content = content,
        .tags = tags,
    };
    var event = try operator.signDraft(secret_key, &draft);
    return operator.serializeEventJson(output, &event);
}
