const std = @import("std");
const noztr = @import("noztr");
const local_operator = @import("local_operator_client.zig");
const legacy_dm_subscription_turn = @import("legacy_dm_subscription_turn_client.zig");
const relay_lifecycle_support = @import("relay_lifecycle_support.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_auth_support = @import("relay_auth_support.zig");
const runtime = @import("../runtime/mod.zig");

pub const LegacyDmSubscriptionJobClientError =
    legacy_dm_subscription_turn.LegacyDmSubscriptionTurnClientError ||
    local_operator.LocalOperatorClientError ||
    noztr.nip01_message.MessageEncodeError ||
    error{
        NoReadyRelay,
        StaleAuthStep,
        RelayNotReady,
    };

pub const LegacyDmSubscriptionJobClientConfig = struct {
    owner_private_key: [local_operator.secret_key_bytes]u8,
    local_operator: local_operator.LocalOperatorClientConfig = .{},
    subscription_turn: legacy_dm_subscription_turn.LegacyDmSubscriptionTurnClientConfig = undefined,
};

pub const LegacyDmSubscriptionJobClientStorage = struct {
    subscription_turn: legacy_dm_subscription_turn.LegacyDmSubscriptionTurnClientStorage = .{},
};

pub const LegacyDmSubscriptionJobAuthEventStorage = relay_auth_client.RelayAuthEventStorage;
pub const PreparedLegacyDmSubscriptionJobAuthEvent = relay_auth_client.PreparedRelayAuthEvent;
pub const LegacyDmSubscriptionJobRequest = legacy_dm_subscription_turn.LegacyDmSubscriptionTurnRequest;
pub const LegacyDmSubscriptionJobIntake = legacy_dm_subscription_turn.LegacyDmSubscriptionTurnIntake;

pub const LegacyDmSubscriptionJobReady = union(enum) {
    authenticate: PreparedLegacyDmSubscriptionJobAuthEvent,
    subscription: LegacyDmSubscriptionJobRequest,
};

pub const LegacyDmSubscriptionJobResult = union(enum) {
    authenticated: runtime.RelayDescriptor,
    subscribed: legacy_dm_subscription_turn.LegacyDmSubscriptionTurnResult,
};

pub const LegacyDmSubscriptionJobClient = struct {
    config: LegacyDmSubscriptionJobClientConfig,
    local_operator: local_operator.LocalOperatorClient,
    subscription_turn: legacy_dm_subscription_turn.LegacyDmSubscriptionTurnClient,

    pub fn init(
        config: LegacyDmSubscriptionJobClientConfig,
        storage: *LegacyDmSubscriptionJobClientStorage,
    ) LegacyDmSubscriptionJobClient {
        storage.* = .{};
        return .{
            .config = configWithSubscriptionTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .subscription_turn = legacy_dm_subscription_turn.LegacyDmSubscriptionTurnClient.init(
                configWithSubscriptionTurn(config).subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn attach(
        config: LegacyDmSubscriptionJobClientConfig,
        storage: *LegacyDmSubscriptionJobClientStorage,
    ) LegacyDmSubscriptionJobClient {
        return .{
            .config = configWithSubscriptionTurn(config),
            .local_operator = local_operator.LocalOperatorClient.init(config.local_operator),
            .subscription_turn = legacy_dm_subscription_turn.LegacyDmSubscriptionTurnClient.attach(
                configWithSubscriptionTurn(config).subscription_turn,
                &storage.subscription_turn,
            ),
        };
    }

    pub fn addRelay(
        self: *LegacyDmSubscriptionJobClient,
        relay_url_text: []const u8,
    ) LegacyDmSubscriptionJobClientError!runtime.RelayDescriptor {
        return relay_lifecycle_support.addRelay(self, "subscription_turn", relay_url_text);
    }

    pub fn markRelayConnected(
        self: *LegacyDmSubscriptionJobClient,
        relay_index: u8,
    ) LegacyDmSubscriptionJobClientError!void {
        return relay_lifecycle_support.markRelayConnected(self, "subscription_turn", relay_index);
    }

    pub fn noteRelayDisconnected(
        self: *LegacyDmSubscriptionJobClient,
        relay_index: u8,
    ) LegacyDmSubscriptionJobClientError!void {
        return relay_lifecycle_support.noteRelayDisconnected(
            self,
            "subscription_turn",
            relay_index,
        );
    }

    pub fn noteRelayAuthChallenge(
        self: *LegacyDmSubscriptionJobClient,
        relay_index: u8,
        challenge: []const u8,
    ) LegacyDmSubscriptionJobClientError!void {
        return relay_lifecycle_support.noteRelayAuthChallenge(
            self,
            "subscription_turn",
            relay_index,
            challenge,
        );
    }

    pub fn inspectRelayRuntime(
        self: *const LegacyDmSubscriptionJobClient,
        storage: *runtime.RelayPoolPlanStorage,
    ) runtime.RelayPoolPlan {
        return relay_lifecycle_support.inspectRelayRuntime(self, "subscription_turn", storage);
    }

    pub fn prepareJob(
        self: *LegacyDmSubscriptionJobClient,
        auth_storage: *LegacyDmSubscriptionJobAuthEventStorage,
        auth_event_json_output: []u8,
        auth_message_output: []u8,
        request_output: []u8,
        specs: []const runtime.RelaySubscriptionSpec,
        created_at: u64,
    ) LegacyDmSubscriptionJobClientError!LegacyDmSubscriptionJobReady {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const auth_plan = self.subscription_turn.inspectAuth(&auth_storage_buf);
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

        var subscription_storage_buf = runtime.RelayPoolSubscriptionStorage{};
        const subscription_plan = try self.subscription_turn.inspectSubscriptions(
            specs,
            &subscription_storage_buf,
        );
        _ = subscription_plan.nextStep() orelse return error.NoReadyRelay;
        return .{
            .subscription = try self.subscription_turn.beginTurn(request_output, specs),
        };
    }

    pub fn acceptPreparedAuthEvent(
        self: *LegacyDmSubscriptionJobClient,
        prepared: *const PreparedLegacyDmSubscriptionJobAuthEvent,
        now_unix_seconds: u64,
        window_seconds: u32,
    ) LegacyDmSubscriptionJobClientError!LegacyDmSubscriptionJobResult {
        const descriptor = try self.subscription_turn.acceptRelayAuthEvent(
            prepared.relay.relay_index,
            &prepared.event,
            now_unix_seconds,
            window_seconds,
        );
        return .{ .authenticated = descriptor };
    }

    pub fn acceptSubscriptionMessageJson(
        self: *LegacyDmSubscriptionJobClient,
        request: *const LegacyDmSubscriptionJobRequest,
        relay_message_json: []const u8,
        plaintext_output: []u8,
        scratch: std.mem.Allocator,
    ) LegacyDmSubscriptionJobClientError!LegacyDmSubscriptionJobIntake {
        return self.subscription_turn.acceptSubscriptionMessageJson(
            request,
            relay_message_json,
            plaintext_output,
            scratch,
        );
    }

    pub fn completeSubscriptionJob(
        self: *LegacyDmSubscriptionJobClient,
        output: []u8,
        request: *const LegacyDmSubscriptionJobRequest,
    ) LegacyDmSubscriptionJobClientError!LegacyDmSubscriptionJobResult {
        return .{ .subscribed = try self.subscription_turn.completeTurn(output, request) };
    }

    fn prepareAuthEvent(
        self: *LegacyDmSubscriptionJobClient,
        auth_storage: *LegacyDmSubscriptionJobAuthEventStorage,
        event_json_output: []u8,
        auth_message_output: []u8,
        step: *const runtime.RelayPoolAuthStep,
        created_at: u64,
    ) LegacyDmSubscriptionJobClientError!PreparedLegacyDmSubscriptionJobAuthEvent {
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
        self: *const LegacyDmSubscriptionJobClient,
        step: *const runtime.RelayPoolAuthStep,
    ) LegacyDmSubscriptionJobClientError!relay_auth_client.RelayAuthTarget {
        var auth_storage_buf = runtime.RelayPoolAuthStorage{};
        const plan = self.subscription_turn.inspectAuth(&auth_storage_buf);
        return relay_auth_support.selectAuthTarget(
            &self.subscription_turn.subscription_turn.relay_exchange.relay_pool,
            plan,
            step,
        );
    }
};

fn configWithSubscriptionTurn(
    config: LegacyDmSubscriptionJobClientConfig,
) LegacyDmSubscriptionJobClientConfig {
    var updated = config;
    updated.subscription_turn = .{
        .owner_private_key = config.owner_private_key,
        .subscription_turn = config.subscription_turn.subscription_turn,
    };
    return updated;
}
