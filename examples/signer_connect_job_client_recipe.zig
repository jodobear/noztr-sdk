const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");

// Command-ready signer connect flow: if the current relay is auth-gated the caller explicitly
// sends one AUTH event first, then sends one connect request and feeds one connect response back.
test "recipe: signer connect job stays explicit across auth and connect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=secret";
    var storage = noztr_sdk.client.SignerConnectJobClientStorage{};
    var client = try noztr_sdk.client.SignerConnectJobClient.initFromBunkerUriText(
        .{},
        &storage,
        bunker_uri,
        arena.allocator(),
    );
    client.markCurrentRelayConnected();
    try client.noteCurrentRelayAuthChallenge(&storage, "challenge-1");

    const secret_key = [_]u8{0x41} ** 32;
    var auth_storage = noztr_sdk.client.SignerConnectJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var connect_scratch_storage: [1024]u8 = undefined;
    var connect_scratch = std.heap.FixedBufferAllocator.init(&connect_scratch_storage);
    const first_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        connect_scratch.allocator(),
        &secret_key,
        90,
        &.{.{ .method = .get_public_key }},
    );
    try std.testing.expect(first_ready == .authenticate);
    try std.testing.expect(std.mem.startsWith(u8, first_ready.authenticate.auth_message_json, "[\"AUTH\","));

    const auth_result = try client.acceptPreparedAuthEvent(
        &storage,
        &first_ready.authenticate,
        95,
        60,
        arena.allocator(),
    );
    try std.testing.expect(auth_result == .authenticated);

    var request_scratch_storage: [1024]u8 = undefined;
    var request_scratch = std.heap.FixedBufferAllocator.init(&request_scratch_storage);
    const second_ready = try client.prepareJob(
        &storage,
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        request_scratch.allocator(),
        &secret_key,
        90,
        &.{.{ .method = .get_public_key }},
    );
    try std.testing.expect(second_ready == .connect);
    try std.testing.expect(
        std.mem.indexOf(u8, second_ready.connect.json, "\"method\":\"connect\"") != null,
    );

    var response_storage: [noztr.limits.nip46_message_json_bytes_max]u8 = undefined;
    var response_scratch_storage: [2048]u8 = undefined;
    var response_scratch = std.heap.FixedBufferAllocator.init(&response_scratch_storage);
    const connect_result = try client.acceptConnectResponseJson(
        try serializeResponseJson(response_storage[0..], .{
            .id = "signer-1",
            .result = .{ .value = .{ .text = "secret" } },
        }),
        response_scratch.allocator(),
    );
    try std.testing.expect(connect_result == .connected);
    try std.testing.expect(client.isConnected());

    const runtime_plan = client.inspectRelayRuntime(&storage);
    try std.testing.expectEqual(@as(u8, 1), runtime_plan.ready_count);
}

fn serializeResponseJson(
    output: []u8,
    response: noztr.nip46_remote_signing.Response,
) noztr.nip46_remote_signing.RemoteSigningError![]const u8 {
    return noztr.nip46_remote_signing.message_serialize_json(output, .{ .response = response });
}
