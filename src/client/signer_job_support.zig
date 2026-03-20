const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth = @import("../relay/auth.zig");
const relay_auth_client = @import("relay_auth_client.zig");
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
    fillAuthEventStorage(auth_storage, state.relayUrl(), state.challengeText());

    const draft = local_operator.LocalEventDraft{
        .kind = noztr.nip42_auth.auth_event_kind,
        .created_at = created_at,
        .content = "",
        .tags = auth_storage.tags[0..],
    };
    var event = try local.signDraft(secret_key, &draft);
    const event_json = try local.serializeEventJson(event_json_output, &event);
    const auth_message_json = try serializeAuthClientMessage(auth_message_output, &event);
    return .{
        .relay_url = state.relayUrl(),
        .challenge = state.challengeText(),
        .event = event,
        .event_json = event_json,
        .auth_message_json = auth_message_json,
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

fn fillAuthEventStorage(
    storage: *SignerJobAuthEventStorage,
    relay_url_text: []const u8,
    challenge_text: []const u8,
) void {
    std.debug.assert(relay_url_text.len <= relay_auth.relay_url_max_bytes);
    std.debug.assert(challenge_text.len <= noztr.nip42_auth.challenge_max_bytes);

    storage.* = .{};
    @memcpy(storage.relay_url[0..relay_url_text.len], relay_url_text);
    storage.relay_url_len = @intCast(relay_url_text.len);
    @memcpy(storage.challenge[0..challenge_text.len], challenge_text);
    storage.challenge_len = @intCast(challenge_text.len);
    storage.relay_items = .{ "relay", storage.relayUrl() };
    storage.challenge_items = .{ "challenge", storage.challengeText() };
    storage.tags = .{
        .{ .items = storage.relay_items[0..] },
        .{ .items = storage.challenge_items[0..] },
    };
}

fn serializeAuthClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) noztr.nip01_message.MessageEncodeError![]const u8 {
    const message = noztr.nip01_message.ClientMessage{ .auth = .{ .event = event.* } };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
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
