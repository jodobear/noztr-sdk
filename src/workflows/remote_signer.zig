const std = @import("std");
const noztr = @import("noztr");
const relay_pool = @import("../relay/pool.zig");
const relay_session = @import("../relay/session.zig");
const shared_runtime = @import("../runtime/mod.zig");

pub const max_pending_requests: u8 = 8;
pub const max_secret_bytes: u16 = noztr.limits.nip46_secret_bytes_max;
pub const max_signer_error_bytes: u16 = 512;

pub const RemoteSignerError =
    noztr.nip46_remote_signing.RemoteSigningError ||
    noztr.nip42_auth.AuthError ||
    noztr.nip01_event.EventParseError ||
    error{
        UnsupportedConnectionUri,
        NoRelays,
        RelayUrlTooLong,
        PoolFull,
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

pub const RemoteSignerMethod = noztr.nip46_remote_signing.RemoteSigningMethod;
pub const PermissionScope = noztr.nip46_remote_signing.PermissionScope;
pub const Permission = noztr.nip46_remote_signing.Permission;
pub const RemoteSignerPubkeyTextRequest = noztr.nip46_remote_signing.PubkeyTextRequest;

/// Caller-owned storage for serialized request JSON.
/// `RemoteSignerOutboundRequest.json` borrows from this buffer until it is overwritten.
pub const RemoteSignerRequestBuffer = struct {
    storage: [noztr.limits.nip46_message_json_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.nip46_message_json_bytes_max,

    fn writable(self: *RemoteSignerRequestBuffer) []u8 {
        return self.storage[0..];
    }
};

/// Caller-owned request-building context shared across `begin...` entrypoints.
/// Request JSON borrows from `buffer` until it is overwritten.
pub const RemoteSignerRequestContext = struct {
    id: []const u8,
    buffer: *RemoteSignerRequestBuffer,
    scratch: std.mem.Allocator,

    pub fn init(
        id: []const u8,
        buffer: *RemoteSignerRequestBuffer,
        scratch: std.mem.Allocator,
    ) RemoteSignerRequestContext {
        return .{
            .id = id,
            .buffer = buffer,
            .scratch = scratch,
        };
    }

    fn writable(self: RemoteSignerRequestContext) []u8 {
        return self.buffer.writable();
    }
};

/// Transport-ready request envelope.
/// `json` borrows from the caller-provided `RemoteSignerRequestBuffer`.
pub const RemoteSignerOutboundRequest = struct {
    relay_url: []const u8,
    remote_signer_pubkey: [32]u8,
    json: []const u8,
};

/// Parsed response result.
/// Borrowed payloads in `signed_event_json` and `text_response.text` come from the
/// `acceptResponseJson(...)` input and parsing scratch. Copy them if the caller needs
/// to retain them after scratch or response input is reused.
pub const RemoteSignerTextResponse = struct {
    method: RemoteSignerMethod,
    text: []const u8,
};

pub const RemoteSignerResponseOutcome = union(enum) {
    connected,
    user_pubkey: [32]u8,
    signed_event_json: []const u8,
    text_response: RemoteSignerTextResponse,
    pong,
    relays_switched: u8,
};

pub const RemoteSignerRelayPoolStorage = struct {
    relay_pool_storage: shared_runtime.RelayPoolStorage = .{},
};

pub const RemoteSignerRelayPoolRuntimeStorage = struct {
    relay_pool_storage: RemoteSignerRelayPoolStorage = .{},
    plan_storage: shared_runtime.RelayPoolPlanStorage = .{},
};

const PendingRequest = struct {
    id: [noztr.limits.nip46_message_id_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.nip46_message_id_bytes_max,
    id_len: u8 = 0,
    method: noztr.nip46_remote_signing.RemoteSigningMethod = .ping,

    fn idSlice(self: *const PendingRequest) []const u8 {
        return self.id[0..self.id_len];
    }
};

pub const RemoteSignerSession = struct {
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
    ) RemoteSignerError!RemoteSignerSession {
        const uri = try noztr.nip46_remote_signing.uri_parse(uri_text, scratch);
        return switch (uri) {
            .bunker => |bunker| initFromBunkerUri(&bunker),
            .client => error.UnsupportedConnectionUri,
        };
    }

    fn initFromBunkerUri(
        bunker: *const noztr.nip46_remote_signing.BunkerUri,
    ) RemoteSignerError!RemoteSignerSession {
        if (bunker.relays.len == 0) return error.NoRelays;

        var session = RemoteSignerSession{
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

    pub fn currentRelayUrl(self: *const RemoteSignerSession) []const u8 {
        const current = self._state.pool.getRelayConst(self._state.current_relay_index) orelse unreachable;
        return current.auth_session.relayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const RemoteSignerSession) bool {
        const current = self._state.pool.getRelayConst(self._state.current_relay_index) orelse unreachable;
        return current.canSendRequests();
    }

    pub fn isConnected(self: *const RemoteSignerSession) bool {
        return self._state.connected;
    }

    pub fn remoteSignerPubkey(self: *const RemoteSignerSession) [32]u8 {
        return self._state.remote_signer_pubkey;
    }

    pub fn getUserPubkey(self: *const RemoteSignerSession) ?[32]u8 {
        return self._state.user_pubkey;
    }

    pub fn lastSignerError(self: *const RemoteSignerSession) ?[]const u8 {
        if (self._state.last_signer_error_len == 0) return null;
        return self._state.last_signer_error[0..self._state.last_signer_error_len];
    }

    pub fn markCurrentRelayConnected(self: *RemoteSignerSession) void {
        self.currentRelaySession().connect();
    }

    pub fn noteCurrentRelayDisconnected(self: *RemoteSignerSession) void {
        self.currentRelaySession().disconnect();
        self._state.connected = false;
        self.clearPendingRequests();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *RemoteSignerSession,
        challenge: []const u8,
    ) RemoteSignerError!void {
        try self.currentRelaySession().requireAuth(challenge);
    }

    pub fn acceptCurrentRelayAuthEventJson(
        self: *RemoteSignerSession,
        auth_event_json: []const u8,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) RemoteSignerError!void {
        const auth_event = try noztr.nip01_event.event_parse_json(auth_event_json, scratch);
        try self.currentRelaySession().acceptAuthEvent(
            &auth_event,
            now_unix_seconds,
            window_seconds,
        );
    }

    pub fn advanceRelay(self: *RemoteSignerSession) RemoteSignerError![]const u8 {
        if (self._state.pending_count != 0) return error.PendingRequestsInFlight;
        if (self._state.pool.count == 0) return error.NoRelays;

        self._state.current_relay_index =
            (self._state.current_relay_index + 1) % self._state.pool.count;
        self._state.connected = false;
        return self.currentRelayUrl();
    }

    pub fn exportRelayPool(
        self: *const RemoteSignerSession,
        storage: *RemoteSignerRelayPoolStorage,
    ) shared_runtime.RelayPool {
        storage.* = .{};
        storage.relay_pool_storage.pool = self._state.pool;
        return shared_runtime.RelayPool.attach(&storage.relay_pool_storage);
    }

    pub fn inspectRelayPoolRuntime(
        self: *const RemoteSignerSession,
        storage: *RemoteSignerRelayPoolRuntimeStorage,
    ) shared_runtime.RelayPoolPlan {
        var pool = self.exportRelayPool(&storage.relay_pool_storage);
        return pool.inspectRuntime(&storage.plan_storage);
    }

    pub fn selectRelayPoolStep(
        self: *RemoteSignerSession,
        step: *const shared_runtime.RelayPoolStep,
    ) RemoteSignerError![]const u8 {
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
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        requested_permissions: []const Permission,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
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
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
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
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        unsigned_event_json: []const u8,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
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
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
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
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        request: *const RemoteSignerPubkeyTextRequest,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip04_encrypt, request);
    }

    pub fn beginNip04Decrypt(
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        request: *const RemoteSignerPubkeyTextRequest,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip04_decrypt, request);
    }

    pub fn beginNip44Encrypt(
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        request: *const RemoteSignerPubkeyTextRequest,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip44_encrypt, request);
    }

    pub fn beginNip44Decrypt(
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        request: *const RemoteSignerPubkeyTextRequest,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
        return self.beginPubkeyTextRequest(context, .nip44_decrypt, request);
    }

    pub fn beginPing(
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
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
        self: *RemoteSignerSession,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) RemoteSignerError!RemoteSignerResponseOutcome {
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
        self: *RemoteSignerSession,
        context: RemoteSignerRequestContext,
        method: RemoteSignerMethod,
        request: *const RemoteSignerPubkeyTextRequest,
    ) RemoteSignerError!RemoteSignerOutboundRequest {
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
        self: *RemoteSignerSession,
        response: *const noztr.nip46_remote_signing.Response,
        scratch: std.mem.Allocator,
    ) RemoteSignerError!RemoteSignerResponseOutcome {
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
                    .value => |payload| switch (payload) {
                        .text => |text| text,
                        .relay_list => return error.InvalidResponse,
                    },
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
        self: *RemoteSignerSession,
        result: noztr.nip46_remote_signing.ConnectResult,
    ) RemoteSignerError!void {
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
        self: *RemoteSignerSession,
        relays: ?[]const []const u8,
    ) RemoteSignerError!void {
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

    fn requireRelayReady(self: *const RemoteSignerSession) RemoteSignerError!void {
        const current =
            self._state.pool.getRelayConst(self._state.current_relay_index) orelse return error.NoRelays;
        if (current.canSendRequests()) return;
        return switch (current.state) {
            .disconnected => error.RelayDisconnected,
            .auth_required => error.RelayAuthRequired,
            .connected => unreachable,
        };
    }

    fn requireConnectedRequestReady(self: *const RemoteSignerSession) RemoteSignerError!void {
        try self.requireRelayReady();
        if (!self._state.connected) return error.SignerSessionNotConnected;
    }

    fn expectedSecret(self: *const RemoteSignerSession) ?[]const u8 {
        if (self._state.expected_secret_len == 0) return null;
        return self._state.expected_secret[0..self._state.expected_secret_len];
    }

    fn currentRelaySession(self: *RemoteSignerSession) *relay_session.RelaySession {
        return self._state.pool.getRelay(self._state.current_relay_index) orelse unreachable;
    }

    fn registerPending(
        self: *RemoteSignerSession,
        id: []const u8,
        method: noztr.nip46_remote_signing.RemoteSigningMethod,
    ) RemoteSignerError!void {
        if (self.findPendingIndex(id) != null) return error.DuplicateRequestId;
        if (self._state.pending_count == max_pending_requests) return error.PendingTableFull;

        self.clearSignerError();
        self._state.pending[self._state.pending_count].id_len = @intCast(id.len);
        @memset(self._state.pending[self._state.pending_count].id[0..], 0);
        @memcpy(self._state.pending[self._state.pending_count].id[0..id.len], id);
        self._state.pending[self._state.pending_count].method = method;
        self._state.pending_count += 1;
    }

    fn findPendingIndex(self: *const RemoteSignerSession, id: []const u8) ?u8 {
        var index: u8 = 0;
        while (index < self._state.pending_count) : (index += 1) {
            if (std.mem.eql(u8, self._state.pending[index].idSlice(), id)) return index;
        }
        return null;
    }

    fn removePendingIndex(self: *RemoteSignerSession, index: u8) void {
        std.debug.assert(index < self._state.pending_count);

        var cursor = index;
        while (cursor + 1 < self._state.pending_count) : (cursor += 1) {
            self._state.pending[cursor] = self._state.pending[cursor + 1];
        }
        self._state.pending_count -= 1;
        self._state.pending[self._state.pending_count] = .{};
    }

    fn clearSignerError(self: *RemoteSignerSession) void {
        self._state.last_signer_error_len = 0;
        @memset(self._state.last_signer_error[0..], 0);
    }

    fn clearPendingRequests(self: *RemoteSignerSession) void {
        self._state.pending_count = 0;
        self._state.pending = [_]PendingRequest{.{}} ** max_pending_requests;
    }

    fn storeSignerError(self: *RemoteSignerSession, error_text: []const u8) RemoteSignerError!void {
        if (error_text.len > self._state.last_signer_error.len) return error.SignerErrorTooLong;
        self.clearSignerError();
        @memcpy(self._state.last_signer_error[0..error_text.len], error_text);
        self._state.last_signer_error_len = @intCast(error_text.len);
    }

    fn clearPendingForMalformedResponse(self: *RemoteSignerSession, response_json: []const u8) void {
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
) RemoteSignerError![]const u8 {
    return switch (response.result) {
        .value => |payload| switch (payload) {
            .text => |text| text,
            .relay_list => error.InvalidResponse,
        },
        .null_result, .absent => error.InvalidResponse,
    };
}

fn serialize_request(
    json_out: []u8,
    request: noztr.nip46_remote_signing.Request,
) RemoteSignerError![]const u8 {
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
    buffer: *RemoteSignerRequestBuffer,
    scratch: std.mem.Allocator,
) RemoteSignerRequestContext {
    return RemoteSignerRequestContext.init(id, buffer, scratch);
}

test "remote signer session connects with matching secret echo" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=abc";
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RemoteSignerRequestBuffer{};
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
        .result = .{ .value = .{ .text = "abc" } },
    });

    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());
    try std.testing.expect(outcome == .connected);
    try std.testing.expect(session.isConnected());
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer exposes caller-owned relay-pool adapter storage" {
    var relay_pool_storage = RemoteSignerRelayPoolStorage{};
    var runtime_storage = RemoteSignerRelayPoolRuntimeStorage{};
    _ = &relay_pool_storage;
    _ = &runtime_storage;
}

test "remote signer exports the shared relay-pool runtime floor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var pool_storage = RemoteSignerRelayPoolStorage{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var runtime_storage = RemoteSignerRelayPoolRuntimeStorage{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    _ = try session.acceptResponseJson(response, arena.allocator());
    try std.testing.expect(session.isConnected());

    var runtime_storage = RemoteSignerRelayPoolRuntimeStorage{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());

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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "nope" } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &request_buffer, request_scratch.allocator()),
        &.{},
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "unexpected-secret" } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var scratch_storage_a: [1024]u8 = undefined;
    var scratch_a = std.heap.FixedBufferAllocator.init(&scratch_storage_a);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, scratch_a.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginGetPublicKey(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    var wrong_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const wrong_response = try serialize_response(wrong_response_json[0..], .{
        .id = "req-9",
        .result = .{ .value = .{ .text = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var scratch_storage_a: [1024]u8 = undefined;
    var scratch_a = std.heap.FixedBufferAllocator.init(&scratch_storage_a);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, scratch_a.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var blocked_request_buffer = RemoteSignerRequestBuffer{};
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

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginPing(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );
}

test "remote signer session keeps relay blocked after invalid auth event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
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

    var blocked_request_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    const relays = [_][]const u8{ "wss://relay.three", "wss://relay.four" };
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .value = .{ .relay_list = relays[0..] } },
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
        RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator()),
    );
}

test "remote signer session keeps state unchanged on null switch relays response" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
    );

    const relays = [_][]const u8{ "https://relay.bad", "wss://relay.four" };
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .value = .{ .relay_list = relays[0..] } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var switch_request_buffer = RemoteSignerRequestBuffer{};
    var switch_scratch_storage: [1024]u8 = undefined;
    var switch_scratch = std.heap.FixedBufferAllocator.init(&switch_scratch_storage);
    _ = try session.beginSwitchRelays(
        requestContext("req-2", &switch_request_buffer, switch_scratch.allocator()),
    );

    const relays = [_][]const u8{ "wss://relay.one", "wss://relay.four" };
    var switch_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const switch_response = try serialize_response(switch_response_json[0..], .{
        .id = "req-2",
        .result = .{ .value = .{ .relay_list = relays[0..] } },
    });
    var switch_response_scratch_storage: [2048]u8 = undefined;
    var switch_response_scratch =
        std.heap.FixedBufferAllocator.init(&switch_response_scratch_storage);
    _ = try session.acceptResponseJson(switch_response, switch_response_scratch.allocator());

    try std.testing.expect(!session.isConnected());
    session.markCurrentRelayConnected();
    try session.noteCurrentRelayAuthChallenge("challenge-1");

    var blocked_request_buffer = RemoteSignerRequestBuffer{};
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

    var reconnect_request_buffer = RemoteSignerRequestBuffer{};
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
        .result = .{ .value = .{ .text = "ack" } },
    });
    var reconnect_response_scratch_storage: [2048]u8 = undefined;
    var reconnect_response_scratch =
        std.heap.FixedBufferAllocator.init(&reconnect_response_scratch_storage);
    _ = try session.acceptResponseJson(reconnect_response, reconnect_response_scratch.allocator());

    var ping_request_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    session.noteCurrentRelayDisconnected();

    var blocked_ping_buffer = RemoteSignerRequestBuffer{};
    var blocked_ping_scratch_storage: [1024]u8 = undefined;
    var blocked_ping_scratch =
        std.heap.FixedBufferAllocator.init(&blocked_ping_scratch_storage);
    try std.testing.expectError(
        error.RelayDisconnected,
        session.beginPing(
            requestContext("req-2", &blocked_ping_buffer, blocked_ping_scratch.allocator()),
        ),
    );

    var blocked_pubkey_buffer = RemoteSignerRequestBuffer{};
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

    var reconnect_request_buffer = RemoteSignerRequestBuffer{};
    var reconnect_request_scratch_storage: [1024]u8 = undefined;
    var reconnect_request_scratch =
        std.heap.FixedBufferAllocator.init(&reconnect_request_scratch_storage);
    try std.testing.expectError(
        error.SignerSessionNotConnected,
        session.beginPing(
            requestContext("req-4", &reconnect_request_buffer, reconnect_request_scratch.allocator()),
        ),
    );

    var reconnect_connect_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var ping_request_buffer = RemoteSignerRequestBuffer{};
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
        .result = .{ .value = .{ .text = "pong" } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [4096]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try session.beginSignEvent(
        requestContext("req-2", &request_buffer, request_scratch.allocator()),
        "{\"kind\":1,\"content\":\"unsigned\",\"tags\":[],\"created_at\":1}",
    );

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response = try serialize_response(response_json[0..], .{
        .id = "req-2",
        .result = .{ .value = .{ .text = "{\"kind\":1}" } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
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
        .result = .{ .value = .{ .text = invalid_signed_event_json } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = RemoteSignerPubkeyTextRequest{
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
        .result = .{ .value = .{ .text = "ciphertext" } },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());
    try std.testing.expect(outcome == .text_response);
    try std.testing.expectEqual(RemoteSignerMethod.nip04_encrypt, outcome.text_response.method);
    try std.testing.expectEqualStrings("ciphertext", outcome.text_response.text);
    try std.testing.expectEqual(@as(u8, 0), session._state.pending_count);
}

test "remote signer session accepts nip44 decrypt text responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = RemoteSignerPubkeyTextRequest{
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
        .result = .{ .value = .{ .text = "plaintext" } },
    });
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const outcome = try session.acceptResponseJson(response, response_scratch.allocator());
    try std.testing.expect(outcome == .text_response);
    try std.testing.expectEqual(RemoteSignerMethod.nip44_decrypt, outcome.text_response.method);
    try std.testing.expectEqualStrings("plaintext", outcome.text_response.text);
}

test "remote signer session blocks pubkey text methods until signer session is connected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = RemoteSignerPubkeyTextRequest{
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = RemoteSignerPubkeyTextRequest{
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
        .result = .{ .value = .{ .relay_list = &.{"wss://wrong.example"} } },
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
    var session = try RemoteSignerSession.initFromBunkerUriText(uri_text, arena.allocator());
    session.markCurrentRelayConnected();

    var connect_request_buffer = RemoteSignerRequestBuffer{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try session.beginConnect(
        requestContext("req-1", &connect_request_buffer, connect_scratch.allocator()),
        &.{},
    );

    var connect_response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response = try serialize_response(connect_response_json[0..], .{
        .id = "req-1",
        .result = .{ .value = .{ .text = "ack" } },
    });
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try session.acceptResponseJson(connect_response, connect_response_scratch.allocator());

    var request_buffer = RemoteSignerRequestBuffer{};
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const request = RemoteSignerPubkeyTextRequest{
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
