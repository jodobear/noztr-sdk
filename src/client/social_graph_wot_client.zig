const std = @import("std");
const local_operator = @import("local_operator_client.zig");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const contact_list_event_kind: u32 = 3;

pub const SocialGraphWotClientError =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    store.EventArchiveError ||
    noztr.nip01_event.EventParseError ||
    noztr.nip02_contacts.ContactsError ||
    error{
        InvalidContactEventKind,
        TooManyAuthors,
        TooManyKinds,
        QueryLimitTooLarge,
        ContactDraftStorageTooSmall,
    };

pub const SocialGraphWotClientConfig = struct {
    publish: publish_client.PublishClientConfig = .{},
    query: relay_query_client.RelayQueryClientConfig = .{},
};

pub const SocialGraphWotClientStorage = struct {
    publish: publish_client.PublishClientStorage = .{},
    query: relay_query_client.RelayQueryClientStorage = .{},
};

pub const SocialContactDraft = struct {
    created_at: u64,
    content: []const u8 = "",
    contacts: []const noztr.nip02_contacts.ContactEntry = &.{},
};

pub const SocialContactTagStorage = struct {
    items: [4][]const u8 = undefined,
};

pub const SocialContactDraftStorage = struct {
    tags: []noztr.nip01_event.EventTag,
    tag_items: []SocialContactTagStorage,
    pubkey_hex: []store.EventPubkeyHex,

    pub fn init(
        tags: []noztr.nip01_event.EventTag,
        tag_items: []SocialContactTagStorage,
        pubkey_hex: []store.EventPubkeyHex,
    ) SocialContactDraftStorage {
        return .{
            .tags = tags,
            .tag_items = tag_items,
            .pubkey_hex = pubkey_hex,
        };
    }
};

pub const SocialContactQuery = struct {
    authors: []const store.EventPubkeyHex = &.{},
    since: ?u64 = null,
    until: ?u64 = null,
    limit: usize = 0,
};

pub const SocialContactSubscriptionRequest = struct {
    subscription_id: []const u8,
    query: SocialContactQuery = .{},
};

pub const SocialSubscriptionPlanStorage = struct {
    filters: [1]noztr.nip01_filter.Filter = [_]noztr.nip01_filter.Filter{.{}} ** 1,
    specs: [1]runtime.RelaySubscriptionSpec = undefined,
    relay_pool: runtime.RelayPoolSubscriptionStorage = .{},
};

pub const SocialContactInspection = struct {
    contacts: []const noztr.nip02_contacts.ContactEntry,
    contact_count: u16,
};

pub const StoredSocialContactSelectionRequest = struct {
    author: store.EventPubkeyHex,
    cursor: ?store.EventCursor = null,
    limit: usize = 0,
};

pub const StoredSocialContactSelection = struct {
    record: store.ClientEventRecord,
    event: noztr.nip01_event.Event,
    contacts: []const noztr.nip02_contacts.ContactEntry,
};

pub const StoredSocialContactInspection = struct {
    selection: ?StoredSocialContactSelection = null,
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const SocialStarterWotRequest = struct {
    root_author: store.EventPubkeyHex,
    candidate: store.EventPubkeyHex,
    cursor: ?store.EventCursor = null,
    limit: usize = 0,
};

pub const SocialStarterWotSupport = struct {
    author: store.EventPubkeyHex,
};

pub const SocialStarterWotInspection = struct {
    root: ?StoredSocialContactSelection = null,
    direct_follow: bool = false,
    root_follow_count: usize = 0,
    expanded_follow_count: usize = 0,
    support_count: usize = 0,
    supporters: []const SocialStarterWotSupport = &.{},
    supporters_truncated: bool = false,
    truncated: bool = false,
    next_cursor: ?store.EventCursor = null,
};

pub const SocialGraphWotClient = struct {
    config: SocialGraphWotClientConfig,
    publish: publish_client.PublishClient,
    query: relay_query_client.RelayQueryClient,

    pub fn init(
        config: SocialGraphWotClientConfig,
        storage: *SocialGraphWotClientStorage,
    ) SocialGraphWotClient {
        storage.* = .{};
        return .{
            .config = config,
            .publish = publish_client.PublishClient.init(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.init(config.query, &storage.query),
        };
    }

    pub fn attach(
        config: SocialGraphWotClientConfig,
        storage: *SocialGraphWotClientStorage,
    ) SocialGraphWotClient {
        return .{
            .config = config,
            .publish = publish_client.PublishClient.attach(config.publish, &storage.publish),
            .query = relay_query_client.RelayQueryClient.attach(config.query, &storage.query),
        };
    }

    pub fn addRelay(
        self: *SocialGraphWotClient,
        relay_url_text: []const u8,
    ) SocialGraphWotClientError!runtime.RelayDescriptor {
        const publish_descriptor = try self.publish.addRelay(relay_url_text);
        const query_descriptor = try self.query.addRelay(relay_url_text);
        std.debug.assert(publish_descriptor.relay_index == query_descriptor.relay_index);
        std.debug.assert(std.mem.eql(u8, publish_descriptor.relay_url, query_descriptor.relay_url));
        return query_descriptor;
    }

    pub fn markRelayConnected(
        self: *SocialGraphWotClient,
        relay_index: u8,
    ) SocialGraphWotClientError!void {
        try self.publish.markRelayConnected(relay_index);
        try self.query.markRelayConnected(relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *SocialGraphWotClient,
        relay_index: u8,
    ) SocialGraphWotClientError!void {
        try self.publish.noteRelayDisconnected(relay_index);
        try self.query.noteRelayDisconnected(relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *SocialGraphWotClient,
        relay_index: u8,
        challenge: []const u8,
    ) SocialGraphWotClientError!void {
        try self.publish.noteRelayAuthChallenge(relay_index, challenge);
        try self.query.noteRelayAuthChallenge(relay_index, challenge);
    }

    pub fn inspectRelayRuntime(
        self: *const SocialGraphWotClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return self.query.inspectRelayRuntime(storage);
    }

    pub fn inspectPublish(
        self: *const SocialGraphWotClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.publish.inspectPublish(storage);
    }

    pub fn buildContactListDraft(
        self: SocialGraphWotClient,
        storage: *SocialContactDraftStorage,
        draft: *const SocialContactDraft,
    ) SocialGraphWotClientError!local_operator.LocalEventDraft {
        _ = self;

        if (draft.contacts.len > storage.tags.len) return error.ContactDraftStorageTooSmall;
        if (draft.contacts.len > storage.tag_items.len) return error.ContactDraftStorageTooSmall;
        if (draft.contacts.len > storage.pubkey_hex.len) return error.ContactDraftStorageTooSmall;

        for (draft.contacts, 0..) |contact, index| {
            const pubkey_hex = std.fmt.bytesToHex(contact.pubkey, .lower);
            @memcpy(storage.pubkey_hex[index][0..], pubkey_hex[0..]);

            storage.tag_items[index].items[0] = "p";
            storage.tag_items[index].items[1] = storage.pubkey_hex[index][0..];
            var item_count: usize = 2;

            if (contact.relay) |relay| {
                storage.tag_items[index].items[item_count] = relay;
                item_count += 1;
            } else if (contact.petname != null) {
                storage.tag_items[index].items[item_count] = "";
                item_count += 1;
            }

            if (contact.petname) |petname| {
                storage.tag_items[index].items[item_count] = petname;
                item_count += 1;
            }

            storage.tags[index] = .{ .items = storage.tag_items[index].items[0..item_count] };
        }

        return .{
            .kind = contact_list_event_kind,
            .created_at = draft.created_at,
            .content = draft.content,
            .tags = storage.tags[0..draft.contacts.len],
        };
    }

    pub fn prepareContactListPublish(
        self: SocialGraphWotClient,
        event_json_output: []u8,
        draft_storage: *SocialContactDraftStorage,
        secret_key: *const [local_operator.secret_key_bytes]u8,
        draft: *const SocialContactDraft,
    ) SocialGraphWotClientError!publish_client.PreparedPublishEvent {
        const local_draft = try self.buildContactListDraft(draft_storage, draft);
        return self.publish.prepareSignedEvent(event_json_output, secret_key, &local_draft);
    }

    pub fn composeTargetedPublish(
        self: *const SocialGraphWotClient,
        output: []u8,
        step: *const runtime.RelayPoolPublishStep,
        prepared: *const publish_client.PreparedPublishEvent,
    ) SocialGraphWotClientError!publish_client.TargetedPublishEvent {
        return self.publish.composeTargetedPublish(output, step, prepared);
    }

    pub fn inspectContactSubscription(
        self: *const SocialGraphWotClient,
        request: *const SocialContactSubscriptionRequest,
        storage: *SocialSubscriptionPlanStorage,
    ) SocialGraphWotClientError!runtime.RelayPoolSubscriptionPlan {
        const kinds = [_]u32{contact_list_event_kind};
        storage.filters[0] = try filterFromSocialContactQuery(&request.query, kinds[0..]);
        storage.specs[0] = .{
            .subscription_id = request.subscription_id,
            .filters = storage.filters[0..1],
        };
        return self.query.inspectSubscriptions(storage.specs[0..1], &storage.relay_pool);
    }

    pub fn composeTargetedSubscriptionRequest(
        self: *const SocialGraphWotClient,
        output: []u8,
        step: *const runtime.RelayPoolSubscriptionStep,
    ) SocialGraphWotClientError!relay_query_client.TargetedSubscriptionRequest {
        return self.query.composeTargetedSubscriptionRequest(output, step);
    }

    pub fn composeTargetedCloseRequest(
        self: *const SocialGraphWotClient,
        output: []u8,
        target: *const relay_query_client.RelayQueryTarget,
        subscription_id: []const u8,
    ) SocialGraphWotClientError!relay_query_client.TargetedCloseRequest {
        return self.query.composeTargetedCloseRequest(output, target, subscription_id);
    }

    pub fn inspectContactEvent(
        self: SocialGraphWotClient,
        event: *const noztr.nip01_event.Event,
        contacts_out: []noztr.nip02_contacts.ContactEntry,
    ) SocialGraphWotClientError!SocialContactInspection {
        _ = self;
        if (event.kind != contact_list_event_kind) return error.InvalidContactEventKind;
        const count = try noztr.nip02_contacts.contacts_extract(event, contacts_out);
        return .{
            .contacts = contacts_out[0..count],
            .contact_count = count,
        };
    }

    pub fn storeContactEventJson(
        self: SocialGraphWotClient,
        archive: store.EventArchive,
        event_json: []const u8,
        scratch: std.mem.Allocator,
    ) SocialGraphWotClientError!void {
        _ = self;
        return archive.ingestEventJson(event_json, scratch);
    }

    pub fn inspectLatestStoredContacts(
        self: SocialGraphWotClient,
        archive: store.EventArchive,
        request: *const StoredSocialContactSelectionRequest,
        page: *store.EventQueryResultPage,
        contacts_out: []noztr.nip02_contacts.ContactEntry,
        scratch: std.mem.Allocator,
    ) SocialGraphWotClientError!StoredSocialContactInspection {
        _ = self;

        const authors = [_]store.EventPubkeyHex{request.author};
        const kinds = [_]u32{contact_list_event_kind};
        try archive.query(&.{
            .authors = authors[0..],
            .kinds = kinds[0..],
            .cursor = request.cursor,
            .limit = request.limit,
        }, page);

        for (page.slice()) |record| {
            const event = try noztr.nip01_event.event_parse_json(record.eventJson(), scratch);
            const count = try noztr.nip02_contacts.contacts_extract(&event, contacts_out);
            return .{
                .selection = .{
                    .record = record,
                    .event = event,
                    .contacts = contacts_out[0..count],
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

    pub fn inspectStarterWot(
        self: SocialGraphWotClient,
        archive: store.EventArchive,
        request: *const SocialStarterWotRequest,
        root_page: *store.EventQueryResultPage,
        peer_page: *store.EventQueryResultPage,
        root_contacts_out: []noztr.nip02_contacts.ContactEntry,
        peer_contacts_out: []noztr.nip02_contacts.ContactEntry,
        supporters_out: []SocialStarterWotSupport,
        scratch: std.mem.Allocator,
    ) SocialGraphWotClientError!SocialStarterWotInspection {
        const root_inspection = try self.inspectLatestStoredContacts(
            archive,
            &.{
                .author = request.root_author,
                .cursor = request.cursor,
                .limit = request.limit,
            },
            root_page,
            root_contacts_out,
            scratch,
        );

        if (root_inspection.selection == null) {
            return .{
                .root = null,
                .truncated = root_inspection.truncated,
                .next_cursor = root_inspection.next_cursor,
            };
        }

        const root_selection = root_inspection.selection.?;
        const direct_follow = contactSliceContainsHex(root_selection.contacts, request.candidate);

        var support_count: usize = 0;
        var expanded_follow_count: usize = 0;
        var supporter_count: usize = 0;
        var supporters_truncated = false;

        for (root_selection.contacts) |contact| {
            const contact_pubkey_hex = std.fmt.bytesToHex(contact.pubkey, .lower);
            if (std.mem.eql(u8, contact_pubkey_hex[0..], request.candidate[0..])) continue;

            expanded_follow_count += 1;
            const peer_inspection = try self.inspectLatestStoredContacts(
                archive,
                &.{ .author = contact_pubkey_hex, .limit = 1 },
                peer_page,
                peer_contacts_out,
                scratch,
            );
            if (peer_inspection.selection == null) continue;
            if (!contactSliceContainsHex(peer_inspection.selection.?.contacts, request.candidate)) continue;

            support_count += 1;
            if (supporter_count < supporters_out.len) {
                supporters_out[supporter_count] = .{ .author = contact_pubkey_hex };
                supporter_count += 1;
            } else {
                supporters_truncated = true;
            }
        }

        return .{
            .root = root_selection,
            .direct_follow = direct_follow,
            .root_follow_count = root_selection.contacts.len,
            .expanded_follow_count = expanded_follow_count,
            .support_count = support_count,
            .supporters = supporters_out[0..supporter_count],
            .supporters_truncated = supporters_truncated,
            .truncated = root_inspection.truncated,
            .next_cursor = root_inspection.next_cursor,
        };
    }
};

fn filterFromSocialContactQuery(
    query: *const SocialContactQuery,
    kinds: []const u32,
) SocialGraphWotClientError!noztr.nip01_filter.Filter {
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

fn contactSliceContainsHex(
    contacts: []const noztr.nip02_contacts.ContactEntry,
    candidate_hex: store.EventPubkeyHex,
) bool {
    for (contacts) |contact| {
        const contact_hex = std.fmt.bytesToHex(contact.pubkey, .lower);
        if (std.mem.eql(u8, contact_hex[0..], candidate_hex[0..])) return true;
    }
    return false;
}

test "social graph wot client composes contact publish and bounded subscription posture" {
    var storage = SocialGraphWotClientStorage{};
    var client = SocialGraphWotClient.init(.{}, &storage);

    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const secret_key = [_]u8{0x2f} ** 32;
    const followed_pubkey = [_]u8{0x55} ** 32;
    const followed_relay = "wss://relay.followed";
    const followed_petname = "friend";

    var tag_storage: [1]noztr.nip01_event.EventTag = undefined;
    var tag_item_storage: [1]SocialContactTagStorage = undefined;
    var pubkey_hex_storage: [1]store.EventPubkeyHex = undefined;
    var draft_storage = SocialContactDraftStorage.init(
        tag_storage[0..],
        tag_item_storage[0..],
        pubkey_hex_storage[0..],
    );
    var event_json: [noztr.limits.event_json_max]u8 = undefined;
    const prepared = try client.prepareContactListPublish(
        event_json[0..],
        &draft_storage,
        &secret_key,
        &.{
            .created_at = 100,
            .contacts = &.{
                .{
                    .pubkey = followed_pubkey,
                    .relay = followed_relay,
                    .petname = followed_petname,
                },
            },
        },
    );

    var contacts_out: [1]noztr.nip02_contacts.ContactEntry = undefined;
    const inspection = try client.inspectContactEvent(&prepared.event, contacts_out[0..]);
    try std.testing.expectEqual(@as(u16, 1), inspection.contact_count);
    try std.testing.expectEqualStrings(followed_relay, inspection.contacts[0].relay.?);
    try std.testing.expectEqualStrings(followed_petname, inspection.contacts[0].petname.?);

    var publish_storage = runtime.RelayPoolPublishStorage{};
    const publish_plan = client.inspectPublish(&publish_storage);
    const publish_step = publish_plan.nextStep().?;
    var publish_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    _ = try client.composeTargetedPublish(publish_message[0..], &publish_step, &prepared);

    const author_hex = std.fmt.bytesToHex(prepared.event.pubkey, .lower);
    var subscription_storage = SocialSubscriptionPlanStorage{};
    const subscription_plan = try client.inspectContactSubscription(
        &.{
            .subscription_id = "contacts",
            .query = .{
                .authors = &.{author_hex},
                .limit = 1,
            },
        },
        &subscription_storage,
    );
    const subscription_step = subscription_plan.nextStep().?;
    var subscription_message: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    _ = try client.composeTargetedSubscriptionRequest(subscription_message[0..], &subscription_step);

}

test "social graph wot client inspects latest stored contacts and starter wot explicitly" {
    var storage = SocialGraphWotClientStorage{};
    var client = SocialGraphWotClient.init(.{}, &storage);

    const root_secret_key = [_]u8{0x31} ** 32;
    const alice_secret_key = [_]u8{0x41} ** 32;
    const bob_secret_key = [_]u8{0x51} ** 32;
    const candidate_pubkey = [_]u8{0x77} ** 32;
    const candidate_hex = std.fmt.bytesToHex(candidate_pubkey, .lower);

    var empty_tags: [0]noztr.nip01_event.EventTag = .{};
    var empty_tag_items: [0]SocialContactTagStorage = .{};
    var empty_pubkeys: [0]store.EventPubkeyHex = .{};

    var alice_draft_storage = SocialContactDraftStorage.init(
        empty_tags[0..],
        empty_tag_items[0..],
        empty_pubkeys[0..],
    );
    var alice_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const alice_prepared = try client.prepareContactListPublish(
        alice_event_json[0..],
        &alice_draft_storage,
        &alice_secret_key,
        &.{ .created_at = 10 },
    );

    var bob_tags: [1]noztr.nip01_event.EventTag = undefined;
    var bob_tag_items: [1]SocialContactTagStorage = undefined;
    var bob_pubkeys: [1]store.EventPubkeyHex = undefined;
    var bob_draft_storage = SocialContactDraftStorage.init(
        bob_tags[0..],
        bob_tag_items[0..],
        bob_pubkeys[0..],
    );
    var bob_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const bob_prepared = try client.prepareContactListPublish(
        bob_event_json[0..],
        &bob_draft_storage,
        &bob_secret_key,
        &.{
            .created_at = 11,
            .contacts = &.{.{ .pubkey = candidate_pubkey }},
        },
    );

    const alice_pubkey = alice_prepared.event.pubkey;
    const bob_pubkey = bob_prepared.event.pubkey;

    var root_tags: [3]noztr.nip01_event.EventTag = undefined;
    var root_tag_items: [3]SocialContactTagStorage = undefined;
    var root_pubkeys: [3]store.EventPubkeyHex = undefined;
    var root_draft_storage = SocialContactDraftStorage.init(
        root_tags[0..],
        root_tag_items[0..],
        root_pubkeys[0..],
    );
    var root_event_json: [noztr.limits.event_json_max]u8 = undefined;
    const root_prepared = try client.prepareContactListPublish(
        root_event_json[0..],
        &root_draft_storage,
        &root_secret_key,
        &.{
            .created_at = 12,
            .contacts = &.{
                .{ .pubkey = candidate_pubkey },
                .{ .pubkey = alice_pubkey },
                .{ .pubkey = bob_pubkey },
            },
        },
    );

    var memory_store = store.MemoryClientStore{};
    const archive = store.EventArchive.init(memory_store.asClientStore());
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try client.storeContactEventJson(archive, alice_prepared.event_json, arena.allocator());
    try client.storeContactEventJson(archive, bob_prepared.event_json, arena.allocator());
    try client.storeContactEventJson(archive, root_prepared.event_json, arena.allocator());

    const root_author_hex = std.fmt.bytesToHex(root_prepared.event.pubkey, .lower);

    var latest_page_storage: [1]store.ClientEventRecord = undefined;
    var latest_page = store.EventQueryResultPage.init(latest_page_storage[0..]);
    var latest_contacts: [3]noztr.nip02_contacts.ContactEntry = undefined;
    const latest = try client.inspectLatestStoredContacts(
        archive,
        &.{ .author = root_author_hex },
        &latest_page,
        latest_contacts[0..],
        arena.allocator(),
    );
    try std.testing.expect(latest.selection != null);
    try std.testing.expectEqual(@as(usize, 3), latest.selection.?.contacts.len);

    var root_page_storage: [1]store.ClientEventRecord = undefined;
    var peer_page_storage: [1]store.ClientEventRecord = undefined;
    var root_page = store.EventQueryResultPage.init(root_page_storage[0..]);
    var peer_page = store.EventQueryResultPage.init(peer_page_storage[0..]);
    var root_contacts_out: [3]noztr.nip02_contacts.ContactEntry = undefined;
    var peer_contacts_out: [2]noztr.nip02_contacts.ContactEntry = undefined;
    var supporters_out: [1]SocialStarterWotSupport = undefined;
    const wot = try client.inspectStarterWot(
        archive,
        &.{
            .root_author = root_author_hex,
            .candidate = candidate_hex,
        },
        &root_page,
        &peer_page,
        root_contacts_out[0..],
        peer_contacts_out[0..],
        supporters_out[0..],
        arena.allocator(),
    );

    try std.testing.expect(wot.root != null);
    try std.testing.expect(wot.direct_follow);
    try std.testing.expectEqual(@as(usize, 3), wot.root_follow_count);
    try std.testing.expectEqual(@as(usize, 2), wot.expanded_follow_count);
    try std.testing.expectEqual(@as(usize, 1), wot.support_count);
    try std.testing.expectEqual(@as(usize, 1), wot.supporters.len);
    const expected_supporter = std.fmt.bytesToHex(bob_pubkey, .lower);
    try std.testing.expectEqualSlices(u8, expected_supporter[0..], wot.supporters[0].author[0..]);
}
