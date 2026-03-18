---
title: Noztr SDK NIP-46 Method Coverage Refinement
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 46
phase: refinement
posture:
  - product
  - zig-native
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP46-001
  - Z-WORKFLOWS-001
read_when:
  - refining_nip46
  - broadening_remote_signer_workflow
---

# Noztr SDK NIP-46 Method Coverage Refinement

Date: 2026-03-15

This packet covers the next accepted `NIP-46` refinement slice: broadening the public remote signer
workflow from event-signing-only plus utility methods into the current kernel-supported
pubkey-plus-text method family.

## Scope Card

Target workflow slice:
- broaden `RemoteSignerSession` to support the current kernel-owned `nip04_encrypt`,
  `nip04_decrypt`, `nip44_encrypt`, and `nip44_decrypt` methods

Target caller persona:
- app authors who already manage their own relay transport and need a reusable remote signer
  workflow that covers both event signing and the current DM-style encrypt/decrypt request family

Public entrypoints to add or change:
- add a public `RemoteSignerPubkeyTextRequest` alias
- add four `RemoteSignerSession.begin...` request builders for the pubkey-plus-text methods
- extend `RemoteSignerResponseOutcome` with a typed text payload outcome for those methods
- update the public recipe surface accordingly

Explicit non-goals for this slice:
- timeout or retry policy
- new relay/session runtime behavior
- buffer-shape or wrapper-surface shaping for `RemoteSignerSession`
- higher-level signer facade work

## Kernel Inventory

`noztr` remains authoritative for:
- `noztr.nip46_remote_signing.PubkeyTextRequest`
- `noztr.nip46_remote_signing.request_build_pubkey_text(...)`
- `noztr.nip46_remote_signing.response_validate(...)`
- common text-response validation for the four pubkey-plus-text methods

SDK-owned work in this slice:
- session gating before those requests can be built
- request/response correlation for those methods
- typed exposure of the response payload at the workflow boundary

Kernel recipe reference:
- `/workspace/projects/noztr/examples/remote_signing_recipe.zig`

## Boundary Answers

Why is this not already a `noztr` concern?
- the kernel already owns the exact request/response contracts; this slice is only exposing those
  existing method families through the SDK session workflow and its response correlation

Why is this not app code above `noztr-sdk`?
- otherwise every app using remote signers would have to duplicate the same request-builder,
  session-gating, and pending-correlation logic for the same common method family

Why is this the simplest useful SDK layer?
- it broadens the existing session to the current kernel-supported method set without inventing a
  second higher-level runtime abstraction

## Example-First Design

Target example shape:
1. connect to a bunker
2. request `nip44_encrypt` for a peer pubkey plus plaintext
3. accept the remote signer response as a typed text outcome
4. request `nip44_decrypt` and observe the paired text result

Minimal example goal:
- teach the broader remote-signer workflow surface without hiding the explicit transport/session
  stepping already accepted for this slice

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- pubkey-plus-text requests are blocked until the relay is ready and the signer session is connected
- only validated text responses are accepted for those methods
- response correlation works identically to the existing `NIP-46` request family
- malformed or mismatched pubkey-plus-text responses clear the matched pending slot

Proven by `noztr`:
- request-family validation
- text-response contract validation for those methods

Proven by `noztr-sdk`:
- session gating
- pending correlation
- typed workflow outcome for the returned text

Accepted assumption gaps:
- the returned text is method-appropriate because the kernel validates the result shape only as a
  text payload; method-specific semantic meaning above that remains an app concern

## Seam Contract Audit

Required seam semantics:
- explicit relay connected/auth/disconnect transitions
- caller forwards raw response JSON

Current seam status:
- sufficient; no seam widening is required for this slice

Scope-narrowing note:
- this slice is intentionally not changing timeout, retry, or buffering posture

## State-Machine Notes

This slice does not add new session states.

It reuses the accepted `NIP-46` state machine:
- requests still require relay ready plus signer connected
- disconnect still clears pending requests
- auth-required still blocks request creation

Additional method-family rule:
- the four pubkey-plus-text methods behave exactly like other connected-session requests for
  gating, pending registration, and response cleanup

## Test Matrix

Required tests:
- build and accept `nip04_encrypt` text response
- build and accept `nip44_decrypt` text response
- requests for these methods fail while signer session is disconnected
- malformed response for a pubkey-plus-text method clears the pending slot
- signer-declared error for a pubkey-plus-text method clears the pending slot and records the
  signer error
- recipe coverage updated to show at least one of the new methods end to end

## Acceptance Checks

This slice does not close until:
- `zig build`
- `zig build test --summary all`
- `/workspace/projects/noztr` compatibility is rechecked
- `A-NIP46-001` and `Z-WORKFLOWS-001` are rerun and updated explicitly
- `examples/README.md`, `handoff.md`, and discovery docs reflect the broader public workflow

## Closeout

Accepted on 2026-03-15:
- `RemoteSignerSession` now exposes the current kernel-supported `nip04_*` and `nip44_*`
  pubkey-plus-text method family
- `RemoteSignerResponseOutcome` now carries a typed text payload outcome for those methods
- `examples/remote_signer_recipe.zig` now teaches one of those methods on the public workflow
  surface
- `A-NIP46-001` is resolved
- `Z-WORKFLOWS-001` remains open only for `NIP-17`

Follow-on refinement accepted on 2026-03-16:
- `docs/plans/nip46-ergonomic-surface-plan.md` reshaped the public request-building surface around
  `RemoteSignerRequestContext`
- this did not broaden method coverage further; it only improved the Zig-native request-building
  shape for the already accepted method family

Follow-on example cleanup accepted on 2026-03-18:
- `docs/plans/nip46-example-cleanup-plan.md` tightened the remote-signer recipe so it teaches the
  SDK workflow path first and keeps repetitive response JSON wiring in one small local helper
