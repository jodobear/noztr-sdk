const std = @import("std");
const noztr_sdk = @import("noztr_sdk");
const noztr = @import("noztr");

const ReceiptFixtureStorage = struct {
    tags: [4]noztr.nip01_event.EventTag = undefined,
    builders: [4]noztr.nip57_zaps.TagBuilder = undefined,
    recipient_pubkey_hex: [64]u8 = undefined,
    sender_pubkey_hex: [64]u8 = undefined,
};

fn buildReceiptEvent(
    receipt_signer_secret_key: *const [32]u8,
    request_json: []const u8,
    recipient_pubkey: [32]u8,
    sender_pubkey: [32]u8,
    storage: *ReceiptFixtureStorage,
    scratch: std.mem.Allocator,
) !noztr.nip01_event.Event {
    var tag_count: usize = 0;
    const recipient_pubkey_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    @memcpy(storage.recipient_pubkey_hex[0..], recipient_pubkey_hex[0..]);
    storage.tags[tag_count] = try noztr.nip57_zaps.zap_build_pubkey_tag(
        &storage.builders[tag_count],
        "p",
        storage.recipient_pubkey_hex[0..],
    );
    tag_count += 1;

    const sender_pubkey_hex = std.fmt.bytesToHex(sender_pubkey, .lower);
    @memcpy(storage.sender_pubkey_hex[0..], sender_pubkey_hex[0..]);
    storage.tags[tag_count] = try noztr.nip57_zaps.zap_build_pubkey_tag(
        &storage.builders[tag_count],
        "P",
        storage.sender_pubkey_hex[0..],
    );
    tag_count += 1;

    storage.tags[tag_count] = try noztr.nip57_zaps.receipt_build_bolt11_tag(
        &storage.builders[tag_count],
        "lnbc10u1example",
    );
    tag_count += 1;

    storage.tags[tag_count] = try noztr.nip57_zaps.receipt_build_description_tag(
        &storage.builders[tag_count],
        request_json,
        scratch,
    );
    tag_count += 1;

    const receipt_signer_pubkey = try noztr.nostr_keys.nostr_derive_public_key(receipt_signer_secret_key);
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = receipt_signer_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip57_zaps.zap_receipt_kind,
        .created_at = 101,
        .content = "",
        .tags = storage.tags[0..tag_count],
    };
    try noztr.nostr_keys.nostr_sign_event(receipt_signer_secret_key, &event);
    return event;
}

test "recipe: zap flow uses explicit publish callback and receipt-validation seams" {
    var storage = noztr_sdk.workflows.zaps.ZapFlowStorage{};
    var flow = noztr_sdk.workflows.zaps.ZapFlow.init(.{}, &storage);

    const relay = try flow.addRelay("wss://relay.one");
    try flow.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x83} ** 32;
    const receipt_signer_secret_key = [_]u8{0x84} ** 32;
    const receipt_signer_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&receipt_signer_secret_key);
    const recipient = [_]u8{0x57} ** 32;
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
        .body = try std.fmt.allocPrint(
            arena.allocator(),
            "{{\"callback\":\"https://wallet.example/callback\",\"allowsNostr\":true,\"nostrPubkey\":\"{s}\"}}",
            .{std.fmt.bytesToHex(receipt_signer_pubkey, .lower)},
        ),
    };
    var endpoint_body: [256]u8 = undefined;
    const endpoint = try flow.fetchPayEndpoint(endpoint_http.client(), .{
        .url = "https://wallet.example/pay",
        .storage = .init(endpoint_body[0..]),
        .scratch = arena.allocator(),
    });
    try std.testing.expect(endpoint.receipt_signer_pubkey != null);

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
            .lnurl = "lnurl1dp68gurn8ghj7m",
            .receipt_signer_pubkey = endpoint.receipt_signer_pubkey.?,
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

    var request_validation_relays: [2][]const u8 = undefined;
    const receipt_validation = try flow.prepareReceiptValidationContext(
        endpoint,
        &prepared.event,
        1000,
        request_validation_relays[0..],
    );

    var invoice_http = FakeHttp{ .body = "{\"pr\":\"lnbc10u1example\"}" };
    var callback_url_buffer: [2048]u8 = undefined;
    var callback_body: [256]u8 = undefined;
    _ = try flow.fetchInvoice(invoice_http.client(), .{
        .endpoint = endpoint,
        .amount_msats = 1000,
        .zap_request_json = prepared.event_json,
        .lnurl = "lnurl1dp68gurn8ghj7m",
        .storage = .init(callback_url_buffer[0..], callback_body[0..]),
        .scratch = arena.allocator(),
    });

    var receipt_storage = ReceiptFixtureStorage{};
    const request_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    const receipt_event = try buildReceiptEvent(
        &receipt_signer_secret_key,
        prepared.event_json,
        recipient,
        request_pubkey,
        &receipt_storage,
        arena.allocator(),
    );
    var receipt_relays: [2][]const u8 = undefined;
    const receipt = try flow.validateReceiptForContext(
        &receipt_event,
        receipt_validation,
        receipt_relays[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(prepared.event.id, receipt.request.id);
}
