const std = @import("std");
const runtime = @import("../runtime/mod.zig");

pub const SyncRuntimePlanStorage = struct {
    auth: runtime.RelayPoolAuthStorage = .{},
    replay: runtime.RelayPoolReplayStorage = .{},
    subscription: runtime.RelayPoolSubscriptionStorage = .{},
};

pub const LongLivedDmPolicyStorage = struct {
    relay_runtime: runtime.RelayPoolPlanStorage = .{},
    runtime: SyncRuntimePlanStorage = .{},
};

pub const DmOrchestrationStorage = struct {
    policy: LongLivedDmPolicyStorage = .{},
};

pub fn SyncRuntimeStep(comptime ReceiveRequest: type) type {
    return union(enum) {
        authenticate: runtime.RelayPoolAuthStep,
        replay: runtime.RelayPoolReplayStep,
        subscribe: runtime.RelayPoolSubscriptionStep,
        receive: ReceiveRequest,
        idle,
    };
}

pub fn SyncRuntimePlan(comptime ReceiveRequest: type) type {
    return struct {
        const Step = SyncRuntimeStep(ReceiveRequest);

        authenticate_count: u8 = 0,
        replay_count: u16 = 0,
        subscribe_count: u16 = 0,
        receive_count: u8 = 0,
        replay_phase_complete: bool = false,
        next_step: Step = .idle,

        pub fn nextStep(self: *const @This()) Step {
            return self.next_step;
        }
    };
}

pub fn LongLivedDmPolicyStep(comptime ReceiveRequest: type) type {
    return union(enum) {
        reconnect: runtime.RelayPoolStep,
        authenticate: runtime.RelayPoolAuthStep,
        replay_resume: runtime.RelayPoolReplayStep,
        subscribe_resume: runtime.RelayPoolSubscriptionStep,
        receive: ReceiveRequest,
        idle,
    };
}

pub fn LongLivedDmPolicyPlan(comptime ReceiveRequest: type) type {
    return struct {
        const Step = LongLivedDmPolicyStep(ReceiveRequest);

        relay_count: u8 = 0,
        reconnect_count: u8 = 0,
        authenticate_count: u8 = 0,
        replay_resume_count: u16 = 0,
        subscribe_resume_count: u16 = 0,
        receive_count: u8 = 0,
        replay_phase_complete: bool = false,
        live_subscription_active: bool = false,
        next_step: Step = .idle,

        pub fn nextStep(self: *const @This()) Step {
            return self.next_step;
        }
    };
}

pub fn DmOrchestrationStep(comptime ReceiveRequest: type) type {
    return union(enum) {
        configure_relays,
        reconnect: runtime.RelayPoolStep,
        authenticate: runtime.RelayPoolAuthStep,
        replay_resume: runtime.RelayPoolReplayStep,
        subscribe_resume: runtime.RelayPoolSubscriptionStep,
        receive: ReceiveRequest,
        idle,
    };
}

pub fn DmOrchestrationPlan(comptime ReceiveRequest: type) type {
    return struct {
        const Step = DmOrchestrationStep(ReceiveRequest);

        relay_count: u8 = 0,
        reconnect_count: u8 = 0,
        authenticate_count: u8 = 0,
        replay_resume_count: u16 = 0,
        subscribe_resume_count: u16 = 0,
        receive_count: u8 = 0,
        replay_phase_complete: bool = false,
        live_subscription_active: bool = false,
        needs_relay_configuration: bool = false,
        needs_connect_progress: bool = false,
        needs_auth_progress: bool = false,
        needs_replay_catchup: bool = false,
        needs_live_subscription: bool = false,
        can_receive_live: bool = false,
        next_step: Step = .idle,

        pub fn nextStep(self: *const @This()) Step {
            return self.next_step;
        }
    };
}

pub fn buildSyncRuntimePlan(
    comptime ReceiveRequest: type,
    auth_plan: runtime.RelayPoolAuthPlan,
    replay_plan: runtime.RelayPoolReplayPlan,
    subscription_plan: runtime.RelayPoolSubscriptionPlan,
    replay_phase_complete: bool,
    live_subscription_active: bool,
    live_subscription_request: ReceiveRequest,
) SyncRuntimePlan(ReceiveRequest) {
    var plan: SyncRuntimePlan(ReceiveRequest) = .{
        .authenticate_count = auth_plan.authenticate_count,
        .replay_count = if (replay_phase_complete) 0 else replay_plan.replay_count,
        .subscribe_count = subscription_plan.subscribe_count,
        .receive_count = if (live_subscription_active) 1 else 0,
        .replay_phase_complete = replay_phase_complete,
    };

    if (auth_plan.nextStep()) |step| {
        plan.next_step = .{ .authenticate = step };
        return plan;
    }
    if (live_subscription_active) {
        plan.next_step = .{ .receive = live_subscription_request };
        return plan;
    }
    if (!replay_phase_complete) {
        if (replay_plan.nextStep()) |step| {
            plan.next_step = .{ .replay = step };
            return plan;
        }
    }
    if (subscription_plan.nextStep()) |step| {
        plan.next_step = .{ .subscribe = step };
        return plan;
    }
    return plan;
}

pub fn classifyLongLivedDmPolicy(
    comptime ReceiveRequest: type,
    relay_count: u8,
    relay_runtime: runtime.RelayPoolPlan,
    runtime_plan: SyncRuntimePlan(ReceiveRequest),
    live_subscription_active: bool,
) LongLivedDmPolicyPlan(ReceiveRequest) {
    var plan: LongLivedDmPolicyPlan(ReceiveRequest) = .{
        .relay_count = relay_count,
        .reconnect_count = relay_runtime.connect_count,
        .authenticate_count = runtime_plan.authenticate_count,
        .replay_resume_count = runtime_plan.replay_count,
        .subscribe_resume_count = runtime_plan.subscribe_count,
        .receive_count = runtime_plan.receive_count,
        .replay_phase_complete = runtime_plan.replay_phase_complete,
        .live_subscription_active = live_subscription_active,
    };

    switch (runtime_plan.nextStep()) {
        .authenticate => |step| {
            plan.next_step = .{ .authenticate = step };
            return plan;
        },
        .receive => |request| {
            plan.next_step = .{ .receive = request };
            return plan;
        },
        else => {},
    }

    if (relay_runtime.nextStep()) |step| {
        if (step.entry.action == .connect) {
            plan.next_step = .{ .reconnect = step };
            return plan;
        }
    }

    switch (runtime_plan.nextStep()) {
        .replay => |step| plan.next_step = .{ .replay_resume = step },
        .subscribe => |step| plan.next_step = .{ .subscribe_resume = step },
        .idle => plan.next_step = .idle,
        .authenticate, .receive => unreachable,
    }
    return plan;
}

pub fn buildDmOrchestration(
    comptime ReceiveRequest: type,
    policy_plan: LongLivedDmPolicyPlan(ReceiveRequest),
) DmOrchestrationPlan(ReceiveRequest) {
    var plan: DmOrchestrationPlan(ReceiveRequest) = .{
        .relay_count = policy_plan.relay_count,
        .reconnect_count = policy_plan.reconnect_count,
        .authenticate_count = policy_plan.authenticate_count,
        .replay_resume_count = policy_plan.replay_resume_count,
        .subscribe_resume_count = policy_plan.subscribe_resume_count,
        .receive_count = policy_plan.receive_count,
        .replay_phase_complete = policy_plan.replay_phase_complete,
        .live_subscription_active = policy_plan.live_subscription_active,
        .needs_relay_configuration = policy_plan.relay_count == 0,
        .needs_connect_progress = policy_plan.reconnect_count != 0,
        .needs_auth_progress = policy_plan.authenticate_count != 0,
        .needs_replay_catchup = policy_plan.replay_resume_count != 0,
        .needs_live_subscription = policy_plan.subscribe_resume_count != 0,
        .can_receive_live = policy_plan.receive_count != 0,
    };

    if (policy_plan.relay_count == 0) {
        plan.next_step = .configure_relays;
        return plan;
    }

    switch (policy_plan.nextStep()) {
        .reconnect => |step| plan.next_step = .{ .reconnect = step },
        .authenticate => |step| plan.next_step = .{ .authenticate = step },
        .replay_resume => |step| plan.next_step = .{ .replay_resume = step },
        .subscribe_resume => |step| plan.next_step = .{ .subscribe_resume = step },
        .receive => |request| plan.next_step = .{ .receive = request },
        .idle => plan.next_step = .idle,
    }
    return plan;
}

test "shared dm sync runtime helper prioritizes auth then receive then replay then subscribe" {
    const ReceiveRequest = struct { token: u8 };

    const auth_entry = runtime.RelayPoolAuthEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .challenge = "challenge",
        .action = .authenticate,
    };
    const replay_entry = runtime.RelayPoolReplayEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "mailbox-sync",
        .action = .replay,
        .query = .{
            .kinds = &.{},
            .authors = &.{},
            .ids = &.{},
            .limit = 0,
            .since = null,
            .until = null,
        },
    };
    const subscription_entry = runtime.RelayPoolSubscriptionEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .subscription_id = "sub",
        .filters = &.{},
        .action = .subscribe,
    };

    const auth_plan = runtime.RelayPoolAuthPlan{
        .entries = (&[_]runtime.RelayPoolAuthEntry{auth_entry})[0..],
        .relay_count = 1,
        .authenticate_count = 1,
    };
    const replay_plan = runtime.RelayPoolReplayPlan{
        .entries = (&[_]runtime.RelayPoolReplayEntry{replay_entry})[0..],
        .entry_count = 1,
        .relay_count = 1,
        .replay_count = 1,
    };
    const subscription_plan = runtime.RelayPoolSubscriptionPlan{
        .entries = (&[_]runtime.RelayPoolSubscriptionEntry{subscription_entry})[0..],
        .entry_count = 1,
        .relay_count = 1,
        .subscribe_count = 1,
    };

    const auth_first = buildSyncRuntimePlan(
        ReceiveRequest,
        auth_plan,
        replay_plan,
        subscription_plan,
        false,
        true,
        .{ .token = 7 },
    );
    try std.testing.expect(auth_first.nextStep() == .authenticate);

    const receive_second = buildSyncRuntimePlan(
        ReceiveRequest,
        .{},
        replay_plan,
        subscription_plan,
        false,
        true,
        .{ .token = 7 },
    );
    try std.testing.expect(receive_second.nextStep() == .receive);

    const replay_third = buildSyncRuntimePlan(
        ReceiveRequest,
        .{},
        replay_plan,
        subscription_plan,
        false,
        false,
        .{ .token = 7 },
    );
    try std.testing.expect(replay_third.nextStep() == .replay);

    const subscribe_fourth = buildSyncRuntimePlan(
        ReceiveRequest,
        .{},
        replay_plan,
        subscription_plan,
        true,
        false,
        .{ .token = 7 },
    );
    try std.testing.expect(subscribe_fourth.nextStep() == .subscribe);
}

test "shared dm long-lived policy helper prioritizes receive then reconnect then replay resume" {
    const ReceiveRequest = struct { token: u8 };
    const runtime_plan = SyncRuntimePlan(ReceiveRequest){
        .receive_count = 1,
        .next_step = .{ .receive = .{ .token = 9 } },
    };
    const reconnect_entry = runtime.RelayPoolEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .action = .connect,
    };
    const relay_runtime = runtime.RelayPoolPlan{
        .entries = (&[_]runtime.RelayPoolEntry{reconnect_entry})[0..],
        .relay_count = 1,
        .connect_count = 1,
    };

    const receive_first = classifyLongLivedDmPolicy(
        ReceiveRequest,
        1,
        relay_runtime,
        runtime_plan,
        true,
    );
    try std.testing.expect(receive_first.nextStep() == .receive);

    const replay_entry = runtime.RelayPoolReplayEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "legacy-dm-sync",
        .action = .replay,
        .query = .{
            .kinds = &.{},
            .authors = &.{},
            .ids = &.{},
            .limit = 0,
            .since = null,
            .until = null,
        },
    };
    const replay_runtime = SyncRuntimePlan(ReceiveRequest){
        .replay_count = 1,
        .next_step = .{ .replay = .{ .entry = replay_entry } },
    };

    const reconnect_first = classifyLongLivedDmPolicy(
        ReceiveRequest,
        1,
        relay_runtime,
        replay_runtime,
        false,
    );
    try std.testing.expect(reconnect_first.nextStep() == .reconnect);

    const no_reconnect_runtime = runtime.RelayPoolPlan{};
    const replay_first = classifyLongLivedDmPolicy(
        ReceiveRequest,
        1,
        no_reconnect_runtime,
        replay_runtime,
        false,
    );
    try std.testing.expect(replay_first.nextStep() == .replay_resume);
}

test "shared dm orchestration helper surfaces relay configuration as a first-class phase" {
    const ReceiveRequest = struct { token: u8 };
    const plan = buildDmOrchestration(ReceiveRequest, .{});

    try std.testing.expect(plan.needs_relay_configuration);
    try std.testing.expect(plan.nextStep() == .configure_relays);
}

test "shared dm orchestration helper carries broader phase obligations" {
    const ReceiveRequest = struct { token: u8 };
    const reconnect_entry = runtime.RelayPoolEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .action = .connect,
    };
    const replay_entry = runtime.RelayPoolReplayEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .checkpoint_scope = "mailbox-sync",
        .action = .replay,
        .query = .{
            .kinds = &.{},
            .authors = &.{},
            .ids = &.{},
            .limit = 0,
            .since = null,
            .until = null,
        },
    };
    const policy = classifyLongLivedDmPolicy(
        ReceiveRequest,
        1,
        .{
            .entries = (&[_]runtime.RelayPoolEntry{reconnect_entry})[0..],
            .relay_count = 1,
            .connect_count = 1,
        },
        .{
            .replay_count = 1,
            .subscribe_count = 1,
            .next_step = .{ .replay = .{ .entry = replay_entry } },
        },
        false,
    );
    const plan = buildDmOrchestration(ReceiveRequest, policy);

    try std.testing.expect(!plan.needs_relay_configuration);
    try std.testing.expect(plan.needs_connect_progress);
    try std.testing.expect(plan.needs_replay_catchup);
    try std.testing.expect(plan.needs_live_subscription);
    try std.testing.expect(plan.nextStep() == .reconnect);
}
