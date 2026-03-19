const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

test "recipe: relay checkpoint archive persists one named cursor per relay and scope" {
    var backing_store = noztr_sdk.store.MemoryClientStore{};
    const archive = noztr_sdk.store.RelayCheckpointArchive.init(backing_store.asClientStore());

    try archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 3 });
    try archive.saveRelayCheckpoint("mailbox", "wss://relay.two", .{ .offset = 8 });

    const first = try archive.loadRelayCheckpoint("mailbox", "wss://relay.one");
    const second = try archive.loadRelayCheckpoint("mailbox", "wss://relay.two");
    try std.testing.expect(first != null);
    try std.testing.expect(second != null);
    try std.testing.expectEqual(@as(u32, 3), first.?.cursor.offset);
    try std.testing.expectEqual(@as(u32, 8), second.?.cursor.offset);
}
