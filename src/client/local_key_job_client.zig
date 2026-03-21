const std = @import("std");
const local_operator = @import("local_operator_client.zig");

pub const LocalKeyJobClientError = local_operator.LocalOperatorClientError;

pub const LocalKeyJobClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const LocalKeyJobClientStorage = struct {};

pub const LocalKeyJobRequest = union(enum) {
    generate,
    derive_pubkey: [local_operator.secret_key_bytes]u8,
};

pub const LocalKeyJobResult = union(enum) {
    generated: local_operator.LocalKeypair,
    derived_pubkey: [local_operator.public_key_bytes]u8,
};

pub const LocalKeyJobClient = struct {
    config: LocalKeyJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,

    pub fn init(
        config: LocalKeyJobClientConfig,
        storage: *LocalKeyJobClientStorage,
    ) LocalKeyJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn attach(
        config: LocalKeyJobClientConfig,
        storage: *LocalKeyJobClientStorage,
    ) LocalKeyJobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn runJob(
        self: LocalKeyJobClient,
        request: *const LocalKeyJobRequest,
    ) LocalKeyJobClientError!LocalKeyJobResult {
        return switch (request.*) {
            .generate => .{ .generated = try self.local_operator.generateKeypair() },
            .derive_pubkey => |secret_key| .{
                .derived_pubkey = try self.local_operator.derivePublicKey(&secret_key),
            },
        };
    }
};

test "local key job client exposes caller-owned config and storage" {
    var storage = LocalKeyJobClientStorage{};
    const client = LocalKeyJobClient.init(.{}, &storage);

    _ = client;
}

test "local key job client derives one public key through stable job posture" {
    var storage = LocalKeyJobClientStorage{};
    const client = LocalKeyJobClient.init(.{}, &storage);
    const secret_key = [_]u8{0x11} ** local_operator.secret_key_bytes;

    const result = try client.runJob(&.{ .derive_pubkey = secret_key });
    try std.testing.expect(result == .derived_pubkey);

    const expected = try client.local_operator.derivePublicKey(&secret_key);
    try std.testing.expectEqualSlices(u8, expected[0..], result.derived_pubkey[0..]);
}

test "local key job client generates one usable keypair through stable job posture" {
    var storage = LocalKeyJobClientStorage{};
    const client = LocalKeyJobClient.init(.{}, &storage);

    const result = try client.runJob(&.{ .generate = {} });
    try std.testing.expect(result == .generated);

    const derived = try client.local_operator.derivePublicKey(&result.generated.secret_key);
    try std.testing.expectEqualSlices(u8, derived[0..], result.generated.public_key[0..]);
}
