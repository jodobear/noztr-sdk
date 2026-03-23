const std = @import("std");
const noztr = @import("noztr");
const relay_pool = @import("../relay/pool.zig");
const relay_session = @import("../relay/session.zig");
const shared_runtime = @import("../runtime/mod.zig");

pub const max_pending_requests: u8 = 8;
pub const max_secret_bytes: u16 = noztr.limits.nip46_secret_bytes_max;
pub const max_signer_error_bytes: u16 = 512;

pub const Error =
    noztr.nip46_remote_signing.RemoteSigningError ||
    noztr.nip42_auth.AuthError ||
    noztr.nip01_event.EventParseError ||
    error{
        UnsupportedConnectionUri,
        NoRelays,
        RelayUrlTooLong,
        PoolFull,
        SessionNotIdle,
        InvalidResumeState,
        NotConnected,
        AuthNotRequired,
        RelayDisconnected,
        RelayAuthRequired,
        SignerSessionNotConnected,
        PendingRequestsInFlight,
        PendingTableFull,
        DuplicateRequestId,
        UnknownResponseId,
        InvalidRelayPoolStep,
        UnexpectedMessageType,
        RemoteSignerRejected,
        SignerErrorTooLong,
        SecretMismatch,
        MissingSecretEcho,
    };

pub const Method = noztr.nip46_remote_signing.Method;
pub const PermissionScope = noztr.nip46_remote_signing.Scope;
pub const Permission = noztr.nip46_remote_signing.Permission;
pub const PubkeyTextRequest = noztr.nip46_remote_signing.PubkeyTextParams;

/// Caller-owned storage for serialized request JSON.
/// `OutboundRequest.json` borrows from this buffer until it is overwritten.
pub const RequestBuffer = struct {
    storage: [noztr.limits.nip46_message_json_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.nip46_message_json_bytes_max,

    fn writable(self: *RequestBuffer) []u8 {
        return self.storage[0..];
    }
};

/// Caller-owned request-building context shared across `begin...` entrypoints.
/// Request JSON borrows from `buffer` until it is overwritten.
pub const RequestContext = struct {
    id: []const u8,
    buffer: *RequestBuffer,
    scratch: std.mem.Allocator,

    pub fn init(
        id: []const u8,
        buffer: *RequestBuffer,
        scratch: std.mem.Allocator,
    ) RequestContext {
        return .{
            .id = id,
            .buffer = buffer,
            .scratch = scratch,
        };
    }

    fn writable(self: RequestContext) []u8 {
        return self.buffer.writable();
    }
};

/// Transport-ready request envelope.
/// `json` borrows from the caller-provided `RequestBuffer`.
pub const OutboundRequest = struct {
    relay_url: []const u8,
    remote_signer_pubkey: [32]u8,
    json: []const u8,
};

/// Parsed response result.
/// Borrowed payloads in `signed_event_json` and `text_response.text` come from the
/// `acceptResponseJson(...)` input and parsing scratch. Copy them if the caller needs
/// to retain them after scratch or response input is reused.
pub const TextResponse = struct {
    method: Method,
    text: []const u8,
};

pub const ResponseOutcome = union(enum) {
    connected,
    user_pubkey: [32]u8,
    signed_event_json: []const u8,
    text_response: TextResponse,
    pong,
    relays_switched: u8,
};

pub const RelayPoolStorage = struct {
    relay_pool_storage: shared_runtime.RelayPoolStorage = .{},
};

pub const RelayRuntimeStorage = struct {
    relay_pool_storage: RelayPoolStorage = .{},
    plan_storage: shared_runtime.RelayPoolPlanStorage = .{},
};

pub const ResumeStorage = struct {
    relay_members: shared_runtime.RelayPoolMemberStorage = .{},
};

pub const ResumeState = struct {
    relay_count: u8 = 0,
    current_relay_index: u8 = 0,
    user_pubkey: ?[32]u8 = null,
    _storage: *const ResumeStorage,

    pub fn relayUrl(self: *const ResumeState, index: u8) ?[]const u8 {
        if (index >= self.relay_count) return null;
        return self._storage.relay_members.records[index].relayUrl();
    }
};

pub const PolicyAction = enum {
    connect_relay,
    authenticate_relay,
    connect_signer,
    ready,
};

pub const PolicyStep = struct {
    action: PolicyAction,
    relay: shared_runtime.RelayDescriptor,
};

pub const PolicyPlan = struct {
    action: PolicyAction,
    relay: shared_runtime.RelayDescriptor,

    pub fn nextStep(self: *const PolicyPlan) PolicyStep {
        return .{
            .action = self.action,
            .relay = self.relay,
        };
    }
};

pub const CadenceRequest = struct {
    now_unix_seconds: u64,
    reconnect_not_before_unix_seconds: ?u64 = null,
};

pub const CadenceWaitReason = enum {
    reconnect_backoff,
};

pub const CadenceWait = struct {
    reason: CadenceWaitReason,
    not_before_unix_seconds: u64,
};

pub const CadenceStep = union(enum) {
    wait: CadenceWait,
    policy: PolicyStep,
};

pub const CadencePlan = struct {
    policy: PolicyPlan,
    waiting: ?CadenceWait = null,

    pub fn nextStep(self: *const CadencePlan) CadenceStep {
        if (self.waiting) |waiting| return .{ .wait = waiting };
        return .{ .policy = self.policy.nextStep() };
    }
};

const PendingRequest = struct {
    id: [noztr.limits.nip46_message_id_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.nip46_message_id_bytes_max,
    id_len: u8 = 0,
    method: noztr.nip46_remote_signing.Method = .ping,

    fn idSlice(self: *const PendingRequest) []const u8 {
        return self.id[0..self.id_len];
    }
};

pub const Session = struct {
    const State = struct {
        pool: relay_pool.Pool,
        current_relay_index: u8,
        remote_signer_pubkey: [32]u8,
        expected_secret: [max_secret_bytes]u8 = [_]u8{0} ** max_secret_bytes,
        expected_secret_len: u16 = 0,
        connected: bool = false,
        user_pubkey: ?[32]u8 = null,
        pending: [max_pending_requests]PendingRequest = [_]PendingRequest{.{}} ** max_pending_requests,
        pending_count: u8 = 0,
        last_signer_error: [max_signer_error_bytes]u8 = [_]u8{0} ** max_signer_error_bytes,
        last_signer_error_len: u16 = 0,
    };

    _state: State,

    pub fn initFromBunkerUriText(
        uri_text: []const u8,
        scratch: std.mem.Allocator,
    ) Error!Session {
        const uri = try noztr.nip46_remote_signing.uri_parse(uri_text, scratch);
        return switch (uri) {
            .bunker => |bunker| initFromBunkerUri(&bunker),
            .client => error.UnsupportedConnectionUri,
        };
    }

    fn initFromBunkerUri(
        bunker: *const noztr.nip46_remote_signing.Bunker,
    ) Error!Session {
        if (bunker.relays.len == 0) return error.NoRelays;

        var session = Session{
            ._state = .{
                .pool = relay_pool.Pool.init(),
                .current_relay_index = 0,
                .remote_signer_pubkey = bunker.remote_signer_pubkey,
            },
        };
        if (bunker.secret) |secret| {
            if (secret.len > session._state.expected_secret.len) return error.InvalidSecret;
            @memcpy(session._state.expected_secret[0..secret.len], secret);
            session._state.expected_secret_len = @intCast(secret.len);
        }
        for (bunker.relays) |relay_url| {
            _ = try session._state.pool.addRelay(relay_url);
        }
        return session;
    }

    pub fn currentRelayUrl(self: *const Session) []const u8 {
        const current = self._state.pool.getRelayConst(self._state.current_relay_index) orelse unreachable;
        return current.auth_session.relayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const Session) bool {
        const current = self._state.pool.getRelayConst(self._state.current_relay_index) orelse unreachable;
        return current.canSendRequests();
    }

    pub fn isConnected(self: *const Session) bool {
        return self._state.connected;
    }

    pub fn remoteSignerPubkey(self: *const Session) [32]u8 {
        return self._state.remote_signer_pubkey;
    }

    pub fn getUserPubkey(self: *const Session) ?[32]u8 {
        return self._state.user_pubkey;
    }

    pub fn lastSignerError(self: *const Session) ?[]const u8 {
        if (self._state.last_signer_error_len == 0) return null;
        return self._state.last_signer_error[0..self._state.last_signer_error_len];
    }

    pub fn markCurrentRelayConnected(self: *Session) void {
        self.currentRelaySession().connect();
    }

    pub fn noteCurrentRelayDisconnected(self: *Session) void {
        self.currentRelaySession().disconnect();
        self._state.connected = false;
        self.clearPendingRequests();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *Session,
        challenge: []const u8,
    ) Error!void {
        try self.currentRelaySession().requireAuth(challenge);
    }

    pub fn acceptCurrentRelayAuthEventJson(
        self: *Session,
        auth_event_json: []const u8,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) Error!void {
        const auth_event = try noztr.nip01_event.event_parse_json(auth_event_json, scratch);
        try self.currentRelaySession().acceptAuthEvent(
            &auth_event,
            now_unix_seconds,
            window_seconds,
        );
    }

    pub fn advanceRelay(self: *Session) Error![]const u8 {
        if (self._state.pending_count != 0) return error.PendingRequestsInFlight;
        if (self._state.pool.count == 0) return error.NoRelays;

        self._state.current_relay_index =
            (self._state.current_relay_index + 1) % self._state.pool.count;
        self._state.connected = false;
        return self.currentRelayUrl();
    }

    pub fn exportRelayPool(
        self: *const Session,
        storage: *RelayPoolStorage,
    ) shared_runtime.RelayPool {
        storage.* = .{};
        storage.relay_pool_storage.pool = self._state.pool;
        return shared_runtime.RelayPool.attach(&storage.relay_pool_storage);
    }

    pub fn inspectRelayPoolRuntime(
        self: *const Session,
        storage: *RelayRuntimeStorage,
    ) shared_runtime.RelayPoolPlan {
        var pool = self.exportRelayPool(&storage.relay_pool_storage);
        return pool.inspectRuntime(&storage.plan_storage);
    }

    pub fn exportResumeState(
        self: *const Session,
        storage: *ResumeStorage,
    ) Error!ResumeState {
        var relay_index: u8 = 0;
        while (relay_index < self._state.pool.count) : (relay_index += 1) {
            const relay = self._state.pool.getRelayConst(relay_index) orelse unreachable;
            const relay_url_text = relay.auth_session.relayUrl();
            if (relay_url_text.len > storage.relay_members.records[relay_index].relay_url.len) {
                return error.RelayUrlTooLong;
            }

            storage.relay_members.records[relay_index] = .{
                .relay_url_len = @intCast(relay_url_text.len),
            };
            @memcpy(
                storage.relay_members.records[relay_index].relay_url[0..relay_url_text.len],
                relay_url_text,
            );
        }

        return .{
            .relay_count = self._state.pool.count,
            .current_relay_index = self._state.current_relay_index,
            .user_pubkey = self._state.user_pubkey,
            ._storage = storage,
        };
    }

    pub fn restoreResumeState(
        self: *Session,
        state: *const ResumeState,
    ) Error!void {
        if (!self.isIdleForResume()) return error.SessionNotIdle;
        if (state.relay_count == 0) return error.NoRelays;
        if (state.current_relay_index >= state.relay_count) return error.InvalidResumeState;

        var next_pool = relay_pool.Pool.init();
        var relay_index: u8 = 0;
        while (relay_index < state.relay_count) : (relay_index += 1) {
            const relay_url = state.relayUrl(relay_index) orelse return error.InvalidResumeState;
            _ = try next_pool.addRelay(relay_url);
        }

        self._state.pool = next_pool;
        self._state.current_relay_index = state.current_relay_index;
        self._state.connected = false;
        self._state.user_pubkey = state.user_pubkey;
        self.clearPendingRequests();
        self.clearSignerError();
    }

    pub fn inspectSessionPolicy(self: *const Session) PolicyPlan {
        return .{
            .action = switch (self.currentRelayState()) {
                .disconnected => .connect_relay,
                .auth_required => .authenticate_relay,
                .connected => if (self._state.connected) .ready else .connect_signer,
            },
            .relay = self.currentRelayDescriptor(),
        };
    }

    pub fn inspectSessionCadence(
        self: *const Session,
        request: CadenceRequest,
    ) CadencePlan {
        const policy = self.inspectSessionPolicy();
        if (policy.action == .connect_relay) {
            if (request.reconnect_not_before_unix_seconds) |not_before| {
                if (not_before > request.now_unix_seconds) {
                    return .{
                        .policy = policy,
                        .waiting = .{
                            .reason = .reconnect_backoff,
                            .not_before_unix_seconds = not_before,
                        },
                    };
                }
            }
        }
        return .{ .policy = policy };
    }

    pub fn selectRelayPoolStep(
        self: *Session,
        step: *const shared_runtime.RelayPoolStep,
    ) Error![]const u8 {
        if (self._state.pending_count != 0) return error.PendingRequestsInFlight;

        const descriptor = step.entry.descriptor;
        const relay = self._state.pool.getRelayConst(descriptor.relay_index) orelse {
            return error.InvalidRelayPoolStep;
        };
        if (!std.mem.eql(u8, relay.auth_session.relayUrl(), descriptor.relay_url)) {
            return error.InvalidRelayPoolStep;
        }
        if (step.entry.action != classifySignerRelayAction(relay.state)) {
            return error.InvalidRelayPoolStep;
        }

        const switching_relays = descriptor.relay_index != self._state.current_relay_index;
        self._state.current_relay_index = descriptor.relay_index;
        if (switching_relays) self._state.connected = false;
        return self.currentRelayUrl();
    }

    pub fn beginConnect(
        self: *Session,
        context: RequestContext,
        requested_permissions: []const Permission,
    ) Error!OutboundRequest {
        try self.requireRelayReady();

        var built_request = noztr.nip46_remote_signing.BuiltRequest{};
        const request = try noztr.nip46_remote_signing.request_build_connect(
            &built_request,
            context.id,
            &.{
                .remote_signer_pubkey = self._state.remote_signer_pubkey,
                .secret = self.expectedSecret(),
                .requested_permissions = requested_permissions,
            },
            context.scratch,
        );
        const json = try serialize_request(context.writable(), request);
        try self.registerPending(context.id, .connect);
        return .{
            .relay_url = self.currentRelayUrl(),
            .remote_signer_pubkey = self._state.remote_signer_pubkey,
            .json = json,
        };
    }

    pub fn beginGetPublicKey(
        self: *Session,
        context: RequestContext,
    ) Error!OutboundRequest {
        try self.requireConnectedRequestReady();

        var built_request = noztr.nip46_remote_signing.BuiltRequest{};
        const request = try noztr.nip46_remote_signing.request_build_empty(
            &built_request,
            context.id,
            .get_public_key,
            context.scratch,
        );
        const json = try serialize_request(context.writable(), request);
        try self.registerPending(context.id, .get_public_key);
        return .{
            .relay_url = self.currentRelayUrl(),
            .remote_signer_pubkey = self._state.remote_signer_pubkey,
            .json = json,
        };
    }

    pub fn beginSignEvent(
        self: *Session,
        context: RequestContext,
        unsigned_event_json: []const u8,
    ) Error!OutboundRequest {
        try self.requireConnectedRequestReady();

        var built_request = noztr.nip46_remote_signing.BuiltRequest{};
        const request = try noztr.nip46_remote_signing.request_build_sign_event(
            &built_request,
            context.id,
            unsigned_event_json,
            context.scratch,
        );
        const json = try serialize_request(context.writable(), request);
        try self.registerPending(context.id, .sign_event);
        return .{
            .relay_url = self.currentRelayUrl(),
            .remote_signer_pubkey = self._state.remote_signer_pubkey,
            .json = json,
        };
    }

    pub fn beginSwitchRelays(
        self: *Session,
        context: RequestContext,
    ) Error!OutboundRequest {
        try self.requireConnectedRequestReady();

        var built_request = noztr.nip46_remote_signing.BuiltRequest{};
        const request = try noztr.nip46_remote_signing.request_build_empty(
            &built_request,
            context.id,
            .switch_relays,
            context.scratch,
        );
        const json = try serialize_request(context.writable(), request);
        try self.registerPending(context.id, .switch_relays);
        return .{
            .relay_url = self.currentRelayUrl(),
            .remote_signer_pubkey = self._state.remote_signer_pubkey,
            .json = json,
        };
    }

    pub fn beginNip04Encrypt(
        self: *Session,
        context: RequestContext,
        request: *const PubkeyTextRequest,
    ) Error!OutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip04_encrypt, request);
    }

    pub fn beginNip04Decrypt(
        self: *Session,
        context: RequestContext,
        request: *const PubkeyTextRequest,
    ) Error!OutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip04_decrypt, request);
    }

    pub fn beginNip44Encrypt(
        self: *Session,
        context: RequestContext,
        request: *const PubkeyTextRequest,
    ) Error!OutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip44_encrypt, request);
    }

    pub fn beginNip44Decrypt(
        self: *Session,
        context: RequestContext,
        request: *const PubkeyTextRequest,
    ) Error!OutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip44_decrypt, request);
    }

    pub fn beginPing(
        self: *Session,
        context: RequestContext,
    ) Error!OutboundRequest {
        try self.requireConnectedRequestReady();

        var built_request = noztr.nip46_remote_signing.BuiltRequest{};
        const request = try noztr.nip46_remote_signing.request_build_empty(
            &built_request,
            context.id,
            .ping,
            context.scratch,
        );
        const json = try serialize_request(context.writable(), request);
        try self.registerPending(context.id, .ping);
        return .{
            .relay_url = self.currentRelayUrl(),
            .remote_signer_pubkey = self._state.remote_signer_pubkey,
            .json = json,
        };
    }

    /// Accepts a raw `NIP-46` response message and returns a typed outcome.
    /// Borrowed payloads in the outcome remain valid only while the caller-owned
    /// response input and parsing scratch remain alive.
    pub fn acceptResponseJson(
        self: *Session,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!ResponseOutcome {
        const message = noztr.nip46_remote_signing.message_parse_json(response_json, scratch) catch |err| {
            self.clearPendingForMalformedResponse(response_json);
            return err;
        };
        return switch (message) {
            .response => |response| try self.acceptResponse(&response, scratch),
            .request => error.UnexpectedMessageType,
        };
    }

    fn beginPubkeyTextRequest(
        self: *Session,
        context: RequestContext,
        method: Method,
        request: *const PubkeyTextRequest,
    ) Error!OutboundRequest {
        try self.requireConnectedRequestReady();

        var built_request = noztr.nip46_remote_signing.BuiltRequest{};
        const signed_request = try noztr.nip46_remote_signing.request_build_pubkey_text(
            &built_request,
            context.id,
            method,
            request,
            context.scratch,
        );
        const json = try serialize_request(context.writable(), signed_request);
        try self.registerPending(context.id, method);
        return .{
            .relay_url = self.currentRelayUrl(),
            .remote_signer_pubkey = self._state.remote_signer_pubkey,
            .json = json,
        };
    }

    fn acceptResponse(
        self: *Session,
        response: *const noztr.nip46_remote_signing.Response,
        scratch: std.mem.Allocator,
    ) Error!ResponseOutcome {
        const pending_index =
            self.findPendingIndex(response.id) orelse return error.UnknownResponseId;
        const method = self._state.pending[pending_index].method;
        var remove_pending_on_error = true;
        errdefer if (remove_pending_on_error) self.removePendingIndex(pending_index);
        try noztr.nip46_remote_signing.response_validate(response, method, scratch);
        if (response.error_text) |error_text| {
            try self.storeSignerError(error_text);
            return error.RemoteSignerRejected;
        }

        switch (method) {
            .connect => {
                const result = try noztr.nip46_remote_signing.response_result_connect(response);
                try self.applyConnectResult(result);
                self.removePendingIndex(pending_index);
                return .connected;
            },
            .get_public_key => {
                const pubkey = try noztr.nip46_remote_signing.response_result_get_public_key(response);
                self._state.user_pubkey = pubkey;
                self.removePendingIndex(pending_index);
                return .{ .user_pubkey = pubkey };
            },
            .sign_event => {
                var signed_event = try noztr.nip46_remote_signing.response_result_sign_event(response, scratch);
                noztr.nip01_event.event_verify(&signed_event) catch return error.InvalidSignedEvent;
                const signed_event_json = switch (response.result) {
                    .text => |text| text,
                    .relays => return error.InvalidResponse,
                    .null_result, .absent => return error.InvalidResponse,
                };
                self.removePendingIndex(pending_index);
                return .{ .signed_event_json = signed_event_json };
            },
            .ping => {
                self.removePendingIndex(pending_index);
                return .pong;
            },
            .nip04_encrypt,
            .nip04_decrypt,
            .nip44_encrypt,
            .nip44_decrypt,
            => {
                const text = try responseTextPayload(response);
                self.removePendingIndex(pending_index);
                return .{ .text_response = .{
                    .method = method,
                    .text = text,
                } };
            },
            .switch_relays => {
                const relays = try noztr.nip46_remote_signing.response_result_switch_relays(response);
                self.applySwitchedRelays(relays) catch |err| {
                    remove_pending_on_error = false;
                    self.removePendingIndex(pending_index);
                    return err;
                };
                self.removePendingIndex(pending_index);
                return .{ .relays_switched = self._state.pool.count };
            },
        }
    }

    fn applyConnectResult(
        self: *Session,
        result: noztr.nip46_remote_signing.ConnectResult,
    ) Error!void {
        if (self.expectedSecret()) |expected_secret| {
            switch (result) {
                .ack => return error.MissingSecretEcho,
                .secret_echo => |secret| {
                    if (!std.mem.eql(u8, expected_secret, secret)) return error.SecretMismatch;
                },
            }
        } else {
            switch (result) {
                .ack => {},
                .secret_echo => return error.InvalidResponse,
            }
        }
        self._state.connected = true;
    }

    fn applySwitchedRelays(
        self: *Session,
        relays: ?[]const []const u8,
    ) Error!void {
        const next_relays = relays orelse return;
        if (next_relays.len == 0) return error.NoRelays;

        var next_pool = relay_pool.Pool.init();
        for (next_relays) |relay_url| {
            _ = try next_pool.addRelay(relay_url);
        }
        self._state.pool = next_pool;
        self._state.current_relay_index = 0;
        self._state.connected = false;
    }

    fn requireRelayReady(self: *const Session) Error!void {
        const current =
            self._state.pool.getRelayConst(self._state.current_relay_index) orelse return error.NoRelays;
        if (current.canSendRequests()) return;
        return switch (current.state) {
            .disconnected => error.RelayDisconnected,
            .auth_required => error.RelayAuthRequired,
            .connected => unreachable,
        };
    }

    fn requireConnectedRequestReady(self: *const Session) Error!void {
        try self.requireRelayReady();
        if (!self._state.connected) return error.SignerSessionNotConnected;
    }

    fn expectedSecret(self: *const Session) ?[]const u8 {
        if (self._state.expected_secret_len == 0) return null;
        return self._state.expected_secret[0..self._state.expected_secret_len];
    }

    fn currentRelaySession(self: *Session) *relay_session.RelaySession {
        return self._state.pool.getRelay(self._state.current_relay_index) orelse unreachable;
    }

    fn currentRelayState(self: *const Session) relay_session.SessionState {
        const current = self._state.pool.getRelayConst(self._state.current_relay_index) orelse unreachable;
        return current.state;
    }

    fn currentRelayDescriptor(self: *const Session) shared_runtime.RelayDescriptor {
        return .{
            .relay_index = self._state.current_relay_index,
            .relay_url = self.currentRelayUrl(),
        };
    }

    fn isIdleForResume(self: *const Session) bool {
        if (self._state.connected or self._state.pending_count != 0) return false;

        var relay_index: u8 = 0;
        while (relay_index < self._state.pool.count) : (relay_index += 1) {
            const relay = self._state.pool.getRelayConst(relay_index) orelse unreachable;
            if (relay.state != .disconnected) return false;
        }
        return true;
    }

    fn registerPending(
        self: *Session,
        id: []const u8,
        method: noztr.nip46_remote_signing.Method,
    ) Error!void {
        if (self.findPendingIndex(id) != null) return error.DuplicateRequestId;
        if (self._state.pending_count == max_pending_requests) return error.PendingTableFull;

        self.clearSignerError();
        self._state.pending[self._state.pending_count].id_len = @intCast(id.len);
        @memset(self._state.pending[self._state.pending_count].id[0..], 0);
        @memcpy(self._state.pending[self._state.pending_count].id[0..id.len], id);
        self._state.pending[self._state.pending_count].method = method;
        self._state.pending_count += 1;
    }

    fn findPendingIndex(self: *const Session, id: []const u8) ?u8 {
        var index: u8 = 0;
        while (index < self._state.pending_count) : (index += 1) {
            if (std.mem.eql(u8, self._state.pending[index].idSlice(), id)) return index;
        }
        return null;
    }

    fn removePendingIndex(self: *Session, index: u8) void {
        std.debug.assert(index < self._state.pending_count);

        var cursor = index;
        while (cursor + 1 < self._state.pending_count) : (cursor += 1) {
            self._state.pending[cursor] = self._state.pending[cursor + 1];
        }
        self._state.pending_count -= 1;
        self._state.pending[self._state.pending_count] = .{};
    }

    fn clearSignerError(self: *Session) void {
        self._state.last_signer_error_len = 0;
        @memset(self._state.last_signer_error[0..], 0);
    }

    fn clearPendingRequests(self: *Session) void {
        self._state.pending_count = 0;
        self._state.pending = [_]PendingRequest{.{}} ** max_pending_requests;
    }

    fn storeSignerError(self: *Session, error_text: []const u8) Error!void {
        if (error_text.len > self._state.last_signer_error.len) return error.SignerErrorTooLong;
        self.clearSignerError();
        @memcpy(self._state.last_signer_error[0..error_text.len], error_text);
        self._state.last_signer_error_len = @intCast(error_text.len);
    }

    fn clearPendingForMalformedResponse(self: *Session, response_json: []const u8) void {
        var parse_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
        var parse_fba = std.heap.FixedBufferAllocator.init(&parse_storage);
        const root = std.json.parseFromSliceLeaky(
            std.json.Value,
            parse_fba.allocator(),
            response_json,
            .{},
        ) catch return;
        if (root != .object) return;

        var response_id: ?[]const u8 = null;
        var has_response_shape = false;
        var iterator = root.object.iterator();
        while (iterator.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, "id")) {
                if (entry.value_ptr.* != .string) return;
                response_id = entry.value_ptr.*.string;
                continue;
            }
            if (std.mem.eql(u8, entry.key_ptr.*, "result") or std.mem.eql(u8, entry.key_ptr.*, "error")) {
                has_response_shape = true;
            }
        }
        if (!has_response_shape) return;
        const id = response_id orelse return;
        const pending_index = self.findPendingIndex(id) orelse return;
        self.removePendingIndex(pending_index);
    }
};

fn responseTextPayload(
    response: *const noztr.nip46_remote_signing.Response,
) Error![]const u8 {
    return switch (response.result) {
        .text => |text| text,
        .relays => error.InvalidResponse,
        .null_result, .absent => error.InvalidResponse,
    };
}

fn serialize_request(
    json_out: []u8,
    request: noztr.nip46_remote_signing.Request,
) Error![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(
        json_out,
        .{ .request = request },
    );
}

fn classifySignerRelayAction(state: relay_session.SessionState) shared_runtime.RelayPoolAction {
    return switch (state) {
        .disconnected => .connect,
        .auth_required => .authenticate,
        .connected => .ready,
    };
}

fn serialize_response(
    json_out: []u8,
    response: noztr.nip46_remote_signing.Response,
) noztr.nip46_remote_signing.RemoteSigningError![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(
        json_out,
        .{ .response = response },
    );
}

fn requestContext(
    id: []const u8,
    buffer: *RequestBuffer,
    scratch: std.mem.Allocator,
) RequestContext {
    return RequestContext.init(id, buffer, scratch);
}

test "remote signer session connects with matching secret echo" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=abc";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const outbound = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );
    try std.testing.expectEqualStrings("wss://relay.one", outbound.relay_url);
    try std.testing.expect(std.mem.indexOf(u8, outbound.json, "\"method\":\"connect\"") != null);
    try std.testing.expect(session._state.pending_count == 1);

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "abc" },
    });

    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());
    try std.testing.expect(outcome == .connected);
    try std.testing.expect(session.isConnected());
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer exposes caller-owned relay-pool adapter storage" {
    var relay_pool_storage = RelayPoolStorage{};
    var runtime_storage = RelayRuntimeStorage{};
    var resume_storage = ResumeStorage{};
    _ = &relay_pool_storage;
    _ = &runtime_storage;
    _ = &resume_storage;
}

test "remote signer exports the shared relay-pool runtime floor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var pool_storage = RelayPoolStorage{};
    var pool = session.exportRelayPool(&pool_storage);
    try std.testing.expectEqual(@as(u8, 2), pool.relayCount());

    var plan_storage = shared_runtime.RelayPoolPlanStorage{};
    const plan = pool.inspectRuntime(&plan_storage);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
}

test "remote signer inspects shared relay-pool runtime through caller-owned storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var runtime_storage = RelayRuntimeStorage{};
    const plan = session.inspectRelayPoolRuntime(&runtime_storage);
    try std.testing.expectEqual(@as(u8, 2), plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), plan.authenticate_count);
    try std.testing.expectEqual(@as(u8, 1), plan.connect_count);
    try std.testing.expectEqual(shared_runtime.RelayPoolAction.authenticate, plan.nextStep().?.entry.action);
}

test "remote signer selects a shared relay-pool step back onto the signer session" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    _ = try session.acceptResponseJson(response, arena.allocator());
    try std.testing.expect(session.isConnected());

    var runtime_storage = RelayRuntimeStorage{};
    const plan = session.inspectRelayPoolRuntime(&runtime_storage);
    const second = plan.entry(1).?;
    const selected_url = try session.selectRelayPoolStep(&.{ .entry = second });
    try std.testing.expectEqualStrings("wss://relay.two", selected_url);
    try std.testing.expectEqualStrings("wss://relay.two", session.currentRelayUrl());
    try std.testing.expect(!session.isConnected());
}

test "remote signer rejects stale relay-pool steps" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());

    const bad_step = shared_runtime.RelayPoolStep{
        .entry = .{
            .descriptor = .{
                .relay_index = 0,
                .relay_url = "wss://relay.other",
            },
            .action = .connect,
        },
    };
    try std.testing.expectError(error.InvalidRelayPoolStep, session.selectRelayPoolStep(&bad_step));
}

test "remote signer session rejects mismatched secret echo" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=abc";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "nope" },
    });

    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.SecretMismatch,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expect(!session.isConnected());
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session requires secret echo when bunker secret is configured" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=abc";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });

    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.MissingSecretEcho,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session rejects echoed secret when bunker secret is absent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "unexpected-secret" },
    });

    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.InvalidResponse,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session enforces request response correlation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var scratch_storage_a: [1024]u8 = undefined;
    var scratch_a = std.heap.FixedBufferAllocator.init(&scratch_storage_a);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, scratch_a.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginGetPublicKey(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    var wrong_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const wrong_response = try serialize_response(wrong_response_json[0..], .{
        .id = "req-9",
        .result = .{ .text = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" },
    });
    var wrong_response_scratch_storage: [2048]u8 = undefined;
    var wrong_response_scratch = std.heap.FixedBufferAllocator.init(&wrong_response_scratch_storage);
    try std.testing.expectError(
        error.UnknownResponseId,
        session.acceptResponseJson(wrong_response, wrong_response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 1), session._state.pending_count);
}

test "remote signer session blocks requests while relay auth is pending and recovers after auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var scratch_storage_a: [1024]u8 = undefined;
    var scratch_a = std.heap.FixedBufferAllocator.init(&scratch_storage_a);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, scratch_a.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var blocked_request_buffer = RequestBuffer{};
    var blocked_request_scratch_storage: [1024]u8 = undefined;
    var blocked_request_scratch =
        std.heap.FixedBufferAllocator.init(&blocked_request_scratch_storage);
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.beginPing(
            requestContext("req-2", &blocked_request_buffer, blocked_request_scratch.allocator()),
        ),
    );

    const auth_event_json =
        \\{"id":"3dc7a38754fee63558d2020588ad38b8baac483969944a6b144735cf415acaa8","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","challenge-1"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    var auth_scratch_storage: [4096]u8 = undefined;
    var auth_scratch = std.heap.FixedBufferAllocator.init(&auth_scratch_storage);
    try session.acceptCurrentRelayAuthEventJson(
        auth_event_json,
        1_773_533_654,
        60,
        auth_scratch.allocator(),
    );

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );
}

test "remote signer exports and restores durable resume state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var pubkey_request_buffer = RequestBuffer{};
    var pubkey_request_scratch_storage: [1024]u8 = undefined;
    var pubkey_request_scratch = std.heap.FixedBufferAllocator.init(&pubkey_request_scratch_storage);
    _ = try session.beginGetPublicKey(
        requestContext("req-2", &pubkey_request_buffer, pubkey_request_scratch.allocator()),
    );

    const user_pubkey = [_]u8{0x11} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var pubkey_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var pubkey_response_scratch_storage: [2048]u8 = undefined;
    var pubkey_response_scratch =
        std.heap.FixedBufferAllocator.init(&pubkey_response_scratch_storage);
    _ = try session.acceptResponseJson(
        try serialize_response(pubkey_response_json[0..], .{
            .id = "req-2",
            .result = .{ .text = user_pubkey_hex[0..] },
        }),
        pubkey_response_scratch.allocator(),
    );

    var switch_request_buffer = RequestBuffer{};
    var switch_request_scratch_storage: [1024]u8 = undefined;
    var switch_request_scratch = std.heap.FixedBufferAllocator.init(&switch_request_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-3", &switch_request_buffer, switch_request_scratch.allocator()),
    );

    const next_relays = [_][]const u8{ "wss://relay.three", "wss://relay.four" };
    var switch_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var switch_response_scratch_storage: [2048]u8 = undefined;
    var switch_response_scratch =
        std.heap.FixedBufferAllocator.init(&switch_response_scratch_storage);
    _ = try session.acceptResponseJson(
        try serialize_response(switch_response_json[0..], .{
            .id = "req-3",
            .result = .{ .relays = next_relays[0..] },
        }),
        switch_response_scratch.allocator(),
    );

    const select_step = shared_runtime.RelayPoolStep{
        .entry = .{
            .descriptor = .{
                .relay_index = 1,
                .relay_url = "wss://relay.four",
            },
            .action = .connect,
        },
    };
    _ = try session.selectRelayPoolStep(&select_step);
    try std.testing.expectEqualStrings("wss://relay.four", session.currentRelayUrl());
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &session.getUserPubkey().?));

    var resume_storage = ResumeStorage{};
    const resume_state = try session.exportResumeState(&resume_storage);

    var restored = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    try restored.restoreResumeState(&resume_state);
    try std.testing.expectEqual(@as(u8, 2), resume_state.relay_count);
    try std.testing.expectEqualStrings("wss://relay.three", resume_state.relayUrl(0).?);
    try std.testing.expectEqualStrings("wss://relay.four", resume_state.relayUrl(1).?);
    try std.testing.expectEqualStrings("wss://relay.four", restored.currentRelayUrl());
    try std.testing.expect(!restored.isConnected());
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &restored.getUserPubkey().?));
}

test "remote signer rejects resume restore while session is not idle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var resume_storage = ResumeStorage{};
    const resume_state = try session.exportResumeState(&resume_storage);
    try std.testing.expectError(error.SessionNotIdle, session.restoreResumeState(&resume_state));
}

test "remote signer session policy classifies current relay posture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());

    const disconnected = session.inspectSessionPolicy();
    try std.testing.expectEqual(PolicyAction.connect_relay, disconnected.action);

    session.markCurrentRelayConnected();
    const connect_signer = session.inspectSessionPolicy();
    try std.testing.expectEqual(PolicyAction.connect_signer, connect_signer.action);

    session.noteCurrentRelayDisconnected();
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");
    const authenticate = session.inspectSessionPolicy();
    try std.testing.expectEqual(
        PolicyAction.authenticate_relay,
        authenticate.action,
    );

    const auth_event_json =
        \\{"id":"3dc7a38754fee63558d2020588ad38b8baac483969944a6b144735cf415acaa8","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","challenge-1"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    var auth_scratch_storage: [4096]u8 = undefined;
    var auth_scratch = std.heap.FixedBufferAllocator.init(&auth_scratch_storage);
    try session.acceptCurrentRelayAuthEventJson(
        auth_event_json,
        1_773_533_654,
        60,
        auth_scratch.allocator(),
    );

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    _ = try session.acceptResponseJson(response, response_scratch.allocator());

    const ready = session.inspectSessionPolicy();
    try std.testing.expectEqual(PolicyAction.ready, ready.action);
}

test "remote signer session cadence can defer reconnect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    const session = try Session.initFromBunkerUriText(uri_text, arena.allocator());

    const waiting = session.inspectSessionCadence(.{
        .now_unix_seconds = 10,
        .reconnect_not_before_unix_seconds = 20,
    });
    try std.testing.expect(waiting.nextStep() == .wait);
    try std.testing.expectEqual(
        CadenceWaitReason.reconnect_backoff,
        waiting.nextStep().wait.reason,
    );

    const due = session.inspectSessionCadence(.{
        .now_unix_seconds = 25,
        .reconnect_not_before_unix_seconds = 20,
    });
    try std.testing.expect(due.nextStep() == .policy);
    try std.testing.expectEqual(
        PolicyAction.connect_relay,
        due.nextStep().policy.action,
    );
}

test "remote signer session keeps relay blocked after invalid auth event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    try session.noteCurrentRelayAuthChallenge("challenge-1");

    const auth_event_json =
        \\{"id":"3dc7a38754fee63558d2020588ad38b8baac483969944a6b144735cf415acaa8","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","wrong-challenge"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    var auth_scratch_storage: [4096]u8 = undefined;
    var auth_scratch = std.heap.FixedBufferAllocator.init(&auth_scratch_storage);
    try std.testing.expectError(
        error.ChallengeMismatch,
        session.acceptCurrentRelayAuthEventJson(
            auth_event_json,
            1_773_533_654,
            60,
            auth_scratch.allocator(),
        ),
    );
    try std.testing.expect(!session.currentRelayCanSendRequests());

    var blocked_request_buffer = RequestBuffer{};
    var blocked_request_scratch_storage: [1024]u8 = undefined;
    var blocked_request_scratch =
        std.heap.FixedBufferAllocator.init(&blocked_request_scratch_storage);
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.beginPing(
            requestContext("req-2", &blocked_request_buffer, blocked_request_scratch.allocator()),
        ),
    );
}

test "remote signer session applies switch relays responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    const relays = [_][]const u8{ "wss://relay.three", "wss://relay.four" };
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .relays = relays[0..] },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());

    try std.testing.expect(outcome == .relays_switched);
    try std.testing.expectEqual(@as(u8, 2), outcome.relays_switched);
    try std.testing.expectEqualStrings("wss://relay.three", session.currentRelayUrl());
    try std.testing.expect(!session.isConnected());
}

test "remote signer session rejects invalid bunker relay urls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=https%3A%2F%2Frelay.one";

    try std.testing.expectError(
        error.InvalidRelayUrl,
        Session.initFromBunkerUriText(uri_text, arena.allocator()),
    );
}

test "remote signer session keeps state unchanged on null switch relays response" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .null_result,
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());

    try std.testing.expect(outcome == .relays_switched);
    try std.testing.expectEqual(@as(u8, 2), outcome.relays_switched);
    try std.testing.expectEqualStrings("wss://relay.one", session.currentRelayUrl());
    try std.testing.expect(session.isConnected());
}

test "remote signer session rejects invalid switch relays urls and keeps state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    const relays = [_][]const u8{ "https://relay.bad", "wss://relay.four" };
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .relays = relays[0..] },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.InvalidRelayUrl,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );

    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
    try std.testing.expectEqualStrings("wss://relay.one", session.currentRelayUrl());
    try std.testing.expect(session.isConnected());
}

test "remote signer session reapplies auth flow after switch relays replacement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var switch_request_buffer = RequestBuffer{};
    var switch_scratch_storage: [1024]u8 = undefined;
    var switch_scratch = std.heap.FixedBufferAllocator.init(&switch_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &switch_request_buffer, switch_scratch.allocator()),
    );

    const relays = [_][]const u8{ "wss://relay.one", "wss://relay.four" };
    var switch_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const switch_response = try serialize_response(switch_response_json[0..], .{
        .id = "req-2",
        .result = .{ .relays = relays[0..] },
    });
    var switch_response_scratch_storage: [2048]u8 = undefined;
    var switch_response_scratch =
        std.heap.FixedBufferAllocator.init(&switch_response_scratch_storage);
    _ = try session.acceptResponseJson(switch_response, switch_response_scratch.allocator());

    try std.testing.expect(!session.isConnected());
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var blocked_request_buffer = RequestBuffer{};
    var blocked_request_scratch_storage: [1024]u8 = undefined;
    var blocked_request_scratch =
        std.heap.FixedBufferAllocator.init(&blocked_request_scratch_storage);
    try std.testing.expectError(
        error.RelayAuthRequired,
        session.beginPing(
            requestContext("req-3", &blocked_request_buffer, blocked_request_scratch.allocator()),
        ),
    );

    const auth_event_json =
        \\{"id":"3dc7a38754fee63558d2020588ad38b8baac483969944a6b144735cf415acaa8","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","challenge-1"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    var auth_scratch_storage: [4096]u8 = undefined;
    var auth_scratch = std.heap.FixedBufferAllocator.init(&auth_scratch_storage);
    try session.acceptCurrentRelayAuthEventJson(
        auth_event_json,
        1_773_533_654,
        60,
        auth_scratch.allocator(),
    );

    var reconnect_request_buffer = RequestBuffer{};
    var reconnect_request_scratch_storage: [1024]u8 = undefined;
    var reconnect_request_scratch =
        std.heap.FixedBufferAllocator.init(&reconnect_request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-3", &reconnect_request_buffer, reconnect_request_scratch.allocator()),
        &.{},
    );

    var reconnect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const reconnect_response = try serialize_response(reconnect_response_json[0..], .{
        .id = "req-3",
        .result = .{ .text = "ack" },
    });
    var reconnect_response_scratch_storage: [2048]u8 = undefined;
    var reconnect_response_scratch =
        std.heap.FixedBufferAllocator.init(&reconnect_response_scratch_storage);
    _ = try session.acceptResponseJson(reconnect_response, reconnect_response_scratch.allocator());

    var ping_request_buffer = RequestBuffer{};
    var ping_request_scratch_storage: [1024]u8 = undefined;
    var ping_request_scratch = std.heap.FixedBufferAllocator.init(&ping_request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-4", &ping_request_buffer, ping_request_scratch.allocator()),
    );
}

test "remote signer session blocks requests after same relay disconnect until reconnected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    session.noteCurrentRelayDisconnected();

    var blocked_ping_buffer = RequestBuffer{};
    var blocked_ping_scratch_storage: [1024]u8 = undefined;
    var blocked_ping_scratch =
        std.heap.FixedBufferAllocator.init(&blocked_ping_scratch_storage);
    try std.testing.expectError(
        error.RelayDisconnected,
        session.beginPing(
            requestContext("req-2", &blocked_ping_buffer, blocked_ping_scratch.allocator()),
        ),
    );

    var blocked_pubkey_buffer = RequestBuffer{};
    var blocked_pubkey_scratch_storage: [1024]u8 = undefined;
    var blocked_pubkey_scratch =
        std.heap.FixedBufferAllocator.init(&blocked_pubkey_scratch_storage);
    try std.testing.expectError(
        error.RelayDisconnected,
        session.beginGetPublicKey(
            requestContext("req-3", &blocked_pubkey_buffer, blocked_pubkey_scratch.allocator()),
        ),
    );

    session.markCurrentRelayConnected();

    var reconnect_request_buffer = RequestBuffer{};
    var reconnect_request_scratch_storage: [1024]u8 = undefined;
    var reconnect_request_scratch =
        std.heap.FixedBufferAllocator.init(&reconnect_request_scratch_storage);
    try std.testing.expectError(
        error.SignerSessionNotConnected,
        session.beginPing(
            requestContext("req-4", &reconnect_request_buffer, reconnect_request_scratch.allocator()),
        ),
    );

    var reconnect_connect_buffer = RequestBuffer{};
    var reconnect_connect_scratch_storage: [1024]u8 = undefined;
    var reconnect_connect_scratch =
        std.heap.FixedBufferAllocator.init(&reconnect_connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-5", &reconnect_connect_buffer, reconnect_connect_scratch.allocator()),
        &.{},
    );
}

test "remote signer disconnect clears in-flight requests so failover can resume" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var ping_request_buffer = RequestBuffer{};
    var ping_request_scratch_storage: [1024]u8 = undefined;
    var ping_request_scratch = std.heap.FixedBufferAllocator.init(&ping_request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-2", &ping_request_buffer, ping_request_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 1), session._state.pending_count);

    session.noteCurrentRelayDisconnected();

    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
    try std.testing.expectEqualStrings("wss://relay.two", try session.advanceRelay());

    var stale_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const stale_response = try serialize_response(stale_response_json[0..], .{
        .id = "req-2",
        .result = .{ .text = "pong" },
    });
    var stale_response_scratch_storage: [2048]u8 = undefined;
    var stale_response_scratch = std.heap.FixedBufferAllocator.init(&stale_response_scratch_storage);
    try std.testing.expectError(
        error.UnknownResponseId,
        session.acceptResponseJson(stale_response, stale_response_scratch.allocator()),
    );
}

test "remote signer session surfaces signer-declared errors and clears pending requests" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .error_text = "denied",
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.RemoteSignerRejected,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqualStrings("denied", session.lastSignerError().?);
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session rejects malformed sign_event responses and clears pending requests" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [4096]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSignEvent(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        "{\"kind\":1,\"content\":\"unsigned\",\"tags\":[],\"created_at\":1}",
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .text = "{\"kind\":1}" },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.InvalidSignedEvent,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session rejects invalidly signed sign_event responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [4096]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSignEvent(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        "{\"kind\":1,\"content\":\"unsigned\",\"tags\":[],\"created_at\":1}",
    );

    const invalid_signed_event_json =
        \\{"id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","pubkey":"f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9","created_at":1773533653,"kind":22242,"tags":[["relay","wss://relay.one"],["challenge","challenge-1"]],"content":"","sig":"cacbeb6595c54d615325569c6a3439e1500e32cfd04cef4900742ea2c996b6dc2e5469586c069a428e0c0d96f2e8191921b996444f8d51ac6e2d7dd3dc069c64"}
    ;
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .text = invalid_signed_event_json },
    });
    var response_scratch_storage: [4096]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.InvalidSignedEvent,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session clears pending requests when signer error text is oversized" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    const oversized_error_text = [_]u8{'x'} ** (max_signer_error_bytes + 1);
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .error_text = oversized_error_text[0..],
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.SignerErrorTooLong,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session clears pending requests for oversized malformed responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    var malformed_response: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var padding: [3000]u8 = undefined;
    @memset(padding[0..], 'x');
    const malformed_json = try std.fmt.bufPrint(
        malformed_response[0..],
        "{{\"id\":\"req-2\",\"result\":123,\"padding\":\"{s}\"}}",
        .{padding[0..]},
    );

    var malformed_scratch_storage: [4096]u8 = undefined;
    var malformed_scratch = std.heap.FixedBufferAllocator.init(&malformed_scratch_storage);
    try std.testing.expectError(
        error.InvalidMessage,
        session.acceptResponseJson(malformed_json, malformed_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session accepts nip04 encrypt text responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = PubkeyTextRequest{
        .pubkey = [_]u8{0xaa} ** 32,
        .text = "hello dm",
    };
    const outbound = try session.beginNip04Encrypt(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        &request,
    );
    try std.testing.expect(std.mem.indexOf(u8, outbound.json, "\"method\":\"nip04_encrypt\"") != null);

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .text = "ciphertext" },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());
    try std.testing.expect(outcome == .text_response);
    try std.testing.expectEqual(Method.nip04_encrypt, outcome.text_response.method);
    try std.testing.expectEqualStrings("ciphertext", outcome.text_response.text);
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session accepts nip44 decrypt text responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = PubkeyTextRequest{
        .pubkey = [_]u8{0xbb} ** 32,
        .text = "ciphertext",
    };
    _ = try session.beginNip44Decrypt(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        &request,
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .text = "plaintext" },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());
    try std.testing.expect(outcome == .text_response);
    try std.testing.expectEqual(Method.nip44_decrypt, outcome.text_response.method);
    try std.testing.expectEqualStrings("plaintext", outcome.text_response.text);
}

test "remote signer session blocks pubkey text methods until signer session is connected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = PubkeyTextRequest{
        .pubkey = [_]u8{0xcc} ** 32,
        .text = "hello",
    };
    try std.testing.expectError(
        error.SignerSessionNotConnected,
        session.beginNip44Encrypt(
            requestContext("req-1", &request_buffer, request_scratch.allocator()),
            &request,
        ),
    );
}

test "remote signer session clears pending requests for malformed pubkey text responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = PubkeyTextRequest{
        .pubkey = [_]u8{0xdd} ** 32,
        .text = "hello",
    };
    _ = try session.beginNip44Encrypt(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        &request,
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .relays = &.{"wss://wrong.example"} },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.InvalidResponse,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session records signer errors for pubkey text methods and clears pending" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try Session.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .text = "ack" },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = PubkeyTextRequest{
        .pubkey = [_]u8{0xee} ** 32,
        .text = "ciphertext",
    };
    _ = try session.beginNip04Decrypt(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        &request,
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .error_text = "denied",
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    try std.testing.expectError(
        error.RemoteSignerRejected,
        session.acceptResponseJson(response, response_scratch.allocator()),
    );
    try std.testing.expectEqualStrings("denied", session.lastSignerError().?);
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}
