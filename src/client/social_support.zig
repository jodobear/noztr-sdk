const std = @import("std");
const publish_client = @import("publish_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const runtime = @import("../runtime/mod.zig");
const store = @import("../store/mod.zig");
const noztr = @import("noztr");

pub const SocialSupportError =
    publish_client.PublishClientError ||
    relay_query_client.RelayQueryClientError ||
    error{
        TooManyAuthors,
        TooManyKinds,
        QueryLimitTooLarge,
    };

pub const ClientConfig = struct {
    publish: publish_client.PublishClientConfig = .{},
    query: relay_query_client.RelayQueryClientConfig = .{},
};

pub const ClientStorage = struct {
    publish: publish_client.PublishClientStorage = .{},
    query: relay_query_client.RelayQueryClientStorage = .{},
};

pub const AuthorTimeQuery = struct {
    authors: []const store.EventPubkeyHex = &.{},
    since: ?u64 = null,
    until: ?u64 = null,
    limit: usize = 0,
};

pub const SubscriptionPlanStorage = struct {
    filters: [1]noztr.nip01_filter.Filter = [_]noztr.nip01_filter.Filter{.{}} ** 1,
    specs: [1]runtime.RelaySubscriptionSpec = undefined,
    relay_pool: runtime.RelayPoolSubscriptionStorage = .{},
};

pub fn addRelay(
    publish: *publish_client.PublishClient,
    query: *relay_query_client.RelayQueryClient,
    relay_url_text: []const u8,
) SocialSupportError!runtime.RelayDescriptor {
    const publish_descriptor = try publish.addRelay(relay_url_text);
    const query_descriptor = try query.addRelay(relay_url_text);
    std.debug.assert(publish_descriptor.relay_index == query_descriptor.relay_index);
    std.debug.assert(std.mem.eql(u8, publish_descriptor.relay_url, query_descriptor.relay_url));
    return query_descriptor;
}

pub fn markRelayConnected(
    publish: *publish_client.PublishClient,
    query: *relay_query_client.RelayQueryClient,
    relay_index: u8,
) SocialSupportError!void {
    try publish.markRelayConnected(relay_index);
    try query.markRelayConnected(relay_index);
}

pub fn noteRelayDisconnected(
    publish: *publish_client.PublishClient,
    query: *relay_query_client.RelayQueryClient,
    relay_index: u8,
) SocialSupportError!void {
    try publish.noteRelayDisconnected(relay_index);
    try query.noteRelayDisconnected(relay_index);
}

pub fn noteRelayAuthChallenge(
    publish: *publish_client.PublishClient,
    query: *relay_query_client.RelayQueryClient,
    relay_index: u8,
    challenge: []const u8,
) SocialSupportError!void {
    try publish.noteRelayAuthChallenge(relay_index, challenge);
    try query.noteRelayAuthChallenge(relay_index, challenge);
}

pub fn inspectRelayRuntime(
    query: *const relay_query_client.RelayQueryClient,
    storage: *runtime.RelayPoolPlanStorage,
) runtime.RelayPoolPlan {
    return query.inspectRelayRuntime(storage);
}

pub fn inspectPublish(
    publish: *const publish_client.PublishClient,
    storage: *runtime.RelayPoolPublishStorage,
) runtime.RelayPoolPublishPlan {
    return publish.inspectPublish(storage);
}

pub fn composeTargetedPublish(
    publish: *const publish_client.PublishClient,
    output: []u8,
    step: *const runtime.RelayPoolPublishStep,
    prepared: *const publish_client.PreparedPublishEvent,
) SocialSupportError!publish_client.TargetedPublishEvent {
    return publish.composeTargetedPublish(output, step, prepared);
}

pub fn inspectSingleSubscription(
    query_client: *const relay_query_client.RelayQueryClient,
    subscription_id: []const u8,
    query: *const AuthorTimeQuery,
    kinds: []const u32,
    storage: *SubscriptionPlanStorage,
) SocialSupportError!runtime.RelayPoolSubscriptionPlan {
    storage.filters[0] = try filterFromAuthorTimeQuery(query, kinds);
    storage.specs[0] = .{
        .subscription_id = subscription_id,
        .filters = storage.filters[0..1],
    };
    return query_client.inspectSubscriptions(storage.specs[0..1], &storage.relay_pool);
}

pub fn composeTargetedSubscriptionRequest(
    query: *const relay_query_client.RelayQueryClient,
    output: []u8,
    step: *const runtime.RelayPoolSubscriptionStep,
) SocialSupportError!relay_query_client.TargetedSubscriptionRequest {
    return query.composeTargetedSubscriptionRequest(output, step);
}

pub fn composeTargetedCloseRequest(
    query: *const relay_query_client.RelayQueryClient,
    output: []u8,
    target: *const relay_query_client.RelayQueryTarget,
    subscription_id: []const u8,
) SocialSupportError!relay_query_client.TargetedCloseRequest {
    return query.composeTargetedCloseRequest(output, target, subscription_id);
}

fn filterFromAuthorTimeQuery(
    query: *const AuthorTimeQuery,
    kinds: []const u32,
) SocialSupportError!noztr.nip01_filter.Filter {
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
