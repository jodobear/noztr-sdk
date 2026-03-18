---
title: Noztr SDK NIP-39 Identity Verifier Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 39
read_when:
  - refining_nip39
  - auditing_identity_verifier
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings: []
---

# Noztr SDK NIP-39 Identity Verifier Plan

Dedicated execution packet for the first `NIP-39` workflow slice in `noztr-sdk`.

Date: 2026-03-15

This plan records the accepted first `NIP-39` slice. Its original loop context now lives under
`docs/archive/plans/`.

Follow-on profile broadening for this slice now lives in
[nip39-profile-workflow-plan.md](./nip39-profile-workflow-plan.md).

Follow-on provider-detail broadening for this slice now lives in
[nip39-provider-details-plan.md](./nip39-provider-details-plan.md).

Follow-on cache/store broadening for this slice now lives in
[nip39-cache-plan.md](./nip39-cache-plan.md).

Follow-on store/discovery broadening for this slice now lives in
[nip39-store-discovery-plan.md](./nip39-store-discovery-plan.md).

Follow-on remembered-profile discovery broadening for this slice now lives in
[nip39-remembered-discovery-plan.md](./nip39-remembered-discovery-plan.md).

Follow-on remembered-discovery freshness broadening for this slice now lives in
[nip39-discovery-freshness-plan.md](./nip39-discovery-freshness-plan.md).

Follow-on explicit preferred remembered-profile selection for this slice now lives in
[nip39-preferred-selection-plan.md](./nip39-preferred-selection-plan.md).

Follow-on remembered runtime-policy inspection for this slice now lives in
[nip39-runtime-policy-plan.md](./nip39-runtime-policy-plan.md).

## Research Delta

Fresh recheck performed against:
- `docs/nips/39.md`
- `/workspace/projects/noztr/src/nip39_external_identities.zig`
- `/workspace/projects/noztr/examples/nip39_example.zig`
- `/workspace/projects/noztr/examples/identity_proof_recipe.zig`

Current kernel posture:
- `noztr` already owns ordered claim extraction from kind-10011 events
- `noztr` already owns canonical proof URL derivation
- `noztr` already owns canonical expected proof text generation
- current `noztr` examples intentionally stop at pure deterministic helpers and do not perform live
  provider fetches

Resulting SDK implication:
- the first `noztr-sdk` slice should stay networked and orchestration-only
- provider fetch and verification classification belong in the SDK
- extraction, URL derivation, and expected-text construction must continue to come from `noztr`

## Scope Card

Target slice:
- stateless provider verification flow for one validated `NIP-39` claim

Target caller persona:
- client, bot, service, and moderation-tool authors who need a reusable external-identity
  verification step without rebuilding deterministic proof URL and expected-text logic

Public entrypoints for this slice:
- `noztr_sdk.workflows.IdentityVerifier`
- `noztr_sdk.workflows.IdentityVerifierError`
- `noztr_sdk.workflows.IdentityVerificationStorage`
- `noztr_sdk.workflows.IdentityVerificationRequest`
- `noztr_sdk.workflows.IdentityVerificationOutcome`
- `noztr_sdk.workflows.IdentityVerificationMatch`

Explicit non-goals for this slice:
- identity-event sync or caching
- batch verification over full profiles
- provider-specific HTML parsing beyond deterministic expected-text containment
- retry policies beyond explicit fetch classification
- store integration
- broad identity management UX

## Kernel Inventory

`noztr` exports that must remain authoritative:
- `noztr.nip39_external_identities.IdentityClaim`
- `noztr.nip39_external_identities.identity_claims_extract(...)`
- `noztr.nip39_external_identities.identity_claim_build_proof_url(...)`
- `noztr.nip39_external_identities.identity_claim_build_expected_text(...)`

Current kernel recipe references:
- `/workspace/projects/noztr/examples/nip39_example.zig`
- `/workspace/projects/noztr/examples/identity_proof_recipe.zig`

SDK-owned orchestration for this slice:
- HTTP fetch of the proof document
- classification of fetch failures versus proof mismatches
- caller-facing verification result surface over existing explicit transport seams

## Boundary Answers

### Identity verifier

Why is this not already a `noztr` concern?
- live provider fetches and result classification are network workflow behavior, not deterministic
  protocol logic

Why is this not application code above `noztr-sdk`?
- multiple apps and services need the same narrow verification step and should not all rebuild it
  from scratch

Why is this the simplest useful SDK layer?
- it converts the kernel’s deterministic claim helpers into one reusable verification action
  without hiding policy or introducing storage/runtime complexity

### Verification outcome modeling

Why is this not already a `noztr` concern?
- fetch failures and mismatch classification depend on transport behavior outside the kernel

Why is this not application code above `noztr-sdk`?
- callers should receive one typed result contract for proof verification instead of custom
  transport-error branching at every call site

Why is this the simplest useful SDK layer?
- it makes verification explicit while keeping retry, cache, and trust policy out of this first
  slice

## Example-First Design

Target example shape:
1. caller constructs a kernel `IdentityClaim`
2. caller passes a `HttpClient` plus one `IdentityVerificationRequest` into
   `IdentityVerifier.verify(...)`
3. the verifier builds the canonical proof URL and expected text using `noztr`
4. the verifier fetches the proof document through the explicit transport seam
5. the caller receives `.verified`, `.mismatch`, or `.fetch_failed`

Minimal example goal:
- "verify one GitHub proof with a fake HTTP client and inspect the canonical proof URL in the
  result"

## API Sketch

Public workflow shape for the first slice:
- `IdentityVerifier.verify(http_client, request) !IdentityVerificationOutcome`
- `IdentityVerificationRequest` carries `claim`, `pubkey`, and caller-owned
  `IdentityVerificationStorage`

Expected result modeling:
- `.verified` with the canonical proof URL and expected proof text
- `.mismatch` with the canonical proof URL and expected proof text
- `.fetch_failed` with the underlying `HttpError` plus the canonical proof URL and expected proof
  text

Internal-only for this slice:
- any helper that matches body text or composes the HTTP request

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- proof URLs and expected proof text come from `noztr`
- unsupported provider shapes are not silently treated as verified
- fetch failures, mismatches, and verified results are separated cleanly

Proven by `noztr`:
- claim validation
- proof URL derivation
- expected proof text derivation

Proven by `noztr-sdk`:
- network fetch orchestration and result classification for the supported first-slice providers

Current accepted proof gap:
- Telegram is intentionally unsupported in this slice because generic containment checks do not
  prove the claim’s Telegram identity binding strongly enough

## Seam Contract Audit

HTTP seam requirements:
- caller must supply a body for the canonical proof URL or a typed fetch error

Current seam status:
- the seam is sufficient for fetch classification in this first stateless slice

Accepted seam limit:
- this slice does not yet model redirect policy or provider-specific DOM parsing

## Test Matrix

Required tests for Gate `G3`:
- happy-path GitHub verification
- proof body mismatch classification
- invalid claim propagation from `noztr`
- HTTP fetch failure classification
- unsupported Telegram provider rejection
- parity check that returned proof URL and expected proof text match current `noztr`
- current public root exports `workflows` plus the narrow `transport` seam only

Deferred tests for later `NIP-39` slices:
- batch verification from extracted profile claims
- cache hit/miss behavior
- provider-specific DOM or response parsing beyond the current deterministic claim adapters

## Acceptance Checks

This first `NIP-39` slice is not done until:
- the verifier lands on the explicit public `noztr_sdk.transport` seam without broadening the root
  beyond `workflows` plus that narrow transport namespace
- all required tests from this plan exist
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` is rechecked after the SDK slice lands
- any newly discovered kernel improvement is recorded in
  [noztr-feedback-log.md](./noztr-feedback-log.md)
- `handoff.md` marks `NIP-39` progress and the next sequential NIP

## Accepted Slice

Implemented on 2026-03-15:
- `src/workflows/identity_verifier.zig`
- `workflows.IdentityVerifier`
- `workflows.IdentityVerificationStorage`
- `workflows.IdentityVerificationRequest`
- explicit verification of one kernel `IdentityClaim` through the narrow public
  `noztr_sdk.transport.HttpClient` seam
- typed `.verified`, `.mismatch`, and `.fetch_failed` outcomes
- canonical proof URL and expected proof text returned in the verification result
- explicit Telegram rejection until provider-specific verification exists
- public recipe coverage in `examples/nip39_verification_recipe.zig`

Refined on 2026-03-16:
- the public verifier surface now uses `IdentityVerificationRequest` and caller-owned
  `IdentityVerificationStorage` instead of three raw temporary buffer parameters
- the recipe now teaches the wrapper shape directly
- `IdentityVerifier` now also exposes `verifyProfile(...)` with caller-owned
  `IdentityProfileVerificationStorage`
- the workflow now supports kind-10011 claim extraction and per-claim batch verification
- the recipe now teaches one full identity event verified over the public HTTP seam
- verified claims now expose provider-shaped details through
  `IdentityClaimVerification.providerDetails(...)`
- `IdentityProfileVerificationSummary.verifiedClaims(...)` now exposes the verified subset without
  forcing callers to rescan the whole result set
- the recipe now teaches provider-detail inspection after profile verification
- `IdentityVerifier.verifyProfileCachedAndRemember(...)` now exposes one explicit verify-and-store
  helper above the cache plus profile-store seams
- `IdentityVerifier.discoverStoredProfileEntries(...)` now returns hydrated stored profile records
  directly for provider-plus-identity discovery
- `IdentityVerifier.getLatestStoredProfile(...)` now exposes one explicit newest-match helper for
  the common remembered-identity lookup path
- the recipe now teaches verify, remember, hydrated discovery, and cached replay on the same
  explicit public surface

Deferred to later `NIP-39` slices:
- hidden background discovery or sync
- durable external store strategy above the current explicit store seam
- retry and trust-policy layers

## Current Next Step

Treat the remembered-profile workflow as the current accepted `NIP-39` floor, with explicit cache,
store, hydrated discovery, and newest-match lookup now available over that surface. Future work, if
needed, should target hidden-background discovery or a durable external store strategy rather than
repeat the current remembered-profile path.
