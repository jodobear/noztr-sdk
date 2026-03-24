const std = @import("std");
const transport = @import("../transport/mod.zig");
const noztr = @import("noztr");

pub const AdminTargetError = error{InvalidAdminTarget};
pub const Error = transport.HttpError || AdminTargetError || noztr.nip86_relay_management.RelayManagementError;
pub const Nip98PostError = noztr.nip86_relay_management.RelayManagementError ||
    AdminTargetError ||
    noztr.nip98_http_auth.HttpAuthError ||
    noztr.nostr_keys.NostrKeysError;

pub const Config = struct {};

pub const Storage = struct {};

pub const PreparedPost = struct {
    url: []const u8,
    request_json: []const u8,
    payload_hex: []const u8,

    pub const method = "POST";
};

pub const SupportedMethodsRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const BanPubkeyRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const UnbanPubkeyRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const AllowPubkeyRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const UnallowPubkeyRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const AllowEventRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    id: [32]u8,
    reason: ?[]const u8 = null,
};

pub const AllowKindRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    kind: u32,
};

pub const DisallowKindRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    kind: u32,
};

pub const ChangeRelayNameRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    name: []const u8,
};

pub const ChangeRelayDescriptionRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    description: []const u8,
};

pub const ChangeRelayIconRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    icon: []const u8,
};

pub const BlockIpRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    ip: []const u8,
    reason: ?[]const u8 = null,
};

pub const UnblockIpRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    ip: []const u8,
};

pub const BanEventRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
    id: [32]u8,
    reason: ?[]const u8 = null,
};

pub const ListAllowedKindsRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const ListBlockedIpsRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const ListBannedEventsRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const ListEventsNeedingModerationRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const ListAllowedPubkeysRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const ListBannedPubkeysRequest = struct {
    url: []const u8,
    authorization: ?[]const u8 = null,
};

pub const PreparedAuthorizedPost = struct {
    url: []const u8,
    request_json: []const u8,
    authorization: []const u8,
};

pub const Client = struct {
    config: Config,

    pub fn init(config: Config, storage: *Storage) Client {
        storage.* = .{};
        return .{ .config = config };
    }

    pub fn attach(config: Config, _: *Storage) Client {
        return .{ .config = config };
    }

    pub fn preparePost(
        _: Client,
        url: []const u8,
        request: noztr.nip86_relay_management.Request,
        request_json_out: []u8,
        payload_hex_out: []u8,
    ) Nip98PostError!PreparedPost {
        try validateAdminPostTarget(url);
        const request_json = try serializeRequestJson(request_json_out, request);
        const payload_hex = try noztr.nip98_http_auth.http_auth_payload_sha256_hex(payload_hex_out, request_json);
        return .{
            .url = url,
            .request_json = request_json,
            .payload_hex = payload_hex,
        };
    }

    pub fn encodePreparedAuthorization(
        _: Client,
        prepared: *const PreparedPost,
        auth_event: *const noztr.nip01_event.Event,
        authorization_out: []u8,
        authorization_json_out: []u8,
    ) Nip98PostError![]const u8 {
        _ = try noztr.nip98_http_auth.http_auth_verify_request(
            auth_event,
            prepared.url,
            PreparedPost.method,
            prepared.payload_hex,
            auth_event.created_at,
            0,
            0,
        );
        return noztr.nip98_http_auth.http_auth_encode_authorization_header(
            authorization_out,
            auth_event,
            authorization_json_out,
        );
    }

    pub fn prepareAuthorizedPost(
        self: Client,
        url: []const u8,
        request: noztr.nip86_relay_management.Request,
        secret_key: *const [32]u8,
        created_at: u64,
        request_json_out: []u8,
        payload_hex_out: []u8,
        authorization_out: []u8,
        authorization_json_out: []u8,
    ) Nip98PostError!PreparedAuthorizedPost {
        const prepared = try self.preparePost(url, request, request_json_out, payload_hex_out);
        const signed = try buildSignedPostAuthorization(secret_key, prepared.url, prepared.payload_hex, created_at);
        const authorization = try self.encodePreparedAuthorization(
            &prepared,
            &signed.event,
            authorization_out,
            authorization_json_out,
        );
        return .{ .url = prepared.url, .request_json = prepared.request_json, .authorization = authorization };
    }

    pub fn postPrepared(
        _: Client,
        http: transport.HttpClient,
        prepared: *const PreparedAuthorizedPost,
        response_json_out: []u8,
    ) (transport.HttpError || AdminTargetError)![]const u8 {
        return postJson(http, prepared.url, prepared.authorization, prepared.request_json, response_json_out);
    }

    pub fn parseSupportedMethodsResponse(
        _: Client,
        response_json: []const u8,
        methods_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .supportedmethods, methods_out, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseBanPubkeyResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .banpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseUnbanPubkeyResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .unbanpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseAllowPubkeyResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .allowpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseUnallowPubkeyResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .unallowpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseAllowEventResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .allowevent, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseAllowKindResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .allowkind, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseDisallowKindResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .disallowkind, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseChangeRelayNameResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .changerelayname, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseChangeRelayDescriptionResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .changerelaydescription, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseChangeRelayIconResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .changerelayicon, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseBlockIpResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .blockip, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseUnblockIpResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .unblockip, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseBanEventResponse(
        _: Client,
        response_json: []const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .banevent, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseListAllowedKindsResponse(
        _: Client,
        response_json: []const u8,
        kinds_out: []u32,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listallowedkinds, &.{}, &.{}, &.{}, &.{}, kinds_out, scratch);
    }

    pub fn parseListAllowedPubkeysResponse(
        _: Client,
        response_json: []const u8,
        pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listallowedpubkeys, &.{}, pubkeys_out, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseListBannedPubkeysResponse(
        _: Client,
        response_json: []const u8,
        pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listbannedpubkeys, &.{}, pubkeys_out, &.{}, &.{}, &.{}, scratch);
    }

    pub fn parseListBlockedIpsResponse(
        _: Client,
        response_json: []const u8,
        ips_out: []noztr.nip86_relay_management.IpReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listblockedips, &.{}, &.{}, &.{}, ips_out, &.{}, scratch);
    }

    pub fn parseListBannedEventsResponse(
        _: Client,
        response_json: []const u8,
        events_out: []noztr.nip86_relay_management.EventIdReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listbannedevents, &.{}, &.{}, events_out, &.{}, &.{}, scratch);
    }

    pub fn parseListEventsNeedingModerationResponse(
        _: Client,
        response_json: []const u8,
        events_out: []noztr.nip86_relay_management.EventIdReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        return parseResponse(response_json, .listeventsneedingmoderation, &.{}, &.{}, events_out, &.{}, &.{}, scratch);
    }

    pub fn fetchSupportedMethods(
        _: Client,
        http: transport.HttpClient,
        request: *const SupportedMethodsRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        methods_out: [][]const u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .supportedmethods);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .supportedmethods, methods_out, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn banPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const BanPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .banpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .banpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn unbanPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const UnbanPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .unbanpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .unbanpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn allowPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const AllowPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .allowpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .allowpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn unallowPubkey(
        _: Client,
        http: transport.HttpClient,
        request: *const UnallowPubkeyRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .unallowpubkey = .{ .pubkey = request.pubkey, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .unallowpubkey, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn allowEvent(
        _: Client,
        http: transport.HttpClient,
        request: *const AllowEventRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .allowevent = .{ .id = request.id, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .allowevent, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn allowKind(
        _: Client,
        http: transport.HttpClient,
        request: *const AllowKindRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .{ .allowkind = request.kind });
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .allowkind, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn disallowKind(
        _: Client,
        http: transport.HttpClient,
        request: *const DisallowKindRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .{ .disallowkind = request.kind });
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .disallowkind, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn changeRelayName(
        _: Client,
        http: transport.HttpClient,
        request: *const ChangeRelayNameRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .{ .changerelayname = request.name });
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .changerelayname, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn changeRelayDescription(
        _: Client,
        http: transport.HttpClient,
        request: *const ChangeRelayDescriptionRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .changerelaydescription = request.description },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .changerelaydescription, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn changeRelayIcon(
        _: Client,
        http: transport.HttpClient,
        request: *const ChangeRelayIconRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .{ .changerelayicon = request.icon });
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .changerelayicon, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn blockIp(
        _: Client,
        http: transport.HttpClient,
        request: *const BlockIpRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .blockip = .{ .ip = request.ip, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .blockip, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn unblockIp(
        _: Client,
        http: transport.HttpClient,
        request: *const UnblockIpRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .{ .unblockip = request.ip });
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .unblockip, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn banEvent(
        _: Client,
        http: transport.HttpClient,
        request: *const BanEventRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(
            request_json_out,
            .{ .banevent = .{ .id = request.id, .reason = request.reason } },
        );
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .banevent, &.{}, &.{}, &.{}, &.{}, &.{}, scratch);
    }

    pub fn fetchListAllowedKinds(
        _: Client,
        http: transport.HttpClient,
        request: *const ListAllowedKindsRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        kinds_out: []u32,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listallowedkinds);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listallowedkinds, &.{}, &.{}, &.{}, &.{}, kinds_out, scratch);
    }

    pub fn fetchListAllowedPubkeys(
        _: Client,
        http: transport.HttpClient,
        request: *const ListAllowedPubkeysRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listallowedpubkeys);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listallowedpubkeys, &.{}, pubkeys_out, &.{}, &.{}, &.{}, scratch);
    }

    pub fn fetchListBannedPubkeys(
        _: Client,
        http: transport.HttpClient,
        request: *const ListBannedPubkeysRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listbannedpubkeys);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listbannedpubkeys, &.{}, pubkeys_out, &.{}, &.{}, &.{}, scratch);
    }

    pub fn fetchListBlockedIps(
        _: Client,
        http: transport.HttpClient,
        request: *const ListBlockedIpsRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        ips_out: []noztr.nip86_relay_management.IpReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listblockedips);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listblockedips, &.{}, &.{}, &.{}, ips_out, &.{}, scratch);
    }

    pub fn fetchListBannedEvents(
        _: Client,
        http: transport.HttpClient,
        request: *const ListBannedEventsRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        events_out: []noztr.nip86_relay_management.EventIdReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listbannedevents);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listbannedevents, &.{}, &.{}, events_out, &.{}, &.{}, scratch);
    }

    pub fn fetchListEventsNeedingModeration(
        _: Client,
        http: transport.HttpClient,
        request: *const ListEventsNeedingModerationRequest,
        request_json_out: []u8,
        response_json_out: []u8,
        events_out: []noztr.nip86_relay_management.EventIdReason,
        scratch: std.mem.Allocator,
    ) Error!noztr.nip86_relay_management.Response {
        const request_json = try serializeRequestJson(request_json_out, .listeventsneedingmoderation);
        const response_json = try postJson(http, request.url, request.authorization, request_json, response_json_out);
        return parseResponse(response_json, .listeventsneedingmoderation, &.{}, &.{}, events_out, &.{}, &.{}, scratch);
    }
};

fn serializeRequestJson(
    request_json_out: []u8,
    request: noztr.nip86_relay_management.Request,
) noztr.nip86_relay_management.RelayManagementError![]const u8 {
    return noztr.nip86_relay_management.request_serialize_json(request_json_out, request);
}

fn postJson(
    http: transport.HttpClient,
    url: []const u8,
    authorization: ?[]const u8,
    request_json: []const u8,
    response_json_out: []u8,
) (transport.HttpError || AdminTargetError)![]const u8 {
    try validateAdminPostTarget(url);
    return http.post(.{
        .url = url,
        .body = request_json,
        .accept = "application/json",
        .content_type = "application/json",
        .authorization = authorization,
    }, response_json_out);
}

fn validateAdminPostTarget(url: []const u8) AdminTargetError!void {
    if (url.len == 0) return error.InvalidAdminTarget;
    const parsed = std.Uri.parse(url) catch return error.InvalidAdminTarget;
    if (parsed.host == null) return error.InvalidAdminTarget;
    if (!std.ascii.eqlIgnoreCase(parsed.scheme, "https")) return error.InvalidAdminTarget;
}

fn parseResponse(
    response_json: []const u8,
    expected_method: noztr.nip86_relay_management.RelayManagementMethod,
    methods_out: [][]const u8,
    pubkeys_out: []noztr.nip86_relay_management.PubkeyReason,
    events_out: []noztr.nip86_relay_management.EventIdReason,
    ips_out: []noztr.nip86_relay_management.IpReason,
    kinds_out: []u32,
    scratch: std.mem.Allocator,
) Error!noztr.nip86_relay_management.Response {
    return noztr.nip86_relay_management.response_parse_json(
        response_json,
        expected_method,
        methods_out,
        pubkeys_out,
        events_out,
        kinds_out,
        ips_out,
        scratch,
    );
}

const SignedPostAuthorization = struct {
    url_tag: noztr.nip98_http_auth.TagBuilder,
    method_tag: noztr.nip98_http_auth.TagBuilder,
    payload_tag: noztr.nip98_http_auth.TagBuilder,
    tags: [3]noztr.nip01_event.EventTag,
    event: noztr.nip01_event.Event,
};

fn buildSignedPostAuthorization(
    secret_key: *const [32]u8,
    url: []const u8,
    payload_hex: []const u8,
    created_at: u64,
) !SignedPostAuthorization {
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(secret_key);
    var signed = SignedPostAuthorization{
        .url_tag = .{},
        .method_tag = .{},
        .payload_tag = .{},
        .tags = undefined,
        .event = undefined,
    };
    signed.tags = .{
        try noztr.nip98_http_auth.http_auth_build_url_tag(&signed.url_tag, url),
        try noztr.nip98_http_auth.http_auth_build_method_tag(&signed.method_tag, PreparedPost.method),
        try noztr.nip98_http_auth.http_auth_build_payload_tag(&signed.payload_tag, payload_hex),
    };
    signed.event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip98_http_auth.http_auth_kind,
        .created_at = created_at,
        .content = "",
        .tags = signed.tags[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(secret_key, &signed.event);
    return signed;
}

test "relay management client posts supportedmethods and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    const expected_body = "{\"method\":\"supportedmethods\",\"params\":[]}";
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = expected_body,
        .response_body = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchSupportedMethods(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        methods[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .methods);
    try std.testing.expectEqualStrings("banpubkey", response.result.methods[1]);
}

test "relay management client prepares caller-driven NIP-98 auth for POST bodies" {
    const secret_key = [_]u8{0x22} ** 32;

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var decoded_json: [1024]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.preparePost(
        "https://relay.example/admin",
        .supportedmethods,
        request_json[0..],
        payload_hex[0..],
    );
    try std.testing.expectEqualStrings(
        "{\"method\":\"supportedmethods\",\"params\":[]}",
        prepared.request_json,
    );

    const signed = try buildSignedPostAuthorization(
        &secret_key,
        prepared.url,
        prepared.payload_hex,
        1_700_000_000,
    );
    const header = try client.encodePreparedAuthorization(
        &prepared,
        &signed.event,
        authorization[0..],
        authorization_json[0..],
    );
    const verified = try noztr.nip98_http_auth.http_auth_verify_authorization_header(
        decoded_json[0..],
        header,
        prepared.url,
        PreparedPost.method,
        prepared.payload_hex,
        signed.event.created_at,
        0,
        0,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("Nostr ", header[0..noztr.nip98_http_auth.authorization_scheme.len]);
    try std.testing.expectEqualStrings(prepared.url, verified.info.url);
    try std.testing.expectEqualStrings(PreparedPost.method, verified.info.method);
    try std.testing.expectEqualStrings(prepared.payload_hex, verified.info.payload_hex.?);
}

test "relay management client preparePost rejects malformed admin URL" {
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.preparePost("://bad-url", .supportedmethods, request_json[0..], payload_hex[0..]),
    );
}

test "relay management client preparePost rejects hostless admin URL" {
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.preparePost("https:///admin", .supportedmethods, request_json[0..], payload_hex[0..]),
    );
}

test "relay management client preparePost rejects non-https admin URL" {
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.preparePost("http://relay.example/admin", .supportedmethods, request_json[0..], payload_hex[0..]),
    );
}

test "relay management client fetchSupportedMethods rejects malformed admin URL" {
    const FakeHttp = struct {
        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{};
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "://bad-url" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}

test "relay management client fetchSupportedMethods rejects hostless admin URL" {
    const FakeHttp = struct {
        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{};
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "https:///admin" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}

test "relay management client fetchSupportedMethods rejects non-https admin URL" {
    const FakeHttp = struct {
        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{};
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "http://relay.example/admin" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}

test "relay management client executes prepared authorized posts coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,
        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }
        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }
        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x34} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .supportedmethods,
        &secret_key,
        1_700_000_300,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseSupportedMethodsResponse(response_json_slice, methods[0..], arena.allocator());

    try std.testing.expect(response.result == .methods);
    try std.testing.expectEqualStrings("banpubkey", response.result.methods[1]);
}

test "relay management client posts banpubkey and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const pubkey = [_]u8{0x11} ** 32;
    const expected_body =
        "{\"method\":\"banpubkey\",\"params\":[\"1111111111111111111111111111111111111111111111111111111111111111\",\"spam\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.banPubkey(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .pubkey = pubkey, .reason = "spam" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts unbanpubkey and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const pubkey = [_]u8{0x12} ** 32;
    const expected_body =
        "{\"method\":\"unbanpubkey\",\"params\":[\"1212121212121212121212121212121212121212121212121212121212121212\",\"appeal\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.unbanPubkey(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .pubkey = pubkey, .reason = "appeal" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts blockip and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body = "{\"method\":\"blockip\",\"params\":[\"127.0.0.1\",\"abuse\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.blockIp(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .ip = "127.0.0.1", .reason = "abuse" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts unblockip and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body = "{\"method\":\"unblockip\",\"params\":[\"127.0.0.1\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [96]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.unblockIp(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .ip = "127.0.0.1" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts allowpubkey and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const pubkey = [_]u8{0xaa} ** 32;
    const expected_body =
        "{\"method\":\"allowpubkey\",\"params\":[\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"operator\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.allowPubkey(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .pubkey = pubkey, .reason = "operator" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts unallowpubkey and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const pubkey = [_]u8{0xab} ** 32;
    const expected_body =
        "{\"method\":\"unallowpubkey\",\"params\":[\"abababababababababababababababababababababababababababababababab\",\"cleanup\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.unallowPubkey(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .pubkey = pubkey, .reason = "cleanup" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts allowevent and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const event_id = [_]u8{0xbb} ** 32;
    const expected_body =
        "{\"method\":\"allowevent\",\"params\":[\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"reviewed\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.allowEvent(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .id = event_id, .reason = "reviewed" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts allowkind and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body = "{\"method\":\"allowkind\",\"params\":[1984]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [96]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.allowKind(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .kind = 1984 },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts disallowkind and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body = "{\"method\":\"disallowkind\",\"params\":[1985]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [96]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.disallowKind(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .kind = 1985 },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts changerelaydescription and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body =
        "{\"method\":\"changerelaydescription\",\"params\":[\"Bounded moderated relay\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [160]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.changeRelayDescription(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .description = "Bounded moderated relay" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts changerelayicon and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const expected_body =
        "{\"method\":\"changerelayicon\",\"params\":[\"https://relay.example/icon.png\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [160]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.changeRelayIcon(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .icon = "https://relay.example/icon.png" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts banevent and parses ack response" {
    const FakeHttp = struct {
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const event_id = [_]u8{0x33} ** 32;
    const expected_body =
        "{\"method\":\"banevent\",\"params\":[\"3333333333333333333333333333333333333333333333333333333333333333\",\"malware\"]}";
    var fake = FakeHttp{ .expected_body = expected_body, .response_body = "{\"result\":true,\"error\":null}" };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [192]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.banEvent(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .id = event_id, .reason = "malware" },
        request_json[0..],
        response_json[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ack);
}

test "relay management client parses prepared changerelayname responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response = "{\"result\":true,\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x56} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .{ .changerelayname = "Noztr Relay" },
        &secret_key,
        1_700_000_500,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseChangeRelayNameResponse(response_json_slice, arena.allocator());

    try std.testing.expect(response.result == .ack);
}

test "relay management client posts listallowedkinds and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listallowedkinds\",\"params\":[]}",
        .response_body = "{\"result\":[1,1984],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var kinds: [2]u32 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListAllowedKinds(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        kinds[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .kinds);
    try std.testing.expectEqual(@as(usize, 2), response.result.kinds.len);
    try std.testing.expectEqual(@as(u32, 1984), response.result.kinds[1]);
}

test "relay management client posts listallowedpubkeys and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const first_pubkey = [_]u8{0x11} ** 32;
    const second_pubkey = [_]u8{0x22} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listallowedpubkeys\",\"params\":[]}",
        .response_body = "{\"result\":[{\"pubkey\":\"1111111111111111111111111111111111111111111111111111111111111111\",\"reason\":\"seed\"},{\"pubkey\":\"2222222222222222222222222222222222222222222222222222222222222222\"}],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [256]u8 = undefined;
    var pubkeys: [2]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListAllowedPubkeys(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        pubkeys[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 2), response.result.pubkeys.len);
    try std.testing.expectEqualDeep(first_pubkey, response.result.pubkeys[0].pubkey);
    try std.testing.expectEqualStrings("seed", response.result.pubkeys[0].reason.?);
    try std.testing.expectEqualDeep(second_pubkey, response.result.pubkeys[1].pubkey);
    try std.testing.expect(response.result.pubkeys[1].reason == null);
}

test "relay management client parses prepared listallowedpubkeys responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response =
                "{\"result\":[{\"pubkey\":\"4444444444444444444444444444444444444444444444444444444444444444\",\"reason\":\"vip\"}],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x45} ** 32;
    const expected_pubkey = [_]u8{0x44} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [192]u8 = undefined;
    var pubkeys: [1]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listallowedpubkeys,
        &secret_key,
        1_700_000_400,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseListAllowedPubkeysResponse(
        response_json_slice,
        pubkeys[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 1), response.result.pubkeys.len);
    try std.testing.expectEqualDeep(expected_pubkey, response.result.pubkeys[0].pubkey);
    try std.testing.expectEqualStrings("vip", response.result.pubkeys[0].reason.?);
}

test "relay management client posts listbannedpubkeys and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const first_pubkey = [_]u8{0x33} ** 32;
    const second_pubkey = [_]u8{0x44} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listbannedpubkeys\",\"params\":[]}",
        .response_body = "{\"result\":[{\"pubkey\":\"3333333333333333333333333333333333333333333333333333333333333333\",\"reason\":\"spam\"},{\"pubkey\":\"4444444444444444444444444444444444444444444444444444444444444444\"}],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [256]u8 = undefined;
    var pubkeys: [2]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListBannedPubkeys(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        pubkeys[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 2), response.result.pubkeys.len);
    try std.testing.expectEqualDeep(first_pubkey, response.result.pubkeys[0].pubkey);
    try std.testing.expectEqualStrings("spam", response.result.pubkeys[0].reason.?);
    try std.testing.expectEqualDeep(second_pubkey, response.result.pubkeys[1].pubkey);
    try std.testing.expect(response.result.pubkeys[1].reason == null);
}

test "relay management client parses prepared listbannedpubkeys responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response =
                "{\"result\":[{\"pubkey\":\"5555555555555555555555555555555555555555555555555555555555555555\",\"reason\":\"banlist\"}],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x49} ** 32;
    const expected_pubkey = [_]u8{0x55} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [192]u8 = undefined;
    var pubkeys: [1]noztr.nip86_relay_management.PubkeyReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listbannedpubkeys,
        &secret_key,
        1_700_000_425,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseListBannedPubkeysResponse(
        response_json_slice,
        pubkeys[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 1), response.result.pubkeys.len);
    try std.testing.expectEqualDeep(expected_pubkey, response.result.pubkeys[0].pubkey);
    try std.testing.expectEqualStrings("banlist", response.result.pubkeys[0].reason.?);
}

test "relay management client posts listbannedevents and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const first_event = [_]u8{0x55} ** 32;
    const second_event = [_]u8{0x66} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listbannedevents\",\"params\":[]}",
        .response_body = "{\"result\":[{\"id\":\"5555555555555555555555555555555555555555555555555555555555555555\",\"reason\":\"malware\"},{\"id\":\"6666666666666666666666666666666666666666666666666666666666666666\"}],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [256]u8 = undefined;
    var events: [2]noztr.nip86_relay_management.EventIdReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListBannedEvents(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        events[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .events);
    try std.testing.expectEqual(@as(usize, 2), response.result.events.len);
    try std.testing.expectEqualDeep(first_event, response.result.events[0].id);
    try std.testing.expectEqualStrings("malware", response.result.events[0].reason.?);
    try std.testing.expectEqualDeep(second_event, response.result.events[1].id);
    try std.testing.expect(response.result.events[1].reason == null);
}

test "relay management client posts listeventsneedingmoderation and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    const first_event = [_]u8{0x88} ** 32;
    const second_event = [_]u8{0x99} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listeventsneedingmoderation\",\"params\":[]}",
        .response_body = "{\"result\":[{\"id\":\"8888888888888888888888888888888888888888888888888888888888888888\",\"reason\":\"reported\"},{\"id\":\"9999999999999999999999999999999999999999999999999999999999999999\"}],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [256]u8 = undefined;
    var events: [2]noztr.nip86_relay_management.EventIdReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListEventsNeedingModeration(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        events[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .events);
    try std.testing.expectEqual(@as(usize, 2), response.result.events.len);
    try std.testing.expectEqualDeep(first_event, response.result.events[0].id);
    try std.testing.expectEqualStrings("reported", response.result.events[0].reason.?);
    try std.testing.expectEqualDeep(second_event, response.result.events[1].id);
    try std.testing.expect(response.result.events[1].reason == null);
}

test "relay management client posts listblockedips and parses typed list response" {
    const FakeHttp = struct {
        expected_url: []const u8,
        expected_authorization: ?[]const u8,
        expected_body: []const u8,
        response_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.url, self.expected_url)) return error.NotFound;
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (self.expected_authorization) |authorization| {
                if (request.authorization == null) return error.InvalidResponse;
                if (!std.mem.eql(u8, request.authorization.?, authorization)) return error.InvalidResponse;
            }
            if (self.response_body.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..self.response_body.len], self.response_body);
            return out[0..self.response_body.len];
        }
    };

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var fake = FakeHttp{
        .expected_url = "https://relay.example/admin",
        .expected_authorization = "Nostr token",
        .expected_body = "{\"method\":\"listblockedips\",\"params\":[]}",
        .response_body = "{\"result\":[{\"ip\":\"203.0.113.7\",\"reason\":\"scanner\"},{\"ip\":\"2001:db8::7\"}],\"error\":null}",
    };
    var request_json: [128]u8 = undefined;
    var response_json: [192]u8 = undefined;
    var ips: [2]noztr.nip86_relay_management.IpReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response = try client.fetchListBlockedIps(
        fake.client(),
        &.{ .url = "https://relay.example/admin", .authorization = "Nostr token" },
        request_json[0..],
        response_json[0..],
        ips[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .ips);
    try std.testing.expectEqual(@as(usize, 2), response.result.ips.len);
    try std.testing.expectEqualStrings("203.0.113.7", response.result.ips[0].ip);
    try std.testing.expectEqualStrings("scanner", response.result.ips[0].reason.?);
    try std.testing.expectEqualStrings("2001:db8::7", response.result.ips[1].ip);
    try std.testing.expect(response.result.ips[1].reason == null);
}

test "relay management client parses prepared listblockedips responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response =
                "{\"result\":[{\"ip\":\"198.51.100.42\",\"reason\":\"manual\"}],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x46} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var ips: [1]noztr.nip86_relay_management.IpReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listblockedips,
        &secret_key,
        1_700_000_500,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseListBlockedIpsResponse(response_json_slice, ips[0..], arena.allocator());

    try std.testing.expect(response.result == .ips);
    try std.testing.expectEqual(@as(usize, 1), response.result.ips.len);
    try std.testing.expectEqualStrings("198.51.100.42", response.result.ips[0].ip);
    try std.testing.expectEqualStrings("manual", response.result.ips[0].reason.?);
}

test "relay management client parses prepared listbannedevents responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response =
                "{\"result\":[{\"id\":\"7777777777777777777777777777777777777777777777777777777777777777\",\"reason\":\"reviewed\"}],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x47} ** 32;
    const expected_event = [_]u8{0x77} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [192]u8 = undefined;
    var events: [1]noztr.nip86_relay_management.EventIdReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listbannedevents,
        &secret_key,
        1_700_000_550,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseListBannedEventsResponse(
        response_json_slice,
        events[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .events);
    try std.testing.expectEqual(@as(usize, 1), response.result.events.len);
    try std.testing.expectEqualDeep(expected_event, response.result.events[0].id);
    try std.testing.expectEqualStrings("reviewed", response.result.events[0].reason.?);
}

test "relay management client parses prepared listeventsneedingmoderation responses coherently" {
    const FakeHttp = struct {
        expected_body: []const u8,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (!std.mem.eql(u8, request.body, self.expected_body)) return error.InvalidResponse;
            if (request.authorization == null) return error.InvalidResponse;
            const response =
                "{\"result\":[{\"id\":\"abababababababababababababababababababababababababababababababab\",\"reason\":\"queue\"}],\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x48} ** 32;
    const expected_event = [_]u8{0xab} ** 32;
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var response_json: [192]u8 = undefined;
    var events: [1]noztr.nip86_relay_management.EventIdReason = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.prepareAuthorizedPost(
        "https://relay.example/admin",
        .listeventsneedingmoderation,
        &secret_key,
        1_700_000_575,
        request_json[0..],
        payload_hex[0..],
        authorization[0..],
        authorization_json[0..],
    );
    var fake = FakeHttp{ .expected_body = prepared.request_json };
    const response_json_slice = try client.postPrepared(fake.client(), &prepared, response_json[0..]);
    const response = try client.parseListEventsNeedingModerationResponse(
        response_json_slice,
        events[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .events);
    try std.testing.expectEqual(@as(usize, 1), response.result.events.len);
    try std.testing.expectEqualDeep(expected_event, response.result.events[0].id);
    try std.testing.expectEqualStrings("queue", response.result.events[0].reason.?);
}

test "relay management client accepts explicit NIP-98 authorization headers" {
    const FakeHttp = struct {
        created_at: u64,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = self, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(ctx: *anyopaque, request: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            const header = request.authorization orelse return error.InvalidResponse;
            var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
            const expected_payload = noztr.nip98_http_auth.http_auth_payload_sha256_hex(
                payload_hex[0..],
                request.body,
            ) catch return error.InvalidResponse;
            var decoded_json: [1024]u8 = undefined;
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();

            _ = noztr.nip98_http_auth.http_auth_verify_authorization_header(
                decoded_json[0..],
                header,
                request.url,
                PreparedPost.method,
                expected_payload,
                self.created_at,
                0,
                0,
                arena.allocator(),
            ) catch return error.InvalidResponse;

            const response = "{\"result\":[\"supportedmethods\",\"banpubkey\"],\"error\":null}";
            if (response.len > out.len) return error.ResponseTooLarge;
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    const secret_key = [_]u8{0x33} ** 32;
    const created_at: u64 = 1_700_000_100;
    var fake = FakeHttp{ .created_at = created_at };
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var nip98_request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [2][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const prepared = try client.preparePost(
        "https://relay.example/admin",
        .supportedmethods,
        nip98_request_json[0..],
        payload_hex[0..],
    );
    const signed = try buildSignedPostAuthorization(
        &secret_key,
        prepared.url,
        prepared.payload_hex,
        created_at,
    );
    const header = try client.encodePreparedAuthorization(
        &prepared,
        &signed.event,
        authorization[0..],
        authorization_json[0..],
    );

    const response = try client.fetchSupportedMethods(
        fake.client(),
        &.{ .url = prepared.url, .authorization = header },
        request_json[0..],
        response_json[0..],
        methods[0..],
        arena.allocator(),
    );

    try std.testing.expect(response.result == .methods);
    try std.testing.expectEqualStrings("supportedmethods", response.result.methods[0]);
}

test "relay management client rejects mismatched prepared NIP-98 auth events" {
    const secret_key = [_]u8{0x44} ** 32;

    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    var authorization: [1024]u8 = undefined;
    var authorization_json: [1024]u8 = undefined;

    const prepared = try client.preparePost(
        "https://relay.example/admin",
        .supportedmethods,
        request_json[0..],
        payload_hex[0..],
    );
    const signed = try buildSignedPostAuthorization(
        &secret_key,
        "https://relay.example/other",
        prepared.payload_hex,
        1_700_000_200,
    );

    try std.testing.expectError(
        error.UrlMismatch,
        client.encodePreparedAuthorization(
            &prepared,
            &signed.event,
            authorization[0..],
            authorization_json[0..],
        ),
    );
}

test "relay management client surfaces invalid relay-management responses" {
    const FakeHttp = struct {
        dummy: u8 = 0,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = &self.dummy, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, out: []u8) transport.HttpError![]const u8 {
            const response = "{\"result\":\"bad\",\"error\":null}";
            @memcpy(out[0..response.len], response);
            return out[0..response.len];
        }
    };

    var fake = FakeHttp{};
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var response_json: [64]u8 = undefined;
    var methods: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidResponse,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "https://relay.example/admin" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}

test "relay management client rejects malformed admin targets before preparing posts" {
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.preparePost(
            "://bad",
            .supportedmethods,
            request_json[0..],
            payload_hex[0..],
        ),
    );
}

test "relay management client rejects hostless admin targets before preparing posts" {
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.preparePost(
            "https:///admin",
            .supportedmethods,
            request_json[0..],
            payload_hex[0..],
        ),
    );
}

test "relay management client rejects non-https admin targets before preparing posts" {
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var payload_hex: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.preparePost(
            "http://relay.example/admin",
            .supportedmethods,
            request_json[0..],
            payload_hex[0..],
        ),
    );
}

test "relay management client rejects malformed admin targets on direct post paths" {
    const FakeHttp = struct {
        dummy: u8 = 0,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = &self.dummy, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, _: []u8) transport.HttpError![]const u8 {
            return error.InvalidResponse;
        }
    };

    var fake = FakeHttp{};
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "://bad" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}

test "relay management client rejects hostless admin targets on direct post paths" {
    const FakeHttp = struct {
        dummy: u8 = 0,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = &self.dummy, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, _: []u8) transport.HttpError![]const u8 {
            return error.InvalidResponse;
        }
    };

    var fake = FakeHttp{};
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "https:///admin" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}

test "relay management client rejects non-https admin targets on direct post paths" {
    const FakeHttp = struct {
        dummy: u8 = 0,

        fn client(self: *@This()) transport.HttpClient {
            return .{ .ctx = &self.dummy, .get_fn = get, .post_fn = post };
        }

        fn get(_: *anyopaque, _: transport.HttpRequest, _: []u8) transport.HttpError![]const u8 {
            return error.NotFound;
        }

        fn post(_: *anyopaque, _: transport.HttpPostRequest, _: []u8) transport.HttpError![]const u8 {
            return error.InvalidResponse;
        }
    };

    var fake = FakeHttp{};
    var storage = Storage{};
    const client = Client.init(.{}, &storage);
    var request_json: [128]u8 = undefined;
    var response_json: [128]u8 = undefined;
    var methods: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidAdminTarget,
        client.fetchSupportedMethods(
            fake.client(),
            &.{ .url = "http://relay.example/admin" },
            request_json[0..],
            response_json[0..],
            methods[0..],
            arena.allocator(),
        ),
    );
}
