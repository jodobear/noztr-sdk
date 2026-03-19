# noztr-sdk Examples

Structured workflow recipes for `noztr-sdk`.

These examples sit above the kernel recipe set in `/workspace/projects/noztr/examples`. They are
technical and direct, and they intentionally teach the public workflow layer rather than app UI,
network daemons, or hidden runtime loops.

## Teaching Posture

- public SDK imports come from `@import("noztr_sdk").workflows`
- HTTP-backed workflow recipes also use `@import("noztr_sdk").transport`
- protocol fixture construction stays on `noztr` kernel helpers
- examples are compile-verified recipes, not hidden runtimes or framework demos
- deferred seams are named explicitly instead of being smuggled into example code

## Start Here

- `consumer_smoke.zig`
  - goal: minimal package/import check
  - public SDK surface: `noztr_sdk.workflows`
  - control point: verify the workflow namespace is the stable top-level entry
- `remote_signer_recipe.zig`
  - goal: explicit `NIP-46` connect plus `get_public_key` and one `nip44_encrypt` request
  - public SDK surface: `RemoteSignerSession`
  - kernel fixture help: `noztr.nip46_remote_signing`
  - control points: caller starts connect, caller starts later signer requests, caller feeds
    responses back in explicitly, caller reuses one request context shape instead of repeating
    `buffer + id + scratch`, and the recipe keeps repetitive response JSON wiring in one small
    helper so the public session flow stays primary
- `mailbox_recipe.zig`
  - goal: build one outbound direct message once, inspect mailbox runtime actions over hydrated
    recipient relays, select one next delivery relay plus one next runtime relay/action
    explicitly, unwrap it through a recipient mailbox session, then build one outbound file
    message once, plan its delivery, and unwrap it through the same mailbox surface
  - public SDK surface: `MailboxSession`, `MailboxDeliveryStorage`, `MailboxDeliveryRole`,
    `MailboxDeliveryPlan`, `MailboxRuntimeAction`, `MailboxRuntimeStorage`,
    `MailboxRuntimePlan`, `MailboxFileDimensions`, `MailboxFileMessageRequest`,
    `MailboxEnvelopeOutcome`, `MailboxFileMessageOutcome`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip44`, `noztr.nostr_keys`
  - control points: caller verifies the recipient relay list, optionally verifies sender-copy
    relays, builds one outbound wrap explicitly, receives the deduplicated publish-relay plan with
    relay-role annotations, can ask the delivery plan for the next recommended relay without
    hand-scanning role flags, inspects hydrated mailbox relays as explicit `connect`,
    `authenticate`, or `receive` actions, can ask the runtime plan for the next recommended relay
    step explicitly, selects one relay explicitly, feeds wrapped event JSON back into a recipient
    mailbox session, can build and plan one explicit outbound file-message wrap on the same
    surface, can classify direct-message vs file-message rumors explicitly, and still owns
    publication and polling policy
- `nip03_verification_recipe.zig`
  - goal: fetch one detached OpenTimestamps proof document, store it explicitly, remember the
    verified result, classify remembered verification entries for freshness, inspect the remembered
    runtime action plus selected next entry explicitly, plan refresh for stale remembered
    verifications, and recover the latest remembered verification for the same target event
  - public SDK surface: `OpenTimestampsVerifier`, `OpenTimestampsRemoteProofRequest`,
    `OpenTimestampsProofStore`, `MemoryOpenTimestampsProofStore`,
    `OpenTimestampsVerificationStore`, `MemoryOpenTimestampsVerificationStore`,
    `OpenTimestampsStoredVerificationDiscoveryFreshnessStorage`,
    `OpenTimestampsStoredVerificationRuntimeStorage`,
    `OpenTimestampsStoredVerificationRuntimeAction`,
    `OpenTimestampsStoredVerificationRefreshStorage`, `transport.HttpClient`
  - kernel fixture help: `noztr.nostr_keys`
  - control points: caller supplies the target event, attestation event, detached proof URL,
    caller-owned proof buffer, caller-owned proof-store records, and caller-owned remembered-
    verification store records over the explicit HTTP seam, then performs one explicit
    freshness-classified remembered discovery lookup plus one explicit remembered runtime
    inspection step plus one explicit next-entry selector step plus one explicit stale-proof
    refresh plan without hidden Bitcoin refresh policy
- `nip39_verification_recipe.zig`
  - goal: verify one full kind-10011 identity event over the public HTTP seam, reuse one explicit
    cache, remember the verified profile, hydrate one stored discovery result directly, classify
    both discovered stored entries and the latest remembered profile for freshness, select one
    preferred remembered profile explicitly, inspect the remembered runtime action plus selected
    next entry explicitly, plan refresh for stale remembered profiles explicitly, and replay the
    same identity from remembered state
  - public SDK surface: `IdentityVerifier`, `IdentityProfileVerificationStorage`,
    `IdentityProviderDetails`, `MemoryIdentityVerificationCache`, `MemoryIdentityProfileStore`,
    `IdentityStoredProfileDiscoveryStorage`, `IdentityStoredProfileDiscoveryFreshnessStorage`,
    `IdentityLatestStoredProfileFreshnessRequest`, `IdentityPreferredStoredProfileRequest`,
    `IdentityStoredProfileFallbackPolicy`, `IdentityStoredProfileRuntimeStorage`,
    `IdentityStoredProfileRuntimeAction`, `IdentityStoredProfileRefreshStorage`,
    `transport.HttpClient`
  - kernel fixture help: `noztr.nip39_external_identities`
  - control points: caller provides the HTTP client, the signed identity event, the target pubkey,
    caller-owned per-claim verification storage, caller-owned cache records, caller-owned profile
    store records, inspects provider-shaped details from the verified claims, then performs one
    explicit remembered discovery lookup, one explicit freshness-classified remembered discovery
    lookup, one newest-match remembered lookup, one explicit preferred-profile selection step, one
    explicit remembered runtime inspection step plus one explicit next-entry selector step, one
    explicit stale-profile refresh plan, and one explicit freshness check without hidden
    background policy
- `nip05_resolution_recipe.zig`
  - goal: resolve and verify one `NIP-05` address over the public HTTP seam
  - public SDK surface: `Nip05Resolver`, `transport.HttpClient`
  - kernel fixture help: none beyond the SDK result surface
  - control points: caller provides the HTTP client, one caller-owned lookup storage wrapper, and
    the scratch allocator
- `group_session_recipe.zig`
  - goal: author a canonical `NIP-29` snapshot, export one checkpoint, restore it into a receiver
    client, select valid `previous` refs, build one outbound moderation event, then replay it
  - public SDK surface: `GroupClient`, `GroupClientStorage`, `GroupCheckpointBuffers`,
    `GroupCheckpointContext`, `GroupPublishContext`, `GroupMetadataDraft`, `GroupRolesDraft`,
    `GroupMembersDraft`
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller provides named caller-owned session plus previous-ref storage, marks
    relay readiness, authors the snapshot state explicitly, exports and restores one checkpoint,
    then builds and replays one explicit outbound moderation event using refs selected from client
    history
- `group_fleet_recipe.zig`
  - goal: persist relay-local `NIP-29` checkpoints from one explicit multi-relay fleet into a
    caller-owned store, restore a fresh fleet from that stored state, inspect runtime actions over
    the restored relays, merge divergent relay-local components by explicit relay selection, run
    one explicit targeted baseline-to-target reconcile step, then plan one moderation publish
    across all reconciled relays
  - public SDK surface: `GroupFleet`, `GroupClient`, `GroupClientStorage`,
    `GroupRelayState`, `GroupFleetRuntimeAction`, `GroupFleetRuntimeStorage`,
    `GroupFleetRuntimePlan`,
    `GroupFleetCheckpointStorage`, `GroupFleetCheckpointContext`,
    `GroupFleetMergeStorage`, `GroupFleetMergeContext`, `GroupFleetMergeSelection`,
    `GroupFleetMergedCheckpoint`, `GroupFleetTargetReconcileOutcome`,
    `GroupFleetCheckpointRecord`, `MemoryGroupFleetCheckpointStore`,
    `GroupFleetStorePersistOutcome`, `GroupFleetStoreRestoreOutcome`,
    `GroupFleetPublishStorage`, `GroupFleetPublishContext`
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller still owns the relay-local clients, chooses relay URLs explicitly,
    persists relay-local checkpoints into a bounded store through the fleet, restores only the
    matching relay-local checkpoints into a fresh fleet, inspects each relay as explicit
    `connect`, `authenticate`, `reconcile`, or `ready` against a chosen baseline, chooses which
    relay contributes each merged checkpoint component explicitly, applies that merged checkpoint
    across the fleet, can then reconcile one chosen target relay explicitly from the chosen
    baseline without updating the whole fleet, and finally plans one explicit per-relay moderation
    publish through caller-owned buffers without hidden merge or runtime policy

## Adversarial Examples

- `group_session_adversarial_example.zig`
  - goal: prove wrong-group `NIP-29` replay is rejected before state mutation
  - public SDK surface: `GroupSession`
  - failure control point: `error.EventGroupMismatch`

## Deferred After The HTTP-Seam Refinement

Still intentionally deferred:
- live HTTP adapters or runtime clients
- redirect-aware `NIP-05` teaching beyond the current explicit seam limit
- richer provider-specific `NIP-39` verification semantics and broader trust/discovery layers
- longer-lived autonomous identity discovery or hidden runtime policy

Reason:
- the public seam is now explicit and teachable
- richer HTTP policy and broader identity workflow breadth are still later slices

## Verification

These files are exercised by `zig build test --summary all` through `examples/examples.zig`.
