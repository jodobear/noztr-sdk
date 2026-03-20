const std = @import("std");
const relay_replay_exchange = @import("relay_replay_exchange_client.zig");
const replay_checkpoint_advance = @import("replay_checkpoint_advance_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const relay_response = @import("relay_response_client.zig");

pub const RelayReplayTurnClientError =
    relay_replay_exchange.RelayReplayExchangeClientError ||
    replay_checkpoint_advance.ReplayCheckpointAdvanceClientError;

pub const RelayReplayTurnClientConfig = struct {
    replay_exchange: relay_replay_exchange.RelayReplayExchangeClientConfig = .{},
    checkpoint_advance: replay_checkpoint_advance.ReplayCheckpointAdvanceClientConfig = .{},
};

pub const RelayReplayTurnClientStorage = struct {
    replay_exchange: relay_replay_exchange.RelayReplayExchangeClientStorage = .{},
    transcript: relay_response.RelaySubscriptionTranscriptStorage = .{},
    advance_state: replay_checkpoint_advance.ReplayCheckpointAdvanceState = undefined,
};

pub const ReplayTurnRequest = struct {
    replay: relay_replay_exchange.ReplayExchangeRequest,
};

pub const ReplayTurnIntake = struct {
    replay: relay_replay_exchange.ReplayExchangeOutcome,
    checkpoint_candidate: ?replay_checkpoint_advance.ReplayCheckpointAdvanceCandidate,
};

pub const ReplayTurnResult = struct {
    request: relay_replay_exchange.ReplayExchangeRequest,
    close: relay_replay_exchange.ReplayCloseRequest,
    checkpoint_candidate: replay_checkpoint_advance.ReplayCheckpointAdvanceCandidate,
    save_target: replay_checkpoint_advance.ReplayCheckpointSaveTarget,
};

pub const RelayReplayTurnClient = struct {
    config: RelayReplayTurnClientConfig,
    replay_exchange: relay_replay_exchange.RelayReplayExchangeClient,
    checkpoint_advance: replay_checkpoint_advance.ReplayCheckpointAdvanceClient,

    pub fn init(
        config: RelayReplayTurnClientConfig,
        storage: *RelayReplayTurnClientStorage,
    ) RelayReplayTurnClient {
        storage.* = .{};
        return .{
            .config = config,
            .replay_exchange = relay_replay_exchange.RelayReplayExchangeClient.init(
                config.replay_exchange,
                &storage.replay_exchange,
            ),
            .checkpoint_advance = replay_checkpoint_advance.ReplayCheckpointAdvanceClient.init(
                config.checkpoint_advance,
            ),
        };
    }

    pub fn attach(
        config: RelayReplayTurnClientConfig,
        storage: *RelayReplayTurnClientStorage,
    ) RelayReplayTurnClient {
        return .{
            .config = config,
            .replay_exchange = relay_replay_exchange.RelayReplayExchangeClient.attach(
                config.replay_exchange,
                &storage.replay_exchange,
            ),
            .checkpoint_advance = replay_checkpoint_advance.ReplayCheckpointAdvanceClient.init(
                config.checkpoint_advance,
            ),
        };
    }

    pub fn addRelay(
        self: *RelayReplayTurnClient,
        relay_url_text: []const u8,
    ) RelayReplayTurnClientError!runtime.RelayDescriptor {
        return self.replay_exchange.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *RelayReplayTurnClient,
        relay_index: u8,
    ) RelayReplayTurnClientError!void {
        return self.replay_exchange.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayReplayTurnClient,
        relay_index: u8,
    ) RelayReplayTurnClientError!void {
        return self.replay_exchange.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayReplayTurnClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayReplayTurnClientError!void {
        return self.replay_exchange.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const RelayReplayTurnClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.replay_exchange.inspectRelayRuntime(storage);
    }

    pub fn inspectReplay(
        self: *const RelayReplayTurnClient,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) RelayReplayTurnClientError!runtime.RelayPoolReplayPlan {
        return self.replay_exchange.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn beginTurn(
        self: *const RelayReplayTurnClient,
        storage: *RelayReplayTurnClientStorage,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) RelayReplayTurnClientError!ReplayTurnRequest {
        const replay_request = try self.replay_exchange.beginReplay(
            checkpoint_store,
            &storage.transcript,
            output,
            subscription_id,
            specs,
        );
        storage.advance_state = self.checkpoint_advance.beginAdvance(&replay_request);
        return .{ .replay = replay_request };
    }

    pub fn acceptReplayMessageJson(
        self: *const RelayReplayTurnClient,
        storage: *RelayReplayTurnClientStorage,
        request: *const ReplayTurnRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayReplayTurnClientError!ReplayTurnIntake {
        const replay_outcome = try self.replay_exchange.acceptReplayMessageJson(
            &request.replay,
            &storage.transcript,
            relay_message_json,
            scratch,
        );
        try self.checkpoint_advance.acceptReplayOutcome(&storage.advance_state, &replay_outcome);
        return .{
            .replay = replay_outcome,
            .checkpoint_candidate = self.checkpoint_advance.candidate(&storage.advance_state),
        };
    }

    pub fn completeTurn(
        self: *const RelayReplayTurnClient,
        storage: *RelayReplayTurnClientStorage,
        output: []u8,
        request: *const ReplayTurnRequest,
    ) RelayReplayTurnClientError!ReplayTurnResult {
        const checkpoint_candidate = self.checkpoint_advance.candidate(&storage.advance_state) orelse {
            return error.IncompleteTranscript;
        };
        const close_request = try self.replay_exchange.composeClose(output, &request.replay);
        const save_target = try self.checkpoint_advance.composeSaveTarget(&storage.advance_state);
        return .{
            .request = request.replay,
            .close = close_request,
            .checkpoint_candidate = checkpoint_candidate,
            .save_target = save_target,
        };
    }

    pub fn saveTurnResult(
        self: *const RelayReplayTurnClient,
        archive: store.RelayCheckpointArchive,
        result: *const ReplayTurnResult,
    ) RelayReplayTurnClientError!void {
        return self.checkpoint_advance.saveTarget(archive, &result.save_target);
    }
};

test "relay replay turn client exposes caller-owned config and storage" {
    var storage = RelayReplayTurnClientStorage{};
    var client = RelayReplayTurnClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.replay_exchange.replay.relay_pool.relayCount());
}

test "relay replay turn client composes one bounded replay turn and checkpoint save" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayReplayTurnClientStorage{};
    var client = RelayReplayTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var request_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;
    const turn_request = try client.beginTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const noztr = @import("noztr");
    const secret_key = [_]u8{0x73} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 25,
        .tags = &.{},
        .content = "replay turn event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    const event_intake = try client.acceptReplayMessageJson(
        &storage,
        &turn_request,
        event_json,
        arena.allocator(),
    );
    try std.testing.expect(event_intake.replay.message == .event);
    try std.testing.expect(event_intake.checkpoint_candidate == null);

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    const eose_intake = try client.acceptReplayMessageJson(
        &storage,
        &turn_request,
        eose_json,
        arena.allocator(),
    );
    try std.testing.expect(eose_intake.replay.message == .eose);
    try std.testing.expect(eose_intake.checkpoint_candidate != null);

    const turn_result = try client.completeTurn(&storage, request_output[0..], &turn_request);
    try std.testing.expectEqualStrings("wss://relay.one", turn_result.request.relay.relay_url);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"replay-feed\"]", turn_result.close.request_json);
    try std.testing.expectEqual(@as(u32, 8), turn_result.checkpoint_candidate.cursor.offset);

    try client.saveTurnResult(checkpoint_archive, &turn_result);
    const restored = try checkpoint_archive.loadRelayCheckpoint("tooling", relay.relay_url);
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 8), restored.?.cursor.offset);
}

test "relay replay turn client rejects partial replay turns" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayReplayTurnClientStorage{};
    var client = RelayReplayTurnClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var request_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;
    const turn_request = try client.beginTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const noztr = @import("noztr");
    const secret_key = [_]u8{0x75} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 26,
        .tags = &.{},
        .content = "partial replay turn event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    _ = try client.acceptReplayMessageJson(&storage, &turn_request, event_json, arena.allocator());

    try std.testing.expectError(
        error.IncompleteTranscript,
        client.completeTurn(&storage, request_output[0..], &turn_request),
    );
}

test "relay replay turn client exposes auth-gated and stale relay posture explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayReplayTurnClientStorage{};
    var client = RelayReplayTurnClient.init(.{}, &storage);
    const auth_relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(auth_relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", auth_relay.relay_url, .{ .offset = 7 });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var request_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;

    try client.noteRelayAuthChallenge(auth_relay.relay_index, "challenge-1");
    try std.testing.expectError(
        error.NoReadyRelay,
        client.beginTurn(
            &storage,
            checkpoint_store,
            request_output[0..],
            "replay-feed",
            replay_specs[0..],
        ),
    );

    const stale_relay = try client.addRelay("wss://relay.two");
    try client.markRelayConnected(stale_relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", stale_relay.relay_url, .{ .offset = 9 });
    const turn_request = try client.beginTurn(
        &storage,
        checkpoint_store,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    const noztr = @import("noztr");
    const secret_key = [_]u8{0x7b} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 28,
        .tags = &.{},
        .content = "stale replay turn event",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);

    var relay_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = event } },
    );
    _ = try client.acceptReplayMessageJson(
        &storage,
        &turn_request,
        event_json,
        arena.allocator(),
    );

    const eose_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .eose = .{ .subscription_id = "replay-feed" } },
    );
    _ = try client.acceptReplayMessageJson(
        &storage,
        &turn_request,
        eose_json,
        arena.allocator(),
    );

    try client.noteRelayDisconnected(stale_relay.relay_index);
    try std.testing.expectError(
        error.RelayNotReady,
        client.completeTurn(&storage, request_output[0..], &turn_request),
    );
}
