const std = @import("std");
const client = @import("client_traits.zig");
const relay_url = @import("../relay/url.zig");

pub const checkpoint_scope_max_bytes: u8 = 32;

pub const RelayCheckpointArchiveError = client.ClientStoreError || error{
    MissingCheckpointStore,
    InvalidCheckpointScope,
    CheckpointScopeTooLong,
    InvalidRelayUrl,
};

pub const RelayCheckpointArchive = struct {
    store: client.ClientStore,

    pub fn init(store: client.ClientStore) RelayCheckpointArchive {
        return .{ .store = store };
    }

    pub fn saveRelayCheckpoint(
        self: RelayCheckpointArchive,
        scope: []const u8,
        relay_url_text: []const u8,
        cursor: client.EventCursor,
    ) RelayCheckpointArchiveError!void {
        var checkpoint_name: [client.checkpoint_name_max_bytes]u8 = undefined;
        const name = try checkpoint_name_for_relay(scope, relay_url_text, checkpoint_name[0..]);
        const checkpoint_store = try self.requireCheckpointStore();
        const record = try client.client_checkpoint_record_from_name(name, cursor);
        return checkpoint_store.putCheckpoint(&record);
    }

    pub fn loadRelayCheckpoint(
        self: RelayCheckpointArchive,
        scope: []const u8,
        relay_url_text: []const u8,
    ) RelayCheckpointArchiveError!?client.ClientCheckpointRecord {
        var checkpoint_name: [client.checkpoint_name_max_bytes]u8 = undefined;
        const name = try checkpoint_name_for_relay(scope, relay_url_text, checkpoint_name[0..]);
        const checkpoint_store = try self.requireCheckpointStore();
        return checkpoint_store.getCheckpoint(name);
    }

    fn requireCheckpointStore(
        self: RelayCheckpointArchive,
    ) RelayCheckpointArchiveError!client.ClientCheckpointStore {
        if (self.store.checkpoint_store) |checkpoint_store| return checkpoint_store;
        return error.MissingCheckpointStore;
    }
};

pub fn checkpoint_name_for_relay(
    scope: []const u8,
    relay_url_text: []const u8,
    output: []u8,
) RelayCheckpointArchiveError![]const u8 {
    if (scope.len == 0) return error.InvalidCheckpointScope;
    if (scope.len > checkpoint_scope_max_bytes) return error.CheckpointScopeTooLong;
    if (output.len < client.checkpoint_name_max_bytes) return error.CheckpointNameTooLong;

    try relay_url.relayUrlValidate(relay_url_text);

    var digest: [32]u8 = undefined;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("relay-checkpoint");
    hasher.update(&.{0});
    hasher.update(scope);
    hasher.update(&.{0});
    hasher.update(relay_url_text);
    hasher.final(&digest);

    const name_hex = std.fmt.bytesToHex(digest, .lower);
    @memcpy(output[0..client.checkpoint_name_max_bytes], name_hex[0..]);
    return output[0..client.checkpoint_name_max_bytes];
}

test "relay checkpoint archive persists one per-relay cursor" {
    var store = @import("client_memory.zig").MemoryClientStore{};
    const archive = RelayCheckpointArchive.init(store.asClientStore());

    try archive.saveRelayCheckpoint("mailbox", "wss://relay.one", .{ .offset = 7 });
    const restored = try archive.loadRelayCheckpoint("mailbox", "wss://relay.one");
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 7), restored.?.cursor.offset);
}

test "relay checkpoint names are stable for the same scope and relay url" {
    var first: [client.checkpoint_name_max_bytes]u8 = undefined;
    var second: [client.checkpoint_name_max_bytes]u8 = undefined;

    const name_a = try checkpoint_name_for_relay("groups", "wss://relay.one", first[0..]);
    const name_b = try checkpoint_name_for_relay("groups", "wss://relay.one", second[0..]);
    try std.testing.expectEqualStrings(name_a, name_b);
}

test "relay checkpoint helper rejects empty scope" {
    var output: [client.checkpoint_name_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidCheckpointScope,
        checkpoint_name_for_relay("", "wss://relay.one", output[0..]),
    );
}
