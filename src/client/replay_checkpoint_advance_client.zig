const std = @import("std");
const relay_replay_exchange = @import("relay_replay_exchange_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");

pub const ReplayCheckpointAdvanceClientError =
    store.RelayCheckpointArchiveError ||
    error{
        MismatchedRelay,
        MismatchedSubscription,
        IncompleteTranscript,
    };

pub const ReplayCheckpointAdvanceClientConfig = struct {};

pub const ReplayCheckpointAdvanceState = struct {
    relay: runtime.RelayDescriptor,
    checkpoint_scope: []const u8,
    subscription_id: []const u8,
    base_cursor: store.EventCursor,
    event_count: u32 = 0,
    saw_eose: bool = false,
    saw_closed: bool = false,
};

pub const ReplayCheckpointAdvanceCandidate = struct {
    relay: runtime.RelayDescriptor,
    checkpoint_scope: []const u8,
    subscription_id: []const u8,
    cursor: store.EventCursor,
    replayed_event_count: u32,
};

pub const ReplayCheckpointSaveTarget = struct {
    relay: runtime.RelayDescriptor,
    checkpoint_scope: []const u8,
    cursor: store.EventCursor,
};

pub const ReplayCheckpointAdvanceClient = struct {
    config: ReplayCheckpointAdvanceClientConfig,

    pub fn init(config: ReplayCheckpointAdvanceClientConfig) ReplayCheckpointAdvanceClient {
        return .{ .config = config };
    }

    pub fn beginAdvance(
        self: ReplayCheckpointAdvanceClient,
        request: *const relay_replay_exchange.ReplayExchangeRequest,
    ) ReplayCheckpointAdvanceState {
        _ = self;
        return .{
            .relay = request.relay,
            .checkpoint_scope = request.checkpoint_scope,
            .subscription_id = request.subscription_id,
            .base_cursor = request.query.cursor orelse .{},
        };
    }

    pub fn acceptReplayOutcome(
        self: ReplayCheckpointAdvanceClient,
        state: *ReplayCheckpointAdvanceState,
        outcome: *const relay_replay_exchange.ReplayExchangeOutcome,
    ) ReplayCheckpointAdvanceClientError!void {
        _ = self;
        if (outcome.relay.relay_index != state.relay.relay_index) return error.MismatchedRelay;
        if (!std.mem.eql(u8, outcome.relay.relay_url, state.relay.relay_url)) {
            return error.MismatchedRelay;
        }

        switch (outcome.message) {
            .event => |event_message| {
                if (!std.mem.eql(u8, event_message.subscription_id, state.subscription_id)) {
                    return error.MismatchedSubscription;
                }
                state.event_count += 1;
            },
            .eose => |eose_message| {
                if (!std.mem.eql(u8, eose_message.subscription_id, state.subscription_id)) {
                    return error.MismatchedSubscription;
                }
                state.saw_eose = true;
            },
            .closed => |closed_message| {
                if (!std.mem.eql(u8, closed_message.subscription_id, state.subscription_id)) {
                    return error.MismatchedSubscription;
                }
                state.saw_closed = true;
            },
        }
    }

    pub fn candidate(
        self: ReplayCheckpointAdvanceClient,
        state: *const ReplayCheckpointAdvanceState,
    ) ?ReplayCheckpointAdvanceCandidate {
        _ = self;
        if (!state.saw_eose) return null;
        return .{
            .relay = state.relay,
            .checkpoint_scope = state.checkpoint_scope,
            .subscription_id = state.subscription_id,
            .cursor = .{ .offset = state.base_cursor.offset + state.event_count },
            .replayed_event_count = state.event_count,
        };
    }

    pub fn composeSaveTarget(
        self: ReplayCheckpointAdvanceClient,
        state: *const ReplayCheckpointAdvanceState,
    ) ReplayCheckpointAdvanceClientError!ReplayCheckpointSaveTarget {
        const advance_candidate = self.candidate(state) orelse return error.IncompleteTranscript;
        return .{
            .relay = advance_candidate.relay,
            .checkpoint_scope = advance_candidate.checkpoint_scope,
            .cursor = advance_candidate.cursor,
        };
    }

    pub fn saveTarget(
        self: ReplayCheckpointAdvanceClient,
        archive: store.RelayCheckpointArchive,
        target: *const ReplayCheckpointSaveTarget,
    ) ReplayCheckpointAdvanceClientError!void {
        _ = self;
        return archive.saveRelayCheckpoint(
            target.checkpoint_scope,
            target.relay.relay_url,
            target.cursor,
        );
    }
};

test "replay checkpoint advance client derives one candidate only after eose" {
    const client = ReplayCheckpointAdvanceClient.init(.{});
    const request = relay_replay_exchange.ReplayExchangeRequest{
        .relay = .{ .relay_index = 1, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "tooling",
        .query = .{ .cursor = .{ .offset = 7 }, .limit = 16 },
        .subscription_id = "replay-feed",
        .request_json = "[\"REQ\",\"replay-feed\",{}]",
    };
    var state = client.beginAdvance(&request);

    const event_outcome = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = request.relay,
        .message = .{
            .event = .{
                .subscription_id = "replay-feed",
                .event = undefined,
                .stage = .req_sent,
            },
        },
    };
    try client.acceptReplayOutcome(&state, &event_outcome);
    try std.testing.expect(client.candidate(&state) == null);

    const eose_outcome = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = request.relay,
        .message = .{
            .eose = .{
                .subscription_id = "replay-feed",
                .stage = .eose_received,
            },
        },
    };
    try client.acceptReplayOutcome(&state, &eose_outcome);

    const advance_candidate = client.candidate(&state).?;
    try std.testing.expectEqual(@as(u32, 8), advance_candidate.cursor.offset);
    try std.testing.expectEqual(@as(u32, 1), advance_candidate.replayed_event_count);
}

test "replay checkpoint advance client does not advance partial or closed-only transcripts" {
    const client = ReplayCheckpointAdvanceClient.init(.{});
    const request = relay_replay_exchange.ReplayExchangeRequest{
        .relay = .{ .relay_index = 1, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "tooling",
        .query = .{ .cursor = .{ .offset = 7 }, .limit = 16 },
        .subscription_id = "replay-feed",
        .request_json = "[\"REQ\",\"replay-feed\",{}]",
    };
    var state = client.beginAdvance(&request);

    const closed_outcome = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = request.relay,
        .message = .{
            .closed = .{
                .subscription_id = "replay-feed",
                .status = "error: blocked",
                .stage = .closed,
            },
        },
    };
    try client.acceptReplayOutcome(&state, &closed_outcome);
    try std.testing.expect(client.candidate(&state) == null);
    try std.testing.expectError(error.IncompleteTranscript, client.composeSaveTarget(&state));
}

test "replay checkpoint advance client persists one explicit save target" {
    var backing_store = @import("../store/client_memory.zig").MemoryClientStore{};
    const archive = store.RelayCheckpointArchive.init(backing_store.asClientStore());
    const client = ReplayCheckpointAdvanceClient.init(.{});
    const request = relay_replay_exchange.ReplayExchangeRequest{
        .relay = .{ .relay_index = 1, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "tooling",
        .query = .{ .cursor = .{ .offset = 7 }, .limit = 16 },
        .subscription_id = "replay-feed",
        .request_json = "[\"REQ\",\"replay-feed\",{}]",
    };
    var state = client.beginAdvance(&request);

    const event_outcome = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = request.relay,
        .message = .{
            .event = .{
                .subscription_id = "replay-feed",
                .event = undefined,
                .stage = .req_sent,
            },
        },
    };
    const eose_outcome = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = request.relay,
        .message = .{
            .eose = .{
                .subscription_id = "replay-feed",
                .stage = .eose_received,
            },
        },
    };
    try client.acceptReplayOutcome(&state, &event_outcome);
    try client.acceptReplayOutcome(&state, &eose_outcome);

    const save_target = try client.composeSaveTarget(&state);
    try client.saveTarget(archive, &save_target);

    const restored = try archive.loadRelayCheckpoint("tooling", "wss://relay.one");
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u32, 8), restored.?.cursor.offset);
}

test "replay checkpoint advance client rejects mismatched replay transcript identity" {
    const client = ReplayCheckpointAdvanceClient.init(.{});
    const request = relay_replay_exchange.ReplayExchangeRequest{
        .relay = .{ .relay_index = 1, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "tooling",
        .query = .{ .cursor = .{ .offset = 7 }, .limit = 16 },
        .subscription_id = "replay-feed",
        .request_json = "[\"REQ\",\"replay-feed\",{}]",
    };
    var state = client.beginAdvance(&request);

    const wrong_subscription = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = request.relay,
        .message = .{
            .eose = .{
                .subscription_id = "other-feed",
                .stage = .eose_received,
            },
        },
    };
    try std.testing.expectError(
        error.MismatchedSubscription,
        client.acceptReplayOutcome(&state, &wrong_subscription),
    );

    const wrong_relay = relay_replay_exchange.ReplayExchangeOutcome{
        .relay = .{ .relay_index = 2, .relay_url = "wss://relay.two" },
        .message = .{
            .eose = .{
                .subscription_id = request.subscription_id,
                .stage = .eose_received,
            },
        },
    };
    try std.testing.expectError(error.MismatchedRelay, client.acceptReplayOutcome(&state, &wrong_relay));
}
