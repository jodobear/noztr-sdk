const std = @import("std");
const internal_runtime = @import("../internal/runtime/mod.zig");
const server_session = @import("server_session.zig");

pub const RelayPolicyHookError = error{
    InvalidClient,
};

pub const RelayPolicyHookEvent = union(enum) {
    session_attached,
    intake: server_session.RelayServerSessionIntake,
    close_requested: internal_runtime.RelayServerIoCloseFrame,
};

pub const RelayPolicyHookContext = struct {
    session_state: server_session.RelayServerSessionState,
    event: RelayPolicyHookEvent,
};

pub const RelayPolicyHookDecision = union(enum) {
    allow,
    reject: internal_runtime.RelayServerIoCloseFrame,
    @"defer",

    pub fn isTerminal(self: RelayPolicyHookDecision) bool {
        return switch (self) {
            .allow => false,
            .reject => true,
            .@"defer" => false,
        };
    }
};

pub const RelayPolicyHook = struct {
    ctx: ?*anyopaque,
    evaluate_fn: *const fn (
        ctx: *anyopaque,
        hook_context: *const RelayPolicyHookContext,
    ) RelayPolicyHookError!RelayPolicyHookDecision,

    pub fn evaluate(
        self: RelayPolicyHook,
        hook_context: *const RelayPolicyHookContext,
    ) RelayPolicyHookError!RelayPolicyHookDecision {
        if (self.ctx == null) return error.InvalidClient;
        return self.evaluate_fn(self.ctx.?, hook_context);
    }
};

test "relay policy hook keeps bounded session evidence and allow reject defer decisions explicit" {
    const FakeHook = struct {
        last_context: ?RelayPolicyHookContext = null,

        fn evaluate(
            ctx: *anyopaque,
            hook_context: *const RelayPolicyHookContext,
        ) RelayPolicyHookError!RelayPolicyHookDecision {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_context = hook_context.*;
            return switch (hook_context.event) {
                .session_attached => .allow,
                .intake => |intake| switch (intake) {
                    .text => .{
                        .reject = .{ .code = 4003, .reason = "text disabled" },
                    },
                    .peer_disconnect => .@"defer",
                    .idle,
                    .peer_close,
                    => .allow,
                },
                .close_requested => .@"defer",
            };
        }
    };

    var fake = FakeHook{};
    const hook = RelayPolicyHook{
        .ctx = &fake,
        .evaluate_fn = FakeHook.evaluate,
    };

    const attached_context = RelayPolicyHookContext{
        .session_state = .open,
        .event = .session_attached,
    };
    const attached_decision = try hook.evaluate(&attached_context);
    try std.testing.expectEqual(RelayPolicyHookDecision.allow, attached_decision);
    try std.testing.expectEqual(server_session.RelayServerSessionState.open, fake.last_context.?.session_state);

    const intake_context = RelayPolicyHookContext{
        .session_state = .open,
        .event = .{
            .intake = .{ .text = "[\"EVENT\"]" },
        },
    };
    const intake_decision = try hook.evaluate(&intake_context);
    try std.testing.expectEqual(@as(u16, 4003), intake_decision.reject.code);
    try std.testing.expect(intake_decision.isTerminal());

    const disconnect_context = RelayPolicyHookContext{
        .session_state = .closed,
        .event = .{
            .intake = .peer_disconnect,
        },
    };
    const disconnect_decision = try hook.evaluate(&disconnect_context);
    try std.testing.expectEqual(RelayPolicyHookDecision.@"defer", disconnect_decision);
    try std.testing.expect(!disconnect_decision.isTerminal());
}

test "relay policy hook rejects invalid caller inputs with typed errors" {
    const FakeHook = struct {
        fn evaluate(
            _: *anyopaque,
            _: *const RelayPolicyHookContext,
        ) RelayPolicyHookError!RelayPolicyHookDecision {
            return .allow;
        }
    };

    const invalid_hook = RelayPolicyHook{
        .ctx = null,
        .evaluate_fn = FakeHook.evaluate,
    };
    const hook_context = RelayPolicyHookContext{
        .session_state = .open,
        .event = .session_attached,
    };

    try std.testing.expectError(error.InvalidClient, invalid_hook.evaluate(&hook_context));
}
