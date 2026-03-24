const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const social_support = @import("social_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const highlight_event_kind: u32 = noztr.nip84_highlights.highlight_kind;

pub const Error =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    store.EventArchiveError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    noztr.nip84_highlights.HighlightError ||
    error{
        InvalidHighlightEventKind,
        InvalidStoredHighlightKind,
        TooManyAuthors,
        TooManyKinds,
        QueryLimitTooLarge,
        HighlightDraftStorageTooSmall,
        HighlightPageStorageTooSmall,
    };

pub const Config = social_support.ClientConfig;

pub const Storage = social_support.ClientStorage;

pub const HighlightAuthorDraft = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

pub const HighlightUrlReferenceDraft = struct {
    url: []const u8,
    marker: ?[]const u8 = null,
};

pub const HighlightDraft = struct {
    created_at: u64,
    content: []const u8,
    source: noztr.nip84_highlights.HighlightSource,
    attributions: []const HighlightAuthorDraft = &.{},
    references: []const HighlightUrlReferenceDraft = &.{},
    context: ?[]const u8 = null,
    comment: ?[]const u8 = null,
};

pub const HighlightDraftStorage = struct {
    builders: []noztr.nip84_highlights.TagBuilder,
    tags: []noztr.nip01_event.EventTag,
    pubkey_hex: []store.EventPubkeyHex,
    source_event_id_hex: [64]u8 = undefined,
    source_coordinate_text: [noztr.limits.tag_item_bytes_max]u8 = undefined,

    pub fn init(
        builders: []noztr.nip84_highlights.TagBuilder,
        tags: []noztr.nip01_event.EventTag,
        pubkey_hex: []store.EventPubkeyHex,
    ) HighlightDraftStorage {
        return .{
            .builders = builders,
            .tags = tags,
            .pubkey_hex = pubkey_hex,
        };
    }
};

pub const Query = social_support.AuthorTimeQuery;

pub const HighlightSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: Query = .{},
};

pub const SubscriptionStorage = social_support.SubscriptionPlanStorage;

pub const HighlightPageRequest = struct {
    query: Query = .{},
    cursor: ?store.EventCursor = null,
};

pub const HighlightRecord = struct {
    record: store.ClientEventRecord,
    event: noztr.nip01_event.Event,
};

pub const HighlightPage = struct {
    highlights: []const HighlightRecord = &.{},
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const Client = struct {
    config: Config,
    publish: publish_client.PublishClient,
    query: relay_query_client.RelayQueryClient,

    pub fn init(
        config: Config,
        storage: *Storage,
    ) Client {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.init(config.query, &storage.query),
        };
    }

    pub fn attach(
        config: Config,
        storage: *Storage,
    ) Client {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.attach(config.query, &storage.query),
        };
    }

    pub fn addRelay(
        self: *Client,
        relay_url_text: []const u8,
    ) Error!runtime.RelayDescriptor {
        return social_support.addRelay(&self.publish, &self.query, relay_url_text);
    }

    pub fn markRelayConnected(
        self: *Client,
        relay_index: u8,
    ) Error!void {
        try social_support.markRelayConnected(&self.publish, &self.query, relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *Client,
        relay_index: u8,
    ) Error!void {
        try social_support.noteRelayDisconnected(&self.publish, &self.query, relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *Client,
        relay_index: u8,
        challenge: []const u8,
    ) Error!void {
        try social_support.noteRelayAuthChallenge(
            &self.publish,
            &self.query,
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const Client,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return social_support.inspectRelayRuntime(&self.query, storage);
    }

    pub fn inspectPublish(
        self: *const Client,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return social_support.inspectPublish(&self.publish, storage);
    }

    pub fn buildHighlightDraft(
        _: Client,
        storage: *HighlightDraftStorage,
        draft: *const HighlightDraft,
    ) Error!local_operator.LocalEventDraft {
        const needed_tags = highlightTagCount(draft);
        if (needed_tags > storage.tags.len) return error.HighlightDraftStorageTooSmall;
        if (needed_tags > storage.builders.len) return error.HighlightDraftStorageTooSmall;
        if (draft.attributions.len > storage.pubkey_hex.len) return error.HighlightDraftStorageTooSmall;

        var tag_index: usize = 0;
        var builder_index: usize = 0;

        storage.tags[tag_index] = try buildHighlightSourceTag(storage, &builder_index, draft.source);
        tag_index += 1;
        for (draft.attributions, 0..) |attribution, index| {
            const pubkey_hex = std.fmt.bytesToHex(attribution.pubkey, .lower);
            @memcpy(storage.pubkey_hex[index][0..], pubkey_hex[0..]);
            storage.tags[tag_index] = try noztr.nip84_highlights.highlight_build_author_tag(
                &storage.builders[builder_index],
                storage.pubkey_hex[index][0..],
                attribution.relay_hint,
                attribution.role,
            );
            builder_index += 1;
            tag_index += 1;
        }
        for (draft.references) |reference| {
            storage.tags[tag_index] = try noztr.nip84_highlights.highlight_build_url_reference_tag(
                &storage.builders[builder_index],
                reference.url,
                reference.marker,
            );
            builder_index += 1;
            tag_index += 1;
        }
        if (draft.context) |context| {
            storage.tags[tag_index] = try noztr.nip84_highlights.highlight_build_context_tag(
                &storage.builders[builder_index],
                context,
            );
            builder_index += 1;
            tag_index += 1;
        }
        if (draft.comment) |comment| {
            storage.tags[tag_index] = try noztr.nip84_highlights.highlight_build_comment_tag(
                &storage.builders[builder_index],
                comment,
            );
            builder_index += 1;
            tag_index += 1;
        }

        return .{
            .kind = highlight_event_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..tag_index],
        };
    }

    pub fn prepareHighlightPublish(
        self: Client,
        event_json_output: []u8,
        draft_storage: *HighlightDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const HighlightDraft,
    ) Error!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildHighlightDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const Client,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) Error!publish_client.TargetedPublishEvent {
        return social_support.composeTargetedPublish(&self.publish, output, step, prepared);
    }

    pub fn inspectHighlightSubscription(
        self: *const Client,
        request: *const HighlightSubscriptionRequest,
        storage: *SubscriptionStorage,
    ) Error!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{highlight_event_kind};
        return social_support.inspectSingleSubscription(
            &self.query,
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const Client,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) Error!relay_query_client.TargetedSubscriptionRequest {
        return social_support.composeTargetedSubscriptionRequest(&self.query, output, step);
    }

    pub fn composeTargetedCloseRequest(
        self: *const Client,
        output: []u8,
        target: *const relay_query_client.RelayQueryTarget,
        subscription_id: []const u8,
    ) Error!relay_query_client.TargetedCloseRequest {
        return social_support.composeTargetedCloseRequest(
            &self.query,
            output,
            target,
            subscription_id,
        );
    }

    pub fn inspectHighlightEvent(
        _: Client,
        event: *const noztr.nip01_event.Event,
        attributions_out: []noztr.nip84_highlights.HighlightAttribution,
        refs_out: []noztr.nip84_highlights.UrlRef,
    ) Error!noztr.nip84_highlights.Highlight {
        if (event.kind != highlight_event_kind) return error.InvalidHighlightEventKind;
        return noztr.nip84_highlights.highlight_extract(event, attributions_out, refs_out);
    }

    pub fn storeHighlightEventJson(
        _: Client,
        archive: store.EventArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!void {
        const event = try parseVerifiedStoredHighlightEventJson(event_json, scratch);
        if (event.kind != highlight_event_kind) return error.InvalidStoredHighlightKind;
        return archive.ingestEventJson(event_json, scratch);
    }

    pub fn inspectHighlightPage(
        _: Client,
        archive: store.EventArchive,
        request: *const HighlightPageRequest,
        page: *store.EventQueryResultPage,
        highlights_out: []HighlightRecord,
        scratch: std.mem.Allocator,
    ) Error!HighlightPage {
        const kinds = [_]u32{highlight_event_kind};
        try archive.query(&.{
            .authors = request.query.authors,
            .kinds = kinds[0..],
            .since = request.query.since,
            .until = request.query.until,
            .cursor = request.cursor,
            .limit = request.query.limit,
        }, page);

        if (page.count > highlights_out.len) return error.HighlightPageStorageTooSmall;

        var highlight_count: usize = 0;
        for (page.slice(), 0..) |record, index| {
            const event = try parseVerifiedStoredHighlightEventJson(record.eventJson(), scratch);
            if (event.kind != highlight_event_kind) return error.InvalidHighlightEventKind;
            highlights_out[index] = .{ .record = record, .event = event };
            highlight_count += 1;
        }

        return .{
            .highlights = highlights_out[0..highlight_count],
            .truncated = page.truncated,
            .next_cursor = page.next_cursor,
        };
    }
};

fn highlightTagCount(draft: *const HighlightDraft) usize {
    var count: usize = 1 + draft.attributions.len + draft.references.len;
    if (draft.context != null) count += 1;
    if (draft.comment != null) count += 1;
    return count;
}

fn buildHighlightSourceTag(
    storage: *HighlightDraftStorage,
    builder_index: *usize,
    source: noztr.nip84_highlights.HighlightSource,
) Error!noztr.nip01_event.EventTag {
    const builder = &storage.builders[builder_index.*];
    builder_index.* += 1;

    return switch (source) {
        .event => |event_source| blk: {
            const event_id_hex = std.fmt.bytesToHex(event_source.event_id, .lower);
            @memcpy(storage.source_event_id_hex[0..], event_id_hex[0..]);
            break :blk try noztr.nip84_highlights.highlight_build_event_source_tag(
                builder,
                storage.source_event_id_hex[0..],
                event_source.relay_hint,
            );
        },
        .address => |address_source| blk: {
            const coordinate_text = std.fmt.bufPrint(
                storage.source_coordinate_text[0..],
                "{d}:{s}:{s}",
                .{
                    address_source.kind,
                    std.fmt.bytesToHex(address_source.pubkey, .lower),
                    address_source.identifier,
                },
            ) catch return error.HighlightDraftStorageTooSmall;
            break :blk try noztr.nip84_highlights.highlight_build_address_source_tag(
                builder,
                coordinate_text,
                address_source.relay_hint,
            );
        },
        .url => |url_source| {
            if (url_source.marker) |marker| {
                if (!std.mem.eql(u8, marker, "source")) return error.InvalidSourceTag;
            }
            return noztr.nip84_highlights.highlight_build_url_reference_tag(
                builder,
                url_source.url,
                "source",
            );
        },
    };
}

fn parseVerifiedStoredHighlightEventJson(
    event_json: []const u8,
    scratch: std.mem.Allocator,
) Error!noztr.nip01_event.Event {
    const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
    try noztr.nip01_event.event_verify(&event);
    return event;
}

test "social highlight client composes highlight publish and archive-backed inspection" {
    var storage = Storage{};
    var client = Client.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x61} ** 32;
    const source_id = [_]u8{0x84} ** 32;
    const author = [_]u8{0x94} ** 32;
    var builders: [4]noztr.nip84_highlights.TagBuilder = undefined;
    var tags: [4]noztr.nip01_event.EventTag = undefined;
    var pubkey_hex: [1]store.EventPubkeyHex = undefined;
    var draft_storage = HighlightDraftStorage.init(builders[0..], tags[0..], pubkey_hex[0..]);
    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareHighlightPublish(
        event_json_buffer[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 12,
            .content = "quoted text",
            .source = .{ .event = .{ .event_id = source_id } },
            .attributions = &.{.{ .pubkey = author }},
            .context = "chapter 1",
            .comment = "important",
        },
    );

    var attributions: [1]noztr.nip84_highlights.HighlightAttribution = undefined;
    var refs: [1]noztr.nip84_highlights.UrlRef = undefined;
    const highlight = try client.inspectHighlightEvent(&prepared.event, attributions[0..], refs[0..]);
    try std.testing.expect(highlight.source != null);
    try std.testing.expectEqualStrings("chapter 1", highlight.context.?);

    var subscription_storage = SubscriptionStorage{};
    const plan = try client.inspectHighlightSubscription(
        &.{ .subscription_id = "highlights", .query = .{ .limit = 10 } },
        &subscription_storage,
    );
    const step = plan.nextStep().?;
    var request_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const request = try client.composeTargetedSubscriptionRequest(request_json[0..], &step);
    try std.testing.expect(std.mem.indexOf(u8, request.request_json, "\"kinds\":[9802]") != null);

    var memory_store = store.MemoryClientStore{};
    const archive = store.EventArchive.init(memory_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try client.storeHighlightEventJson(archive, prepared.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(prepared.event.pubkey, .lower);
    const authors = [_]store.EventPubkeyHex{author_hex};
    var page_storage: [1]store.ClientEventRecord = undefined;
    var page = store.EventQueryResultPage.init(page_storage[0..]);
    var highlights: [1]HighlightRecord = undefined;
    const stored = try client.inspectHighlightPage(
        archive,
        &.{ .query = .{ .authors = authors[0..], .limit = 1 } },
        &page,
        highlights[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 1), stored.highlights.len);
}
