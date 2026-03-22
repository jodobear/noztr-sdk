const std = @import("std");
const signer_capability = @import("signer_capability.zig");

pub const Nip07BrowserAvailability = enum {
    absent,
    present,
};

pub const Nip07BrowserMethodSupport = struct {
    get_public_key: bool = false,
    sign_event: bool = false,
    nip04_encrypt: bool = false,
    nip04_decrypt: bool = false,
    nip44_encrypt: bool = false,
    nip44_decrypt: bool = false,

    pub fn supports(
        self: *const Nip07BrowserMethodSupport,
        operation: signer_capability.SignerOperation,
    ) bool {
        return switch (operation) {
            .get_public_key => self.get_public_key,
            .sign_event => self.sign_event,
            .nip04_encrypt => self.nip04_encrypt,
            .nip04_decrypt => self.nip04_decrypt,
            .nip44_encrypt => self.nip44_encrypt,
            .nip44_decrypt => self.nip44_decrypt,
        };
    }
};

pub const Nip07BrowserSupport = struct {
    availability: Nip07BrowserAvailability = .absent,
    methods: Nip07BrowserMethodSupport = .{},

    pub fn isPresent(self: *const Nip07BrowserSupport) bool {
        return self.availability == .present;
    }

    pub fn supports(
        self: *const Nip07BrowserSupport,
        operation: signer_capability.SignerOperation,
    ) bool {
        return self.isPresent() and self.methods.supports(operation);
    }

    pub fn modeFor(
        self: *const Nip07BrowserSupport,
        operation: signer_capability.SignerOperation,
    ) signer_capability.SignerOperationMode {
        if (!self.supports(operation)) return .unsupported;
        return .caller_driven_request;
    }

    pub fn signerCapabilityProfile(
        self: *const Nip07BrowserSupport,
    ) signer_capability.SignerCapabilityProfile {
        return .init(.browser, .{
            .get_public_key = self.modeFor(.get_public_key),
            .sign_event = self.modeFor(.sign_event),
            .nip04_encrypt = self.modeFor(.nip04_encrypt),
            .nip04_decrypt = self.modeFor(.nip04_decrypt),
            .nip44_encrypt = self.modeFor(.nip44_encrypt),
            .nip44_decrypt = self.modeFor(.nip44_decrypt),
        });
    }
};

pub const Nip07BrowserProvider = struct {
    context: *const anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        inspectSupport: *const fn (context: *const anyopaque) Nip07BrowserSupport,
    };

    pub fn init(
        context: *const anyopaque,
        vtable: *const VTable,
    ) Nip07BrowserProvider {
        return .{
            .context = context,
            .vtable = vtable,
        };
    }

    pub fn inspectSupport(self: *const Nip07BrowserProvider) Nip07BrowserSupport {
        return self.vtable.inspectSupport(self.context);
    }

    pub fn signerCapabilityProfile(
        self: *const Nip07BrowserProvider,
    ) signer_capability.SignerCapabilityProfile {
        const support = self.inspectSupport();
        return support.signerCapabilityProfile();
    }
};

test "nip07 browser support stays explicit about absent and partial signer availability" {
    const absent: Nip07BrowserSupport = .{};
    try std.testing.expect(!absent.isPresent());
    try std.testing.expect(!absent.supports(.get_public_key));
    try std.testing.expectEqual(.unsupported, absent.modeFor(.get_public_key));

    const partial: Nip07BrowserSupport = .{
        .availability = .present,
        .methods = .{
            .get_public_key = true,
            .sign_event = true,
        },
    };
    try std.testing.expect(partial.isPresent());
    try std.testing.expect(partial.supports(.get_public_key));
    try std.testing.expect(!partial.supports(.nip44_encrypt));
    try std.testing.expectEqual(.caller_driven_request, partial.modeFor(.sign_event));
    try std.testing.expectEqual(.unsupported, partial.modeFor(.nip44_encrypt));
}

test "nip07 browser provider exposes capability profile through a thin support seam" {
    const FakeContext = struct {
        support: Nip07BrowserSupport,
    };
    const fake_vtable = Nip07BrowserProvider.VTable{
        .inspectSupport = struct {
            fn call(context: *const anyopaque) Nip07BrowserSupport {
                const typed: *const FakeContext = @ptrCast(@alignCast(context));
                return typed.support;
            }
        }.call,
    };

    const fake_context = FakeContext{
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
    const provider = Nip07BrowserProvider.init(&fake_context, &fake_vtable);

    const support = provider.inspectSupport();
    try std.testing.expect(support.isPresent());
    try std.testing.expect(support.supports(.sign_event));
    try std.testing.expect(!support.supports(.nip04_encrypt));

    const capability = provider.signerCapabilityProfile();
    try std.testing.expectEqual(.browser, capability.backend);
    try std.testing.expectEqual(.caller_driven_request, capability.modeFor(.get_public_key));
    try std.testing.expectEqual(.caller_driven_request, capability.modeFor(.nip44_encrypt));
    try std.testing.expectEqual(.unsupported, capability.modeFor(.nip04_encrypt));
}
