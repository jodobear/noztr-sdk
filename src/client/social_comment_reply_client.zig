const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const social_support = @import("social_support.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const reply_event_kind: u32 = noztr.nip10_threads.text_note_event_kind;
pub const comment_event_kind: u32 = noztr.nip22_comments.comment_event_kind;

pub const SocialCommentReplyClientError =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    store.EventArchiveError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip01_event.EventVerifyError ||
    noztr.nip10_threads.ThreadError ||
    noztr.nip22_comments.CommentError ||
    error{
        InvalidReplyEventKind,
        InvalidCommentEventKind,
        InvalidStoredInteractionKind,
        TooManyAuthors,
        TooManyKinds,
        QueryLimitTooLarge,
        ReplyPageStorageTooSmall,
        CommentPageStorageTooSmall,
        ReplyDraftStorageTooSmall,
        CommentDraftStorageTooSmall,
    };

pub const SocialCommentReplyClientConfig = social_support.ClientConfig;

pub const SocialCommentReplyClientStorage = social_support.ClientStorage;

pub const ReplyReference = noztr.nip10_threads.Reference;

pub const ReplyDraft = struct {
    created_at: u64,
    content: []const u8,
    root: ReplyReference,
    parent: ?ReplyReference = null,
};

pub const ReplyDraftStorage = struct {
    tags: [2]noztr.nip01_event.EventTag = undefined,
    root_items: [5][]const u8 = undefined,
    parent_items: [5][]const u8 = undefined,
    root_event_id_hex: [64]u8 = undefined,
    root_author_pubkey_hex: [64]u8 = undefined,
    parent_event_id_hex: [64]u8 = undefined,
    parent_author_pubkey_hex: [64]u8 = undefined,
};

pub const CommentDraft = struct {
    created_at: u64,
    content: []const u8,
    root: CommentTargetDraft,
    parent: CommentTargetDraft,
};

pub const ExternalCommentTargetDraft = struct {
    value: []const u8,
    hint: ?[]const u8 = null,
    external_kind: []const u8,
    author_pubkey: [32]u8,
    author_hint: ?[]const u8 = null,
};

pub const CommentTargetDraft = union(enum) {
    event: noztr.nip22_comments.EventTarget,
    coordinate: noztr.nip22_comments.CoordinateTarget,
    external: ExternalCommentTargetDraft,
};

pub const CommentDraftStorage = struct {
    tags: [6]noztr.nip01_event.EventTag = undefined,
    root_target_items: [4][]const u8 = undefined,
    root_kind_items: [2][]const u8 = undefined,
    root_author_items: [3][]const u8 = undefined,
    parent_target_items: [4][]const u8 = undefined,
    parent_kind_items: [2][]const u8 = undefined,
    parent_author_items: [3][]const u8 = undefined,
    root_target_id_hex: [64]u8 = undefined,
    root_target_author_hex: [64]u8 = undefined,
    root_event_author_hex: [64]u8 = undefined,
    parent_target_id_hex: [64]u8 = undefined,
    parent_target_author_hex: [64]u8 = undefined,
    parent_event_author_hex: [64]u8 = undefined,
    root_kind_text: [20]u8 = undefined,
    parent_kind_text: [20]u8 = undefined,
    root_coordinate_text: [noztr.limits.tag_item_bytes_max]u8 = undefined,
    parent_coordinate_text: [noztr.limits.tag_item_bytes_max]u8 = undefined,
};

pub const SocialEventQuery = social_support.AuthorTimeQuery;

pub const ReplySubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialEventQuery = .{},
};

pub const CommentSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialEventQuery = .{},
};

pub const SocialSubscriptionPlanStorage = social_support.SubscriptionPlanStorage;

pub const ReplyPageRequest = struct {
    query: SocialEventQuery = .{},
    cursor: ?store.EventCursor = null,
};

pub const CommentPageRequest = struct {
    query: SocialEventQuery = .{},
    cursor: ?store.EventCursor = null,
};

pub const ReplyRecord = struct {
    record: store.ClientEventRecord,
    event: noztr.nip01_event.Event,
};

pub const CommentRecord = struct {
    record: store.ClientEventRecord,
    event: noztr.nip01_event.Event,
};

pub const ReplyPage = struct {
    replies: []const ReplyRecord = &.{},
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const CommentPage = struct {
    comments: []const CommentRecord = &.{},
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const SocialCommentReplyClient = struct {
    config: SocialCommentReplyClientConfig,
    publish: publish_client.PublishClient,
    query: relay_query_client.RelayQueryClient,

    pub fn init(
        config: SocialCommentReplyClientConfig,
        storage: *SocialCommentReplyClientStorage,
    ) SocialCommentReplyClient {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.init(config.query, &storage.query),
        };
    }

    pub fn attach(
        config: SocialCommentReplyClientConfig,
        storage: *SocialCommentReplyClientStorage,
    ) SocialCommentReplyClient {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.attach(config.query, &storage.query),
        };
    }

    pub fn addRelay(
        self: *SocialCommentReplyClient,
        relay_url_text: []const u8,
    ) SocialCommentReplyClientError!runtime.RelayDescriptor {
        return social_support.addRelay(&self.publish, &self.query, relay_url_text);
    }

    pub fn markRelayConnected(
        self: *SocialCommentReplyClient,
        relay_index: u8,
    ) SocialCommentReplyClientError!void {
        try social_support.markRelayConnected(&self.publish, &self.query, relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *SocialCommentReplyClient,
        relay_index: u8,
    ) SocialCommentReplyClientError!void {
        try social_support.noteRelayDisconnected(&self.publish, &self.query, relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *SocialCommentReplyClient,
        relay_index: u8,
        challenge: []const u8,
    ) SocialCommentReplyClientError!void {
        try social_support.noteRelayAuthChallenge(
            &self.publish,
            &self.query,
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const SocialCommentReplyClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return social_support.inspectRelayRuntime(&self.query, storage);
    }

    pub fn inspectPublish(
        self: *const SocialCommentReplyClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return social_support.inspectPublish(&self.publish, storage);
    }

    pub fn buildReplyDraft(
        _: SocialCommentReplyClient,
        storage: *ReplyDraftStorage,
        draft: *const ReplyDraft,
    ) SocialCommentReplyClientError!local_operator.LocalEventDraft {
        storage.tags[0] = buildThreadReferenceTag(
            storage.root_items[0..],
            storage.root_event_id_hex[0..],
            storage.root_author_pubkey_hex[0..],
            "root",
            draft.root,
        );

        var tag_count: usize = 1;
        if (draft.parent) |parent| {
            storage.tags[tag_count] = buildThreadReferenceTag(
                storage.parent_items[0..],
                storage.parent_event_id_hex[0..],
                storage.parent_author_pubkey_hex[0..],
                "reply",
                parent,
            );
            tag_count += 1;
        }

        return .{
            .kind = reply_event_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..tag_count],
        };
    }

    pub fn prepareReplyPublish(
        self: SocialCommentReplyClient,
        event_json_output: []u8,
        draft_storage: *ReplyDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const ReplyDraft,
    ) SocialCommentReplyClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildReplyDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn buildCommentDraft(
        _: SocialCommentReplyClient,
        storage: *CommentDraftStorage,
        draft: *const CommentDraft,
    ) SocialCommentReplyClientError!local_operator.LocalEventDraft {
        var tag_count: usize = 0;
        try buildCommentTargetTags(storage, &tag_count, .root, draft.root);
        try buildCommentTargetTags(storage, &tag_count, .parent, draft.parent);
        std.debug.assert(tag_count <= storage.tags.len);

        return .{
            .kind = comment_event_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..tag_count],
        };
    }

    pub fn prepareCommentPublish(
        self: SocialCommentReplyClient,
        event_json_output: []u8,
        draft_storage: *CommentDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const CommentDraft,
    ) SocialCommentReplyClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildCommentDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const SocialCommentReplyClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) SocialCommentReplyClientError!publish_client.TargetedPublishEvent {
        return social_support.composeTargetedPublish(&self.publish, output, step, prepared);
    }

    pub fn inspectReplySubscription(
        self: *const SocialCommentReplyClient,
        request: *const ReplySubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialCommentReplyClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{reply_event_kind};
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn inspectCommentSubscription(
        self: *const SocialCommentReplyClient,
        request: *const CommentSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialCommentReplyClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{comment_event_kind};
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const SocialCommentReplyClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) SocialCommentReplyClientError!relay_query_client.TargetedSubscriptionRequest {
        return social_support.composeTargetedSubscriptionRequest(&self.query, output, step);
    }

    pub fn composeTargetedCloseRequest(
        self: *const SocialCommentReplyClient,
        output: []u8,
        target: *const relay_query_client.RelayQueryTarget,
        subscription_id: []const u8,
    ) SocialCommentReplyClientError!relay_query_client.TargetedCloseRequest {
        return social_support.composeTargetedCloseRequest(
            &self.query,
            output,
            target,
            subscription_id,
        );
    }

    pub fn inspectReplyEvent(
        _: SocialCommentReplyClient,
        event: *const noztr.nip01_event.Event,
        mentions_out: []noztr.nip10_threads.Reference,
    ) SocialCommentReplyClientError!noztr.nip10_threads.Thread {
        if (event.kind != reply_event_kind) return error.InvalidReplyEventKind;
        return noztr.nip10_threads.thread_extract(event, mentions_out);
    }

    pub fn inspectCommentEvent(
        _: SocialCommentReplyClient,
        event: *const noztr.nip01_event.Event,
    ) SocialCommentReplyClientError!noztr.nip22_comments.Comment {
        if (event.kind != comment_event_kind) return error.InvalidCommentEventKind;
        return noztr.nip22_comments.comment_parse(event);
    }

    pub fn storeInteractionEventJson(
        _: SocialCommentReplyClient,
        archive: store.EventArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) SocialCommentReplyClientError!void {
        const event = try parseVerifiedStoredInteractionEventJson(event_json, scratch);
        if (!storedInteractionKindSupported(event.kind)) return error.InvalidStoredInteractionKind;
        return archive.ingestEventJson(event_json, scratch);
    }

    pub fn inspectReplyPage(
        _: SocialCommentReplyClient,
        archive: store.EventArchive,
        request: *const ReplyPageRequest,
        page: *store.EventQueryResultPage,
        replies_out: []ReplyRecord,
        scratch: std.mem.Allocator,
    ) SocialCommentReplyClientError!ReplyPage {
        const kinds = [_]u32{reply_event_kind};
        try archive.query(&.{
            .authors = request.query.authors,
            .kinds = kinds[0..],
            .since = request.query.since,
            .until = request.query.until,
            .cursor = request.cursor,
            .limit = request.query.limit,
        }, page);

        if (page.count > replies_out.len) return error.ReplyPageStorageTooSmall;

        var reply_count: usize = 0;
        for (page.slice(), 0..) |record, index| {
            const event = try parseVerifiedStoredInteractionEventJson(record.eventJson(), scratch);
            if (event.kind != reply_event_kind) return error.InvalidReplyEventKind;
            replies_out[index] = .{ .record = record, .event = event };
            reply_count += 1;
        }

        return .{
            .replies = replies_out[0..reply_count],
            .truncated = page.truncated,
            .next_cursor = page.next_cursor,
        };
    }

    pub fn inspectCommentPage(
        self: SocialCommentReplyClient,
        archive: store.EventArchive,
        request: *const CommentPageRequest,
        page: *store.EventQueryResultPage,
        comments_out: []CommentRecord,
        scratch: std.mem.Allocator,
    ) SocialCommentReplyClientError!CommentPage {
        const kinds = [_]u32{comment_event_kind};
        try archive.query(&.{
            .authors = request.query.authors,
            .kinds = kinds[0..],
            .since = request.query.since,
            .until = request.query.until,
            .cursor = request.cursor,
            .limit = request.query.limit,
        }, page);

        if (page.count > comments_out.len) return error.CommentPageStorageTooSmall;

        var comment_count: usize = 0;
        for (page.slice(), 0..) |record, index| {
            const event = try parseVerifiedStoredInteractionEventJson(record.eventJson(), scratch);
            _ = try self.inspectCommentEvent(&event);
            comments_out[index] = .{ .record = record, .event = event };
            comment_count += 1;
        }

        return .{
            .comments = comments_out[0..comment_count],
            .truncated = page.truncated,
            .next_cursor = page.next_cursor,
        };
    }

    fn inspectSingleSubscription(
        self: *const SocialCommentReplyClient,
        subscription_id: []const u8,
        query: *const SocialEventQuery,
        kinds: []const u32,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialCommentReplyClientError!runtime.RelayPoolSubscriptionPlan {
        return social_support.inspectSingleSubscription(
            &self.query,
            subscription_id,
            query,
            kinds,
            storage,
        );
    }
};

const CommentTargetKind = enum {
    root,
    parent,
};

fn buildThreadReferenceTag(
    items: [][]const u8,
    event_id_hex_storage: []u8,
    author_pubkey_hex_storage: []u8,
    marker: []const u8,
    reference: ReplyReference,
) noztr.nip01_event.EventTag {
    const event_id_hex = std.fmt.bytesToHex(reference.event_id, .lower);
    @memcpy(event_id_hex_storage[0..event_id_hex.len], event_id_hex[0..]);
    items[0] = "e";
    items[1] = event_id_hex_storage[0..event_id_hex.len];
    items[2] = reference.relay_hint orelse "";
    items[3] = marker;
    var item_count: usize = 4;
    if (reference.author_pubkey) |author_pubkey| {
        const author_hex = std.fmt.bytesToHex(author_pubkey, .lower);
        @memcpy(author_pubkey_hex_storage[0..author_hex.len], author_hex[0..]);
        items[item_count] = author_pubkey_hex_storage[0..author_hex.len];
        item_count += 1;
    }
    return .{ .items = items[0..item_count] };
}

fn buildCommentTargetTags(
    storage: *CommentDraftStorage,
    tag_count: *usize,
    kind: CommentTargetKind,
    target: CommentTargetDraft,
) SocialCommentReplyClientError!void {
    switch (target) {
        .event => |event_target| {
            try appendCommentEventTargetTags(storage, tag_count, kind, event_target);
        },
        .coordinate => |coordinate_target| {
            try appendCommentCoordinateTargetTags(storage, tag_count, kind, coordinate_target);
        },
        .external => |external_target| {
            try appendCommentExternalTargetTags(storage, tag_count, kind, external_target);
        },
    }
}

fn appendCommentEventTargetTags(
    storage: *CommentDraftStorage,
    tag_count: *usize,
    kind: CommentTargetKind,
    target: noztr.nip22_comments.EventTarget,
) SocialCommentReplyClientError!void {
    if (target.kind == reply_event_kind) {
        return switch (kind) {
            .root => error.RootTextNoteUnsupported,
            .parent => error.ParentTextNoteUnsupported,
        };
    }

    const target_items = targetItemsFor(storage, kind);
    const target_id_hex = targetIdHexFor(storage, kind);
    const event_author_hex = eventAuthorHexFor(storage, kind);
    const author_items = authorItemsFor(storage, kind);
    const author_hex = authorHexFor(storage, kind);
    const kind_items = kindItemsFor(storage, kind);
    const kind_text = kindTextFor(storage, kind);

    const event_id_hex = std.fmt.bytesToHex(target.event_id, .lower);
    @memcpy(target_id_hex[0..event_id_hex.len], event_id_hex[0..]);
    target_items[0] = targetTagName(kind, .event);
    target_items[1] = target_id_hex[0..event_id_hex.len];
    var target_item_count: usize = 2;
    if (target.relay_hint != null or target.event_author_pubkey != null) {
        target_items[target_item_count] = target.relay_hint orelse "";
        target_item_count += 1;
    }
    if (target.event_author_pubkey) |event_author_pubkey| {
        const event_author_pubkey_hex = std.fmt.bytesToHex(event_author_pubkey, .lower);
        @memcpy(event_author_hex[0..event_author_pubkey_hex.len], event_author_pubkey_hex[0..]);
        target_items[target_item_count] = event_author_hex[0..event_author_pubkey_hex.len];
        target_item_count += 1;
    }

    appendTag(storage, tag_count, target_items[0..target_item_count]) catch {
        return error.CommentDraftStorageTooSmall;
    };
    appendCommentKindAndAuthorTags(
        storage,
        tag_count,
        kind,
        target.kind,
        kind_items,
        kind_text,
        target.author_pubkey,
        target.author_hint,
        author_items,
        author_hex,
        null,
    ) catch return error.CommentDraftStorageTooSmall;
}

fn appendCommentCoordinateTargetTags(
    storage: *CommentDraftStorage,
    tag_count: *usize,
    kind: CommentTargetKind,
    target: noztr.nip22_comments.CoordinateTarget,
) SocialCommentReplyClientError!void {
    if (target.kind == reply_event_kind) {
        return switch (kind) {
            .root => error.RootTextNoteUnsupported,
            .parent => error.ParentTextNoteUnsupported,
        };
    }
    std.debug.assert(target.event_hint == null or target.event_id != null);
    if (target.event_id != null) return error.CommentDraftStorageTooSmall;

    const target_items = targetItemsFor(storage, kind);
    const coordinate_text = coordinateTextFor(storage, kind);
    const author_items = authorItemsFor(storage, kind);
    const author_hex = authorHexFor(storage, kind);
    const kind_items = kindItemsFor(storage, kind);
    const kind_text = kindTextFor(storage, kind);

    target_items[0] = targetTagName(kind, .coordinate);
    target_items[1] = try formatCommentCoordinate(coordinate_text, target);
    var target_item_count: usize = 2;
    if (target.relay_hint) |relay_hint| {
        target_items[target_item_count] = relay_hint;
        target_item_count += 1;
    }
    appendTag(storage, tag_count, target_items[0..target_item_count]) catch {
        return error.CommentDraftStorageTooSmall;
    };
    appendCommentKindAndAuthorTags(
        storage,
        tag_count,
        kind,
        target.kind,
        kind_items,
        kind_text,
        target.pubkey,
        target.author_hint,
        author_items,
        author_hex,
        null,
    ) catch return error.CommentDraftStorageTooSmall;
}

fn appendCommentExternalTargetTags(
    storage: *CommentDraftStorage,
    tag_count: *usize,
    kind: CommentTargetKind,
    target: ExternalCommentTargetDraft,
) SocialCommentReplyClientError!void {
    const target_items = targetItemsFor(storage, kind);
    const author_items = authorItemsFor(storage, kind);
    const author_hex = authorHexFor(storage, kind);
    const kind_items = kindItemsFor(storage, kind);
    const kind_text = kindTextFor(storage, kind);
    target_items[0] = targetTagName(kind, .external);
    target_items[1] = target.value;
    var target_item_count: usize = 2;
    if (target.hint) |hint| {
        target_items[target_item_count] = hint;
        target_item_count += 1;
    }
    appendTag(storage, tag_count, target_items[0..target_item_count]) catch {
        return error.CommentDraftStorageTooSmall;
    };
    appendCommentKindAndAuthorTags(
        storage,
        tag_count,
        kind,
        0,
        kind_items,
        kind_text,
        target.author_pubkey,
        target.author_hint,
        author_items,
        author_hex,
        target.external_kind,
    ) catch return error.CommentDraftStorageTooSmall;
}

fn appendCommentKindAndAuthorTags(
    storage: *CommentDraftStorage,
    tag_count: *usize,
    kind: CommentTargetKind,
    target_kind: u32,
    kind_items: [][]const u8,
    kind_text: []u8,
    author_pubkey: [32]u8,
    author_hint: ?[]const u8,
    author_items: [][]const u8,
    author_hex: []u8,
    external_kind_override: ?[]const u8,
) error{CommentDraftStorageTooSmall}!void {
    kind_items[0] = kindTagName(kind);
    if (external_kind_override) |external_kind| {
        kind_items[1] = external_kind;
    } else {
        kind_items[1] = std.fmt.bufPrint(kind_text, "{d}", .{target_kind}) catch {
            return error.CommentDraftStorageTooSmall;
        };
    }
    try appendTag(storage, tag_count, kind_items[0..2]);

    const pubkey_hex = std.fmt.bytesToHex(author_pubkey, .lower);
    @memcpy(author_hex[0..pubkey_hex.len], pubkey_hex[0..]);
    author_items[0] = authorTagName(kind);
    author_items[1] = author_hex[0..pubkey_hex.len];
    var author_item_count: usize = 2;
    if (author_hint) |hint| {
        author_items[author_item_count] = hint;
        author_item_count += 1;
    }
    try appendTag(storage, tag_count, author_items[0..author_item_count]);
}

fn appendTag(
    storage: *CommentDraftStorage,
    tag_count: *usize,
    items: []const []const u8,
) error{CommentDraftStorageTooSmall}!void {
    if (tag_count.* >= storage.tags.len) return error.CommentDraftStorageTooSmall;
    storage.tags[tag_count.*] = .{ .items = items };
    tag_count.* += 1;
}

fn targetItemsFor(storage: *CommentDraftStorage, kind: CommentTargetKind) [][]const u8 {
    return switch (kind) {
        .root => storage.root_target_items[0..],
        .parent => storage.parent_target_items[0..],
    };
}

fn kindItemsFor(storage: *CommentDraftStorage, kind: CommentTargetKind) [][]const u8 {
    return switch (kind) {
        .root => storage.root_kind_items[0..],
        .parent => storage.parent_kind_items[0..],
    };
}

fn authorItemsFor(storage: *CommentDraftStorage, kind: CommentTargetKind) [][]const u8 {
    return switch (kind) {
        .root => storage.root_author_items[0..],
        .parent => storage.parent_author_items[0..],
    };
}

fn targetIdHexFor(storage: *CommentDraftStorage, kind: CommentTargetKind) []u8 {
    return switch (kind) {
        .root => storage.root_target_id_hex[0..],
        .parent => storage.parent_target_id_hex[0..],
    };
}

fn authorHexFor(storage: *CommentDraftStorage, kind: CommentTargetKind) []u8 {
    return switch (kind) {
        .root => storage.root_target_author_hex[0..],
        .parent => storage.parent_target_author_hex[0..],
    };
}

fn eventAuthorHexFor(storage: *CommentDraftStorage, kind: CommentTargetKind) []u8 {
    return switch (kind) {
        .root => storage.root_event_author_hex[0..],
        .parent => storage.parent_event_author_hex[0..],
    };
}

fn kindTextFor(storage: *CommentDraftStorage, kind: CommentTargetKind) []u8 {
    return switch (kind) {
        .root => storage.root_kind_text[0..],
        .parent => storage.parent_kind_text[0..],
    };
}

fn coordinateTextFor(storage: *CommentDraftStorage, kind: CommentTargetKind) []u8 {
    return switch (kind) {
        .root => storage.root_coordinate_text[0..],
        .parent => storage.parent_coordinate_text[0..],
    };
}

const CommentTargetTagName = enum {
    event,
    coordinate,
    external,
};

fn targetTagName(kind: CommentTargetKind, tag_name: CommentTargetTagName) []const u8 {
    return switch (kind) {
        .root => switch (tag_name) {
            .event => "E",
            .coordinate => "A",
            .external => "I",
        },
        .parent => switch (tag_name) {
            .event => "e",
            .coordinate => "a",
            .external => "i",
        },
    };
}

fn kindTagName(kind: CommentTargetKind) []const u8 {
    return switch (kind) {
        .root => "K",
        .parent => "k",
    };
}

fn authorTagName(kind: CommentTargetKind) []const u8 {
    return switch (kind) {
        .root => "P",
        .parent => "p",
    };
}

fn formatCommentCoordinate(
    output: []u8,
    coordinate: noztr.nip22_comments.CoordinateTarget,
) SocialCommentReplyClientError![]const u8 {
    const pubkey_hex = std.fmt.bytesToHex(coordinate.pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{d}:{s}:{s}",
        .{ coordinate.kind, pubkey_hex[0..], coordinate.identifier },
    ) catch error.CommentDraftStorageTooSmall;
}

fn parseVerifiedStoredInteractionEventJson(
    event_json: []const u8,
    scratch: std.mem.Allocator,
) SocialCommentReplyClientError!noztr.nip01_event.Event {
    const event = try noztr.nip01_event.event_parse_json(event_json, scratch);
    try noztr.nip01_event.event_verify(&event);
    return event;
}

fn storedInteractionKindSupported(kind: u32) bool {
    if (kind == reply_event_kind) return true;
    return kind == comment_event_kind;
}

test "social comment reply client composes reply and comment publish with explicit inspection" {
    var storage = SocialCommentReplyClientStorage{};
    var client = SocialCommentReplyClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x51} ** 32;
    const root_event_id = [_]u8{0x11} ** 32;
    const root_author = [_]u8{0xaa} ** 32;
    const parent_event_id = [_]u8{0x22} ** 32;
    const parent_author = [_]u8{0xbb} ** 32;

    var reply_storage = ReplyDraftStorage{};
    var reply_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_reply = try client.prepareReplyPublish(
        reply_event_json[0..],
        &reply_storage,
        &secret_key,
        &.{
            .created_at = 10,
            .content = "reply",
            .root = .{
                .event_id = root_event_id,
                .relay_hint = "wss://relay.root",
                .author_pubkey = root_author,
            },
            .parent = .{
                .event_id = parent_event_id,
                .relay_hint = "wss://relay.parent",
                .author_pubkey = parent_author,
            },
        },
    );
    var mentions: [2]noztr.nip10_threads.Reference = undefined;
    const thread = try client.inspectReplyEvent(&prepared_reply.event, mentions[0..]);
    try std.testing.expect(thread.root != null);
    try std.testing.expect(thread.reply != null);

    var reply_subscription_storage = SocialSubscriptionPlanStorage{};
    const reply_plan = try client.inspectReplySubscription(
        &.{ .subscription_id = "replies", .query = .{ .limit = 20 } },
        &reply_subscription_storage,
    );
    const reply_step = reply_plan.nextStep().?;
    var reply_request_json: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const reply_request = try client.composeTargetedSubscriptionRequest(
        reply_request_json[0..],
        &reply_step,
    );
    try std.testing.expect(std.mem.indexOf(u8, reply_request.request_json, "\"kinds\":[1]") != null);

    var comment_storage = CommentDraftStorage{};
    var comment_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_comment = try client.prepareCommentPublish(
        comment_event_json[0..],
        &comment_storage,
        &secret_key,
        &.{
            .created_at = 11,
            .content = "comment",
            .root = .{ .external = .{
                .value = "https://example.com/root",
                .external_kind = "web",
                .author_pubkey = [_]u8{0x01} ** 32,
            } },
            .parent = .{ .external = .{
                .value = "https://example.com/parent",
                .external_kind = "web",
                .author_pubkey = [_]u8{0x02} ** 32,
            } },
        },
    );
    const parsed_comment = try client.inspectCommentEvent(&prepared_comment.event);
    try std.testing.expect(parsed_comment.root == .external);
    try std.testing.expect(parsed_comment.parent == .external);

    var memory_store = store.MemoryClientStore{};
    const archive = store.EventArchive.init(memory_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try client.storeInteractionEventJson(archive, prepared_reply.event_json, arena.allocator());
    try client.storeInteractionEventJson(archive, prepared_comment.event_json, arena.allocator());

    const author_hex = std.fmt.bytesToHex(prepared_comment.event.pubkey, .lower);
    const authors = [_]store.EventPubkeyHex{author_hex};
    var comment_page_storage: [1]store.ClientEventRecord = undefined;
    var comment_page = store.EventQueryResultPage.init(comment_page_storage[0..]);
    var comments: [1]CommentRecord = undefined;
    const stored_comments = try client.inspectCommentPage(
        archive,
        &.{ .query = .{ .authors = authors[0..], .limit = 1 } },
        &comment_page,
        comments[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 1), stored_comments.comments.len);
}
