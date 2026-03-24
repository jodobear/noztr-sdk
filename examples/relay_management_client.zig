const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay management client exercises a broad typed NIP-86 admin matrix with executeAuthorizedPost" {
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
    var banned_pubkeys: [1]noztr.nip86_relay_management.PubkeyReason = undefined;
    var banned_events: [1]noztr.nip86_relay_management.EventIdReason = undefined;
    var moderation_events: [1]noztr.nip86_relay_management.EventIdReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var methods_http = FakeHttp{ .response_body = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}" };
    const methods_response = try client.executeAuthorizedPost(
        methods_http.client(),
        "https://relay.example/admin",
        .supportedmethods,
        &admin_secret,
        1_700_000_000,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
        response_json[0..],
        .{ .methods = methods[0..] },
        arena.allocator(),
    );
    try std.testing.expect(methods_response.result == .methods);

    var relay_name_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const relay_name_response = try client.executeAuthorizedPost(
        relay_name_http.client(),
        "https://relay.example/admin",
        .{ .changerelayname = "Noztr Relay" },
        &admin_secret,
        1_700_000_000,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
        response_json[0..],
        .{},
        arena.allocator(),
    );
    try std.testing.expect(relay_name_response.result == .ack);

    const changerelaydescription_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .changerelaydescription = "A bounded operator relay" },
        &admin_secret,
        1_700_000_000,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var relay_description_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const relay_description_response_json = try client.postPrepared(
        relay_description_http.client(),
        &changerelaydescription_post,
        response_json[0..],
    );
    const relay_description_response = try client.parseChangeRelayDescriptionResponse(
        relay_description_response_json,
        arena.allocator(),
    );
    try std.testing.expect(relay_description_response.result == .ack);

    const changerelayicon_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .changerelayicon = "https://relay.example/icon.png" },
        &admin_secret,
        1_700_000_000,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var relay_icon_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const relay_icon_response_json = try client.postPrepared(
        relay_icon_http.client(),
        &changerelayicon_post,
        response_json[0..],
    );
    const relay_icon_response = try client.parseChangeRelayIconResponse(
        relay_icon_response_json,
        arena.allocator(),
    );
    try std.testing.expect(relay_icon_response.result == .ack);

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
        1_700_000_002,
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

    const banned_pubkeys_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listbannedpubkeys,
        &admin_secret,
        1_700_000_003,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var banned_pubkeys_http = FakeHttp{
        .response_body = "{\"result\":[{\"pubkey\":\"3333333333333333333333333333333333333333333333333333333333333333\",\"reason\":\"spam\"}],\"error\":null}",
    };
    const banned_pubkeys_response_json = try client.postPrepared(
        banned_pubkeys_http.client(),
        &banned_pubkeys_post,
        response_json[0..],
    );
    const banned_pubkeys_response = try client.parseListBannedPubkeysResponse(
        banned_pubkeys_response_json,
        banned_pubkeys[0..],
        arena.allocator(),
    );
    try std.testing.expect(banned_pubkeys_response.result == .pubkeys);
    try std.testing.expectEqualStrings("spam", banned_pubkeys_response.result.pubkeys[0].reason.?);

    const blocked_ips_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listblockedips,
        &admin_secret,
        1_700_000_004,
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

    const banned_events_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listbannedevents,
        &admin_secret,
        1_700_000_005,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var banned_events_http = FakeHttp{
        .response_body = "{\"result\":[{\"id\":\"7777777777777777777777777777777777777777777777777777777777777777\",\"reason\":\"reviewed\"}],\"error\":null}",
    };
    const banned_events_response_json = try client.postPrepared(
        banned_events_http.client(),
        &banned_events_post,
        response_json[0..],
    );
    const banned_events_response = try client.parseListBannedEventsResponse(
        banned_events_response_json,
        banned_events[0..],
        arena.allocator(),
    );
    try std.testing.expect(banned_events_response.result == .events);
    try std.testing.expectEqualStrings("reviewed", banned_events_response.result.events[0].reason.?);

    const moderation_events_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listeventsneedingmoderation,
        &admin_secret,
        1_700_000_006,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var moderation_events_http = FakeHttp{
        .response_body = "{\"result\":[{\"id\":\"abababababababababababababababababababababababababababababababab\",\"reason\":\"reported\"}],\"error\":null}",
    };
    const moderation_events_response_json = try client.postPrepared(
        moderation_events_http.client(),
        &moderation_events_post,
        response_json[0..],
    );
    const moderation_events_response = try client.parseListEventsNeedingModerationResponse(
        moderation_events_response_json,
        moderation_events[0..],
        arena.allocator(),
    );
    try std.testing.expect(moderation_events_response.result == .events);
    try std.testing.expectEqualStrings("reported", moderation_events_response.result.events[0].reason.?);

    const pubkey = [_]u8{0x11} ** 32;
    const allowpubkey_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .allowpubkey = .{ .pubkey = pubkey, .reason = "operator" } },
        &admin_secret,
        1_700_000_007,
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

    const unallowpubkey_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .unallowpubkey = .{ .pubkey = pubkey, .reason = "cleanup" } },
        &admin_secret,
        1_700_000_008,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const unallowpubkey_response_json = try client.postPrepared(
        allowpubkey_http.client(),
        &unallowpubkey_post,
        response_json[0..],
    );
    const unallowpubkey_response = try client.parseUnallowPubkeyResponse(
        unallowpubkey_response_json,
        arena.allocator(),
    );
    try std.testing.expect(unallowpubkey_response.result == .ack);

    const allowkind_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .allowkind = 1984 },
        &admin_secret,
        1_700_000_009,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var ack_http = FakeHttp{ .response_body = "{\"result\":true,\"error\":null}" };
    const ack_response_json = try client.postPrepared(ack_http.client(), &allowkind_post, response_json[0..]);
    const ack_response = try client.parseAllowKindResponse(ack_response_json, arena.allocator());
    try std.testing.expect(ack_response.result == .ack);

    const disallowkind_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .disallowkind = 1984 },
        &admin_secret,
        1_700_000_010,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const disallowkind_response_json = try client.postPrepared(
        ack_http.client(),
        &disallowkind_post,
        response_json[0..],
    );
    const disallowkind_response = try client.parseDisallowKindResponse(
        disallowkind_response_json,
        arena.allocator(),
    );
    try std.testing.expect(disallowkind_response.result == .ack);

    const blockip_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .blockip = .{ .ip = "198.51.100.42", .reason = "manual" } },
        &admin_secret,
        1_700_000_011,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const blockip_response_json = try client.postPrepared(ack_http.client(), &blockip_post, response_json[0..]);
    const blockip_response = try client.parseBlockIpResponse(blockip_response_json, arena.allocator());
    try std.testing.expect(blockip_response.result == .ack);

    const unblockip_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .unblockip = "198.51.100.42" },
        &admin_secret,
        1_700_000_012,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const unblockip_response_json = try client.postPrepared(
        ack_http.client(),
        &unblockip_post,
        response_json[0..],
    );
    const unblockip_response = try client.parseUnblockIpResponse(
        unblockip_response_json,
        arena.allocator(),
    );
    try std.testing.expect(unblockip_response.result == .ack);

    const ban_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .banpubkey = .{ .pubkey = pubkey, .reason = "spam" } },
        &admin_secret,
        1_700_000_013,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const ban_response_json = try client.postPrepared(ack_http.client(), &ban_post, response_json[0..]);
    const ban_response = try client.parseBanPubkeyResponse(ban_response_json, arena.allocator());
    try std.testing.expect(ban_response.result == .ack);

    const event_id = [_]u8{0x33} ** 32;
    const banevent_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .banevent = .{ .id = event_id, .reason = "malware" } },
        &admin_secret,
        1_700_000_014,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const banevent_response_json = try client.postPrepared(ack_http.client(), &banevent_post, response_json[0..]);
    const banevent_response = try client.parseBanEventResponse(banevent_response_json, arena.allocator());
    try std.testing.expect(banevent_response.result == .ack);

    const allowevent_post = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .allowevent = .{ .id = event_id, .reason = "manual-review" } },
        &admin_secret,
        1_700_000_015,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    const allowevent_response_json = try client.postPrepared(ack_http.client(), &allowevent_post, response_json[0..]);
    const allowevent_response = try client.parseAllowEventResponse(allowevent_response_json, arena.allocator());
    try std.testing.expect(allowevent_response.result == .ack);
}
