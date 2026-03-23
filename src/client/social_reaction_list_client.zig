const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const social_support = @import("social_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const reaction_event_kind: u32 = noztr.nip25_reactions.reaction_event_kind;

pub const SocialReactionListClientError =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    store.EventArchiveError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip25_reactions.ReactionError ||
    noztr.nip51_lists.ListError ||
    error{
        InvalidReactionEventKind,
        InvalidListEventKind,
        TooManyAuthors,
        TooManyKinds,
        QueryLimitTooLarge,
        MissingListIdentifier,
        UnexpectedListIdentifier,
        ReactionDraftStorageTooSmall,
        ListDraftStorageTooSmall,
        InvalidReactionEmoji,
        InvalidReactionAuthorHint,
    };

pub const SocialReactionListClientConfig = social_support.ClientConfig;

pub const SocialReactionListClientStorage = social_support.ClientStorage;

pub const SocialReactionEmojiReference = struct {
    image_url: []const u8,
    set_coordinate: ?noztr.nip25_reactions.ReactionCoordinate = null,
};

pub const SocialReactionDraft = struct {
    created_at: u64,
    content: []const u8,
    target_event_id: [32]u8,
    event_hint: ?[]const u8 = null,
    author_pubkey: ?[32]u8 = null,
    author_hint: ?[]const u8 = null,
    coordinate: ?noztr.nip25_reactions.ReactionCoordinate = null,
    reacted_kind: ?u32 = null,
    custom_emoji: ?SocialReactionEmojiReference = null,
};

pub const SocialReactionDraftStorage = struct {
    tags: [5]noztr.nip01_event.EventTag = undefined,
    event_tag_items: [3][]const u8 = undefined,
    pubkey_tag_items: [3][]const u8 = undefined,
    coordinate_tag_items: [3][]const u8 = undefined,
    kind_tag_items: [2][]const u8 = undefined,
    emoji_tag_items: [4][]const u8 = undefined,
    event_id_hex: [64]u8 = undefined,
    author_pubkey_hex: [64]u8 = undefined,
    coordinate_text: [noztr.limits.tag_item_bytes_max]u8 = undefined,
    emoji_set_coordinate_text: [noztr.limits.tag_item_bytes_max]u8 = undefined,
    kind_text: [20]u8 = undefined,
};

pub const SocialListDraft = struct {
    kind: noztr.nip51_lists.ListKind,
    created_at: u64,
    identifier: ?[]const u8 = null,
    content: []const u8 = "",
    tags: []const noztr.nip01_event.EventTag = &.{},
};

pub const SocialListDraftStorage = struct {
    identifier_tag: noztr.nip51_lists.TagBuilder = undefined,
    tags: []noztr.nip01_event.EventTag,

    pub fn init(tags: []noztr.nip01_event.EventTag) SocialListDraftStorage {
        return .{ .tags = tags };
    }
};

pub const SocialEventQuery = social_support.AuthorTimeQuery;

pub const SocialReactionSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialEventQuery = .{},
};

pub const SocialListSubscriptionRequest = struct {
    subscription_id: []const u8,
    kind: noztr.nip51_lists.ListKind,
    query: SocialEventQuery = .{},
};

pub const SocialSubscriptionPlanStorage = social_support.SubscriptionPlanStorage;

pub const StoredSocialListSelectionRequest = struct {
    author: store.EventPubkeyHex,
    kind: noztr.nip51_lists.ListKind,
    identifier: ?[]const u8 = null,
    cursor: ?store.EventCursor = null,
    limit: usize = 0,
};

pub const StoredSocialListSelection = struct {
    record: store.ClientEventRecord,
    event: noztr.nip01_event.Event,
    info: noztr.nip51_lists.List,
    items: []const noztr.nip51_lists.ListItem,
};

pub const StoredSocialListInspection = struct {
    selection: ?StoredSocialListSelection = null,
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const SocialReactionListClient = struct {
    config: SocialReactionListClientConfig,
    publish: publish_client.PublishClient,
    query: relay_query_client.RelayQueryClient,

    pub fn init(
        config: SocialReactionListClientConfig,
        storage: *SocialReactionListClientStorage,
    ) SocialReactionListClient {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.init(config.query, &storage.query),
        };
    }

    pub fn attach(
        config: SocialReactionListClientConfig,
        storage: *SocialReactionListClientStorage,
    ) SocialReactionListClient {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.attach(config.query, &storage.query),
        };
    }

    pub fn addRelay(
        self: *SocialReactionListClient,
        relay_url_text: []const u8,
    ) SocialReactionListClientError!runtime.RelayDescriptor {
        return social_support.addRelay(&self.publish, &self.query, relay_url_text);
    }

    pub fn markRelayConnected(
        self: *SocialReactionListClient,
        relay_index: u8,
    ) SocialReactionListClientError!void {
        try social_support.markRelayConnected(&self.publish, &self.query, relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *SocialReactionListClient,
        relay_index: u8,
    ) SocialReactionListClientError!void {
        try social_support.noteRelayDisconnected(&self.publish, &self.query, relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *SocialReactionListClient,
        relay_index: u8,
        challenge: []const u8,
    ) SocialReactionListClientError!void {
        try social_support.noteRelayAuthChallenge(
            &self.publish,
            &self.query,
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const SocialReactionListClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return social_support.inspectRelayRuntime(&self.query, storage);
    }

    pub fn inspectPublish(
        self: *const SocialReactionListClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return social_support.inspectPublish(&self.publish, storage);
    }

    pub fn buildReactionDraft(
        self: SocialReactionListClient,
        storage: *SocialReactionDraftStorage,
        draft: *const SocialReactionDraft,
    ) SocialReactionListClientError!local_operator.LocalEventDraft {
        _ = self;

        const reaction_type = try noztr.nip25_reactions.reaction_classify_content(draft.content);
        if (reaction_type == .custom_emoji) {
            if (draft.custom_emoji == null) return error.InvalidReactionEmoji;
        } else if (draft.custom_emoji != null) {
            return error.InvalidReactionEmoji;
        }

        var tag_count: usize = 0;

        const event_id_hex = std.fmt.bytesToHex(draft.target_event_id, .lower);
        @memcpy(storage.event_id_hex[0..], event_id_hex[0..]);
        storage.event_tag_items[0] = "e";
        storage.event_tag_items[1] = storage.event_id_hex[0..];
        var event_tag_len: usize = 2;
        if (draft.event_hint) |event_hint| {
            storage.event_tag_items[event_tag_len] = event_hint;
            event_tag_len += 1;
        }
        storage.tags[tag_count] = .{ .items = storage.event_tag_items[0..event_tag_len] };
        tag_count += 1;

        if (draft.author_pubkey) |author_pubkey| {
            const author_hex = std.fmt.bytesToHex(author_pubkey, .lower);
            @memcpy(storage.author_pubkey_hex[0..], author_hex[0..]);
            storage.pubkey_tag_items[0] = "p";
            storage.pubkey_tag_items[1] = storage.author_pubkey_hex[0..];
            var pubkey_tag_len: usize = 2;
            if (draft.author_hint) |author_hint| {
                storage.pubkey_tag_items[pubkey_tag_len] = author_hint;
                pubkey_tag_len += 1;
            }
            storage.tags[tag_count] = .{ .items = storage.pubkey_tag_items[0..pubkey_tag_len] };
            tag_count += 1;
        } else if (draft.author_hint != null) {
            return error.InvalidReactionAuthorHint;
        }

        if (draft.coordinate) |coordinate| {
            storage.coordinate_tag_items[0] = "a";
            storage.coordinate_tag_items[1] = try formatCoordinate(
                storage.coordinate_text[0..],
                coordinate,
            );
            var coordinate_tag_len: usize = 2;
            if (coordinate.relay_hint) |relay_hint| {
                storage.coordinate_tag_items[coordinate_tag_len] = relay_hint;
                coordinate_tag_len += 1;
            }
            storage.tags[tag_count] = .{ .items = storage.coordinate_tag_items[0..coordinate_tag_len] };
            tag_count += 1;
        }

        if (draft.reacted_kind) |reacted_kind| {
            storage.kind_tag_items[0] = "k";
            storage.kind_tag_items[1] = std.fmt.bufPrint(
                storage.kind_text[0..],
                "{d}",
                .{reacted_kind},
            ) catch return error.ReactionDraftStorageTooSmall;
            storage.tags[tag_count] = .{ .items = storage.kind_tag_items[0..2] };
            tag_count += 1;
        }

        if (draft.custom_emoji) |custom_emoji| {
            storage.emoji_tag_items[0] = "emoji";
            storage.emoji_tag_items[1] = customEmojiShortcode(draft.content) orelse {
                return error.InvalidReactionEmoji;
            };
            storage.emoji_tag_items[2] = custom_emoji.image_url;
            var emoji_tag_len: usize = 3;
            if (custom_emoji.set_coordinate) |set_coordinate| {
                storage.emoji_tag_items[emoji_tag_len] = try formatCoordinate(
                    storage.emoji_set_coordinate_text[0..],
                    set_coordinate,
                );
                emoji_tag_len += 1;
            }
            storage.tags[tag_count] = .{ .items = storage.emoji_tag_items[0..emoji_tag_len] };
            tag_count += 1;
        }

        return .{
            .kind = reaction_event_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..tag_count],
        };
    }

    pub fn prepareReactionPublish(
        self: SocialReactionListClient,
        event_json_output: []u8,
        draft_storage: *SocialReactionDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const SocialReactionDraft,
    ) SocialReactionListClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildReactionDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn buildListDraft(
        self: SocialReactionListClient,
        storage: *SocialListDraftStorage,
        draft: *const SocialListDraft,
    ) SocialReactionListClientError!local_operator.LocalEventDraft {
        _ = self;

        const needs_identifier = listKindRequiresIdentifier(draft.kind);
        if (needs_identifier and draft.identifier == null) return error.MissingListIdentifier;
        if (!needs_identifier and draft.identifier != null) return error.UnexpectedListIdentifier;

        const extra_tag_count: usize = if (draft.identifier != null) 1 else 0;
        if (extra_tag_count + draft.tags.len > storage.tags.len) return error.ListDraftStorageTooSmall;

        var tag_index: usize = 0;
        if (draft.identifier) |identifier| {
            storage.tags[tag_index] = try noztr.nip51_lists.list_build_identifier_tag(
                &storage.identifier_tag,
                identifier,
            );
            tag_index += 1;
        }
        for (draft.tags) |tag| {
            storage.tags[tag_index] = tag;
            tag_index += 1;
        }

        return .{
            .kind = @intFromEnum(draft.kind),
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..tag_index],
        };
    }

    pub fn prepareListPublish(
        self: SocialReactionListClient,
        event_json_output: []u8,
        draft_storage: *SocialListDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const SocialListDraft,
    ) SocialReactionListClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildListDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const SocialReactionListClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) SocialReactionListClientError!publish_client.TargetedPublishEvent {
        return self.publish.composeTargetedPublish(output, step, prepared);
    }

    pub fn inspectReactionSubscription(
        self: *const SocialReactionListClient,
        request: *const SocialReactionSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialReactionListClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{reaction_event_kind};
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn inspectListSubscription(
        self: *const SocialReactionListClient,
        request: *const SocialListSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialReactionListClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{@intFromEnum(request.kind)};
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const SocialReactionListClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) SocialReactionListClientError!relay_query_client.TargetedSubscriptionRequest {
        return social_support.composeTargetedSubscriptionRequest(&self.query, output, step);
    }

    pub fn composeTargetedCloseRequest(
        self: *const SocialReactionListClient,
        output: []u8,
        target: *const relay_query_client.RelayQueryTarget,
        subscription_id: []const u8,
    ) SocialReactionListClientError!relay_query_client.TargetedCloseRequest {
        return social_support.composeTargetedCloseRequest(
            &self.query,
            output,
            target,
            subscription_id,
        );
    }

    pub fn inspectReactionEvent(
        self: SocialReactionListClient,
        event: *const noztr.nip01_event.Event,
    ) SocialReactionListClientError!noztr.nip25_reactions.ReactionTarget {
        _ = self;
        if (event.kind != reaction_event_kind) return error.InvalidReactionEventKind;
        return noztr.nip25_reactions.reaction_parse(event);
    }

    pub fn inspectListEvent(
        self: SocialReactionListClient,
        event: *const noztr.nip01_event.Event,
        items_out: []noztr.nip51_lists.ListItem,
    ) SocialReactionListClientError!noztr.nip51_lists.List {
        _ = self;
        if (noztr.nip51_lists.list_kind_classify(event.kind) == null) {
            return error.InvalidListEventKind;
        }
        return noztr.nip51_lists.list_extract(event, items_out);
    }

    pub fn storeListEventJson(
        self: SocialReactionListClient,
        archive: store.EventArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) SocialReactionListClientError!void {
        _ = self;
        return archive.ingestEventJson(event_json, scratch);
    }

    pub fn inspectLatestStoredList(
        self: SocialReactionListClient,
        archive: store.EventArchive,
        request: *const StoredSocialListSelectionRequest,
        page: *store.EventQueryResultPage,
        items_out: []noztr.nip51_lists.ListItem,
        scratch: std.mem.Allocator,
    ) SocialReactionListClientError!StoredSocialListInspection {
        _ = self;

        const authors = [_]store.EventPubkeyHex{request.author};
        const kinds = [_]u32{@intFromEnum(request.kind)};
        try archive.query(&.{
            .authors = authors[0..],
            .kinds = kinds[0..],
            .cursor = request.cursor,
            .limit = request.limit,
        }, page);

        for (page.slice()) |record| {
            const event = try noztr.nip01_event.event_parse_json(record.eventJson(), scratch);
            const info = try noztr.nip51_lists.list_extract(&event, items_out);
            if (request.identifier) |identifier| {
                if (info.metadata.identifier == null) continue;
                if (!std.mem.eql(u8, info.metadata.identifier.?, identifier)) continue;
            }

            return .{
                .selection = .{
                    .record = record,
                    .event = event,
                    .info = info,
                    .items = items_out[0..info.item_count],
                },
                .truncated = page.truncated,
                .next_cursor = page.next_cursor,
            };
        }

        return .{
            .selection = null,
            .truncated = page.truncated,
            .next_cursor = page.next_cursor,
        };
    }

    fn inspectSingleSubscription(
        self: *const SocialReactionListClient,
        subscription_id: []const u8,
        query: *const SocialEventQuery,
        kinds: []const u32,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialReactionListClientError!runtime.RelayPoolSubscriptionPlan {
        return social_support.inspectSingleSubscription(
            &self.query,
            subscription_id,
            query,
            kinds,
            storage,
        );
    }
};

fn listKindRequiresIdentifier(kind: noztr.nip51_lists.ListKind) bool {
    return switch (kind) {
        .follow_set,
        .relay_set,
        .bookmark_set,
        .articles_curation_set,
        .interest_set,
        .emoji_set,
        => true,
        else => false,
    };
}

fn formatCoordinate(
    output: []u8,
    coordinate: noztr.nip25_reactions.ReactionCoordinate,
) SocialReactionListClientError![]const u8 {
    const pubkey_hex = std.fmt.bytesToHex(coordinate.pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{d}:{s}:{s}",
        .{ coordinate.kind, pubkey_hex[0..], coordinate.identifier },
    ) catch error.ReactionDraftStorageTooSmall;
}

fn customEmojiShortcode(content: []const u8) ?[]const u8 {
    if (content.len < 3) return null;
    if (content[0] != ':' or content[content.len - 1] != ':') return null;
    return content[1 .. content.len - 1];
}

test "social reaction list client composes reaction and list publish plus bounded subscriptions" {
    var storage = SocialReactionListClientStorage{};
    var client = SocialReactionListClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x31} ** 32;

    var reaction_storage = SocialReactionDraftStorage{};
    var reaction_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_reaction = try client.prepareReactionPublish(
        reaction_event_json[0..],
        &reaction_storage,
        &secret_key,
        &.{
            .created_at = 10,
            .content = "+",
            .target_event_id = [_]u8{0x11} ** 32,
        },
    );
    const parsed_reaction = try client.inspectReactionEvent(&prepared_reaction.event);
    try std.testing.expectEqual(noztr.nip25_reactions.ReactionType.like, parsed_reaction.reaction_type);

    var reaction_subscription_storage = SocialSubscriptionPlanStorage{};
    const reaction_plan = try client.inspectReactionSubscription(
        &.{
            .subscription_id = "reactions",
            .query = .{ .limit = 20 },
        },
        &reaction_subscription_storage,
    );
    const reaction_step = reaction_plan.nextStep().?;
    var reaction_request_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const reaction_request = try client.composeTargetedSubscriptionRequest(
        reaction_request_json[0..],
        &reaction_step,
    );
    try std.testing.expect(std.mem.indexOf(u8, reaction_request.request_json, "\"kinds\":[7]") != null);

    const follow_pubkey = [_]u8{0x44} ** 32;
    const follow_pubkey_hex = std.fmt.bytesToHex(follow_pubkey, .lower);
    const follow_tag_items = [_][]const u8{ "p", follow_pubkey_hex[0..] };
    const follow_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = follow_tag_items[0..] },
    };
    var list_tags: [2]noztr.nip01_event.EventTag = undefined;
    var list_storage = SocialListDraftStorage.init(list_tags[0..]);
    var list_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_list = try client.prepareListPublish(
        list_event_json[0..],
        &list_storage,
        &secret_key,
        &.{
            .kind = .follow_set,
            .created_at = 11,
            .identifier = "friends",
            .tags = follow_tags[0..],
        },
    );
    var list_items: [2]noztr.nip51_lists.ListItem = undefined;
    const list_info = try client.inspectListEvent(&prepared_list.event, list_items[0..]);
    try std.testing.expectEqual(noztr.nip51_lists.ListKind.follow_set, list_info.kind);
    try std.testing.expectEqualStrings("friends", list_info.metadata.identifier.?);

    const author_hex = std.fmt.bytesToHex(prepared_list.event.pubkey, .lower);
    const authors = [_]store.EventPubkeyHex{author_hex};
    var list_subscription_storage = SocialSubscriptionPlanStorage{};
    const list_plan = try client.inspectListSubscription(
        &.{
            .subscription_id = "follow-sets",
            .kind = .follow_set,
            .query = .{
                .authors = authors[0..],
                .limit = 5,
            },
        },
        &list_subscription_storage,
    );
    const list_step = list_plan.nextStep().?;
    var list_request_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const list_request = try client.composeTargetedSubscriptionRequest(
        list_request_json[0..],
        &list_step,
    );
    try std.testing.expect(std.mem.indexOf(u8, list_request.request_json, "\"kinds\":[30000]") != null);
}

test "social reaction list client selects the latest stored list explicitly over the archive seam" {
    var storage = SocialReactionListClientStorage{};
    const client = SocialReactionListClient.init(.{}, &storage);

    var backing_store = store.MemoryClientStore{};
    const archive = store.EventArchive.init(backing_store.asClientStore());
    const secret_key = [_]u8{0x51} ** 32;
    const followed_one = [_]u8{0x61} ** 32;
    const followed_two = [_]u8{0x62} ** 32;
    const followed_one_hex = std.fmt.bytesToHex(followed_one, .lower);
    const followed_two_hex = std.fmt.bytesToHex(followed_two, .lower);

    const first_follow_tag_items = [_][]const u8{ "p", followed_one_hex[0..] };
    const second_follow_tag_items = [_][]const u8{ "p", followed_two_hex[0..] };
    const first_follow_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = first_follow_tag_items[0..] },
    };
    const second_follow_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = second_follow_tag_items[0..] },
    };

    var first_list_tags: [2]noztr.nip01_event.EventTag = undefined;
    var first_storage = SocialListDraftStorage.init(first_list_tags[0..]);
    var first_event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const first_prepared = try client.prepareListPublish(
        first_event_json_buffer[0..],
        &first_storage,
        &secret_key,
        &.{
            .kind = .follow_set,
            .created_at = 10,
            .identifier = "team",
            .tags = first_follow_tags[0..],
        },
    );

    var second_list_tags: [2]noztr.nip01_event.EventTag = undefined;
    var second_storage = SocialListDraftStorage.init(second_list_tags[0..]);
    var second_event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const second_prepared = try client.prepareListPublish(
        second_event_json_buffer[0..],
        &second_storage,
        &secret_key,
        &.{
            .kind = .follow_set,
            .created_at = 20,
            .identifier = "team",
            .tags = second_follow_tags[0..],
        },
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try client.storeListEventJson(archive, first_prepared.event_json, arena.allocator());
    try client.storeListEventJson(archive, second_prepared.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(second_prepared.event.pubkey, .lower);
    var page_storage: [2]store.ClientEventRecord = undefined;
    var page = store.EventQueryResultPage.init(page_storage[0..]);
    var items: [2]noztr.nip51_lists.ListItem = undefined;
    const inspection = try client.inspectLatestStoredList(
        archive,
        &.{
            .author = author_hex,
            .kind = .follow_set,
            .identifier = "team",
        },
        &page,
        items[0..],
        arena.allocator(),
    );
    try std.testing.expect(inspection.selection != null);
    try std.testing.expectEqual(@as(u64, 20), inspection.selection.?.event.created_at);
    try std.testing.expectEqualStrings("team", inspection.selection.?.info.metadata.identifier.?);
    try std.testing.expect(inspection.selection.?.items[0] == .pubkey);
    try std.testing.expectEqual(followed_two, inspection.selection.?.items[0].pubkey.pubkey);
}
