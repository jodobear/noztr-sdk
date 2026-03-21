const std = @import("std");
const noztr_sdk = @import("noztr_sdk");

// Remember one explicit relay set in bounded local storage, then list it back in stable order
// without introducing file-system or daemon ownership.
test "recipe: relay registry archive composes remembered relay state over the relay-info store seam" {
    var memory_store = noztr_sdk.store.MemoryRelayInfoStore{};
    const archive = noztr_sdk.store.RelayRegistryArchive.init(memory_store.asRelayInfoStore());

    _ = try archive.rememberRelay("wss://relay.one");
    _ = try archive.rememberRelay("wss://relay.two");

    var page_storage: [2]noztr_sdk.store.RelayInfoRecord = undefined;
    var page = noztr_sdk.store.RelayInfoResultPage.init(page_storage[0..]);
    try archive.listRelayInfo(&page);

    try std.testing.expectEqual(@as(usize, 2), page.count);
    try std.testing.expectEqualStrings("wss://relay.one", page.slice()[0].relayUrl());
    try std.testing.expectEqualStrings("wss://relay.two", page.slice()[1].relayUrl());
}
