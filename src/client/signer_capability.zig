const std = @import("std");
const workflows = @import("../workflows/mod.zig");

pub const public_key_bytes: u8 = 32;

pub const SignerBackendKind = enum {
    local,
    remote,
    browser,
};

pub const SignerOperation = enum {
    get_public_key,
    sign_event,
    nip04_encrypt,
    nip04_decrypt,
    nip44_encrypt,
    nip44_decrypt,

    pub fn isTextOperation(self: SignerOperation) bool {
        return switch (self) {
            .nip04_encrypt,
            .nip04_decrypt,
            .nip44_encrypt,
            .nip44_decrypt,
            => true,
            .get_public_key,
            .sign_event,
            => false,
        };
    }
};

pub const SignerOperationMode = enum {
    unsupported,
    local_immediate,
    caller_driven_request,
};

pub const SignerOperationModes = struct {
    get_public_key: SignerOperationMode = .unsupported,
    sign_event: SignerOperationMode = .unsupported,
    nip04_encrypt: SignerOperationMode = .unsupported,
    nip04_decrypt: SignerOperationMode = .unsupported,
    nip44_encrypt: SignerOperationMode = .unsupported,
    nip44_decrypt: SignerOperationMode = .unsupported,

    pub fn modeFor(
        self: *const SignerOperationModes,
        operation: SignerOperation,
    ) SignerOperationMode {
        return switch (operation) {
            .get_public_key => self.get_public_key,
            .sign_event => self.sign_event,
            .nip04_encrypt => self.nip04_encrypt,
            .nip04_decrypt => self.nip04_decrypt,
            .nip44_encrypt => self.nip44_encrypt,
            .nip44_decrypt => self.nip44_decrypt,
        };
    }

    pub fn supports(
        self: *const SignerOperationModes,
        operation: SignerOperation,
    ) bool {
        return self.modeFor(operation) != .unsupported;
    }
};

pub const SignerCapabilityProfile = struct {
    backend: SignerBackendKind,
    operations: SignerOperationModes,

    pub fn init(
        backend: SignerBackendKind,
        operations: SignerOperationModes,
    ) SignerCapabilityProfile {
        return .{
            .backend = backend,
            .operations = operations,
        };
    }

    pub fn localOperator() SignerCapabilityProfile {
        return .init(.local, .{
            .get_public_key = .local_immediate,
            .sign_event = .local_immediate,
            .nip44_encrypt = .local_immediate,
            .nip44_decrypt = .local_immediate,
        });
    }

    pub fn remoteSigner() SignerCapabilityProfile {
        return .init(.remote, .{
            .get_public_key = .caller_driven_request,
            .sign_event = .caller_driven_request,
            .nip04_encrypt = .caller_driven_request,
            .nip04_decrypt = .caller_driven_request,
            .nip44_encrypt = .caller_driven_request,
            .nip44_decrypt = .caller_driven_request,
        });
    }

    pub fn modeFor(
        self: *const SignerCapabilityProfile,
        operation: SignerOperation,
    ) SignerOperationMode {
        return self.operations.modeFor(operation);
    }

    pub fn supports(
        self: *const SignerCapabilityProfile,
        operation: SignerOperation,
    ) bool {
        return self.operations.supports(operation);
    }
};

pub const SignerPubkeyTextRequest = workflows.signer.remote.RemoteSignerPubkeyTextRequest;

/// Request payloads borrow caller-owned data.
pub const SignerOperationRequest = union(SignerOperation) {
    get_public_key: void,
    sign_event: []const u8,
    nip04_encrypt: SignerPubkeyTextRequest,
    nip04_decrypt: SignerPubkeyTextRequest,
    nip44_encrypt: SignerPubkeyTextRequest,
    nip44_decrypt: SignerPubkeyTextRequest,

    pub fn operation(self: *const SignerOperationRequest) SignerOperation {
        return std.meta.activeTag(self.*);
    }

    pub fn modeIn(
        self: *const SignerOperationRequest,
        capability: *const SignerCapabilityProfile,
    ) SignerOperationMode {
        return capability.modeFor(self.operation());
    }

    pub fn isSupportedBy(
        self: *const SignerOperationRequest,
        capability: *const SignerCapabilityProfile,
    ) bool {
        return capability.supports(self.operation());
    }

    pub fn expectsTextResponse(self: *const SignerOperationRequest) bool {
        return self.operation().isTextOperation();
    }

    pub fn acceptsResult(
        self: *const SignerOperationRequest,
        result: *const SignerOperationResult,
    ) bool {
        return switch (self.operation()) {
            .get_public_key => result.* == .user_pubkey,
            .sign_event => result.* == .signed_event_json,
            .nip04_encrypt,
            .nip04_decrypt,
            .nip44_encrypt,
            .nip44_decrypt,
            => result.* == .text_response and result.text_response.operation == self.operation(),
        };
    }
};

/// `text` borrows from the caller-owned response storage.
pub const SignerTextResponse = struct {
    operation: SignerOperation,
    text: []const u8,
};

/// Borrowed payloads in `signed_event_json` and `text_response.text` come from caller-owned data.
pub const SignerOperationResult = union(enum) {
    user_pubkey: [public_key_bytes]u8,
    signed_event_json: []const u8,
    text_response: SignerTextResponse,

    pub fn operation(self: *const SignerOperationResult) SignerOperation {
        return switch (self.*) {
            .user_pubkey => .get_public_key,
            .signed_event_json => .sign_event,
            .text_response => |response| response.operation,
        };
    }
};

test "local and remote signer profiles expose bounded backend differences honestly" {
    const local = SignerCapabilityProfile.localOperator();
    try std.testing.expectEqual(.local, local.backend);
    try std.testing.expectEqual(.local_immediate, local.modeFor(.get_public_key));
    try std.testing.expectEqual(.local_immediate, local.modeFor(.sign_event));
    try std.testing.expectEqual(.unsupported, local.modeFor(.nip04_encrypt));
    try std.testing.expectEqual(.local_immediate, local.modeFor(.nip44_encrypt));

    const remote = SignerCapabilityProfile.remoteSigner();
    try std.testing.expectEqual(.remote, remote.backend);
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.get_public_key));
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.sign_event));
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.nip04_encrypt));
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.nip44_encrypt));

    const browser = SignerCapabilityProfile.init(.browser, .{
        .get_public_key = .caller_driven_request,
        .sign_event = .caller_driven_request,
    });
    try std.testing.expectEqual(.browser, browser.backend);
    try std.testing.expectEqual(.caller_driven_request, browser.modeFor(.get_public_key));
    try std.testing.expectEqual(.unsupported, browser.modeFor(.nip44_encrypt));
}

test "unsupported operations remain explicit instead of pretending every signer can do everything" {
    const local = SignerCapabilityProfile.localOperator();
    const nip04_encrypt_request: SignerOperationRequest = .{
        .nip04_encrypt = .{
            .pubkey = [_]u8{0x11} ** public_key_bytes,
            .text = "hello",
        },
    };
    try std.testing.expectEqual(.nip04_encrypt, nip04_encrypt_request.operation());
    try std.testing.expectEqual(.unsupported, nip04_encrypt_request.modeIn(&local));
    try std.testing.expect(!nip04_encrypt_request.isSupportedBy(&local));
    try std.testing.expect(nip04_encrypt_request.expectsTextResponse());
}

test "shared and backend-limited operations route through the common signer vocabulary" {
    const local = SignerCapabilityProfile.localOperator();
    const remote = SignerCapabilityProfile.remoteSigner();

    const sign_event_request: SignerOperationRequest = .{ .sign_event = "{\"kind\":1}" };
    try std.testing.expect(sign_event_request.isSupportedBy(&local));
    try std.testing.expect(sign_event_request.isSupportedBy(&remote));
    try std.testing.expectEqual(.local_immediate, sign_event_request.modeIn(&local));
    try std.testing.expectEqual(.caller_driven_request, sign_event_request.modeIn(&remote));

    const sign_event_result: SignerOperationResult = .{
        .signed_event_json = "{\"id\":\"abc\"}",
    };
    try std.testing.expect(sign_event_request.acceptsResult(&sign_event_result));

    const nip04_decrypt_request: SignerOperationRequest = .{
        .nip04_decrypt = .{
            .pubkey = [_]u8{0x22} ** public_key_bytes,
            .text = "ciphertext",
        },
    };
    try std.testing.expectEqual(.unsupported, nip04_decrypt_request.modeIn(&local));
    try std.testing.expectEqual(.caller_driven_request, nip04_decrypt_request.modeIn(&remote));

    const nip04_decrypt_result: SignerOperationResult = .{
        .text_response = .{
            .operation = .nip04_decrypt,
            .text = "plaintext",
        },
    };
    try std.testing.expect(nip04_decrypt_request.acceptsResult(&nip04_decrypt_result));
    try std.testing.expectEqual(.nip04_decrypt, nip04_decrypt_result.operation());

    const wrong_result: SignerOperationResult = .{ .user_pubkey = [_]u8{0x44} ** public_key_bytes };
    try std.testing.expect(!nip04_decrypt_request.acceptsResult(&wrong_result));
}
