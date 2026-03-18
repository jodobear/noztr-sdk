---
title: Noztr SDK NIP-03 OpenTimestamps Verifier Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 3
read_when:
  - refining_nip03
  - auditing_opentimestamps_verifier
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings: []
---

# Noztr SDK NIP-03 OpenTimestamps Verifier Plan

Dedicated execution packet for the first `NIP-03` workflow slice in `noztr-sdk`.

Date: 2026-03-15

This plan records the accepted first `NIP-03` slice. Its original loop context now lives under
`docs/archive/plans/`.

Follow-on detached proof retrieval broadening for this slice now lives in
[nip03-remote-proof-plan.md](./nip03-remote-proof-plan.md).

Follow-on proof-store broadening for this slice now lives in
[nip03-proof-store-plan.md](./nip03-proof-store-plan.md).

Follow-on remembered-verification broadening for this slice now lives in
[nip03-remembered-verification-plan.md](./nip03-remembered-verification-plan.md).

Follow-on remembered runtime-policy inspection for this slice now lives in
[nip03-runtime-policy-plan.md](./nip03-runtime-policy-plan.md).

## Research Delta

Fresh recheck performed against:
- `docs/nips/03.md`
- `/workspace/projects/noztr/src/nip03_opentimestamps.zig`
- `/workspace/projects/noztr/examples/nip03_example.zig`
- `/workspace/projects/noztr/examples/nip03_verification_recipe.zig`

Current kernel posture:
- `noztr` already owns bounded attestation extraction from kind-1040 events
- `noztr` already owns target-reference validation
- `noztr` already owns the local OpenTimestamps proof floor, including Bitcoin-attestation
  requirements
- the kernel recipe set now includes one end-to-end local verification flow, but still does not
  provide a higher-level SDK verifier workflow

Resulting SDK implication:
- the first `noztr-sdk` slice should stay local and orchestration-only
- it should compose the existing kernel helpers into one typed verification action
- remote Bitcoin verification and proof retrieval should be deferred until a real client seam is
  justified

## Scope Card

Target slice:
- stateless local verification flow for one `NIP-03` attestation event against one target event

Target caller persona:
- client, relay, signer, and service authors who need a reusable local verification step for
  `NIP-03` attestations without reconstructing the proof floor from raw kernel helpers

Public entrypoints for this slice:
- `noztr_sdk.workflows.OpenTimestampsVerifier`
- `noztr_sdk.workflows.OpenTimestampsVerifierError`
- `noztr_sdk.workflows.OpenTimestampsVerificationOutcome`
- `noztr_sdk.workflows.OpenTimestampsVerification`

Explicit non-goals for this slice:
- remote proof retrieval
- Bitcoin RPC or esplora integration
- caching or store integration
- batch verification over many attestations
- attestation publishing helpers
- hidden network policy or retry logic

## Kernel Inventory

`noztr` exports that must remain authoritative:
- `noztr.nip03_opentimestamps.OpenTimestampsAttestation`
- `noztr.nip03_opentimestamps.OpenTimestampsError`
- `noztr.nip03_opentimestamps.opentimestamps_extract(...)`
- `noztr.nip03_opentimestamps.opentimestamps_validate_target_reference(...)`
- `noztr.nip03_opentimestamps.opentimestamps_validate_local_proof(...)`

Current kernel recipe references:
- `/workspace/projects/noztr/examples/nip03_example.zig`
- `/workspace/projects/noztr/examples/nip03_verification_recipe.zig`

SDK-owned orchestration for this slice:
- one caller-facing verifier surface that sequences extract, target-reference validation, and local
  proof validation
- typed classification of target mismatches and invalid local proofs after successful extraction

## Boundary Answers

### OpenTimestamps verifier

Why is this not already a `noztr` concern?
- the kernel already provides the deterministic proof checks; the missing piece is the reusable
  workflow that sequences them into one app-facing verification action

Why is this not application code above `noztr-sdk`?
- multiple downstream apps will need the same extract-plus-verify flow and should not all rebuild
  the same typed branching around kernel helpers

Why is this the simplest useful SDK layer?
- it adds one narrow verification step without dragging in network clients, stores, or policy

### Outcome modeling

Why is this not already a `noztr` concern?
- the kernel exposes exact helper failures; classifying the verification workflow result is an SDK
  concern above those deterministic primitives

Why is this not application code above `noztr-sdk`?
- callers should receive one stable result contract for the common verification branches instead of
  repeating the same error branching at each call site

Why is this the simplest useful SDK layer?
- it keeps malformed attestation inputs as kernel errors while classifying only the expected local
  verification outcomes

## Example-First Design

Target example shape:
1. caller has a target event and a parsed kind-1040 attestation event
2. caller provides a bounded proof buffer
3. `OpenTimestampsVerifier.verifyLocal(...)` extracts the attestation using `noztr`
4. the verifier validates target reference and the local Bitcoin-attested proof floor
5. the caller receives `.verified`, `.target_mismatch`, or `.invalid_local_proof`

Minimal example goal:
- "verify one local `NIP-03` attestation from a parsed event pair and inspect the extracted target
  metadata"

## API Sketch

Public workflow shape for the first slice:
- `OpenTimestampsVerifier.verifyLocal(target_event, attestation_event, proof_buffer)
  !OpenTimestampsVerificationOutcome`

Expected result modeling:
- `.verified` with extracted attestation metadata and the decoded proof bytes
- `.target_mismatch` with extracted attestation metadata and the decoded proof bytes
- `.invalid_local_proof` with extracted attestation metadata, the decoded proof bytes, and the
  narrowed local-proof failure cause

Internal-only for this slice:
- test-only proof fixture builders
- local helpers that narrow kernel proof-validation errors into the SDK outcome shape

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- extraction, target-reference validation, and local-proof validation stay kernel-owned
- caller target mismatch is distinguished from an internally inconsistent attestation proof
- the slice stays local-only and does not imply networked Bitcoin verification

Proven by `noztr`:
- attestation extraction
- target-reference validation
- local proof floor validation

Proven by `noztr-sdk`:
- sequencing and caller-facing outcome classification

Current accepted proof gap:
- this slice proves only the local proof floor, not remote Bitcoin inclusion or network freshness

## Seam Contract Audit

Current seam status:
- this slice is local-only and requires no transport seam

Accepted seam limit:
- remote proof retrieval and Bitcoin client integration are deferred intentionally

## Test Matrix

Required tests for Gate `G3`:
- happy-path local verification with one Bitcoin attestation
- target mismatch classification
- invalid local proof classification for a proof missing a Bitcoin attestation
- invalid attestation classification when the proof digest disagrees with the attestation target
- malformed attestation propagation from `noztr`
- parity check that extracted target metadata still comes from current `noztr`
- current public root exports `workflows` plus the narrow `transport` seam only

Deferred tests for later `NIP-03` slices:
- remote proof retrieval
- transient network failure classification
- Bitcoin-client verification beyond the local proof floor
- store-backed proof caching

## Acceptance Checks

This first `NIP-03` slice is not done until:
- the verifier lands without broadening the root surface beyond the current `workflows` plus narrow
  `transport` posture
- all required tests from this plan exist
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` is rechecked after the SDK slice lands
- any newly discovered kernel improvement is recorded in
  [noztr-feedback-log.md](./noztr-feedback-log.md)
- `handoff.md` marks `NIP-03` progress and the next sequential NIP

## Accepted Slice

Implemented on 2026-03-15:
- `src/workflows/opentimestamps_verifier.zig`
- `workflows.OpenTimestampsVerifier`
- `workflows.OpenTimestampsVerifierError`
- `workflows.OpenTimestampsVerificationOutcome`
- one local verification flow that composes `opentimestamps_extract(...)`,
  `opentimestamps_validate_target_reference(...)`, and `opentimestamps_validate_local_proof(...)`
- typed `.verified`, `.target_mismatch`, `.invalid_attestation`, and `.invalid_local_proof`
  outcomes
- local proof fixtures that mirror the current `noztr` proof floor in SDK tests

Deferred to later `NIP-03` slices:
- remote proof retrieval
- transient fetch classification
- Bitcoin client integration beyond the current local proof floor
- attestation publish helpers

## Current Next Step

Treat this first verifier slice as the accepted floor for `NIP-03`, then move to `NIP-05` per the
strict meta loop.
