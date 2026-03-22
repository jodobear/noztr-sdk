const std = @import("std");

pub const RelayIoError = error{
    InvalidClient,
    InvalidRequest,
    InvalidMessage,
    TransportUnavailable,
    InvalidRelayUrl,
    ConnectFailed,
    HandshakeFailed,
    ConnectionClosed,
    MessageTooLarge,
    ReadFailed,
    WriteFailed,
};

pub const RelayIoConnectionState = enum {
    idle,
    connecting,
    open,
    closing,
    closed,
};

pub const RelayIoConnectRequest = struct {
    relay_url: []const u8,
};

pub const RelayIoCloseFrame = struct {
    code: u16 = 1000,
    reason: []const u8 = "",
};

pub const RelayIoInboundMessage = union(enum) {
    idle,
    text: []const u8,
    close: RelayIoCloseFrame,
};

pub const RelayIoConnection = struct {
    ctx: ?*anyopaque,
    connect_fn: *const fn (ctx: *anyopaque, request: RelayIoConnectRequest) RelayIoError!void,
    send_text_fn: *const fn (ctx: *anyopaque, text: []const u8) RelayIoError!void,
    next_fn: *const fn (ctx: *anyopaque, buffer: []u8) RelayIoError!RelayIoInboundMessage,
    close_fn: *const fn (ctx: *anyopaque, frame: RelayIoCloseFrame) RelayIoError!void,
    inspect_state_fn: *const fn (ctx: *anyopaque) RelayIoConnectionState,

    pub fn connect(self: RelayIoConnection, request: RelayIoConnectRequest) RelayIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        if (request.relay_url.len == 0) return error.InvalidRequest;
        return self.connect_fn(self.ctx.?, request);
    }

    pub fn sendText(self: RelayIoConnection, text: []const u8) RelayIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        if (text.len == 0) return error.InvalidMessage;
        return self.send_text_fn(self.ctx.?, text);
    }

    pub fn next(self: RelayIoConnection, buffer: []u8) RelayIoError!RelayIoInboundMessage {
        if (self.ctx == null) return error.InvalidClient;
        return self.next_fn(self.ctx.?, buffer);
    }

    pub fn close(self: RelayIoConnection, frame: RelayIoCloseFrame) RelayIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        return self.close_fn(self.ctx.?, frame);
    }

    pub fn inspectState(self: RelayIoConnection) RelayIoError!RelayIoConnectionState {
        if (self.ctx == null) return error.InvalidClient;
        return self.inspect_state_fn(self.ctx.?);
    }
};

test "relay io connection forwards connect send next close and state inspection" {
    const FakeConnection = struct {
        state: RelayIoConnectionState = .idle,
        last_url: []const u8 = "",
        last_text: []const u8 = "",
        last_close: RelayIoCloseFrame = .{},

        fn connect(ctx: *anyopaque, request: RelayIoConnectRequest) RelayIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .open;
            self.last_url = request.relay_url;
        }

        fn sendText(ctx: *anyopaque, text: []const u8) RelayIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_text = text;
        }

        fn next(ctx: *anyopaque, buffer: []u8) RelayIoError!RelayIoInboundMessage {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            _ = self;
            const message = "[]";
            @memcpy(buffer[0..message.len], message);
            return .{ .text = buffer[0..message.len] };
        }

        fn close(ctx: *anyopaque, frame: RelayIoCloseFrame) RelayIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .closed;
            self.last_close = frame;
        }

        fn inspectState(ctx: *anyopaque) RelayIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }
    };

    var fake = FakeConnection{};
    const connection = RelayIoConnection{
        .ctx = &fake,
        .connect_fn = FakeConnection.connect,
        .send_text_fn = FakeConnection.sendText,
        .next_fn = FakeConnection.next,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };
    var buffer: [16]u8 = undefined;

    try connection.connect(.{ .relay_url = "wss://relay.one" });
    try std.testing.expectEqualStrings("wss://relay.one", fake.last_url);
    try std.testing.expectEqual(.open, try connection.inspectState());

    try connection.sendText("[\"REQ\",\"one\"]");
    try std.testing.expectEqualStrings("[\"REQ\",\"one\"]", fake.last_text);

    const inbound = try connection.next(buffer[0..]);
    try std.testing.expectEqualStrings("[]", inbound.text);

    try connection.close(.{ .code = 4000, .reason = "done" });
    try std.testing.expectEqual(@as(u16, 4000), fake.last_close.code);
    try std.testing.expectEqualStrings("done", fake.last_close.reason);
    try std.testing.expectEqual(.closed, try connection.inspectState());
}

test "relay io connection rejects invalid caller inputs with typed errors" {
    const FakeConnection = struct {
        fn connect(_: *anyopaque, _: RelayIoConnectRequest) RelayIoError!void {}
        fn sendText(_: *anyopaque, _: []const u8) RelayIoError!void {}
        fn next(_: *anyopaque, _: []u8) RelayIoError!RelayIoInboundMessage {
            return .idle;
        }
        fn close(_: *anyopaque, _: RelayIoCloseFrame) RelayIoError!void {}
        fn inspectState(_: *anyopaque) RelayIoConnectionState {
            return .idle;
        }
    };

    const invalid = RelayIoConnection{
        .ctx = null,
        .connect_fn = FakeConnection.connect,
        .send_text_fn = FakeConnection.sendText,
        .next_fn = FakeConnection.next,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };
    var buffer: [8]u8 = undefined;

    try std.testing.expectError(error.InvalidClient, invalid.connect(.{ .relay_url = "wss://relay.one" }));
    try std.testing.expectError(error.InvalidClient, invalid.sendText("[\"REQ\"]"));
    try std.testing.expectError(error.InvalidClient, invalid.next(buffer[0..]));
    try std.testing.expectError(error.InvalidClient, invalid.close(.{}));
    try std.testing.expectError(error.InvalidClient, invalid.inspectState());

    var fake_ctx: u8 = 0;
    const connection = RelayIoConnection{
        .ctx = &fake_ctx,
        .connect_fn = FakeConnection.connect,
        .send_text_fn = FakeConnection.sendText,
        .next_fn = FakeConnection.next,
        .close_fn = FakeConnection.close,
        .inspect_state_fn = FakeConnection.inspectState,
    };

    try std.testing.expectError(error.InvalidRequest, connection.connect(.{ .relay_url = "" }));
    try std.testing.expectError(error.InvalidMessage, connection.sendText(""));
}
