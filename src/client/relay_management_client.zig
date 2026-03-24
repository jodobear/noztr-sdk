const std = @import("std");
const transport = @import("../transport/mod.zig");
const noztr = @import("noztr");

pub const Error = transport.HttpError || noztr.nip86_relay_management.RelayManagementError;
pub const Nip98PostError = noztr.nip86_relay_management.RelayManagementError ||
    noztr.nip98_http_auth.HttpAuthError ||
    noztr.nostr_keys.NostrKeysError;

pub const Config = struct {};

pub const Storage = struct {};

pub const PreparedPost = struct {
    url: []const u8,
    request_json: []const u8,
    payload_hex: []const u8,

    pub const method = "POST";
};

pub const SupportedMethodsRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const BanPubkeyRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const AllowPubkeyRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const AllowKindRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    kind: u32,
};

pub const ListAllowedKindsRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const ListAllowedPubkeysRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const PreparedAuthorizedPost = struct {
    url: []const u8,
    request_json: []const u8,
    authorization: []const u8,
};

pub const Client = struct {
    config: Config,

    pub fn init(config: Config, storage: *Storage) Client {
        storage.* = .{};
        return .{ .config = config };
    }

    pub fn attach(config: Config, _: *Storage) Client {
        return .{ .config = config };
    }

    pub fn preparePost(
        _: Client,
        url: []const u8,
        request: noztr.nip86_relay_management.Request,
        request_json_out: []u8,
        payload_hex_out: []u8,
    ) Nip98PostError!PreparedPost {
        const request_json = try serializeRequestJson(request_json_out, request);
        const payload_hex = try noztr.nip98_http_auth.http_auth_payload_sha256_hex(payload_hex_out, request_json);
        return .{
            .url = url,
            .request_json = request_json,
            .payload_hex = payload_hex,
        };
    }

    pub fn encodePreparedAuthorization(
        _: Client,
        prepared: *const PreparedPost,
        auth_event: *const noztr.nip01_event.Event,
        authorization_out: []u8,
        authorization_json_out: []u8,
    ) Nip98PostError![]const u8 {
        _ = try noztr.nip98_http_auth.http_auth_verify_request(
            auth_event,
            prepared.url,
            PreparedPost.method,
            prepared.payload_hex,
            auth_event.created_at,
            0,
            0,
        );
        return noztr.nip98_http_auth.http_auth_encode_authorization_header(
            authorization_out,
            auth_event,
            authorization_json_out,
        );
    }

    pub fn prepareAuthorizedPost(
        self: Client,
        url: []const u8,
        request: noztr.nip86_relay_management.Request,
        secret_key: *const [32]u8,
        created_at: u64,
        request_json_out: []u8,
        payload_hex_out: []u8,
        authorization_out: []u8,
        authorization_json_out: []u8,
    ) Nip98PostError!PreparedAuthorizedPost {
        const prepared = try self.preparePost(url, request, request_json_out, payload_hex_out);
        const signed = try buildSignedPostAuthorization(secret_key, prepared.url, prepared.payload_hex, created_at);
        const authorization = try self.encodePreparedAuthorization(
            &prepared,
            &signed.event,
            authorization_out,
            authorization_json_out,
        );
        return .{ .url = prepared.url, .request_json = prepared.request_json, .authorization = authorization };
    }

    pub fn postPrepared(
        _: Client,
        http: transport.HttpClient,
        prepared: *const PreparedAuthorizedPost,
        response_json_out: []u8,
    ) transport.HttpError![]const u8 {
        return postJson(http, prepared.url, prepared.authorization, prepared.request_json, response_json_out);
    }

    pub fn parseSupportedMethodsResponse(
        _: Client,
        response_json: []const u8,
        methods_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .supportedmethods, methods_out, &.{}, &.{}, scratch);
    }

    pub fn parseBanPubkeyResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .banpubkey, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseAllowPubkeyResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .allowpubkey, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseAllowKindResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .allowkind, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseListAllowedKindsResponse(
        _: Client,
        response_json: []const u8,
        kinds_out: []u32,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listallowedkinds, &.{}, &.{}, kinds_out, scratch);
    }

    pub fn parseListAllowedPubkeysResponse(
        _: Client,
        response_json: []const u8,
        pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listallowedpubkeys, &.{}, pubkeys_out, &.{}, scratch);
    }

    pub fn fetchSupportedMethods(
        _: Client,
        http: transport.HttpClient,
        request: *const SupportedMethodsRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        methods_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .supportedmethods);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .supportedmethods, methods_out, &.{}, &.{}, scratch);
    }

    pub fn banPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const BanPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .banpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .banpubkey, &.{}, &.{}, &.{}, scratch);
    }

    pub fn allowPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const AllowPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .allowpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .allowpubkey, &.{}, &.{}, &.{}, scratch);
    }

    pub fn allowKind(
        _: Client,
        http: transport.HttpClient,
        request: *const AllowKindRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .{ .allowkind = request.kind });
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .allowkind, &.{}, &.{}, &.{}, scratch);
    }

    pub fn fetchListAllowedKinds(
        _: Client,
        http: transport.HttpClient,
        request: *const ListAllowedKindsRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        kinds_out: []u32,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listallowedkinds);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listallowedkinds, &.{}, &.{}, kinds_out, scratch);
    }

    pub fn fetchListAllowedPubkeys(
        _: Client,
        http: transport.HttpClient,
        request: *const ListAllowedPubkeysRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listallowedpubkeys);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listallowedpubkeys, &.{}, pubkeys_out, &.{}, scratch);
    }
};

fn serializeRequestJson(
    request_json_out: []u8,
    request: noztr.nip86_relay_management.Request,
) noztr.nip86_relay_management.RelayManagementError![]const u8 {
    return noztr.nip86_relay_management.request_serialize_json(request_json_out, request);
}

fn postJson(
    http: transport.HttpClient,
    url: []const u8,
    authorization: ?[]const u8,
    request_json: []const u8,
    response_json_out: []u8,
) transport.HttpError![]const u8 {
    return http.post(.{
        .url = url,
        .body = request_json,
        .accept = "application/json",
        .content_type = "application/json",
        .authorization = authorization,
    }, response_json_out);
}

fn parseResponse(
    response_json: []const u8,
    expected_method: noztr.nip86_relay_management.RelayManagementMethod,
    methods_out: [][]const u8,
    pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
    kinds_out: []u32,
    scratch: std.mem.Allocator,
) Error!noztr.nip86_relay_management.Response {
    var zero_events: [0]noztr.nip86_relay_management.EventIdReason = .{};
    var zero_ips: [0]noztr.nip86_relay_management.IpReason = .{};
    return noztr.nip86_relay_management.response_parse_json(
        response_json,
        expected_method,
        methods_out,
        pubkeys_out,
        zero_events[0..],
        kinds_out,
        zero_ips[0..],
        scratch,
    );
}

const SignedPostAuthorization = struct {
    url_tag: noztr.nip98_http_auth.TagBuilder,
    method_tag: noztr.nip98_http_auth.TagBuilder,
    payload_tag: noztr.nip98_http_auth.TagBuilder,
    tags: [3]noztr.nip01_event.EventTag,
    event: noztr.nip01_event.Event,
};

fn buildSignedPostAuthorization(
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
        try noztr.nip98_http_auth.http_auth_build_url_tag(&signed.url_tag, url),
        try noztr.nip98_http_auth.http_auth_build_method_tag(&signed.method_tag, PreparedPost.method),
        try noztr.nip98_http_auth.http_auth_build_payload_tag(&signed.payload_tag, payload_hex),
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

test "relay management client posts supportedmethods and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    const expected_body = "{\"method\":\"supportedmethods\",\"params\":[]}";
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = expected_body,
        .response_body = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchSupportedMethods(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        methods[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .methods);
    try std.testing.expectEqualStrings("banpubkey", response.result.methods[1]);
}

test "relay management client prepares caller-driven NIP-98 auth for POST bodies" {
    const secret_key = [_]u8{0x22} ** 32;

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var decoded_json: [1024]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.preparePost(
        "https://relay.example/admin",
        .supportedmethods,
        request_json[0..],
        payload_hex[0..],
    );
    try std.testing.expectEqualStrings(
        "{\"method\":\"supportedmethods\",\"params\":[]}",
        prepared.request_json,
    );

    const signed = try buildSignedPostAuthorization(
        &secret_key,
        prepared.url,
        prepared.payload_hex,
        1_700_000_000,
    );
    const header = try client.encodePreparedAuthorization(
        &prepared,
        &signed.event,
        authorization[0..],
        authorization_json[0..],
    );
    const verified = try noztr.nip98_http_auth.http_auth_verify_authorization_header(
        decoded_json[0..],
        header,
        prepared.url,
        PreparedPost.method,
        prepared.payload_hex,
        signed.event.created_at,
        0,
        0,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("Nostr ", header[0..noztr.nip98_http_auth.authorization_scheme.len]);
    try std.testing.expectEqualStrings(prepared.url, verified.info.url);
    try std.testing.expectEqualStrings(PreparedPost.method, verified.info.method);
    try std.testing.expectEqualStrings(prepared.payload_hex, verified.info.payload_hex.?);
}

test "relay management client executes prepared authorized posts coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,
        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }
        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x34} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .supportedmethods,
        &secret_key,
        1_700_000_300,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseSupportedMethodsResponse(response_json_slice, methods[0..], arena.allocator());

    try std.testing.expect(response.result == .methods);
    try std.testing.expectEqualStrings("banpubkey", response.result.methods[1]);
}

test "relay management client posts banpubkey and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const pubkey = [_]u8{0x11} ** 32;
    const expected_body =
        "{\"method\":\"banpubkey\",\"params\":[\"1111111111111111111111111111111111111111111111111111111111111111\",\"spam\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.banPubkey(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .pubkey = pubkey, .reason = "spam" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts allowpubkey and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const pubkey = [_]u8{0xaa} ** 32;
    const expected_body =
        "{\"method\":\"allowpubkey\",\"params\":[\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"operator\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.allowPubkey(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .pubkey = pubkey, .reason = "operator" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts allowkind and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body = "{\"method\":\"allowkind\",\"params\":[1984]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [96]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.allowKind(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .kind = 1984 },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts listallowedkinds and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listallowedkinds\",\"params\":[]}",
        .response_body = "{\"result\":[1,1984],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var kinds: [2]u32 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListAllowedKinds(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        kinds[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .kinds);
    try std.testing.expectEqual(@as(usize, 2), response.result.kinds.len);
    try std.testing.expectEqual(@as(u32, 1984), response.result.kinds[1]);
}

test "relay management client posts listallowedpubkeys and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const first_pubkey = [_]u8{0x11} ** 32;
    const second_pubkey = [_]u8{0x22} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listallowedpubkeys\",\"params\":[]}",
        .response_body = "{\"result\":[{\"pubkey\":\"1111111111111111111111111111111111111111111111111111111111111111\",\"reason\":\"seed\"},{\"pubkey\":\"2222222222222222222222222222222222222222222222222222222222222222\"}],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [256]u8 = undefined;
    var pubkeys: [2]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListAllowedPubkeys(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        pubkeys[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 2), response.result.pubkeys.len);
    try std.testing.expectEqualDeep(first_pubkey, response.result.pubkeys[0].pubkey);
    try std.testing.expectEqualStrings("seed", response.result.pubkeys[0].reason.?);
    try std.testing.expectEqualDeep(second_pubkey, response.result.pubkeys[1].pubkey);
    try std.testing.expect(response.result.pubkeys[1].reason == null);
}

test "relay management client parses prepared listallowedpubkeys responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response =
                "{\"result\":[{\"pubkey\":\"4444444444444444444444444444444444444444444444444444444444444444\",\"reason\":\"vip\"}],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x45} ** 32;
    const expected_pubkey = [_]u8{0x44} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [192]u8 = undefined;
    var pubkeys: [1]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listallowedpubkeys,
        &secret_key,
        1_700_000_400,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseListAllowedPubkeysResponse(
        response_json_slice,
        pubkeys[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 1), response.result.pubkeys.len);
    try std.testing.expectEqualDeep(expected_pubkey, response.result.pubkeys[0].pubkey);
    try std.testing.expectEqualStrings("vip", response.result.pubkeys[0].reason.?);
}

test "relay management client accepts explicit NIP-98 authorization headers" {
    const FakeHttp = struct {
        created_at: u64,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            const header = request.authorization orelse return error.InvalidResponse;
            var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
            const expected_payload = noztr.nip98_http_auth.http_auth_payload_sha256_hex(
                payload_hex[0..],
                request.body,
            ) catch return error.InvalidResponse;
            var decoded_json: [1024]u8 = undefined;
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();

            _ = noztr.nip98_http_auth.http_auth_verify_authorization_header(
                decoded_json[0..],
                header,
                request.url,
                PreparedPost.method,
                expected_payload,
                self.created_at,
                0,
                0,
                arena.allocator(),
            ) catch return error.InvalidResponse;

            const response = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}";
            if (response.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x33} ** 32;
    const created_at: u64 = 1_700_000_100;
    var fake = FakeHttp{ .created_at = created_at };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var nip98_request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.preparePost(
        "https://relay.example/admin",
        .supportedmethods,
        nip98_request_json[0..],
        payload_hex[0..],
    );
    const signed = try buildSignedPostAuthorization(
        &secret_key,
        prepared.url,
        prepared.payload_hex,
        created_at,
    );
    const header = try client.encodePreparedAuthorization(
        &prepared,
        &signed.event,
        authorization[0..],
        authorization_json[0..],
    );

    const response = try client.fetchSupportedMethods(
        fake.client(),
        &.{ .url = prepared.url, .authorization = header },
        request_json[0..],
        response_json[0..],
        methods[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .methods);
    try std.testing.expectEqualStrings("supportedmethods", response.result.methods[0]);
}

test "relay management client rejects mismatched prepared NIP-98 auth events" {
    const secret_key = [_]u8{0x44} ** 32;

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;

    const prepared = try client.preparePost(
        "https://relay.example/admin",
        .supportedmethods,
        request_json[0..],
        payload_hex[0..],
    );
    const signed = try buildSignedPostAuthorization(
        &secret_key,
        "https://relay.example/other",
        prepared.payload_hex,
        1_700_000_200,
    );

    try std.testing.expectError(
        error.UrlMismatch,
        client.encodePreparedAuthorization(
            &prepared,
            &signed.event,
            authorization[0..],
            authorization_json[0..],
        ),
    );
}

test "relay management client surfaces invalid relay-management responses" {
    const FakeHttp = struct {
        dummy: u8 = 0,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = &self.dummy, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const response = "{\"result\":\"bad\",\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    var fake = FakeHttp{};
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var methods: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidResponse,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "https://relay.example/admin" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}
