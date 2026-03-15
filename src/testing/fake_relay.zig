const session = @import("../relay/session.zig");

pub const FakeRelay = struct {
    relay_url: []const u8,
    challenge: []const u8,

    pub fn requireAuth(self: *const FakeRelay, relay_session: *session.RelaySession) !void {
        relay_session.connect();
        try relay_session.requireAuth(self.challenge);
    }
};
