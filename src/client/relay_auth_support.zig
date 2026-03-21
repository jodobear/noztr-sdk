const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_auth = @import("../relay/auth.zig");
const runtime = @import("../runtime/mod.zig");
const noztr = @import("noztr");

pub const RelayAuthTarget = struct {
    relay: runtime.RelayDescriptor,
    challenge: []const u8,
};

pub const RelayAuthEventStorage = struct {
    relay_url: [relay_auth.relay_url_max_bytes]u8 = [_]u8{0} ** relay_auth.relay_url_max_bytes,
    relay_url_len: u16 = 0,
    challenge: [noztr.nip42_auth.challenge_max_bytes]u8 =
        [_]u8{0} ** noztr.nip42_auth.challenge_max_bytes,
    challenge_len: u8 = 0,
    relay_items: [2][]const u8 = undefined,
    challenge_items: [2][]const u8 = undefined,
    tags: [2]noztr.nip01_event.EventTag = undefined,

    pub fn relayUrl(self: *const RelayAuthEventStorage) []const u8 {
        return self.relay_url[0..self.relay_url_len];
    }

    pub fn challengeText(self: *const RelayAuthEventStorage) []const u8 {
        return self.challenge[0..self.challenge_len];
    }
};

pub const PreparedRelayAuthEvent = struct {
    relay: runtime.RelayDescriptor,
    challenge: []const u8,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    auth_message_json: []const u8,
};

pub const SignedAuthPayload = struct {
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    auth_message_json: []const u8,
};

pub fn selectAuthTarget(
    relay_pool: *const runtime.RelayPool,
    auth_plan: runtime.RelayPoolAuthPlan,
    step: *const runtime.RelayPoolAuthStep,
) error{ StaleAuthStep, RelayNotReady }!RelayAuthTarget {
    const live_descriptor = relay_pool.descriptor(step.entry.descriptor.relay_index) orelse {
        return error.StaleAuthStep;
    };
    if (!std.mem.eql(u8, live_descriptor.relay_url, step.entry.descriptor.relay_url)) {
        return error.StaleAuthStep;
    }

    const current = auth_plan.entry(step.entry.descriptor.relay_index) orelse return error.StaleAuthStep;
    return requireCurrentAuthTarget(current, step.entry.descriptor, step.entry.challenge);
}

pub fn requireCurrentAuth(
    auth_plan: runtime.RelayPoolAuthPlan,
    descriptor: runtime.RelayDescriptor,
    challenge: []const u8,
) error{ StaleAuthStep, RelayNotReady }!void {
    const current = auth_plan.entry(descriptor.relay_index) orelse return error.StaleAuthStep;
    _ = try requireCurrentAuthTarget(current, descriptor, challenge);
}

pub fn buildSignedAuthPayload(
    local: *const local_operator.LocalOperatorClient,
    auth_storage: *RelayAuthEventStorage,
    event_json_output: []u8,
    auth_message_output: []u8,
    secret_key: *const [local_operator.secret_key_bytes]u8,
    created_at: u64,
    relay_url_text: []const u8,
    challenge: []const u8,
) (local_operator.LocalOperatorClientError || noztr.nip01_message.MessageEncodeError)!SignedAuthPayload {
    fillAuthEventStorage(auth_storage, relay_url_text, challenge);

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
        .event = event,
        .event_json = event_json,
        .auth_message_json = auth_message_json,
    };
}

pub fn fillAuthEventStorage(
    storage: *RelayAuthEventStorage,
    relay_url_text: []const u8,
    challenge: []const u8,
) void {
    std.debug.assert(relay_url_text.len <= relay_auth.relay_url_max_bytes);
    std.debug.assert(challenge.len <= noztr.nip42_auth.challenge_max_bytes);

    storage.* = .{};
    storage.relay_url_len = @intCast(relay_url_text.len);
    storage.challenge_len = @intCast(challenge.len);
    @memcpy(storage.relay_url[0..relay_url_text.len], relay_url_text);
    @memcpy(storage.challenge[0..challenge.len], challenge);
    storage.relay_items = .{ "relay", storage.relayUrl() };
    storage.challenge_items = .{ "challenge", storage.challengeText() };
    storage.tags[0] = .{ .items = storage.relay_items[0..] };
    storage.tags[1] = .{ .items = storage.challenge_items[0..] };
}

fn requireCurrentAuthTarget(
    current: runtime.RelayPoolAuthEntry,
    descriptor: runtime.RelayDescriptor,
    challenge: []const u8,
) error{ StaleAuthStep, RelayNotReady }!RelayAuthTarget {
    if (!std.mem.eql(u8, current.descriptor.relay_url, descriptor.relay_url)) {
        return error.StaleAuthStep;
    }
    if (current.action != .authenticate) return error.RelayNotReady;
    if (!std.mem.eql(u8, current.challenge, challenge)) return error.StaleAuthStep;

    return .{
        .relay = current.descriptor,
        .challenge = current.challenge,
    };
}

fn serializeAuthClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) noztr.nip01_message.MessageEncodeError![]const u8 {
    const message = noztr.nip01_message.ClientMessage{ .auth = .{ .event = event.* } };
    return noztr.nip01_message.client_message_serialize_json(output, &message);
}

test "relay auth support builds one signed auth payload with relay and challenge tags" {
    var local = local_operator.LocalOperatorClient.init(.{});
    var auth_storage = RelayAuthEventStorage{};
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const secret_key = [_]u8{9} ** local_operator.secret_key_bytes;

    const payload = try buildSignedAuthPayload(
        &local,
        &auth_storage,
        event_json_output[0..],
        auth_message_output[0..],
        &secret_key,
        1_732_000_000,
        "wss://relay.one",
        "challenge-1",
    );

    try std.testing.expectEqualStrings("wss://relay.one", auth_storage.relayUrl());
    try std.testing.expectEqualStrings("challenge-1", auth_storage.challengeText());
    try std.testing.expect(std.mem.startsWith(u8, payload.auth_message_json, "[\"AUTH\","));
}
