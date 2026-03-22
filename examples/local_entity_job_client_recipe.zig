const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Command-ready local entity flow: encode one `npub`, encode one `nsec`, and decode one
// representative entity through one stable job layer above the local operator floor.
test "recipe: local entity job client keeps nip19 entity work command-ready" {
    var storage = noztr_sdk.client.local.entities.LocalEntityJobClientStorage{};
    const client = noztr_sdk.client.local.entities.LocalEntityJobClient.init(.{}, &storage);
    const author_secret = [_]u8{0x11} ** 32;
    const author_pubkey = try client.local_operator.derivePublicKey(&author_secret);

    var encoded_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    const npub = try client.runJob(
        &.{ .encode_npub = author_pubkey },
        encoded_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(npub == .encoded);

    const nsec = try client.runJob(
        &.{ .encode_nsec = author_secret },
        encoded_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(nsec == .encoded);

    const note_id = [_]u8{0x44} ** 32;
    const note = try client.runJob(
        &.{ .encode_entity = .{ .note = note_id } },
        encoded_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(note == .encoded);

    const decoded = try client.runJob(
        &.{ .decode_entity = note.encoded },
        encoded_output[0..],
        tlv_scratch[0..],
    );
    try std.testing.expect(decoded == .decoded);
    try std.testing.expect(decoded.decoded == .note);
}
