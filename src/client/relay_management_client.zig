const std = @import("std");
const transport = @import("../transport/mod.zig");
const noztr = @import("noztr");

pub const Error = transport.HttpError || noztr.nip86_relay_management.RelayManagementError;

pub const Config = struct {};

pub const Storage = struct {};

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

pub const Client = struct {
    config: Config,

    pub fn init(config: Config, storage: *Storage) Client {
        storage.* = .{};
        return .{ .config = config };
    }

    pub fn attach(config: Config, _: *Storage) Client {
        return .{ .config = config };
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
        const request_json = try noztr.nip86_relay_management.request_serialize_json(
            request_json_out,
            .supportedmethods,
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .supportedmethods, methods_out, scratch);
    }

    pub fn banPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const BanPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try noztr.nip86_relay_management.request_serialize_json(
            request_json_out,
            .{ .banpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .banpubkey, &.{}, scratch);
    }
};

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
    scratch: std.mem.Allocator,
) Error!noztr.nip86_relay_management.Response {
    var zero_pubkeys: [0]noztr.nip86_relay_management.PubkeyReason = .{};
    var zero_events: [0]noztr.nip86_relay_management.EventIdReason = .{};
    var zero_kinds: [0]u32 = .{};
    var zero_ips: [0]noztr.nip86_relay_management.IpReason = .{};
    return noztr.nip86_relay_management.response_parse_json(
        response_json,
        expected_method,
        methods_out,
        zero_pubkeys[0..],
        zero_events[0..],
        zero_kinds[0..],
        zero_ips[0..],
        scratch,
    );
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
