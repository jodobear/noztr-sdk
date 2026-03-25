const std = @import("std");
const workflows = @import("../workflows/mod.zig");

pub const public_key_bytes: u8 = 32;

pub const BackendKind = enum {
    local,
    remote,
    browser,
};

pub const Operation = enum {
    get_public_key,
    sign_event,
    nip04_encrypt,
    nip04_decrypt,
    nip44_encrypt,
    nip44_decrypt,

    pub fn isTextOperation(self: Operation) bool {
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

pub const OperationMode = enum {
    unsupported,
    local_immediate,
    caller_driven_request,
};

pub const OperationModes = struct {
    get_public_key: OperationMode = .unsupported,
    sign_event: OperationMode = .unsupported,
    nip04_encrypt: OperationMode = .unsupported,
    nip04_decrypt: OperationMode = .unsupported,
    nip44_encrypt: OperationMode = .unsupported,
    nip44_decrypt: OperationMode = .unsupported,

    pub fn modeFor(
        self: *const OperationModes,
        operation: Operation,
    ) OperationMode {
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
        self: *const OperationModes,
        operation: Operation,
    ) bool {
        return self.modeFor(operation) != .unsupported;
    }
};

pub const Profile = struct {
    backend: BackendKind,
    operations: OperationModes,

    pub fn init(
        backend: BackendKind,
        operations: OperationModes,
    ) Profile {
        return .{
            .backend = backend,
            .operations = operations,
        };
    }

    pub fn localOperator() Profile {
        return .init(.local, .{
            .get_public_key = .local_immediate,
            .sign_event = .local_immediate,
            .nip44_encrypt = .local_immediate,
            .nip44_decrypt = .local_immediate,
        });
    }

    pub fn remoteSigner() Profile {
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
        self: *const Profile,
        operation: Operation,
    ) OperationMode {
        return self.operations.modeFor(operation);
    }

    pub fn supports(
        self: *const Profile,
        operation: Operation,
    ) bool {
        return self.operations.supports(operation);
    }
};

pub const PubkeyTextRequest = workflows.signer.remote.PubkeyTextRequest;

/// Request payloads borrow caller-owned data.
pub const OperationRequest = union(Operation) {
    get_public_key: void,
    sign_event: []const u8,
    nip04_encrypt: PubkeyTextRequest,
    nip04_decrypt: PubkeyTextRequest,
    nip44_encrypt: PubkeyTextRequest,
    nip44_decrypt: PubkeyTextRequest,

    pub fn operation(self: *const OperationRequest) Operation {
        return std.meta.activeTag(self.*);
    }

    pub fn modeIn(
        self: *const OperationRequest,
        capability: *const Profile,
    ) OperationMode {
        return capability.modeFor(self.operation());
    }

    pub fn isSupportedBy(
        self: *const OperationRequest,
        capability: *const Profile,
    ) bool {
        return capability.supports(self.operation());
    }

    pub fn expectsTextResponse(self: *const OperationRequest) bool {
        return self.operation().isTextOperation();
    }

    pub fn acceptsResult(
        self: *const OperationRequest,
        result: *const OperationResult,
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
pub const TextResponse = struct {
    operation: Operation,
    text: []const u8,
};

/// Borrowed payloads in `signed_event_json` and `text_response.text` come from caller-owned data.
pub const OperationResult = union(enum) {
    user_pubkey: [public_key_bytes]u8,
    signed_event_json: []const u8,
    text_response: TextResponse,

    pub fn operation(self: *const OperationResult) Operation {
        return switch (self.*) {
            .user_pubkey => .get_public_key,
            .signed_event_json => .sign_event,
            .text_response => |response| response.operation,
        };
    }
};

test "local and remote signer profiles expose bounded backend differences honestly" {
    const local = Profile.localOperator();
    try std.testing.expectEqual(.local, local.backend);
    try std.testing.expectEqual(.local_immediate, local.modeFor(.get_public_key));
    try std.testing.expectEqual(.local_immediate, local.modeFor(.sign_event));
    try std.testing.expectEqual(.unsupported, local.modeFor(.nip04_encrypt));
    try std.testing.expectEqual(.local_immediate, local.modeFor(.nip44_encrypt));

    const remote = Profile.remoteSigner();
    try std.testing.expectEqual(.remote, remote.backend);
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.get_public_key));
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.sign_event));
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.nip04_encrypt));
    try std.testing.expectEqual(.caller_driven_request, remote.modeFor(.nip44_encrypt));

    const browser = Profile.init(.browser, .{
        .get_public_key = .caller_driven_request,
        .sign_event = .caller_driven_request,
    });
    try std.testing.expectEqual(.browser, browser.backend);
    try std.testing.expectEqual(.caller_driven_request, browser.modeFor(.get_public_key));
    try std.testing.expectEqual(.unsupported, browser.modeFor(.nip44_encrypt));
}

test "unsupported operations remain explicit instead of pretending every signer can do everything" {
    const local = Profile.localOperator();
    const nip04_encrypt_request: OperationRequest = .{
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
    const local = Profile.localOperator();
    const remote = Profile.remoteSigner();

    const sign_event_request: OperationRequest = .{ .sign_event = "{\"kind\":1}" };
    try std.testing.expect(sign_event_request.isSupportedBy(&local));
    try std.testing.expect(sign_event_request.isSupportedBy(&remote));
    try std.testing.expectEqual(.local_immediate, sign_event_request.modeIn(&local));
    try std.testing.expectEqual(.caller_driven_request, sign_event_request.modeIn(&remote));

    const sign_event_result: OperationResult = .{
        .signed_event_json = "{\"id\":\"abc\"}",
    };
    try std.testing.expect(sign_event_request.acceptsResult(&sign_event_result));

    const nip04_decrypt_request: OperationRequest = .{
        .nip04_decrypt = .{
            .pubkey = [_]u8{0x22} ** public_key_bytes,
            .text = "ciphertext",
        },
    };
    try std.testing.expectEqual(.unsupported, nip04_decrypt_request.modeIn(&local));
    try std.testing.expectEqual(.caller_driven_request, nip04_decrypt_request.modeIn(&remote));

    const nip04_decrypt_result: OperationResult = .{
        .text_response = .{
            .operation = .nip04_decrypt,
            .text = "plaintext",
        },
    };
    try std.testing.expect(nip04_decrypt_request.acceptsResult(&nip04_decrypt_result));
    try std.testing.expectEqual(.nip04_decrypt, nip04_decrypt_result.operation());

    const wrong_result: OperationResult = .{ .user_pubkey = [_]u8{0x44} ** public_key_bytes };
    try std.testing.expect(!nip04_decrypt_request.acceptsResult(&wrong_result));
}
