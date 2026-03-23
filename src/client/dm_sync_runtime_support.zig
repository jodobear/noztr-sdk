const std = @import("std");
const runtime = @import("../runtime/mod.zig");

pub const PlanStorage = struct {
    auth: runtime.RelayPoolAuthStorage = .{},
    replay: runtime.RelayPoolReplayStorage = .{},
    subscription: runtime.RelayPoolSubscriptionStorage = .{},
};

pub const PolicyStorage = struct {
    relay_runtime: runtime.RelayPoolPlanStorage = .{},
    runtime: PlanStorage = .{},
};

pub const OrchestrationStorage = struct {
    policy: PolicyStorage = .{},
};

pub const CadenceRequest = struct {
    now_unix_seconds: u64,
    reconnect_not_before_unix_seconds: ?u64 = null,
    subscribe_resume_not_before_unix_seconds: ?u64 = null,
    replay_refresh_not_before_unix_seconds: ?u64 = null,
};

pub const CadenceStorage = struct {
    orchestration: OrchestrationStorage = .{},
};

pub const CadenceWaitReason = enum {
    reconnect_backoff,
    subscribe_resume_backoff,
    replay_refresh_not_due_yet,
};

pub const CadenceWait = struct {
    reason: CadenceWaitReason,
    due_at_unix_seconds: u64,
};

pub fn Step(comptime ReceiveRequest: type) type {
    return union(enum) {
        authenticate: runtime.RelayPoolAuthStep,
        replay: runtime.RelayPoolReplayStep,
        subscribe: runtime.RelayPoolSubscriptionStep,
        receive: ReceiveRequest,
        idle,
    };
}

pub fn Plan(comptime ReceiveRequest: type) type {
    return struct {
        const NextStep = Step(ReceiveRequest);

        authenticate_count: u8 = 0,
        replay_count: u16 = 0,
        subscribe_count: u16 = 0,
        receive_count: u8 = 0,
        replay_phase_complete: bool = false,
        next_step: NextStep = .idle,

        pub fn nextStep(self: *const @This()) NextStep {
            return self.next_step;
        }
    };
}

pub fn PolicyStep(comptime ReceiveRequest: type) type {
    return union(enum) {
        reconnect: runtime.RelayPoolStep,
        authenticate: runtime.RelayPoolAuthStep,
        replay_resume: runtime.RelayPoolReplayStep,
        subscribe_resume: runtime.RelayPoolSubscriptionStep,
        receive: ReceiveRequest,
        idle,
    };
}

pub fn PolicyPlan(comptime ReceiveRequest: type) type {
    return struct {
        const NextStep = PolicyStep(ReceiveRequest);

        relay_count: u8 = 0,
        reconnect_count: u8 = 0,
        authenticate_count: u8 = 0,
        replay_resume_count: u16 = 0,
        subscribe_resume_count: u16 = 0,
        receive_count: u8 = 0,
        replay_phase_complete: bool = false,
        live_subscription_active: bool = false,
        next_step: NextStep = .idle,

        pub fn nextStep(self: *const @This()) NextStep {
            return self.next_step;
        }
    };
}

pub fn OrchestrationStep(comptime ReceiveRequest: type) type {
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

pub fn OrchestrationPlan(comptime ReceiveRequest: type) type {
    return struct {
        const NextStep = OrchestrationStep(ReceiveRequest);

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
        next_step: NextStep = .idle,

        pub fn nextStep(self: *const @This()) NextStep {
            return self.next_step;
        }
    };
}

pub fn CadenceStep(comptime ReceiveRequest: type) type {
    return union(enum) {
        wait: CadenceWait,
        reopen_replay_catchup,
        configure_relays,
        reconnect: runtime.RelayPoolStep,
        authenticate: runtime.RelayPoolAuthStep,
        replay_resume: runtime.RelayPoolReplayStep,
        subscribe_resume: runtime.RelayPoolSubscriptionStep,
        receive: ReceiveRequest,
        idle,
    };
}

pub fn CadencePlan(comptime ReceiveRequest: type) type {
    return struct {
        const NextStep = CadenceStep(ReceiveRequest);

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
        blocked_by_reconnect_backoff: bool = false,
        blocked_by_subscribe_backoff: bool = false,
        waiting_for_replay_refresh: bool = false,
        replay_refresh_due: bool = false,
        next_due_at_unix_seconds: ?u64 = null,
        next_step: NextStep = .idle,

        pub fn nextStep(self: *const @This()) NextStep {
            return self.next_step;
        }
    };
}

pub fn buildPlan(
    comptime ReceiveRequest: type,
    auth_plan: runtime.RelayPoolAuthPlan,
    replay_plan: runtime.RelayPoolReplayPlan,
    subscription_plan: runtime.RelayPoolSubscriptionPlan,
    replay_phase_complete: bool,
    live_subscription_active: bool,
    live_subscription_request: ReceiveRequest,
) Plan(ReceiveRequest) {
    var plan: Plan(ReceiveRequest) = .{
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

pub fn classifyPolicy(
    comptime ReceiveRequest: type,
    relay_count: u8,
    relay_runtime: runtime.RelayPoolPlan,
    runtime_plan: Plan(ReceiveRequest),
    live_subscription_active: bool,
) PolicyPlan(ReceiveRequest) {
    var plan: PolicyPlan(ReceiveRequest) = .{
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

pub fn buildOrchestration(
    comptime ReceiveRequest: type,
    policy_plan: PolicyPlan(ReceiveRequest),
) OrchestrationPlan(ReceiveRequest) {
    var plan: OrchestrationPlan(ReceiveRequest) = .{
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

pub fn buildCadence(
    comptime ReceiveRequest: type,
    orchestration_plan: OrchestrationPlan(ReceiveRequest),
    request: CadenceRequest,
) CadencePlan(ReceiveRequest) {
    var plan: CadencePlan(ReceiveRequest) = .{
        .relay_count = orchestration_plan.relay_count,
        .reconnect_count = orchestration_plan.reconnect_count,
        .authenticate_count = orchestration_plan.authenticate_count,
        .replay_resume_count = orchestration_plan.replay_resume_count,
        .subscribe_resume_count = orchestration_plan.subscribe_resume_count,
        .receive_count = orchestration_plan.receive_count,
        .replay_phase_complete = orchestration_plan.replay_phase_complete,
        .live_subscription_active = orchestration_plan.live_subscription_active,
        .needs_relay_configuration = orchestration_plan.needs_relay_configuration,
        .needs_connect_progress = orchestration_plan.needs_connect_progress,
        .needs_auth_progress = orchestration_plan.needs_auth_progress,
        .needs_replay_catchup = orchestration_plan.needs_replay_catchup,
        .needs_live_subscription = orchestration_plan.needs_live_subscription,
        .can_receive_live = orchestration_plan.can_receive_live,
    };

    const replay_refresh_due = blk: {
        const not_before = request.replay_refresh_not_before_unix_seconds orelse break :blk false;
        break :blk orchestration_plan.replay_phase_complete and
            !orchestration_plan.live_subscription_active and
            request.now_unix_seconds >= not_before;
    };
    plan.replay_refresh_due = replay_refresh_due;

    switch (orchestration_plan.nextStep()) {
        .configure_relays => {
            plan.next_step = .configure_relays;
            return plan;
        },
        .authenticate => |step| {
            plan.next_step = .{ .authenticate = step };
            return plan;
        },
        .replay_resume => |step| {
            plan.next_step = .{ .replay_resume = step };
            return plan;
        },
        .receive => |request_step| {
            plan.next_step = .{ .receive = request_step };
            return plan;
        },
        .reconnect => |step| {
            if (waitFor(
                request.now_unix_seconds,
                request.reconnect_not_before_unix_seconds,
                .reconnect_backoff,
            )) |wait| {
                plan.blocked_by_reconnect_backoff = true;
                plan.next_due_at_unix_seconds = wait.due_at_unix_seconds;
                plan.next_step = .{ .wait = wait };
                return plan;
            }
            plan.next_step = .{ .reconnect = step };
            return plan;
        },
        .subscribe_resume => |step| {
            if (replay_refresh_due) {
                plan.next_step = .reopen_replay_catchup;
                return plan;
            }
            if (waitFor(
                request.now_unix_seconds,
                request.subscribe_resume_not_before_unix_seconds,
                .subscribe_resume_backoff,
            )) |wait| {
                plan.blocked_by_subscribe_backoff = true;
                plan.next_due_at_unix_seconds = wait.due_at_unix_seconds;
                plan.next_step = .{ .wait = wait };
                return plan;
            }
            plan.next_step = .{ .subscribe_resume = step };
            return plan;
        },
        .idle => {
            if (request.replay_refresh_not_before_unix_seconds) |not_before| {
                if (request.now_unix_seconds < not_before) {
                    plan.waiting_for_replay_refresh = true;
                    plan.next_due_at_unix_seconds = not_before;
                    plan.next_step = .{ .wait = .{
                        .reason = .replay_refresh_not_due_yet,
                        .due_at_unix_seconds = not_before,
                    } };
                    return plan;
                }
                if (replay_refresh_due) {
                    plan.next_step = .reopen_replay_catchup;
                    return plan;
                }
            }
            plan.next_step = .idle;
            return plan;
        },
    }
}

fn waitFor(
    now_unix_seconds: u64,
    not_before_unix_seconds: ?u64,
    reason: CadenceWaitReason,
) ?CadenceWait {
    const due_at = not_before_unix_seconds orelse return null;
    if (now_unix_seconds >= due_at) return null;
    return .{
        .reason = reason,
        .due_at_unix_seconds = due_at,
    };
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

    const auth_first = buildPlan(
        ReceiveRequest,
        auth_plan,
        replay_plan,
        subscription_plan,
        false,
        true,
        .{ .token = 7 },
    );
    try std.testing.expect(auth_first.nextStep() == .authenticate);

    const receive_second = buildPlan(
        ReceiveRequest,
        .{},
        replay_plan,
        subscription_plan,
        false,
        true,
        .{ .token = 7 },
    );
    try std.testing.expect(receive_second.nextStep() == .receive);

    const replay_third = buildPlan(
        ReceiveRequest,
        .{},
        replay_plan,
        subscription_plan,
        false,
        false,
        .{ .token = 7 },
    );
    try std.testing.expect(replay_third.nextStep() == .replay);

    const subscribe_fourth = buildPlan(
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
    const runtime_plan = Plan(ReceiveRequest){
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

    const receive_first = classifyPolicy(
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
    const replay_runtime = Plan(ReceiveRequest){
        .replay_count = 1,
        .next_step = .{ .replay = .{ .entry = replay_entry } },
    };

    const reconnect_first = classifyPolicy(
        ReceiveRequest,
        1,
        relay_runtime,
        replay_runtime,
        false,
    );
    try std.testing.expect(reconnect_first.nextStep() == .reconnect);

    const no_reconnect_runtime = runtime.RelayPoolPlan{};
    const replay_first = classifyPolicy(
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
    const plan = buildOrchestration(ReceiveRequest, .{});

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
    const policy = classifyPolicy(
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
    const plan = buildOrchestration(ReceiveRequest, policy);

    try std.testing.expect(!plan.needs_relay_configuration);
    try std.testing.expect(plan.needs_connect_progress);
    try std.testing.expect(plan.needs_replay_catchup);
    try std.testing.expect(plan.needs_live_subscription);
    try std.testing.expect(plan.nextStep() == .reconnect);
}

test "shared dm runtime cadence helper defers reconnect until caller backoff elapses" {
    const ReceiveRequest = struct { token: u8 };
    const reconnect_entry = runtime.RelayPoolEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .action = .connect,
    };
    const orchestration = OrchestrationPlan(ReceiveRequest){
        .relay_count = 1,
        .reconnect_count = 1,
        .needs_connect_progress = true,
        .next_step = .{ .reconnect = .{ .entry = reconnect_entry } },
    };

    const waiting = buildCadence(ReceiveRequest, orchestration, .{
        .now_unix_seconds = 50,
        .reconnect_not_before_unix_seconds = 60,
    });
    try std.testing.expect(waiting.blocked_by_reconnect_backoff);
    try std.testing.expectEqual(@as(?u64, 60), waiting.next_due_at_unix_seconds);
    try std.testing.expect(waiting.nextStep() == .wait);
    try std.testing.expectEqual(
        CadenceWaitReason.reconnect_backoff,
        waiting.nextStep().wait.reason,
    );

    const due = buildCadence(ReceiveRequest, orchestration, .{
        .now_unix_seconds = 60,
        .reconnect_not_before_unix_seconds = 60,
    });
    try std.testing.expect(due.nextStep() == .reconnect);
}

test "shared dm runtime cadence helper reopens replay catchup before subscribe when refresh is due" {
    const ReceiveRequest = struct { token: u8 };
    const subscribe_entry = runtime.RelayPoolSubscriptionEntry{
        .descriptor = .{ .relay_index = 0, .relay_url = "wss://relay.one" },
        .subscription_id = "dm-live",
        .filters = &.{},
        .action = .subscribe,
    };
    const orchestration = OrchestrationPlan(ReceiveRequest){
        .relay_count = 1,
        .subscribe_resume_count = 1,
        .replay_phase_complete = true,
        .needs_live_subscription = true,
        .next_step = .{ .subscribe_resume = .{ .entry = subscribe_entry } },
    };

    const plan = buildCadence(ReceiveRequest, orchestration, .{
        .now_unix_seconds = 90,
        .replay_refresh_not_before_unix_seconds = 80,
    });
    try std.testing.expect(plan.replay_refresh_due);
    try std.testing.expect(plan.nextStep() == .reopen_replay_catchup);
}

test "shared dm runtime cadence helper waits for replay refresh while otherwise idle" {
    const ReceiveRequest = struct { token: u8 };
    const plan = buildCadence(ReceiveRequest, .{
        .relay_count = 1,
        .replay_phase_complete = true,
        .next_step = .idle,
    }, .{
        .now_unix_seconds = 70,
        .replay_refresh_not_before_unix_seconds = 100,
    });

    try std.testing.expect(plan.waiting_for_replay_refresh);
    try std.testing.expectEqual(@as(?u64, 100), plan.next_due_at_unix_seconds);
    try std.testing.expect(plan.nextStep() == .wait);
    try std.testing.expectEqual(
        CadenceWaitReason.replay_refresh_not_due_yet,
        plan.nextStep().wait.reason,
    );
}
