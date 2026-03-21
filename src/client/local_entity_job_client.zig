const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const noztr = @import("noztr");

pub const LocalEntityJobClientError = local_operator.LocalOperatorClientError;

pub const LocalEntityJobClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const LocalEntityJobClientStorage = struct {};

pub const LocalEntityJobRequest = union(enum) {
    encode_npub: [local_operator.public_key_bytes]u8,
    encode_nsec: [local_operator.secret_key_bytes]u8,
    encode_entity: noztr.nip19_bech32.Nip19Entity,
    decode_entity: []const u8,
};

pub const LocalEntityJobResult = union(enum) {
    encoded: []const u8,
    decoded: noztr.nip19_bech32.Nip19Entity,
};

pub const LocalEntityJobClient = struct {
    config: LocalEntityJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,

    pub fn init(
        config: LocalEntityJobClientConfig,
        storage: *LocalEntityJobClientStorage,
    ) LocalEntityJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn attach(
        config: LocalEntityJobClientConfig,
        storage: *LocalEntityJobClientStorage,
    ) LocalEntityJobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn runJob(
        self: LocalEntityJobClient,
        request: *const LocalEntityJobRequest,
        output: []u8,
        tlv_scratch: []u8,
    ) LocalEntityJobClientError!LocalEntityJobResult {
        return switch (request.*) {
            .encode_npub => |public_key| .{
                .encoded = try self.local_operator.encodeNpub(output, &public_key),
            },
            .encode_nsec => |secret_key| .{
                .encoded = try self.local_operator.encodeNsec(output, &secret_key),
            },
            .encode_entity => |entity| .{
                .encoded = try self.local_operator.encodeEntity(output, entity),
            },
            .decode_entity => |text| .{
                .decoded = try self.local_operator.decodeEntity(text, tlv_scratch),
            },
        };
    }
};

test "local entity job client exposes caller-owned config and storage" {
    var storage = LocalEntityJobClientStorage{};
    const client = LocalEntityJobClient.init(.{}, &storage);

    _ = client;
}

test "local entity job client roundtrips npub and nsec through stable job posture" {
    var storage = LocalEntityJobClientStorage{};
    const client = LocalEntityJobClient.init(.{}, &storage);
    const secret_key = [_]u8{0x11} ** local_operator.secret_key_bytes;
    const public_key = try client.local_operator.derivePublicKey(&secret_key);

    var npub_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var nsec_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    const encoded_npub = try client.runJob(
        &.{ .encode_npub = public_key },
        npub_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(encoded_npub == .encoded);

    const decoded_npub = try client.runJob(
        &.{ .decode_entity = encoded_npub.encoded },
        nsec_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(decoded_npub == .decoded);
    try std.testing.expect(decoded_npub.decoded == .npub);
    try std.testing.expectEqualSlices(u8, public_key[0..], decoded_npub.decoded.npub[0..]);

    const encoded_nsec = try client.runJob(
        &.{ .encode_nsec = secret_key },
        nsec_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(encoded_nsec == .encoded);

    const decoded_nsec = try client.runJob(
        &.{ .decode_entity = encoded_nsec.encoded },
        npub_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(decoded_nsec == .decoded);
    try std.testing.expect(decoded_nsec.decoded == .nsec);
    try std.testing.expectEqualSlices(u8, secret_key[0..], decoded_nsec.decoded.nsec[0..]);
}

test "local entity job client decodes one representative generic entity" {
    var storage = LocalEntityJobClientStorage{};
    const client = LocalEntityJobClient.init(.{}, &storage);
    const event_id = [_]u8{0x33} ** local_operator.event_id_bytes;

    var output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    const encoded = try client.runJob(
        &.{ .encode_entity = .{ .note = event_id } },
        output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(encoded == .encoded);

    const decoded = try client.runJob(
        &.{ .decode_entity = encoded.encoded },
        output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(decoded == .decoded);
    try std.testing.expect(decoded.decoded == .note);
    try std.testing.expectEqualSlices(u8, event_id[0..], decoded.decoded.note[0..]);
}
