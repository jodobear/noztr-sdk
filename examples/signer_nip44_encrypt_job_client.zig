const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Command-ready signer nip44_encrypt flow: the caller explicitly establishes one signer session,
// handles one auth gate if needed, then sends one nip44_encrypt request and feeds one text
// response back.
test "recipe: signer nip44 encrypt job stays explicit after connect and across auth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = noztr_sdk.client.signer.nip44_encrypt_job.Storage{};
    var client = try noztr_sdk.client.signer.nip44_encrypt_job.Client.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    try establishSignerSession(&client.signer, &storage.signer, "secret", arena.allocator());
    try client.noteCurrentRelayAuthChallenge(&storage, "challenge-3");

    const secret_key = [_]u8{0x43} ** 32;
    const peer_pubkey = [_]u8{0x66} ** 32;
    var auth_storage = noztr_sdk.client.signer.nip44_encrypt_job.AuthEventStorage{};
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
        &.{ .pubkey = peer_pubkey, .text = "hello" },
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

    var encrypt_scratch_storage: [1024]u8 = undefined;
    var encrypt_scratch = std.heap.FixedBufferAllocator.init(&encrypt_scratch_storage);
    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        encrypt_scratch.allocator(),
        &secret_key,
        &.{ .pubkey = peer_pubkey, .text = "hello" },
        90,
    );
    try std.testing.expect(second_ready == .encrypt);
    try std.testing.expect(
        std.mem.indexOf(u8, second_ready.encrypt.json, "\"method\":\"nip44_encrypt\"") != null,
    );

    var response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    const encrypt_result = try client.acceptEncryptResponseJson(
        try textResponse(response_storage[0..], "signer-2", "ciphertext"),
        arena.allocator(),
    );
    try std.testing.expect(encrypt_result == .ciphertext);
    try std.testing.expectEqualStrings("ciphertext", encrypt_result.ciphertext);
}

fn establishSignerSession(
    signer: *noztr_sdk.client.signer.session.Client,
    storage: *noztr_sdk.client.signer.session.Storage,
    secret_text: []const u8,
    scratch: std.mem.Allocator,
) noztr_sdk.workflows.signer.remote.Error!void {
    signer.markCurrentRelayConnected();

    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    _ = try signer.beginConnect(storage, request_scratch.allocator(), &.{});

    var response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    _ = try signer.acceptResponseJson(
        try serializeResponseJson(response_storage[0..], .{
            .id = "signer-1",
            .result = .{ .text = secret_text },
        }),
        scratch,
    );
}

fn textResponse(
    output: []u8,
    id: []const u8,
    text: []const u8,
) noztr_sdk.workflows.signer.remote.Error![]const u8 {
    return serializeResponseJson(output, .{
        .id = id,
        .result = .{ .text = text },
    });
}

fn serializeResponseJson(
    output: []u8,
    response: noztr.nip46_remote_signing.Response,
) noztr.nip46_remote_signing.RemoteSigningError![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(output, .{ .response = response });
}
