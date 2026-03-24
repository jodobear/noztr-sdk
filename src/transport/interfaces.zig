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

pub const HttpPostRequest = struct {
    url: []const u8,
    body: []const u8,
    accept: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    authorization: ?[]const u8 = null,
};

pub const HttpClient = struct {
    ctx: ?*anyopaque,
    get_fn: *const fn (ctx: *anyopaque, request: HttpRequest, out: []u8) HttpError![]const u8,
    post_fn: ?*const fn (ctx: *anyopaque, request: HttpPostRequest, out: []u8) HttpError![]const u8 = null,

    pub fn get(self: HttpClient, request: HttpRequest, out: []u8) HttpError![]const u8 {
        if (self.ctx == null) return error.InvalidClient;
        if (request.url.len == 0) return error.InvalidRequest;

        return self.get_fn(self.ctx.?, request, out);
    }

    pub fn post(self: HttpClient, request: HttpPostRequest, out: []u8) HttpError![]const u8 {
        if (self.ctx == null) return error.InvalidClient;
        if (request.url.len == 0) return error.InvalidRequest;
        if (request.body.len == 0) return error.InvalidRequest;
        const post_fn = self.post_fn orelse return error.InvalidClient;

        return post_fn(self.ctx.?, request, out);
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

    try std.testing.expectError(
        error.InvalidClient,
        client.post(.{ .url = "https://example.test", .body = "{}" }, out[0..]),
    );
}

test "http client forwards bounded post requests" {
    const FakeHttp = struct {
        last_url: []const u8 = "",
        last_body: []const u8 = "",
        last_accept: ?[]const u8 = null,
        last_content_type: ?[]const u8 = null,
        last_authorization: ?[]const u8 = null,

        fn get(_: *anyopaque, _: HttpRequest, _: []u8) HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: HttpPostRequest, out: []u8) HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_url = request.url;
            self.last_body = request.body;
            self.last_accept = request.accept;
            self.last_content_type = request.content_type;
            self.last_authorization = request.authorization;
            const body = "ok";
            @memcpy(out[0..body.len], body);
            return out[0..body.len];
        }
    };

    var fake = FakeHttp{};
    const client = HttpClient{
        .ctx = &fake,
        .get_fn = FakeHttp.get,
        .post_fn = FakeHttp.post,
    };
    var out: [8]u8 = undefined;

    const body = try client.post(.{
        .url = "https://example.test/admin",
        .body = "{}",
        .accept = "application/json",
        .content_type = "application/json",
        .authorization = "Nostr token",
    }, out[0..]);
    try std.testing.expectEqualStrings("https://example.test/admin", fake.last_url);
    try std.testing.expectEqualStrings("{}", fake.last_body);
    try std.testing.expectEqualStrings("application/json", fake.last_accept.?);
    try std.testing.expectEqualStrings("application/json", fake.last_content_type.?);
    try std.testing.expectEqualStrings("Nostr token", fake.last_authorization.?);
    try std.testing.expectEqualStrings("ok", body);
}
