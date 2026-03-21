const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Command-ready local nip44 flow: encrypt one plaintext to a peer and decrypt it again through
// one stable job layer above the local operator floor.
test "recipe: local nip44 job client keeps local crypto work command-ready" {
    var storage = noztr_sdk.client.LocalNip44JobClientStorage{};
    const client = noztr_sdk.client.LocalNip44JobClient.init(.{}, &storage);
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const sender_pubkey = try client.local_operator.derivePublicKey(&sender_secret);
    const recipient_pubkey = try client.local_operator.derivePublicKey(&recipient_secret);
    const nonce = [_]u8{0} ** 31 ++ [_]u8{1};

    var ciphertext_output: [256]u8 = undefined;
    const encrypted = try client.runJob(
        &.{ .encrypt = .{
            .secret_key = sender_secret,
            .peer_public_key = recipient_pubkey,
            .plaintext = "hello local peer",
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
    try std.testing.expectEqualStrings("hello local peer", decrypted.plaintext);
}
