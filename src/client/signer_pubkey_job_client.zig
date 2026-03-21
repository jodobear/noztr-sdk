const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const runtime = @import("../runtime/mod.zig");
const signer_client = @import("signer_client.zig");
const signer_job_support = @import("signer_job_support.zig");
const signer_runtime_support = @import("signer_runtime_support.zig");
const workflows = @import("../workflows/mod.zig");

pub const SignerPubkeyJobClientError =
    signer_client.SignerClientError ||
    signer_job_support.SignerJobAuthError;

pub const SignerPubkeyJobClientConfig = struct {
    signer: signer_client.SignerClientConfig = .{},
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const SignerPubkeyJobClientStorage = struct {
    signer: signer_client.SignerClientStorage = .{},
    auth_state: signer_job_support.SignerJobAuthState = .{},
};

pub const SignerPubkeyJobAuthEventStorage = signer_job_support.SignerJobAuthEventStorage;
pub const PreparedSignerPubkeyJobAuthEvent = signer_job_support.PreparedSignerJobAuthEvent;
pub const SignerPubkeyJobRequest = workflows.RemoteSignerOutboundRequest;

pub const SignerPubkeyJobReady = union(enum) {
    authenticate: PreparedSignerPubkeyJobAuthEvent,
    pubkey: SignerPubkeyJobRequest,
};

pub const SignerPubkeyJobResult = union(enum) {
    authenticated: []const u8,
    pubkey: [32]u8,
};

pub const SignerPubkeyJobClient = struct {
    config: SignerPubkeyJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    signer: signer_client.SignerClient,

    pub fn init(
        config: SignerPubkeyJobClientConfig,
        signer: signer_client.SignerClient,
        storage: *SignerPubkeyJobClientStorage,
    ) SignerPubkeyJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn initFromBunkerUriText(
        config: SignerPubkeyJobClientConfig,
        storage: *SignerPubkeyJobClientStorage,
        uri_text: []const u8,
        scratch: std.mem.Allocator,
    ) SignerPubkeyJobClientError!SignerPubkeyJobClient {
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
        config: SignerPubkeyJobClientConfig,
        signer: signer_client.SignerClient,
        storage: *SignerPubkeyJobClientStorage,
    ) SignerPubkeyJobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .signer = signer,
        };
    }

    pub fn currentRelayUrl(self: *const SignerPubkeyJobClient) []const u8 {
        return self.signer.currentRelayUrl();
    }

    pub fn currentRelayCanSendRequests(self: *const SignerPubkeyJobClient) bool {
        return self.signer.currentRelayCanSendRequests();
    }

    pub fn isConnected(self: *const SignerPubkeyJobClient) bool {
        return self.signer.isConnected();
    }

    pub fn getUserPubkey(self: *const SignerPubkeyJobClient) ?[32]u8 {
        return self.signer.getUserPubkey();
    }

    pub fn lastSignerError(self: *const SignerPubkeyJobClient) ?[]const u8 {
        return self.signer.lastSignerError();
    }

    pub fn markCurrentRelayConnected(self: *SignerPubkeyJobClient) void {
        self.signer.markCurrentRelayConnected();
    }

    pub fn noteCurrentRelayDisconnected(
        self: *SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
    ) void {
        self.signer.noteCurrentRelayDisconnected();
        storage.auth_state.clear();
    }

    pub fn noteCurrentRelayAuthChallenge(
        self: *SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
        challenge: []const u8,
    ) SignerPubkeyJobClientError!void {
        return signer_runtime_support.noteCurrentRelayAuthChallenge(
            &self.signer,
            &storage.auth_state,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
    ) runtime.RelayPoolPlan {
        return signer_runtime_support.inspectRelayRuntime(&self.signer, &storage.signer);
    }

    pub fn selectRelayRuntimeStep(
        self: *SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
        step: *const runtime.RelayPoolStep,
    ) SignerPubkeyJobClientError![]const u8 {
        return signer_runtime_support.selectRelayRuntimeStep(
            &self.signer,
            &storage.auth_state,
            step,
        );
    }

    pub fn advanceRelay(
        self: *SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
    ) SignerPubkeyJobClientError![]const u8 {
        return signer_runtime_support.advanceRelay(&self.signer, &storage.auth_state);
    }

    pub fn prepareJob(
        self: *SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
        auth_storage: *SignerPubkeyJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        scratch: std.mem.Allocator,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        created_at: u64,
    ) SignerPubkeyJobClientError!SignerPubkeyJobReady {
        if (self.signer.currentRelayCanSendRequests()) {
            return .{
                .pubkey = try self.signer.beginGetPublicKey(
                    &storage.signer,
                    scratch,
                ),
            };
        }
        if (!storage.auth_state.active) {
            return .{
                .pubkey = try self.signer.beginGetPublicKey(
                    &storage.signer,
                    scratch,
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
        self: *SignerPubkeyJobClient,
        storage: *SignerPubkeyJobClientStorage,
        prepared: *const PreparedSignerPubkeyJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
        scratch: std.mem.Allocator,
    ) SignerPubkeyJobClientError!SignerPubkeyJobResult {
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

    pub fn acceptPubkeyResponseJson(
        self: *SignerPubkeyJobClient,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) SignerPubkeyJobClientError!SignerPubkeyJobResult {
        const result = try self.signer.acceptResponseJson(response_json, scratch);
        std.debug.assert(result == .user_pubkey);
        return .{ .pubkey = result.user_pubkey };
    }
};

test "signer pubkey job client exposes caller-owned config and storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = SignerPubkeyJobClientStorage{};
    var client = try SignerPubkeyJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("wss://relay.one", client.currentRelayUrl());
    try std.testing.expectEqual(@as(u64, 0), storage.signer.request.request_sequence);
}

test "signer pubkey job client prepares ready pubkey work after an explicit connect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = SignerPubkeyJobClientStorage{};
    var client = try SignerPubkeyJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());

    const secret_key = [_]u8{0xa1} ** 32;
    var auth_storage = SignerPubkeyJobAuthEventStorage{};
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
        90,
    );
    try std.testing.expect(ready == .pubkey);

    const user_pubkey = [_]u8{0x31} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const result = try client.acceptPubkeyResponseJson(
        try textResponse(response_json[0..], "signer-2", user_pubkey_hex[0..]),
        arena.allocator(),
    );
    try std.testing.expect(result == .pubkey);
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &result.pubkey));
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &client.getUserPubkey().?));
}

test "signer pubkey job client drives auth-gated pubkey progression through one job surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const noztr = @import("noztr");
    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = SignerPubkeyJobClientStorage{};
    var client = try SignerPubkeyJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());
    try client.noteCurrentRelayAuthChallenge(&storage, "challenge-2");

    const secret_key = [_]u8{0xa2} ** 32;
    var auth_storage = SignerPubkeyJobAuthEventStorage{};
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
        91,
    );
    try std.testing.expect(second_ready == .pubkey);

    const user_pubkey = [_]u8{0x32} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var response_json: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const pubkey_result = try client.acceptPubkeyResponseJson(
        try textResponse(response_json[0..], "signer-2", user_pubkey_hex[0..]),
        arena.allocator(),
    );
    try std.testing.expect(pubkey_result == .pubkey);
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &pubkey_result.pubkey));
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
