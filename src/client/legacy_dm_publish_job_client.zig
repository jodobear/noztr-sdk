const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const relay_response = @import("relay_response_client.zig");
const runtime = @import("../runtime/mod.zig");
const workflows = @import("../workflows/mod.zig");

pub const LegacyDmPublishJobClientError =
    workflows.LegacyDmError ||
    local_operator.LocalOperatorClientError ||
    relay_response.RelayResponseClientError ||
    runtime.RelayPoolError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoAuthOrPublishStep,
        StaleAuthStep,
        RelayNotReady,
    };

pub const LegacyDmPublishJobClientConfig = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    relay_response: relay_response.RelayResponseClientConfig = .{},
};

pub const LegacyDmPublishJobClientStorage = struct {
    session: workflows.LegacyDmSession = undefined,
    outbound: workflows.LegacyDmOutboundStorage = .{},
    relay_pool: runtime.RelayPoolStorage = .{},
};

pub const LegacyDmPublishJobAuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedLegacyDmPublishJobAuthEvent = relay_auth_client.PreparedRelayAuthEvent;

pub const LegacyDmPublishJobRequest = struct {
    relay: runtime.RelayDescriptor,
    event: noztr.nip01_event.Event,
    event_json: []const u8,
    event_message_json: []const u8,
};

pub const LegacyDmPublishJobReady = union(enum) {
    authenticate: PreparedLegacyDmPublishJobAuthEvent,
    publish: LegacyDmPublishJobRequest,
};

pub const LegacyDmPublishJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    published: struct {
        request: LegacyDmPublishJobRequest,
        event_id: [32]u8,
        accepted: bool,
        status: []const u8,
    },
};

pub const LegacyDmPublishJobClient = struct {
    config: LegacyDmPublishJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    relay_response: relay_response.RelayResponseClient,
    relay_pool: runtime.RelayPool,
    storage: *LegacyDmPublishJobClientStorage,

    pub fn init(
        config: LegacyDmPublishJobClientConfig,
        storage: *LegacyDmPublishJobClientStorage,
    ) LegacyDmPublishJobClient {
        storage.* = .{
            .session = workflows.LegacyDmSession.init(&config.owner_private_key),
        };
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
            .storage = storage,
        };
    }

    pub fn attach(
        config: LegacyDmPublishJobClientConfig,
        storage: *LegacyDmPublishJobClientStorage,
    ) LegacyDmPublishJobClient {
        return .{
            .config = config,
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .relay_response = relay_response.RelayResponseClient.init(config.relay_response),
            .relay_pool = runtime.RelayPool.attach(&storage.relay_pool),
            .storage = storage,
        };
    }

    pub fn addRelay(
        self: *LegacyDmPublishJobClient,
        relay_url_text: []const u8,
    ) LegacyDmPublishJobClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "relay_pool", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *LegacyDmPublishJobClient,
        relay_index: u8,
    ) LegacyDmPublishJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LegacyDmPublishJobClient,
        relay_index: u8,
    ) LegacyDmPublishJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(self, "relay_pool", relay_index);
    }

    pub fn noteRelayAuthChallenge(
        self: *LegacyDmPublishJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) LegacyDmPublishJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "relay_pool",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const LegacyDmPublishJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "relay_pool", storage);
    }

    pub fn inspectAuth(
        self: *const LegacyDmPublishJobClient,
        storage: *runtime.RelayPoolAuthStorage,
    ) runtime.RelayPoolAuthPlan {
        return self.relay_pool.inspectAuth(storage);
    }

    pub fn inspectPublish(
        self: *const LegacyDmPublishJobClient,
        storage: *runtime.RelayPoolPublishStorage,
    ) runtime.RelayPoolPublishPlan {
        return self.relay_pool.inspectPublish(storage);
    }

    pub fn prepareJob(
        self: *LegacyDmPublishJobClient,
        auth_storage: *LegacyDmPublishJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        event_json_output: []u8,
        event_message_output: []u8,
        request: *const workflows.LegacyDmDirectMessageRequest,
        created_at: u64,
    ) LegacyDmPublishJobClientError!LegacyDmPublishJobReady {
        var auth_plan_storage = runtime.RelayPoolAuthStorage{};
        const auth_plan = self.inspectAuth(&auth_plan_storage);
        if (auth_plan.nextStep()) |step| {
            return .{
                .authenticate = try self.prepareAuthEvent(
                    auth_storage,
                    auth_event_json_output,
                    auth_message_output,
                    &step,
                    created_at,
                ),
            };
        }

        var publish_storage = runtime.RelayPoolPublishStorage{};
        const publish_plan = self.inspectPublish(&publish_storage);
        const publish_step = publish_plan.nextStep() orelse return error.NoAuthOrPublishStep;

        const prepared = try self.storage.session.buildDirectMessageEvent(&self.storage.outbound, request);
        const event_json = try self.storage.session.serializeDirectMessageEventJson(
            event_json_output,
            &prepared.event,
        );
        const event_message_json = try serializeEventClientMessage(
            event_message_output,
            &prepared.event,
        );
        return .{
            .publish = .{
                .relay = publish_step.entry.descriptor,
                .event = prepared.event,
                .event_json = event_json,
                .event_message_json = event_message_json,
            },
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *LegacyDmPublishJobClient,
        prepared: *const PreparedLegacyDmPublishJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) LegacyDmPublishJobClientError!LegacyDmPublishJobResult {
        try self.requireCurrentAuth(prepared.relay, prepared.challenge);
        try self.relay_pool.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = prepared.relay };
    }

    pub fn acceptPublishOkJson(
        self: *const LegacyDmPublishJobClient,
        request: *const LegacyDmPublishJobRequest,
        relay_message_json: []const u8,
        scratch: std.mem.Allocator,
    ) LegacyDmPublishJobClientError!LegacyDmPublishJobResult {
        const ok = try self.relay_response.acceptPublishOkJson(
            &request.event.id,
            relay_message_json,
            scratch,
        );
        return .{
            .published = .{
                .request = request.*,
                .event_id = ok.event_id,
                .accepted = ok.accepted,
                .status = ok.status,
            },
        };
    }

    fn prepareAuthEvent(
        self: *LegacyDmPublishJobClient,
        auth_storage: *LegacyDmPublishJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) LegacyDmPublishJobClientError!PreparedLegacyDmPublishJobAuthEvent {
        const target = try self.selectAuthTarget(step);
        const payload = try relay_auth_support.buildSignedAuthPayload(
            &self.local_operator,
            auth_storage,
            event_json_output,
            auth_message_output,
            &self.config.owner_private_key,
            created_at,
            target.relay.relay_url,
            target.challenge,
        );
        return .{
            .relay = target.relay,
            .challenge = auth_storage.challengeText(),
            .event = payload.event,
            .event_json = payload.event_json,
            .auth_message_json = payload.auth_message_json,
        };
    }

    fn selectAuthTarget(
        self: *const LegacyDmPublishJobClient,
        step: *const runtime.RelayPoolAuthStep,
    ) LegacyDmPublishJobClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.selectAuthTarget(&self.relay_pool, plan, step);
    }

    fn requireCurrentAuth(
        self: *const LegacyDmPublishJobClient,
        descriptor: runtime.RelayDescriptor,
        challenge: []const u8,
    ) LegacyDmPublishJobClientError!void {
        var auth_storage = runtime.RelayPoolAuthStorage{};
        const plan = self.inspectAuth(&auth_storage);
        return relay_auth_support.requireCurrentAuth(plan, descriptor, challenge);
    }
};

fn serializeEventClientMessage(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) LegacyDmPublishJobClientError![]const u8 {
    const prefix = "[\"EVENT\",";
    if (output.len < prefix.len + 1) return error.BufferTooSmall;

    @memcpy(output[0..prefix.len], prefix);
    const event_json = try noztr.nip01_event.event_serialize_json_object(
        output[prefix.len .. output.len - 1],
        event,
    );
    const end = prefix.len + event_json.len;
    output[end] = ']';
    return output[0 .. end + 1];
}

test "legacy dm publish job client exposes caller-owned config and storage" {
    var storage = LegacyDmPublishJobClientStorage{};
    var client = LegacyDmPublishJobClient.init(.{
        .owner_private_key = [_]u8{0x41} ** 32,
    }, &storage);

    try std.testing.expectEqual(@as(u8, 0), client.relay_pool.relayCount());
}

test "legacy dm publish job client prepares ready publish work without auth gating" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = LegacyDmPublishJobClientStorage{};
    var client = LegacyDmPublishJobClient.init(.{
        .owner_private_key = [_]u8{0x51} ** 32,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);

    const recipient_secret = [_]u8{0x61} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);
    var auth_storage = LegacyDmPublishJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    const ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        event_json_output[0..],
        event_message_output[0..],
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "ready legacy dm publish",
            .created_at = 51,
            .iv = [_]u8{0x33} ** noztr.limits.nip04_iv_bytes,
        },
        50,
    );
    try std.testing.expect(ready == .publish);
    try std.testing.expectEqual(relay.relay_index, ready.publish.relay.relay_index);

    var ok_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        ok_output[0..],
        &.{ .ok = .{ .event_id = ready.publish.event.id, .accepted = true, .status = "" } },
    );
    const result = try client.acceptPublishOkJson(&ready.publish, ok_json, arena.allocator());
    try std.testing.expect(result == .published);
    try std.testing.expect(result.published.accepted);
}

test "legacy dm publish job client drives auth-gated publish progression explicitly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var storage = LegacyDmPublishJobClientStorage{};
    var client = LegacyDmPublishJobClient.init(.{
        .owner_private_key = [_]u8{0x71} ** 32,
    }, &storage);
    const relay = try client.addRelay("wss://relay.one");
    try client.markRelayConnected(relay.relay_index);
    try client.noteRelayAuthChallenge(relay.relay_index, "challenge-1");

    const recipient_secret = [_]u8{0x81} ** 32;
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);
    var auth_storage = LegacyDmPublishJobAuthEventStorage{};
    var auth_event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var auth_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;
    var event_json_output: [noztr.limits.event_json_max]u8 = undefined;
    var event_message_output: [noztr.limits.relay_message_bytes_max]u8 = undefined;

    const first_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        event_json_output[0..],
        event_message_output[0..],
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "auth-gated legacy dm publish",
            .created_at = 71,
            .iv = [_]u8{0x44} ** noztr.limits.nip04_iv_bytes,
        },
        70,
    );
    try std.testing.expect(first_ready == .authenticate);

    const auth_result = try client.acceptPreparedAuthEvent(&first_ready.authenticate, 75, 60);
    try std.testing.expect(auth_result == .authenticated);

    const second_ready = try client.prepareJob(
        &auth_storage,
        auth_event_json_output[0..],
        auth_message_output[0..],
        event_json_output[0..],
        event_message_output[0..],
        &.{
            .recipient_pubkey = recipient_pubkey,
            .content = "auth-gated legacy dm publish",
            .created_at = 71,
            .iv = [_]u8{0x44} ** noztr.limits.nip04_iv_bytes,
        },
        70,
    );
    try std.testing.expect(second_ready == .publish);

    var ok_output: [256]u8 = undefined;
    const ok_json = try noztr.nip01_message.relay_message_serialize_json(
        ok_output[0..],
        &.{ .ok = .{ .event_id = second_ready.publish.event.id, .accepted = true, .status = "" } },
    );
    const publish_result = try client.acceptPublishOkJson(
        &second_ready.publish,
        ok_json,
        arena.allocator(),
    );
    try std.testing.expect(publish_result == .published);
    try std.testing.expect(publish_result.published.accepted);
}
