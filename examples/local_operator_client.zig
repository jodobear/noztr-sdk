const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Compose one local-only operator tooling surface above the kernel: derive one deterministic
// keypair, roundtrip one `npub` and `nsec`, sign and inspect one event locally, then perform one
// explicit `NIP-44` encrypt/decrypt roundtrip without any relay or runtime ownership.
test "recipe: local operator client composes key, event, entity, and local nip44 helpers" {
    const client = noztr_sdk.client.local.operator.LocalOperatorClient.init(.{});
    const author_secret = [_]u8{0x11} ** 32;
    const peer_secret = [_]u8{0x22} ** 32;
    const author_keypair = try client.keypairFromSecretKey(&author_secret);
    const peer_pubkey = try client.derivePublicKey(&peer_secret);

    var npub_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var nsec_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    const npub = try client.encodeNpub(npub_output[0..], &author_keypair.public_key);
    const nsec = try client.encodeNsec(nsec_output[0..], &author_keypair.secret_key);

    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    const decoded_npub = try client.decodeEntity(npub, tlv_scratch[0..]);
    try std.testing.expect(decoded_npub == .npub);
    const decoded_nsec = try client.decodeEntity(nsec, tlv_scratch[0..]);
    try std.testing.expect(decoded_nsec == .nsec);

    const draft = noztr_sdk.client.local.operator.LocalEventDraft{
        .kind = 1,
        .created_at = 42,
        .content = "local operator event",
    };
    var signed_event = try client.signDraft(&author_secret, &draft);
    const signed_view = client.inspectEvent(&signed_event);
    const signed_pubkey_hex = signed_view.pubkeyHex();
    try std.testing.expectEqualStrings(
        &std.fmt.bytesToHex(signed_event.pubkey, .lower),
        signed_pubkey_hex[0..],
    );

    var event_json_output: [512]u8 = undefined;
    const event_json = try client.serializeEventJson(event_json_output[0..], &signed_event);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const reparsed = try client.inspectEventJson(event_json, arena.allocator());
    try std.testing.expectEqualStrings("local operator event", reparsed.event.content);

    const nonce = [_]u8{0} ** 31 ++ [_]u8{1};
    var ciphertext_output: [noztr.limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const ciphertext = try client.encryptNip44ToPeerWithNonce(
        ciphertext_output[0..],
        &author_secret,
        &peer_pubkey,
        "hello local peer",
        &nonce,
    );

    var plaintext_output: [noztr.limits.nip44_plaintext_max_bytes]u8 = undefined;
    const author_pubkey = author_keypair.public_key;
    const plaintext = try client.decryptNip44FromPeer(
        plaintext_output[0..],
        &peer_secret,
        &author_pubkey,
        ciphertext,
    );
    try std.testing.expectEqualStrings("hello local peer", plaintext);
}
