const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Command-ready signer pubkey flow: the caller explicitly establishes one signer session, handles
// one auth gate if needed, then sends one get_public_key request and feeds one response back.
test "recipe: signer pubkey job stays explicit after connect and across auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = noztr_sdk.client.signer.pubkey_job.SignerPubkeyJobClientStorage{};
    var client = try noztr_sdk.client.signer.pubkey_job.SignerPubkeyJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());
    try client.noteCurrentRelayAuthChallenge(&storage, "challenge-2");

    const secret_key = [_]u8{0x42} ** 32;
    var auth_storage = noztr_sdk.client.signer.pubkey_job.SignerPubkeyJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const first_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_scratch.allocator(),
        &secret_key,
        90,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(
        &storage,
        &first_ready.authenticate,
        95,
        60,
        arena.allocator(),
    );
    try std.testing.expect(auth_result == .authenticated);

    var pubkey_scratch_storage: [1024]u8 = undefined;
    var pubkey_scratch = std.heap.FixedBufferAllocator.init(&pubkey_scratch_storage);
    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        pubkey_scratch.allocator(),
        &secret_key,
        90,
    );
    try std.testing.expect(second_ready == .pubkey);
    try std.testing.expect(
        std.mem.indexOf(u8, second_ready.pubkey.json, "\"method\":\"get_public_key\"") != null,
    );

    const user_pubkey = [_]u8{0x33} ** 32;
    const user_pubkey_hex = std.fmt.bytesToHex(user_pubkey, .lower);
    var response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const pubkey_result = try client.acceptPubkeyResponseJson(
        try textResponse(response_storage[0..], "signer-2", user_pubkey_hex[0..]),
        arena.allocator(),
    );
    try std.testing.expect(pubkey_result == .pubkey);
    try std.testing.expect(std.mem.eql(u8, &user_pubkey, &pubkey_result.pubkey));
}

fn establishSignerSession(
    signer: *noztr_sdk.client.signer.session.SignerClient,
    storage: *noztr_sdk.client.signer.session.SignerClientStorage,
    secret_text: []const u8,
    scratch: std.mem.Allocator,
) noztr_sdk.workflows.signer.remote.RemoteSignerError!void {
    signer.markCurrentRelayConnected();

    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try signer.beginConnect(storage, request_scratch.allocator(), &.{});

    var response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    _ = try signer.acceptResponseJson(
        try serializeResponseJson(response_storage[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = secret_text } },
        }),
        scratch,
    );
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) noztr_sdk.workflows.signer.remote.RemoteSignerError![]const u8 {
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
