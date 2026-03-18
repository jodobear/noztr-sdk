---
title: Noztr SDK NIP-05 Resolver Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 5
read_when:
  - refining_nip05
  - auditing_nip05
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings: []
---

# Noztr SDK NIP-05 Resolver Plan

Dedicated execution packet for the first `NIP-05` workflow slice in `noztr-sdk`.

Date: 2026-03-15

This plan records the accepted first `NIP-05` slice. Its original loop context now lives under
`docs/archive/plans/`.

## Research Delta

Fresh recheck performed against:
- `docs/nips/05.md`
- `/workspace/projects/noztr/src/nip05_identity.zig`
- `/workspace/projects/noztr/examples/nip05_example.zig`
- `/workspace/projects/noztr/examples/discovery_recipe.zig`

Current kernel posture:
- `noztr` already owns canonical NIP-05 address parsing and formatting
- `noztr` already owns canonical well-known URL composition
- `noztr` already owns `nostr.json` profile parsing and verification, including optional `relays`
  and `nip46` relay maps
- current `noztr` examples intentionally stop at deterministic parsing and recipe composition, not
  HTTP fetch workflow

Resulting SDK implication:
- the first `noztr-sdk` slice should stay networked and orchestration-only
- it should compose fetch, parse, and optional pubkey verification over explicit HTTP seams
- caching should be deferred until the fetch/verify shape settles

## Scope Card

Target slice:
- stateless fetch/parse/verify workflow for one NIP-05 address

Target caller persona:
- client, bot, signer, and service authors who need a reusable NIP-05 lookup step without
  rebuilding HTTP fetch, typed outcomes, and parsed relay extraction around the kernel helpers

Public entrypoints for this slice:
- `noztr_sdk.workflows.Nip05Resolver`
- `noztr_sdk.workflows.Nip05ResolverError`
- `noztr_sdk.workflows.Nip05LookupStorage`
- `noztr_sdk.workflows.Nip05LookupRequest`
- `noztr_sdk.workflows.Nip05VerificationRequest`
- `noztr_sdk.workflows.Nip05LookupOutcome`
- `noztr_sdk.workflows.Nip05VerificationOutcome`
- `noztr_sdk.workflows.Nip05Resolution`

Explicit non-goals for this slice:
- durable caching
- redirect or retry policy beyond explicit fetch-failure classification
- kind-0 metadata fetch or reverse-profile discovery
- trust scoring or identity UX
- automatic `NIP-46` discovery composition

## Kernel Inventory

`noztr` exports that must remain authoritative:
- `noztr.nip05_identity.Address`
- `noztr.nip05_identity.Profile`
- `noztr.nip05_identity.Nip05Error`
- `noztr.nip05_identity.address_parse(...)`
- `noztr.nip05_identity.address_compose_well_known_url(...)`
- `noztr.nip05_identity.profile_parse_json(...)`
- `noztr.nip05_identity.profile_verify_json(...)`

Current kernel recipe references:
- `/workspace/projects/noztr/examples/nip05_example.zig`
- `/workspace/projects/noztr/examples/discovery_recipe.zig`

SDK-owned orchestration for this slice:
- HTTP fetch of `/.well-known/nostr.json`
- typed classification of fetch failure versus verification mismatch
- caller-facing workflow entrypoints that return parsed `relays` and `nip46_relays`

## Boundary Answers

### NIP-05 resolver

Why is this not already a `noztr` concern?
- live HTTP fetch and result classification are workflow behavior above the deterministic address and
  document helpers

Why is this not application code above `noztr-sdk`?
- many downstream apps need the same narrow NIP-05 lookup flow and should not all rebuild the same
  fetch/parse/verify branch structure

Why is this the simplest useful SDK layer?
- it turns the kernel’s deterministic helpers into one explicit reusable lookup action without
  adding caching or hidden policy

### Outcome modeling

Why is this not already a `noztr` concern?
- fetch failures and mismatch classification depend on transport behavior outside the kernel

Why is this not application code above `noztr-sdk`?
- callers should receive one typed contract for resolution and verification instead of branching over
  raw transport and parse errors in every codebase

Why is this the simplest useful SDK layer?
- it keeps malformed addresses/documents as kernel errors while classifying only the common network
  and verification outcomes

## Example-First Design

Target example shape:
1. caller passes an explicit `HttpClient` plus one `Nip05LookupRequest` or
   `Nip05VerificationRequest`
2. the resolver parses the address and composes the canonical well-known URL using `noztr`
3. the resolver fetches the document over the explicit transport seam
4. the resolver returns the parsed profile plus `relays` and `nip46_relays`
5. the caller optionally verifies the result against an expected pubkey

Minimal example goal:
- "resolve `alice@example.com`, inspect the canonical lookup URL, and get parsed relays and bunker
  relays from one typed SDK result"

## API Sketch

Public workflow shape for the first slice:
- `Nip05Resolver.lookup(http_client, request) !Nip05LookupOutcome`
- `Nip05Resolver.verify(http_client, request) !Nip05VerificationOutcome`
- caller-owned `Nip05LookupStorage` carries the bounded lookup/body buffers
- the request type keeps the scratch allocator explicit because parsed profile lifetimes still
  depend on caller-owned allocation

Expected result modeling:
- `lookup(...)` returns `.resolved` or `.fetch_failed`
- `verify(...)` returns `.verified`, `.mismatch`, or `.fetch_failed`
- both paths surface the parsed kernel `Address`, canonical lookup URL, and parsed kernel `Profile`

Internal-only for this slice:
- the helper that performs the shared fetch/parse sequence

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- address parsing and lookup URL composition stay kernel-owned
- verification mismatch semantics follow `noztr`’s `profile_verify_json(...)` behavior for the
  `names` mapping instead of being tightened accidentally by optional relay-map parsing
- verified results still require a full parsed profile because the SDK returns the parsed profile in
  the success outcome

Proven by `noztr`:
- address parsing
- lookup URL composition
- `names`-mapping verification semantics
- profile parsing

Proven by `noztr-sdk`:
- HTTP fetch orchestration
- typed fetch-failure and mismatch result modeling

Current accepted proof gap:
- redirect prohibition from `NIP-05` cannot yet be enforced by the current `HttpClient` seam

## Seam Contract Audit

HTTP seam requirements from `NIP-05`:
- fetchers must ignore redirects from `/.well-known/nostr.json`
- callers need a typed fetch failure when no document is available

Current seam status:
- fetch failure classification is supported
- redirect/final-URL policy is not exposed by the seam yet

Accepted seam limit for this first slice:
- this slice assumes the caller-supplied `HttpClient` already enforces a no-redirect policy or
  equivalent final-URL safety outside the resolver

## Test Matrix

Required tests for Gate `G3`:
- happy-path lookup returns parsed profile plus `relays` and `nip46_relays`
- happy-path verification returns `.verified`
- mismatched expected pubkey returns `.mismatch`
- mismatched expected pubkey still returns `.mismatch` when optional relay maps are malformed
- transport failure returns `.fetch_failed`
- malformed document propagates kernel errors
- current public root exports `workflows` plus the narrow `transport` seam only

Deferred tests for later `NIP-05` slices:
- cache hit/miss behavior
- redirect-policy enforcement
- reverse discovery via kind-0 metadata fetch
- higher-level `NIP-05` plus `NIP-46` composition examples

## Acceptance Checks

This first `NIP-05` slice is not done until:
- the resolver lands on the explicit public `noztr_sdk.transport` seam without broadening the root
  beyond `workflows` plus that narrow transport namespace
- all required tests from this plan exist
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` is rechecked after the SDK slice lands
- any newly discovered kernel improvement is recorded in
  [noztr-feedback-log.md](./noztr-feedback-log.md)
- `handoff.md` marks `NIP-05` progress and the next sequential NIP

## Current Next Step

The first fetch/parse/verify slice is implemented. Current follow-on work:
- keep the resolver on the explicit public `noztr_sdk.transport.HttpClient` seam
- preserve the written redirect-policy proof gap until the seam expands
- refine ergonomics or transport semantics in a later packet rather than broadening silently

Refined on 2026-03-16:
- the public resolver surface now uses `Nip05LookupRequest`, `Nip05VerificationRequest`, and
  caller-owned `Nip05LookupStorage`
- the recipe now teaches the wrapper shape directly instead of raw buffer choreography
