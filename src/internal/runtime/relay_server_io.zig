const std = @import("std");

pub const RelayServerIoError = error{
    InvalidClient,
    InvalidRequest,
    InvalidMessage,
    TransportUnavailable,
    ListenerUnavailable,
    AcceptFailed,
    ConnectionClosed,
    MessageTooLarge,
    ReadFailed,
    WriteFailed,
    CloseFailed,
};

pub const RelayServerIoListenerState = enum {
    idle,
    listening,
    closing,
    closed,
};

pub const RelayServerIoConnectionState = enum {
    open,
    closing,
    closed,
};

pub const RelayServerIoListenRequest = struct {
    endpoint: []const u8,
};

pub const RelayServerIoCloseFrame = struct {
    code: u16 = 1000,
    reason: []const u8 = "",
};

pub const RelayServerIoInboundMessage = union(enum) {
    idle,
    text: []const u8,
    close: RelayServerIoCloseFrame,
};

pub const RelayServerIoConnection = struct {
    ctx: ?*anyopaque,
    read_next_fn: *const fn (ctx: *anyopaque, buffer: []u8) RelayServerIoError!RelayServerIoInboundMessage,
    write_text_fn: *const fn (ctx: *anyopaque, text: []const u8) RelayServerIoError!void,
    close_fn: *const fn (ctx: *anyopaque, frame: RelayServerIoCloseFrame) RelayServerIoError!void,
    inspect_state_fn: *const fn (ctx: *anyopaque) RelayServerIoConnectionState,

    pub fn readNext(self: RelayServerIoConnection, buffer: []u8) RelayServerIoError!RelayServerIoInboundMessage {
        if (self.ctx == null) return error.InvalidClient;
        return self.read_next_fn(self.ctx.?, buffer);
    }

    pub fn writeText(self: RelayServerIoConnection, text: []const u8) RelayServerIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        if (text.len == 0) return error.InvalidMessage;
        return self.write_text_fn(self.ctx.?, text);
    }

    pub fn close(self: RelayServerIoConnection, frame: RelayServerIoCloseFrame) RelayServerIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        return self.close_fn(self.ctx.?, frame);
    }

    pub fn inspectState(self: RelayServerIoConnection) RelayServerIoError!RelayServerIoConnectionState {
        if (self.ctx == null) return error.InvalidClient;
        return self.inspect_state_fn(self.ctx.?);
    }
};

pub const RelayServerIoListener = struct {
    ctx: ?*anyopaque,
    listen_fn: *const fn (ctx: *anyopaque, request: RelayServerIoListenRequest) RelayServerIoError!void,
    accept_fn: *const fn (ctx: *anyopaque) RelayServerIoError!RelayServerIoConnection,
    close_fn: *const fn (ctx: *anyopaque, frame: RelayServerIoCloseFrame) RelayServerIoError!void,
    inspect_state_fn: *const fn (ctx: *anyopaque) RelayServerIoListenerState,

    pub fn listen(self: RelayServerIoListener, request: RelayServerIoListenRequest) RelayServerIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        if (request.endpoint.len == 0) return error.InvalidRequest;
        return self.listen_fn(self.ctx.?, request);
    }

    pub fn accept(self: RelayServerIoListener) RelayServerIoError!RelayServerIoConnection {
        if (self.ctx == null) return error.InvalidClient;
        return self.accept_fn(self.ctx.?);
    }

    pub fn close(self: RelayServerIoListener, frame: RelayServerIoCloseFrame) RelayServerIoError!void {
        if (self.ctx == null) return error.InvalidClient;
        return self.close_fn(self.ctx.?, frame);
    }

    pub fn inspectState(self: RelayServerIoListener) RelayServerIoError!RelayServerIoListenerState {
        if (self.ctx == null) return error.InvalidClient;
        return self.inspect_state_fn(self.ctx.?);
    }
};

pub const RelayServerIoDriver = struct {
    ctx: ?*anyopaque,
    start_listener_fn: *const fn (ctx: *anyopaque, request: RelayServerIoListenRequest) RelayServerIoError!RelayServerIoListener,

    pub fn startListener(self: RelayServerIoDriver, request: RelayServerIoListenRequest) RelayServerIoError!RelayServerIoListener {
        if (self.ctx == null) return error.InvalidClient;
        if (request.endpoint.len == 0) return error.InvalidRequest;
        return self.start_listener_fn(self.ctx.?, request);
    }
};

test "relay server io listener forwards listen accept close and connection operations" {
    const FakeServer = struct {
        listener_state: RelayServerIoListenerState = .idle,
        connection_state: RelayServerIoConnectionState = .closed,
        last_endpoint: []const u8 = "",
        last_written_text: []const u8 = "",
        last_close: RelayServerIoCloseFrame = .{},

        fn listen(ctx: *anyopaque, request: RelayServerIoListenRequest) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_endpoint = request.endpoint;
            self.listener_state = .listening;
        }

        fn accept(ctx: *anyopaque) RelayServerIoError!RelayServerIoConnection {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.connection_state = .open;
            return .{
                .ctx = self,
                .read_next_fn = readNext,
                .write_text_fn = writeText,
                .close_fn = closeConnection,
                .inspect_state_fn = inspectConnectionState,
            };
        }

        fn closeListener(ctx: *anyopaque, frame: RelayServerIoCloseFrame) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.listener_state = .closed;
            self.last_close = frame;
        }

        fn inspectListenerState(ctx: *anyopaque) RelayServerIoListenerState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.listener_state;
        }

        fn readNext(ctx: *anyopaque, buffer: []u8) RelayServerIoError!RelayServerIoInboundMessage {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            _ = self;
            const message = "[\"EVENT\"]";
            @memcpy(buffer[0..message.len], message);
            return .{ .text = buffer[0..message.len] };
        }

        fn writeText(ctx: *anyopaque, text: []const u8) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_written_text = text;
        }

        fn closeConnection(ctx: *anyopaque, frame: RelayServerIoCloseFrame) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.connection_state = .closed;
            self.last_close = frame;
        }

        fn inspectConnectionState(ctx: *anyopaque) RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.connection_state;
        }
    };

    var fake = FakeServer{};
    const listener = RelayServerIoListener{
        .ctx = &fake,
        .listen_fn = FakeServer.listen,
        .accept_fn = FakeServer.accept,
        .close_fn = FakeServer.closeListener,
        .inspect_state_fn = FakeServer.inspectListenerState,
    };
    var buffer: [32]u8 = undefined;

    try listener.listen(.{ .endpoint = "ws://127.0.0.1:7447" });
    try std.testing.expectEqualStrings("ws://127.0.0.1:7447", fake.last_endpoint);
    try std.testing.expectEqual(.listening, try listener.inspectState());

    const connection = try listener.accept();
    try std.testing.expectEqual(.open, try connection.inspectState());

    const inbound = try connection.readNext(buffer[0..]);
    try std.testing.expectEqualStrings("[\"EVENT\"]", inbound.text);

    try connection.writeText("[\"OK\"]");
    try std.testing.expectEqualStrings("[\"OK\"]", fake.last_written_text);

    try connection.close(.{ .code = 4100, .reason = "done" });
    try std.testing.expectEqual(@as(u16, 4100), fake.last_close.code);
    try std.testing.expectEqualStrings("done", fake.last_close.reason);
    try std.testing.expectEqual(.closed, try connection.inspectState());

    try listener.close(.{ .code = 1001, .reason = "shutdown" });
    try std.testing.expectEqual(@as(u16, 1001), fake.last_close.code);
    try std.testing.expectEqualStrings("shutdown", fake.last_close.reason);
    try std.testing.expectEqual(.closed, try listener.inspectState());
}

test "relay server io surfaces reject invalid caller inputs with typed errors" {
    const FakeServer = struct {
        fn listen(_: *anyopaque, _: RelayServerIoListenRequest) RelayServerIoError!void {}

        fn accept(_: *anyopaque) RelayServerIoError!RelayServerIoConnection {
            return .{
                .ctx = null,
                .read_next_fn = readNext,
                .write_text_fn = writeText,
                .close_fn = closeConnection,
                .inspect_state_fn = inspectConnectionState,
            };
        }

        fn closeListener(_: *anyopaque, _: RelayServerIoCloseFrame) RelayServerIoError!void {}

        fn inspectListenerState(_: *anyopaque) RelayServerIoListenerState {
            return .idle;
        }

        fn readNext(_: *anyopaque, _: []u8) RelayServerIoError!RelayServerIoInboundMessage {
            return .idle;
        }

        fn writeText(_: *anyopaque, _: []const u8) RelayServerIoError!void {}

        fn closeConnection(_: *anyopaque, _: RelayServerIoCloseFrame) RelayServerIoError!void {}

        fn inspectConnectionState(_: *anyopaque) RelayServerIoConnectionState {
            return .closed;
        }
    };

    const invalid_listener = RelayServerIoListener{
        .ctx = null,
        .listen_fn = FakeServer.listen,
        .accept_fn = FakeServer.accept,
        .close_fn = FakeServer.closeListener,
        .inspect_state_fn = FakeServer.inspectListenerState,
    };
    var buffer: [8]u8 = undefined;

    try std.testing.expectError(error.InvalidClient, invalid_listener.listen(.{ .endpoint = "ws://127.0.0.1:7447" }));
    try std.testing.expectError(error.InvalidClient, invalid_listener.accept());
    try std.testing.expectError(error.InvalidClient, invalid_listener.close(.{}));
    try std.testing.expectError(error.InvalidClient, invalid_listener.inspectState());

    var fake_ctx: u8 = 0;
    const listener = RelayServerIoListener{
        .ctx = &fake_ctx,
        .listen_fn = FakeServer.listen,
        .accept_fn = FakeServer.accept,
        .close_fn = FakeServer.closeListener,
        .inspect_state_fn = FakeServer.inspectListenerState,
    };
    try std.testing.expectError(error.InvalidRequest, listener.listen(.{ .endpoint = "" }));

    const invalid_connection = RelayServerIoConnection{
        .ctx = null,
        .read_next_fn = FakeServer.readNext,
        .write_text_fn = FakeServer.writeText,
        .close_fn = FakeServer.closeConnection,
        .inspect_state_fn = FakeServer.inspectConnectionState,
    };
    try std.testing.expectError(error.InvalidClient, invalid_connection.readNext(buffer[0..]));
    try std.testing.expectError(error.InvalidClient, invalid_connection.writeText("[\"OK\"]"));
    try std.testing.expectError(error.InvalidClient, invalid_connection.close(.{}));
    try std.testing.expectError(error.InvalidClient, invalid_connection.inspectState());

    const accepted = try listener.accept();
    try std.testing.expectError(error.InvalidClient, accepted.readNext(buffer[0..]));

    const valid_connection = RelayServerIoConnection{
        .ctx = &fake_ctx,
        .read_next_fn = FakeServer.readNext,
        .write_text_fn = FakeServer.writeText,
        .close_fn = FakeServer.closeConnection,
        .inspect_state_fn = FakeServer.inspectConnectionState,
    };
    try std.testing.expectError(error.InvalidMessage, valid_connection.writeText(""));
}

test "relay server io driver starts one listener and forwards listener lifecycle" {
    const FakeServer = struct {
        listener_state: RelayServerIoListenerState = .idle,
        last_endpoint: []const u8 = "",

        fn startListener(ctx: *anyopaque, request: RelayServerIoListenRequest) RelayServerIoError!RelayServerIoListener {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_endpoint = request.endpoint;
            self.listener_state = .listening;
            return .{
                .ctx = self,
                .listen_fn = listen,
                .accept_fn = accept,
                .close_fn = closeListener,
                .inspect_state_fn = inspectListenerState,
            };
        }

        fn listen(ctx: *anyopaque, request: RelayServerIoListenRequest) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_endpoint = request.endpoint;
            self.listener_state = .listening;
        }

        fn accept(_: *anyopaque) RelayServerIoError!RelayServerIoConnection {
            return error.AcceptFailed;
        }

        fn closeListener(ctx: *anyopaque, _: RelayServerIoCloseFrame) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.listener_state = .closed;
        }

        fn inspectListenerState(ctx: *anyopaque) RelayServerIoListenerState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.listener_state;
        }
    };

    var fake = FakeServer{};
    const driver = RelayServerIoDriver{
        .ctx = &fake,
        .start_listener_fn = FakeServer.startListener,
    };

    const listener = try driver.startListener(.{ .endpoint = "ws://127.0.0.1:7447" });
    try std.testing.expectEqualStrings("ws://127.0.0.1:7447", fake.last_endpoint);
    try std.testing.expectEqual(.listening, try listener.inspectState());

    try listener.close(.{});
    try std.testing.expectEqual(.closed, try listener.inspectState());
}

test "relay server io driver rejects invalid caller inputs with typed errors" {
    const FakeServer = struct {
        fn startListener(_: *anyopaque, _: RelayServerIoListenRequest) RelayServerIoError!RelayServerIoListener {
            return .{
                .ctx = null,
                .listen_fn = listen,
                .accept_fn = accept,
                .close_fn = closeListener,
                .inspect_state_fn = inspectListenerState,
            };
        }

        fn listen(_: *anyopaque, _: RelayServerIoListenRequest) RelayServerIoError!void {}
        fn accept(_: *anyopaque) RelayServerIoError!RelayServerIoConnection {
            return error.AcceptFailed;
        }
        fn closeListener(_: *anyopaque, _: RelayServerIoCloseFrame) RelayServerIoError!void {}
        fn inspectListenerState(_: *anyopaque) RelayServerIoListenerState {
            return .idle;
        }
    };

    const invalid_driver = RelayServerIoDriver{
        .ctx = null,
        .start_listener_fn = FakeServer.startListener,
    };
    try std.testing.expectError(error.InvalidClient, invalid_driver.startListener(.{ .endpoint = "ws://127.0.0.1:7447" }));

    var fake_ctx: u8 = 0;
    const driver = RelayServerIoDriver{
        .ctx = &fake_ctx,
        .start_listener_fn = FakeServer.startListener,
    };
    try std.testing.expectError(error.InvalidRequest, driver.startListener(.{ .endpoint = "" }));
}

test "relay server io propagates closed-connection and bounded-message errors" {
    const FakeServer = struct {
        connection_state: RelayServerIoConnectionState = .open,

        fn startListener(ctx: *anyopaque, _: RelayServerIoListenRequest) RelayServerIoError!RelayServerIoListener {
            return .{
                .ctx = ctx,
                .listen_fn = listen,
                .accept_fn = accept,
                .close_fn = closeListener,
                .inspect_state_fn = inspectListenerState,
            };
        }

        fn listen(_: *anyopaque, _: RelayServerIoListenRequest) RelayServerIoError!void {}

        fn accept(ctx: *anyopaque) RelayServerIoError!RelayServerIoConnection {
            return .{
                .ctx = ctx,
                .read_next_fn = readNext,
                .write_text_fn = writeText,
                .close_fn = closeConnection,
                .inspect_state_fn = inspectConnectionState,
            };
        }

        fn closeListener(_: *anyopaque, _: RelayServerIoCloseFrame) RelayServerIoError!void {}

        fn inspectListenerState(_: *anyopaque) RelayServerIoListenerState {
            return .listening;
        }

        fn readNext(ctx: *anyopaque, buffer: []u8) RelayServerIoError!RelayServerIoInboundMessage {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.connection_state == .closed) return error.ConnectionClosed;
            const message = "[\"EVENT\",\"payload\"]";
            if (buffer.len < message.len) return error.MessageTooLarge;
            @memcpy(buffer[0..message.len], message);
            return .{ .text = buffer[0..message.len] };
        }

        fn writeText(ctx: *anyopaque, _: []const u8) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.connection_state == .closed) return error.ConnectionClosed;
        }

        fn closeConnection(ctx: *anyopaque, _: RelayServerIoCloseFrame) RelayServerIoError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.connection_state = .closed;
        }

        fn inspectConnectionState(ctx: *anyopaque) RelayServerIoConnectionState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.connection_state;
        }
    };

    var fake = FakeServer{};
    const driver = RelayServerIoDriver{
        .ctx = &fake,
        .start_listener_fn = FakeServer.startListener,
    };
    const listener = try driver.startListener(.{ .endpoint = "ws://127.0.0.1:7447" });
    const connection = try listener.accept();

    var small: [8]u8 = undefined;
    try std.testing.expectError(error.MessageTooLarge, connection.readNext(small[0..]));

    try connection.close(.{});
    try std.testing.expectEqual(.closed, try connection.inspectState());
    try std.testing.expectError(error.ConnectionClosed, connection.readNext(small[0..]));
    try std.testing.expectError(error.ConnectionClosed, connection.writeText("[\"OK\"]"));
}
