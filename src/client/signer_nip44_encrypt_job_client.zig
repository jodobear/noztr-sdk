const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const signer_client = @import("signer_client.zig");
const signer_job_support = @import("signer_job_support.zig");
const signer_runtime_support = @import("signer_runtime_support.zig");
const workflows = @import("../workflows/mod.zig");

pub const Error =
    signer_client.Error ||
    signer_job_support.SignerJobAuthError;

pub const Config = struct {
    signer: signer_client.Config = .{},
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const Storage = struct {
    signer: signer_client.Storage = .{},
    auth_state: signer_job_support.SignerJobAuthState = .{},
};

pub const AuthEventStorage = signer_job_support.SignerJobAuthEventStorage;
pub const PreparedAuthEvent = signer_job_support.PreparedSignerJobAuthEvent;
pub const Request = workflows.signer.remote.OutboundRequest;

pub const Ready = union(enum) {
    authenticate: PreparedAuthEvent,
    encrypt: Request,
};

pub const Result = union(enum) {
    authenticated: []const u8,
    ciphertext: []const u8,
};

pub const Client = struct {
    config: Config,
    local_operator: local_operator.LocalOperatorClient,
    signer: signer_client.Client,

    pub fn init(
        config: Config,
        signer: signer_client.Client,
        storage: *Storage,
    ) Client {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn initFromBunkerUriText(
        config: Config,
        storage: *Storage,
        uri_text: []const u8,
        scratch: std.mem.Allocator,
    ) Error!Client {
        return .init(
            config,
            try signer_client.Client.initFromBunkerUriText(
                config.signer,
                uri_text,
                scratch,
            ),
            storage,
        );
    }

    pub fn attach(
        config: Config,
    signer: signer_client.Client,
        storage: *Storage,
    ) Client {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn currentRelayUrl(self: *const Client) []const u8 {
        return self.signer.currentRelayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const Client) bool {
        return self.signer.currentRelayCanSendRequests();
    }

    pub fn isConnected(self: *const Client) bool {
        return self.signer.isConnected();
    }

    pub fn lastSignerError(self: *const Client) ?[]const u8 {
        return self.signer.lastSignerError();
    }

    pub fn markCurrentRelayConnected(self: *Client) void {
        self.signer.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(
        self: *Client,
        storage: *Storage,
    ) void {
        self.signer.noteCurrentRelayDisconnected();
        storage.auth_state.clear();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *Client,
        storage: *Storage,
        challenge: []const u8,
    ) Error!void {
        return signer_runtime_support.noteCurrentRelayAuthChallenge(
            &self.signer,
            &storage.auth_state,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const Client,
        storage: *Storage,
    ) runtime.RelayPoolPlan {
        return signer_runtime_support.inspectRelayRuntime(&self.signer, &storage.signer);
    }

    pub fn selectRelayRuntimeStep(
        self: *Client,
        storage: *Storage,
        step: *const runtime.RelayPoolStep,
    ) Error![]const u8 {
        return signer_runtime_support.selectRelayRuntimeStep(
            &self.signer,
            &storage.auth_state,
            step,
        );
    }

    pub fn advanceRelay(
        self: *Client,
        storage: *Storage,
    ) Error![]const u8 {
        return signer_runtime_support.advanceRelay(&self.signer, &storage.auth_state);
    }

    pub fn prepareJob(
        self: *Client,
        storage: *Storage,
        auth_storage: *AuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        scratch: std.mem.Allocator,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        request: *const workflows.signer.remote.PubkeyTextRequest,
        created_at: u64,
    ) Error!Ready {
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
        self: *Client,
        storage: *Storage,
        prepared: *const PreparedAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) Error!Result {
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
        self: *Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!Result {
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
    var storage = Storage{};
    var client = try Client.initFromBunkerUriText(
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
    var storage = Storage{};
    var client = try Client.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());

    const secret_key = [_]u8{0xb1} ** 32;
    const peer_pubkey = [_]u8{0x44} ** 32;
    var auth_storage = AuthEventStorage{};
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
    var storage = Storage{};
    var client = try Client.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());
    try client.noteCurrentRelayAuthChallenge(&storage, "challenge-3");

    const secret_key = [_]u8{0xb2} ** 32;
    const peer_pubkey = [_]u8{0x55} ** 32;
    var auth_storage = AuthEventStorage{};
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
    signer: *signer_client.Client,
    storage: *signer_client.Storage,
    secret_text: []const u8,
    scratch: std.mem.Allocator,
) workflows.signer.remote.Error!void {
    signer.markCurrentRelayConnected();

    var request_scratch_bytes: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_bytes);
    _ = try signer.beginConnect(storage, request_scratch.allocator(), &.{});

    var response_json: [@import("noztr").limits.nip46_message_json_bytes_max]u8 = undefined;
    _ = try signer.acceptResponseJson(
        try serializeResponseJson(response_json[0..], .{
            .id = "signer-1",
            .result = .{ .text = secret_text },
        }),
        scratch,
    );
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) workflows.signer.remote.Error![]const u8 {
    return serializeResponseJson(output, .{
        .id = id,
        .result = .{ .text = text },
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
