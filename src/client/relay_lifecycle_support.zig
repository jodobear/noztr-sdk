const std = @import("std");
const runtime = @import("../runtime/mod.zig");

pub fn addRelay(
    self: anytype,
    comptime field_name: []const u8,
    relay_url_text: []const u8,
) @TypeOf(@field(self, field_name).addRelay(relay_url_text)) {
    return @field(self, field_name).addRelay(relay_url_text);
}

pub fn markRelayConnected(
    self: anytype,
    comptime field_name: []const u8,
    relay_index: u8,
) @TypeOf(@field(self, field_name).markRelayConnected(relay_index)) {
    return @field(self, field_name).markRelayConnected(relay_index);
}

pub fn noteRelayDisconnected(
    self: anytype,
    comptime field_name: []const u8,
    relay_index: u8,
) @TypeOf(@field(self, field_name).noteRelayDisconnected(relay_index)) {
    return @field(self, field_name).noteRelayDisconnected(relay_index);
}

pub fn noteRelayAuthChallenge(
    self: anytype,
    comptime field_name: []const u8,
    relay_index: u8,
    challenge: []const u8,
) @TypeOf(@field(self, field_name).noteRelayAuthChallenge(relay_index, challenge)) {
    return @field(self, field_name).noteRelayAuthChallenge(relay_index, challenge);
}

pub fn inspectRelayRuntime(
    self: anytype,
    comptime field_name: []const u8,
    storage: *runtime.RelayPoolPlanStorage,
) runtime.RelayPoolPlan {
    const target = @field(self, field_name);
    const Target = @TypeOf(target);
    if (@hasDecl(Target, "inspectRelayRuntime")) {
        return target.inspectRelayRuntime(storage);
    }
    if (@hasDecl(Target, "inspectRuntime")) {
        return target.inspectRuntime(storage);
    }
    @compileError("relay lifecycle target must expose inspectRelayRuntime or inspectRuntime");
}

test "relay lifecycle helpers delegate to the named field" {
    const TestError = error{TestFailure};

    const FakeDelegate = struct {
        add_calls: usize = 0,
        connect_calls: usize = 0,
        disconnect_calls: usize = 0,
        challenge_calls: usize = 0,
        last_index: u8 = 0,
        last_url: []const u8 = "",
        last_challenge: []const u8 = "",

        pub fn addRelay(
            self: *@This(),
            relay_url_text: []const u8,
        ) TestError!runtime.RelayDescriptor {
            self.add_calls += 1;
            self.last_url = relay_url_text;
            return .{ .relay_index = 7, .relay_url = relay_url_text };
        }

        pub fn markRelayConnected(self: *@This(), relay_index: u8) TestError!void {
            self.connect_calls += 1;
            self.last_index = relay_index;
        }

        pub fn noteRelayDisconnected(self: *@This(), relay_index: u8) TestError!void {
            self.disconnect_calls += 1;
            self.last_index = relay_index;
        }

        pub fn noteRelayAuthChallenge(
            self: *@This(),
            relay_index: u8,
            challenge: []const u8,
        ) TestError!void {
            self.challenge_calls += 1;
            self.last_index = relay_index;
            self.last_challenge = challenge;
        }

        pub fn inspectRelayRuntime(
            self: *const @This(),
            storage: *runtime.RelayPoolPlanStorage,
        ) runtime.RelayPoolPlan {
            _ = self;
            return .{
                .entries = storage.entries[0..0],
                .relay_count = 0,
            };
        }
    };

    const FakeClient = struct {
        delegate: FakeDelegate = .{},
    };

    var client = FakeClient{};
    const added = try addRelay(&client, "delegate", "wss://relay.one");
    try markRelayConnected(&client, "delegate", 3);
    try noteRelayDisconnected(&client, "delegate", 4);
    try noteRelayAuthChallenge(&client, "delegate", 5, "challenge-1");

    var storage = runtime.RelayPoolPlanStorage{};
    const plan = inspectRelayRuntime(&client, "delegate", &storage);

    try std.testing.expectEqual(@as(usize, 1), client.delegate.add_calls);
    try std.testing.expectEqual(@as(usize, 1), client.delegate.connect_calls);
    try std.testing.expectEqual(@as(usize, 1), client.delegate.disconnect_calls);
    try std.testing.expectEqual(@as(usize, 1), client.delegate.challenge_calls);
    try std.testing.expectEqual(@as(u8, 7), added.relay_index);
    try std.testing.expectEqualStrings("wss://relay.one", client.delegate.last_url);
    try std.testing.expectEqualStrings("challenge-1", client.delegate.last_challenge);
    try std.testing.expectEqual(@as(u8, 0), plan.relay_count);
}
