const std = @import("std");
const noztr = @import("noztr");
const relay_url = @import("url.zig");

pub const relay_url_max_bytes: u16 = relay_url.relay_url_max_bytes;

pub const AuthSession = struct {
    relay_url: [relay_url_max_bytes]u8 = [_]u8{0} ** relay_url_max_bytes,
    relay_url_len: u16 = 0,
    state: noztr.nip42_auth.AuthState = .{},

    pub fn init(relay_url_text: []const u8) error{RelayUrlTooLong}!AuthSession {
        if (relay_url_text.len > relay_url_max_bytes) return error.RelayUrlTooLong;

        var session = AuthSession{};
        session.relay_url_len = @intCast(relay_url_text.len);
        @memcpy(session.relay_url[0..relay_url_text.len], relay_url_text);
        noztr.nip42_auth.auth_state_init(&session.state);
        return session;
    }

    pub fn relayUrl(self: *const AuthSession) []const u8 {
        return self.relay_url[0..self.relay_url_len];
    }

    pub fn setChallenge(
        self: *AuthSession,
        challenge: []const u8,
    ) error{ ChallengeEmpty, ChallengeTooLong }!void {
        return noztr.nip42_auth.auth_state_set_challenge(&self.state, challenge);
    }

    pub fn acceptEvent(
        self: *AuthSession,
        auth_event: *const noztr.nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) noztr.nip42_auth.AuthError!void {
        return noztr.nip42_auth.auth_state_accept_event(
            &self.state,
            auth_event,
            self.relayUrl(),
            now_unix_seconds,
            window_seconds,
        );
    }
};
