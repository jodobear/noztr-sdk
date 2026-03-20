const std = @import("std");
const noztr = @import("noztr");

pub const RelayResponseClientError =
    noztr.nip01_message.MessageParseError ||
    error{
        InvalidTranscriptTransition,
        UnexpectedRelayMessage,
        UnexpectedSubscriptionId,
        UnexpectedEventId,
    };

pub const RelayResponseClientConfig = struct {};

pub const RelaySubscriptionTranscriptStorage = struct {
    state: noztr.nip01_message.TranscriptState = .{},

    pub fn subscriptionId(self: *const RelaySubscriptionTranscriptStorage) []const u8 {
        return self.state.subscription_id[0..self.state.subscription_id_len];
    }
};

pub const RelaySubscriptionEventMessage = struct {
    subscription_id: []const u8,
    event: noztr.nip01_event.Event,
    stage: noztr.nip01_message.TranscriptStage,
};

pub const RelaySubscriptionEoseMessage = struct {
    subscription_id: []const u8,
    stage: noztr.nip01_message.TranscriptStage,
};

pub const RelaySubscriptionClosedMessage = struct {
    subscription_id: []const u8,
    status: []const u8,
    stage: noztr.nip01_message.TranscriptStage,
};

pub const RelaySubscriptionMessageOutcome = union(enum) {
    event: RelaySubscriptionEventMessage,
    eose: RelaySubscriptionEoseMessage,
    closed: RelaySubscriptionClosedMessage,
};

pub const RelayCountMessage = struct {
    subscription_id: []const u8,
    count: u64,
};

pub const RelayPublishOkMessage = struct {
    event_id: [32]u8,
    accepted: bool,
    status: []const u8,
};

pub const RelayNoticeMessage = struct {
    message: []const u8,
};

pub const RelayAuthChallengeMessage = struct {
    challenge: []const u8,
};

pub const RelayResponseClient = struct {
    config: RelayResponseClientConfig,

    pub fn init(config: RelayResponseClientConfig) RelayResponseClient {
        return .{ .config = config };
    }

    pub fn parseRelayMessageJson(
        self: RelayResponseClient,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayResponseClientError!noztr.nip01_message.RelayMessage {
        _ = self;
        return noztr.nip01_message.relay_message_parse_json(relay_message_json, scratch);
    }

    pub fn beginSubscriptionTranscript(
        self: RelayResponseClient,
        storage: *RelaySubscriptionTranscriptStorage,
        subscription_id: []const u8,
    ) RelayResponseClientError!void {
        _ = self;
        storage.* = .{};
        return noztr.nip01_message.transcript_mark_client_req(&storage.state, subscription_id);
    }

    pub fn acceptSubscriptionMessageJson(
        self: RelayResponseClient,
        storage: *RelaySubscriptionTranscriptStorage,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayResponseClientError!RelaySubscriptionMessageOutcome {
        const message = try self.parseRelayMessageJson(relay_message_json, scratch);
        return self.acceptSubscriptionMessage(storage, message);
    }

    pub fn acceptSubscriptionMessage(
        self: RelayResponseClient,
        storage: *RelaySubscriptionTranscriptStorage,
        message: noztr.nip01_message.RelayMessage,
    ) RelayResponseClientError!RelaySubscriptionMessageOutcome {
        _ = self;
        switch (message) {
            .event => |event_message| {
                try noztr.nip01_message.transcript_apply_relay(&storage.state, message);
                return .{
                    .event = .{
                        .subscription_id = event_message.subscription_id,
                        .event = event_message.event,
                        .stage = storage.state.stage,
                    },
                };
            },
            .eose => |eose_message| {
                try noztr.nip01_message.transcript_apply_relay(&storage.state, message);
                return .{
                    .eose = .{
                        .subscription_id = eose_message.subscription_id,
                        .stage = storage.state.stage,
                    },
                };
            },
            .closed => |closed_message| {
                try noztr.nip01_message.transcript_apply_relay(&storage.state, message);
                return .{
                    .closed = .{
                        .subscription_id = closed_message.subscription_id,
                        .status = closed_message.status,
                        .stage = storage.state.stage,
                    },
                };
            },
            else => return error.UnexpectedRelayMessage,
        }
    }

    pub fn acceptCountMessageJson(
        self: RelayResponseClient,
        expected_subscription_id: []const u8,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayResponseClientError!RelayCountMessage {
        const message = try self.parseRelayMessageJson(relay_message_json, scratch);
        return self.acceptCountMessage(expected_subscription_id, message);
    }

    pub fn acceptCountMessage(
        self: RelayResponseClient,
        expected_subscription_id: []const u8,
        message: noztr.nip01_message.RelayMessage,
    ) RelayResponseClientError!RelayCountMessage {
        _ = self;
        switch (message) {
            .count => |count_message| {
                if (!std.mem.eql(u8, expected_subscription_id, count_message.subscription_id)) {
                    return error.UnexpectedSubscriptionId;
                }
                return .{
                    .subscription_id = count_message.subscription_id,
                    .count = count_message.count,
                };
            },
            else => return error.UnexpectedRelayMessage,
        }
    }

    pub fn acceptPublishOkJson(
        self: RelayResponseClient,
        expected_event_id: *const [32]u8,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayResponseClientError!RelayPublishOkMessage {
        const message = try self.parseRelayMessageJson(relay_message_json, scratch);
        return self.acceptPublishOk(expected_event_id, message);
    }

    pub fn acceptPublishOk(
        self: RelayResponseClient,
        expected_event_id: *const [32]u8,
        message: noztr.nip01_message.RelayMessage,
    ) RelayResponseClientError!RelayPublishOkMessage {
        _ = self;
        switch (message) {
            .ok => |ok_message| {
                if (!std.mem.eql(u8, expected_event_id, &ok_message.event_id)) {
                    return error.UnexpectedEventId;
                }
                return .{
                    .event_id = ok_message.event_id,
                    .accepted = ok_message.accepted,
                    .status = ok_message.status,
                };
            },
            else => return error.UnexpectedRelayMessage,
        }
    }

    pub fn acceptNoticeJson(
        self: RelayResponseClient,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayResponseClientError!RelayNoticeMessage {
        const message = try self.parseRelayMessageJson(relay_message_json, scratch);
        return self.acceptNotice(message);
    }

    pub fn acceptNotice(
        self: RelayResponseClient,
        message: noztr.nip01_message.RelayMessage,
    ) RelayResponseClientError!RelayNoticeMessage {
        _ = self;
        switch (message) {
            .notice => |notice_message| return .{ .message = notice_message.message },
            else => return error.UnexpectedRelayMessage,
        }
    }

    pub fn acceptAuthChallengeJson(
        self: RelayResponseClient,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) RelayResponseClientError!RelayAuthChallengeMessage {
        const message = try self.parseRelayMessageJson(relay_message_json, scratch);
        return self.acceptAuthChallenge(message);
    }

    pub fn acceptAuthChallenge(
        self: RelayResponseClient,
        message: noztr.nip01_message.RelayMessage,
    ) RelayResponseClientError!RelayAuthChallengeMessage {
        _ = self;
        switch (message) {
            .auth => |auth_message| return .{ .challenge = auth_message.challenge },
            else => return error.UnexpectedRelayMessage,
        }
    }
};

test "relay response client accepts subscription event eose and closed transcript intake" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client = RelayResponseClient.init(.{});
    var storage = RelaySubscriptionTranscriptStorage{};
    try client.beginSubscriptionTranscript(&storage, "feed");

    const event = try sampleSignedEvent();

    var event_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const event_message_json = try relayMessageJson(event_json[0..], .{
        .event = .{
            .subscription_id = "feed",
            .event = event,
        },
    });
    const event_outcome = try client.acceptSubscriptionMessageJson(
        &storage,
        event_message_json,
        arena.allocator(),
    );
    try std.testing.expect(event_outcome == .event);
    try std.testing.expectEqualStrings("feed", event_outcome.event.subscription_id);
    try std.testing.expectEqual(noztr.nip01_message.TranscriptStage.req_sent, event_outcome.event.stage);

    var eose_json: [128]u8 = undefined;
    const eose_message_json = try relayMessageJson(eose_json[0..], .{
        .eose = .{ .subscription_id = "feed" },
    });
    const eose_outcome = try client.acceptSubscriptionMessageJson(
        &storage,
        eose_message_json,
        arena.allocator(),
    );
    try std.testing.expect(eose_outcome == .eose);
    try std.testing.expectEqual(noztr.nip01_message.TranscriptStage.eose_received, eose_outcome.eose.stage);

    var closed_json: [256]u8 = undefined;
    const closed_message_json = try relayMessageJson(closed_json[0..], .{
        .closed = .{
            .subscription_id = "feed",
            .status = "error: done",
        },
    });
    const closed_outcome = try client.acceptSubscriptionMessageJson(
        &storage,
        closed_message_json,
        arena.allocator(),
    );
    try std.testing.expect(closed_outcome == .closed);
    try std.testing.expectEqual(noztr.nip01_message.TranscriptStage.closed, closed_outcome.closed.stage);
}

test "relay response client rejects wrong transcript ordering and non transcript variants" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client = RelayResponseClient.init(.{});
    var storage = RelaySubscriptionTranscriptStorage{};
    try client.beginSubscriptionTranscript(&storage, "feed");

    const event = try sampleSignedEvent();
    var wrong_event_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const wrong_event_message_json = try relayMessageJson(wrong_event_json[0..], .{
        .event = .{
            .subscription_id = "other",
            .event = event,
        },
    });
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        client.acceptSubscriptionMessageJson(&storage, wrong_event_message_json, arena.allocator()),
    );

    var notice_json: [128]u8 = undefined;
    const notice_message_json = try relayMessageJson(notice_json[0..], .{
        .notice = .{ .message = "heads up" },
    });
    try std.testing.expectError(
        error.UnexpectedRelayMessage,
        client.acceptSubscriptionMessageJson(&storage, notice_message_json, arena.allocator()),
    );
}

test "relay response client accepts count response and rejects wrong subscription id" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client = RelayResponseClient.init(.{});
    var count_json: [128]u8 = undefined;
    const count_message_json = try relayMessageJson(count_json[0..], .{
        .count = .{
            .subscription_id = "count-feed",
            .count = 42,
        },
    });
    const count_outcome = try client.acceptCountMessageJson(
        "count-feed",
        count_message_json,
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u64, 42), count_outcome.count);

    try std.testing.expectError(
        error.UnexpectedSubscriptionId,
        client.acceptCountMessageJson("other", count_message_json, arena.allocator()),
    );
}

test "relay response client accepts publish ok and rejects wrong event id" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client = RelayResponseClient.init(.{});
    const event = try sampleSignedEvent();
    const other_event = try sampleSignedEventWithCreatedAt(9);

    var ok_json: [256]u8 = undefined;
    const ok_message_json = try relayMessageJson(ok_json[0..], .{
        .ok = .{
            .event_id = event.id,
            .accepted = true,
            .status = "",
        },
    });
    const ok_outcome = try client.acceptPublishOkJson(&event.id, ok_message_json, arena.allocator());
    try std.testing.expect(ok_outcome.accepted);

    try std.testing.expectError(
        error.UnexpectedEventId,
        client.acceptPublishOkJson(&other_event.id, ok_message_json, arena.allocator()),
    );
}

test "relay response client accepts notice and auth messages only through the matching helpers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client = RelayResponseClient.init(.{});

    var notice_json: [128]u8 = undefined;
    const notice_message_json = try relayMessageJson(notice_json[0..], .{
        .notice = .{ .message = "heads up" },
    });
    const notice = try client.acceptNoticeJson(notice_message_json, arena.allocator());
    try std.testing.expectEqualStrings("heads up", notice.message);

    var auth_json: [128]u8 = undefined;
    const auth_message_json = try relayMessageJson(auth_json[0..], .{
        .auth = .{ .challenge = "challenge-1" },
    });
    const auth = try client.acceptAuthChallengeJson(auth_message_json, arena.allocator());
    try std.testing.expectEqualStrings("challenge-1", auth.challenge);

    try std.testing.expectError(
        error.UnexpectedRelayMessage,
        client.acceptNoticeJson(auth_message_json, arena.allocator()),
    );
}

fn sampleSignedEvent() noztr.nostr_keys.NostrKeysError!noztr.nip01_event.Event {
    return sampleSignedEventWithCreatedAt(7);
}

fn sampleSignedEventWithCreatedAt(
    created_at: u64,
) noztr.nostr_keys.NostrKeysError!noztr.nip01_event.Event {
    const secret_key = [_]u8{0x11} ** 32;
    const public_key = try noztr.nostr_keys.nostr_derive_public_key(&secret_key);
    var event: noztr.nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = created_at,
        .tags = &.{},
        .content = "hello relay response",
    };
    try noztr.nostr_keys.nostr_sign_event(&secret_key, &event);
    return event;
}

fn relayMessageJson(
    output: []u8,
    message: noztr.nip01_message.RelayMessage,
) noztr.nip01_message.MessageEncodeError![]const u8 {
    return noztr.nip01_message.relay_message_serialize_json(output, &message);
}
