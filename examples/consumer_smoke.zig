const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Minimal import smoke for the stable workflow namespace.
test "consumer smoke: import the sdk workflow namespace" {
    try std.testing.expect(@TypeOf(noztr_sdk.workflows) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.RemoteSignerSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.MailboxSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.OpenTimestampsVerifier) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.GroupSession) == type);
}
