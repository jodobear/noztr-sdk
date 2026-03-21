const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Command-ready local key flow: derive one deterministic public key and generate one fresh
// keypair without dropping to raw kernel modules or CLI-owned key plumbing.
test "recipe: local key job client keeps key generation and pubkey derivation command-ready" {
    var storage = noztr_sdk.client.LocalKeyJobClientStorage{};
    const client = noztr_sdk.client.LocalKeyJobClient.init(.{}, &storage);
    const author_secret = [_]u8{0x11} ** 32;

    const derived = try client.runJob(&.{ .derive_pubkey = author_secret });
    try std.testing.expect(derived == .derived_pubkey);

    const generated = try client.runJob(&.{ .generate = {} });
    try std.testing.expect(generated == .generated);

    const expected = try client.local_operator.derivePublicKey(&generated.generated.secret_key);
    try std.testing.expectEqualSlices(u8, expected[0..], generated.generated.public_key[0..]);
}
