const std = @import("std");

pub const HttpError = error{
    TransportUnavailable,
    NotFound,
    ResponseTooLarge,
    InvalidResponse,
};

pub const HttpRequest = struct {
    url: []const u8,
    accept: ?[]const u8 = null,
};

pub const HttpClient = struct {
    ctx: *anyopaque,
    get_fn: *const fn (ctx: *anyopaque, request: HttpRequest, out: []u8) HttpError![]const u8,

    pub fn get(self: HttpClient, request: HttpRequest, out: []u8) HttpError![]const u8 {
        std.debug.assert(@intFromPtr(self.ctx) != 0);
        std.debug.assert(request.url.len > 0);

        return self.get_fn(self.ctx, request, out);
    }
};
