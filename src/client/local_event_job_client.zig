const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const noztr = @import("noztr");

pub const LocalEventJobClientError = local_operator.LocalOperatorClientError;

pub const LocalEventJobClientConfig = struct {
    local_operator: local_operator.LocalOperatorClientConfig = .{},
};

pub const LocalEventJobClientStorage = struct {};

pub const LocalEventJobRequest = union(enum) {
    inspect_json: []const u8,
    sign_draft: struct {
        secret_key: [local_operator.secret_key_bytes]u8,
        draft: local_operator.LocalEventDraft,
    },
    verify_event: noztr.nip01_event.Event,
};

pub const LocalEventJobResult = union(enum) {
    inspected: local_operator.LocalEventInspection,
    signed: noztr.nip01_event.Event,
    verified: local_operator.LocalEventInspection,
};

pub const LocalEventJobClient = struct {
    config: LocalEventJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,

    pub fn init(
        config: LocalEventJobClientConfig,
        storage: *LocalEventJobClientStorage,
    ) LocalEventJobClient {
        storage.* = .{};
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn attach(
        config: LocalEventJobClientConfig,
        storage: *LocalEventJobClientStorage,
    ) LocalEventJobClient {
        _ = storage;
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
        };
    }

    pub fn runJob(
        self: LocalEventJobClient,
        request: *const LocalEventJobRequest,
        scratch: std.mem.Allocator,
    ) LocalEventJobClientError!LocalEventJobResult {
        return switch (request.*) {
            .inspect_json => |event_json| .{
                .inspected = try self.local_operator.inspectEventJson(event_json, scratch),
            },
            .sign_draft => |job| .{
                .signed = try self.local_operator.signDraft(&job.secret_key, &job.draft),
            },
            .verify_event => |event| verified: {
                try self.local_operator.verifyEvent(&event);
                break :verified .{ .verified = self.local_operator.inspectEvent(&event) };
            },
        };
    }
};

test "local event job client exposes caller-owned config and storage" {
    var storage = LocalEventJobClientStorage{};
    const client = LocalEventJobClient.init(.{}, &storage);

    _ = client;
}

test "local event job client signs and verifies one local event through stable job posture" {
    var storage = LocalEventJobClientStorage{};
    const client = LocalEventJobClient.init(.{}, &storage);
    const secret_key = [_]u8{0x21} ** local_operator.secret_key_bytes;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 7,
        .content = "job signed event",
    };

    const signed = try client.runJob(
        &.{ .sign_draft = .{ .secret_key = secret_key, .draft = draft } },
        std.testing.allocator,
    );
    try std.testing.expect(signed == .signed);

    const verified = try client.runJob(&.{ .verify_event = signed.signed }, std.testing.allocator);
    try std.testing.expect(verified == .verified);
    try std.testing.expectEqualStrings("job signed event", verified.verified.event.content);
}

test "local event job client inspects one event json through stable job posture" {
    var storage = LocalEventJobClientStorage{};
    const client = LocalEventJobClient.init(.{}, &storage);
    const secret_key = [_]u8{0x22} ** local_operator.secret_key_bytes;
    const draft = local_operator.LocalEventDraft{
        .kind = 1,
        .created_at = 9,
        .content = "inspect json event",
    };
    var event = try client.local_operator.signDraft(&secret_key, &draft);

    var json_output: [512]u8 = undefined;
    const event_json = try client.local_operator.serializeEventJson(json_output[0..], &event);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const inspected = try client.runJob(&.{ .inspect_json = event_json }, arena.allocator());
    try std.testing.expect(inspected == .inspected);
    try std.testing.expectEqualStrings("inspect json event", inspected.inspected.event.content);
}
