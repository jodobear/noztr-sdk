const noztr = @import("noztr");

pub fn simpleEvent(
    kind: u32,
    pubkey: [32]u8,
    created_at: u64,
    content: []const u8,
    tags: []const noztr.nip01_event.EventTag,
) noztr.nip01_event.Event {
    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = created_at,
        .content = content,
        .tags = tags,
    };
}

pub fn derivePublicKey(secret_key: *const [32]u8) ![32]u8 {
    return noztr.nostr_keys.nostr_derive_public_key(secret_key);
}

pub fn signEvent(secret_key: *const [32]u8, event: *noztr.nip01_event.Event) !void {
    try noztr.nostr_keys.nostr_sign_event(secret_key, event);
}

pub fn serializeEventJson(output: []u8, event: *const noztr.nip01_event.Event) ![]const u8 {
    return noztr.nip01_event.event_serialize_json_object(output, event);
}
