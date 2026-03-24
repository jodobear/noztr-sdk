const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay management client posts typed NIP-86 calls with explicit NIP-98 auth setup" {
    const FakeHttp = struct {
        response_body: []const u8,

        fn client(self: *@This()) noztr_sdk.transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: noztr_sdk.transport.HttpRequest, _: []u8) noztr_sdk.transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: noztr_sdk.transport.HttpPostRequest, out: []u8) noztr_sdk.transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, "https://relay.example/admin")) return error.InvalidResponse;
            if (request.content_type == null) return error.InvalidResponse;
            if (!std.mem.eql(u8, request.content_type.?, "application/json")) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            if (!std.mem.startsWith(u8, request.authorization.?, noztr.nip98_http_auth.authorization_scheme)) {
                return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = noztr_sdk.client.relay.management.Storage{};
    const client = noztr_sdk.client.relay.management.Client.init(.{}, &storage);
    const admin_secret = [_]u8{0x55} ** 32;
    var request_json: [192]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [256]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var kinds: [2]u32 = undefined;
    var blocked_ips: [1]noztr.nip86_relay_management.IpReason = undefined;
    var allowed_pubkeys: [1]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const supportedmethods_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .supportedmethods,
        &admin_secret,
        1_700_000_000,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var methods_http = FakeHttp{ .response_body = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}" };
    const methods_response_json = try client.postPrepared(methods_http.client(), &supportedmethods_post, response_json[0..]);
    const methods_response = try client.parseSupportedMethodsResponse(methods_response_json, methods[0..], arena.allocator());
    try std.testing.expect(methods_response.result == .methods);

    const allowed_kinds_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listallowedkinds,
        &admin_secret,
        1_700_000_001,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var kinds_http = FakeHttp{ .response_body = "{\"result\":[1,1984],\"error\":null}" };
    const kinds_response_json = try client.postPrepared(kinds_http.client(), &allowed_kinds_post, response_json[0..]);
    const kinds_response = try client.parseListAllowedKindsResponse(kinds_response_json, kinds[0..], arena.allocator());
    try std.testing.expect(kinds_response.result == .kinds);
    try std.testing.expectEqual(@as(u32, 1984), kinds_response.result.kinds[1]);

    const allowed_pubkeys_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listallowedpubkeys,
        &admin_secret,
        1_700_000_001,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var allowed_pubkeys_http = FakeHttp{
        .response_body = "{\"result\":[{\"pubkey\":\"1111111111111111111111111111111111111111111111111111111111111111\",\"reason\":\"seed\"}],\"error\":null}",
    };
    const allowed_pubkeys_response_json = try client.postPrepared(
        allowed_pubkeys_http.client(),
        &allowed_pubkeys_post,
        response_json[0..],
    );
    const allowed_pubkeys_response = try client.parseListAllowedPubkeysResponse(
        allowed_pubkeys_response_json,
        allowed_pubkeys[0..],
        arena.allocator(),
    );
    try std.testing.expect(allowed_pubkeys_response.result == .pubkeys);
    try std.testing.expectEqualStrings("seed", allowed_pubkeys_response.result.pubkeys[0].reason.?);

    const blocked_ips_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listblockedips,
        &admin_secret,
        1_700_000_002,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var blocked_ips_http = FakeHttp{
        .response_body = "{\"result\":[{\"ip\":\"203.0.113.7\",\"reason\":\"scanner\"}],\"error\":null}",
    };
    const blocked_ips_response_json = try client.postPrepared(
        blocked_ips_http.client(),
        &blocked_ips_post,
        response_json[0..],
    );
    const blocked_ips_response = try client.parseListBlockedIpsResponse(
        blocked_ips_response_json,
        blocked_ips[0..],
        arena.allocator(),
    );
    try std.testing.expect(blocked_ips_response.result == .ips);
    try std.testing.expectEqualStrings("203.0.113.7", blocked_ips_response.result.ips[0].ip);
    try std.testing.expectEqualStrings("scanner", blocked_ips_response.result.ips[0].reason.?);

    const pubkey = [_]u8{0x11} ** 32;
    const allowpubkey_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .allowpubkey = .{ .pubkey = pubkey, .reason = "operator" } },
        &admin_secret,
        1_700_000_002,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var allowpubkey_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const allowpubkey_response_json = try client.postPrepared(
        allowpubkey_http.client(),
        &allowpubkey_post,
        response_json[0..],
    );
    const allowpubkey_response = try client.parseAllowPubkeyResponse(
        allowpubkey_response_json,
        arena.allocator(),
    );
    try std.testing.expect(allowpubkey_response.result == .ack);

    const allowkind_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .allowkind = 1984 },
        &admin_secret,
        1_700_000_003,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var ack_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const ack_response_json = try client.postPrepared(ack_http.client(), &allowkind_post, response_json[0..]);
    const ack_response = try client.parseAllowKindResponse(ack_response_json, arena.allocator());
    try std.testing.expect(ack_response.result == .ack);

    const blockip_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .blockip = .{ .ip = "198.51.100.42", .reason = "manual" } },
        &admin_secret,
        1_700_000_004,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const blockip_response_json = try client.postPrepared(ack_http.client(), &blockip_post, response_json[0..]);
    const blockip_response = try client.parseBlockIpResponse(blockip_response_json, arena.allocator());
    try std.testing.expect(blockip_response.result == .ack);

    const ban_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .banpubkey = .{ .pubkey = pubkey, .reason = "spam" } },
        &admin_secret,
        1_700_000_005,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const ban_response_json = try client.postPrepared(ack_http.client(), &ban_post, response_json[0..]);
    const ban_response = try client.parseBanPubkeyResponse(ban_response_json, arena.allocator());
    try std.testing.expect(ban_response.result == .ack);
}
