const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth = @import("../relay/auth.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const noztr = @import("noztr");

pub const SignerJobAuthError =
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        MissingAuthChallenge,
        StaleAuthState,
    };

pub const SignerJobAuthEventStorage = relay_auth_client.RelayAuthEventStorage;

pub const PreparedSignerJobAuthEvent = struct {
    relay_url: []const u8,
    challenge: []const u8,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    auth_message_json: []const u8,
};

pub const SignerJobAuthState = struct {
    relay_url: [relay_auth.relay_url_max_bytes]u8 = [_]u8{0} ** relay_auth.relay_url_max_bytes,
    relay_url_len: u16 = 0,
    challenge: [noztr.nip42_auth.challenge_max_bytes]u8 =
        [_]u8{0} ** noztr.nip42_auth.challenge_max_bytes,
    challenge_len: u8 = 0,
    active: bool = false,

    pub fn clear(self: *SignerJobAuthState) void {
        self.relay_url_len = 0;
        self.challenge_len = 0;
        self.active = false;
        @memset(self.relay_url[0..], 0);
        @memset(self.challenge[0..], 0);
    }

    pub fn remember(
        self: *SignerJobAuthState,
        relay_url_text: []const u8,
        challenge_text: []const u8,
    ) void {
        std.debug.assert(relay_url_text.len <= relay_auth.relay_url_max_bytes);
        std.debug.assert(challenge_text.len <= noztr.nip42_auth.challenge_max_bytes);

        self.clear();
        @memcpy(self.relay_url[0..relay_url_text.len], relay_url_text);
        @memcpy(self.challenge[0..challenge_text.len], challenge_text);
        self.relay_url_len = @intCast(relay_url_text.len);
        self.challenge_len = @intCast(challenge_text.len);
        self.active = true;
    }

    pub fn relayUrl(self: *const SignerJobAuthState) []const u8 {
        return self.relay_url[0..self.relay_url_len];
    }

    pub fn challengeText(self: *const SignerJobAuthState) []const u8 {
        return self.challenge[0..self.challenge_len];
    }
};

pub fn prepareAuthEvent(
    local: *const local_operator.LocalOperatorClient,
    state: *const SignerJobAuthState,
    auth_storage: *SignerJobAuthEventStorage,
    event_json_output: []u8,
    auth_message_output: []u8,
    secret_key: *const [local_operator.secret_key_bytes]u8,
    created_at: u64,
) SignerJobAuthError!PreparedSignerJobAuthEvent {
    if (!state.active) return error.MissingAuthChallenge;
    const payload = try relay_auth_support.buildSignedAuthPayload(
        local,
        auth_storage,
        event_json_output,
        auth_message_output,
        secret_key,
        created_at,
        state.relayUrl(),
        state.challengeText(),
    );
    return .{
        .relay_url = state.relayUrl(),
        .challenge = state.challengeText(),
        .event = payload.event,
        .event_json = payload.event_json,
        .auth_message_json = payload.auth_message_json,
    };
}

pub fn requireCurrentAuthState(
    state: *const SignerJobAuthState,
    relay_url_text: []const u8,
    challenge_text: []const u8,
) SignerJobAuthError!void {
    if (!state.active) return error.MissingAuthChallenge;
    if (!std.mem.eql(u8, state.relayUrl(), relay_url_text)) return error.StaleAuthState;
    if (!std.mem.eql(u8, state.challengeText(), challenge_text)) return error.StaleAuthState;
}

test "signer job auth state remembers and clears one relay challenge" {
    var state = SignerJobAuthState{};
    state.remember("wss://relay.one", "challenge-1");

    try std.testing.expect(state.active);
    try std.testing.expectEqualStrings("wss://relay.one", state.relayUrl());
    try std.testing.expectEqualStrings("challenge-1", state.challengeText());

    state.clear();
    try std.testing.expect(!state.active);
    try std.testing.expectEqual(@as(usize, 0), state.relayUrl().len);
    try std.testing.expectEqual(@as(usize, 0), state.challengeText().len);
}
