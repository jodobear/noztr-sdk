const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const profile_event_kind: u32 = 0;
pub const note_event_kind: u32 = noztr.nip10_threads.text_note_event_kind;

pub const SocialProfileContentClientError =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    noztr.nip23_long_form.LongFormError ||
    noztr.nip24_extra_metadata.ExtraMetadataError ||
    noztr.nip10_threads.ThreadError ||
    error{
        InvalidProfileEventKind,
        InvalidNoteEventKind,
        TooManyAuthors,
        TooManyKinds,
        QueryLimitTooLarge,
        LongFormDraftStorageTooSmall,
        LongFormBuiltTagStorageTooSmall,
    };

pub const SocialProfileContentClientConfig = struct {
    publish: publish_client.PublishClientConfig = .{},
    query: relay_query_client.RelayQueryClientConfig = .{},
};

pub const SocialProfileContentClientStorage = struct {
    publish: publish_client.PublishClientStorage = .{},
    query: relay_query_client.RelayQueryClientStorage = .{},
};

pub const SocialProfileDraft = struct {
    created_at: u64,
    extras: noztr.nip24_extra_metadata.MetadataExtras = .{},
    tags: []const noztr.nip01_event.EventTag = &.{},
};

pub const SocialProfileDraftStorage = struct {
    content_json: []u8,

    pub fn init(content_json: []u8) SocialProfileDraftStorage {
        return .{ .content_json = content_json };
    }
};

pub const SocialNoteDraft = struct {
    created_at: u64,
    content: []const u8,
    tags: []const noztr.nip01_event.EventTag = &.{},
};

pub const SocialLongFormDraft = struct {
    kind: noztr.nip23_long_form.LongFormKind = .article,
    created_at: u64,
    content: []const u8,
    identifier: []const u8,
    title: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    image_dimensions: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    published_at: ?u64 = null,
    hashtags: []const []const u8 = &.{},
    tags: []const noztr.nip01_event.EventTag = &.{},
};

pub const SocialLongFormDraftStorage = struct {
    built_tags: []noztr.nip23_long_form.BuiltTag,
    tags: []noztr.nip01_event.EventTag,

    pub fn init(
        built_tags: []noztr.nip23_long_form.BuiltTag,
        tags: []noztr.nip01_event.EventTag,
    ) SocialLongFormDraftStorage {
        return .{
            .built_tags = built_tags,
            .tags = tags,
        };
    }
};

pub const SocialEventQuery = struct {
    authors: []const store.EventPubkeyHex = &.{},
    since: ?u64 = null,
    until: ?u64 = null,
    limit: usize = 0,
};

pub const SocialProfileSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialEventQuery = .{},
};

pub const SocialNoteSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialEventQuery = .{},
};

pub const SocialLongFormSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialEventQuery = .{},
    include_drafts: bool = false,
};

pub const SocialSubscriptionPlanStorage = struct {
    filters: [1]noztr.nip01_filter.Filter = [_]noztr.nip01_filter.Filter{.{}} ** 1,
    specs: [1]runtime.RelaySubscriptionSpec = undefined,
    relay_pool: runtime.RelayPoolSubscriptionStorage = .{},
};

pub const SocialProfileInspection = struct {
    extras: noztr.nip24_extra_metadata.MetadataExtras,
    common_tags: noztr.nip24_extra_metadata.CommonTagInfo,
};

pub const SocialProfileContentClient = struct {
    config: SocialProfileContentClientConfig,
    publish: publish_client.PublishClient,
    query: relay_query_client.RelayQueryClient,

    pub fn init(
        config: SocialProfileContentClientConfig,
        storage: *SocialProfileContentClientStorage,
    ) SocialProfileContentClient {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.init(config.query, &storage.query),
        };
    }

    pub fn attach(
        config: SocialProfileContentClientConfig,
        storage: *SocialProfileContentClientStorage,
    ) SocialProfileContentClient {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.attach(config.query, &storage.query),
        };
    }

    pub fn addRelay(
        self: *SocialProfileContentClient,
        relay_url_text: []const u8,
    ) SocialProfileContentClientError!runtime.RelayDescriptor {
        const publish_descriptor = try self.publish.addRelay(relay_url_text);
        const query_descriptor = try self.query.addRelay(relay_url_text);
        std.debug.assert(publish_descriptor.relay_index == query_descriptor.relay_index);
        std.debug.assert(std.mem.eql(u8, publish_descriptor.relay_url, query_descriptor.relay_url));
        return query_descriptor;
    }

    pub fn markRelayConnected(
        self: *SocialProfileContentClient,
        relay_index: u8,
    ) SocialProfileContentClientError!void {
        try self.publish.markRelayConnected(relay_index);
        try self.query.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *SocialProfileContentClient,
        relay_index: u8,
    ) SocialProfileContentClientError!void {
        try self.publish.noteRelayDisconnected(relay_index);
        try self.query.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *SocialProfileContentClient,
        relay_index: u8,
        challenge: []const u8,
    ) SocialProfileContentClientError!void {
        try self.publish.noteRelayAuthChallenge(relay_index, challenge);
        try self.query.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const SocialProfileContentClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.query.inspectRelayRuntime(storage);
    }

    pub fn inspectPublish(
        self: *const SocialProfileContentClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.publish.inspectPublish(storage);
    }

    pub fn buildProfileDraft(
        self: SocialProfileContentClient,
        storage: *SocialProfileDraftStorage,
        draft: *const SocialProfileDraft,
    ) SocialProfileContentClientError!local_operator.LocalEventDraft {
        _ = self;

        const metadata_json = try noztr.nip24_extra_metadata.metadata_extras_serialize_json(
            storage.content_json,
            &draft.extras,
        );
        return .{
            .kind = profile_event_kind,
            .created_at = draft.created_at,
            .content = metadata_json,
            .tags = draft.tags,
        };
    }

    pub fn prepareProfilePublish(
        self: SocialProfileContentClient,
        event_json_output: []u8,
        draft_storage: *SocialProfileDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const SocialProfileDraft,
    ) SocialProfileContentClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildProfileDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn prepareNotePublish(
        self: SocialProfileContentClient,
        event_json_output: []u8,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const SocialNoteDraft,
    ) SocialProfileContentClientError!publish_client.PreparedPublishEvent {
        const local_draft = local_operator.LocalEventDraft{
            .kind = note_event_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = draft.tags,
        };
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn buildLongFormDraft(
        self: SocialProfileContentClient,
        draft_storage: *SocialLongFormDraftStorage,
        draft: *const SocialLongFormDraft,
    ) SocialProfileContentClientError!local_operator.LocalEventDraft {
        _ = self;

        if (!std.unicode.utf8ValidateSlice(draft.content)) return error.InvalidContent;
        if (draft.image_dimensions != null and draft.image_url == null) return error.InvalidImageTag;

        const built_tag_count = longFormBuiltTagCount(draft);
        if (built_tag_count > draft_storage.built_tags.len) {
            return error.LongFormBuiltTagStorageTooSmall;
        }
        if (built_tag_count + draft.tags.len > draft_storage.tags.len) {
            return error.LongFormDraftStorageTooSmall;
        }

        var built_index: usize = 0;
        var tag_index: usize = 0;

        draft_storage.tags[tag_index] = try noztr.nip23_long_form.long_form_build_identifier_tag(
            &draft_storage.built_tags[built_index],
            draft.identifier,
        );
        built_index += 1;
        tag_index += 1;

        if (draft.title) |title| {
            draft_storage.tags[tag_index] = try noztr.nip23_long_form.long_form_build_title_tag(
                &draft_storage.built_tags[built_index],
                title,
            );
            built_index += 1;
            tag_index += 1;
        }
        if (draft.image_url) |image_url| {
            draft_storage.tags[tag_index] = try noztr.nip23_long_form.long_form_build_image_tag(
                &draft_storage.built_tags[built_index],
                image_url,
                draft.image_dimensions,
            );
            built_index += 1;
            tag_index += 1;
        }
        if (draft.summary) |summary| {
            draft_storage.tags[tag_index] = try noztr.nip23_long_form.long_form_build_summary_tag(
                &draft_storage.built_tags[built_index],
                summary,
            );
            built_index += 1;
            tag_index += 1;
        }
        if (draft.published_at) |published_at| {
            draft_storage.tags[tag_index] =
                try noztr.nip23_long_form.long_form_build_published_at_tag(
                    &draft_storage.built_tags[built_index],
                    published_at,
                );
            built_index += 1;
            tag_index += 1;
        }
        for (draft.hashtags) |hashtag| {
            draft_storage.tags[tag_index] = try noztr.nip23_long_form.long_form_build_hashtag_tag(
                &draft_storage.built_tags[built_index],
                hashtag,
            );
            built_index += 1;
            tag_index += 1;
        }
        for (draft.tags) |tag| {
            draft_storage.tags[tag_index] = tag;
            tag_index += 1;
        }

        return .{
            .kind = @intFromEnum(draft.kind),
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = draft_storage.tags[0..tag_index],
        };
    }

    pub fn prepareLongFormPublish(
        self: SocialProfileContentClient,
        event_json_output: []u8,
        draft_storage: *SocialLongFormDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const SocialLongFormDraft,
    ) SocialProfileContentClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildLongFormDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const SocialProfileContentClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) SocialProfileContentClientError!publish_client.TargetedPublishEvent {
        return self.publish.composeTargetedPublish(output, step, prepared);
    }

    pub fn inspectProfileSubscription(
        self: *const SocialProfileContentClient,
        request: *const SocialProfileSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialProfileContentClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{profile_event_kind};
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn inspectNoteSubscription(
        self: *const SocialProfileContentClient,
        request: *const SocialNoteSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialProfileContentClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{note_event_kind};
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds[0..],
            storage,
        );
    }

    pub fn inspectLongFormSubscription(
        self: *const SocialProfileContentClient,
        request: *const SocialLongFormSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialProfileContentClientError!runtime.RelayPoolSubscriptionPlan {
        const article_kind = @intFromEnum(noztr.nip23_long_form.LongFormKind.article);
        const draft_kind = @intFromEnum(noztr.nip23_long_form.LongFormKind.draft);
        const live_kinds = [_]u32{article_kind};
        const live_and_draft_kinds = [_]u32{ article_kind, draft_kind };
        const kinds = if (request.include_drafts) live_and_draft_kinds[0..] else live_kinds[0..];
        return self.inspectSingleSubscription(
            request.subscription_id,
            &request.query,
            kinds,
            storage,
        );
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const SocialProfileContentClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) SocialProfileContentClientError!relay_query_client.TargetedSubscriptionRequest {
        return self.query.composeTargetedSubscriptionRequest(output, step);
    }

    pub fn composeTargetedCloseRequest(
        self: *const SocialProfileContentClient,
        output: []u8,
        target: *const relay_query_client.RelayQueryTarget,
        subscription_id: []const u8,
    ) SocialProfileContentClientError!relay_query_client.TargetedCloseRequest {
        return self.query.composeTargetedCloseRequest(output, target, subscription_id);
    }

    pub fn inspectProfileEvent(
        self: SocialProfileContentClient,
        event: *const noztr.nip01_event.Event,
        out_reference_urls: [][]const u8,
        out_hashtags: [][]const u8,
        scratch: std.mem.Allocator,
    ) SocialProfileContentClientError!SocialProfileInspection {
        _ = self;
        if (event.kind != profile_event_kind) return error.InvalidProfileEventKind;

        return .{
            .extras = try noztr.nip24_extra_metadata.metadata_extras_parse_json(
                event.content,
                scratch,
            ),
            .common_tags = try noztr.nip24_extra_metadata.common_tags_extract(
                event.tags,
                out_reference_urls,
                out_hashtags,
            ),
        };
    }

    pub fn inspectNoteThread(
        self: SocialProfileContentClient,
        event: *const noztr.nip01_event.Event,
        mentions_out: []noztr.nip10_threads.ThreadReference,
    ) SocialProfileContentClientError!noztr.nip10_threads.ThreadInfo {
        _ = self;
        if (event.kind != note_event_kind) return error.InvalidNoteEventKind;
        return noztr.nip10_threads.thread_extract(event, mentions_out);
    }

    pub fn inspectLongFormEvent(
        self: SocialProfileContentClient,
        event: *const noztr.nip01_event.Event,
        out_hashtags: [][]const u8,
    ) SocialProfileContentClientError!noztr.nip23_long_form.LongFormMetadata {
        _ = self;
        return noztr.nip23_long_form.long_form_extract(event, out_hashtags);
    }

    fn inspectSingleSubscription(
        self: *const SocialProfileContentClient,
        subscription_id: []const u8,
        query: *const SocialEventQuery,
        kinds: []const u32,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialProfileContentClientError!runtime.RelayPoolSubscriptionPlan {
        storage.filters[0] = try filterFromSocialEventQuery(query, kinds);
        storage.specs[0] = .{
            .subscription_id = subscription_id,
            .filters = storage.filters[0..1],
        };
        return self.query.inspectSubscriptions(storage.specs[0..1], &storage.relay_pool);
    }
};

fn longFormBuiltTagCount(draft: *const SocialLongFormDraft) usize {
    var count: usize = 1;
    if (draft.title != null) count += 1;
    if (draft.image_url != null) count += 1;
    if (draft.summary != null) count += 1;
    if (draft.published_at != null) count += 1;
    count += draft.hashtags.len;
    return count;
}

fn filterFromSocialEventQuery(
    query: *const SocialEventQuery,
    kinds: []const u32,
) SocialProfileContentClientError!noztr.nip01_filter.Filter {
    var filter = noztr.nip01_filter.Filter{};

    if (query.authors.len > filter.authors.len) return error.TooManyAuthors;
    for (query.authors, 0..) |author_hex, index| {
        _ = std.fmt.hexToBytes(filter.authors[index][0..], author_hex[0..]) catch unreachable;
        filter.authors_prefix_nibbles[index] = @intCast(author_hex.len);
    }
    filter.authors_count = @intCast(query.authors.len);

    if (kinds.len > filter.kinds.len) return error.TooManyKinds;
    for (kinds, 0..) |kind, index| {
        filter.kinds[index] = kind;
    }
    filter.kinds_count = @intCast(kinds.len);

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

test "social profile content client composes publish and subscription posture over shared relay state" {
    var storage = SocialProfileContentClientStorage{};
    var client = SocialProfileContentClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x21} ** 32;

    var profile_content: [256]u8 = undefined;
    var profile_storage = SocialProfileDraftStorage.init(profile_content[0..]);
    var event_json_buffer: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_profile = try client.prepareProfilePublish(
        event_json_buffer[0..],
        &profile_storage,
        &secret_key,
        &.{
            .created_at = 10,
            .extras = .{
                .display_name = "alice",
                .website = "https://example.com",
            },
        },
    );
    try noztr.nip01_event.event_verify(&prepared_profile.event);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    try std.testing.expectEqual(@as(u8, 1), publish_plan.publish_count);

    const publish_step = publish_plan.nextStep().?;
    var publish_message_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_publish = try client.composeTargetedPublish(
        publish_message_buffer[0..],
        &publish_step,
        &prepared_profile,
    );
    try std.testing.expectEqualStrings("wss://relay.one", targeted_publish.relay.relay_url);
    try std.testing.expect(std.mem.startsWith(u8, targeted_publish.event_message_json, "[\"EVENT\","));

    const author_hex = std.fmt.bytesToHex(prepared_profile.event.pubkey, .lower);
    const authors = [_]store.EventPubkeyHex{author_hex};

    var profile_subscription_storage = SocialSubscriptionPlanStorage{};
    const profile_plan = try client.inspectProfileSubscription(
        &.{
            .subscription_id = "profiles",
            .query = .{
                .authors = authors[0..],
                .limit = 10,
            },
        },
        &profile_subscription_storage,
    );
    const profile_step = profile_plan.nextStep().?;
    var subscription_buffer: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const targeted_subscription = try client.composeTargetedSubscriptionRequest(
        subscription_buffer[0..],
        &profile_step,
    );
    try std.testing.expectEqualStrings("profiles", targeted_subscription.subscription_id);
    try std.testing.expect(std.mem.indexOf(u8, targeted_subscription.request_json, "\"kinds\":[0]") != null);
}

test "social profile content client builds long-form publish posture and inspects profile and thread events" {
    var storage = SocialProfileContentClientStorage{};
    const client = SocialProfileContentClient.init(.{}, &storage);
    const local = local_operator.LocalOperatorClient.init(.{});
    const secret_key = [_]u8{0x42} ** 32;

    var long_form_built_tags: [8]noztr.nip23_long_form.BuiltTag = undefined;
    var long_form_tags: [8]noztr.nip01_event.EventTag = undefined;
    var long_form_storage = SocialLongFormDraftStorage.init(
        long_form_built_tags[0..],
        long_form_tags[0..],
    );
    var long_form_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_long_form = try client.prepareLongFormPublish(
        long_form_event_json[0..],
        &long_form_storage,
        &secret_key,
        &.{
            .created_at = 40,
            .content = "# hello world",
            .identifier = "hello-world",
            .title = "Hello World",
            .summary = "short summary",
            .hashtags = &.{"zig", "nostr"},
        },
    );
    var hashtags: [4][]const u8 = undefined;
    const long_form_metadata = try client.inspectLongFormEvent(
        &prepared_long_form.event,
        hashtags[0..],
    );
    try std.testing.expectEqual(noztr.nip23_long_form.LongFormKind.article, long_form_metadata.kind);
    try std.testing.expectEqualStrings("hello-world", long_form_metadata.identifier);
    try std.testing.expectEqual(@as(u16, 2), long_form_metadata.hashtag_count);

    var profile_content: [256]u8 = undefined;
    var profile_storage = SocialProfileDraftStorage.init(profile_content[0..]);
    var profile_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared_profile = try client.prepareProfilePublish(
        profile_event_json[0..],
        &profile_storage,
        &secret_key,
        &.{
            .created_at = 41,
            .extras = .{
                .display_name = "Alice",
                .website = "https://example.com",
                .banner = "https://example.com/banner.png",
            },
        },
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var reference_urls: [2][]const u8 = undefined;
    var profile_hashtags: [2][]const u8 = undefined;
    const profile = try client.inspectProfileEvent(
        &prepared_profile.event,
        reference_urls[0..],
        profile_hashtags[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("Alice", profile.extras.display_name.?);
    try std.testing.expectEqualStrings("https://example.com", profile.extras.website.?);

    const root_id = [_]u8{0x11} ** 32;
    const root_pubkey = [_]u8{0x22} ** 32;
    const root_id_hex = std.fmt.bytesToHex(root_id, .lower);
    const root_pubkey_hex = std.fmt.bytesToHex(root_pubkey, .lower);
    const reply_id = [_]u8{0x33} ** 32;
    const reply_id_hex = std.fmt.bytesToHex(reply_id, .lower);
    const root_tag_items = [_][]const u8{ "e", root_id_hex[0..], "wss://relay.root", "root", root_pubkey_hex[0..] };
    const reply_tag_items = [_][]const u8{ "e", reply_id_hex[0..], "", "reply" };
    const note_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = root_tag_items[0..] },
        .{ .items = reply_tag_items[0..] },
    };
    var note_event = try local.signDraft(&secret_key, &.{
        .kind = note_event_kind,
        .created_at = 42,
        .content = "reply note",
        .tags = note_tags[0..],
    });
    var mentions: [2]noztr.nip10_threads.ThreadReference = undefined;
    const thread = try client.inspectNoteThread(&note_event, mentions[0..]);
    try std.testing.expectEqual(root_id, thread.root.?.event_id);
    try std.testing.expectEqual(reply_id, thread.reply.?.event_id);
}

