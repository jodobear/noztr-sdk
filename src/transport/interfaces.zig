const std = @import("std");

pub const HttpError = error{
    InvalidClient,
    InvalidRequest,
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
    ctx: ?*anyopaque,
    get_fn: *const fn (ctx: *anyopaque, request: HttpRequest, out: []u8) HttpError![]const u8,

    pub fn get(self: HttpClient, request: HttpRequest, out: []u8) HttpError![]const u8 {
        if (self.ctx == null) return error.InvalidClient;
        if (request.url.len == 0) return error.InvalidRequest;

        return self.get_fn(self.ctx.?, request, out);
    }
};

test "http client forwards bounded get requests" {
    const FakeHttp = struct {
        last_url: []const u8 = "",
        last_accept: ?[]const u8 = null,

        fn get(ctx: *anyopaque, request: HttpRequest, out: []u8) HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_url = request.url;
            self.last_accept = request.accept;
            const body = "ok";
            @memcpy(out[0..body.len], body);
            return out[0..body.len];
        }
    };

    var fake = FakeHttp{};
    const client = HttpClient{
        .ctx = &fake,
        .get_fn = FakeHttp.get,
    };
    var out: [8]u8 = undefined;

    const body = try client.get(.{
        .url = "https://example.test",
        .accept = "application/json",
    }, out[0..]);
    try std.testing.expectEqualStrings("https://example.test", fake.last_url);
    try std.testing.expectEqualStrings("application/json", fake.last_accept.?);
    try std.testing.expectEqualStrings("ok", body);
}

test "http client rejects invalid caller inputs with typed errors" {
    const FakeHttp = struct {
        fn get(_: *anyopaque, _: HttpRequest, _: []u8) HttpError![]const u8 {
            return "unused";
        }
    };

    const invalid_client = HttpClient{
        .ctx = null,
        .get_fn = FakeHttp.get,
    };
    var out: [8]u8 = undefined;

    try std.testing.expectError(
        error.InvalidClient,
        invalid_client.get(.{ .url = "https://example.test" }, out[0..]),
    );

    var fake_ctx: u8 = 0;
    const client = HttpClient{
        .ctx = &fake_ctx,
        .get_fn = FakeHttp.get,
    };
    try std.testing.expectError(
        error.InvalidRequest,
        client.get(.{ .url = "" }, out[0..]),
    );
}
