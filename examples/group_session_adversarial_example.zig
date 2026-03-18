const std = @import("std");
const noztr_sdk = @import("noztr_sdk");
const common = @import("common.zig");
const noztr = @import("noztr");

// Hostile-path example: wrong-group replay must fail before mutating reduced state.
test "adversarial example: group session rejects wrong-group replay before mutation" {
    var users: [1]noztr.nip29_relay_groups.GroupStateUser = undefined;
    var roles: [0]noztr.nip29_relay_groups.GroupRole = .{};
    var user_roles: [noztr.nip29_relay_groups.group_state_user_roles_max][]const u8 = undefined;
    var session = try noztr_sdk.workflows.GroupSession.init(.{
        .reference_text = "relay.one'pizza-lovers",
        .relay_url = "wss://relay.one",
        .storage = noztr_sdk.workflows.GroupSessionStorage.init(
            users[0..],
            roles[0..],
            user_roles[0..],
        ),
    });
    session.markCurrentRelayConnected();

    var metadata_json_storage: [1024]u8 = undefined;
    const metadata_json = try buildMetadataEventJson(
        metadata_json_storage[0..],
        "pizza-lovers",
        "Pizza Lovers",
    );
    var wrong_put_json_storage: [1024]u8 = undefined;
    const wrong_put_json = try buildPutUserEventJson(
        wrong_put_json_storage[0..],
        "other-group",
        "moderator",
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    _ = try session.acceptCanonicalStateEventJson(metadata_json, arena.allocator());
    try std.testing.expectError(
        error.EventGroupMismatch,
        session.acceptCanonicalStateEventJson(wrong_put_json, arena.allocator()),
    );
    try std.testing.expectEqualStrings("pizza-lovers", session.view().metadata.group_id);
}

fn buildMetadataEventJson(output: []u8, group_id: []const u8, name: []const u8) ![]const u8 {
    const signer_secret = [_]u8{0x09} ** 32;
    const signer_pubkey = try common.derivePublicKey(&signer_secret);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", group_id } },
        .{ .items = &.{ "name", name } },
        .{ .items = &.{ "public" } },
    };
    var event = common.simpleEvent(noztr.nip29_relay_groups.group_metadata_kind, signer_pubkey, 1, "", tags[0..]);
    try common.signEvent(&signer_secret, &event);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":1,\"kind\":39000," ++
            "\"tags\":[[\"d\",\"{s}\"],[\"name\",\"{s}\"],[\"public\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            group_id,
            name,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}

fn buildPutUserEventJson(
    output: []u8,
    group_id: []const u8,
    role: []const u8,
) ![]const u8 {
    const signer_secret = [_]u8{0x09} ** 32;
    const signer_pubkey = try common.derivePublicKey(&signer_secret);
    const member_hex = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "h", group_id } },
        .{ .items = &.{ "p", member_hex, role } },
    };
    var event = common.simpleEvent(noztr.nip29_relay_groups.group_put_user_kind, signer_pubkey, 1, "promote", tags[0..]);
    try common.signEvent(&signer_secret, &event);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":1,\"kind\":9000," ++
            "\"tags\":[[\"h\",\"{s}\"],[\"p\",\"{s}\",\"{s}\"]]," ++
            "\"content\":\"promote\",\"sig\":\"{s}\"}}",
        .{
            std.fmt.bytesToHex(event.id, .lower),
            std.fmt.bytesToHex(event.pubkey, .lower),
            group_id,
            member_hex,
            role,
            std.fmt.bytesToHex(event.sig, .lower),
        },
    ) catch error.BufferTooSmall;
}
