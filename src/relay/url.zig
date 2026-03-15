const std = @import("std");
const noztr = @import("noztr");

pub const relay_url_max_bytes: u16 = noztr.limits.nip65_relay_url_bytes_max;

pub fn relayUrlValidate(relay_url: []const u8) error{InvalidRelayUrl}!void {
    var out: [1]noztr.nip65_relays.RelayPermission = undefined;
    _ = try extractRelayPermissions(relay_url, null, out[0..]);
}

pub fn relayUrlsEquivalent(left: []const u8, right: []const u8) bool {
    if (std.mem.eql(u8, left, right)) return true;

    var out: [2]noztr.nip65_relays.RelayPermission = undefined;
    const count = extractRelayPermissions(left, right, out[0..]) catch return false;
    return count == 1;
}

fn extractRelayPermissions(
    left: []const u8,
    right: ?[]const u8,
    out: []noztr.nip65_relays.RelayPermission,
) error{InvalidRelayUrl}!u16 {
    const left_items = [_][]const u8{ "r", left };
    const right_items = [_][]const u8{ "r", right orelse left };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = left_items[0..] },
        .{ .items = right_items[0..] },
    };
    const event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 10002,
        .created_at = 0,
        .content = "",
        .tags = tags[0 .. if (right != null) 2 else 1],
    };

    return noztr.nip65_relays.relay_list_extract(&event, out) catch |err| switch (err) {
        error.InvalidRelayUrl => error.InvalidRelayUrl,
        error.InvalidEventKind,
        error.InvalidRelayTag,
        error.InvalidMarker,
        error.BufferTooSmall,
        => unreachable,
    };
}

test "relay url validate accepts current noztr relay url envelope" {
    try relayUrlValidate("wss://relay.example.com/path");
}

test "relay urls equivalent follows current noztr normalization" {
    try std.testing.expect(
        relayUrlsEquivalent(
            "WSS://RELAY.EXAMPLE.COM:443/path/exact?x=1#f",
            "wss://relay.example.com/path/exact",
        ),
    );
    try std.testing.expect(
        !relayUrlsEquivalent(
            "wss://relay.example.com/path/exact",
            "wss://relay.example.com/path/other",
        ),
    );
}
