const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Minimal import smoke for the stable public namespace shape.
test "consumer smoke: import the sdk workflow namespace" {
    try std.testing.expect(@TypeOf(noztr_sdk.workflows) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.signer.remote.RemoteSignerSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.dm.mailbox.MailboxSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.workflows.groups.session.GroupSession) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.dm.capability.DmCapabilityClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.dm.mixed.MixedDmClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.dm.mixed.OutboundStorage) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.dm.mixed.PreparedOutbound) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.signer.capability.SignerCapabilityProfile) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.signer.browser.Nip07BrowserProvider) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.relay.session.RelaySessionClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.identity.nip39.Nip39VerifyClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.social.graph_wot.SocialGraphWotClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.social.profile_content.SocialProfileContentClient) == type);
    try std.testing.expect(@TypeOf(noztr_sdk.client.social.reaction_list.SocialReactionListClient) == type);
}
