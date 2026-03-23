const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Command-ready local event flow: sign one draft, verify that signed event, then inspect its JSON
// through one stable job layer above the local operator floor.
test "recipe: local event job client keeps inspect and sign work command-ready" {
    var storage = noztr_sdk.client.local.events.LocalEventJobClientStorage{};
    const client = noztr_sdk.client.local.events.LocalEventJobClient.init(.{}, &storage);
    const author_secret = [_]u8{0x11} ** 32;
    const draft = noztr_sdk.client.local.operator.LocalEventDraft{
        .kind = 1,
        .created_at = 42,
        .content = "local event job",
    };

    const signed = try client.runJob(
        &.{ .sign_draft = .{ .secret_key = author_secret, .draft = draft } },
        std.testing.allocator,
    );
    try std.testing.expect(signed == .signed);

    const verified = try client.runJob(&.{ .verify_event = signed.signed }, std.testing.allocator);
    try std.testing.expect(verified == .verified);

    var json_output: [512]u8 = undefined;
    const event_json = try client.local_operator.serializeEventJson(json_output[0..], &signed.signed);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const inspected = try client.runJob(&.{ .inspect_json = event_json }, arena.allocator());
    try std.testing.expect(inspected == .inspected);
    try std.testing.expectEqualStrings("local event job", inspected.inspected.event.content);
}
