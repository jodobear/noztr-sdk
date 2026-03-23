const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Shared signer capability route: the same request vocabulary can be driven through local,
// remote, and browser signer adapters while preserving the real backend differences.
test "recipe: signer capability adapters stay explicit across local remote and browser signers" {
    const local = noztr_sdk.client.local.operator.LocalOperatorClient.init(.{});
    const local_capability = local.signerCapabilityProfile();
    const author_secret = [_]u8{0x11} ** 32;

    const get_public_key_request: noztr_sdk.client.signer.capability.SignerOperationRequest = .{
        .get_public_key = {},
    };
    try std.testing.expectEqual(.local_immediate, get_public_key_request.modeIn(&local_capability));

    var local_output: [512]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const local_pubkey_result = try local.completeSignerCapabilityOperation(
        local_output[0..],
        &author_secret,
        &get_public_key_request,
        arena.allocator(),
    );
    try std.testing.expect(get_public_key_request.acceptsResult(&local_pubkey_result));

    var unsigned_event = local.buildUnsignedEvent(
        &.{
            .kind = 1,
            .created_at = 42,
            .content = "sign me locally",
        },
        &local_pubkey_result.user_pubkey,
    );
    var unsigned_event_json_output: [512]u8 = undefined;
    const unsigned_event_json = try local.serializeEventJson(unsigned_event_json_output[0..], &unsigned_event);
    const sign_event_request: noztr_sdk.client.signer.capability.SignerOperationRequest = .{
        .sign_event = unsigned_event_json,
    };
    const local_sign_result = try local.completeSignerCapabilityOperation(
        local_output[0..],
        &author_secret,
        &sign_event_request,
        arena.allocator(),
    );
    try std.testing.expect(sign_event_request.acceptsResult(&local_sign_result));

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var remote = try noztr_sdk.client.signer.session.SignerClient.initFromBunkerUriText(
        .{},
        bunker_uri,
        arena.allocator(),
    );
    remote.markCurrentRelayConnected();
    const remote_capability = remote.signerCapabilityProfile();
    try std.testing.expectEqual(.caller_driven_request, sign_event_request.modeIn(&remote_capability));

    var remote_storage = noztr_sdk.client.signer.session.SignerClientStorage{};
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    _ = try remote.beginConnect(&remote_storage, connect_scratch.allocator(), &.{});

    var connect_response_json_output: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const connect_response_json = try noztr.nip46_remote_signing.message_serialize_json(
        connect_response_json_output[0..],
        .{ .response = .{
            .id = "signer-1",
            .result = .{ .text = "secret" },
        } },
    );
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch = std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    _ = try remote.acceptResponseJson(
        connect_response_json,
        connect_response_scratch.allocator(),
    );

    var remote_scratch_storage: [1024]u8 = undefined;
    var remote_scratch = std.heap.FixedBufferAllocator.init(&remote_scratch_storage);
    const outbound = try remote.beginSignerCapabilityOperation(
        &remote_storage,
        remote_scratch.allocator(),
        &get_public_key_request,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound.json, "\"method\":\"get_public_key\"") != null,
    );

    const remote_pubkey = [_]u8{0x44} ** 32;
    const remote_pubkey_hex = std.fmt.bytesToHex(remote_pubkey, .lower);
    var response_json_output: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const response_json = try noztr.nip46_remote_signing.message_serialize_json(
        response_json_output[0..],
        .{ .response = .{
            .id = "signer-2",
            .result = .{ .text = remote_pubkey_hex[0..] },
        } },
    );
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const remote_result = try remote.acceptSignerCapabilityResponseJson(
        response_json,
        response_scratch.allocator(),
    );
    try std.testing.expect(get_public_key_request.acceptsResult(&remote_result));

    const FakeBrowser = struct {
        support: noztr_sdk.client.signer.browser.Nip07BrowserSupport,
    };
    const fake_browser_vtable = noztr_sdk.client.signer.browser.Nip07BrowserProvider.VTable{
        .inspectSupport = struct {
            fn call(
                context: *const anyopaque,
            ) noztr_sdk.client.signer.browser.Nip07BrowserSupport {
                const typed: *const FakeBrowser = @ptrCast(@alignCast(context));
                return typed.support;
            }
        }.call,
        .completeOperation = struct {
            fn call(
                context: *const anyopaque,
                output: []u8,
                request: *const noztr_sdk.client.signer.capability.SignerOperationRequest,
            ) noztr_sdk.client.signer.browser.Nip07BrowserError![]const u8 {
                _ = context;
                return switch (request.*) {
                    .get_public_key => std.fmt.bufPrint(output, "{s}", .{
                        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    }) catch unreachable,
                    .sign_event => |unsigned_browser_event_json| std.fmt.bufPrint(output, "{s}", .{
                        unsigned_browser_event_json,
                    }) catch unreachable,
                    .nip04_encrypt,
                    .nip04_decrypt,
                    .nip44_encrypt,
                    .nip44_decrypt,
                    => std.fmt.bufPrint(output, "{s}", .{"text"}) catch unreachable,
                };
            }
        }.call,
    };
    const fake_browser = FakeBrowser{
        .support = .{
            .availability = .present,
            .methods = .{
                .get_public_key = true,
                .sign_event = true,
                .nip44_encrypt = true,
                .nip44_decrypt = true,
            },
        },
    };
    const browser = noztr_sdk.client.signer.browser.Nip07BrowserProvider.init(
        &fake_browser,
        &fake_browser_vtable,
    );
    const browser_capability = browser.signerCapabilityProfile();
    try std.testing.expectEqual(.caller_driven_request, get_public_key_request.modeIn(&browser_capability));
    const browser_result = try browser.completeSignerCapabilityOperation(
        local_output[0..],
        &get_public_key_request,
    );
    try std.testing.expect(get_public_key_request.acceptsResult(&browser_result));
}
