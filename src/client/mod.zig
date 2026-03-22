const cli_archive_client = @import("cli_archive_client.zig");
const auth_count_turn_client = @import("auth_count_turn_client.zig");
const auth_publish_turn_client = @import("auth_publish_turn_client.zig");
const auth_replay_turn_client = @import("auth_replay_turn_client.zig");
const auth_subscription_turn_client = @import("auth_subscription_turn_client.zig");
const count_job_client = @import("count_job_client.zig");
const count_turn_client = @import("count_turn_client.zig");
const local_entity_job_client = @import("local_entity_job_client.zig");
const legacy_dm_publish_job_client = @import("legacy_dm_publish_job_client.zig");
const legacy_dm_replay_job_client = @import("legacy_dm_replay_job_client.zig");
const legacy_dm_replay_turn_client = @import("legacy_dm_replay_turn_client.zig");
const legacy_dm_subscription_job_client = @import("legacy_dm_subscription_job_client.zig");
const legacy_dm_subscription_turn_client = @import("legacy_dm_subscription_turn_client.zig");
const legacy_dm_sync_runtime_client = @import("legacy_dm_sync_runtime_client.zig");
const group_fleet_client = @import("group_fleet_client.zig");
const local_event_job_client = @import("local_event_job_client.zig");
const local_key_job_client = @import("local_key_job_client.zig");
const mailbox_job_client = @import("mailbox_job_client.zig");
const mailbox_sync_runtime_client = @import("mailbox_sync_runtime_client.zig");
const mailbox_subscription_job_client = @import("mailbox_subscription_job_client.zig");
const mailbox_subscription_turn_client = @import("mailbox_subscription_turn_client.zig");
const mailbox_replay_job_client = @import("mailbox_replay_job_client.zig");
const mailbox_replay_turn_client = @import("mailbox_replay_turn_client.zig");
const local_nip44_job_client = @import("local_nip44_job_client.zig");
const local_operator_client = @import("local_operator_client.zig");
const local_state_client = @import("local_state_client.zig");
const nip03_verify_client = @import("nip03_verify_client.zig");
const nip05_verify_client = @import("nip05_verify_client.zig");
const nip39_verify_client = @import("nip39_verify_client.zig");
const publish_job_client = @import("publish_job_client.zig");
const publish_client = @import("publish_client.zig");
const publish_turn_client = @import("publish_turn_client.zig");
const relay_auth_client = @import("relay_auth_client.zig");
const relay_directory_job_client = @import("relay_directory_job_client.zig");
const relay_exchange_client = @import("relay_exchange_client.zig");
const relay_query_client = @import("relay_query_client.zig");
const relay_session_client = @import("relay_session_client.zig");
const relay_workspace_client = @import("relay_workspace_client.zig");
const replay_job_client = @import("replay_job_client.zig");
const relay_replay_client = @import("relay_replay_client.zig");
const replay_checkpoint_advance_client = @import("replay_checkpoint_advance_client.zig");
const relay_replay_exchange_client = @import("relay_replay_exchange_client.zig");
const relay_replay_turn_client = @import("relay_replay_turn_client.zig");
const relay_response_client = @import("relay_response_client.zig");
const signer_connect_job_client = @import("signer_connect_job_client.zig");
const signer_capability = @import("signer_capability.zig");
const signer_client = @import("signer_client.zig");
const signer_nip44_encrypt_job_client = @import("signer_nip44_encrypt_job_client.zig");
const signer_pubkey_job_client = @import("signer_pubkey_job_client.zig");
const subscription_job_client = @import("subscription_job_client.zig");
const subscription_turn_client = @import("subscription_turn_client.zig");

pub const local = struct {
    pub const archive = cli_archive_client;
    pub const state = local_state_client;
    pub const operator = local_operator_client;
    pub const keys = local_key_job_client;
    pub const entities = local_entity_job_client;
    pub const events = local_event_job_client;
    pub const nip44 = local_nip44_job_client;
};

pub const relay = struct {
    pub const auth = relay_auth_client;
    pub const auth_count_turn = auth_count_turn_client;
    pub const auth_publish_turn = auth_publish_turn_client;
    pub const auth_replay_turn = auth_replay_turn_client;
    pub const auth_subscription_turn = auth_subscription_turn_client;
    pub const count_job = count_job_client;
    pub const count_turn = count_turn_client;
    pub const directory = relay_directory_job_client;
    pub const exchange = relay_exchange_client;
    pub const publish = publish_client;
    pub const publish_job = publish_job_client;
    pub const publish_turn = publish_turn_client;
    pub const query = relay_query_client;
    pub const replay = relay_replay_client;
    pub const replay_checkpoint_advance = replay_checkpoint_advance_client;
    pub const replay_exchange = relay_replay_exchange_client;
    pub const replay_job = replay_job_client;
    pub const replay_turn = relay_replay_turn_client;
    pub const response = relay_response_client;
    pub const session = relay_session_client;
    pub const subscription_job = subscription_job_client;
    pub const subscription_turn = subscription_turn_client;
    pub const workspace = relay_workspace_client;
};

pub const signer = struct {
    pub const capability = signer_capability;
    pub const session = signer_client;
    pub const connect_job = signer_connect_job_client;
    pub const pubkey_job = signer_pubkey_job_client;
    pub const nip44_encrypt_job = signer_nip44_encrypt_job_client;
};

pub const dm = struct {
    pub const legacy = struct {
        pub const publish_job = legacy_dm_publish_job_client;
        pub const replay_turn = legacy_dm_replay_turn_client;
        pub const replay_job = legacy_dm_replay_job_client;
        pub const subscription_turn = legacy_dm_subscription_turn_client;
        pub const subscription_job = legacy_dm_subscription_job_client;
        pub const sync_runtime = legacy_dm_sync_runtime_client;
    };

    pub const mailbox = struct {
        pub const job = mailbox_job_client;
        pub const subscription_turn = mailbox_subscription_turn_client;
        pub const subscription_job = mailbox_subscription_job_client;
        pub const replay_turn = mailbox_replay_turn_client;
        pub const replay_job = mailbox_replay_job_client;
        pub const sync_runtime = mailbox_sync_runtime_client;
    };
};

pub const identity = struct {
    pub const nip05 = nip05_verify_client;
    pub const nip39 = nip39_verify_client;
};

pub const proof = struct {
    pub const nip03 = nip03_verify_client;
};

pub const groups = struct {
    pub const fleet = group_fleet_client;
};
