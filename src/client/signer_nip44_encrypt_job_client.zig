const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const signer_client = @import("signer_client.zig");
const signer_job_support = @import("signer_job_support.zig");
const workflows = @import("../workflows/mod.zig");

pub const SignerNip44EncryptJobClientError =
    signer_client.SignerClientError ||
    signer_job_support.SignerJobAuthError;

pub const SignerNip44EncryptJobClientConfig = struct {
    signer: signer_client.SignerClientConfig = .{},
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const SignerNip44EncryptJobClientStorage = struct {
    signer: signer_client.SignerClientStorage = .{},
    auth_state: signer_job_support.SignerJobAuthState = .{},
};

pub const SignerNip44EncryptJobAuthEventStorage = signer_job_support.SignerJobAuthEventStorage;
pub const PreparedSignerNip44EncryptJobAuthEvent = signer_job_support.PreparedSignerJobAuthEvent;
pub const SignerNip44EncryptJobRequest = workflows.RemoteSignerOutboundRequest;

pub const SignerNip44EncryptJobReady = union(enum) {
    authenticate: PreparedSignerNip44EncryptJobAuthEvent,
    encrypt: SignerNip44EncryptJobRequest,
};

pub const SignerNip44EncryptJobResult = union(enum) {
    authenticated: []const u8,
    ciphertext: []const u8,
};

pub const SignerNip44EncryptJobClient = struct {
    config: SignerNip44EncryptJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    signer: signer_client.SignerClient,

    pub fn init(
        config: SignerNip44EncryptJobClientConfig,
        signer: signer_client.SignerClient,
        storage: *SignerNip44EncryptJobClientStorage,
    ) SignerNip44EncryptJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn initFromBunkerUriText(
        config: SignerNip44EncryptJobClientConfig,
        storage: *SignerNip44EncryptJobClientStorage,
        uri_text: []const u8,
        scratch: std.mem.Allocator,
    ) SignerNip44EncryptJobClientError!SignerNip44EncryptJobClient {
        return .init(
            config,
            try signer_client.SignerClient.initFromBunkerUriText(
                config.signer,
                uri_text,
                scratch,
            ),
            storage,
        );
    }

    pub fn attach(
        config: SignerNip44EncryptJobClientConfig,
        signer: signer_client.SignerClient,
        storage: *SignerNip44EncryptJobClientStorage,
    ) SignerNip44EncryptJobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn currentRelayUrl(self: *const SignerNip44EncryptJobClient) []const u8 {
        return self.signer.currentRelayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const SignerNip44EncryptJobClient) bool {
        return self.signer.currentRelayCanSendRequests();
    }

    pub fn isConnected(self: *const SignerNip44EncryptJobClient) bool {
        return self.signer.isConnected();
    }

    pub fn lastSignerError(self: *const SignerNip44EncryptJobClient) ?[]const u8 {
        return self.signer.lastSignerError();
    }

    pub fn markCurrentRelayConnected(self: *SignerNip44EncryptJobClient) void {
        self.signer.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(
        self: *SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
    ) void {
        self.signer.noteCurrentRelayDisconnected();
        storage.auth_state.clear();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
        challenge: []const u8,
    ) SignerNip44EncryptJobClientError!void {
        try self.signer.noteCurrentRelayAuthChallenge(challenge);
        storage.auth_state.remember(self.signer.currentRelayUrl(), challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
    ) runtime.RelayPoolPlan {
        return self.signer.inspectRelayRuntime(&storage.signer);
    }

    pub fn selectRelayRuntimeStep(
        self: *SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
        step: *const runtime.RelayPoolStep,
    ) SignerNip44EncryptJobClientError![]const u8 {
        const relay_url = try self.signer.selectRelayRuntimeStep(step);
        storage.auth_state.clear();
        return relay_url;
    }

    pub fn advanceRelay(
        self: *SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
    ) SignerNip44EncryptJobClientError![]const u8 {
        const relay_url = try self.signer.advanceRelay();
        storage.auth_state.clear();
        return relay_url;
    }

    pub fn prepareJob(
        self: *SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
        auth_storage: *SignerNip44EncryptJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        scratch: std.mem.Allocator,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        request: *const workflows.RemoteSignerPubkeyTextRequest,
        created_at: u64,
    ) SignerNip44EncryptJobClientError!SignerNip44EncryptJobReady {
        if (self.signer.currentRelayCanSendRequests()) {
            return .{
                .encrypt = try self.signer.beginNip44Encrypt(
                    &storage.signer,
                    scratch,
                    request,
                ),
            };
        }
        if (!storage.auth_state.active) {
            return .{
                .encrypt = try self.signer.beginNip44Encrypt(
                    &storage.signer,
                    scratch,
                    request,
                ),
            };
        }
        try signer_job_support.requireCurrentAuthState(
            &storage.auth_state,
            self.signer.currentRelayUrl(),
            storage.auth_state.challengeText(),
        );
        return .{
            .authenticate = try signer_job_support.prepareAuthEvent(
                &self.local_operator,
                &storage.auth_state,
                auth_storage,
                event_json_output,
                auth_message_output,
                secret_key,
                created_at,
            ),
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *SignerNip44EncryptJobClient,
        storage: *SignerNip44EncryptJobClientStorage,
        prepared: *const PreparedSignerNip44EncryptJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) SignerNip44EncryptJobClientError!SignerNip44EncryptJobResult {
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
        return .{ .authenticated = prepared.relay_url };
    }

    pub fn acceptEncryptResponseJson(
        self: *SignerNip44EncryptJobClient,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) SignerNip44EncryptJobClientError!SignerNip44EncryptJobResult {
        const result = try self.signer.acceptResponseJson(response_json, scratch);
        std.debug.assert(result == .text_response);
        std.debug.assert(result.text_response.method == .nip44_encrypt);
        return .{ .ciphertext = result.text_response.text };
    }
};

test "signer nip44 encrypt job client exposes caller-owned config and storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = SignerNip44EncryptJobClientStorage{};
    var client = try SignerNip44EncryptJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("wss://relay.one", client.currentRelayUrl());
    try std.testing.expectEqual(@as(u64, 0), storage.signer.request.request_sequence);
}

test "signer nip44 encrypt job client prepares ready encrypt work after an explicit connect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = SignerNip44EncryptJobClientStorage{};
    var client = try SignerNip44EncryptJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());

    const secret_key = [_]u8{0xb1} ** 32;
    const peer_pubkey = [_]u8{0x44} ** 32;
    var auth_storage = SignerNip44EncryptJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_scratch_bytes: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_bytes);
    const ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_scratch.allocator(),
        &secret_key,
        &.{ .pubkey = peer_pubkey, .text = "hello" },
        90,
    );
    try std.testing.expect(ready == .encrypt);

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const result = try client.acceptEncryptResponseJson(
        try textResponse(response_json[0..], "signer-2", "ciphertext"),
        arena.allocator(),
    );
    try std.testing.expect(result == .ciphertext);
    try std.testing.expectEqualStrings("ciphertext", result.ciphertext);
}

test "signer nip44 encrypt job client drives auth-gated encrypt progression through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = SignerNip44EncryptJobClientStorage{};
    var client = try SignerNip44EncryptJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());
    try client.noteCurrentRelayAuthChallenge(&storage, "challenge-3");

    const secret_key = [_]u8{0xb2} ** 32;
    const peer_pubkey = [_]u8{0x55} ** 32;
    var auth_storage = SignerNip44EncryptJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var first_scratch_bytes: [1024]u8 = undefined;
    var first_scratch = std.heap.FixedBufferAllocator.init(&first_scratch_bytes);
    const first_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        first_scratch.allocator(),
        &secret_key,
        &.{ .pubkey = peer_pubkey, .text = "hello" },
        91,
    );
    try std.testing.expect(first_ready == .authenticate);
    try std.testing.expect(
        std.mem.startsWith(u8, first_ready.authenticate.auth_message_json, "[\"AUTH\","),
    );

    const auth_result = try client.acceptPreparedAuthEvent(
        &storage,
        &first_ready.authenticate,
        95,
        60,
        arena.allocator(),
    );
    try std.testing.expect(auth_result == .authenticated);

    var second_scratch_bytes: [1024]u8 = undefined;
    var second_scratch = std.heap.FixedBufferAllocator.init(&second_scratch_bytes);
    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        second_scratch.allocator(),
        &secret_key,
        &.{ .pubkey = peer_pubkey, .text = "hello" },
        91,
    );
    try std.testing.expect(second_ready == .encrypt);

    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const encrypt_result = try client.acceptEncryptResponseJson(
        try textResponse(response_json[0..], "signer-2", "ciphertext-2"),
        arena.allocator(),
    );
    try std.testing.expect(encrypt_result == .ciphertext);
    try std.testing.expectEqualStrings("ciphertext-2", encrypt_result.ciphertext);
}

fn establishSignerSession(
    signer: *signer_client.SignerClient,
    storage: *signer_client.SignerClientStorage,
    secret_text: []const u8,
    scratch: std.mem.Allocator,
) workflows.RemoteSignerError!void {
    signer.markCurrentRelayConnected();

    var request_scratch_bytes: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_bytes);
    _ = try signer.beginConnect(storage, request_scratch.allocator(), &.{});

    var response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    _ = try signer.acceptResponseJson(
        try serializeResponseJson(response_json[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = secret_text } },
        }),
        scratch,
    );
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) workflows.RemoteSignerError![]const u8 {
    return serializeResponseJson(output, .{
        .id = id,
        .result = .{ .value = .{ .text = text } },
    });
}

fn serializeResponseJson(
    output: []u8,
    response: @import("noztr").nip46_remote_signing.Response,
) workflows.RemoteSignerError![]const u8 {
    return @import("noztr").nip46_remote_signing.message_serialize_json(
        output,
        .{ .response = response },
    );
}
