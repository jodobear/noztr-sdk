const std = @import("std");
const internal_runtime = @import("../internal/runtime/mod.zig");

pub const RelayServerSessionError = internal_runtime.RelayServerIoError || error{
    InvalidSessionState,
};

pub const RelayServerSessionState = enum {
    open,
    peer_closing,
    closed,
};

pub const RelayServerSessionIntake = union(enum) {
    idle,
    text: []const u8,
    peer_close: internal_runtime.RelayServerIoCloseFrame,
    peer_disconnect,
};

pub const RelayServerSessionCloseOutcome = enum {
    local_close,
    acknowledge_peer_close,
};

pub const RelayServerSession = struct {
    connection: internal_runtime.RelayServerIoConnection,
    state: RelayServerSessionState,

    pub fn attach(
        connection: internal_runtime.RelayServerIoConnection,
    ) RelayServerSessionError!RelayServerSession {
        return .{
            .connection = connection,
            .state = switch (try connection.inspectState()) {
                .open => .open,
                .closing => .peer_closing,
                .closed => .closed,
            },
        };
    }

    pub fn inspectState(self: *const RelayServerSession) RelayServerSessionState {
        return self.state;
    }

    pub fn readNext(
        self: *RelayServerSession,
        buffer: []u8,
    ) RelayServerSessionError!RelayServerSessionIntake {
        if (self.state != .open) return error.InvalidSessionState;

        const inbound = self.connection.readNext(buffer) catch |err| switch (err) {
            error.ConnectionClosed => {
                self.state = .closed;
                return .peer_disconnect;
            },
            else => return err,
        };
        return switch (inbound) {
            .idle => .idle,
            .text => |text| .{ .text = text },
            .close => |frame| blk: {
                self.state = .peer_closing;
                break :blk .{ .peer_close = frame };
            },
        };
    }

    pub fn close(
        self: *RelayServerSession,
        frame: internal_runtime.RelayServerIoCloseFrame,
    ) RelayServerSessionError!RelayServerSessionCloseOutcome {
        switch (self.state) {
            .open => {
                self.connection.close(frame) catch |err| switch (err) {
                    error.ConnectionClosed => {},
                    else => return err,
                };
                self.state = .closed;
                return .local_close;
            },
            .peer_closing => {
                self.connection.close(frame) catch |err| switch (err) {
                    error.ConnectionClosed => {},
                    else => return err,
                };
                self.state = .closed;
                return .acknowledge_peer_close;
            },
            .closed => return error.InvalidSessionState,
        }
    }
};

test "relay server session keeps open state for text intake and local close" {
    const FakeConnection = struct {
        state: internal_runtime.RelayServerIoConnectionState = .open,
        last_close: internal_runtime.RelayServerIoCloseFrame = .{},
        next_text: []const u8 = "[\"REQ\"]",

        fn readNext(ctx: *anyopaque, buffer: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            @memcpy(buffer[0..self.next_text.len], self.next_text);
            return .{ .text = buffer[0..self.next_text.len] };
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(ctx: *anyopaque, frame: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_close = frame;
            self.state = .closed;
        }

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var fake = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    var session = try RelayServerSession.attach(connection);
    try std.testing.expectEqual(RelayServerSessionState.open, session.inspectState());

    var buffer: [32]u8 = undefined;
    const intake = try session.readNext(buffer[0..]);
    try std.testing.expectEqualStrings("[\"REQ\"]", intake.text);
    try std.testing.expectEqual(RelayServerSessionState.open, session.inspectState());

    const outcome = try session.close(.{ .code = 1000, .reason = "done" });
    try std.testing.expectEqual(RelayServerSessionCloseOutcome.local_close, outcome);
    try std.testing.expectEqual(RelayServerSessionState.closed, session.inspectState());
    try std.testing.expectEqual(@as(u16, 1000), fake.last_close.code);
}

test "relay server session records peer close and requires explicit acknowledgement" {
    const FakeConnection = struct {
        state: internal_runtime.RelayServerIoConnectionState = .open,
        last_close: internal_runtime.RelayServerIoCloseFrame = .{},

        fn readNext(_: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            return .{ .close = .{ .code = 4000, .reason = "peer done" } };
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(ctx: *anyopaque, frame: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_close = frame;
            self.state = .closed;
        }

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var fake = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    var session = try RelayServerSession.attach(connection);
    var buffer: [8]u8 = undefined;
    const intake = try session.readNext(buffer[0..]);
    try std.testing.expectEqual(@as(u16, 4000), intake.peer_close.code);
    try std.testing.expectEqual(RelayServerSessionState.peer_closing, session.inspectState());

    try std.testing.expectError(error.InvalidSessionState, session.readNext(buffer[0..]));

    const outcome = try session.close(.{ .code = 1000, .reason = "ack" });
    try std.testing.expectEqual(RelayServerSessionCloseOutcome.acknowledge_peer_close, outcome);
    try std.testing.expectEqual(RelayServerSessionState.closed, session.inspectState());
    try std.testing.expectEqualStrings("ack", fake.last_close.reason);
}

test "relay server session treats transport closure during intake as peer disconnect" {
    const FakeConnection = struct {
        state: internal_runtime.RelayServerIoConnectionState = .open,

        fn readNext(ctx: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .closed;
            return error.ConnectionClosed;
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(ctx: *anyopaque, _: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .closed;
            return error.ConnectionClosed;
        }

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var fake = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    var session = try RelayServerSession.attach(connection);
    var buffer: [8]u8 = undefined;
    const intake = try session.readNext(buffer[0..]);
    try std.testing.expectEqual(RelayServerSessionIntake.peer_disconnect, intake);
    try std.testing.expectEqual(RelayServerSessionState.closed, session.inspectState());
    try std.testing.expectError(error.InvalidSessionState, session.readNext(buffer[0..]));
    try std.testing.expectError(error.InvalidSessionState, session.close(.{}));
}

test "relay server session keeps malformed intake as an explicit seam error" {
    const FakeConnection = struct {
        state: internal_runtime.RelayServerIoConnectionState = .open,

        fn readNext(_: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            return error.MessageTooLarge;
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(ctx: *anyopaque, _: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .closed;
        }

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var fake = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    var session = try RelayServerSession.attach(connection);
    var buffer: [4]u8 = undefined;
    try std.testing.expectError(error.MessageTooLarge, session.readNext(buffer[0..]));
    try std.testing.expectEqual(RelayServerSessionState.open, session.inspectState());
}

test "relay server session absorbs repeated close semantics into one bounded closed state" {
    const FakeConnection = struct {
        state: internal_runtime.RelayServerIoConnectionState = .open,
        close_calls: usize = 0,

        fn readNext(_: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            return .idle;
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(ctx: *anyopaque, _: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.close_calls += 1;
            if (self.close_calls > 1) return error.ConnectionClosed;
            self.state = .closed;
        }

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var fake = FakeConnection{};
    const connection = internal_runtime.RelayServerIoConnection{
        .ctx = &fake,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    var session = try RelayServerSession.attach(connection);
    const outcome = try session.close(.{ .code = 1000, .reason = "done" });
    try std.testing.expectEqual(RelayServerSessionCloseOutcome.local_close, outcome);
    try std.testing.expectEqual(RelayServerSessionState.closed, session.inspectState());
    try std.testing.expectEqual(@as(usize, 1), fake.close_calls);
    try std.testing.expectError(error.InvalidSessionState, session.close(.{ .code = 1000, .reason = "again" }));
}

test "relay server session attaches closing and closed connections honestly" {
    const FakeConnection = struct {
        state: internal_runtime.RelayServerIoConnectionState,

        fn readNext(_: *anyopaque, _: []u8) internal_runtime.RelayServerIoError!internal_runtime.RelayServerIoInboundMessage {
            return .idle;
        }

        fn writeText(_: *anyopaque, _: []const u8) internal_runtime.RelayServerIoError!void {}

        fn close(ctx: *anyopaque, _: internal_runtime.RelayServerIoCloseFrame) internal_runtime.RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .closed;
        }

        fn inspectState(ctx: *anyopaque) internal_runtime.RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var closing = FakeConnection{ .state = .closing };
    var closed = FakeConnection{ .state = .closed };
    const closing_connection = internal_runtime.RelayServerIoConnection{
        .ctx = &closing,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };
    const closed_connection = internal_runtime.RelayServerIoConnection{
        .ctx = &closed,
        .read_next_fn = FakeConnection.readNext,
        .write_text_fn = FakeConnection.writeText,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    var closing_session = try RelayServerSession.attach(closing_connection);
    try std.testing.expectEqual(RelayServerSessionState.peer_closing, closing_session.inspectState());

    var closed_session = try RelayServerSession.attach(closed_connection);
    try std.testing.expectEqual(RelayServerSessionState.closed, closed_session.inspectState());

    try std.testing.expectError(error.InvalidSessionState, closed_session.close(.{}));
}
