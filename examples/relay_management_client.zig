const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay management client posts typed supportedmethods and banpubkey calls" {
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
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = noztr_sdk.client.relay.management.Storage{};
    const client = noztr_sdk.client.relay.management.Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var methods_http = FakeHttp{ .response_body = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}" };
    const methods_response = try client.fetchSupportedMethods(
        methods_http.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        methods[0..],
        arena.allocator(),
    );
    try std.testing.expect(methods_response.result == .methods);

    var ack_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const pubkey = [_]u8{0x11} ** 32;
    const ack_response = try client.banPubkey(
        ack_http.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token", .pubkey = pubkey, .reason = "spam" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );
    try std.testing.expect(ack_response.result == .ack);
}
