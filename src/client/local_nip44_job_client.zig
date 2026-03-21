const std = @import("std");
const local_operator = @import("local_operator_client.zig");

pub const LocalNip44JobClientError = local_operator.LocalOperatorClientError;

pub const LocalNip44JobClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const LocalNip44JobClientStorage = struct {};

pub const LocalNip44JobRequest = union(enum) {
    encrypt: struct {
        secret_key: [local_operator.secret_key_bytes]u8,
        peer_public_key: [local_operator.public_key_bytes]u8,
        plaintext: []const u8,
        nonce: ?[32]u8 = null,
    },
    decrypt: struct {
        secret_key: [local_operator.secret_key_bytes]u8,
        peer_public_key: [local_operator.public_key_bytes]u8,
        payload: []const u8,
    },
};

pub const LocalNip44JobResult = union(enum) {
    ciphertext: []const u8,
    plaintext: []const u8,
};

pub const LocalNip44JobClient = struct {
    config: LocalNip44JobClientConfig,
    local_operator: local_operator.LocalOperatorClient,

    pub fn init(
        config: LocalNip44JobClientConfig,
        storage: *LocalNip44JobClientStorage,
    ) LocalNip44JobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn attach(
        config: LocalNip44JobClientConfig,
        storage: *LocalNip44JobClientStorage,
    ) LocalNip44JobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn runJob(
        self: LocalNip44JobClient,
        request: *const LocalNip44JobRequest,
        output: []u8,
    ) LocalNip44JobClientError!LocalNip44JobResult {
        return switch (request.*) {
            .encrypt => |job| encrypted: {
                if (job.nonce) |nonce| {
                    break :encrypted .{ .ciphertext = try self.local_operator.encryptNip44ToPeerWithNonce(
                        output,
                        &job.secret_key,
                        &job.peer_public_key,
                        job.plaintext,
                        &nonce,
                    ) };
                }
                break :encrypted .{ .ciphertext = try self.local_operator.encryptNip44ToPeer(
                    output,
                    &job.secret_key,
                    &job.peer_public_key,
                    job.plaintext,
                ) };
            },
            .decrypt => |job| .{
                .plaintext = try self.local_operator.decryptNip44FromPeer(
                    output,
                    &job.secret_key,
                    &job.peer_public_key,
                    job.payload,
                ),
            },
        };
    }
};

test "local nip44 job client exposes caller-owned config and storage" {
    var storage = LocalNip44JobClientStorage{};
    const client = LocalNip44JobClient.init(.{}, &storage);

    _ = client;
}

test "local nip44 job client roundtrips one explicit nonce flow through stable job posture" {
    var storage = LocalNip44JobClientStorage{};
    const client = LocalNip44JobClient.init(.{}, &storage);
    const sender_secret = [_]u8{0x31} ** local_operator.secret_key_bytes;
    const recipient_secret = [_]u8{0x32} ** local_operator.secret_key_bytes;
    const sender_pubkey = try client.local_operator.derivePublicKey(&sender_secret);
    const recipient_pubkey = try client.local_operator.derivePublicKey(&recipient_secret);
    const nonce = [_]u8{0} ** 31 ++ [_]u8{1};

    var ciphertext_output: [256]u8 = undefined;
    const encrypted = try client.runJob(
        &.{ .encrypt = .{
            .secret_key = sender_secret,
            .peer_public_key = recipient_pubkey,
            .plaintext = "hello peer",
            .nonce = nonce,
        } },
        ciphertext_output[0..],
    );
    try std.testing.expect(encrypted == .ciphertext);

    var plaintext_output: [256]u8 = undefined;
    const decrypted = try client.runJob(
        &.{ .decrypt = .{
            .secret_key = recipient_secret,
            .peer_public_key = sender_pubkey,
            .payload = encrypted.ciphertext,
        } },
        plaintext_output[0..],
    );
    try std.testing.expect(decrypted == .plaintext);
    try std.testing.expectEqualStrings("hello peer", decrypted.plaintext);
}

test "local nip44 job client supports default nonce generation through stable job posture" {
    var storage = LocalNip44JobClientStorage{};
    const client = LocalNip44JobClient.init(.{}, &storage);
    const sender_secret = [_]u8{0x41} ** local_operator.secret_key_bytes;
    const recipient_secret = [_]u8{0x42} ** local_operator.secret_key_bytes;
    const sender_pubkey = try client.local_operator.derivePublicKey(&sender_secret);
    const recipient_pubkey = try client.local_operator.derivePublicKey(&recipient_secret);

    var ciphertext_output: [256]u8 = undefined;
    const encrypted = try client.runJob(
        &.{ .encrypt = .{
            .secret_key = sender_secret,
            .peer_public_key = recipient_pubkey,
            .plaintext = "nonce free",
        } },
        ciphertext_output[0..],
    );
    try std.testing.expect(encrypted == .ciphertext);

    var plaintext_output: [256]u8 = undefined;
    const decrypted = try client.runJob(
        &.{ .decrypt = .{
            .secret_key = recipient_secret,
            .peer_public_key = sender_pubkey,
            .payload = encrypted.ciphertext,
        } },
        plaintext_output[0..],
    );
    try std.testing.expect(decrypted == .plaintext);
    try std.testing.expectEqualStrings("nonce free", decrypted.plaintext);
}
