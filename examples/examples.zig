comptime {
    _ = @import("consumer_smoke.zig");
    _ = @import("common.zig");
    _ = @import("remote_signer_recipe.zig");
    _ = @import("store_query_recipe.zig");
    _ = @import("store_archive_recipe.zig");
    _ = @import("relay_checkpoint_recipe.zig");
    _ = @import("mailbox_recipe.zig");
    _ = @import("nip39_verification_recipe.zig");
    _ = @import("nip03_verification_recipe.zig");
    _ = @import("nip05_resolution_recipe.zig");
    _ = @import("group_session_recipe.zig");
    _ = @import("group_fleet_recipe.zig");
    _ = @import("group_session_adversarial_example.zig");
}
