const std = @import("std");
const transport = @import("../transport/mod.zig");

pub const FakeHttp = struct {
    expected_url: []const u8,
    expected_accept: ?[]const u8 = null,
    body: []const u8,
    fail_with: ?transport.HttpError = null,

    pub fn init(expected_url: []const u8, body: []const u8) FakeHttp {
        return .{
            .expected_url = expected_url,
            .expected_accept = null,
            .body = body,
            .fail_with = null,
        };
    }

    pub fn client(self: *FakeHttp) transport.HttpClient {
        return .{
            .ctx = self,
            .get_fn = get,
        };
    }
};

fn get(ctx: *anyopaque, request: transport.HttpRequest, out: []u8) transport.HttpError![]const u8 {
    const self: *FakeHttp = @ptrCast(@alignCast(ctx));
    if (self.fail_with) |failure| return failure;
    if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
    if (self.expected_accept) |accept| {
        if (request.accept == null) return error.InvalidResponse;
        if (!std.mem.eql(u8, request.accept.?, accept)) return error.InvalidResponse;
    }
    if (self.body.len > out.len) return error.ResponseTooLarge;

    @memcpy(out[0..self.body.len], self.body);
    return out[0..self.body.len];
}
