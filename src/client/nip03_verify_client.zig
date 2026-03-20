const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const transport = @import("../transport/mod.zig");
const workflows = @import("../workflows/mod.zig");
const workflow_testing = if (builtin.is_test) @import("../testing/mod.zig") else struct {};

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70,
    0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84,
    0xe8, 0x92, 0x94,
};
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

pub const Nip03VerifyClientError = workflows.OpenTimestampsRememberedRemoteVerificationError;

pub const Nip03VerifyClientConfig = struct {};

pub const Nip03VerifyClientStorage = struct {
    proof_buffer: []u8,
    accept: ?[]const u8 = null,

    pub fn init(proof_buffer: []u8) Nip03VerifyClientStorage {
        return .{
            .proof_buffer = proof_buffer,
            .accept = null,
        };
    }
};

pub const Nip03VerifyJob = workflows.OpenTimestampsRemoteProofRequest;
pub const Nip03VerifyCachedResult = workflows.OpenTimestampsRemoteVerificationOutcome;
pub const Nip03VerifyJobResult = workflows.OpenTimestampsRememberedRemoteVerificationOutcome;

pub const Nip03VerifyClient = struct {
    config: Nip03VerifyClientConfig,

    pub fn init(config: Nip03VerifyClientConfig) Nip03VerifyClient {
        return .{ .config = config };
    }

    pub fn prepareVerifyJob(
        self: *const Nip03VerifyClient,
        storage: *const Nip03VerifyClientStorage,
        target_event: *const noztr.nip01_event.Event,
        attestation_event: *const noztr.nip01_event.Event,
        proof_url: []const u8,
    ) Nip03VerifyJob {
        _ = self;
        return .{
            .target_event = target_event,
            .attestation_event = attestation_event,
            .proof_url = proof_url,
            .proof_buffer = storage.proof_buffer,
            .accept = storage.accept,
        };
    }

    pub fn verifyRemote(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyCachedResult {
        _ = self;
        return workflows.OpenTimestampsVerifier.verifyRemote(http_client, job);
    }

    pub fn verifyRemoteCached(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        proof_store: workflows.OpenTimestampsProofStore,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyCachedResult {
        _ = self;
        return workflows.OpenTimestampsVerifier.verifyRemoteCached(http_client, proof_store, job);
    }

    pub fn verifyRemoteCachedAndRemember(
        self: *const Nip03VerifyClient,
        http_client: transport.HttpClient,
        proof_store: workflows.OpenTimestampsProofStore,
        verification_store: workflows.OpenTimestampsVerificationStore,
        job: *const Nip03VerifyJob,
    ) Nip03VerifyClientError!Nip03VerifyJobResult {
        _ = self;
        return workflows.OpenTimestampsVerifier.verifyRemoteCachedAndRemember(
            http_client,
            proof_store,
            verification_store,
            job,
        );
    }
};

test "nip03 verify client exposes caller-owned remote-proof storage" {
    var proof_buffer: [256]u8 = undefined;
    var storage = Nip03VerifyClientStorage.init(proof_buffer[0..]);
    storage.accept = "application/octet-stream";
    const client = Nip03VerifyClient.init(.{});
    _ = client;

    try std.testing.expectEqual(@as(usize, 256), storage.proof_buffer.len);
    try std.testing.expectEqualStrings("application/octet-stream", storage.accept.?);
}

test "nip03 verify client drives remembered remote verification through one command-ready surface" {
    const signer_secret = [_]u8{0x13} ** 32;
    const signer_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&signer_secret);
    var target = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = signer_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "hello",
        .tags = &.{},
    };
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &target);

    var proof_bytes: [96]u8 = undefined;
    const proof = buildLocalBitcoinProof(proof_bytes[0..], &target.id);
    var proof_b64: [256]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(proof_b64[0..], proof);
    const event_id_hex = std.fmt.bytesToHex(target.id, .lower);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", event_id_hex[0..] } },
        .{ .items = &.{ "k", "1" } },
    };
    const attestation_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x33} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1040,
        .created_at = 2,
        .content = encoded,
        .tags = tags[0..],
    };

    var fake_http = workflow_testing.FakeHttp.init("https://proof.example/hello.ots", proof);
    var fetched_proof: [128]u8 = undefined;
    var storage = Nip03VerifyClientStorage.init(fetched_proof[0..]);
    var proof_store_records: [1]workflows.OpenTimestampsProofRecord =
        [_]workflows.OpenTimestampsProofRecord{.{}} ** 1;
    var proof_store = workflows.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [1]workflows.OpenTimestampsStoredVerificationRecord =
        [_]workflows.OpenTimestampsStoredVerificationRecord{.{}} ** 1;
    var verification_store =
        workflows.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const client = Nip03VerifyClient.init(.{});
    const job = client.prepareVerifyJob(
        &storage,
        &target,
        &attestation_event,
        "https://proof.example/hello.ots",
    );
    const remembered = try client.verifyRemoteCachedAndRemember(
        fake_http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &job,
    );
    try std.testing.expect(remembered == .verified);
    try std.testing.expectEqual(
        workflows.OpenTimestampsVerificationStorePutOutcome.stored,
        remembered.verified.store_outcome,
    );

    const cached = try client.verifyRemoteCached(
        fake_http.client(),
        proof_store.asStore(),
        &job,
    );
    try std.testing.expect(cached == .verified);
    try std.testing.expectEqualStrings(
        "https://proof.example/hello.ots",
        cached.verified.proof_url,
    );
}

fn buildLocalBitcoinProof(output: []u8, digest: *const [32]u8) []const u8 {
    var index: usize = 0;
    @memcpy(output[index .. index + ots_header_magic.len], ots_header_magic[0..]);
    index += ots_header_magic.len;
    output[index] = 0x01;
    output[index + 1] = 0x08;
    index += 2;
    @memcpy(output[index .. index + digest.len], digest[0..]);
    index += digest.len;
    output[index] = 0x00;
    index += 1;
    @memcpy(output[index .. index + ots_bitcoin_tag.len], ots_bitcoin_tag[0..]);
    index += ots_bitcoin_tag.len;
    output[index] = 0x01;
    output[index + 1] = 0x2a;
    return output[0 .. index + 2];
}
