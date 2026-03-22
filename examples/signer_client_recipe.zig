const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Explicit client-layer `NIP-46` flow: connect, later signer requests, durable resume export, and
// explicit shared relay/session policy all stay caller-driven.
test "recipe: signer client stays explicit from connect to get_public_key and nip44_encrypt" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two&secret=secret";
    var client = try noztr_sdk.client.signer.session.SignerClient.initFromBunkerUriText(
        .{},
        bunker_uri,
        arena.allocator(),
    );
    client.markCurrentRelayConnected();

    var storage = noztr_sdk.client.signer.session.SignerClientStorage{};

    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    const outbound_connect = try client.beginConnect(
        &storage,
        connect_scratch.allocator(),
        &.{.{ .method = .get_public_key }},
    );
    try std.testing.expectEqualStrings("wss://relay.one", outbound_connect.relay_url);
    try std.testing.expect(std.mem.indexOf(u8, outbound_connect.json, "\"method\":\"connect\"") != null);

    var connect_response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var connect_response_scratch_storage: [2048]u8 = undefined;
    var connect_response_scratch =
        std.heap.FixedBufferAllocator.init(&connect_response_scratch_storage);
    const connect_outcome = try client.acceptResponseJson(
        try textResponse(connect_response_storage[0..], "signer-1", "secret"),
        connect_response_scratch.allocator(),
    );
    try std.testing.expect(connect_outcome == .connected);
    try std.testing.expect(client.isConnected());

    var get_pubkey_scratch_storage: [1024]u8 = undefined;
    var get_pubkey_scratch = std.heap.FixedBufferAllocator.init(&get_pubkey_scratch_storage);
    const outbound_get_pubkey = try client.beginGetPublicKey(
        &storage,
        get_pubkey_scratch.allocator(),
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_get_pubkey.json, "\"method\":\"get_public_key\"") != null,
    );

    const user_pubkey = [_]u8{0x11} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var get_pubkey_response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var get_pubkey_response_scratch_storage: [2048]u8 = undefined;
    var get_pubkey_response_scratch =
        std.heap.FixedBufferAllocator.init(&get_pubkey_response_scratch_storage);
    const get_pubkey_outcome = try client.acceptResponseJson(
        try textResponse(get_pubkey_response_storage[0..], "signer-2", user_pubkey_hex[0..]),
        get_pubkey_response_scratch.allocator(),
    );

    try std.testing.expect(get_pubkey_outcome == .user_pubkey);
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &get_pubkey_outcome.user_pubkey));
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &client.getUserPubkey().?));

    const peer_pubkey = [_]u8{0x22} ** 32;
    var nip44_scratch_storage: [1024]u8 = undefined;
    var nip44_scratch = std.heap.FixedBufferAllocator.init(&nip44_scratch_storage);
    const outbound_nip44_encrypt = try client.beginNip44Encrypt(
        &storage,
        nip44_scratch.allocator(),
        &.{
            .pubkey = peer_pubkey,
            .text = "hello",
        },
    );
    try std.testing.expect(
        std.mem.indexOf(u8, outbound_nip44_encrypt.json, "\"method\":\"nip44_encrypt\"") != null,
    );

    var nip44_response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var nip44_response_scratch_storage: [2048]u8 = undefined;
    var nip44_response_scratch =
        std.heap.FixedBufferAllocator.init(&nip44_response_scratch_storage);
    const nip44_outcome = try client.acceptResponseJson(
        try textResponse(nip44_response_storage[0..], "signer-3", "ciphertext"),
        nip44_response_scratch.allocator(),
    );

    try std.testing.expect(nip44_outcome == .text_response);
    try std.testing.expectEqual(.nip44_encrypt, nip44_outcome.text_response.method);
    try std.testing.expectEqualStrings("ciphertext", nip44_outcome.text_response.text);

    const runtime_plan = client.inspectRelayRuntime(&storage);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.connect_count);

    const relay_two_step = noztr_sdk.runtime.RelayPoolStep{
        .entry = runtime_plan.entry(1).?,
    };
    const selected_relay = try client.selectRelayRuntimeStep(&relay_two_step);
    try std.testing.expectEqualStrings("wss://relay.two", selected_relay);
    try std.testing.expectEqualStrings("wss://relay.two", client.currentRelayUrl());
    try std.testing.expect(!client.isConnected());

    var resume_storage = noztr_sdk.client.signer.session.SignerClientResumeStorage{};
    const resume_state = try client.exportResumeState(&resume_storage);

    var restored = try noztr_sdk.client.signer.session.SignerClient.initFromBunkerUriText(
        .{},
        bunker_uri,
        arena.allocator(),
    );
    try restored.restoreResumeState(&resume_state);
    try std.testing.expectEqualStrings("wss://relay.two", restored.currentRelayUrl());

    const cadence = restored.inspectSessionCadence(.{
        .now_unix_seconds = 10,
        .reconnect_not_before_unix_seconds = 20,
    });
    try std.testing.expect(cadence.nextStep() == .wait);
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) noztr.nip46_remote_signing.RemoteSigningError![]const u8 {
    return serializeResponseJson(output, .{
        .id = id,
        .result = .{ .value = .{ .text = text } },
    });
}

fn serializeResponseJson(
    output: []u8,
    response: noztr.nip46_remote_signing.Response,
) noztr.nip46_remote_signing.RemoteSigningError![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(output, .{ .response = response });
}
