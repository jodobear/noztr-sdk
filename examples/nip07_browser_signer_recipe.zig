const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Thin NIP-07 browser adapter route: presence and supported-method reporting stay explicit, and
// the browser seam can project onto the shared signer-capability vocabulary without claiming a
// full browser-extension product.
test "recipe: thin NIP-07 browser support projects onto signer capability honestly" {
    const FakeBrowser = struct {
        support: noztr_sdk.client.signer.browser.Nip07BrowserSupport,
    };
    const fake_vtable = noztr_sdk.client.signer.browser.Nip07BrowserProvider.VTable{
        .inspectSupport = struct {
            fn call(
                context: *const anyopaque,
            ) noztr_sdk.client.signer.browser.Nip07BrowserSupport {
                const typed: *const FakeBrowser = @ptrCast(@alignCast(context));
                return typed.support;
            }
        }.call,
    };

    const fake_browser = FakeBrowser{
        .support = .{
            .availability = .present,
            .methods = .{
                .get_public_key = true,
                .sign_event = true,
                .nip44_encrypt = true,
                .nip44_decrypt = true,
            },
        },
    };
    const browser = noztr_sdk.client.signer.browser.Nip07BrowserProvider.init(
        &fake_browser,
        &fake_vtable,
    );

    const support = browser.inspectSupport();
    try std.testing.expect(support.isPresent());
    try std.testing.expect(support.supports(.get_public_key));
    try std.testing.expect(!support.supports(.nip04_encrypt));

    const capability = browser.signerCapabilityProfile();
    try std.testing.expectEqual(.browser, capability.backend);

    const get_public_key_request: noztr_sdk.client.signer.capability.SignerOperationRequest = .{
        .get_public_key = {},
    };
    const nip04_encrypt_request: noztr_sdk.client.signer.capability.SignerOperationRequest = .{
        .nip04_encrypt = .{
            .pubkey = [_]u8{0x22} ** 32,
            .text = "hello",
        },
    };
    try std.testing.expectEqual(
        .caller_driven_request,
        get_public_key_request.modeIn(&capability),
    );
    try std.testing.expectEqual(.unsupported, nip04_encrypt_request.modeIn(&capability));
}
