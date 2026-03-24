const std = @import("std");
const local_operator = @import("../client/local_operator_client.zig");
const publish_client = @import("../client/publish_client.zig");
const runtime = @import("../runtime/mod.zig");
const transport = @import("../transport/mod.zig");
const noztr = @import("noztr");

pub const Error =
    publish_client.PublishClientError ||
    transport.HttpError ||
    noztr.nip57_zaps.ZapError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    error{
        ZapDraftStorageTooSmall,
        InvalidPayEndpoint,
        AmountOutsideEndpointRange,
        MissingCallbackUrl,
        InvalidReceiptSignerPubkey,
        CallbackUrlTooSmall,
        MissingInvoice,
        InvalidInvoiceResponse,
    };

pub const ZapFlowConfig = struct {
    publish: publish_client.PublishClientConfig = .{},
};

pub const ZapFlowStorage = struct {
    publish: publish_client.PublishClientStorage = .{},
};

pub const ZapRequestDraft = struct {
    created_at: u64,
    receipt_relays: []const []const u8,
    recipient_pubkey: [32]u8,
    amount_msats: ?u64 = null,
    lnurl: ?[]const u8 = null,
    event_id: ?[32]u8 = null,
    coordinate: ?Coordinate = null,
    target_kind: ?u32 = null,
    receipt_signer_pubkey: ?[32]u8 = null,
    content: []const u8 = "",
};

pub const Coordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
};

pub const ZapRequestDraftStorage = struct {
    tags: [8]noztr.nip01_event.EventTag = undefined,
    builders: [8]noztr.nip57_zaps.TagBuilder = undefined,
    coordinate_items: [2][]const u8 = undefined,
    recipient_pubkey_hex: [64]u8 = undefined,
    receipt_signer_pubkey_hex: [64]u8 = undefined,
    event_id_hex: [64]u8 = undefined,
    coordinate_text: [noztr.limits.tag_item_bytes_max]u8 = undefined,
};

pub const PayEndpointFetchStorage = struct {
    body_buffer: []u8,

    pub fn init(body_buffer: []u8) PayEndpointFetchStorage {
        return .{ .body_buffer = body_buffer };
    }
};

pub const PayEndpointFetchRequest = struct {
    url: []const u8,
    storage: PayEndpointFetchStorage,
    scratch: std.mem.Allocator,
};

pub const PayEndpoint = struct {
    callback_url: []const u8,
    allows_nostr: bool = false,
    receipt_signer_pubkey: ?[32]u8 = null,
    min_sendable_msats: ?u64 = null,
    max_sendable_msats: ?u64 = null,
};

pub const InvoiceFetchStorage = struct {
    url_buffer: []u8,
    body_buffer: []u8,

    pub fn init(url_buffer: []u8, body_buffer: []u8) InvoiceFetchStorage {
        return .{ .url_buffer = url_buffer, .body_buffer = body_buffer };
    }
};

pub const InvoiceFetchRequest = struct {
    endpoint: PayEndpoint,
    amount_msats: u64,
    zap_request_json: []const u8,
    lnurl: ?[]const u8 = null,
    storage: InvoiceFetchStorage,
    scratch: std.mem.Allocator,
};

pub const InvoiceResult = struct {
    invoice: []const u8,
    verify_url: ?[]const u8 = null,
};

pub const ZapFlow = struct {
    config: ZapFlowConfig,
    publish: publish_client.PublishClient,

    pub fn init(config: ZapFlowConfig, storage: *ZapFlowStorage) ZapFlow {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
        };
    }

    pub fn attach(config: ZapFlowConfig, storage: *ZapFlowStorage) ZapFlow {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
        };
    }

    pub fn addRelay(self: *ZapFlow, relay_url_text: []const u8) Error!runtime.RelayDescriptor {
        return self.publish.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(self: *ZapFlow, relay_index: u8) Error!void {
        try self.publish.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(self: *ZapFlow, relay_index: u8) Error!void {
        try self.publish.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *ZapFlow,
        relay_index: u8,
        challenge: []const u8,
    ) Error!void {
        try self.publish.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const ZapFlow,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.publish.inspectRelayRuntime(storage);
    }

    pub fn inspectPublish(
        self: *const ZapFlow,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.publish.inspectPublish(storage);
    }

    pub fn buildZapRequestDraft(
        _: ZapFlow,
        storage: *ZapRequestDraftStorage,
        draft: *const ZapRequestDraft,
    ) Error!local_operator.LocalEventDraft {
        var tag_count: usize = 0;
        const recipient_hex = std.fmt.bytesToHex(draft.recipient_pubkey, .lower);
        @memcpy(storage.recipient_pubkey_hex[0..], recipient_hex[0..]);
        storage.tags[tag_count] = try noztr.nip57_zaps.zap_build_pubkey_tag(
            &storage.builders[tag_count],
            "p",
            storage.recipient_pubkey_hex[0..],
        );
        tag_count += 1;

        storage.tags[tag_count] = try noztr.nip57_zaps.request_build_relays_tag(
            &storage.builders[tag_count],
            draft.receipt_relays,
        );
        tag_count += 1;

        if (draft.amount_msats) |amount_msats| {
            storage.tags[tag_count] = try noztr.nip57_zaps.request_build_amount_tag(
                &storage.builders[tag_count],
                amount_msats,
            );
            tag_count += 1;
        }
        if (draft.lnurl) |lnurl| {
            storage.tags[tag_count] = try noztr.nip57_zaps.request_build_lnurl_tag(
                &storage.builders[tag_count],
                lnurl,
            );
            tag_count += 1;
        }
        if (draft.event_id) |event_id| {
            const event_hex = std.fmt.bytesToHex(event_id, .lower);
            @memcpy(storage.event_id_hex[0..], event_hex[0..]);
            storage.tags[tag_count] = try noztr.nip57_zaps.zap_build_event_tag(
                &storage.builders[tag_count],
                storage.event_id_hex[0..],
            );
            tag_count += 1;
        }
        if (draft.coordinate) |coordinate| {
            try validateCoordinate(coordinate);
            const coordinate_text = try formatCoordinate(storage.coordinate_text[0..], coordinate);
            storage.coordinate_items[0] = "a";
            storage.coordinate_items[1] = coordinate_text;
            storage.tags[tag_count] = .{ .items = storage.coordinate_items[0..2] };
            tag_count += 1;
        }
        if (draft.target_kind) |target_kind| {
            storage.tags[tag_count] = try noztr.nip57_zaps.zap_build_kind_tag(
                &storage.builders[tag_count],
                target_kind,
            );
            tag_count += 1;
        }
        if (draft.receipt_signer_pubkey) |receipt_signer_pubkey| {
            const receipt_signer_hex = std.fmt.bytesToHex(receipt_signer_pubkey, .lower);
            @memcpy(storage.receipt_signer_pubkey_hex[0..], receipt_signer_hex[0..]);
            storage.tags[tag_count] = try noztr.nip57_zaps.zap_build_pubkey_tag(
                &storage.builders[tag_count],
                "P",
                storage.receipt_signer_pubkey_hex[0..],
            );
            tag_count += 1;
        }

        return .{
            .kind = noztr.nip57_zaps.zap_request_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..tag_count],
        };
    }

    pub fn prepareZapRequestPublish(
        self: ZapFlow,
        event_json_output: []u8,
        draft_storage: *ZapRequestDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const ZapRequestDraft,
    ) Error!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildZapRequestDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const ZapFlow,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) Error!publish_client.TargetedPublishEvent {
        return self.publish.composeTargetedPublish(output, step, prepared);
    }

    pub fn inspectZapRequestEvent(
        _: ZapFlow,
        event: *const noztr.nip01_event.Event,
        relays_out: [][]const u8,
    ) Error!noztr.nip57_zaps.ZapRequest {
        return noztr.nip57_zaps.zap_request_extract(event, relays_out);
    }

    pub fn validateZapRequestEvent(
        _: ZapFlow,
        event: *const noztr.nip01_event.Event,
        expected_amount_msats: ?u64,
        expected_receipt_signer_pubkey: ?[32]u8,
        relays_out: [][]const u8,
    ) Error!noztr.nip57_zaps.ZapRequest {
        return noztr.nip57_zaps.zap_request_validate(
            event,
            expected_amount_msats,
            expected_receipt_signer_pubkey,
            relays_out,
        );
    }

    pub fn inspectZapReceiptEvent(
        _: ZapFlow,
        event: *const noztr.nip01_event.Event,
        relays_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip57_zaps.ZapReceipt {
        return noztr.nip57_zaps.zap_receipt_extract(event, relays_out, scratch);
    }

    pub fn validateZapReceiptEvent(
        _: ZapFlow,
        event: *const noztr.nip01_event.Event,
        expected_receipt_signer_pubkey: [32]u8,
        relays_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip57_zaps.ZapReceipt {
        return noztr.nip57_zaps.zap_receipt_validate(
            event,
            expected_receipt_signer_pubkey,
            relays_out,
            scratch,
        );
    }

    pub fn fetchPayEndpoint(
        _: ZapFlow,
        http: transport.HttpClient,
        request: PayEndpointFetchRequest,
    ) Error!PayEndpoint {
        const response_body = try http.get(.{
            .url = request.url,
            .accept = "application/json",
        }, request.storage.body_buffer);
        return try parsePayEndpoint(response_body, request.scratch);
    }

    pub fn fetchInvoice(
        _: ZapFlow,
        http: transport.HttpClient,
        request: InvoiceFetchRequest,
    ) Error!InvoiceResult {
        if (!request.endpoint.allows_nostr) return error.InvalidPayEndpoint;
        if (request.endpoint.min_sendable_msats) |min_sendable_msats| {
            if (request.amount_msats < min_sendable_msats) return error.AmountOutsideEndpointRange;
        }
        if (request.endpoint.max_sendable_msats) |max_sendable_msats| {
            if (request.amount_msats > max_sendable_msats) return error.AmountOutsideEndpointRange;
        }
        const callback_url = try composeInvoiceRequestUrl(
            request.storage.url_buffer,
            request.endpoint.callback_url,
            request.amount_msats,
            request.zap_request_json,
            request.lnurl,
        );
        const response_body = try http.get(.{
            .url = callback_url,
            .accept = "application/json",
        }, request.storage.body_buffer);
        return try parseInvoiceResult(response_body, request.scratch);
    }
};

fn parsePayEndpoint(body: []const u8, scratch: std.mem.Allocator) Error!PayEndpoint {
    var endpoint = PayEndpoint{ .callback_url = "" };
    const root = std.json.parseFromSliceLeaky(std.json.Value, scratch, body, .{}) catch {
        return error.InvalidPayEndpoint;
    };
    if (root != .object) return error.InvalidPayEndpoint;

    var iterator = root.object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "callback")) {
            if (entry.value_ptr.* != .string) return error.InvalidPayEndpoint;
            endpoint.callback_url = entry.value_ptr.*.string;
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "allowsNostr")) {
            if (entry.value_ptr.* != .bool) return error.InvalidPayEndpoint;
            endpoint.allows_nostr = entry.value_ptr.*.bool;
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "nostrPubkey")) {
            if (entry.value_ptr.* != .string) return error.InvalidPayEndpoint;
            endpoint.receipt_signer_pubkey = parsePubkeyHex(entry.value_ptr.*.string) catch {
                return error.InvalidReceiptSignerPubkey;
            };
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "minSendable")) {
            endpoint.min_sendable_msats = parseJsonU64(entry.value_ptr.*) catch {
                return error.InvalidPayEndpoint;
            };
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "maxSendable")) {
            endpoint.max_sendable_msats = parseJsonU64(entry.value_ptr.*) catch {
                return error.InvalidPayEndpoint;
            };
        }
    }

    if (endpoint.callback_url.len == 0) return error.MissingCallbackUrl;
    if (endpoint.allows_nostr and endpoint.receipt_signer_pubkey == null) return error.InvalidPayEndpoint;
    return endpoint;
}

fn parseInvoiceResult(body: []const u8, scratch: std.mem.Allocator) Error!InvoiceResult {
    var result = InvoiceResult{ .invoice = "" };
    const root = std.json.parseFromSliceLeaky(std.json.Value, scratch, body, .{}) catch {
        return error.InvalidInvoiceResponse;
    };
    if (root != .object) return error.InvalidInvoiceResponse;

    var iterator = root.object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "pr")) {
            if (entry.value_ptr.* != .string) return error.InvalidInvoiceResponse;
            result.invoice = entry.value_ptr.*.string;
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "verify")) {
            if (entry.value_ptr.* != .string) return error.InvalidInvoiceResponse;
            result.verify_url = entry.value_ptr.*.string;
        }
    }

    if (result.invoice.len == 0) return error.MissingInvoice;
    return result;
}

fn composeInvoiceRequestUrl(
    output: []u8,
    callback_url: []const u8,
    amount_msats: u64,
    zap_request_json: []const u8,
    lnurl: ?[]const u8,
) Error![]const u8 {
    if (callback_url.len == 0) return error.MissingCallbackUrl;
    var cursor: usize = 0;
    if (callback_url.len >= output.len) return error.CallbackUrlTooSmall;
    @memcpy(output[0..callback_url.len], callback_url);
    cursor += callback_url.len;
    output[cursor] = if (std.mem.indexOfScalar(u8, callback_url, '?') == null) '?' else '&';
    cursor += 1;

    const amount_prefix = std.fmt.bufPrint(output[cursor..], "amount={d}&nostr=", .{amount_msats}) catch {
        return error.CallbackUrlTooSmall;
    };
    cursor += amount_prefix.len;
    cursor += try percentEncodeInto(output[cursor..], zap_request_json);
    if (lnurl) |encoded_lnurl| {
        if (cursor >= output.len) return error.CallbackUrlTooSmall;
        output[cursor] = '&';
        cursor += 1;
        const lnurl_prefix = "lnurl=";
        if (cursor + lnurl_prefix.len > output.len) return error.CallbackUrlTooSmall;
        @memcpy(output[cursor .. cursor + lnurl_prefix.len], lnurl_prefix);
        cursor += lnurl_prefix.len;
        cursor += try percentEncodeInto(output[cursor..], encoded_lnurl);
    }
    return output[0..cursor];
}

fn percentEncodeInto(output: []u8, input: []const u8) Error!usize {
    var cursor: usize = 0;
    for (input) |byte| {
        if (isUnreservedByte(byte)) {
            if (cursor >= output.len) return error.CallbackUrlTooSmall;
            output[cursor] = byte;
            cursor += 1;
            continue;
        }
        if (cursor + 3 > output.len) return error.CallbackUrlTooSmall;
        output[cursor] = '%';
        _ = std.fmt.bufPrint(output[cursor + 1 .. cursor + 3], "{X:0>2}", .{byte}) catch {
            return error.CallbackUrlTooSmall;
        };
        cursor += 3;
    }
    return cursor;
}

fn isUnreservedByte(byte: u8) bool {
    if (byte >= 'a' and byte <= 'z') return true;
    if (byte >= 'A' and byte <= 'Z') return true;
    if (byte >= '0' and byte <= '9') return true;
    return byte == '-' or byte == '_' or byte == '.' or byte == '~';
}

fn parseJsonU64(value: std.json.Value) error{Invalid}!u64 {
    return switch (value) {
        .integer => |integer| if (integer >= 0) @intCast(integer) else error.Invalid,
        .string => |text| std.fmt.parseInt(u64, text, 10) catch error.Invalid,
        else => error.Invalid,
    };
}

fn parsePubkeyHex(hex: []const u8) ![32]u8 {
    var out: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(out[0..], hex) catch return error.InvalidReceiptSignerPubkey;
    return out;
}

fn formatCoordinate(output: []u8, coordinate: Coordinate) Error![]const u8 {
    const pubkey_hex = std.fmt.bytesToHex(coordinate.pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{d}:{s}:{s}",
        .{ coordinate.kind, pubkey_hex[0..], coordinate.identifier },
    ) catch error.ZapDraftStorageTooSmall;
}

fn validateCoordinate(coordinate: Coordinate) noztr.nip57_zaps.ZapError!void {
    if (!std.unicode.utf8ValidateSlice(coordinate.identifier)) return error.InvalidCoordinateTag;

    const replaceable = coordinate.kind >= 10_000 and coordinate.kind < 20_000;
    const addressable = coordinate.kind >= 30_000 and coordinate.kind < 40_000;
    if (!replaceable and !addressable) return error.InvalidCoordinateTag;
    if (addressable and coordinate.identifier.len == 0) return error.InvalidCoordinateTag;
}

test "zap flow composes request publish and explicit HTTP-backed invoice fetch" {
    var storage = ZapFlowStorage{};
    var flow = ZapFlow.init(.{}, &storage);

    const relay = try flow.addRelay("wss://relay.one");
    try flow.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x71} ** 32;
    const target_pubkey = [_]u8{0x55} ** 32;
    const receipt_signer_pubkey = [_]u8{0x66} ** 32;
    var draft_storage = ZapRequestDraftStorage{};
    var request_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try flow.prepareZapRequestPublish(
        request_json_buffer[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 20,
            .receipt_relays = &.{"wss://relay.one"},
            .recipient_pubkey = target_pubkey,
            .amount_msats = 1000,
            .lnurl = "lnurl1dp68gurn8ghj7m",
            .event_id = [_]u8{0x77} ** 32,
            .coordinate = .{
                .kind = 30_023,
                .pubkey = target_pubkey,
                .identifier = "article",
            },
            .target_kind = 1,
            .receipt_signer_pubkey = receipt_signer_pubkey,
        },
    );

    var relays: [2][]const u8 = undefined;
    const request = try flow.validateZapRequestEvent(
        &prepared.event,
        1000,
        receipt_signer_pubkey,
        relays[0..],
    );
    try std.testing.expectEqual(@as(usize, 1), request.receipt_relays.len);
    try std.testing.expectEqualStrings("lnurl1dp68gurn8ghj7m", request.lnurl.?);

    const FakeHttp = struct {
        expected_url: []const u8,
        body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get };
        }

        fn get(ctx: *anyopaque, request_input: transport.HttpRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request_input.url, self.expected_url)) return error.NotFound;
            if (self.body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.body.len], self.body);
            return out[0..self.body.len];
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var pay_body: [256]u8 = undefined;
    const pay_json = try std.fmt.bufPrint(
        pay_body[0..],
        "{{\"callback\":\"https://wallet.example/callback\",\"allowsNostr\":true,\"nostrPubkey\":\"{s}\",\"minSendable\":1000,\"maxSendable\":100000}}",
        .{std.fmt.bytesToHex(receipt_signer_pubkey, .lower)},
    );
    var pay_http = FakeHttp{ .expected_url = "https://wallet.example/pay", .body = pay_json };
    var pay_fetch_body: [256]u8 = undefined;
    const endpoint = try flow.fetchPayEndpoint(pay_http.client(), .{
        .url = "https://wallet.example/pay",
        .storage = PayEndpointFetchStorage.init(pay_fetch_body[0..]),
        .scratch = arena.allocator(),
    });
    try std.testing.expect(endpoint.allows_nostr);
    try std.testing.expect(endpoint.receipt_signer_pubkey != null);

    var invoice_url_buffer: [2048]u8 = undefined;
    const expected_invoice_url = try composeInvoiceRequestUrl(
        invoice_url_buffer[0..],
        endpoint.callback_url,
        1000,
        prepared.event_json,
        "lnurl1dp68gurn8ghj7m",
    );
    var invoice_http = FakeHttp{
        .expected_url = expected_invoice_url,
        .body = "{\"pr\":\"lnbc10u1example\",\"verify\":\"https://wallet.example/verify\"}",
    };
    var callback_url_buffer: [2048]u8 = undefined;
    var callback_body_buffer: [256]u8 = undefined;
    const invoice = try flow.fetchInvoice(invoice_http.client(), .{
        .endpoint = endpoint,
        .amount_msats = 1000,
        .zap_request_json = prepared.event_json,
        .lnurl = "lnurl1dp68gurn8ghj7m",
        .storage = InvoiceFetchStorage.init(callback_url_buffer[0..], callback_body_buffer[0..]),
        .scratch = arena.allocator(),
    });
    try std.testing.expectEqualStrings("lnbc10u1example", invoice.invoice);
}

test "zap flow rejects invalid typed coordinate drafts" {
    var storage = ZapFlowStorage{};
    var flow = ZapFlow.init(.{}, &storage);

    const secret_key = [_]u8{0x72} ** 32;
    const target_pubkey = [_]u8{0x56} ** 32;
    var draft_storage = ZapRequestDraftStorage{};
    var request_json_buffer: [noztr.limits.event_json_max]u8 = undefined;

    try std.testing.expectError(
        error.InvalidCoordinateTag,
        flow.prepareZapRequestPublish(
            request_json_buffer[0..],
            &draft_storage,
            &secret_key,
            &.{
                .created_at = 21,
                .receipt_relays = &.{"wss://relay.one"},
                .recipient_pubkey = target_pubkey,
                .coordinate = .{
                    .kind = 30_023,
                    .pubkey = target_pubkey,
                    .identifier = "",
                },
            },
        ),
    );
}

test "zap flow rejects invoice fetch when endpoint does not allow nostr" {
    var storage = ZapFlowStorage{};
    const flow = ZapFlow.init(.{}, &storage);

    const FakeHttp = struct {
        fn client(_: *@This()) transport.HttpClient {
            return .{ .ctx = undefined, .get_fn = get };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
    };

    var fake = FakeHttp{};
    var callback_url_buffer: [128]u8 = undefined;
    var callback_body_buffer: [128]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidPayEndpoint,
        flow.fetchInvoice(fake.client(), .{
            .endpoint = .{ .callback_url = "https://wallet.example/callback", .allows_nostr = false },
            .amount_msats = 1000,
            .zap_request_json = "{}",
            .lnurl = "lnurl1dp68gurn8ghj7m",
            .storage = InvoiceFetchStorage.init(callback_url_buffer[0..], callback_body_buffer[0..]),
            .scratch = arena.allocator(),
        }),
    );
}

test "zap flow rejects invoice fetch outside advertised sendable range" {
    var storage = ZapFlowStorage{};
    const flow = ZapFlow.init(.{}, &storage);

    const FakeHttp = struct {
        fn client(_: *@This()) transport.HttpClient {
            return .{ .ctx = undefined, .get_fn = get };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
    };

    var fake = FakeHttp{};
    var callback_url_buffer: [128]u8 = undefined;
    var callback_body_buffer: [128]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.AmountOutsideEndpointRange,
        flow.fetchInvoice(fake.client(), .{
            .endpoint = .{
                .callback_url = "https://wallet.example/callback",
                .allows_nostr = true,
                .min_sendable_msats = 2000,
                .max_sendable_msats = 5000,
            },
            .amount_msats = 1000,
            .zap_request_json = "{}",
            .lnurl = "lnurl1dp68gurn8ghj7m",
            .storage = InvoiceFetchStorage.init(callback_url_buffer[0..], callback_body_buffer[0..]),
            .scratch = arena.allocator(),
        }),
    );
}
