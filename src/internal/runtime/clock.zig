const std = @import("std");

pub const ClockError = error{
    InvalidClient,
    ClockUnavailable,
    SleepUnavailable,
};

pub const RetryBackoffPolicy = struct {
    base_ms: u32 = 250,
    factor: u8 = 2,
    max_ms: u32 = 30_000,
};

pub const Clock = struct {
    ctx: ?*anyopaque,
    unix_seconds_fn: *const fn (ctx: *anyopaque) ClockError!u64,
    monotonic_ns_fn: *const fn (ctx: *anyopaque) ClockError!u64,
    sleep_until_ns_fn: *const fn (ctx: *anyopaque, deadline_ns: u64) ClockError!void,

    pub fn unixSeconds(self: Clock) ClockError!u64 {
        if (self.ctx == null) return error.InvalidClient;
        return self.unix_seconds_fn(self.ctx.?);
    }

    pub fn monotonicNs(self: Clock) ClockError!u64 {
        if (self.ctx == null) return error.InvalidClient;
        return self.monotonic_ns_fn(self.ctx.?);
    }

    pub fn sleepUntilNs(self: Clock, deadline_ns: u64) ClockError!void {
        if (self.ctx == null) return error.InvalidClient;
        return self.sleep_until_ns_fn(self.ctx.?, deadline_ns);
    }
};

pub fn nextBackoffDelayMs(policy: RetryBackoffPolicy, attempt: u16) u32 {
    var delay: u64 = policy.base_ms;
    var remaining = attempt;
    while (remaining > 0 and delay < policy.max_ms) : (remaining -= 1) {
        delay *= @max(@as(u64, policy.factor), 1);
        if (delay >= policy.max_ms) return policy.max_ms;
    }
    return @intCast(@min(delay, policy.max_ms));
}

test "clock forwards time access and sleep while backoff saturates at max" {
    const FakeClock = struct {
        unix_seconds: u64 = 1_732_000_000,
        monotonic_ns: u64 = 5_000,
        last_deadline: u64 = 0,

        fn unixSeconds(ctx: *anyopaque) ClockError!u64 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.unix_seconds;
        }

        fn monotonicNs(ctx: *anyopaque) ClockError!u64 {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.monotonic_ns;
        }

        fn sleepUntilNs(ctx: *anyopaque, deadline_ns: u64) ClockError!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.last_deadline = deadline_ns;
        }
    };

    var fake = FakeClock{};
    const clock = Clock{
        .ctx = &fake,
        .unix_seconds_fn = FakeClock.unixSeconds,
        .monotonic_ns_fn = FakeClock.monotonicNs,
        .sleep_until_ns_fn = FakeClock.sleepUntilNs,
    };

    try std.testing.expectEqual(@as(u64, 1_732_000_000), try clock.unixSeconds());
    try std.testing.expectEqual(@as(u64, 5_000), try clock.monotonicNs());
    try clock.sleepUntilNs(99_000);
    try std.testing.expectEqual(@as(u64, 99_000), fake.last_deadline);

    const policy = RetryBackoffPolicy{ .base_ms = 100, .factor = 2, .max_ms = 700 };
    try std.testing.expectEqual(@as(u32, 100), nextBackoffDelayMs(policy, 0));
    try std.testing.expectEqual(@as(u32, 200), nextBackoffDelayMs(policy, 1));
    try std.testing.expectEqual(@as(u32, 400), nextBackoffDelayMs(policy, 2));
    try std.testing.expectEqual(@as(u32, 700), nextBackoffDelayMs(policy, 3));
    try std.testing.expectEqual(@as(u32, 700), nextBackoffDelayMs(policy, 7));
}

test "clock rejects invalid caller inputs with typed errors" {
    const FakeClock = struct {
        fn unixSeconds(_: *anyopaque) ClockError!u64 {
            return 0;
        }

        fn monotonicNs(_: *anyopaque) ClockError!u64 {
            return 0;
        }

        fn sleepUntilNs(_: *anyopaque, _: u64) ClockError!void {}
    };

    const clock = Clock{
        .ctx = null,
        .unix_seconds_fn = FakeClock.unixSeconds,
        .monotonic_ns_fn = FakeClock.monotonicNs,
        .sleep_until_ns_fn = FakeClock.sleepUntilNs,
    };

    try std.testing.expectError(error.InvalidClient, clock.unixSeconds());
    try std.testing.expectError(error.InvalidClient, clock.monotonicNs());
    try std.testing.expectError(error.InvalidClient, clock.sleepUntilNs(123));
}
