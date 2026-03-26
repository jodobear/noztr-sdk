const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const mailbox_relay_list_kind: u32 = noztr.nip17_private_messages.dm_relays_kind;
const mailbox_wrap_event_kind: u32 = 1059;

pub const DmCapabilityClientError =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    store.EventArchiveError ||
    noztr.nip17_private_messages.RelayListError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    error{
        InvalidMailboxRelayListEventKind,
        InvalidDmProtocolEventKind,
        RelayListDraftStorageTooSmall,
        TooManyAuthors,
        QueryLimitTooLarge,
        MailboxReplyUnavailable,
    };

pub const DmCapabilityClientConfig = struct {
    publish: publish_client.PublishClientConfig = .{},
    query: relay_query_client.RelayQueryClientConfig = .{},
};

pub const DmCapabilityClientStorage = struct {
    publish: publish_client.PublishClientStorage = .{},
    query: relay_query_client.RelayQueryClientStorage = .{},
};

pub const MailboxRelayListDraft = struct {
    created_at: u64,
    relays: []const []const u8,
};

pub const MailboxRelayListDraftStorage = struct {
    tags: []noztr.nip01_event.EventTag,
    built_tags: []noztr.nip17_private_messages.TagBuilder,

    pub fn init(
        tags: []noztr.nip01_event.EventTag,
        built_tags: []noztr.nip17_private_messages.TagBuilder,
    ) MailboxRelayListDraftStorage {
        return .{
            .tags = tags,
            .built_tags = built_tags,
        };
    }
};

pub const MailboxRelayListQuery = struct {
    authors: []const store.EventPubkeyHex = &.{},
    since: ?u64 = null,
    until: ?u64 = null,
    limit: usize = 0,
};

pub const MailboxRelaySubscriptionRequest = struct {
    subscription_id: []const u8,
    query: MailboxRelayListQuery = .{},
};

pub const MailboxRelaySubscriptionStorage = struct {
    filters: [1]noztr.nip01_filter.Filter = [_]noztr.nip01_filter.Filter{.{}} ** 1,
    specs: [1]runtime.RelaySubscriptionSpec = undefined,
    relay_pool: runtime.RelayPoolSubscriptionStorage = .{},
};

pub const MailboxRelayListInspection = struct {
    relays: []const []const u8,
    relay_count: u16,
};

pub const LatestMailboxRelayListRequest = struct {
    author: store.EventPubkeyHex,
    cursor: ?store.EventCursor = null,
    limit: usize = 0,
};

pub const LatestMailboxRelayList = struct {
    record: store.ClientEventRecord,
    event: noztr.nip01_event.Event,
    relays: []const []const u8,
};

pub const LatestMailboxRelayListResult = struct {
    latest: ?LatestMailboxRelayList = null,
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const DmProtocol = enum {
    mailbox,
    legacy,
};

pub const DmReplyPolicy = enum {
    sender_protocol,
    prefer_mailbox,
    prefer_legacy,
};

pub const DmReplySelectionRequest = struct {
    sender_protocol: DmProtocol,
    policy: DmReplyPolicy = .sender_protocol,
    recipient_mailbox_available: bool = false,
};

pub const DmReplySelectionReason = enum {
    mirrored_sender_protocol,
    preferred_mailbox,
    preferred_legacy,
    fell_back_to_legacy_without_mailbox,
};

pub const DmReplySelection = struct {
    protocol: DmProtocol,
    reason: DmReplySelectionReason,
};

pub const DmCapabilityClient = struct {
    config: DmCapabilityClientConfig,
    publish: publish_client.PublishClient,
    query: relay_query_client.RelayQueryClient,

    pub fn init(
        config: DmCapabilityClientConfig,
        storage: *DmCapabilityClientStorage,
    ) DmCapabilityClient {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.init(config.query, &storage.query),
        };
    }

    pub fn attach(
        config: DmCapabilityClientConfig,
        storage: *DmCapabilityClientStorage,
    ) DmCapabilityClient {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.attach(config.query, &storage.query),
        };
    }

    pub fn addRelay(
        self: *DmCapabilityClient,
        relay_url_text: []const u8,
    ) DmCapabilityClientError!runtime.RelayDescriptor {
        const publish_descriptor = try self.publish.addRelay(relay_url_text);
        const query_descriptor = try self.query.addRelay(relay_url_text);
        std.debug.assert(publish_descriptor.relay_index == query_descriptor.relay_index);
        std.debug.assert(std.mem.eql(u8, publish_descriptor.relay_url, query_descriptor.relay_url));
        return query_descriptor;
    }

    pub fn markRelayConnected(
        self: *DmCapabilityClient,
        relay_index: u8,
    ) DmCapabilityClientError!void {
        try self.publish.markRelayConnected(relay_index);
        try self.query.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *DmCapabilityClient,
        relay_index: u8,
    ) DmCapabilityClientError!void {
        try self.publish.noteRelayDisconnected(relay_index);
        try self.query.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *DmCapabilityClient,
        relay_index: u8,
        challenge: []const u8,
    ) DmCapabilityClientError!void {
        try self.publish.noteRelayAuthChallenge(relay_index, challenge);
        try self.query.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const DmCapabilityClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.query.inspectRelayRuntime(storage);
    }

    pub fn inspectPublish(
        self: *const DmCapabilityClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.publish.inspectPublish(storage);
    }

    pub fn buildMailboxRelayListDraft(
        _: DmCapabilityClient,
        storage: *MailboxRelayListDraftStorage,
        draft: *const MailboxRelayListDraft,
    ) DmCapabilityClientError!local_operator.LocalEventDraft {
        if (draft.relays.len > storage.tags.len) return error.RelayListDraftStorageTooSmall;
        if (draft.relays.len > storage.built_tags.len) return error.RelayListDraftStorageTooSmall;

        for (draft.relays, 0..) |relay_url, index| {
            storage.tags[index] = try noztr.nip17_private_messages.nip17_build_relay_tag(
                &storage.built_tags[index],
                relay_url,
            );
        }

        return .{
            .kind = mailbox_relay_list_kind,
            .created_at = draft.created_at,
            .content = "",
            .tags = storage.tags[0..draft.relays.len],
        };
    }

    pub fn prepareMailboxRelayListPublish(
        self: DmCapabilityClient,
        event_json_output: []u8,
        draft_storage: *MailboxRelayListDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const MailboxRelayListDraft,
    ) DmCapabilityClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildMailboxRelayListDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const DmCapabilityClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) DmCapabilityClientError!publish_client.TargetedPublishEvent {
        return self.publish.composeTargetedPublish(output, step, prepared);
    }

    pub fn inspectMailboxRelayListSubscription(
        self: *const DmCapabilityClient,
        request: *const MailboxRelaySubscriptionRequest,
        storage: *MailboxRelaySubscriptionStorage,
    ) DmCapabilityClientError!runtime.RelayPoolSubscriptionPlan {
        storage.filters[0] = try filterFromMailboxRelayListQuery(&request.query);
        storage.specs[0] = .{
            .subscription_id = request.subscription_id,
            .filters = storage.filters[0..1],
        };
        return self.query.inspectSubscriptions(storage.specs[0..1], &storage.relay_pool);
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const DmCapabilityClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) DmCapabilityClientError!relay_query_client.TargetedSubscriptionRequest {
        return self.query.composeTargetedSubscriptionRequest(output, step);
    }

    pub fn composeTargetedCloseRequest(
        self: *const DmCapabilityClient,
        output: []u8,
        target: *const relay_query_client.RelayQueryTarget,
        subscription_id: []const u8,
    ) DmCapabilityClientError!relay_query_client.TargetedCloseRequest {
        return self.query.composeTargetedCloseRequest(output, target, subscription_id);
    }

    pub fn inspectMailboxRelayListEvent(
        _: DmCapabilityClient,
        event: *const noztr.nip01_event.Event,
        relays_out: [][]const u8,
    ) DmCapabilityClientError!MailboxRelayListInspection {
        if (event.kind != mailbox_relay_list_kind) return error.InvalidMailboxRelayListEventKind;
        const count = try noztr.nip17_private_messages.nip17_relay_list_extract(event, relays_out);
        return .{
            .relays = relays_out[0..count],
            .relay_count = count,
        };
    }

    pub fn storeMailboxRelayListEventJson(
        _: DmCapabilityClient,
        archive: store.EventArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) DmCapabilityClientError!void {
        const event = try parseVerifiedMailboxRelayListEventJson(event_json, scratch);
        if (event.kind != mailbox_relay_list_kind) return error.InvalidMailboxRelayListEventKind;
        return archive.ingestEventJson(event_json, scratch);
    }

    pub fn inspectLatestMailboxRelayList(
        self: DmCapabilityClient,
        archive: store.EventArchive,
        request: *const LatestMailboxRelayListRequest,
        page: *store.EventQueryResultPage,
        relays_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) DmCapabilityClientError!LatestMailboxRelayListResult {
        const authors = [_]store.EventPubkeyHex{request.author};
        const kinds = [_]u32{mailbox_relay_list_kind};
        try archive.query(&.{
            .authors = authors[0..],
            .kinds = kinds[0..],
            .cursor = request.cursor,
            .limit = request.limit,
        }, page);

        for (page.slice()) |record| {
            const event = try parseVerifiedMailboxRelayListEventJson(record.eventJson(), scratch);
            const inspection = try self.inspectMailboxRelayListEvent(&event, relays_out);
            return .{
                .latest = .{
                    .record = record,
                    .event = event,
                    .relays = inspection.relays,
                },
                .truncated = page.truncated,
                .next_cursor = page.next_cursor,
            };
        }

        return .{
            .latest = null,
            .truncated = page.truncated,
            .next_cursor = page.next_cursor,
        };
    }

    pub fn inspectDmProtocolKind(
        _: DmCapabilityClient,
        event_kind: u32,
    ) DmCapabilityClientError!DmProtocol {
        return switch (event_kind) {
            mailbox_wrap_event_kind,
            noztr.nip17_private_messages.dm_kind,
            noztr.nip17_private_messages.file_dm_kind,
            => .mailbox,
            noztr.nip04.dm_kind => .legacy,
            else => error.InvalidDmProtocolEventKind,
        };
    }

    pub fn inspectInboundProtocolEvent(
        self: DmCapabilityClient,
        event: *const noztr.nip01_event.Event,
    ) DmCapabilityClientError!DmProtocol {
        return self.inspectDmProtocolKind(event.kind);
    }

    pub fn selectReplyProtocol(
        _: DmCapabilityClient,
        request: *const DmReplySelectionRequest,
    ) DmCapabilityClientError!DmReplySelection {
        return switch (request.policy) {
            .sender_protocol => switch (request.sender_protocol) {
                .mailbox => {
                    if (!request.recipient_mailbox_available) return error.MailboxReplyUnavailable;
                    return .{
                        .protocol = .mailbox,
                        .reason = .mirrored_sender_protocol,
                    };
                },
                .legacy => .{
                    .protocol = .legacy,
                    .reason = .mirrored_sender_protocol,
                },
            },
            .prefer_mailbox => if (request.recipient_mailbox_available)
                .{
                    .protocol = .mailbox,
                    .reason = .preferred_mailbox,
                }
            else
                .{
                    .protocol = .legacy,
                    .reason = .fell_back_to_legacy_without_mailbox,
                },
            .prefer_legacy => .{
                .protocol = .legacy,
                .reason = .preferred_legacy,
            },
        };
    }
};

fn filterFromMailboxRelayListQuery(
    query: *const MailboxRelayListQuery,
) DmCapabilityClientError!noztr.nip01_filter.Filter {
    var filter = noztr.nip01_filter.Filter{};

    if (query.authors.len > filter.authors.len) return error.TooManyAuthors;
    for (query.authors, 0..) |author_hex, index| {
        _ = std.fmt.hexToBytes(filter.authors[index][0..], author_hex[0..]) catch unreachable;
        filter.authors_prefix_nibbles[index] = @intCast(author_hex.len);
    }
    filter.authors_count = @intCast(query.authors.len);
    filter.kinds[0] = mailbox_relay_list_kind;
    filter.kinds_count = 1;
    filter.since = query.since;
    filter.until = query.until;

    if (query.limit == 0) {
        filter.limit = null;
    } else {
        if (query.limit > std.math.maxInt(u16)) return error.QueryLimitTooLarge;
        filter.limit = @intCast(query.limit);
    }

    return filter;
}

fn parseVerifiedMailboxRelayListEventJson(
    event_json: []const u8,
    scratch: std.mem.Allocator,
) DmCapabilityClientError!noztr.nip01_event.Event {
    const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
    try noztr.nip01_event.event_verify(&event);
    return event;
}

test "dm capability client prepares mailbox relay-list publish and subscription posture" {
    var storage = DmCapabilityClientStorage{};
    var client = DmCapabilityClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x71} ** 32;
    var tag_storage: [2]noztr.nip01_event.EventTag = undefined;
    var built_tag_storage: [2]noztr.nip17_private_messages.TagBuilder = undefined;
    var draft_storage = MailboxRelayListDraftStorage.init(
        tag_storage[0..],
        built_tag_storage[0..],
    );
    var event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareMailboxRelayListPublish(
        event_json[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 80,
            .relays = &.{ "wss://dm.one", "wss://dm.two" },
        },
    );
    try noztr.nip01_event.event_verify(&prepared.event);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_publish = try client.composeTargetedPublish(
        publish_message[0..],
        &publish_step,
        &prepared,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_publish.relay.relay_url);

    const author_hex = std.fmt.bytesToHex(prepared.event.pubkey, .lower);
    var subscription_storage = MailboxRelaySubscriptionStorage{};
    const subscription_plan = try client.inspectMailboxRelayListSubscription(
        &.{
            .subscription_id = "dm-relays",
            .query = .{
                .authors = &.{author_hex},
                .limit = 1,
            },
        },
        &subscription_storage,
    );
    const subscription_step = subscription_plan.nextStep().?;
    var subscription_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_subscription = try client.composeTargetedSubscriptionRequest(
        subscription_message[0..],
        &subscription_step,
    );
    try std.testing.expectEqualStrings("dm-relays", targeted_subscription.subscription_id);

    const target = try client.query.selectSubscriptionTarget(&subscription_step);
    var close_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const close_request = try client.composeTargetedCloseRequest(
        close_message[0..],
        &target,
        targeted_subscription.subscription_id,
    );
    try std.testing.expectEqualStrings("dm-relays", close_request.subscription_id);
}

test "dm capability client stores and selects the latest verified mailbox relay-list event" {
    var storage = DmCapabilityClientStorage{};
    const client = DmCapabilityClient.init(.{}, &storage);

    var memory_store = store.MemoryClientStore{};
    const archive = store.EventArchive.init(memory_store.asClientStore());

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const secret_key = [_]u8{0x61} ** 32;
    var first_tags: [1]noztr.nip01_event.EventTag = undefined;
    var first_built: [1]noztr.nip17_private_messages.TagBuilder = undefined;
    var first_draft_storage = MailboxRelayListDraftStorage.init(first_tags[0..], first_built[0..]);
    var second_tags: [2]noztr.nip01_event.EventTag = undefined;
    var second_built: [2]noztr.nip17_private_messages.TagBuilder = undefined;
    var second_draft_storage = MailboxRelayListDraftStorage.init(second_tags[0..], second_built[0..]);
    var first_json: [noztr.limits.event_json_max]u8 = undefined;
    var second_json: [noztr.limits.event_json_max]u8 = undefined;

    const first_prepared = try client.prepareMailboxRelayListPublish(
        first_json[0..],
        &first_draft_storage,
        &secret_key,
        &.{ .created_at = 50, .relays = &.{"wss://dm.first"} },
    );
    const second_prepared = try client.prepareMailboxRelayListPublish(
        second_json[0..],
        &second_draft_storage,
        &secret_key,
        &.{ .created_at = 60, .relays = &.{ "wss://dm.second", "wss://dm.third" } },
    );

    try client.storeMailboxRelayListEventJson(archive, first_prepared.event_json, arena.allocator());
    try client.storeMailboxRelayListEventJson(archive, second_prepared.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(second_prepared.event.pubkey, .lower);
    var page_storage: [2]store.ClientEventRecord = undefined;
    var page = store.EventQueryResultPage.init(page_storage[0..]);
    var relays_out: [4][]const u8 = undefined;
    const inspection = try client.inspectLatestMailboxRelayList(
        archive,
        &.{ .author = author_hex, .limit = 2 },
        &page,
        relays_out[0..],
        arena.allocator(),
    );

    try std.testing.expect(inspection.latest != null);
    try std.testing.expectEqual(@as(usize, 2), inspection.latest.?.relays.len);
    try std.testing.expectEqualStrings("wss://dm.second", inspection.latest.?.relays[0]);
    try std.testing.expectEqualStrings("wss://dm.third", inspection.latest.?.relays[1]);
}

test "dm capability client classifies protocols and keeps reply-policy selection explicit" {
    var storage = DmCapabilityClientStorage{};
    const client = DmCapabilityClient.init(.{}, &storage);

    try std.testing.expectEqual(.mailbox, try client.inspectDmProtocolKind(mailbox_wrap_event_kind));
    try std.testing.expectEqual(.mailbox, try client.inspectDmProtocolKind(noztr.nip17_private_messages.dm_kind));
    try std.testing.expectEqual(.legacy, try client.inspectDmProtocolKind(noztr.nip04.dm_kind));
    try std.testing.expectError(error.InvalidDmProtocolEventKind, client.inspectDmProtocolKind(1));

    const mirrored_legacy = try client.selectReplyProtocol(&.{
        .sender_protocol = .legacy,
    });
    try std.testing.expectEqual(.legacy, mirrored_legacy.protocol);
    try std.testing.expectEqual(.mirrored_sender_protocol, mirrored_legacy.reason);

    try std.testing.expectError(error.MailboxReplyUnavailable, client.selectReplyProtocol(&.{
        .sender_protocol = .mailbox,
        .policy = .sender_protocol,
        .recipient_mailbox_available = false,
    }));

    const preferred_mailbox = try client.selectReplyProtocol(&.{
        .sender_protocol = .legacy,
        .policy = .prefer_mailbox,
        .recipient_mailbox_available = true,
    });
    try std.testing.expectEqual(.mailbox, preferred_mailbox.protocol);
    try std.testing.expectEqual(.preferred_mailbox, preferred_mailbox.reason);

    const fallback_legacy = try client.selectReplyProtocol(&.{
        .sender_protocol = .mailbox,
        .policy = .prefer_mailbox,
        .recipient_mailbox_available = false,
    });
    try std.testing.expectEqual(.legacy, fallback_legacy.protocol);
    try std.testing.expectEqual(.fell_back_to_legacy_without_mailbox, fallback_legacy.reason);
}
