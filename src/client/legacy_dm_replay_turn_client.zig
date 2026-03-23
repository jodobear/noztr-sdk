const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_replay_turn = @import("relay_replay_turn_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const workflows = @import("../workflows/mod.zig");

pub const Error =
    relay_replay_turn.RelayReplayTurnClientError ||
    workflows.dm.legacy.LegacyDmError;

pub const Config = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    replay_turn: relay_replay_turn.RelayReplayTurnClientConfig = .{},
};

pub const Storage = struct {
    session: workflows.dm.legacy.LegacyDmSession = undefined,
    replay_turn: relay_replay_turn.RelayReplayTurnClientStorage = .{},
};

pub const Request = relay_replay_turn.ReplayTurnRequest;
pub const Result = relay_replay_turn.ReplayTurnResult;

pub const Intake = struct {
    replay: relay_replay_turn.ReplayTurnIntake,
    message: ?workflows.dm.legacy.LegacyDmMessageOutcome,
};

pub const Client = struct {
    config: Config,
    storage: *Storage,
    replay_turn: relay_replay_turn.RelayReplayTurnClient,

    pub fn init(
        config: Config,
        storage: *Storage,
    ) Client {
        storage.* = .{
            .session = workflows.dm.legacy.LegacyDmSession.init(&config.owner_private_key),
        };
        return .{
            .config = config,
            .storage = storage,
            .replay_turn = relay_replay_turn.RelayReplayTurnClient.attach(
                config.replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn attach(
        config: Config,
        storage: *Storage,
    ) Client {
        return .{
            .config = config,
            .storage = storage,
            .replay_turn = relay_replay_turn.RelayReplayTurnClient.attach(
                config.replay_turn,
                &storage.replay_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *Client,
        relay_url_text: []const u8,
    ) Error!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "replay_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *Client,
        relay_index: u8,
    ) Error!void {
        return relay_lifecycle_support.markRelayConnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *Client,
        relay_index: u8,
    ) Error!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "replay_turn", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *Client,
        relay_index: u8,
        challenge: []const u8,
    ) Error!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "replay_turn",
            relay_index,
            challenge,
        );
    }

    pub fn acceptRelayAuthEvent(
        self: *Client,
        relay_index: u8,
        auth_event: *const @import("noztr").nip01_event.Event,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) Error!runtime.RelayDescriptor {
        try self.replay_turn.replay_exchange.replay.relay_pool.acceptRelayAuthEvent(
            relay_index,
            auth_event,
            now_unix_seconds,
            window_seconds,
        );
        return self.replay_turn.replay_exchange.replay.relay_pool.descriptor(relay_index) orelse {
            return error.InvalidRelayIndex;
        };
    }

    pub fn inspectRelayRuntime(
        self: *const Client,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "replay_turn", storage);
    }

    pub fn inspectAuth(
        self: *const Client,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.replay_turn.replay_exchange.replay.relay_pool.inspectAuth(storage);
    }

    pub fn inspectReplay(
        self: *const Client,
        checkpoint_store: store.ClientCheckpointStore,
        specs: []const runtime.RelayReplaySpec,
        storage: *runtime.RelayPoolReplayStorage,
    ) Error!runtime.RelayPoolReplayPlan {
        return self.replay_turn.inspectReplay(checkpoint_store, specs, storage);
    }

    pub fn beginTurn(
        self: *const Client,
        checkpoint_store: store.ClientCheckpointStore,
        output: []u8,
        subscription_id: []const u8,
        specs: []const runtime.RelayReplaySpec,
    ) Error!Request {
        return self.replay_turn.beginTurn(
            &self.storage.replay_turn,
            checkpoint_store,
            output,
            subscription_id,
            specs,
        );
    }

    pub fn acceptReplayMessageJson(
        self: *Client,
        request: *const Request,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) Error!Intake {
        const replay = try self.replay_turn.acceptReplayMessageJson(
            &self.storage.replay_turn,
            request,
            relay_message_json,
            scratch,
        );

        var message: ?workflows.dm.legacy.LegacyDmMessageOutcome = null;
        if (replay.replay.message == .event and
            replay.replay.message.event.event.kind == @import("noztr").nip04.dm_kind)
        {
            message = try self.storage.session.acceptDirectMessageEvent(
                &replay.replay.message.event.event,
                plaintext_output,
            );
        }

        return .{
            .replay = replay,
            .message = message,
        };
    }

    pub fn completeTurn(
        self: *const Client,
        output: []u8,
        request: *const Request,
    ) Error!Result {
        return self.replay_turn.completeTurn(&self.storage.replay_turn, output, request);
    }

    pub fn saveTurnResult(
        self: *const Client,
        archive: store.RelayCheckpointArchive,
        result: *const Result,
    ) Error!void {
        return self.replay_turn.saveTurnResult(archive, result);
    }
};

test "legacy dm replay turn client accepts replay transcript events through dm intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var memory_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const checkpoint_store = memory_store.asClientStore().checkpoint_store.?;
    const checkpoint_archive = store.RelayCheckpointArchive.init(memory_store.asClientStore());

    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try @import("noztr").nostr_keys.nostr_derive_public_key(&recipient_secret);

    var storage = Storage{};
    var client = Client.init(.{
        .owner_private_key = recipient_secret,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try checkpoint_archive.saveRelayCheckpoint("legacy-dm", relay.relay_url, .{ .offset = 7 });

    var outbound = workflows.dm.legacy.LegacyDmOutboundStorage{};
    const sender = workflows.dm.legacy.LegacyDmSession.init(&sender_secret);
    const prepared = try sender.buildDirectMessageEvent(&outbound, &.{
        .recipient_pubkey = recipient_pubkey,
        .content = "legacy replay intake",
        .created_at = 60,
        .iv = [_]u8{0x55} ** @import("noztr").limits.nip04_iv_bytes,
    });

    const replay_specs = [_]runtime.RelayReplaySpec{
        .{
            .checkpoint_scope = "legacy-dm",
            .query = .{ .limit = 16 },
        },
    };
    var request_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;
    const turn_request = try client.beginTurn(
        checkpoint_store,
        request_output[0..],
        "legacy-feed",
        replay_specs[0..],
    );

    var relay_output: [@import("noztr").limits.relay_message_bytes_max]u8 = undefined;
    const event_json = try @import("noztr").nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "legacy-feed", .event = prepared.event } },
    );
    var plaintext_output: [@import("noztr").limits.nip04_plaintext_max_bytes]u8 = undefined;
    const intake = try client.acceptReplayMessageJson(
        &turn_request,
        event_json,
        plaintext_output[0..],
        arena.allocator(),
    );
    try std.testing.expect(intake.replay.replay.message == .event);
    try std.testing.expect(intake.message != null);
    try std.testing.expectEqualStrings("legacy replay intake", intake.message.?.plaintext);
}
