const std = @import("std");
const session = @import("session.zig");
const relay_url = @import("url.zig");

pub const pool_capacity: u8 = 32;

pub const Pool = struct {
    sessions: [pool_capacity]session.RelaySession = undefined,
    count: u8 = 0,

    pub fn init() Pool {
        return .{
            .sessions = undefined,
            .count = 0,
        };
    }

    pub fn addRelay(self: *Pool, relay_url_text: []const u8) error{ InvalidRelayUrl, RelayUrlTooLong, PoolFull }!u8 {
        std.debug.assert(@intFromPtr(self) != 0);

        try relay_url.relayUrlValidate(relay_url_text);
        if (self.findRelayIndex(relay_url_text)) |index| return index;
        if (self.count == pool_capacity) return error.PoolFull;
        self.sessions[self.count] = try session.RelaySession.init(relay_url_text);
        self.count += 1;
        return self.count - 1;
    }

    pub fn getRelay(self: *Pool, index: u8) ?*session.RelaySession {
        if (index >= self.count) return null;
        return &self.sessions[index];
    }

    pub fn getRelayConst(self: *const Pool, index: u8) ?*const session.RelaySession {
        if (index >= self.count) return null;
        return &self.sessions[index];
    }

    fn findRelayIndex(self: *const Pool, relay_url_text: []const u8) ?u8 {
        var index: u8 = 0;
        while (index < self.count) : (index += 1) {
            if (relay_url.relayUrlsEquivalent(self.sessions[index].auth_session.relayUrl(), relay_url_text)) {
                return index;
            }
        }
        return null;
    }
};

test "pool adds bounded relay sessions" {
    var pool = Pool.init();
    const index = try pool.addRelay("wss://relay.one");
    try std.testing.expectEqual(@as(u8, 0), index);
    try std.testing.expect(pool.getRelay(index) != null);
}

test "pool deduplicates identical relay urls" {
    var pool = Pool.init();
    const first = try pool.addRelay("wss://relay.one");
    const second = try pool.addRelay("wss://relay.one");
    try std.testing.expectEqual(first, second);
    try std.testing.expectEqual(@as(u8, 1), pool.count);
}

test "pool deduplicates normalized-equivalent relay urls" {
    var pool = Pool.init();
    const first = try pool.addRelay("wss://relay.example.com/path/exact");
    const second = try pool.addRelay("WSS://RELAY.EXAMPLE.COM:443/path/exact?x=1#f");
    try std.testing.expectEqual(first, second);
    try std.testing.expectEqual(@as(u8, 1), pool.count);
}
