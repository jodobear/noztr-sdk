const std = @import("std");
const runtime = @import("../runtime/mod.zig");

pub fn noteCurrentRelayAuthChallenge(
    signer: anytype,
    auth_state: anytype,
    challenge: []const u8,
) !void {
    try signer.noteCurrentRelayAuthChallenge(challenge);
    auth_state.remember(signer.currentRelayUrl(), challenge);
}

pub fn inspectRelayRuntime(
    signer: anytype,
    storage: anytype,
) runtime.RelayPoolPlan {
    return signer.inspectRelayRuntime(storage);
}

pub fn selectRelayRuntimeStep(
    signer: anytype,
    auth_state: anytype,
    step: *const runtime.RelayPoolStep,
) ![]const u8 {
    const relay_url = try signer.selectRelayRuntimeStep(step);
    auth_state.clear();
    return relay_url;
}

pub fn advanceRelay(
    signer: anytype,
    auth_state: anytype,
) ![]const u8 {
    const relay_url = try signer.advanceRelay();
    auth_state.clear();
    return relay_url;
}

test "signer runtime support remembers challenges and clears auth state on runtime step changes" {
    const FakeAuthState = struct {
        cleared: bool = false,
        relay_url: []const u8 = "",
        challenge: []const u8 = "",

        fn remember(self: *@This(), relay_url: []const u8, challenge: []const u8) void {
            self.relay_url = relay_url;
            self.challenge = challenge;
        }

        fn clear(self: *@This()) void {
            self.cleared = true;
        }
    };

    const FakeSigner = struct {
        relay_url: []const u8 = "wss://relay.one",
        plan: runtime.RelayPoolPlan = .{},

        fn currentRelayUrl(self: *@This()) []const u8 {
            return self.relay_url;
        }

        fn noteCurrentRelayAuthChallenge(self: *@This(), challenge: []const u8) !void {
            _ = self;
            _ = challenge;
        }

        fn inspectRelayRuntime(
            self: *@This(),
            storage: *runtime.RelayPoolPlanStorage,
        ) runtime.RelayPoolPlan {
            _ = storage;
            return self.plan;
        }

        fn selectRelayRuntimeStep(
            self: *@This(),
            step: *const runtime.RelayPoolStep,
        ) ![]const u8 {
            _ = step;
            return self.relay_url;
        }

        fn advanceRelay(self: *@This()) ![]const u8 {
            return self.relay_url;
        }
    };

    var signer = FakeSigner{};
    var auth_state = FakeAuthState{};
    var plan_storage = runtime.RelayPoolPlanStorage{};
    var step: runtime.RelayPoolStep = undefined;

    try noteCurrentRelayAuthChallenge(&signer, &auth_state, "challenge-1");
    try std.testing.expectEqualStrings("wss://relay.one", auth_state.relay_url);
    try std.testing.expectEqualStrings("challenge-1", auth_state.challenge);

    _ = inspectRelayRuntime(&signer, &plan_storage);

    _ = try selectRelayRuntimeStep(&signer, &auth_state, &step);
    try std.testing.expect(auth_state.cleared);

    auth_state.cleared = false;
    _ = try advanceRelay(&signer, &auth_state);
    try std.testing.expect(auth_state.cleared);
}
