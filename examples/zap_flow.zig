const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

test "recipe: zap flow uses explicit publish and http callback seams" {
    var storage = noztr_sdk.workflows.zaps.ZapFlowStorage{};
    var flow = noztr_sdk.workflows.zaps.ZapFlow.init(.{}, &storage);

    const relay = try flow.addRelay("wss://relay.one");
    try flow.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x83} ** 32;
    const recipient = [_]u8{0x57} ** 32;
    var draft_storage = noztr_sdk.workflows.zaps.ZapRequestDraftStorage{};
    var event_json: [1024]u8 = undefined;
    const prepared = try flow.prepareZapRequestPublish(
        event_json[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .receipt_relays = &.{"wss://relay.one"},
            .recipient_pubkey = recipient,
            .amount_msats = 1000,
            .pay_request_url = "https://wallet.example/pay",
        },
    );

    var relays: [2][]const u8 = undefined;
    _ = try flow.inspectZapRequestEvent(&prepared.event, relays[0..]);

    var publish_storage = noztr_sdk.runtime.RelayPoolPublishStorage{};
    const publish_plan = flow.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_request_json: [2048]u8 = undefined;
    const targeted_publish = try flow.composeTargetedPublish(
        publish_request_json[0..],
        &publish_step,
        &prepared,
    );
    try std.testing.expect(targeted_publish.event_message_json.len > 0);

    const FakeHttp = struct {
        body: []const u8,

        fn client(self: *@This()) noztr_sdk.transport.HttpClient {
            return .{ .ctx = self, .get_fn = get };
        }

        fn get(ctx: *anyopaque, _: noztr_sdk.transport.HttpRequest, out: []u8) noztr_sdk.transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.body.len], self.body);
            return out[0..self.body.len];
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var endpoint_http = FakeHttp{
        .body = "{\"callback\":\"https://wallet.example/callback\",\"allowsNostr\":true}",
    };
    var endpoint_body: [256]u8 = undefined;
    const endpoint = try flow.fetchPayEndpoint(endpoint_http.client(), .{
        .url = "https://wallet.example/pay",
        .storage = .init(endpoint_body[0..]),
        .scratch = arena.allocator(),
    });

    var invoice_http = FakeHttp{ .body = "{\"pr\":\"lnbc10u1example\"}" };
    var callback_url_buffer: [1024]u8 = undefined;
    var callback_body: [256]u8 = undefined;
    _ = try flow.fetchInvoice(invoice_http.client(), .{
        .endpoint = endpoint,
        .amount_msats = 1000,
        .zap_request_json = prepared.event_json,
        .pay_request_url = "https://wallet.example/pay",
        .storage = .init(callback_url_buffer[0..], callback_body[0..]),
        .scratch = arena.allocator(),
    });
}
