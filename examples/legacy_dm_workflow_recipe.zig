const std = @import("std");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");

// Build one signed legacy kind-4 DM explicitly, serialize it once, then decrypt it through the
// workflow floor without inventing relay or polling policy.
test "recipe: legacy dm workflow builds and accepts one signed kind4 message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try common.derivePublicKey(&recipient_secret);

    const sender = noztr_sdk.workflows.LegacyDmSession.init(&sender_secret);
    var outbound_storage = noztr_sdk.workflows.LegacyDmOutboundStorage{};
    const prepared = try sender.buildDirectMessageEvent(&outbound_storage, &.{
        .recipient_pubkey = recipient_pubkey,
        .recipient_relay_hint = "wss://dm.example",
        .content = "legacy workflow recipe",
        .created_at = 44,
        .iv = [_]u8{0x55} ** 16,
    });

    var event_json_output: [1024]u8 = undefined;
    const event_json = try sender.serializeDirectMessageEventJson(
        event_json_output[0..],
        &prepared.event,
    );

    const recipient = noztr_sdk.workflows.LegacyDmSession.init(&recipient_secret);
    var plaintext_output: [4096]u8 = undefined;
    const outcome = try recipient.acceptDirectMessageEventJson(
        event_json,
        plaintext_output[0..],
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("legacy workflow recipe", outcome.plaintext);
    try std.testing.expectEqualStrings("wss://dm.example", outcome.message.recipient_relay_hint.?);
}
