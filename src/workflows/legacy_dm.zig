const std = @import("std");
const noztr = @import("noztr");

pub const LegacyDmError =
    noztr.nip04.LegacyDmError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    noztr.nip01_event.EventSerializeError ||
    noztr.nostr_keys.NostrKeysError ||
    error{
        InvalidRecipientRelayHint,
        InvalidReplyRelayHint,
    };

pub const max_tag_items: u8 = 2;

pub const LegacyDmDirectMessageRequest = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    reply_to: ?noztr.nip04.Nip04ReplyRef = null,
    content: []const u8,
    created_at: u64,
    iv: [noztr.limits.nip04_iv_bytes]u8,
};

pub const LegacyDmOutboundStorage = struct {
    payload: [noztr.limits.content_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.content_bytes_max,
    recipient_pubkey_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    recipient_relay_hint: [noztr.limits.tag_item_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.tag_item_bytes_max,
    reply_event_id_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    reply_relay_hint: [noztr.limits.tag_item_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.tag_item_bytes_max,
    recipient_items: [3][]const u8 = undefined,
    reply_items: [3][]const u8 = undefined,
    tags: [max_tag_items]noztr.nip01_event.EventTag = undefined,
    tag_count: u8 = 0,
};

/// `event` borrows from the caller-provided outbound storage.
pub const PreparedLegacyDmEvent = struct {
    event: noztr.nip01_event.Event,
};

/// `event` and `message` borrow from caller-provided parse scratch when JSON intake is used.
/// `plaintext` borrows from caller-provided plaintext output.
pub const LegacyDmMessageOutcome = struct {
    event: noztr.nip01_event.Event,
    message: noztr.nip04.Nip04MessageInfo,
    plaintext: []const u8,
};

pub const LegacyDmSession = struct {
    owner_private_key: [32]u8,

    pub fn init(owner_private_key: *const [32]u8) LegacyDmSession {
        return .{ .owner_private_key = owner_private_key.* };
    }

    pub fn ownerPublicKey(self: *const LegacyDmSession) LegacyDmError![32]u8 {
        return noztr.nostr_keys.nostr_derive_public_key(&self.owner_private_key);
    }

    pub fn buildDirectMessageEvent(
        self: *const LegacyDmSession,
        storage: *LegacyDmOutboundStorage,
        request: *const LegacyDmDirectMessageRequest,
    ) LegacyDmError!PreparedLegacyDmEvent {
        storage.* = .{};

        const sender_pubkey = try self.ownerPublicKey();
        const payload = try noztr.nip04.nip04_encrypt_with_iv(
            storage.payload[0..],
            &self.owner_private_key,
            &request.recipient_pubkey,
            request.content,
            &request.iv,
        );

        storage.tags[0] = try buildRecipientTag(
            storage,
            &request.recipient_pubkey,
            request.recipient_relay_hint,
        );
        storage.tag_count = 1;
        if (request.reply_to) |reply_to| {
            storage.tags[1] = try buildReplyTag(storage, &reply_to);
            storage.tag_count = 2;
        }

        var event: noztr.nip01_event.Event = .{
            .id = [_]u8{0} ** 32,
            .pubkey = sender_pubkey,
            .sig = [_]u8{0} ** 64,
            .kind = noztr.nip04.dm_kind,
            .created_at = request.created_at,
            .tags = storage.tags[0..storage.tag_count],
            .content = payload,
        };
        try noztr.nostr_keys.nostr_sign_event(&self.owner_private_key, &event);
        return .{ .event = event };
    }

    pub fn serializeDirectMessageEventJson(
        self: *const LegacyDmSession,
        output: []u8,
        event: *const noztr.nip01_event.Event,
    ) LegacyDmError![]const u8 {
        _ = self;
        return noztr.nip01_event.event_serialize_json_object(output, event);
    }

    pub fn acceptDirectMessageEvent(
        self: *const LegacyDmSession,
        event: *const noztr.nip01_event.Event,
        plaintext_output: []u8,
    ) LegacyDmError!LegacyDmMessageOutcome {
        try noztr.nip01_event.event_verify(event);
        const message = try noztr.nip04.nip04_message_parse(event);
        const plaintext = try noztr.nip04.nip04_decrypt(
            plaintext_output,
            &self.owner_private_key,
            &event.pubkey,
            message.content,
        );
        return .{
            .event = event.*,
            .message = message,
            .plaintext = plaintext,
        };
    }

    pub fn acceptDirectMessageEventJson(
        self: *const LegacyDmSession,
        event_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) LegacyDmError!LegacyDmMessageOutcome {
        const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
        return self.acceptDirectMessageEvent(&event, plaintext_output);
    }
};

fn buildRecipientTag(
    storage: *LegacyDmOutboundStorage,
    recipient_pubkey: *const [32]u8,
    relay_hint: ?[]const u8,
) LegacyDmError!noztr.nip01_event.EventTag {
    const pubkey_hex = std.fmt.bytesToHex(recipient_pubkey.*, .lower);
    @memcpy(storage.recipient_pubkey_hex[0..], pubkey_hex[0..]);
    storage.recipient_items[0] = "p";
    storage.recipient_items[1] = storage.recipient_pubkey_hex[0..];
    var item_count: u8 = 2;
    if (relay_hint) |hint| {
        const copied = try copyRecipientRelayHint(storage.recipient_relay_hint[0..], hint);
        storage.recipient_items[2] = copied;
        item_count = 3;
    }
    return .{ .items = storage.recipient_items[0..item_count] };
}

fn buildReplyTag(
    storage: *LegacyDmOutboundStorage,
    reply_to: *const noztr.nip04.Nip04ReplyRef,
) LegacyDmError!noztr.nip01_event.EventTag {
    const event_id_hex = std.fmt.bytesToHex(reply_to.event_id, .lower);
    @memcpy(storage.reply_event_id_hex[0..], event_id_hex[0..]);
    storage.reply_items[0] = "e";
    storage.reply_items[1] = storage.reply_event_id_hex[0..];
    var item_count: u8 = 2;
    if (reply_to.relay_hint) |hint| {
        const copied = try copyReplyRelayHint(storage.reply_relay_hint[0..], hint);
        storage.reply_items[2] = copied;
        item_count = 3;
    }
    return .{ .items = storage.reply_items[0..item_count] };
}

fn copyRecipientRelayHint(output: []u8, input: []const u8) error{InvalidRecipientRelayHint}![]const u8 {
    if (input.len == 0 or input.len > output.len) return error.InvalidRecipientRelayHint;
    const parsed = std.Uri.parse(input) catch return error.InvalidRecipientRelayHint;
    if (parsed.scheme.len == 0 or parsed.host == null) return error.InvalidRecipientRelayHint;
    @memcpy(output[0..input.len], input);
    return output[0..input.len];
}

fn copyReplyRelayHint(output: []u8, input: []const u8) error{InvalidReplyRelayHint}![]const u8 {
    if (input.len == 0 or input.len > output.len) return error.InvalidReplyRelayHint;
    const parsed = std.Uri.parse(input) catch return error.InvalidReplyRelayHint;
    if (parsed.scheme.len == 0 or parsed.host == null) return error.InvalidReplyRelayHint;
    @memcpy(output[0..input.len], input);
    return output[0..input.len];
}

test "legacy dm session builds signs parses and decrypts one legacy kind4 event" {
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    const sender = LegacyDmSession.init(&sender_secret);
    var outbound_storage = LegacyDmOutboundStorage{};
    const prepared = try sender.buildDirectMessageEvent(&outbound_storage, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy dm workflow",
        .created_at = 41,
        .iv = [_]u8{0x55} ** noztr.limits.nip04_iv_bytes,
    });

    var plaintext: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const recipient = LegacyDmSession.init(&recipient_secret);
    const outcome = try recipient.acceptDirectMessageEvent(&prepared.event, plaintext[0..]);
    try std.testing.expectEqual(noztr.nip04.dm_kind, outcome.event.kind);
    try std.testing.expectEqualStrings("legacy dm workflow", outcome.plaintext);
    try std.testing.expect(std.mem.eql(u8, &outcome.message.recipient_pubkey, &recipient_pubkey));
}

test "legacy dm session keeps reply and relay hints in the event shape" {
    const sender_secret = [_]u8{0x31} ** 32;
    const recipient_secret = [_]u8{0x42} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    const session = LegacyDmSession.init(&sender_secret);
    var outbound_storage = LegacyDmOutboundStorage{};
    const prepared = try session.buildDirectMessageEvent(&outbound_storage, &.{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_hint = "wss://dm.example",
        .reply_to = .{
            .event_id = [_]u8{0x99} ** 32,
            .relay_hint = "wss://thread.example",
        },
        .content = "thread reply",
        .created_at = 42,
        .iv = [_]u8{0x66} ** noztr.limits.nip04_iv_bytes,
    });

    const parsed = try noztr.nip04.nip04_message_parse(&prepared.event);
    try std.testing.expectEqualStrings("wss://dm.example", parsed.recipient_relay_hint.?);
    try std.testing.expect(parsed.reply_to != null);
    try std.testing.expectEqualStrings("wss://thread.example", parsed.reply_to.?.relay_hint.?);
}

test "legacy dm session accepts event json intake explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x51} ** 32;
    const recipient_secret = [_]u8{0x62} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    const sender = LegacyDmSession.init(&sender_secret);
    var outbound_storage = LegacyDmOutboundStorage{};
    const prepared = try sender.buildDirectMessageEvent(&outbound_storage, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "json intake",
        .created_at = 43,
        .iv = [_]u8{0x77} ** noztr.limits.nip04_iv_bytes,
    });

    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    const event_json = try sender.serializeDirectMessageEventJson(
        event_json_output[0..],
        &prepared.event,
    );

    var plaintext: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
    const recipient = LegacyDmSession.init(&recipient_secret);
    const outcome = try recipient.acceptDirectMessageEventJson(
        event_json,
        plaintext[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("json intake", outcome.plaintext);
}

test "legacy dm session accepts standard reply e-tag variants through parse and decrypt" {
    const sender_secret = [_]u8{0x71} ** 32;
    const recipient_secret = [_]u8{0x82} ** 32;
    const author_pubkey = [_]u8{0xaa} ** 32;
    const reply_event_id = [_]u8{0x99} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);

    const sender = LegacyDmSession.init(&sender_secret);
    const recipient = LegacyDmSession.init(&recipient_secret);
    const relay_hint = "wss://thread.example";
    const variants = [_]ReplyTagVariant{
        .event_only,
        .event_and_reply,
        .event_and_relay,
        .event_relay_and_reply,
        .event_relay_reply_and_author,
    };

    for (variants, 0..) |variant, index| {
        var fixture = ReplyTagVariantFixture{};
        const event = try buildSignedLegacyDmEventWithReplyVariant(
            &fixture,
            &sender,
            &sender_secret,
            &recipient_pubkey,
            &reply_event_id,
            &author_pubkey,
            relay_hint,
            variant,
            @as(u64, 50) + index,
        );

        var plaintext: [noztr.limits.nip04_plaintext_max_bytes]u8 = undefined;
        const outcome = try recipient.acceptDirectMessageEvent(event, plaintext[0..]);
        try std.testing.expectEqualStrings("reply variant intake", outcome.plaintext);
        try std.testing.expect(outcome.message.reply_to != null);
        try std.testing.expect(std.mem.eql(
            u8,
            &reply_event_id,
            &outcome.message.reply_to.?.event_id,
        ));

        switch (variant) {
            .event_only, .event_and_reply => {
                try std.testing.expect(outcome.message.reply_to.?.relay_hint == null);
            },
            .event_and_relay, .event_relay_and_reply, .event_relay_reply_and_author => {
                try std.testing.expectEqualStrings(
                    relay_hint,
                    outcome.message.reply_to.?.relay_hint.?,
                );
            },
        }
    }
}

const ReplyTagVariant = enum {
    event_only,
    event_and_reply,
    event_and_relay,
    event_relay_and_reply,
    event_relay_reply_and_author,
};

const ReplyTagVariantFixture = struct {
    outbound: LegacyDmOutboundStorage = .{},
    recipient_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    reply_event_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    author_pubkey_hex: [noztr.limits.pubkey_hex_length]u8 =
        [_]u8{0} ** noztr.limits.pubkey_hex_length,
    relay_hint_storage: [noztr.limits.tag_item_bytes_max]u8 =
        [_]u8{0} ** noztr.limits.tag_item_bytes_max,
    recipient_items: [2][]const u8 = undefined,
    reply_items: [5][]const u8 = undefined,
    tags: [2]noztr.nip01_event.EventTag = undefined,
    event: noztr.nip01_event.Event = undefined,
};

fn buildSignedLegacyDmEventWithReplyVariant(
    fixture: *ReplyTagVariantFixture,
    sender: *const LegacyDmSession,
    sender_secret: *const [32]u8,
    recipient_pubkey: *const [32]u8,
    reply_event_id: *const [32]u8,
    author_pubkey: *const [32]u8,
    relay_hint: []const u8,
    variant: ReplyTagVariant,
    created_at: u64,
) !*const noztr.nip01_event.Event {
    fixture.* = .{};

    const prepared = try sender.buildDirectMessageEvent(&fixture.outbound, &.{
        .recipient_pubkey = recipient_pubkey.*,
        .content = "reply variant intake",
        .created_at = created_at,
        .iv = [_]u8{0x33} ** noztr.limits.nip04_iv_bytes,
    });

    const recipient_hex = std.fmt.bytesToHex(recipient_pubkey.*, .lower);
    @memcpy(fixture.recipient_hex[0..], recipient_hex[0..]);
    fixture.recipient_items = .{ "p", fixture.recipient_hex[0..] };
    fixture.tags[0] = .{ .items = fixture.recipient_items[0..] };

    const reply_event_hex = std.fmt.bytesToHex(reply_event_id.*, .lower);
    @memcpy(fixture.reply_event_hex[0..], reply_event_hex[0..]);
    const author_pubkey_hex = std.fmt.bytesToHex(author_pubkey.*, .lower);
    @memcpy(fixture.author_pubkey_hex[0..], author_pubkey_hex[0..]);
    @memcpy(fixture.relay_hint_storage[0..relay_hint.len], relay_hint);

    fixture.reply_items[0] = "e";
    fixture.reply_items[1] = fixture.reply_event_hex[0..];
    var item_count: usize = 2;

    switch (variant) {
        .event_only => {},
        .event_and_reply => {
            fixture.reply_items[item_count] = "reply";
            item_count += 1;
        },
        .event_and_relay => {
            fixture.reply_items[item_count] = fixture.relay_hint_storage[0..relay_hint.len];
            item_count += 1;
        },
        .event_relay_and_reply => {
            fixture.reply_items[item_count] = fixture.relay_hint_storage[0..relay_hint.len];
            fixture.reply_items[item_count + 1] = "reply";
            item_count += 2;
        },
        .event_relay_reply_and_author => {
            fixture.reply_items[item_count] = fixture.relay_hint_storage[0..relay_hint.len];
            fixture.reply_items[item_count + 1] = "reply";
            fixture.reply_items[item_count + 2] = fixture.author_pubkey_hex[0..];
            item_count += 3;
        },
    }

    fixture.tags[1] = .{ .items = fixture.reply_items[0..item_count] };
    fixture.event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = try sender.ownerPublicKey(),
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip04.dm_kind,
        .created_at = created_at,
        .tags = fixture.tags[0..],
        .content = prepared.event.content,
    };
    try noztr.nostr_keys.nostr_sign_event(sender_secret, &fixture.event);
    return &fixture.event;
}
