const std = @import("std");

pub const RelayIoError = error{
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
    ctx: *anyopaque,
    connect_fn: *const fn (ctx: *anyopaque, request: RelayIoConnectRequest) RelayIoError!void,
    send_text_fn: *const fn (ctx: *anyopaque, text: []const u8) RelayIoError!void,
    next_fn: *const fn (ctx: *anyopaque, buffer: []u8) RelayIoError!RelayIoInboundMessage,
    close_fn: *const fn (ctx: *anyopaque, frame: RelayIoCloseFrame) RelayIoError!void,
    inspect_state_fn: *const fn (ctx: *anyopaque) RelayIoConnectionState,

    pub fn connect(self: RelayIoConnection, request: RelayIoConnectRequest) RelayIoError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        std.debug.assert(request.relay_url.len > 0);
        return self.connect_fn(self.ctx, request);
    }

    pub fn sendText(self: RelayIoConnection, text: []const u8) RelayIoError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        std.debug.assert(text.len > 0);
        return self.send_text_fn(self.ctx, text);
    }

    pub fn next(self: RelayIoConnection, buffer: []u8) RelayIoError!RelayIoInboundMessage {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.next_fn(self.ctx, buffer);
    }

    pub fn close(self: RelayIoConnection, frame: RelayIoCloseFrame) RelayIoError!void {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.close_fn(self.ctx, frame);
    }

    pub fn inspectState(self: RelayIoConnection) RelayIoConnectionState {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        return self.inspect_state_fn(self.ctx);
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
    try std.testing.expectEqual(.open, connection.inspectState());

    try connection.sendText("[\"REQ\",\"one\"]");
    try std.testing.expectEqualStrings("[\"REQ\",\"one\"]", fake.last_text);

    const inbound = try connection.next(buffer[0..]);
    try std.testing.expectEqualStrings("[]", inbound.text);

    try connection.close(.{ .code = 4000, .reason = "done" });
    try std.testing.expectEqual(@as(u16, 4000), fake.last_close.code);
    try std.testing.expectEqualStrings("done", fake.last_close.reason);
    try std.testing.expectEqual(.closed, connection.inspectState());
}
