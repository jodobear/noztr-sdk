---
title: Noztr SDK Implemented-NIPs Zig-Native Audit
doc_type: audit
status: active
owner: noztr-sdk
posture: zig-native
read_when:
  - evaluating_zig_native_api_shape
  - planning_refinement_work
---

# Noztr SDK Implemented-NIPs Zig-Native Audit

Audit date: 2026-03-15

Scope:
- implemented workflow surfaces under `src/workflows/`
- public exports in `src/workflows/mod.zig` and `src/root.zig`
- current structured examples under `examples/`
- active planning packets for the implemented NIP slices

Lens:
- `noztr-sdk` should become the Zig-native analogue to applesauce
- that means matching or exceeding applesauce in real-world usefulness and teaching posture
- but doing so in a Zig way:
  - explicit ownership
  - bounded storage
  - deterministic state transitions
  - compile-checked and easy-to-reason-about surfaces
  - no mechanical TypeScript-to-Zig API translation

## Overall Assessment

The implemented workflow set already uses several Zig strengths well:
- bounded state instead of hidden runtime growth
- explicit relay/session state transitions
- clear ownership boundaries between `noztr` and `noztr-sdk`
- compile-verified examples

The current weakness is different:
- the repo is often exposing the bounded core directly as the public SDK surface
- that is good for correctness, but not yet good enough for "simple and straightforward" Zig SDK
  ergonomics

In other words:
- current slices are often good Zig substrate
- they are not yet consistently good Zig SDK surface

## Open Findings Index

- `Z-WORKFLOWS-001`: `NIP-17` is still a session core more than a fuller app workflow
- `Z-ABSTRACTION-001`: implemented slices still mix substrate and SDK abstraction levels

## Findings

### `Z-HTTP-001` Resolved: the HTTP-backed workflows now have a coherent public Zig seam

- status: resolved
- applies_to: `NIP-39`, `NIP-05`

Resolution note:
- `src/root.zig` now exports the narrow `noztr_sdk.transport` seam deliberately
- the public examples now demonstrate that seam directly for `IdentityVerifier` and
  `Nip05Resolver`
- the remaining Zig-native HTTP issue is no longer discoverability of the seam; it is the broader
  ergonomic question captured by `Z-BUFFER-001`

### `Z-BUFFER-001` Resolved: the implemented workflow floor now teaches caller-owned wrapper shapes instead of raw buffer choreography

- status: resolved
- applies_to: `NIP-46`, `NIP-39`, `NIP-05`

Resolution note for `NIP-39`:
- `src/workflows/identity_verifier.zig` now exposes `IdentityVerificationStorage` and
  `IdentityVerificationRequest`
- the primary verifier entrypoint now teaches one caller-owned wrapper shape instead of three raw
  temporary buffers
- `examples/nip39_verification_recipe.zig` now teaches that wrapper shape directly

Resolution note for `NIP-05`:
- `src/workflows/nip05_resolver.zig` now exposes `Nip05LookupStorage`, `Nip05LookupRequest`, and
  `Nip05VerificationRequest`
- the resolver now teaches one caller-owned storage wrapper plus explicit request structs instead
  of raw buffer choreography
- `examples/nip05_resolution_recipe.zig` now teaches that wrapper shape directly

Resolution note for `NIP-46`:
- `src/workflows/remote_signer.zig` now exposes `RequestContext` so callers provide one explicit
  request id, buffer, and scratch wrapper to every `begin...` method
- `src/workflows/mod.zig` now exports `RemoteSignerRequestContext`
- `examples/remote_signer_recipe.zig` now teaches the request-context shape instead of repeating
  raw `buffer + id + scratch` arguments on each call

### `Z-NIP29-001` Resolved: `GroupSession` now uses a clearer Zig-native config/storage/view surface

- status: resolved
- applies_to: `NIP-29`

Resolution note:
- `src/workflows/group_session.zig` now exposes `GroupSessionStorage`, `GroupSessionConfig`, and
  `GroupSessionView`
- the preferred init path no longer requires positional raw storage slices
- the recipe in [examples/group_session_recipe.zig](/workspace/projects/nzdk/examples/group_session_recipe.zig#L8)
  now teaches the wrapper/view surface instead of reducer-layout mechanics first
- the remaining `NIP-29` gap is broader client breadth, not raw storage-shape friction

### `Z-EXAMPLES-001` Resolved: the remote-signer recipe now teaches the public SDK path first instead of letting transcript scaffolding dominate the example

- status: resolved
- applies_to: `NIP-46`, examples

Resolution note:
- `examples/remote_signer_recipe.zig` now foregrounds the connect, public-key, and `nip44_encrypt`
  workflow path and keeps repetitive response JSON wiring in one small local helper
- the examples catalog now calls out the stable control points directly for the remote-signer,
  mailbox, `NIP-03`, `NIP-39`, and `NIP-29` recipes
- the remaining Zig-native teaching gap is broader workflow completeness, not one recipe being
  mechanically dominated by transcript plumbing

### `Z-WORKFLOWS-001` Medium: `NIP-17` now has sender-copy-aware delivery planning, explicit file-message send and intake, and explicit mailbox runtime inspection, but still stops short of a fuller Zig app workflow

- status: open
- applies_to: `NIP-17`

Observed friction:
- `MailboxSession` now exposes one outbound direct-message builder as well as inbound intake in
  [src/workflows/mailbox.zig](/workspace/projects/nzdk/src/workflows/mailbox.zig)
- it now also plans deduplicated recipient relay fanout from a verified kind-10050 relay list
- it now also plans verified sender-copy delivery over one built wrap with explicit relay-role
  annotation
- `MailboxDeliveryPlan` now also exposes `nextRelayIndex()` and `nextStep()` so callers can step
  the deduplicated delivery plan without re-scanning relay-role flags or re-stitching wrap
  payload context above the workflow
- it now also authors one explicit outbound file-message wrap and can plan relay delivery for that
  same file-message payload without rebuilding the wrap
- it now also unwraps and parses `NIP-17` file messages and can classify direct-message vs file-
  message rumors on one explicit intake path
- it now also exposes one explicit runtime view over hydrated mailbox relays and one explicit relay
  selection helper so callers can drive connect/authenticate/receive decisions without hand-scanning
  relay pool state above the workflow
- it now also exposes one explicit next-step selector above that runtime view so callers can follow
  the bounded mailbox action priority without hand-scanning the runtime plan
- but callers still have to handle broader mailbox sync posture and richer mailbox runtime policy
  above the workflow

Why this matters through the Zig lens:
- Zig does not force minimality here; the current thinness is a product-scope choice, not a language
  constraint
- if the objective is "better than applesauce-in-TypeScript by using Zig well", these workflows
  should eventually offer fuller round-trip app paths, not only bounded session kernels plus
  explicit send and intake helpers

### `Z-ABSTRACTION-001` Low: the repo is now explicit about the product target, but the implemented slices still mix two levels of abstraction

- status: open
- applies_to: implemented workflow set

Observed friction:
- the docs now correctly describe a Zig-native applesauce analogue in
  [README.md](/workspace/projects/nzdk/README.md#L11),
  [AGENTS.md](/workspace/projects/nzdk/AGENTS.md#L41),
  [NOZTR_SDK_STYLE.md](/workspace/projects/nzdk/docs/guides/NOZTR_SDK_STYLE.md#L10), and
  [build-plan.md](/workspace/projects/nzdk/docs/plans/build-plan.md#L36)
- the stronger slices now have better public wrapper shapes, especially `NIP-29`
- `NIP-29` now has clearer authored state plus higher-level mixed-intake client layers and one
  explicit checkpoint export/restore path
- `NIP-29` now also has `GroupFleet` as an explicit multi-relay routing layer above relay-local
  `GroupClient`s
- `NIP-29` now also has a caller-owned fleet checkpoint set for explicit multi-relay persistence
  without hidden store policy
- `NIP-29` now also has an explicit fleet-level divergence report and one source-led
  reconciliation helper instead of forcing callers to hand-compose relay-to-relay checkpoint copy
  flows
- `NIP-29` now also has an explicit caller-owned fleet checkpoint-store seam, so durable-sync
  reuse no longer requires carrying one giant fleet-local checkpoint blob through the caller
- `NIP-29` now also has one explicit component-level merge selection layer over the fleet
  checkpoint seam, so callers no longer need to hand-compose merged metadata/admins/members/roles
  checkpoints above the fleet
- `NIP-29` now also has an explicit caller-owned fleet publish-planning surface for moderation
  events, so multi-relay app flows no longer need to hand-compose per-relay previous-ref
  selection and publish-buffer wiring above the fleet
- `GroupFleet.nextPublishEvent(...)` now also exposes one explicit next-relay selector above that
  fanout so callers can step one publish target without hand-scanning the returned fleet slice
- `NIP-29` now also has one explicit fleet runtime plan over relay readiness and divergence against
  a chosen baseline, so callers no longer need to hand-compose runtime action selection above the
  fleet
- `GroupFleetRuntimePlan` now also exposes `nextEntry()` so callers can follow that bounded
  runtime policy without hand-scanning the fleet plan
- `NIP-29` now also has one explicit targeted baseline-to-target reconcile helper, so callers can
  step one divergent relay toward the chosen runtime baseline without falling back to all-relay
  reconcile helpers or hand-rolled checkpoint copy code
- `NIP-39` now exposes provider-shaped details plus one explicit cached verification seam instead
  of only raw verification counts
- `NIP-39` now also exposes one explicit freshness-classified remembered discovery helper instead
  of leaving all multi-match remembered-age policy above the store seam
- `NIP-39` now also exposes one explicit remembered runtime-policy helper above the same caller-
  owned freshness discovery surface, so the common verify-vs-refresh-vs-use decision no longer
  has to be rebuilt entirely above the store seam
- `IdentityStoredProfileRuntimePlan` now also exposes `nextEntry()` so callers can follow the
  selected remembered-profile step directly instead of re-matching the runtime-selected entry
  above the workflow
- `IdentityStoredProfileRuntimePlan` now also exposes `nextStep()` so callers can package the
  selected remembered-profile action and entry as one explicit step value instead of reconstructing
  that SDK view above the runtime plan
- `NIP-39` now also exposes one explicit stale-profile refresh-plan helper, so bounded remembered
  refresh targeting no longer has to be rebuilt above the same freshness discovery surface
- `NIP-03` now also exposes one explicit stale-verification refresh-plan helper, so bounded proof
  refresh targeting no longer has to be rebuilt above the same freshness discovery surface
- `OpenTimestampsStoredVerificationRuntimePlan` now also exposes `nextEntry()` so callers can
  follow the selected remembered-verification step directly instead of re-matching the runtime-
  selected entry above the workflow
- `OpenTimestampsStoredVerificationRuntimePlan` now also exposes `nextStep()` so callers can
  package the selected remembered-verification action and entry as one explicit step value instead
  of reconstructing that SDK view above the runtime plan
- but several public workflow surfaces still sit halfway between:
  - low-level bounded substrate
  - higher-level SDK workflow

Why this matters:
- if the repo does not distinguish those two layers more clearly, future slices may stay correct but
  keep feeling mechanical

Current assessment:
- `NIP-29` is materially better here after the fleet reconciliation and durable-store slices
  because the multi-relay surface is now more clearly expressed as SDK workflow policy above the
  relay-local client layer, including explicit moderation fanout, explicit component-level merge
  selection, explicit runtime action inspection, and one targeted reconcile step
- `Z-ABSTRACTION-001` remains open mainly because other workflows still mix substrate and SDK
  levels, not because `GroupFleet` still lacks fleet-level reconciliation, merge-policy helpers, or
  runtime inspection

## Per-NIP View

### `NIP-46`

Strengths:
- explicit state machine
- bounded pending table
- good disconnect/failover semantics
- current method coverage now matches the kernel-supported request family, including the
  pubkey-plus-text encrypt/decrypt methods

Zig-native gap:
- request-building ergonomics are materially better through `RemoteSignerRequestContext`
- the remaining gap is example/teaching complexity, not the public method signature shape

### `NIP-17`

Strengths:
- strong relay/session explicitness
- good duplicate handling and boundary discipline
- one-wrap recipient relay-fanout planning above the kernel helper boundary

Zig-native gap:
- current surface is no longer inbound-only, and it now includes a bounded runtime inspection layer,
  but it is still closer to an explicit messaging core than a fuller app-facing mailbox workflow

### `NIP-39`

Strengths:
- disciplined refusal to overclaim provider verification
- clear typed result outcomes
- clearer caller-owned request/storage wrapper shape than the original raw multi-buffer entrypoint
- now supports full identity-event extraction plus batch verification without hiding the HTTP seam
- now exposes one explicit caller-owned cache seam for reusing deterministic verification outcomes
- now exposes one explicit caller-owned profile-store seam for remembered verified profiles and
  bounded provider-plus-identity discovery
- now exposes one explicit verify-and-remember helper plus hydrated stored-discovery helpers for the
  common remembered-identity path
- now also exposes one explicit freshness helper over the latest remembered profile instead of
  forcing age-policy stitching entirely above the store seam
- now also exposes one explicit freshness-classified remembered discovery helper for all stored
  matches of one provider identity
- now also exposes one explicit preferred remembered-profile selection helper with caller-chosen
  stale fallback instead of forcing that small but real policy layer above the store seam
- now also exposes one explicit remembered runtime-policy helper that classifies the common
  verify/refresh/use decision over caller-owned remembered discovery instead of leaving that
  workflow step entirely above the store seam

Zig-native gap:
- still narrower than a richer identity/discovery workflow with provider-specific parsing and cache
  policy; provider-shaped claim details plus remembered discovery/freshness/runtime policy now
  exist, but broader autonomous discovery and longer-lived identity strategy still sit above the
  current slice

### `NIP-03`

Strengths:
- clear, bounded local verification step
- good typed outcome classification
- now also exposes one caller-directed detached-proof fetch-and-verify path over the explicit HTTP
  seam
- now also exposes one explicit caller-owned proof-store seam for detached-proof reuse without
  hidden background refresh
- now also exposes one explicit caller-owned remembered-verification store seam plus latest-match
  lookup so callers can recover a verified detached proof summary later without inventing hidden
  global state
- now also exposes one explicit freshness-classified remembered-discovery helper for all stored
  verifications of one target event
- now also exposes one explicit remembered runtime-policy helper that classifies the common
  verify/refresh/use decision over caller-owned remembered verification discovery

Zig-native gap:
- useful proof workflow surface now, but still narrower than a fuller higher-level verification
  policy with Bitcoin inclusion/freshness handling and longer-lived proof strategy

### `NIP-05`

Strengths:
- correct mismatch semantics
- explicit fetch/verify split
- clearer caller-owned request/storage wrapper than the original raw buffer-heavy entrypoint

Zig-native gap:
- still narrower than a richer higher-level identity/discovery workflow

### `NIP-29`

Strengths:
- best current use of Zig strengths: bounded state, explicit replay, no hidden magic
- strongest current candidate for a truly differentiated Zig workflow
- now has a coherent publish layer through caller-owned publish context, outbound buffer, and typed
  drafts instead of leaving group-event authoring entirely above the SDK
- now also has a clearer higher-level `GroupClient` layer above `GroupSession` for mixed event
  intake
- now also has an explicit fleet-level moderation fanout surface through caller-owned publish
  storage instead of forcing per-relay publish orchestration entirely above the SDK
  intake without hiding runtime control
- now also has one explicit checkpoint export/restore path for local single-relay durability
- now also has explicit fleet routing, source-led reconciliation, and a caller-owned checkpoint
  store seam for durable multi-relay reuse without hidden runtime magic
- now also has one explicit fleet runtime view over relay state plus divergence against a chosen
  baseline instead of forcing callers to compose readiness plus reconcile policy entirely above the
  fleet
- now also has one explicit targeted baseline-to-target reconcile step, so incremental runtime
  convergence does not require all-relay restore helpers or hand-rolled checkpoint copy code

Zig-native gap:
- still stops short of a fuller higher-level groups client or sync runtime

## Recommended Direction

1. Introduce a clearer distinction between:
   - bounded core workflow surface
   - ergonomic Zig SDK surface above it
2. Keep the current explicitness, but move more temporary scratch/buffer choreography out of the
   first thing downstream users see.
3. Use the `NIP-29` storage/config/view refinement as the model for future stateful workflow
   shaping rather than exposing positional raw slices by default.
