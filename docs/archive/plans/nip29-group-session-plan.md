# Noztr SDK NIP-29 Group Session Plan

Dedicated execution packet for the first `NIP-29` workflow slice in `noztr-sdk`.

Date: 2026-03-15

This plan satisfies Gate `G2` for the active `NIP-29` loop in
[nip-meta-loop-17-39-03-05-29.md](./nip-meta-loop-17-39-03-05-29.md).

## Research Delta

Fresh recheck performed against:
- `docs/nips/29.md`
- `/workspace/projects/noztr/src/nip29_relay_groups.zig`
- `/workspace/projects/noztr/examples/nip29_example.zig`
- `/workspace/projects/noztr/examples/nip29_reducer_recipe.zig`
- `/workspace/projects/noztr/examples/nip29_adversarial_example.zig`

Current kernel posture:
- `noztr` already owns bounded `NIP-29` group-reference parsing, metadata/admin/member/role
  extraction, moderation-event extraction, canonical tag builders, and a fixed-capacity group-state
  reducer
- the kernel recipe set now covers reducer replay and hostile mixed-group input in addition to the
  smaller extraction example
- `noztr` still does not model relay session state, target-group pinning, or workflow intake

Resulting SDK implication:
- the first `noztr-sdk` slice should stay above the reducer and own only explicit relay/session
  handling plus bounded state intake around a pinned target group
- this slice should not attempt full subscription runtime, event ordering policy, or durable group
  storage yet

## Scope Card

Target slice:
- step-driven single-relay `NIP-29` group session for one pinned group reference

Target caller persona:
- client or service authors who already control transport and want reusable bounded group-state
  intake, auth/session transitions, and target-group validation without rebuilding the same wrapper
  around the kernel reducer

Public entrypoints for this slice:
- `noztr_sdk.workflows.GroupSession`
- `noztr_sdk.workflows.GroupSessionError`
- `noztr_sdk.workflows.GroupStateEventKind`

Explicit non-goals for this slice:
- websocket subscription runtime
- multi-relay fanout or fork reconciliation
- durable group-state storage
- canonical ordering or timeline-`previous` selection policy
- join-request or leave-request send workflows
- moderation-event builders or publish flows
- broad top-level client expansion

## Kernel Inventory

`noztr` exports that must remain authoritative:
- `noztr.nip29_relay_groups.GroupReference`
- `noztr.nip29_relay_groups.GroupState`
- `noztr.nip29_relay_groups.GroupStateUser`
- `noztr.nip29_relay_groups.GroupRole`
- `noztr.nip29_relay_groups.group_reference_parse(...)`
- `noztr.nip29_relay_groups.group_metadata_extract(...)`
- `noztr.nip29_relay_groups.group_admins_extract(...)`
- `noztr.nip29_relay_groups.group_members_extract(...)`
- `noztr.nip29_relay_groups.group_roles_extract(...)`
- `noztr.nip29_relay_groups.group_put_user_extract(...)`
- `noztr.nip29_relay_groups.group_remove_user_extract(...)`
- `noztr.nip29_relay_groups.group_state_apply_event(...)`
- `noztr.nip01_event.event_parse_json(...)`
- `noztr.nip01_event.event_verify(...)`
- `noztr.nip42_auth`

Current kernel recipe reference:
- `/workspace/projects/noztr/examples/nip29_example.zig`
- `/workspace/projects/noztr/examples/nip29_reducer_recipe.zig`
- `/workspace/projects/noztr/examples/nip29_adversarial_example.zig`

SDK-owned orchestration for this slice:
- one pinned group reference plus one validated relay URL
- relay connect/auth/disconnect transitions over the existing relay-session substrate
- explicit resettable kernel-state ownership for one group session
- target-group validation before reducer mutation
- typed acceptance of only the reducer-relevant `NIP-29` state kinds

## Boundary Answers

### Group session

Why is this not already a `noztr` concern?
- it combines relay session state, target-group pinning, and incremental state intake above the
  deterministic reducer

Why is this not application code above `noztr-sdk`?
- multiple apps will need the same bounded group-session core even when they differ on transport,
  persistence, and UI

Why is this the simplest useful SDK layer?
- it turns the pure reducer into one reusable workflow surface without hiding transport or sync
  policy

### Target-group pinning

Why is this not already a `noztr` concern?
- pinning one session to one reference and one relay is workflow context, not protocol parsing

Why is this not application code above `noztr-sdk`?
- every group client should not have to rebuild the same "does this event belong to my current
  group session?" checks

Why is this the simplest useful SDK layer?
- it makes cross-group drift explicit before state mutation while keeping the caller in control of
  ordering and transport

## Example-First Design

Target example shape:
1. caller initializes a `GroupSession` from `"groups.example'pizza-lovers"` plus
   `"wss://groups.example"`
2. caller marks the relay connected and handles auth explicitly if needed
3. caller passes canonical metadata/admin/member/moderation event JSON payloads into the session
4. caller reads the reduced group state from the session
5. caller resets the state explicitly before replaying a fresh canonical snapshot sequence

Minimal example goal:
- "hydrate one group session from metadata, admin, member, and `put-user` events, reject a
  different-group event, then reset and replay cleanly"

## API Sketch

Public workflow shape for the first slice:
- `GroupSession.init(reference_text, relay_url, user_storage, supported_role_storage, user_role_storage) !GroupSession`
- `GroupSession.groupReference() GroupReference`
- `GroupSession.currentRelayUrl() []const u8`
- `GroupSession.currentRelayCanReceive() bool`
- `GroupSession.markCurrentRelayConnected() void`
- `GroupSession.noteCurrentRelayDisconnected() void`
- `GroupSession.noteCurrentRelayAuthChallenge(challenge) !void`
- `GroupSession.acceptCurrentRelayAuthEventJson(auth_event_json, now, window, scratch) !void`
- `GroupSession.resetState() void`
- `GroupSession.groupState() *const GroupState`
- `GroupSession.acceptCanonicalStateEventJson(event_json, scratch) !GroupStateEventKind`

Expected result modeling:
- accepted state kinds return one of:
  - `.metadata`
  - `.admins`
  - `.members`
  - `.roles`
  - `.put_user`
  - `.remove_user`
- only reducer-relevant state kinds are accepted in this first slice

Internal-only for this slice:
- group-reference storage
- relay-host matching helper
- event-to-group-id extraction helper

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- the session is pinned to one validated group reference and one validated relay URL
- only cryptographically valid events mutate the reduced state
- only reducer-relevant `NIP-29` state kinds are accepted in this slice
- accepted events must target the pinned group id before the reducer mutates session state
- disconnect and auth-required states block event intake until the relay is usable again
- `resetState()` clears reduced state but preserves the pinned reference and relay session shell

Proven by `noztr`:
- group-reference parsing
- metadata/admin/member/role/put-user/remove-user extraction
- fixed-capacity group-state reduction
- event signature verification

Proven by `noztr-sdk`:
- relay/session gating
- one-group pinning
- one-relay pinning
- explicit reset semantics
- rejection of unsupported or wrong-group events before reducer mutation

Current accepted proof gaps:
- this slice cannot prove moderation authorization against relay policy; it can only verify event
  signatures and reduce structurally valid events
- this slice cannot prove canonical ordering; callers must supply the canonical event sequence for
  correct replay
- this slice does not validate `previous` references against local relay history because no
  timeline-history seam exists yet

## Seam Contract Audit

Relay/session seam requirements:
- caller must be able to report relay connected, auth challenge, auth success, and disconnect
- event intake must be blocked while the relay is disconnected or auth-gated

Current seam status:
- the existing relay session supports explicit connect/auth/disconnect transitions
- this first slice intentionally stays on one relay only

Accepted seam limits:
- no subscription runtime or retry scheduler exists in this slice
- no relay-history seam exists yet for `previous` validation
- no group-state store seam exists yet, so reduced state remains in caller-owned in-memory storage

## State-Machine Table

Relay states:
- disconnected
- connected
- auth required

Valid transitions:
- disconnected -> connected via `markCurrentRelayConnected()`
- connected -> auth required via `noteCurrentRelayAuthChallenge(...)`
- auth required -> connected via `acceptCurrentRelayAuthEventJson(...)`
- any state -> disconnected via `noteCurrentRelayDisconnected()`

Invalid transitions:
- auth challenge while disconnected
- auth acceptance while auth is not required
- state-event intake while disconnected or auth-gated

Reset rules:
- `resetState()` clears reduced group metadata, users, and supported roles
- `resetState()` preserves the pinned group reference and relay URL
- disconnect clears relay readiness only; it does not clear reduced state

## Test Matrix

Required tests for Gate `G3`:
- happy-path session init, connect, and canonical metadata/admin/member/put-user intake
- relay-host mismatch at init is rejected
- malformed group-reference text is rejected
- invalid signed state events are rejected before mutation
- wrong-group events are rejected before mutation
- unsupported non-state `NIP-29` kinds are rejected explicitly
- auth-required relay blocks state-event intake until auth succeeds
- same-relay disconnect blocks state-event intake until reconnection
- `resetState()` clears reduced state and allows clean replay
- mixed-group replay after accepted events is rejected
- snapshot replacement semantics stay aligned with the kernel reducer
- root/workflows export remains narrow

Deferred tests for later `NIP-29` slices:
- canonical ordering helpers
- `previous` reference selection/validation
- multi-relay or forked-group reconciliation
- durable store-backed sync
- join/leave/moderation publish flows

## Acceptance Checks

This first `NIP-29` slice is not done until:
- the group session lands without broadening the root surface beyond `workflows`
- all required tests from this plan exist
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` is rechecked after the SDK slice lands
- any newly discovered kernel improvement is recorded in
  [noztr-feedback-log.md](./noztr-feedback-log.md)
- `handoff.md` marks `NIP-29` progress and the next execution step

## Accepted Slice

Implemented and reviewed on 2026-03-15:
- `src/workflows/group_session.zig`
- `workflows.GroupSession`
- one pinned group reference plus one validated relay URL
- explicit relay connect/auth/disconnect transitions over the existing substrate
- reduced fixed-capacity `GroupState` ownership with explicit `resetState()`
- typed acceptance of reducer-relevant `NIP-29` state kinds only
- wrong-group rejection before reducer mutation
- relay-host matching that accepts normalized and explicit-default-port reference hosts

Deferred to later `NIP-29` slices:
- canonical ordering helpers
- `previous`-reference validation against local relay history
- multi-relay and fork reconciliation
- durable store-backed sync
- join/leave/moderation publish flows

## Current Next Step

Treat this first group-session slice as the accepted floor for `NIP-29`, then follow the decision in
[nip29-next-slice-evaluation.md](./nip29-next-slice-evaluation.md):
- build the top-level `examples/` tree first
- defer broader `NIP-29` sync/store work until a dedicated packet answers transcript, history, and
  store seam questions explicitly
