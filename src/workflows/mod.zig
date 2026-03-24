const group_client = @import("group_client.zig");
const group_fleet = @import("group_fleet.zig");
const group_session = @import("group_session.zig");
const identity_verifier = @import("identity_verifier.zig");
const legacy_dm = @import("legacy_dm.zig");
const mailbox_workflow = @import("mailbox.zig");
const nip05_resolver = @import("nip05_resolver.zig");
const opentimestamps_verifier = @import("opentimestamps_verifier.zig");
const remote_signer = @import("remote_signer.zig");
const zap_flow = @import("zap_flow.zig");

pub const groups = struct {
    pub const local = group_client;
    pub const session = group_session;
    pub const fleet = group_fleet;
};

pub const identity = struct {
    pub const verify = identity_verifier;
    pub const nip05 = nip05_resolver;
};

pub const dm = struct {
    pub const legacy = legacy_dm;
    pub const mailbox = mailbox_workflow;
};

pub const proof = struct {
    pub const nip03 = opentimestamps_verifier;
};

pub const signer = struct {
    pub const remote = remote_signer;
};

pub const zaps = zap_flow;
