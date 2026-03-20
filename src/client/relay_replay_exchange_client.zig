const std = @import("std");
const relay_replay = @import("relay_replay_client.zig");
const relay_response = @import("relay_response_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const RelayReplayExchangeClientError =
    relay_replay.RelayReplayClientError ||
    relay_response.RelayResponseClientError ||
    error{
        NoReadyRelay,
        RelayNotReady,
    };

pub const RelayReplayExchangeClientConfig = struct {
    replay: relay_replay.RelayReplayClientConfig = .{},
    relay_response: relay_response.RelayResponseClientConfig = .{},
};

pub const RelayReplayExchangeClientStorage = struct {
    replay: relay_replay.RelayReplayClientStorage = .{},
};

pub const ReplayExchangeRequest = struct {
    relay: runtime.RelayDescriptor,
    checkpoint_scope: []const u8,
    query: store.ClientQuery,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const ReplayExchangeOutcome = struct {
    relay: runtime.RelayDescriptor,
    message: relay_response.RelaySubscriptionMessageOutcome,
};

pub const ReplayCloseRequest = struct {
    relay: runtime.RelayDescriptor,
    subscription_id: []const u8,
    request_json: []const u8,
};

pub const RelayReplayExchangeClient = struct {
    config: RelayReplayExchangeClientConfig,
    replay: relay_replay.RelayReplayClient,
    relay_response: relay_response.RelayResponseClient,

    pub fn init(
        config: RelayReplayExchangeClientConfig,
        storage: *RelayReplayExchangeClientStorage,
    ) RelayReplayExchangeClient {
        storage.* = .{};
        return .{
            .config = config,
            .replay = relay_replay.RelayReplayClient.init(config.replay, &storage.replay),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
        };
    }

    pub fn attach(
        config: RelayReplayExchangeClientConfig,
        storage: *RelayReplayExchangeClientStorage,
    ) RelayReplayExchangeClient {
        return .{
            .config = config,
            .replay = relay_replay.RelayReplayClient.attach(config.replay, &storage.replay),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
        };
    }

    pub fn addRelay(
        self: *RelayReplayExchangeClient,
        relay_url_text: []const u8,
    ) RelayReplayExchangeClientError!runtime.RelayDescriptor {
        return self.replay.addRelay(relay_url_text);
    }

    pub fn markRelayConnected(
        self: *RelayReplayExchangeClient,
        relay_index: u8,
    ) RelayReplayExchangeClientError!void {
        return self.replay.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *RelayReplayExchangeClient,
        relay_index: u8,
    ) RelayReplayExchangeClientError!void {
        return self.replay.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *RelayReplayExchangeClient,
        relay_index: u8,
        challenge: []const u8,
    ) RelayReplayExchangeClientError!void {
        return self.replay.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const RelayReplayExchangeClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.replay.inspectRelayRuntime(storage);
    }

    pub fn inspectReplay(
        self: *const RelayReplayExchangeClient,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) RelayReplayExchangeClientError!runtime.RelayPoolReplayPlan {
        return self.replay.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn beginReplay(
        self: *const RelayReplayExchangeClient,
        checkpoint_store: store.ClientCheckpointStore,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) RelayReplayExchangeClientError!ReplayExchangeRequest {
        var replay_storage = runtime.RelayPoolReplayStorage{};
        const replay_plan = try self.replay.inspectReplay(checkpoint_store, specs, &replay_storage);
        const replay_step = replay_plan.nextStep() orelse return error.NoReadyRelay;
        try self.relay_response.beginSubscriptionTranscript(transcript, subscription_id);
        const targeted = try self.replay.composeTargetedReplayRequest(
            output,
            &replay_step,
            subscription_id,
        );
        return .{
            .relay = targeted.relay,
            .checkpoint_scope = targeted.checkpoint_scope,
            .query = targeted.query,
            .subscription_id = targeted.subscription_id,
            .request_json = targeted.request_json,
        };
    }

    pub fn acceptReplayMessageJson(
        self: *const RelayReplayExchangeClient,
        request: *const ReplayExchangeRequest,
        transcript: *relay_response.RelaySubscriptionTranscriptStorage,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayReplayExchangeClientError!ReplayExchangeOutcome {
        const message = try self.relay_response.acceptSubscriptionMessageJson(
            transcript,
            relay_message_json,
            scratch,
        );
        return .{
            .relay = request.relay,
            .message = message,
        };
    }

    pub fn composeClose(
        self: *const RelayReplayExchangeClient,
        output: []u8,
        request: *const ReplayExchangeRequest,
    ) RelayReplayExchangeClientError!ReplayCloseRequest {
        try self.requireReadyRelay(&request.relay);
        const message = noztr.nip01_message.ClientMessage{
            .close = .{ .subscription_id = request.subscription_id },
        };
        const request_json = try noztr.nip01_message.client_message_serialize_json(output, &message);
        return .{
            .relay = request.relay,
            .subscription_id = request.subscription_id,
            .request_json = request_json,
        };
    }

    fn requireReadyRelay(
        self: *const RelayReplayExchangeClient,
        descriptor: *const runtime.RelayDescriptor,
    ) RelayReplayExchangeClientError!void {
        const live_descriptor = self.replay.relay_pool.descriptor(descriptor.relay_index) orelse {
            return error.RelayNotReady;
        };
        if (!std.mem.eql(u8, live_descriptor.relay_url, descriptor.relay_url)) {
            return error.RelayNotReady;
        }

        var storage_buf = runtime.RelayPoolPlanStorage{};
        const runtime_plan = self.inspectRelayRuntime(&storage_buf);
        const current = runtime_plan.entry(descriptor.relay_index) orelse return error.RelayNotReady;
        if (!std.mem.eql(u8, current.descriptor.relay_url, descriptor.relay_url)) {
            return error.RelayNotReady;
        }
        if (current.action != .ready) return error.RelayNotReady;
    }
};

test "relay replay exchange client exposes caller-owned config and storage" {
    var storage = RelayReplayExchangeClientStorage{};
    var client = RelayReplayExchangeClient.init(.{}, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.replay.relay_pool.relayCount());
}

test "relay replay exchange client composes replay transcript intake and close explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    var storage = RelayReplayExchangeClientStorage{};
    var client = RelayReplayExchangeClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("tooling", relay.relay_url, .{ .offset = 7 });

    const authors = [_]store.EventPubkeyHex{
        try store.event_pubkey_hex_from_text(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
    };
    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{
                .authors = authors[0..],
                .kinds = (&[_]u32{1})[0..],
                .limit = 16,
            },
        },
    };

    var transcript = relay_response.RelaySubscriptionTranscriptStorage{};
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_request = try client.beginReplay(
        checkpoint_store,
        &transcript,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );
    try std.testing.expectEqualStrings("wss://relay.one", replay_request.relay.relay_url);
    try std.testing.expectEqualStrings("tooling", replay_request.checkpoint_scope);

    const secret_key = [_]u8{0x61} ** 32;
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var replay_event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 20,
        .content = "replay event",
        .tags = &.{},
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &replay_event);

    var relay_json_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_reply_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_json_output[0..],
        &.{ .event = .{ .subscription_id = "replay-feed", .event = replay_event } },
    );
    const replay_outcome = try client.acceptReplayMessageJson(
        &replay_request,
        &transcript,
        event_reply_json,
        arena.allocator(),
    );
    try std.testing.expect(replay_outcome.message == .event);

    const close_request = try client.composeClose(request_output[0..], &replay_request);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"replay-feed\"]", close_request.request_json);
}

test "relay replay exchange client rejects close when the relay is no longer ready" {
    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;

    var storage = RelayReplayExchangeClientStorage{};
    var client = RelayReplayExchangeClient.init(.{}, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "tooling",
            .query = .{ .limit = 16 },
        },
    };

    var transcript = relay_response.RelaySubscriptionTranscriptStorage{};
    var request_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const replay_request = try client.beginReplay(
        checkpoint_store,
        &transcript,
        request_output[0..],
        "replay-feed",
        replay_specs[0..],
    );

    try client.noteRelayDisconnected(relay.relay_index);
    try std.testing.expectError(error.RelayNotReady, client.composeClose(request_output[0..], &replay_request));
}
