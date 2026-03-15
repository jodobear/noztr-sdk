const std = @import("std");

/// Stable workflow namespace.
pub const workflows = @import("workflows/mod.zig");

test "root module keeps the public surface minimal until workflows land" {
    try std.testing.expect(!@hasDecl(@This(), "noztr"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(!@hasDecl(@This(), "transport"));
    try std.testing.expect(!@hasDecl(@This(), "relay"));
    try std.testing.expect(!@hasDecl(@This(), "store"));
    try std.testing.expect(@TypeOf(workflows) == type);
    try std.testing.expect(!@hasDecl(@This(), "policy"));
    try std.testing.expect(!@hasDecl(@This(), "sync"));
    try std.testing.expect(!@hasDecl(@This(), "Config"));
    try std.testing.expect(!@hasDecl(@This(), "testing"));
}

test "root smoke uses noztr stable helper" {
    const noztr = @import("noztr");
    const parsed_method = try noztr.nip46_remote_signing.method_parse("connect");
    try std.testing.expectEqual(.connect, parsed_method);
}

test "phase3 relay directory fetches nip11 over explicit seams" {
    const store = @import("store/mod.zig");
    const relay_directory = @import("relay/directory.zig");
    const testing = @import("testing/mod.zig");
    const json =
        \\{"name":"alpha","pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","supported_nips":[11,42]}
    ;
    var fake_http = testing.FakeHttp.init("https://relay.test", json);
    var memory_store = store.MemoryStore{};
    var directory = relay_directory.RelayDirectory.init(memory_store.asRelayInfoStore());
    var url_buffer: [128]u8 = undefined;
    var response_buffer: [256]u8 = undefined;
    var parse_scratch: [4096]u8 = undefined;

    const record = try directory.refresh(
        fake_http.client(),
        "wss://relay.test",
        &url_buffer,
        &response_buffer,
        &parse_scratch,
    );
    try std.testing.expectEqualStrings("wss://relay.test", record.relayUrl());
    try std.testing.expectEqualStrings("alpha", record.nameSlice());
}

test "phase3 session helpers stay internal and explicit" {
    const testing = @import("testing/mod.zig");
    const relay_pool = @import("relay/pool.zig");
    var pool = relay_pool.Pool.init();
    const relay_index = try pool.addRelay("wss://relay.one");
    const relay_session = pool.getRelay(relay_index) orelse unreachable;
    const fake_relay = testing.FakeRelay{
        .relay_url = "wss://relay.one",
        .challenge = "challenge-1",
    };
    try fake_relay.requireAuth(relay_session);
    try std.testing.expect(!relay_session.canSendRequests());
}

test "phase4 exposes the remote signer workflow surface" {
    try std.testing.expect(@TypeOf(workflows.RemoteSignerSession) == type);
}
