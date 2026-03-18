---
title: Noztr SDK NIP-29 Sync And Store Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 29
read_when:
  - refining_nip29
  - auditing_group_session
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings: []
---

# Noztr SDK NIP-29 Sync And Store Plan

Dedicated execution packet for the broader post-loop `NIP-29` lane after the first examples slice.

Date: 2026-03-15

This plan records the accepted broader `NIP-29` slice. The earlier next-slice evaluation it came
from now lives under `docs/archive/plans/`.

Follow-on Zig-native surface shaping for this slice now lives in
[nip29-ergonomic-surface-plan.md](./nip29-ergonomic-surface-plan.md).

Follow-on client-surface broadening for this slice now lives in
[nip29-client-surface-plan.md](./nip29-client-surface-plan.md).

Follow-on runtime/client broadening for this slice now lives in
[nip29-runtime-client-plan.md](./nip29-runtime-client-plan.md).

Follow-on state-authoring broadening for this slice now lives in
[nip29-state-authoring-plan.md](./nip29-state-authoring-plan.md).

Follow-on checkpoint/durable single-relay broadening for this slice now lives in
[nip29-checkpoint-plan.md](./nip29-checkpoint-plan.md).

Follow-on fleet checkpoint persistence broadening for this slice now lives in
[nip29-fleet-checkpoint-plan.md](./nip29-fleet-checkpoint-plan.md).

Follow-on explicit fleet reconciliation broadening for this slice now lives in
[nip29-reconciliation-plan.md](./nip29-reconciliation-plan.md).

This packet should now be read as a slice-specific record, not as a replacement for the canonical
quality gate.

## Research Delta

Fresh recheck performed against:
- `docs/nips/29.md`
- `/workspace/projects/noztr/src/nip29_relay_groups.zig`
- `/workspace/projects/noztr/examples/nip29_reducer_recipe.zig`
- `/workspace/projects/noztr/examples/nip29_adversarial_example.zig`
- `/workspace/projects/noztr/handoff.md`
- `/workspace/projects/noztr/docs/plans/decision-log.md`

Current kernel posture:
- `noztr` owns deterministic `NIP-29` group-reference parsing, state extraction, and bounded
  reducer replay
- `noztr` now also covers reducer/adversarial recipes and moderation replay with bounded
  `previous` tags
- `noztr` still does not own relay transcript orchestration, ordering policy, snapshot history, or
  durable state

Resulting SDK implication:
- the next `NIP-29` lane should stay above the reducer and add only explicit transcript intake plus
  snapshot-and-incremental replay semantics
- bounded recent-history handling for `previous` validation and selection belongs in the SDK layer
- multi-relay merge, durable stores, and automatic canonical ordering remain deferred

## Scope Card

Target slice:
- single-relay `NIP-29` session engine over caller-supplied canonical event streams, bounded recent
  history, and explicit request/timeline observation

Target caller persona:
- client, relay-admin, or service authors who already control relay IO and want a reusable SDK
  layer for group-state replay with explicit snapshot reset and incremental apply

Public entrypoints to add or change:
- extend `noztr_sdk.workflows.GroupSession` with:
  - explicit snapshot and incremental transcript helpers
  - bounded `previous` validation and selection helpers
  - explicit join/leave request intake
  - bounded generic group-event observation

Explicit non-goals for this slice:
- multi-relay merge or fork reconciliation
- durable store implementation
- automatic canonical ordering policy
- publish-flow automation
- background subscription loops
- relay fetch/runtime ownership outside explicit caller stepping

## Kernel And SDK Inventory

`noztr` remains authoritative for:
- `GroupReference`
- `GroupState`
- group event extraction
- `group_state_apply_event(...)`
- event parse and verify

Kernel recipe references:
- `nip29_reducer_recipe.zig`
- `nip29_adversarial_example.zig`

SDK-owned orchestration for this slice:
- explicit snapshot reset plus replay entrypoint
- incremental apply entrypoint that shares the same gating and target-group checks
- caller-owned transcript ordering responsibility
- bounded recent-history tracking for `previous` validation and selection
- explicit join/leave request intake and generic group-event observation over the pinned session

## Boundary Answers

### Snapshot-plus-incremental replay

Why is this not already a `noztr` concern?
- it combines reducer application with caller-controlled relay transcript boundaries and workflow
  state, which are orchestration concerns

Why is this not application code above `noztr-sdk`?
- multiple apps will need the same bounded “reset to snapshot, then apply incremental events”
  workflow without rewriting reducer-safe replay shells

Why is this the simplest useful SDK layer?
- it adds one reusable sync shape without freezing transport runtime or durable-store policy

### Previous-reference history

Why is this not already a `noztr` concern?
- tracking recent relay context and validating `previous` references is workflow/session state, not
  pure protocol parsing

Why is this not application code above `noztr-sdk`?
- callers should not have to reinvent the same bounded recent-history shell just to comply with the
  `previous` contract

Why is this the simplest useful SDK layer?
- a fixed-capacity recent-history helper keeps `previous` handling explicit without turning the SDK
  into a database or hidden sync engine

## Example-First Design

Target example shape:
1. caller initializes a `GroupSession`
2. caller marks the relay connected
3. caller applies one canonical snapshot array
4. caller selects valid `previous` refs from recent session history
5. caller applies one later incremental moderation event
6. caller observes a request or generic group event if desired

Minimal example goal:
- “apply a full snapshot, select valid `previous` refs, then apply and observe later group events”

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- snapshot replay and incremental replay share the same relay gating and target-group checks
- every accepted event is signature-verified before reducer mutation
- replay helpers do not silently imply canonical ordering the SDK does not own
- snapshot reset semantics are explicit and caller-visible
- incremental apply does not mutate state when the relay is disconnected or auth-gated
- `previous` references are only accepted when they match bounded recent relay context tracked by
  the session
- outbound `previous` selection does not require callers to duplicate recent-history bookkeeping

Proven by `noztr`:
- event parsing and signature verification
- group extraction and state reduction

Proven by `noztr-sdk`:
- explicit replay boundaries
- shared gating between JSON and typed replay entrypoints
- reset-and-replay orchestration
- bounded recent-history tracking and lookup
- request/timeline observation over the pinned group session

Current proof gaps to keep explicit:
- the SDK still cannot prove that the caller-supplied ordering is canonical
- the SDK can validate `previous` refs only against the events observed through the session, not
  against a full relay database
- this slice still does not claim durable cursor persistence or retained transcript storage

## Seam Contract Audit

Relay/session seam requirements:
- replay must be blocked while disconnected or auth-gated
- disconnect semantics must be shared across all replay entrypoints

Transcript seam requirements:
- caller must provide already-collected canonical or incremental event sequences
- the SDK does not fetch or order events in this slice

History seam requirements:
- bounded recent relay context must stay in-memory and explicit
- no durable history or cursor storage is introduced in this slice

Accepted seam limits:
- no auto-reconnect
- no durable sync cursor
- no relay backfill/fetch API

## State-Machine Table

Relay states:
- disconnected
- connected
- auth required

Replay states:
- empty
- snapshot applied
- incremental replayed
- recent history available

Valid transitions:
- disconnected -> connected via existing relay transition
- connected -> auth required via existing auth challenge transition
- connected + empty -> snapshot applied via snapshot replay entrypoint
- connected + snapshot applied -> incremental replayed via incremental entrypoint
- any accepted replay or observed group event may refresh recent-history entries
- any replay state -> empty via explicit reset

Invalid transitions:
- snapshot or incremental replay while disconnected
- snapshot or incremental replay while auth is required
- incremental replay that bypasses the same validation rules used by snapshot replay
- request or generic observation that accepts unknown `previous` refs

Reset rules:
- snapshot reset clears reduced state and in-memory recent-history entries
- reset preserves the pinned group reference and relay session shell

## Test Matrix

Required tests before close:
- snapshot replay happy path over canonical metadata/roles/members/moderation sequence
- incremental apply happy path after an accepted snapshot
- snapshot reset plus replacement replay
- disconnect blocks both snapshot and incremental replay
- auth-required blocks both snapshot and incremental replay
- wrong-group event in snapshot is rejected before mutation
- wrong-group event in incremental apply is rejected before mutation
- malformed or invalid signed event is rejected before mutation in both paths
- parity check that JSON and typed replay entrypoints share the same gating and mutation rules
- join request acceptance with known `previous` refs
- join request rejection with unknown `previous` refs
- leave request intake over JSON path
- generic group-event observation with bounded `previous` validation
- `selectPreviousRefs(...)` returns bounded recent refs and can exclude the current author
- in-memory recent-history bookkeeping is reset correctly
- adversarial mixed-group or reordered transcript test does not leave partial hidden state

Deferred tests:
- multi-relay merge
- durable cursor/store behavior
- retained transcript/history validation beyond the session-owned window

## Acceptance Checks

This broader `NIP-29` slice is not done until:
- the new packet is reflected in startup docs and handoff
- the chosen public surface stays narrow and does not freeze multi-relay/store policy too early
- required tests exist and pass
- examples are updated if the public replay shape changes materially
- `zig build`
- `zig build test --summary all`
- local `noztr` compatibility is rechecked
- any real new kernel friction is recorded in `noztr-feedback-log.md`

## Planned First Cut

Start with:
- explicit `applySnapshot...` helper(s)
- explicit `applyIncremental...` helper(s)
- shared internal replay path so typed and JSON entrypoints cannot drift
- bounded recent-history helpers for `previous`
- explicit request/timeline observation
- no new store module yet

Only after that lands green should the repo evaluate:
- a reusable durable cursor seam
- retained transcript/history storage
- multi-relay or fork reconciliation

## Accepted Slice

Implemented and reviewed on 2026-03-15:
- `GroupSession.applySnapshotEvents(...)`
- `GroupSession.applySnapshotEventJsons(...)`
- `GroupSession.applyIncrementalStateEvent(...)`
- `GroupSession.applyIncrementalStateEventJson(...)`
- `GroupSession.acceptJoinRequestEvent(...)`
- `GroupSession.acceptJoinRequestEventJson(...)`
- `GroupSession.acceptLeaveRequestEvent(...)`
- `GroupSession.acceptLeaveRequestEventJson(...)`
- `GroupSession.observeGroupEvent(...)`
- `GroupSession.observeGroupEventJson(...)`
- `GroupSession.selectPreviousRefs(...)`
- shared replay validation so typed and JSON entrypoints cannot drift
- snapshot failure semantics that clear the replay back to empty instead of leaving partially
  applied hidden state
- bounded recent-history validation and selection for `previous`
- explicit join/leave request intake and generic group-event observation
- updated recipe coverage in `examples/group_session_recipe.zig`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `108/108`

Deferred after this accepted slice:
- reusable durable cursor seam
- retained transcript/history storage beyond the session-owned window
- multi-relay or durable-store work
- higher-level client breadth beyond the current session engine

Follow-on accepted client-surface slice on 2026-03-16:
- `GroupSession.beginJoinRequest(...)`
- `GroupSession.beginLeaveRequest(...)`
- `GroupSession.beginPutUser(...)`
- `GroupSession.beginRemoveUser(...)`
- caller-owned publish context and outbound buffer types
- round-trip recipe coverage for replay plus one outbound moderation publish

Follow-on accepted runtime/client slice on 2026-03-16:
- `src/workflows/group_client.zig`
- `GroupClient` mixed-event intake over owned previous-ref scratch
- typed batch relay-event summaries over the single-relay group core

Follow-on accepted state-authoring slice on 2026-03-16:
- `GroupSession.beginMetadataSnapshot(...)`
- `GroupSession.beginAdminsSnapshot(...)`
- `GroupSession.beginMembersSnapshot(...)`
- `GroupSession.beginRolesSnapshot(...)`
- matching `GroupClient` wrapper entrypoints
- recipe coverage now teaches authored snapshot state plus moderation publish through `GroupClient`

Follow-on accepted durable fleet-store slice on 2026-03-18:
- `GroupFleetCheckpointStore`
- `MemoryGroupFleetCheckpointStore`
- `GroupFleet.persistCheckpointStore(...)`
- `GroupFleet.restoreCheckpointStore(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches explicit fleet persistence into
  a caller-owned store and restore into a fresh fleet
