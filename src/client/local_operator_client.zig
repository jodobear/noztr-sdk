const std = @import("std");
const noztr = @import("noztr");
const signer_capability = @import("signer_capability.zig");

pub const secret_key_bytes: u8 = 32;
pub const public_key_bytes: u8 = 32;
pub const event_id_bytes: u8 = 32;
pub const signature_bytes: u8 = 64;
pub const hex_chars_per_byte: u8 = 2;
pub const secret_key_hex_bytes: u8 = secret_key_bytes * hex_chars_per_byte;
pub const public_key_hex_bytes: u8 = public_key_bytes * hex_chars_per_byte;
pub const event_id_hex_bytes: u8 = event_id_bytes * hex_chars_per_byte;
pub const signature_hex_bytes: u8 = signature_bytes * hex_chars_per_byte;

pub const SecretKeyHex = [secret_key_hex_bytes]u8;
pub const PublicKeyHex = [public_key_hex_bytes]u8;
pub const EventIdHex = [event_id_hex_bytes]u8;
pub const SignatureHex = [signature_hex_bytes]u8;

pub const LocalOperatorClientError = error{
    InvalidSecretKeyHex,
    InvalidPublicKeyHex,
} || noztr.nostr_keys.NostrKeysError || noztr.nip19_bech32.Bech32Error || noztr.nip01_event.EventParseError || noztr.nip01_event.EventVerifyError || noztr.nip01_event.EventShapeError || noztr.nip01_event.EventSerializeError || noztr.nip44.ConversationEncryptionError;

pub const LocalOperatorSignerCapabilityError = LocalOperatorClientError || error{
    UnsupportedSignerOperation,
};

pub const LocalOperatorClientConfig = struct {};

pub const LocalKeypair = struct {
    secret_key: [secret_key_bytes]u8,
    public_key: [public_key_bytes]u8,

    pub fn secretKeyHex(self: *const LocalKeypair) SecretKeyHex {
        return std.fmt.bytesToHex(self.secret_key, .lower);
    }

    pub fn publicKeyHex(self: *const LocalKeypair) PublicKeyHex {
        return std.fmt.bytesToHex(self.public_key, .lower);
    }
};

pub const LocalEventDraft = struct {
    kind: u32,
    created_at: u64,
    content: []const u8,
    tags: []const noztr.nip01_event.EventTag = &.{},
};

pub const LocalEventInspection = struct {
    event: noztr.nip01_event.Event,

    pub fn eventIdHex(self: *const LocalEventInspection) EventIdHex {
        return std.fmt.bytesToHex(self.event.id, .lower);
    }

    pub fn pubkeyHex(self: *const LocalEventInspection) PublicKeyHex {
        return std.fmt.bytesToHex(self.event.pubkey, .lower);
    }

    pub fn signatureHex(self: *const LocalEventInspection) SignatureHex {
        return std.fmt.bytesToHex(self.event.sig, .lower);
    }
};

pub const LocalOperatorClient = struct {
    config: LocalOperatorClientConfig,

    pub fn init(config: LocalOperatorClientConfig) LocalOperatorClient {
        return .{ .config = config };
    }

    pub fn generateKeypair(self: LocalOperatorClient) LocalOperatorClientError!LocalKeypair {
        _ = self;

        while (true) {
            var secret_key: [secret_key_bytes]u8 = undefined;
            std.crypto.random.bytes(secret_key[0..]);
            const public_key = noztr.nostr_keys.nostr_derive_public_key(&secret_key) catch |err| {
                switch (err) {
                    error.InvalidSecretKey => continue,
                    else => return err,
                }
            };
            return .{
                .secret_key = secret_key,
                .public_key = public_key,
            };
        }
    }

    pub fn keypairFromSecretKey(
        self: LocalOperatorClient,
        secret_key: *const [secret_key_bytes]u8,
    ) LocalOperatorClientError!LocalKeypair {
        _ = self;
        return .{
            .secret_key = secret_key.*,
            .public_key = try noztr.nostr_keys.nostr_derive_public_key(secret_key),
        };
    }

    pub fn derivePublicKey(
        self: LocalOperatorClient,
        secret_key: *const [secret_key_bytes]u8,
    ) LocalOperatorClientError![public_key_bytes]u8 {
        _ = self;
        return noztr.nostr_keys.nostr_derive_public_key(secret_key);
    }

    pub fn parseSecretKeyHex(
        self: LocalOperatorClient,
        text: []const u8,
    ) LocalOperatorClientError![secret_key_bytes]u8 {
        _ = self;
        const secret_key = parseHex32(text, error.InvalidSecretKeyHex) catch |err| return err;
        _ = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
        return secret_key;
    }

    pub fn parsePublicKeyHex(
        self: LocalOperatorClient,
        text: []const u8,
    ) LocalOperatorClientError![public_key_bytes]u8 {
        _ = self;
        return parseHex32(text, error.InvalidPublicKeyHex);
    }

    pub fn encodeNpub(
        self: LocalOperatorClient,
        output: []u8,
        public_key: *const [public_key_bytes]u8,
    ) LocalOperatorClientError![]const u8 {
        _ = self;
        return noztr.nip19_bech32.nip19_encode(output, .{ .npub = public_key.* });
    }

    pub fn encodeNsec(
        self: LocalOperatorClient,
        output: []u8,
        secret_key: *const [secret_key_bytes]u8,
    ) LocalOperatorClientError![]const u8 {
        _ = try self.keypairFromSecretKey(secret_key);
        return noztr.nip19_bech32.nip19_encode(output, .{ .nsec = secret_key.* });
    }

    pub fn encodeEntity(
        self: LocalOperatorClient,
        output: []u8,
        entity: noztr.nip19_bech32.Nip19Entity,
    ) LocalOperatorClientError![]const u8 {
        _ = self;
        return noztr.nip19_bech32.nip19_encode(output, entity);
    }

    pub fn decodeEntity(
        self: LocalOperatorClient,
        input: []const u8,
        tlv_scratch: []u8,
    ) LocalOperatorClientError!noztr.nip19_bech32.Nip19Entity {
        _ = self;
        return noztr.nip19_bech32.nip19_decode(input, tlv_scratch);
    }

    pub fn parseEventJson(
        self: LocalOperatorClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) LocalOperatorClientError!noztr.nip01_event.Event {
        _ = self;
        return noztr.nip01_event.event_parse_json(event_json, scratch);
    }

    pub fn verifyEvent(
        self: LocalOperatorClient,
        event: *const noztr.nip01_event.Event,
    ) LocalOperatorClientError!void {
        _ = self;
        return noztr.nip01_event.event_verify(event);
    }

    pub fn inspectEvent(
        self: LocalOperatorClient,
        event: *const noztr.nip01_event.Event,
    ) LocalEventInspection {
        _ = self;
        return .{ .event = event.* };
    }

    pub fn inspectEventJson(
        self: LocalOperatorClient,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) LocalOperatorClientError!LocalEventInspection {
        const event = try self.parseEventJson(event_json, scratch);
        try self.verifyEvent(&event);
        return self.inspectEvent(&event);
    }

    pub fn signerCapabilityProfile(
        self: LocalOperatorClient,
    ) signer_capability.Profile {
        _ = self;
        return .localOperator();
    }

    pub fn buildUnsignedEvent(
        self: LocalOperatorClient,
        draft: *const LocalEventDraft,
        public_key: *const [public_key_bytes]u8,
    ) noztr.nip01_event.Event {
        _ = self;
        return .{
            .id = [_]u8{0} ** event_id_bytes,
            .pubkey = public_key.*,
            .sig = [_]u8{0} ** signature_bytes,
            .kind = draft.kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = draft.tags,
        };
    }

    pub fn signEvent(
        self: LocalOperatorClient,
        secret_key: *const [secret_key_bytes]u8,
        event: *noztr.nip01_event.Event,
    ) LocalOperatorClientError!void {
        _ = self;
        return noztr.nostr_keys.nostr_sign_event(secret_key, event);
    }

    pub fn signDraft(
        self: LocalOperatorClient,
        secret_key: *const [secret_key_bytes]u8,
        draft: *const LocalEventDraft,
    ) LocalOperatorClientError!noztr.nip01_event.Event {
        const public_key = try self.derivePublicKey(secret_key);
        var event = self.buildUnsignedEvent(draft, &public_key);
        try self.signEvent(secret_key, &event);
        return event;
    }

    pub fn completeSignerCapabilityOperation(
        self: LocalOperatorClient,
        output: []u8,
        secret_key: *const [secret_key_bytes]u8,
        request: *const signer_capability.OperationRequest,
        scratch: std.mem.Allocator,
    ) LocalOperatorSignerCapabilityError!signer_capability.OperationResult {
        return switch (request.*) {
            .get_public_key => .{ .user_pubkey = try self.derivePublicKey(secret_key) },
            .sign_event => |unsigned_event_json| blk: {
                var event = try self.parseEventJson(unsigned_event_json, scratch);
                try self.signEvent(secret_key, &event);
                const signed_event_json = try self.serializeEventJson(output, &event);
                break :blk .{ .signed_event_json = signed_event_json };
            },
            .nip44_encrypt => |value| blk: {
                const ciphertext = try self.encryptNip44ToPeer(
                    output,
                    secret_key,
                    &value.pubkey,
                    value.text,
                );
                break :blk .{
                    .text_response = .{
                        .operation = .nip44_encrypt,
                        .text = ciphertext,
                    },
                };
            },
            .nip44_decrypt => |value| blk: {
                const plaintext = try self.decryptNip44FromPeer(
                    output,
                    secret_key,
                    &value.pubkey,
                    value.text,
                );
                break :blk .{
                    .text_response = .{
                        .operation = .nip44_decrypt,
                        .text = plaintext,
                    },
                };
            },
            .nip04_encrypt,
            .nip04_decrypt,
            => error.UnsupportedSignerOperation,
        };
    }

    pub fn serializeEventJson(
        self: LocalOperatorClient,
        output: []u8,
        event: *const noztr.nip01_event.Event,
    ) LocalOperatorClientError![]const u8 {
        _ = self;
        return noztr.nip01_event.event_serialize_json_object(output, event);
    }

    pub fn deriveConversationKey(
        self: LocalOperatorClient,
        secret_key: *const [secret_key_bytes]u8,
        peer_public_key: *const [public_key_bytes]u8,
    ) LocalOperatorClientError![32]u8 {
        _ = self;
        return noztr.nip44.nip44_get_conversation_key(secret_key, peer_public_key);
    }

    pub fn encryptNip44ToPeer(
        self: LocalOperatorClient,
        output: []u8,
        secret_key: *const [secret_key_bytes]u8,
        peer_public_key: *const [public_key_bytes]u8,
        plaintext: []const u8,
    ) LocalOperatorClientError![]const u8 {
        const conversation_key = try self.deriveConversationKey(secret_key, peer_public_key);
        return noztr.nip44.nip44_encrypt_to_base64(
            output,
            &conversation_key,
            plaintext,
            null,
            randomNip44Nonce,
        );
    }

    pub fn encryptNip44ToPeerWithNonce(
        self: LocalOperatorClient,
        output: []u8,
        secret_key: *const [secret_key_bytes]u8,
        peer_public_key: *const [public_key_bytes]u8,
        plaintext: []const u8,
        nonce: *const [32]u8,
    ) LocalOperatorClientError![]const u8 {
        const conversation_key = try self.deriveConversationKey(secret_key, peer_public_key);
        return noztr.nip44.nip44_encrypt_with_nonce_to_base64(
            output,
            &conversation_key,
            plaintext,
            nonce,
        );
    }

    pub fn decryptNip44FromPeer(
        self: LocalOperatorClient,
        output: []u8,
        secret_key: *const [secret_key_bytes]u8,
        peer_public_key: *const [public_key_bytes]u8,
        payload: []const u8,
    ) LocalOperatorClientError![]const u8 {
        const conversation_key = try self.deriveConversationKey(secret_key, peer_public_key);
        return noztr.nip44.nip44_decrypt_from_base64(output, &conversation_key, payload);
    }
};

fn parseHex32(
    text: []const u8,
    comptime invalid_error: LocalOperatorClientError,
) LocalOperatorClientError![32]u8 {
    if (text.len != secret_key_hex_bytes) return invalid_error;

    var value: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(value[0..], text) catch return invalid_error;
    return value;
}

fn randomNip44Nonce(
    _: ?*anyopaque,
    out_nonce: *[32]u8,
) noztr.nip44.ConversationEncryptionError!void {
    std.crypto.random.bytes(out_nonce[0..]);
}

test "local operator client generates and derives usable key material" {
    const client = LocalOperatorClient.init(.{});

    const generated = try client.generateKeypair();
    const reparsed_public = try client.derivePublicKey(&generated.secret_key);
    try std.testing.expectEqualSlices(u8, generated.public_key[0..], reparsed_public[0..]);

    const deterministic_secret = [_]u8{0x11} ** 32;
    const keypair = try client.keypairFromSecretKey(&deterministic_secret);
    const secret_hex = keypair.secretKeyHex();
    const public_hex = keypair.publicKeyHex();
    const reparsed_secret = try client.parseSecretKeyHex(secret_hex[0..]);
    const reparsed_pubkey = try client.parsePublicKeyHex(public_hex[0..]);
    try std.testing.expectEqualSlices(u8, deterministic_secret[0..], reparsed_secret[0..]);
    try std.testing.expectEqualSlices(u8, keypair.public_key[0..], reparsed_pubkey[0..]);
}

test "local operator client roundtrips npub and nsec entities" {
    const client = LocalOperatorClient.init(.{});
    const secret_key = [_]u8{0x11} ** 32;
    const keypair = try client.keypairFromSecretKey(&secret_key);

    var npub_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var nsec_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    const npub = try client.encodeNpub(npub_output[0..], &keypair.public_key);
    const nsec = try client.encodeNsec(nsec_output[0..], &keypair.secret_key);

    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    const decoded_npub = try client.decodeEntity(npub, tlv_scratch[0..]);
    try std.testing.expect(decoded_npub == .npub);
    try std.testing.expectEqualSlices(
        u8,
        keypair.public_key[0..],
        decoded_npub.npub[0..],
    );

    const decoded_nsec = try client.decodeEntity(nsec, tlv_scratch[0..]);
    try std.testing.expect(decoded_nsec == .nsec);
    try std.testing.expectEqualSlices(
        u8,
        keypair.secret_key[0..],
        decoded_nsec.nsec[0..],
    );
}

test "local operator client inspects and signs local events over kernel boundaries" {
    const client = LocalOperatorClient.init(.{});
    const secret_key = [_]u8{0x11} ** 32;
    const draft = LocalEventDraft{
        .kind = 1,
        .created_at = 7,
        .content = "hello from local tooling",
    };

    var signed = try client.signDraft(&secret_key, &draft);
    try noztr.nip01_event.event_verify(&signed);

    const signed_view = client.inspectEvent(&signed);
    try std.testing.expectEqual(
        std.fmt.bytesToHex(signed.id, .lower),
        signed_view.eventIdHex(),
    );

    var json_output: [512]u8 = undefined;
    const event_json = try client.serializeEventJson(json_output[0..], &signed);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed_view = try client.inspectEventJson(event_json, arena.allocator());
    try std.testing.expectEqualStrings("hello from local tooling", parsed_view.event.content);
    try std.testing.expectEqualSlices(u8, signed.id[0..], parsed_view.event.id[0..]);
    try std.testing.expectEqualSlices(u8, signed.pubkey[0..], parsed_view.event.pubkey[0..]);
}

test "local operator client composes local nip44 encrypt and decrypt over peer keys" {
    const client = LocalOperatorClient.init(.{});
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const sender_pubkey = try client.derivePublicKey(&sender_secret);
    const recipient_pubkey = try client.derivePublicKey(&recipient_secret);
    const nonce = [_]u8{0} ** 31 ++ [_]u8{1};

    var ciphertext_output: [noztr.limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const ciphertext = try client.encryptNip44ToPeerWithNonce(
        ciphertext_output[0..],
        &sender_secret,
        &recipient_pubkey,
        "hello peer",
        &nonce,
    );

    var plaintext_output: [noztr.limits.nip44_plaintext_max_bytes]u8 = undefined;
    const plaintext = try client.decryptNip44FromPeer(
        plaintext_output[0..],
        &recipient_secret,
        &sender_pubkey,
        ciphertext,
    );
    try std.testing.expectEqualStrings("hello peer", plaintext);
}

test "local operator client rejects invalid key text and malformed nip19 text" {
    const client = LocalOperatorClient.init(.{});

    try std.testing.expectError(
        error.InvalidSecretKeyHex,
        client.parseSecretKeyHex("zz"),
    );
    try std.testing.expectError(
        error.InvalidPublicKeyHex,
        client.parsePublicKeyHex("zz"),
    );

    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    try std.testing.expectError(
        error.InvalidBech32,
        client.decodeEntity("nostr", tlv_scratch[0..]),
    );
}

test "local operator client adapts onto the signer capability surface" {
    const client = LocalOperatorClient.init(.{});
    const secret_key = [_]u8{0x11} ** 32;
    const peer_secret = [_]u8{0x22} ** 32;
    const peer_pubkey = try client.derivePublicKey(&peer_secret);

    const capability = client.signerCapabilityProfile();
    try std.testing.expectEqual(.local, capability.backend);
    try std.testing.expectEqual(.local_immediate, capability.modeFor(.get_public_key));
    try std.testing.expectEqual(.unsupported, capability.modeFor(.nip04_decrypt));

    var output: [512]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const get_public_key_request: signer_capability.OperationRequest = .{ .get_public_key = {} };
    const get_public_key_result = try client.completeSignerCapabilityOperation(
        output[0..],
        &secret_key,
        &get_public_key_request,
        arena.allocator(),
    );
    try std.testing.expect(get_public_key_request.acceptsResult(&get_public_key_result));

    var unsigned_event = client.buildUnsignedEvent(
        &.{
            .kind = 1,
            .created_at = 42,
            .content = "sign me",
        },
        &get_public_key_result.user_pubkey,
    );
    var unsigned_event_json_output: [512]u8 = undefined;
    const unsigned_event_json = try client.serializeEventJson(unsigned_event_json_output[0..], &unsigned_event);
    const sign_event_request: signer_capability.OperationRequest = .{
        .sign_event = unsigned_event_json,
    };
    const sign_event_result = try client.completeSignerCapabilityOperation(
        output[0..],
        &secret_key,
        &sign_event_request,
        arena.allocator(),
    );
    try std.testing.expect(sign_event_request.acceptsResult(&sign_event_result));

    const decrypt_request: signer_capability.OperationRequest = .{
        .nip04_decrypt = .{
            .pubkey = peer_pubkey,
            .text = "ciphertext",
        },
    };
    try std.testing.expectError(
        error.UnsupportedSignerOperation,
        client.completeSignerCapabilityOperation(
            output[0..],
            &secret_key,
            &decrypt_request,
            arena.allocator(),
        ),
    );
}
