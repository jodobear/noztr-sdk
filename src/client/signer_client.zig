const std = @import("std");
const runtime = @import("../runtime/mod.zig");
const workflows = @import("../workflows/mod.zig");
const signer_capability = @import("signer_capability.zig");

pub const signer_client_request_id_max_bytes: u8 = 32;

pub const SignerClientError = workflows.signer.remote.Error;
pub const SignerClientCapabilityError = SignerClientError || error{
    UnexpectedCapabilityOutcome,
};

pub const SignerClientConfig = struct {};

pub const SignerClientRequestStorage = struct {
    buffer: workflows.signer.remote.RequestBuffer = .{},
    request_id: [signer_client_request_id_max_bytes]u8 =
        [_]u8{0} ** signer_client_request_id_max_bytes,
    request_sequence: u64 = 0,

    /// The returned request context borrows both the generated id and serialized request buffer
    /// until the next call overwrites this storage.
    pub fn nextRequestContext(
        self: *SignerClientRequestStorage,
        scratch: std.mem.Allocator,
    ) workflows.signer.remote.RequestContext {
        return .init(self.nextRequestId(), &self.buffer, scratch);
    }

    fn nextRequestId(self: *SignerClientRequestStorage) []const u8 {
        self.request_sequence += 1;
        @memset(self.request_id[0..], 0);
        return std.fmt.bufPrint(
            self.request_id[0..],
            "signer-{d}",
            .{self.request_sequence},
        ) catch unreachable;
    }
};

pub const SignerClientStorage = struct {
    request: SignerClientRequestStorage = .{},
    relay_runtime: workflows.signer.remote.RelayRuntimeStorage = .{},
};

pub const SignerClientResumeStorage = workflows.signer.remote.ResumeStorage;
pub const SignerClientResumeState = workflows.signer.remote.ResumeState;
pub const SignerClientSessionPolicyAction = workflows.signer.remote.PolicyAction;
pub const SignerClientSessionPolicyStep = workflows.signer.remote.PolicyStep;
pub const SignerClientSessionPolicyPlan = workflows.signer.remote.PolicyPlan;
pub const SignerClientSessionCadenceRequest = workflows.signer.remote.CadenceRequest;
pub const SignerClientSessionCadenceWaitReason = workflows.signer.remote.CadenceWaitReason;
pub const SignerClientSessionCadenceWait = workflows.signer.remote.CadenceWait;
pub const SignerClientSessionCadenceStep = workflows.signer.remote.CadenceStep;
pub const SignerClientSessionCadencePlan = workflows.signer.remote.CadencePlan;

pub const SignerClient = struct {
    config: SignerClientConfig,
    session: workflows.signer.remote.Session,

    pub fn init(
        config: SignerClientConfig,
        session: workflows.signer.remote.Session,
    ) SignerClient {
        return .{
            .config = config,
            .session = session,
        };
    }

    pub fn initFromBunkerUriText(
        config: SignerClientConfig,
        uri_text: []const u8,
        scratch: std.mem.Allocator,
    ) SignerClientError!SignerClient {
        return .{
            .config = config,
            .session = try workflows.signer.remote.Session.initFromBunkerUriText(uri_text, scratch),
        };
    }

    pub fn currentRelayUrl(self: *const SignerClient) []const u8 {
        return self.session.currentRelayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const SignerClient) bool {
        return self.session.currentRelayCanSendRequests();
    }

    pub fn isConnected(self: *const SignerClient) bool {
        return self.session.isConnected();
    }

    pub fn remoteSignerPubkey(self: *const SignerClient) [32]u8 {
        return self.session.remoteSignerPubkey();
    }

    pub fn getUserPubkey(self: *const SignerClient) ?[32]u8 {
        return self.session.getUserPubkey();
    }

    pub fn signerCapabilityProfile(
        self: *const SignerClient,
    ) signer_capability.SignerCapabilityProfile {
        _ = self;
        return .remoteSigner();
    }

    pub fn lastSignerError(self: *const SignerClient) ?[]const u8 {
        return self.session.lastSignerError();
    }

    pub fn markCurrentRelayConnected(self: *SignerClient) void {
        self.session.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(self: *SignerClient) void {
        self.session.noteCurrentRelayDisconnected();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *SignerClient,
        challenge: []const u8,
    ) SignerClientError!void {
        try self.session.noteCurrentRelayAuthChallenge(challenge);
    }

    pub fn acceptCurrentRelayAuthEventJson(
        self: *SignerClient,
        auth_event_json: []const u8,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) SignerClientError!void {
        try self.session.acceptCurrentRelayAuthEventJson(
            auth_event_json,
            now_unix_seconds,
            window_seconds,
            scratch,
        );
    }

    pub fn advanceRelay(self: *SignerClient) SignerClientError![]const u8 {
        return self.session.advanceRelay();
    }

    pub fn inspectRelayRuntime(
        self: *const SignerClient,
        storage: *SignerClientStorage,
    ) runtime.RelayPoolPlan {
        return self.session.inspectRelayPoolRuntime(&storage.relay_runtime);
    }

    pub fn exportResumeState(
        self: *const SignerClient,
        storage: *SignerClientResumeStorage,
    ) SignerClientError!SignerClientResumeState {
        return self.session.exportResumeState(storage);
    }

    pub fn restoreResumeState(
        self: *SignerClient,
        state: *const SignerClientResumeState,
    ) SignerClientError!void {
        return self.session.restoreResumeState(state);
    }

    pub fn inspectSessionPolicy(self: *const SignerClient) SignerClientSessionPolicyPlan {
        return self.session.inspectSessionPolicy();
    }

    pub fn inspectSessionCadence(
        self: *const SignerClient,
        request: SignerClientSessionCadenceRequest,
    ) SignerClientSessionCadencePlan {
        return self.session.inspectSessionCadence(request);
    }

    pub fn selectRelayRuntimeStep(
        self: *SignerClient,
        step: *const runtime.RelayPoolStep,
    ) SignerClientError![]const u8 {
        return self.session.selectRelayPoolStep(step);
    }

    pub fn beginConnect(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        requested_permissions: []const workflows.signer.remote.Permission,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginConnect(
            storage.request.nextRequestContext(scratch),
            requested_permissions,
        );
    }

    pub fn beginGetPublicKey(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginGetPublicKey(storage.request.nextRequestContext(scratch));
    }

    pub fn beginSignEvent(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        unsigned_event_json: []const u8,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginSignEvent(
            storage.request.nextRequestContext(scratch),
            unsigned_event_json,
        );
    }

    pub fn beginSwitchRelays(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginSwitchRelays(storage.request.nextRequestContext(scratch));
    }

    pub fn beginNip04Encrypt(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        request: *const workflows.signer.remote.PubkeyTextRequest,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginNip04Encrypt(
            storage.request.nextRequestContext(scratch),
            request,
        );
    }

    pub fn beginNip04Decrypt(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        request: *const workflows.signer.remote.PubkeyTextRequest,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginNip04Decrypt(
            storage.request.nextRequestContext(scratch),
            request,
        );
    }

    pub fn beginNip44Encrypt(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        request: *const workflows.signer.remote.PubkeyTextRequest,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginNip44Encrypt(
            storage.request.nextRequestContext(scratch),
            request,
        );
    }

    pub fn beginNip44Decrypt(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        request: *const workflows.signer.remote.PubkeyTextRequest,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginNip44Decrypt(
            storage.request.nextRequestContext(scratch),
            request,
        );
    }

    pub fn beginPing(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return self.session.beginPing(storage.request.nextRequestContext(scratch));
    }

    pub fn beginSignerCapabilityOperation(
        self: *SignerClient,
        storage: *SignerClientStorage,
        scratch: std.mem.Allocator,
        request: *const signer_capability.SignerOperationRequest,
    ) SignerClientError!workflows.signer.remote.OutboundRequest {
        return switch (request.*) {
            .get_public_key => self.beginGetPublicKey(storage, scratch),
            .sign_event => |unsigned_event_json| self.beginSignEvent(
                storage,
                scratch,
                unsigned_event_json,
            ),
            .nip04_encrypt => |value| self.beginNip04Encrypt(storage, scratch, &value),
            .nip04_decrypt => |value| self.beginNip04Decrypt(storage, scratch, &value),
            .nip44_encrypt => |value| self.beginNip44Encrypt(storage, scratch, &value),
            .nip44_decrypt => |value| self.beginNip44Decrypt(storage, scratch, &value),
        };
    }

    pub fn acceptResponseJson(
        self: *SignerClient,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) SignerClientError!workflows.signer.remote.ResponseOutcome {
        return self.session.acceptResponseJson(response_json, scratch);
    }

    pub fn acceptSignerCapabilityResponseJson(
        self: *SignerClient,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) SignerClientCapabilityError!signer_capability.SignerOperationResult {
        const outcome = try self.acceptResponseJson(response_json, scratch);
        return switch (outcome) {
            .user_pubkey => |pubkey| .{ .user_pubkey = pubkey },
            .signed_event_json => |signed_event_json| .{ .signed_event_json = signed_event_json },
            .text_response => |response| .{
                .text_response = .{
                    .operation = capabilityOperationFromRemoteMethod(response.method) orelse
                        return error.UnexpectedCapabilityOutcome,
                    .text = response.text,
                },
            },
            .connected,
            .pong,
            .relays_switched,
            => error.UnexpectedCapabilityOutcome,
        };
    }
};

fn capabilityOperationFromRemoteMethod(
    method: workflows.signer.remote.Method,
) ?signer_capability.SignerOperation {
    return switch (method) {
        .get_public_key => .get_public_key,
        .sign_event => .sign_event,
        .nip04_encrypt => .nip04_encrypt,
        .nip04_decrypt => .nip04_decrypt,
        .nip44_encrypt => .nip44_encrypt,
        .nip44_decrypt => .nip44_decrypt,
        else => null,
    };
}

test "signer client request storage generates sequential bounded request ids" {
    var storage = SignerClientRequestStorage{};
    var scratch_bytes: [32]u8 = undefined;
    var scratch = std.heap.FixedBufferAllocator.init(&scratch_bytes);

    const first = storage.nextRequestContext(scratch.allocator());
    try std.testing.expectEqualStrings("signer-1", first.id);

    const second = storage.nextRequestContext(scratch.allocator());
    try std.testing.expectEqualStrings("signer-2", second.id);
    try std.testing.expectEqual(@as(u64, 2), storage.request_sequence);
}

test "signer client composes connect get_public_key and nip44 encrypt without caller ids" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var client = try SignerClient.initFromBunkerUriText(.{}, bunker_uri, arena.allocator());
    client.markCurrentRelayConnected();

    var storage = SignerClientStorage{};

    var connect_scratch_bytes: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_bytes);
    const outbound_connect = try client.beginConnect(
        &storage,
        connect_scratch.allocator(),
        &.{.{ .method = .get_public_key }},
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_connect.json, "\"id\":\"signer-1\"") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_connect.json, "\"method\":\"connect\"") != null,
    );

    var connect_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var connect_response_scratch_bytes: [2048]u8 = undefined;
    var connect_response_scratch = std.heap.FixedBufferAllocator.init(&connect_response_scratch_bytes);
    const connect_outcome = try client.acceptResponseJson(
        try serializeResponseJson(connect_response_json[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = "secret" } },
        }),
        connect_response_scratch.allocator(),
    );
    try std.testing.expect(connect_outcome == .connected);
    try std.testing.expect(client.isConnected());

    var pubkey_scratch_bytes: [1024]u8 = undefined;
    var pubkey_scratch = std.heap.FixedBufferAllocator.init(&pubkey_scratch_bytes);
    const outbound_pubkey = try client.beginGetPublicKey(&storage, pubkey_scratch.allocator());
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_pubkey.json, "\"id\":\"signer-2\"") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_pubkey.json, "\"method\":\"get_public_key\"") != null,
    );

    const user_pubkey = [_]u8{0x11} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var pubkey_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var pubkey_response_scratch_bytes: [2048]u8 = undefined;
    var pubkey_response_scratch = std.heap.FixedBufferAllocator.init(&pubkey_response_scratch_bytes);
    const pubkey_outcome = try client.acceptResponseJson(
        try textResponse(pubkey_response_json[0..], "signer-2", user_pubkey_hex[0..]),
        pubkey_response_scratch.allocator(),
    );
    try std.testing.expect(pubkey_outcome == .user_pubkey);
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &pubkey_outcome.user_pubkey));

    const peer_pubkey = [_]u8{0x22} ** 32;
    var nip44_scratch_bytes: [1024]u8 = undefined;
    var nip44_scratch = std.heap.FixedBufferAllocator.init(&nip44_scratch_bytes);
    const outbound_nip44 = try client.beginNip44Encrypt(
        &storage,
        nip44_scratch.allocator(),
        &.{ .pubkey = peer_pubkey, .text = "hello" },
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_nip44.json, "\"id\":\"signer-3\"") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_nip44.json, "\"method\":\"nip44_encrypt\"") != null,
    );

    var nip44_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var nip44_response_scratch_bytes: [2048]u8 = undefined;
    var nip44_response_scratch = std.heap.FixedBufferAllocator.init(&nip44_response_scratch_bytes);
    const nip44_outcome = try client.acceptResponseJson(
        try textResponse(nip44_response_json[0..], "signer-3", "ciphertext"),
        nip44_response_scratch.allocator(),
    );
    try std.testing.expect(nip44_outcome == .text_response);
    try std.testing.expectEqual(.nip44_encrypt, nip44_outcome.text_response.method);
    try std.testing.expectEqualStrings("ciphertext", nip44_outcome.text_response.text);
}

test "signer client keeps relay runtime inspection explicit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var client = try SignerClient.initFromBunkerUriText(.{}, bunker_uri, arena.allocator());
    client.markCurrentRelayConnected();

    var storage = SignerClientStorage{};
    const runtime_plan = client.inspectRelayRuntime(&storage);
    try std.testing.expectEqual(@as(u8, 2), runtime_plan.relay_count);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.connect_count);

    const relay_two_step = runtime.RelayPoolStep{
        .entry = runtime_plan.entry(1).?,
    };
    const selected = try client.selectRelayRuntimeStep(&relay_two_step);
    try std.testing.expectEqualStrings("wss://relay.two", selected);
    try std.testing.expectEqualStrings("wss://relay.two", client.currentRelayUrl());
    try std.testing.expect(!client.isConnected());
}

test "signer client restores durable resume state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two";
    var client = try SignerClient.initFromBunkerUriText(.{}, bunker_uri, arena.allocator());
    client.markCurrentRelayConnected();
    var storage = SignerClientStorage{};

    var connect_scratch_bytes: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_bytes);
    _ = try client.beginConnect(&storage, connect_scratch.allocator(), &.{});

    var connect_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var connect_response_scratch_bytes: [2048]u8 = undefined;
    var connect_response_scratch = std.heap.FixedBufferAllocator.init(&connect_response_scratch_bytes);
    _ = try client.acceptResponseJson(
        try serializeResponseJson(connect_response_json[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = "ack" } },
        }),
        connect_response_scratch.allocator(),
    );

    var switch_scratch_bytes: [1024]u8 = undefined;
    var switch_scratch = std.heap.FixedBufferAllocator.init(&switch_scratch_bytes);
    _ = try client.beginSwitchRelays(&storage, switch_scratch.allocator());

    const next_relays = [_][]const u8{ "wss://relay.three", "wss://relay.four" };
    var switch_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var switch_response_scratch_bytes: [2048]u8 = undefined;
    var switch_response_scratch = std.heap.FixedBufferAllocator.init(&switch_response_scratch_bytes);
    _ = try client.acceptResponseJson(
        try serializeResponseJson(switch_response_json[0..], .{
            .id = "signer-2",
            .result = .{ .value = .{ .relay_list = next_relays[0..] } },
        }),
        switch_response_scratch.allocator(),
    );

    var resume_storage = SignerClientResumeStorage{};
    const resume_state = try client.exportResumeState(&resume_storage);

    var restored = try SignerClient.initFromBunkerUriText(.{}, bunker_uri, arena.allocator());
    try restored.restoreResumeState(&resume_state);
    try std.testing.expectEqualStrings("wss://relay.three", restored.currentRelayUrl());
    try std.testing.expect(!restored.isConnected());
    try std.testing.expectEqual(
        SignerClientSessionPolicyAction.connect_relay,
        restored.inspectSessionPolicy().action,
    );
}

test "signer client exposes session cadence parity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one";
    const client = try SignerClient.initFromBunkerUriText(.{}, bunker_uri, arena.allocator());

    const cadence = client.inspectSessionCadence(.{
        .now_unix_seconds = 10,
        .reconnect_not_before_unix_seconds = 20,
    });
    try std.testing.expect(cadence.nextStep() == .wait);
    try std.testing.expectEqual(
        SignerClientSessionCadenceWaitReason.reconnect_backoff,
        cadence.nextStep().wait.reason,
    );
}

test "signer client adapts onto the signer capability surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var client = try SignerClient.initFromBunkerUriText(.{}, bunker_uri, arena.allocator());
    client.markCurrentRelayConnected();

    const capability = client.signerCapabilityProfile();
    try std.testing.expectEqual(.remote, capability.backend);
    try std.testing.expectEqual(.caller_driven_request, capability.modeFor(.get_public_key));
    try std.testing.expectEqual(.caller_driven_request, capability.modeFor(.nip04_encrypt));

    var storage = SignerClientStorage{};

    var connect_scratch_bytes: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_bytes);
    _ = try client.beginConnect(&storage, connect_scratch.allocator(), &.{});

    var connect_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var connect_response_scratch_bytes: [2048]u8 = undefined;
    var connect_response_scratch = std.heap.FixedBufferAllocator.init(&connect_response_scratch_bytes);
    _ = try client.acceptResponseJson(
        try serializeResponseJson(connect_response_json[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = "secret" } },
        }),
        connect_response_scratch.allocator(),
    );

    const get_public_key_request: signer_capability.SignerOperationRequest = .{ .get_public_key = {} };
    var pubkey_scratch_bytes: [1024]u8 = undefined;
    var pubkey_scratch = std.heap.FixedBufferAllocator.init(&pubkey_scratch_bytes);
    const outbound_pubkey = try client.beginSignerCapabilityOperation(
        &storage,
        pubkey_scratch.allocator(),
        &get_public_key_request,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_pubkey.json, "\"method\":\"get_public_key\"") != null,
    );

    const user_pubkey = [_]u8{0x44} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var pubkey_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var pubkey_response_scratch_bytes: [2048]u8 = undefined;
    var pubkey_response_scratch = std.heap.FixedBufferAllocator.init(&pubkey_response_scratch_bytes);
    const pubkey_result = try client.acceptSignerCapabilityResponseJson(
        try textResponse(pubkey_response_json[0..], "signer-2", user_pubkey_hex[0..]),
        pubkey_response_scratch.allocator(),
    );
    try std.testing.expect(get_public_key_request.acceptsResult(&pubkey_result));

    var unexpected_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var unexpected_response_scratch_bytes: [2048]u8 = undefined;
    var unexpected_response_scratch = std.heap.FixedBufferAllocator.init(
        &unexpected_response_scratch_bytes,
    );
    try std.testing.expectError(
        error.UnknownResponseId,
        client.acceptSignerCapabilityResponseJson(
            try serializeResponseJson(unexpected_response_json[0..], .{
                .id = "signer-99",
                .result = .{ .value = .{ .text = "secret" } },
            }),
            unexpected_response_scratch.allocator(),
        ),
    );

    var ping_scratch_bytes: [1024]u8 = undefined;
    var ping_scratch = std.heap.FixedBufferAllocator.init(&ping_scratch_bytes);
    _ = try client.beginPing(&storage, ping_scratch.allocator());

    var pong_response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    var pong_response_scratch_bytes: [2048]u8 = undefined;
    var pong_response_scratch = std.heap.FixedBufferAllocator.init(&pong_response_scratch_bytes);
    try std.testing.expectError(
        error.UnexpectedCapabilityOutcome,
        client.acceptSignerCapabilityResponseJson(
            try serializeResponseJson(pong_response_json[0..], .{
                .id = "signer-3",
                .result = .{ .value = .{ .text = "pong" } },
            }),
            pong_response_scratch.allocator(),
        ),
    );
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
    response: @import("noztr").nip46_remote_signing.Response,
) workflows.signer.remote.Error![]const u8 {
    return @import("noztr").nip46_remote_signing.message_serialize_json(
        output,
        .{ .response = response },
    );
}
