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
    var payload_hex: [64]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
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

    const pubkey = [_]u8{0x11} ** 32;
    const ban_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .banpubkey = .{ .pubkey = pubkey, .reason = "spam" } },
        &admin_secret,
        1_700_000_001,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var ack_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const ack_response_json = try client.postPrepared(ack_http.client(), &ban_post, response_json[0..]);
    const ack_response = try client.parseBanPubkeyResponse(ack_response_json, arena.allocator());
    try std.testing.expect(ack_response.result == .ack);
}
