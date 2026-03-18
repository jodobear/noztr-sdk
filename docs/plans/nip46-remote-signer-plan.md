---
title: Noztr SDK NIP-46 Remote Signer Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 46
read_when:
  - refining_nip46
  - auditing_remote_signer
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings: []
---

# Noztr SDK NIP-46 Remote Signer Plan

Dedicated execution packet for the accepted `NIP-46` workflow slice in `noztr-sdk`.

Date: 2026-03-15

This document backfills the implemented `NIP-46` slice so it is closed against the tightened
implementation gate.

## Research Delta

Fresh recheck performed against:
- `docs/nips/46.md`
- `/workspace/projects/noztr/src/nip46_remote_signing.zig`
- `/workspace/projects/noztr/examples/remote_signing_recipe.zig`

Current kernel posture:
- `noztr` owns bunker URI parsing, request/response builders, response validation, and
  `sign_event` result parsing
- `noztr` owns `switch_relays` result parsing and `NIP-42` auth event validation
- the kernel recipe intentionally stops at deterministic protocol helpers and does not model relay
  transport/session orchestration

Resulting SDK implication:
- the SDK owns relay/session state, connection sequencing, response correlation, and failover
- protocol validation must remain in `noztr`

## Scope Card

Target slice:
- step-driven remote signer session over one active relay at a time

Target caller persona:
- client, signer, and service authors who control transport and want a reusable `NIP-46` workflow
  core without hidden runtime policy

Public entrypoints for this slice:
- `noztr_sdk.workflows.RemoteSignerSession`
- `noztr_sdk.workflows.RemoteSignerError`
- `noztr_sdk.workflows.RemoteSignerOutboundRequest`
- `noztr_sdk.workflows.RemoteSignerResponseOutcome`

Explicit non-goals for this slice:
- websocket runtime ownership
- timeout or retry policy above explicit state transitions
- encryption/decryption helper coverage beyond the accepted empty-method subset
- broad client facade work

## Kernel Inventory

`noztr` exports that remain authoritative:
- `noztr.nip46_remote_signing.uri_parse(...)`
- `noztr.nip46_remote_signing.request_build_connect(...)`
- `noztr.nip46_remote_signing.request_build_empty(...)`
- `noztr.nip46_remote_signing.request_build_sign_event(...)`
- `noztr.nip46_remote_signing.message_parse_json(...)`
- `noztr.nip46_remote_signing.response_validate(...)`
- `noztr.nip46_remote_signing.response_result_connect(...)`
- `noztr.nip46_remote_signing.response_result_get_public_key(...)`
- `noztr.nip46_remote_signing.response_result_sign_event(...)`
- `noztr.nip46_remote_signing.response_result_switch_relays(...)`
- `noztr.nip42_auth`
- `noztr.nip01_event.event_verify(...)`

Current kernel recipe reference:
- `/workspace/projects/noztr/examples/remote_signing_recipe.zig`

SDK-owned orchestration for this slice:
- relay pool and current-relay state
- connect/auth/disconnect transitions
- request correlation and bounded pending table
- failover after disconnect or `switch_relays`

## Boundary Answers

### Remote signer session

Why is this not already a `noztr` concern?
- it sequences network relay state, pending requests, auth gating, and failover above the protocol
  kernel

Why is this not application code above `noztr-sdk`?
- multiple apps need the same bounded signer-session core and should not all rebuild correlation and
  transport-state logic

Why is this the simplest useful SDK layer?
- it gives one explicit `NIP-46` session without hiding the caller’s transport decisions

## Example-First Design

Target example shape:
1. caller builds a session from a bunker URI
2. caller marks a relay connected
3. caller begins `connect`, forwards the outbound request, and accepts the response
4. caller handles optional relay auth explicitly
5. caller begins later requests, handles a disconnect, and either reconnects or fails over cleanly

Minimal example goal:
- "connect to a bunker, survive one relay disconnect, and continue on the next relay"

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- only validated `NIP-46` responses are accepted
- `sign_event` success requires full signed-event verification
- requests are blocked while relay auth is required
- disconnect clears signer-session connectivity and abandons in-flight pending requests so failover
  is still possible
- stale or malformed responses must not leak pending slots

Proven by `noztr`:
- protocol parsing, response validation, and `sign_event` result parsing

Proven by `noztr-sdk`:
- request/response correlation
- relay/session gating
- disconnect cleanup and failover readiness

Current accepted assumption gaps:
- no timeout clock or retry scheduler is built into this slice; callers decide when to declare a
  disconnect and call the explicit disconnect transition

## Seam Contract Audit

Relay/session seam requirements:
- caller must be able to report relay connected, auth challenge, auth success, and disconnect
- caller forwards raw response JSON into the session

Current seam status:
- the session now exposes explicit transitions for connect, auth, disconnect, and relay advance
- no hidden retry or timeout policy exists in the seam

Accepted seam limit:
- timeout detection lives above the workflow and must trigger `noteCurrentRelayDisconnected()`

## State-Machine Table

Session-level states:
- relay disconnected, signer disconnected
- relay connected, signer disconnected
- relay auth required, signer disconnected
- relay connected, signer connected

Valid transitions:
- disconnected -> relay connected via `markCurrentRelayConnected()`
- relay connected -> auth required via `noteCurrentRelayAuthChallenge(...)`
- auth required -> relay connected via `acceptCurrentRelayAuthEventJson(...)`
- relay connected + signer disconnected -> signer connected via successful `connect`
- any active state -> disconnected via `noteCurrentRelayDisconnected()`
- signer connected -> signer disconnected via `advanceRelay()` or successful `switch_relays`

Reset rules:
- disconnect clears pending requests and signer-connected state
- relay advance clears signer-connected state
- `switch_relays` replacement clears signer-connected state and replaces the relay pool

## Test Matrix

Required tests:
- connect happy path with secret echo
- secret mismatch and missing secret echo rejection
- request/response id correlation
- auth gating and recovery
- invalid auth event keeps relay blocked
- invalid `switch_relays` response keeps prior state
- same-relay disconnect blocks requests until reconnection
- disconnect with in-flight request clears pending state and allows failover
- malformed, oversized, and invalidly signed `sign_event` responses clear pending slots
- oversized signer error text clears pending state

## Acceptance Checks

This `NIP-46` slice is not closed until:
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` is rechecked
- handoff records residual limits and next execution slice

## Accepted Slice

Implemented and re-audited on 2026-03-15:
- `src/workflows/remote_signer.zig`
- full `sign_event` verification
- explicit disconnect transition
- disconnect cleanup for in-flight pending requests
- malformed oversized-response cleanup

Deferred to later `NIP-46` slices:
- timeout/retry policy
- broader method coverage
- higher-level client composition
