const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

pub const ExampleHttp = struct {
    expected_url: []const u8,
    expected_accept: ?[]const u8 = null,
    body: []const u8,
    fail_with: ?noztr_sdk.transport.HttpError = null,

    pub fn init(expected_url: []const u8, body: []const u8) ExampleHttp {
        return .{
            .expected_url = expected_url,
            .body = body,
        };
    }

    pub fn client(self: *ExampleHttp) noztr_sdk.transport.HttpClient {
        return .{
            .ctx = self,
            .get_fn = get,
        };
    }

    fn get(
        ctx: *anyopaque,
        request: noztr_sdk.transport.HttpRequest,
        out: []u8,
    ) noztr_sdk.transport.HttpError![]const u8 {
        const self: *ExampleHttp = @ptrCast(@alignCast(ctx));
        if (self.fail_with) |err| return err;
        if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
        if (self.expected_accept) |accept| {
            if (request.accept == null) return error.InvalidResponse;
            if (!std.mem.eql(u8, request.accept.?, accept)) return error.InvalidResponse;
        }
        if (self.body.len > out.len) return error.ResponseTooLarge;

        @memcpy(out[0..self.body.len], self.body);
        return out[0..self.body.len];
    }
};
