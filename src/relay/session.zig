const std = @import("std");
const auth = @import("auth.zig");
const noztr = @import("noztr");

pub const SessionState = enum {
    disconnected,
    connected,
    auth_required,
};

pub const RelaySession = struct {
    auth_session: auth.AuthSession,
    state: SessionState = .disconnected,

    pub fn init(relay_url: []const u8) error{RelayUrlTooLong}!RelaySession {
        return .{
            .auth_session = try auth.AuthSession.init(relay_url),
            .state = .disconnected,
        };
    }

    pub fn connect(self: *RelaySession) void {
        if (self.state == .auth_required) return;
        self.state = .connected;
    }

    pub fn requireAuth(
        self: *RelaySession,
        challenge: []const u8,
    ) error{ ChallengeEmpty, ChallengeTooLong, NotConnected }!void {
        if (self.state != .connected) return error.NotConnected;
        try self.auth_session.setChallenge(challenge);
        self.state = .auth_required;
    }

    pub fn acceptAuthEvent(
        self: *RelaySession,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) (noztr.nip42_auth.AuthError || error{AuthNotRequired})!void {
        if (self.state != .auth_required) return error.AuthNotRequired;
        try self.auth_session.acceptEvent(auth_event, now_unix_seconds, window_seconds);
        self.state = .connected;
    }

    pub fn canSendRequests(self: *const RelaySession) bool {
        return self.state == .connected;
    }
};

test "relay session blocks requests when auth is required" {
    var session = try RelaySession.init("wss://relay.test");
    try std.testing.expect(!session.canSendRequests());
    session.connect();
    try std.testing.expect(session.canSendRequests());
    try session.requireAuth("challenge-1");
    try std.testing.expect(!session.canSendRequests());
    session.connect();
    try std.testing.expect(!session.canSendRequests());
}

test "relay session rejects auth before connection" {
    var session = try RelaySession.init("wss://relay.test");
    try std.testing.expectError(error.NotConnected, session.requireAuth("challenge-1"));
}
