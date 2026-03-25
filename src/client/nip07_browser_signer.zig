const std = @import("std");
const signer_capability = @import("signer_capability.zig");

pub const Nip07BrowserError = error{
    SignerUnavailable,
    UnsupportedMethod,
    InvalidPublicKeyHex,
};

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
        operation: signer_capability.Operation,
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
        operation: signer_capability.Operation,
    ) bool {
        return self.isPresent() and self.methods.supports(operation);
    }

    pub fn modeFor(
        self: *const Nip07BrowserSupport,
        operation: signer_capability.Operation,
    ) signer_capability.OperationMode {
        if (!self.supports(operation)) return .unsupported;
        return .caller_driven_request;
    }

    pub fn signerCapabilityProfile(
        self: *const Nip07BrowserSupport,
    ) signer_capability.Profile {
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
        completeOperation: *const fn (
            context: *const anyopaque,
            output: []u8,
            request: *const signer_capability.OperationRequest,
        ) Nip07BrowserError![]const u8,
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
    ) signer_capability.Profile {
        const support = self.inspectSupport();
        return support.signerCapabilityProfile();
    }

    pub fn completeSignerCapabilityOperation(
        self: *const Nip07BrowserProvider,
        output: []u8,
        request: *const signer_capability.OperationRequest,
    ) Nip07BrowserError!signer_capability.OperationResult {
        const support = self.inspectSupport();
        if (!support.isPresent()) return error.SignerUnavailable;
        if (!request.isSupportedBy(&support.signerCapabilityProfile())) return error.UnsupportedMethod;

        const response = try self.vtable.completeOperation(self.context, output, request);
        return switch (request.*) {
            .get_public_key => .{ .user_pubkey = try parsePublicKeyHex(response) },
            .sign_event => .{ .signed_event_json = response },
            .nip04_encrypt,
            .nip04_decrypt,
            .nip44_encrypt,
            .nip44_decrypt,
            => .{
                .text_response = .{
                    .operation = request.operation(),
                    .text = response,
                },
            },
        };
    }
};

fn parsePublicKeyHex(text: []const u8) Nip07BrowserError![32]u8 {
    if (text.len != 64) return error.InvalidPublicKeyHex;
    var public_key: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(public_key[0..], text) catch return error.InvalidPublicKeyHex;
    return public_key;
}

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
        .completeOperation = struct {
            fn call(
                context: *const anyopaque,
                output: []u8,
                request: *const signer_capability.OperationRequest,
            ) Nip07BrowserError![]const u8 {
                _ = context;
                return switch (request.*) {
                    .get_public_key => std.fmt.bufPrint(output, "{s}", .{
                        "4444444444444444444444444444444444444444444444444444444444444444",
                    }) catch unreachable,
                    .sign_event => |unsigned_event_json| std.fmt.bufPrint(output, "{s}", .{
                        unsigned_event_json,
                    }) catch unreachable,
                    .nip04_encrypt,
                    .nip04_decrypt,
                    .nip44_encrypt,
                    .nip44_decrypt,
                    => std.fmt.bufPrint(output, "{s}", .{"text"}) catch unreachable,
                };
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

    var output: [256]u8 = undefined;
    const get_public_key_request: signer_capability.OperationRequest = .{ .get_public_key = {} };
    const result = try provider.completeSignerCapabilityOperation(output[0..], &get_public_key_request);
    try std.testing.expect(get_public_key_request.acceptsResult(&result));
}

test "nip07 browser adapter completes shared signer requests while keeping unsupported methods explicit" {
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
        .completeOperation = struct {
            fn call(
                context: *const anyopaque,
                output: []u8,
                request: *const signer_capability.OperationRequest,
            ) Nip07BrowserError![]const u8 {
                _ = context;
                return switch (request.*) {
                    .get_public_key => std.fmt.bufPrint(output, "{s}", .{
                        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    }) catch unreachable,
                    .sign_event => std.fmt.bufPrint(output, "{s}", .{
                        "{\"id\":\"browser\"}",
                    }) catch unreachable,
                    .nip44_encrypt => std.fmt.bufPrint(output, "{s}", .{"ciphertext"}) catch unreachable,
                    .nip44_decrypt => std.fmt.bufPrint(output, "{s}", .{"plaintext"}) catch unreachable,
                    .nip04_encrypt,
                    .nip04_decrypt,
                    => unreachable,
                };
            }
        }.call,
    };

    const partial_context = FakeContext{
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
    const provider = Nip07BrowserProvider.init(&partial_context, &fake_vtable);

    var output: [256]u8 = undefined;
    const sign_event_request: signer_capability.OperationRequest = .{
        .sign_event = "{\"kind\":1}",
    };
    const sign_event_result = try provider.completeSignerCapabilityOperation(
        output[0..],
        &sign_event_request,
    );
    try std.testing.expect(sign_event_request.acceptsResult(&sign_event_result));

    const nip04_request: signer_capability.OperationRequest = .{
        .nip04_encrypt = .{
            .pubkey = [_]u8{0x22} ** 32,
            .text = "hello",
        },
    };
    try std.testing.expectError(
        error.UnsupportedMethod,
        provider.completeSignerCapabilityOperation(output[0..], &nip04_request),
    );

    const absent_context = FakeContext{ .support = .{} };
    const absent_provider = Nip07BrowserProvider.init(&absent_context, &fake_vtable);
    try std.testing.expectError(
        error.SignerUnavailable,
        absent_provider.completeSignerCapabilityOperation(output[0..], &sign_event_request),
    );
}
