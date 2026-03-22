const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Shared signer capability vocabulary: local and remote signers can report the same operation
// surface honestly without hiding backend differences or product runtime.
test "recipe: signer capability surface stays explicit across local and remote signers" {
    const local = noztr_sdk.client.signer.capability.SignerCapabilityProfile.localOperator();
    const remote = noztr_sdk.client.signer.capability.SignerCapabilityProfile.remoteSigner();

    const sign_event_request: noztr_sdk.client.signer.capability.SignerOperationRequest = .{
        .sign_event = "{\"kind\":1}",
    };
    try std.testing.expect(sign_event_request.isSupportedBy(&local));
    try std.testing.expect(sign_event_request.isSupportedBy(&remote));
    try std.testing.expectEqual(.local_immediate, sign_event_request.modeIn(&local));
    try std.testing.expectEqual(.caller_driven_request, sign_event_request.modeIn(&remote));

    const nip04_request: noztr_sdk.client.signer.capability.SignerOperationRequest = .{
        .nip04_encrypt = .{
            .pubkey = [_]u8{0x33} ** 32,
            .text = "hello",
        },
    };
    try std.testing.expectEqual(.unsupported, nip04_request.modeIn(&local));
    try std.testing.expectEqual(.caller_driven_request, nip04_request.modeIn(&remote));
}
