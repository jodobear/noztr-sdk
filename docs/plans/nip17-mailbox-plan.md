---
title: Noztr SDK NIP-17 Mailbox Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 17
read_when:
  - refining_nip17
  - auditing_mailbox
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings: []
---

# Noztr SDK NIP-17 Mailbox Plan

Dedicated execution packet for the first `NIP-17` workflow slice in `noztr-sdk`.

Date: 2026-03-15

This plan records the accepted first `NIP-17` slice. Its original loop context now lives under
`docs/archive/plans/`.

Follow-on outbound mailbox broadening for this slice now lives in
[nip17-outbound-mailbox-plan.md](./nip17-outbound-mailbox-plan.md).

Follow-on recipient-relay fanout broadening for this slice now lives in
[nip17-relay-fanout-plan.md](./nip17-relay-fanout-plan.md).

Follow-on sender-copy delivery broadening for this slice now lives in
[nip17-sender-copy-plan.md](./nip17-sender-copy-plan.md).

Follow-on file-message intake broadening for this slice now lives in
[nip17-file-intake-plan.md](./nip17-file-intake-plan.md).

Follow-on outbound file-message broadening for this slice now lives in
[nip17-file-send-plan.md](./nip17-file-send-plan.md).

Follow-on mailbox runtime broadening for this slice now lives in
[nip17-runtime-plan.md](./nip17-runtime-plan.md).

## Research Delta

Fresh recheck performed against:
- `/workspace/projects/noztr/src/nip17_private_messages.zig`
- `/workspace/projects/noztr/src/nip59_wrap.zig`
- `/workspace/projects/noztr/examples/nip17_example.zig`
- `/workspace/projects/noztr/examples/nip17_wrap_recipe.zig`
- `/workspace/projects/noztr/src/nostr_keys.zig`

Current kernel posture:
- `noztr` already owns the deterministic `NIP-17` parsing helpers
- `noztr` already owns staged `NIP-59` unwrap and cryptographic validation
- `noztr` now also exposes bounded key helpers through `noztr.nostr_keys`
- the kernel recipe set now covers both basic parsing and one full signed wrap-build transcript, but
  still stops short of mailbox-session orchestration

Resulting SDK implication:
- the first `noztr-sdk` slice should add mailbox-session orchestration only
- no protocol parsing, decrypt logic, or wrap validation should be reimplemented in the SDK

## Scope Card

Target slice:
- step-driven mailbox session core for one-recipient `NIP-17` inbox handling

Target caller persona:
- client or service authors who already control transport and want reusable mailbox relay/session
  state plus gift-wrap unwrap handling

Public entrypoints for this slice:
- `noztr_sdk.workflows.MailboxSession`
- `noztr_sdk.workflows.MailboxError`
- `noztr_sdk.workflows.MailboxMessageOutcome`

Explicit non-goals for this slice:
- websocket subscription runtime
- hidden polling loops
- durable inbox persistence
- file-message workflow coverage
- outbound message construction helpers
- a broad public `client` facade

## Kernel Inventory

`noztr` exports that must remain authoritative:
- `noztr.nip17_private_messages.nip17_relay_list_extract(...)`
- `noztr.nip17_private_messages.nip17_unwrap_message(...)`
- `noztr.nip01_event.event_parse_json(...)`
- `noztr.nip42_auth`
- `noztr.nip65_relays` through existing relay URL validation seams in `noztr-sdk`

Current kernel recipe reference:
- `/workspace/projects/noztr/examples/nip17_example.zig`
- `/workspace/projects/noztr/examples/nip17_wrap_recipe.zig`

SDK-owned orchestration for this slice:
- mailbox relay-list hydration into the existing relay pool
- current-relay stepping and auth/session handling
- duplicate wrap protection for a bounded in-memory mailbox session
- typed message intake over caller-supplied wrap-event JSON

## Boundary Answers

### Mailbox session state

Why is this not already a `noztr` concern?
- it combines relay selection, auth/session state, duplicate suppression, and message intake over
  multiple kernel helpers

Why is this not application code above `noztr-sdk`?
- multiple apps will need the same explicit mailbox-session core even when they differ on transport
  and persistence

Why is this the simplest useful SDK layer?
- it provides reusable mailbox control without freezing a broader runtime or hiding network policy

### Duplicate-wrap tracking

Why is this not already a `noztr` concern?
- replay suppression is session and workflow policy, not deterministic protocol parsing

Why is this not application code above `noztr-sdk`?
- mailbox consumers should not all have to rebuild the same bounded duplicate filter

Why is this the simplest useful SDK layer?
- it prevents accidental double-processing while keeping capacity and reset behavior explicit

## Example-First Design

Target example shape:
1. caller creates a `MailboxSession` with recipient private key material
2. caller hydrates relay URLs from a kind-10050 relay-list event
3. caller marks the current relay connected and handles auth explicitly if needed
4. caller passes one wrapped-event JSON payload into the mailbox session
5. caller receives a typed message outcome with parsed recipient metadata and the unwrapped rumor

Minimal example goal:
- "hydrate one mailbox relay, unwrap one private message, reject a replay of the same wrap"

## API Sketch

Public workflow shape for the first slice:
- `MailboxSession.init(recipient_private_key: *const [32]u8) MailboxSession`
- `MailboxSession.hydrateRelayListEventJson(event_json, scratch) !u8`
- `MailboxSession.markCurrentRelayConnected()`
- `MailboxSession.noteCurrentRelayAuthChallenge(challenge) !void`
- `MailboxSession.acceptCurrentRelayAuthEventJson(auth_event_json, now, window, scratch) !void`
- `MailboxSession.advanceRelay() ![]const u8`
- `MailboxSession.currentRelayUrl() ?[]const u8`
- `MailboxSession.currentRelayCanReceive() bool`
- `MailboxSession.acceptWrappedMessageJson(wrap_event_json, recipients_out, scratch) !MailboxMessageOutcome`

Expected result shape:
- message outcome returns the unwrapped rumor event and parsed `DmMessageInfo`
- returned slices borrow from caller-provided parse/scratch allocations

Internal-only for this slice:
- seen-wrap table representation
- any helper used only to parse relay-list events or recover stable session state

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- only valid kind-10050 relay-list events are hydrated
- relay-list hydration replaces stale relay state instead of appending
- wrapped-message intake is blocked while the current relay is disconnected or auth-gated
- duplicate wraps do not get processed twice
- same-relay transport loss can be represented explicitly

Proven by `noztr`:
- relay-list extraction
- gift-wrap unwrap and message validation
- recipient-pubkey derivation from a secret key for relay-list authorship checks

Proven by `noztr-sdk`:
- relay/session orchestration
- duplicate-wrap suppression
- relay-list replacement semantics
- same-relay disconnect handling

Current accepted proof gap:
- none in the relay-list authorship path; that check now stays on the kernel helper surface

## Seam Contract Audit

Relay/session seam requirements:
- caller must be able to report relay connected, auth challenge, auth success, and disconnect
- relay-list hydration must dedupe normalized-equivalent relay URLs

Current seam status:
- explicit connect/auth/disconnect/advance transitions exist
- relay URL normalization is handled by the internal pool seam

Accepted seam limit:
- this first slice still does not own websocket subscription or polling policy

## State-Machine Table

Mailbox relay states:
- disconnected
- connected
- auth required

Valid transitions:
- disconnected -> connected via `markCurrentRelayConnected()`
- connected -> auth required via `noteCurrentRelayAuthChallenge(...)`
- auth required -> connected via `acceptCurrentRelayAuthEventJson(...)`
- any current relay -> disconnected via `noteCurrentRelayDisconnected()`
- any relay -> next relay via `advanceRelay()`

Reset rules:
- relay-list hydration replaces the pool and resets the current index to zero
- relay disconnect clears receive-readiness for the current relay
- relay rotation preserves per-relay auth state already stored in the pool

## Test Matrix

Required tests for Gate `G3`:
- happy-path relay-list hydration and one wrapped-message unwrap
- malformed relay-list event JSON
- malformed relay-list tags
- invalid relay-list signatures
- relay-list authored by a different pubkey
- malformed wrapped-message payload
- duplicate wrapped-message rejection
- relay advance resets mailbox receive readiness
- auth-required relay blocks wrapped-message intake until auth succeeds
- same-relay disconnect blocks wrapped-message intake until reconnection
- auth gating survives relay rotation
- relay-list normalization deduplicates equivalent relay URLs
- seen-wrap table eviction when the duplicate table fills

Deferred tests for later `NIP-17` slices:
- file-message unwrap
- live subscription or polling transcripts
- durable inbox state

## Acceptance Checks

This first `NIP-17` slice is not done until:
- the mailbox workflow lands without broadening the root surface beyond the current `workflows`
  plus narrow `transport` posture
- all required tests from this plan exist
- `zig build`
- `zig build test --summary all`
- `/workspace/projects/noztr` is rechecked after the SDK slice lands
- any newly discovered kernel improvement is recorded in
  [noztr-feedback-log.md](./noztr-feedback-log.md)
- `handoff.md` marks `NIP-17` Gate `G2` and the current next implementation step

## Accepted Slice

Implemented on 2026-03-15:
- `src/workflows/mailbox.zig`
- `workflows.MailboxSession`
- relay-list hydration from kind-10050 events
- explicit relay connection/auth stepping over the existing substrate
- one wrapped-message intake path using `noztr.nip17_private_messages.nip17_unwrap_message(...)`
- bounded duplicate-wrap suppression plus eviction
- explicit same-relay disconnect transition

Deferred to later `NIP-17` slices:
- outbound message and gift-wrap construction
- transport-level polling or subscription orchestration

Refined on 2026-03-18:
- `MailboxSession` now also exposes `acceptWrappedFileMessageJson(...)`
- `MailboxSession` now also exposes `acceptWrappedEnvelopeJson(...)` so callers can classify direct
  messages vs file messages on one explicit intake path
- public mailbox workflow exports now include `MailboxFileMessageOutcome` and
  `MailboxEnvelopeOutcome`
- the mailbox recipe now teaches direct-message delivery plus file-message intake on the same
  public workflow surface
- durable mailbox persistence

## Current Next Step

Treat this first mailbox slice as the accepted floor for `NIP-17`, then decide whether to extend
`NIP-17` with outbound/file-message work now or move to `NIP-39` per the strict meta loop once all
review gates are closed.
