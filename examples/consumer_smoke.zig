const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Minimal import smoke for the stable public namespace shape.
test "consumer smoke: import the sdk workflow namespace" {
    try std.testing.expect(@TypeOf(noztr_sdk.workflows) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.signer.remote.RemoteSignerSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.dm.mailbox.MailboxSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.groups.session.GroupSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.signer.remote.RemoteSignerSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.dm.mailbox.MailboxSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.groups.session.GroupSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.relay.session.RelaySessionClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.identity.nip39.Nip39VerifyClient) == type);
}
