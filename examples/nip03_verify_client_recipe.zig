const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70,
    0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84,
    0xe8, 0x92, 0x94,
};
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

// Prepare one command-ready NIP-03 detached-proof verify job, then run it over the explicit HTTP,
// proof-store, and remembered-verification seams.
test "recipe: nip03 verify client prepares and runs one remembered detached-proof verify job" {
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

    var http = http_fake.ExampleHttp.init("https://proof.example/hello.ots", proof);
    var fetched_proof: [128]u8 = undefined;
    var storage = noztr_sdk.client.Nip03VerifyClientStorage.init(fetched_proof[0..]);
    var proof_store_records: [1]noztr_sdk.workflows.OpenTimestampsProofRecord =
        [_]noztr_sdk.workflows.OpenTimestampsProofRecord{.{}} ** 1;
    var proof_store =
        noztr_sdk.workflows.MemoryOpenTimestampsProofStore.init(proof_store_records[0..]);
    var verification_store_records: [1]noztr_sdk.workflows.OpenTimestampsStoredVerificationRecord =
        [_]noztr_sdk.workflows.OpenTimestampsStoredVerificationRecord{.{}} ** 1;
    var verification_store =
        noztr_sdk.workflows.MemoryOpenTimestampsVerificationStore.init(verification_store_records[0..]);

    const client = noztr_sdk.client.Nip03VerifyClient.init(.{});
    const job = client.prepareVerifyJob(
        &storage,
        &target,
        &attestation_event,
        "https://proof.example/hello.ots",
    );
    const result = try client.verifyRemoteCachedAndRemember(
        http.client(),
        proof_store.asStore(),
        verification_store.asStore(),
        &job,
    );

    try std.testing.expect(result == .verified);
    try std.testing.expectEqual(
        noztr_sdk.workflows.OpenTimestampsVerificationStorePutOutcome.stored,
        result.verified.store_outcome,
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
