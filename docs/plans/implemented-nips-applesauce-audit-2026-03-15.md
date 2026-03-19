---
title: Noztr SDK Implemented-NIPs Applesauce-Lens Audit
doc_type: audit
status: active
owner: noztr-sdk
posture: applesauce
read_when:
  - evaluating_product_surface_readiness
  - planning_refinement_work
---

# Noztr SDK Implemented-NIPs Applesauce-Lens Audit

Audit date: 2026-03-15

Scope:
- `src/workflows/remote_signer.zig`
- `src/workflows/mailbox.zig`
- `src/workflows/identity_verifier.zig`
- `src/workflows/opentimestamps_verifier.zig`
- `src/workflows/nip05_resolver.zig`
- `src/workflows/group_session.zig`
- `src/workflows/mod.zig`
- `src/root.zig`
- `src/transport/interfaces.zig`
- `examples/README.md`
- workflow plan packets for `NIP-46`, `NIP-17`, `NIP-39`, `NIP-03`, `NIP-05`, and `NIP-29`

Lens:
- `noztr-sdk` is intended to become the Zig analogue to applesauce in broad functionality,
  opinionated real-world usability, structured examples, and ecosystem compatibility
- `noztr-sdk` must still preserve the `noztr` protocol-kernel boundary

## Overall Assessment

The implemented slices are materially better than raw kernel wrappers. They are bounded, explicit,
compile-verified, and generally disciplined about leaving deterministic protocol logic in `noztr`.

They are not yet applesauce-equivalent in product readiness.

The strongest current slice is `NIP-29`, followed by `NIP-46`.

## Open Findings Index

- `A-NIP17-001`: mailbox workflow now covers sender-copy-aware delivery planning plus file-message
  send and intake, but still not a fuller app workflow
- `A-NIP03-001`: OpenTimestamps workflow now has detached proof retrieval plus freshness-
  classified remembered verification discovery plus explicit remembered runtime and refresh
  planning, but is still not a fuller proof workflow
- `A-NIP29-001`: `NIP-29` now has explicit multi-relay routing, caller-owned fleet checkpoint
  persistence, durable store seams, source-led plus targeted fleet reconciliation, and explicit
  fleet runtime inspection over relay-local group clients, but still not a fuller groups client
- `A-NIP39-001`: `NIP-39` now verifies full identity events, reuses explicit cached verification
  outcomes, remembers verified profiles, and supports hydrated stored discovery plus freshness
  classification plus explicit remembered runtime and refresh planning, but it is still not a
  complete identity workflow

## Findings

### `A-HTTP-001` Resolved: `NIP-39` and `NIP-05` now have an explicit public HTTP seam

- status: resolved
- applies_to: `NIP-39`, `NIP-05`

Resolution note:
- `src/root.zig` now exports `noztr_sdk.transport` intentionally
- `examples/nip39_verification_recipe.zig` and `examples/nip05_resolution_recipe.zig` now teach the
  HTTP-backed workflows through that public seam
- the remaining `NIP-39` and `NIP-05` gaps are about workflow breadth and transport-policy limits,
  not hidden/public seam mismatch anymore

### `A-NIP46-001` Resolved: `NIP-46` now covers the current kernel-supported remote-signer method family

- status: resolved
- applies_to: `NIP-46`

Resolution note:
- `RemoteSignerSession` now exposes `nip04_encrypt`, `nip04_decrypt`, `nip44_encrypt`, and
  `nip44_decrypt` alongside the earlier `connect`, `get_public_key`, `sign_event`,
  `switch_relays`, and `ping` methods in
  [src/workflows/remote_signer.zig](/workspace/projects/nzdk/src/workflows/remote_signer.zig)
- the public workflow surface now exports `RemoteSignerPubkeyTextRequest` and
  `RemoteSignerTextResponse` in
  [src/workflows/mod.zig](/workspace/projects/nzdk/src/workflows/mod.zig)
- the recipe in
  [examples/remote_signer_recipe.zig](/workspace/projects/nzdk/examples/remote_signer_recipe.zig)
  now teaches one end-to-end pubkey-plus-text method as part of the public remote-signer flow

### `A-NIP17-001` Medium: `NIP-17` now covers sender-copy-aware delivery planning, file-message send and intake, plus explicit mailbox runtime inspection, but it is still not a complete mailbox workflow for real apps

- status: open
- applies_to: `NIP-17`

Observed friction:
- the public `MailboxSession` surface now covers relay-list hydration, relay state stepping,
  outbound direct-message build, outbound file-message build, recipient relay-fanout planning,
  sender-copy-aware delivery planning, and wrapped message intake in
  [src/workflows/mailbox.zig](/workspace/projects/nzdk/src/workflows/mailbox.zig)
- the sender can now build one wrap once and receive a deduplicated recipient publish-relay plan
  from a verified kind-10050 relay-list event
- the sender can now also union verified sender-copy relays into that delivery plan without
  rebuilding the wrap or duplicating equivalent relay URLs
- `MailboxDeliveryPlan` now also exposes `nextRelayIndex()` and `nextStep()` so callers can step
  one next publish relay without hand-scanning the deduplicated relay-role delivery plan or
  re-stitching wrap payload context above the workflow
- `MailboxDeliveryPlan` now also exposes explicit recipient-only and sender-copy-only next-step
  selectors so callers can follow those two delivery policies separately without rebuilding relay
  filtering above the workflow
- the sender can now also author one explicit outbound `NIP-17` file-message wrap and plan relay
  delivery for that same wrap without hand-building the rumor above the SDK
- the recipient path can now also unwrap and parse `NIP-17` file messages through explicit mailbox
  helpers instead of stopping at direct-message rumors only
- callers can now also inspect all hydrated mailbox relays as explicit `connect`,
  `authenticate`, or `receive` actions, select one relay directly on the mailbox workflow surface,
  and ask the runtime plan for one typed next recommended relay/action step instead of
  hand-scanning relay pool state above the SDK
- but transport-level polling/subscription orchestration and broader durable mailbox runtime
  ownership remain deferred

Why this matters through the applesauce lens:
- real-world private-message clients usually need more than explicit send, receive, and relay-state
  inspection: they also need some mailbox sync/fanout posture
- the current slice is now materially closer to a reusable mailbox workflow than a one-relay send
  helper because file-message send and receive no longer need to be rebuilt above the SDK
- it is still not the fuller mailbox workflow most downstream apps will eventually want because
  subscription/polling orchestration and longer-lived mailbox runtime policy still sit above the
  current slice

### `A-NIP03-001` Medium: `NIP-03` now has detached proof retrieval, stored-proof reuse, and freshness-classified remembered verification discovery, but is still not the broader proof workflow real apps need

- status: open
- applies_to: `NIP-03`

Observed friction:
- the public surface now covers:
  - one local verifier entrypoint
  - one detached proof fetch-and-verify entrypoint over the explicit HTTP seam
- one explicit caller-owned proof-store seam plus cached detached-proof replay
- one explicit caller-owned remembered-verification store seam plus newest-match lookup by target
  event id
- one explicit newest-match freshness helper over that remembered verification store seam
- one explicit preferred remembered-verification selection helper with caller-chosen stale fallback
  and caller-owned freshness storage
- one explicit freshness-classified remembered-discovery helper over all stored verifications for a
  target event
- one explicit remembered runtime-policy helper that classifies one target event as `verify_now`,
  `refresh_existing`, `use_preferred`, or `use_stale_and_refresh`
- `OpenTimestampsStoredVerificationRuntimePlan` now also exposes `nextEntry()` so callers can step
  the selected remembered verification directly instead of re-matching the runtime-selected entry
  above the workflow
- `OpenTimestampsStoredVerificationRuntimePlan` now also exposes `nextStep()` so callers can
  consume the remembered runtime action plus its selected verification as one explicit SDK step
  instead of stitching that view together above the workflow
- remembered-profile and remembered-verification discovery helpers now classify inconsistent custom
  store hydration as typed `error.InconsistentStoreData` instead of relying on invariant-only crash
  paths
- one explicit stale-verification refresh-plan helper over remembered verification freshness, with
  `nextEntry()` and `nextStep()` above that plan
- the detached proof path is still caller-directed and local-floor only in
  [src/workflows/opentimestamps_verifier.zig](/workspace/projects/nzdk/src/workflows/opentimestamps_verifier.zig#L50)
- broader proof workflow steps are still deferred in
  [docs/plans/nip03-opentimestamps-verifier-plan.md](/workspace/projects/nzdk/docs/plans/nip03-opentimestamps-verifier-plan.md#L47)
  and [docs/plans/nip03-remote-proof-plan.md](/workspace/projects/nzdk/docs/plans/nip03-remote-proof-plan.md)
  plus [docs/plans/nip03-proof-store-plan.md](/workspace/projects/nzdk/docs/plans/nip03-proof-store-plan.md)
  and [docs/plans/nip03-remembered-verification-plan.md](/workspace/projects/nzdk/docs/plans/nip03-remembered-verification-plan.md)

Why this matters through the applesauce lens:
- the current surface is now useful as a bounded verifier plus one caller-directed retrieval step
  plus explicit stored-proof reuse and remembered-verification seams with freshness-classified
  discovery and explicit remembered runtime policy
- it is not yet the opinionated real-world proof workflow that apps will usually need when they do
  anything beyond local validation of already-fetched attestations because broader Bitcoin
  verification, freshness policy, and longer-lived proof strategy still sit above the current slice

### `A-NIP29-001` Medium: `NIP-29` now has explicit multi-relay routing, component-level merge selection, fleet-wide moderation fanout, caller-owned fleet checkpoint persistence, durable store seams, source-led plus targeted fleet reconciliation, and explicit fleet runtime inspection over relay-local group clients, but it is still not a fuller groups client

- status: open
- applies_to: `NIP-29`

Observed friction:
- the public `NIP-29` surface now splits into:
  - `GroupSession` as the bounded replay/publish core
  - `GroupClient` as the higher-level mixed-intake client over owned previous-ref scratch
  - `GroupFleet` as the explicit multi-relay router over caller-owned `GroupClient`s
- the current slice now also authors metadata, admins, members, and roles snapshot state through
  the same explicit relay-local publish path
- it now also exports one explicit single-relay checkpoint and can restore it locally into a fresh
  client without requiring live relay readiness
- the newer fleet slice now routes authored snapshot intake and checkpoint export/restore by relay
  URL without introducing hidden merge or background runtime policy
- it now also exports one fleet-wide checkpoint set and can restore it into a fresh fleet without
  inventing reconciliation policy
- it now also inspects relay-local divergence against a chosen baseline and can reconcile the full
  fleet from one explicit source relay without inventing hidden merge rules
- it now also persists relay-local checkpoints into an explicit caller-owned store seam and can
  restore a fresh fleet from that stored state without inventing hidden durable-sync policy
- it now also builds one merged fleet checkpoint from explicit per-component relay choices and can
  apply that merged checkpoint across the fleet without inventing hidden authority or automatic
  conflict resolution
- it now also plans `put-user` and `remove-user` moderation publishes across all relays in the
  fleet through explicit caller-owned buffers and relay-local previous-ref selection
- `GroupFleet.nextPublishEvent(...)` and `nextPublishStep(...)` now also select one next per-
  relay moderation publish step without hand-scanning the fleet fanout slice or re-stitching the
  selected event context above the workflow
- it now also exposes one explicit fleet runtime plan that classifies each relay as `connect`,
  `authenticate`, `reconcile`, or `ready` against a chosen baseline instead of forcing callers to
  hand-compose relay readiness plus divergence checks above the fleet
- `GroupFleetRuntimePlan` now also exposes `nextEntry()` and `nextStep()` so callers can step one
  next runtime relay/action without hand-scanning the bounded fleet runtime plan or re-stitching
  baseline context above the workflow
- `GroupFleetConsistencyReport` now also exposes `nextEntry()` so callers can step one next
  divergent relay without hand-scanning the consistency report above the fleet
- `GroupFleetConsistencyReport` now also exposes `nextStep()` so callers can package that next
  divergent relay together with the chosen baseline into one typed fleet consistency step
- it now also exposes one explicit targeted baseline-to-target reconcile helper, so callers no
  longer have to choose between hand-rolled checkpoint copy code and all-relays reconciliation
  when one runtime step only needs to converge one divergent relay
- that is materially broader and more app-facing than the earlier session-only shape
- but the broader client story still stops at explicit relay-local authoring plus caller-owned
  runtime stepping
- the accepted slices still defer automatic merge heuristics, canonical ordering policy, and
  background subscription/runtime loops in
  [docs/plans/nip29-sync-store-plan.md](/workspace/projects/nzdk/docs/plans/nip29-sync-store-plan.md)
  and [docs/plans/nip29-client-surface-plan.md](/workspace/projects/nzdk/docs/plans/nip29-client-surface-plan.md)
  plus [docs/plans/nip29-runtime-client-plan.md](/workspace/projects/nzdk/docs/plans/nip29-runtime-client-plan.md)
  and [docs/plans/nip29-state-authoring-plan.md](/workspace/projects/nzdk/docs/plans/nip29-state-authoring-plan.md)
  plus [docs/plans/nip29-checkpoint-plan.md](/workspace/projects/nzdk/docs/plans/nip29-checkpoint-plan.md)
  and [docs/plans/nip29-multirelay-runtime-plan.md](/workspace/projects/nzdk/docs/plans/nip29-multirelay-runtime-plan.md)
  plus [docs/plans/nip29-fleet-checkpoint-plan.md](/workspace/projects/nzdk/docs/plans/nip29-fleet-checkpoint-plan.md)
  and [docs/plans/nip29-reconciliation-plan.md](/workspace/projects/nzdk/docs/plans/nip29-reconciliation-plan.md)
  plus [docs/plans/nip29-merge-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip29-merge-policy-plan.md)

Why this matters through the applesauce lens:
- this is now the closest slice to a real app-facing workflow and the best current candidate for a
  richer groups client
- but it is still not yet the broader groups client surface many apps would expect from an
  applesauce-like SDK because long-lived runtime ownership and broader background sync posture still
  remain above the current slice, and reconciliation plus publish automation are still explicit
  policy surfaces rather than a fuller higher-level sync/runtime system

### `A-NIP39-001` Medium: `NIP-39` is broader now, but it is still not a complete identity workflow

- status: open
- applies_to: `NIP-39`

Observed friction:
- the current public workflow now covers both one-claim verification and full kind-10011
  identity-event extraction plus batch verification in
  [src/workflows/identity_verifier.zig](/workspace/projects/nzdk/src/workflows/identity_verifier.zig)
- the workflow now also exposes deterministic provider-shaped claim details for GitHub, Twitter,
  Mastodon, and Telegram claims
- it now also exposes an explicit caller-owned cache seam plus an in-memory reference cache for
  reusing deterministic `proof_url + expected_text` verification outcomes across profile
  verification runs
- it now also exposes an explicit caller-owned profile store seam plus an in-memory reference store
  for remembering verified profile summaries and discovering stored identities by provider plus
  identity text
- it now also exposes one explicit verify-and-remember helper above the cache plus profile-store
  seams
- it now also returns hydrated stored profile discovery entries directly and exposes one newest-
  match helper for the common remembered-identity lookup path
- it now also classifies the latest remembered profile as fresh or stale for one provider identity
  without inventing hidden background refresh
- it now also classifies all discovered remembered matches as fresh or stale on one explicit stored
  discovery path instead of forcing callers to re-stitch age policy above the hydrated discovery
  helper
- it now also selects one preferred remembered profile explicitly under a freshness window with
  caller-chosen stale fallback instead of forcing that choice entirely above the store seam
- it now also exposes one explicit remembered runtime-policy helper that classifies one provider
  identity as `verify_now`, `refresh_existing`, `use_preferred`, or `use_stale_and_refresh`
  instead of leaving that common refresh/use decision entirely above the stored discovery seam
- `IdentityStoredProfileRuntimePlan` now also exposes `nextEntry()` so callers can step the
  selected remembered profile directly instead of re-matching the runtime-selected entry above the
  workflow
- `IdentityStoredProfileRuntimePlan` now also exposes `nextStep()` so callers can consume the
  remembered runtime action plus its selected stored profile as one explicit SDK step instead of
  stitching that view together above the workflow
- it now also exposes one explicit stale-profile refresh-plan helper over remembered discovery
  freshness, and `IdentityStoredProfileRefreshPlan` now exposes `nextEntry()` and `nextStep()`,
  so callers do not have to rebuild bounded refresh targeting above the same store seam
- broader identity-management flows are still deferred in
  [docs/plans/nip39-identity-verifier-plan.md](/workspace/projects/nzdk/docs/plans/nip39-identity-verifier-plan.md)
  and [docs/plans/nip39-profile-workflow-plan.md](/workspace/projects/nzdk/docs/plans/nip39-profile-workflow-plan.md)
  plus [docs/plans/nip39-provider-details-plan.md](/workspace/projects/nzdk/docs/plans/nip39-provider-details-plan.md)
  and [docs/plans/nip39-cache-plan.md](/workspace/projects/nzdk/docs/plans/nip39-cache-plan.md)
  plus [docs/plans/nip39-store-discovery-plan.md](/workspace/projects/nzdk/docs/plans/nip39-store-discovery-plan.md)
  plus [docs/plans/nip39-remembered-discovery-plan.md](/workspace/projects/nzdk/docs/plans/nip39-remembered-discovery-plan.md)
  and [docs/plans/nip39-freshness-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip39-freshness-policy-plan.md)
- Telegram is explicitly unsupported for correctness reasons in
  [src/workflows/identity_verifier.zig](/workspace/projects/nzdk/src/workflows/identity_verifier.zig#L45)

Why this matters through the applesauce lens:
- the current slice is now closer to a reusable identity workflow than a simple proof helper
- it is still not yet the fuller identity/discovery workflow that downstream applications can
  readily build around without adding longer-lived store strategy, richer provider semantics, and
  broader autonomous discovery or refresh policy on top

## Per-NIP Assessment

### `NIP-46`

Current state:
- strong correctness and state-machine discipline
- good explicit transport/session control
- current kernel-supported method coverage is now present for connect, key discovery, event signing,
  ping, relay switching, and the pubkey-plus-text encrypt/decrypt family
- examples exist and teach the current surface

Current gap:
- no currently open product-breadth finding; later work, if needed, would be higher-level client
  composition rather than missing method-family coverage

### `NIP-17`

Current state:
- solid inbound mailbox/session core
- one explicit outbound direct-message build path plus recipient relay-fanout planning
- one explicit outbound file-message build path plus recipient relay-fanout planning
- typed file-message intake plus one generic wrapped-envelope intake path
- explicit auth/disconnect behavior
- good kernel-boundary discipline

Current gap:
- still lacks subscription/polling orchestration and broader durable mailbox runtime posture

### `NIP-39`

Current state:
- correct single-claim verifier plus full identity-event claim extraction and batch verification
- explicit caller-owned cache seam plus cached profile verification over deterministic verification
  matches
- explicit remembered-profile store plus hydrated stored discovery
- explicit remembered runtime inspection over stored discovery freshness and preferred selection
- appropriately refuses Telegram instead of overclaiming verification

Current gaps:
- still not a fuller identity workflow: the cache and remembered-profile layers are now explicit,
  but broader autonomous discovery/refresh policy and longer-lived store strategy remain above the
  current slice even though direct remembered-discovery, freshness classification, preferred
  selection, and remembered runtime inspection now exist

### `NIP-03`

Current state:
- clean local verification wrapper over kernel helpers
- useful typed outcomes for local and detached-proof checks
- one explicit caller-owned proof-store seam for detached-proof reuse without hidden runtime
- explicit remembered runtime inspection over stored verification freshness and preferred reuse

Current gap:
- not yet a fuller proof retrieval/verification workflow with Bitcoin-client, freshness, or durable
  proof policy

### `NIP-05`

Current state:
- good fetch/parse/verify shell
- correct mismatch semantics relative to `noztr`

Current gaps:
- redirect-policy correctness still depends on caller-supplied transport behavior

### `NIP-29`

Current state:
- strongest current applesauce-style slice
- meaningful replay/session behavior above the reducer
- explicit outbound join/leave/moderation publish helpers over the pinned relay session
- higher-level `GroupClient` intake over owned previous-ref scratch
- explicit checkpoint export/restore for single-relay snapshot durability
- explicit caller-owned fleet checkpoint-store seam for persisting and restoring relay-local
  multi-relay state
- explicit fleet runtime inspection over relay readiness plus divergence against a chosen baseline
- explicit targeted baseline-to-target reconcile stepping for one divergent relay
- examples teach a real workflow rather than only a helper call
- setup and inspection are now more client-like through named config/storage and a stable view

Current gap:
- still not a full group client: no broader background runtime ownership and no broader
  sync/publish automation beyond the current explicit relay-local path and fleet runtime view

## Recommended Direction Before New NIP Work

1. Broaden `NIP-17`, `NIP-39`, `NIP-03`, or `NIP-29` toward the remaining real-world workflow
   paths.
2. Keep treating `NIP-29` as the leading candidate for a richer app-facing client layer.
3. Do not claim applesauce-equivalent functionality yet; claim instead that the repo has a strong,
   explicit first workflow floor with one especially promising groups slice.
