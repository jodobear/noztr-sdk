const std = @import("std");

pub const TaskError = error{
    InvalidClient,
    InvalidRequest,
    TaskUnavailable,
    StartFailed,
    StopFailed,
    JoinFailed,
};

pub const TaskState = enum {
    idle,
    running,
    stop_requested,
    completed,
    failed,
    cancelled,
};

pub const TaskExit = union(enum) {
    completed,
    failed: []const u8,
    cancelled,
};

pub const TaskHandle = struct {
    ctx: ?*anyopaque,
    request_stop_fn: *const fn (ctx: *anyopaque) TaskError!void,
    inspect_fn: *const fn (ctx: *anyopaque) TaskState,
    join_fn: *const fn (ctx: *anyopaque) TaskError!TaskExit,

    pub fn requestStop(self: TaskHandle) TaskError!void {
        if (self.ctx == null) return error.InvalidClient;
        return self.request_stop_fn(self.ctx.?);
    }

    pub fn inspect(self: TaskHandle) TaskError!TaskState {
        if (self.ctx == null) return error.InvalidClient;
        return self.inspect_fn(self.ctx.?);
    }

    pub fn join(self: TaskHandle) TaskError!TaskExit {
        if (self.ctx == null) return error.InvalidClient;
        return self.join_fn(self.ctx.?);
    }
};

pub const TaskStartRequest = struct {
    label: []const u8,
};

pub const TaskDriver = struct {
    ctx: ?*anyopaque,
    start_fn: *const fn (ctx: *anyopaque, request: TaskStartRequest) TaskError!TaskHandle,

    pub fn start(self: TaskDriver, request: TaskStartRequest) TaskError!TaskHandle {
        if (self.ctx == null) return error.InvalidClient;
        if (request.label.len == 0) return error.InvalidRequest;
        return self.start_fn(self.ctx.?, request);
    }
};

test "task driver starts one handle that can be inspected stopped and joined" {
    const FakeTask = struct {
        state: TaskState = .idle,
        label: []const u8 = "",

        fn requestStop(ctx: *anyopaque) TaskError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .stop_requested;
        }

        fn inspect(ctx: *anyopaque) TaskState {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.state;
        }

        fn join(ctx: *anyopaque) TaskError!TaskExit {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .completed;
            return .completed;
        }

        fn start(ctx: *anyopaque, request: TaskStartRequest) TaskError!TaskHandle {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.state = .running;
            self.label = request.label;
            return .{
                .ctx = self,
                .request_stop_fn = requestStop,
                .inspect_fn = inspect,
                .join_fn = join,
            };
        }
    };

    var fake = FakeTask{};
    const driver = TaskDriver{
        .ctx = &fake,
        .start_fn = FakeTask.start,
    };

    const handle = try driver.start(.{ .label = "mailbox-sync" });
    try std.testing.expectEqualStrings("mailbox-sync", fake.label);
    try std.testing.expectEqual(.running, try handle.inspect());

    try handle.requestStop();
    try std.testing.expectEqual(.stop_requested, try handle.inspect());

    const result = try handle.join();
    try std.testing.expectEqual(TaskExit.completed, result);
    try std.testing.expectEqual(.completed, try handle.inspect());
}

test "task facade rejects invalid caller inputs with typed errors" {
    const FakeTask = struct {
        fn requestStop(_: *anyopaque) TaskError!void {}

        fn inspect(_: *anyopaque) TaskState {
            return .idle;
        }

        fn join(_: *anyopaque) TaskError!TaskExit {
            return .completed;
        }

        fn start(_: *anyopaque, _: TaskStartRequest) TaskError!TaskHandle {
            return .{
                .ctx = null,
                .request_stop_fn = requestStop,
                .inspect_fn = inspect,
                .join_fn = join,
            };
        }
    };

    const invalid_driver = TaskDriver{
        .ctx = null,
        .start_fn = FakeTask.start,
    };
    try std.testing.expectError(error.InvalidClient, invalid_driver.start(.{ .label = "sync" }));

    var fake_ctx: u8 = 0;
    const driver = TaskDriver{
        .ctx = &fake_ctx,
        .start_fn = FakeTask.start,
    };
    try std.testing.expectError(error.InvalidRequest, driver.start(.{ .label = "" }));

    const invalid_handle = TaskHandle{
        .ctx = null,
        .request_stop_fn = FakeTask.requestStop,
        .inspect_fn = FakeTask.inspect,
        .join_fn = FakeTask.join,
    };
    try std.testing.expectError(error.InvalidClient, invalid_handle.requestStop());
    try std.testing.expectError(error.InvalidClient, invalid_handle.inspect());
    try std.testing.expectError(error.InvalidClient, invalid_handle.join());
}
