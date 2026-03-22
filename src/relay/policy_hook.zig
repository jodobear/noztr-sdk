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

pub const RelayPolicyHookAdapter = struct {
    hook: RelayPolicyHook,

    pub fn init(hook: RelayPolicyHook) RelayPolicyHookAdapter {
        return .{ .hook = hook };
    }

    pub fn evaluateSessionAttached(
        self: RelayPolicyHookAdapter,
        session: *const server_session.RelayServerSession,
    ) RelayPolicyHookError!RelayPolicyHookDecision {
        const hook_context = RelayPolicyHookContext{
            .session_state = session.inspectState(),
            .event = .session_attached,
        };
        return self.hook.evaluate(&hook_context);
    }

    pub fn evaluateIntake(
        self: RelayPolicyHookAdapter,
        session: *const server_session.RelayServerSession,
        intake: server_session.RelayServerSessionIntake,
    ) RelayPolicyHookError!RelayPolicyHookDecision {
        const hook_context = RelayPolicyHookContext{
            .session_state = session.inspectState(),
            .event = .{ .intake = intake },
        };
        return self.hook.evaluate(&hook_context);
    }

    pub fn evaluateCloseRequested(
        self: RelayPolicyHookAdapter,
        session: *const server_session.RelayServerSession,
        frame: internal_runtime.RelayServerIoCloseFrame,
    ) RelayPolicyHookError!RelayPolicyHookDecision {
        const hook_context = RelayPolicyHookContext{
            .session_state = session.inspectState(),
            .event = .{ .close_requested = frame },
        };
        return self.hook.evaluate(&hook_context);
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

test "relay policy hook adapter builds bounded session contexts for attach intake and close events" {
    const FakeConnection = struct {
        state: server_session.RelayServerSessionState = .open,

        fn readNext(_: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            return .idle;
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(_: *anyopaque, _: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {}

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return switch (self.state) {
                .open => .open,
                .peer_closing => .closing,
                .closed => .closed,
            };
        }
    };

    const FakeHook = struct {
        seen_states: [3]server_session.RelayServerSessionState = undefined,
        seen_events: [3]RelayPolicyHookEvent = undefined,
        seen_count: usize = 0,

        fn evaluate(
            ctx: *anyopaque,
            hook_context: *const RelayPolicyHookContext,
        ) RelayPolicyHookError!RelayPolicyHookDecision {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.seen_states[self.seen_count] = hook_context.session_state;
            self.seen_events[self.seen_count] = hook_context.event;
            self.seen_count += 1;
            return switch (hook_context.event) {
                .session_attached => .allow,
                .intake => |intake| switch (intake) {
                    .text => .{ .reject = .{ .code = 4004, .reason = "blocked" } },
                    .peer_disconnect => .@"defer",
                    .idle,
                    .peer_close,
                    => .allow,
                },
                .close_requested => .@"defer",
            };
        }
    };

    var fake_connection = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake_connection,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };
    var session = try server_session.RelayServerSession.attach(connection);

    var fake_hook = FakeHook{};
    const hook = RelayPolicyHook{
        .ctx = &fake_hook,
        .evaluate_fn = FakeHook.evaluate,
    };
    const adapter = RelayPolicyHookAdapter.init(hook);

    const attached = try adapter.evaluateSessionAttached(&session);
    try std.testing.expectEqual(RelayPolicyHookDecision.allow, attached);

    const intake = try adapter.evaluateIntake(&session, .{ .text = "[\"REQ\"]" });
    try std.testing.expectEqual(@as(u16, 4004), intake.reject.code);
    try std.testing.expect(intake.isTerminal());

    session.state = .peer_closing;
    const close_requested = try adapter.evaluateCloseRequested(
        &session,
        .{ .code = 1000, .reason = "shutdown" },
    );
    try std.testing.expectEqual(RelayPolicyHookDecision.@"defer", close_requested);
    try std.testing.expectEqual(@as(usize, 3), fake_hook.seen_count);
    try std.testing.expectEqual(server_session.RelayServerSessionState.open, fake_hook.seen_states[0]);
    try std.testing.expectEqual(server_session.RelayServerSessionState.open, fake_hook.seen_states[1]);
    try std.testing.expectEqual(server_session.RelayServerSessionState.peer_closing, fake_hook.seen_states[2]);
}

test "relay policy hook adapter preserves explicit defer and reject outcomes for hostile inputs" {
    const FakeConnection = struct {
        state: server_session.RelayServerSessionState = .open,

        fn readNext(_: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            return .idle;
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(_: *anyopaque, _: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {}

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return switch (self.state) {
                .open => .open,
                .peer_closing => .closing,
                .closed => .closed,
            };
        }
    };

    const FakeHook = struct {
        fn evaluate(
            _: *anyopaque,
            hook_context: *const RelayPolicyHookContext,
        ) RelayPolicyHookError!RelayPolicyHookDecision {
            return switch (hook_context.event) {
                .intake => |intake| switch (intake) {
                    .peer_disconnect => .@"defer",
                    .peer_close => |frame| .{ .reject = frame },
                    .idle,
                    .text,
                    => .allow,
                },
                .session_attached,
                .close_requested,
                => .allow,
            };
        }
    };

    var fake_connection = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake_connection,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };
    const session = try server_session.RelayServerSession.attach(connection);

    var fake_hook: u8 = 0;
    const adapter = RelayPolicyHookAdapter.init(.{
        .ctx = &fake_hook,
        .evaluate_fn = FakeHook.evaluate,
    });

    const deferred = try adapter.evaluateIntake(&session, .peer_disconnect);
    try std.testing.expectEqual(RelayPolicyHookDecision.@"defer", deferred);

    const rejected = try adapter.evaluateIntake(&session, .{
        .peer_close = .{ .code = 4008, .reason = "rate limited" },
    });
    try std.testing.expectEqual(@as(u16, 4008), rejected.reject.code);
    try std.testing.expectEqualStrings("rate limited", rejected.reject.reason);
}
