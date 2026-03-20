const std = @import("std");
const noztr = @import("noztr");
const noztr_sdk = @import("noztr_sdk");
const http_fake = @import("http_fake.zig");

// Prepare one command-ready NIP-39 profile-verify job over caller-owned buffers, then run it over
// the explicit public HTTP seam with caller-owned cache and remembered-profile store seams.
test "recipe: nip39 verify client prepares and runs one remembered profile verify job" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "alice",
        .proof = "gist-id",
    };
    const signer_secret = [_]u8{0x7a} ** 32;
    const pubkey = try noztr.nostr_keys.nostr_derive_public_key(&signer_secret);

    var expected_text_buffer: [256]u8 = undefined;
    const expected_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        expected_text_buffer[0..],
        &claim,
        &pubkey,
    );
    var body_storage: [384]u8 = undefined;
    const body = try std.fmt.bufPrint(body_storage[0..], "<pre>{s}</pre>", .{expected_text});
    var fake_http = http_fake.ExampleHttp.init(
        "https://gist.github.com/alice/gist-id",
        body,
    );

    var built_tag: noztr.nip39_external_identities.BuiltTag = undefined;
    const tag = try noztr.nip39_external_identities.identity_claim_build_tag(&built_tag, &claim);
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip39_external_identities.identity_kind,
        .created_at = 1,
        .content = "",
        .tags = (&[_]noztr.nip01_event.EventTag{tag})[0..],
    };
    try noztr.nostr_keys.nostr_sign_event(&signer_secret, &event);

    var claims: [1]noztr.nip39_external_identities.IdentityClaim = undefined;
    var url_buffers: [1][256]u8 = undefined;
    var expected_buffers: [1][256]u8 = undefined;
    var body_buffers: [1][512]u8 = undefined;
    var verification: [1]noztr_sdk.workflows.IdentityVerificationStorage = undefined;
    verification[0] = noztr_sdk.workflows.IdentityVerificationStorage.init(
        url_buffers[0][0..],
        expected_buffers[0][0..],
        body_buffers[0][0..],
    );
    var results: [1]noztr_sdk.workflows.IdentityClaimVerification = undefined;
    var cache_records: [1]noztr_sdk.workflows.IdentityVerificationCacheRecord = undefined;
    var cache = noztr_sdk.workflows.MemoryIdentityVerificationCache.init(cache_records[0..]);
    var profile_records: [1]noztr_sdk.workflows.IdentityProfileRecord = undefined;
    var profile_store = noztr_sdk.workflows.MemoryIdentityProfileStore.init(profile_records[0..]);

    const client = noztr_sdk.client.Nip39VerifyClient.init(.{});
    var storage = noztr_sdk.client.Nip39VerifyClientStorage.init(
        claims[0..],
        verification[0..],
        results[0..],
    );
    const job = client.prepareVerifyJob(&storage, &event, &pubkey);
    const result = try client.verifyProfileCachedAndRemember(
        fake_http.client(),
        cache.asCache(),
        profile_store.asStore(),
        job,
    );

    try std.testing.expectEqual(@as(usize, 1), result.summary.verified_count);
    try std.testing.expectEqual(@as(usize, 1), result.summary.network_fetch_count);
    try std.testing.expectEqual(
        noztr_sdk.workflows.IdentityProfileStorePutOutcome.stored,
        result.store_outcome,
    );
}
