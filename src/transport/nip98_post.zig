const std = @import("std");
const interfaces = @import("interfaces.zig");
const noztr = @import("noztr");

pub const TargetError = error{InvalidPostTarget};

pub const PreparedPost = struct {
    url: []const u8,
    body: []const u8,
    accept: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    payload_hex: []const u8,

    pub const method = "POST";
};

pub const PreparedAuthorizedPost = struct {
    url: []const u8,
    body: []const u8,
    accept: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    authorization: []const u8,
};

const SignedPostAuthorization = struct {
    url_tag: noztr.nip98_http_auth.TagBuilder,
    method_tag: noztr.nip98_http_auth.TagBuilder,
    payload_tag: noztr.nip98_http_auth.TagBuilder,
    tags: [3]noztr.nip01_event.EventTag,
    event: noztr.nip01_event.Event,
};

pub fn preparePost(
    url: []const u8,
    body: []const u8,
    accept: ?[]const u8,
    content_type: ?[]const u8,
    payload_hex_out: []u8,
) (TargetError || noztr.nip98_http_auth.HttpAuthError)!PreparedPost {
    try validatePostTarget(url);
    const payload_hex = try noztr.nip98_http_auth.payload_sha256_hex(payload_hex_out, body);
    return .{
        .url = url,
        .body = body,
        .accept = accept,
        .content_type = content_type,
        .payload_hex = payload_hex,
    };
}

pub fn encodePreparedAuthorization(
    prepared: *const PreparedPost,
    auth_event: *const noztr.nip01_event.Event,
    authorization_out: []u8,
    authorization_json_out: []u8,
) noztr.nip98_http_auth.HttpAuthError![]const u8 {
    _ = try noztr.nip98_http_auth.verify_request(
        auth_event,
        prepared.url,
        PreparedPost.method,
        prepared.payload_hex,
        auth_event.created_at,
        0,
        0,
    );
    return noztr.nip98_http_auth.encode_authorization_header(
        authorization_out,
        auth_event,
        authorization_json_out,
    );
}

pub fn prepareSignedPostAuthorization(
    secret_key: *const [32]u8,
    url: []const u8,
    payload_hex: []const u8,
    created_at: u64,
) !SignedPostAuthorization {
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(secret_key);
    var signed = SignedPostAuthorization{
        .url_tag = .{},
        .method_tag = .{},
        .payload_tag = .{},
        .tags = undefined,
        .event = undefined,
    };
    signed.tags = .{
        try noztr.nip98_http_auth.build_url_tag(&signed.url_tag, url),
        try noztr.nip98_http_auth.build_method_tag(&signed.method_tag, PreparedPost.method),
        try noztr.nip98_http_auth.build_payload_tag(&signed.payload_tag, payload_hex),
    };
    signed.event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip98_http_auth.http_auth_kind,
        .created_at = created_at,
        .content = "",
        .tags = signed.tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(secret_key, &signed.event);
    return signed;
}

pub fn prepareAuthorizedPost(
    url: []const u8,
    body: []const u8,
    accept: ?[]const u8,
    content_type: ?[]const u8,
    secret_key: *const [32]u8,
    created_at: u64,
    payload_hex_out: []u8,
    authorization_out: []u8,
    authorization_json_out: []u8,
) (TargetError || noztr.nip98_http_auth.HttpAuthError || noztr.nostr_keys.NostrKeysError)!PreparedAuthorizedPost {
    const prepared = try preparePost(url, body, accept, content_type, payload_hex_out);
    const signed = try prepareSignedPostAuthorization(secret_key, prepared.url, prepared.payload_hex, created_at);
    const authorization = try encodePreparedAuthorization(&prepared, &signed.event, authorization_out, authorization_json_out);
    return .{
        .url = prepared.url,
        .body = prepared.body,
        .accept = prepared.accept,
        .content_type = prepared.content_type,
        .authorization = authorization,
    };
}

pub fn executePreparedPost(
    http: interfaces.HttpClient,
    prepared: *const PreparedAuthorizedPost,
    response_json_out: []u8,
) (interfaces.HttpError || TargetError)![]const u8 {
    try validatePostTarget(prepared.url);
    return http.post(.{
        .url = prepared.url,
        .body = prepared.body,
        .accept = prepared.accept,
        .content_type = prepared.content_type,
        .authorization = prepared.authorization,
    }, response_json_out);
}

pub fn executePost(
    http: interfaces.HttpClient,
    url: []const u8,
    body: []const u8,
    accept: ?[]const u8,
    content_type: ?[]const u8,
    authorization: ?[]const u8,
    response_json_out: []u8,
) (interfaces.HttpError || TargetError)![]const u8 {
    try validatePostTarget(url);
    return http.post(.{
        .url = url,
        .body = body,
        .accept = accept,
        .content_type = content_type,
        .authorization = authorization,
    }, response_json_out);
}

fn validatePostTarget(url: []const u8) TargetError!void {
    if (url.len == 0) return error.InvalidPostTarget;
    const parsed = std.Uri.parse(url) catch return error.InvalidPostTarget;
    if (parsed.host == null) return error.InvalidPostTarget;
    if (!std.ascii.eqlIgnoreCase(parsed.scheme, "https")) return error.InvalidPostTarget;
}

test "transport nip98 prepares payload hash and keeps request ownership" {
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    const prepared = try preparePost(
        "https://relay.example/admin",
        "{\"method\":\"supportedmethods\",\"params\":[]}",
        "application/json",
        "application/json",
        payload_hex[0..],
    );
    try std.testing.expectEqualStrings("https://relay.example/admin", prepared.url);
    try std.testing.expectEqualStrings(
        "{\"method\":\"supportedmethods\",\"params\":[]}",
        prepared.body,
    );
    try std.testing.expect(prepared.payload_hex.len > 0);
}

test "transport nip98 rejects malformed post targets before preparation" {
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidPostTarget,
        preparePost(
            "://bad",
            "{\"method\":\"supportedmethods\",\"params\":[]}",
            "application/json",
            "application/json",
            payload_hex[0..],
        ),
    );

    try std.testing.expectError(
        error.InvalidPostTarget,
        preparePost(
            "https:///admin",
            "{\"method\":\"supportedmethods\",\"params\":[]}",
            "application/json",
            "application/json",
            payload_hex[0..],
        ),
    );

    try std.testing.expectError(
        error.InvalidPostTarget,
        preparePost(
            "http://relay.example/admin",
            "{\"method\":\"supportedmethods\",\"params\":[]}",
            "application/json",
            "application/json",
            payload_hex[0..],
        ),
    );
}

test "transport nip98 executes prepared posts with explicit auth" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: []const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) interfaces.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: interfaces.HttpRequest, _: []u8) interfaces.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: interfaces.HttpPostRequest, out: []u8) interfaces.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.InvalidResponse;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            if (!std.mem.eql(u8, request.authorization.?, self.expected_authorization)) return error.InvalidResponse;
            if (request.accept == null or !std.mem.eql(u8, request.accept.?, "application/json")) return error.InvalidResponse;
            if (request.content_type == null or !std.mem.eql(u8, request.content_type.?, "application/json")) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;

    const prepared = try prepareAuthorizedPost(
        "https://relay.example/admin",
        "{\"method\":\"supportedmethods\",\"params\":[]}",
        "application/json",
        "application/json",
        &[_]u8{0x55} ** 32,
        1_700_000_001,
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );

    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = prepared.authorization,
        .expected_body = "{\"method\":\"supportedmethods\",\"params\":[]}",
        .response_body = "{\"result\":[\"supportedmethods\"],\"error\":null}",
    };

    var response_out: [96]u8 = undefined;
    const response = try executePreparedPost(fake.client(), &prepared, response_out[0..]);
    try std.testing.expectEqualStrings("{\"result\":[\"supportedmethods\"],\"error\":null}", response);
}
