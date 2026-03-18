---
title: Noztr SDK Examples Tree Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - changing_examples
  - auditing_teaching_posture
depends_on:
  - docs/plans/implementation-quality-gate.md
target_findings: []
---

# Noztr SDK Examples Tree Plan

Dedicated execution packet for the first structured `noztr-sdk/examples/` lane.

Date: 2026-03-15

This plan records the accepted first structured SDK examples lane. The earlier next-slice
evaluation it came from now lives under `docs/archive/plans/`.

## Research Delta

Fresh recheck performed against:
- `/workspace/projects/noztr/examples/README.md`
- `/workspace/projects/noztr/examples/examples.zig`
- `/workspace/projects/noztr/examples/remote_signing_recipe.zig`
- `/workspace/projects/noztr/examples/nip17_wrap_recipe.zig`
- `/workspace/projects/noztr/examples/nip03_verification_recipe.zig`
- `/workspace/projects/noztr/examples/nip29_reducer_recipe.zig`
- `/workspace/projects/noztr/examples/nip29_adversarial_example.zig`

Current kernel posture:
- `noztr` examples are technical, direct, and recipe-oriented
- boundary-heavy kernel surfaces are taught with both valid recipes and adversarial examples
- `noztr` intentionally stops at deterministic protocol helpers and does not teach relay/session,
  store, or workflow orchestration

Resulting SDK implication:
- `noztr-sdk` examples should mirror the kernel recipe posture, but teach the workflow layer above
  it
- the first slice should stay on the currently stable public workflow surface
- examples must not teach internal substrate imports as if they were public SDK posture

## Structure Delta Versus Applesauce

Current applesauce advantages that `noztr-sdk` does not match yet:
- examples are part of a broader docs and discovery system rather than only a code tree
- examples have an explicit manifest-like indexing layer for navigation
- applesauce documents AI-agent usage directly and makes example/document lookup a first-class
  workflow

Current accepted `noztr-sdk` posture:
- keep the first SDK examples slice smaller and compile-verified
- compensate with a stricter examples README/catalog and explicit startup pointers
- defer search/indexing or richer docs-site work until the workflow surface grows further

## Scope Card

Target slice:
- top-level `examples/` tree for the stable public workflow surfaces that do not require internal
  transport or store imports

Target caller persona:
- Zig application authors evaluating `noztr-sdk` as the workflow layer above `noztr`

Explicit outputs for this slice:
- `examples/README.md`
- `examples/examples.zig`
- `examples/common.zig`
- one consumer smoke example
- recipe examples for:
  - remote signer
  - mailbox inbox
  - local OpenTimestamps verification
  - group session
- at least one adversarial example for a boundary-heavy SDK workflow
- build/test wiring so examples are verified by Zig

Explicit non-goals for this slice:
- exhaustive coverage of every implemented workflow
- live relay or live HTTP demos
- reference HTTP adapter design
- broader `NIP-29` sync/store behavior

## Kernel And SDK Inventory

Kernel recipe references for this slice:
- `remote_signing_recipe.zig`
- `nip17_wrap_recipe.zig`
- `nip03_verification_recipe.zig`
- `nip29_reducer_recipe.zig`
- `nip29_adversarial_example.zig`

Stable SDK workflow surfaces available now:
- `noztr_sdk.workflows.RemoteSignerSession`
- `noztr_sdk.workflows.MailboxSession`
- `noztr_sdk.workflows.IdentityVerifier`
- `noztr_sdk.workflows.OpenTimestampsVerifier`
- `noztr_sdk.workflows.Nip05Resolver`
- `noztr_sdk.workflows.GroupSession`
- `noztr_sdk.transport.HttpClient`

Originally deferred but now accepted after the HTTP-seam refinement:
- `noztr_sdk.workflows.IdentityVerifier`
- `noztr_sdk.workflows.Nip05Resolver`

Current teaching reason:
- the seam is now public and explicit through `noztr_sdk.transport`
- examples still stop short of teaching a live runtime adapter or redirect-policy enforcement

## Boundary Answers

### Examples tree

Why is this not already a `noztr` concern?
- these examples teach orchestration-heavy SDK workflows above the deterministic kernel boundary

Why is this not just application code above `noztr-sdk`?
- downstream consumers need one canonical example set that shows how the SDK layer is intended to
  be used before they invent their own patterns

Why is this the simplest useful SDK layer?
- the examples remain thin, technical recipes over the public workflow surface instead of adding
  more runtime or abstraction

## Example-First Design

Start-here order for this slice:
1. consumer smoke import
2. remote signer recipe
3. mailbox recipe
4. local OpenTimestamps verification recipe
5. group session recipe
6. one adversarial group-session example

Minimal caller promise:
- each example can be read as a small standalone recipe
- each example uses `noztr_sdk.workflows` plus `noztr` kernel helpers only
- each example demonstrates explicit control points rather than hidden runtime behavior
- each example should be discoverable from `examples/README.md` without requiring plan archaeology

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- examples must compile and run under Zig verification
- examples must stay on stable public SDK workflow surfaces
- examples must use `noztr` for protocol construction/validation instead of re-implementing kernel
  behavior locally
- examples must not imply support the SDK does not actually expose yet

Proven by `noztr`:
- deterministic fixture/event construction, signing, and protocol parsing helpers

Proven by `noztr-sdk`:
- the workflow APIs demonstrated by the examples

Current accepted proof gaps:
- the examples tree still does not teach a live HTTP runtime or redirect-aware `NIP-05` policy

## Seam Contract Audit

Relevant seams for this first slice:
- relay/session state for remote signer, mailbox, and group session
- local proof verification for OpenTimestamps

Current seam status:
- these workflows can be taught entirely through public workflow methods plus kernel fixtures

Deferred seam work:
- the public seam is now teachable through explicit local fake HTTP adapters
- a reference live adapter remains deferred until the repo accepts a broader HTTP runtime posture

## Example Authoring Rules

For this examples lane and later slices:
- prefer one narrow helper per concrete transcript shape over a generic helper that tries to cover
  many branches
- derive event pubkeys from signer secrets in one place for all signed fixtures
- add a short top-of-file comment when it materially improves “what does this teach?” readability
- keep examples on public SDK surfaces and call out any intentional `noztr` fixture dependency
- update the examples README/catalog in the same change as new example files

## Example Coverage Table

First-slice files must cover:
- valid remote signer flow
- valid mailbox relay-list hydration plus wrap intake
- valid local OpenTimestamps verification
- valid group session replay
- hostile or wrong-group `NIP-29` input rejection

## Test Matrix

Required checks for this slice:
- every example file compiles through one `examples/examples.zig` aggregate root
- examples are exercised by `zig build test --summary all`
- remote signer recipe shows connect plus one post-connect request
- mailbox recipe shows hydrate plus unwrap
- OpenTimestamps recipe shows verified local attestation
- group session recipe shows canonical replay into reduced state
- adversarial example shows explicit wrong-input rejection instead of silent state mutation

Deferred checks:
- live transport demos
- durable-store examples

## Acceptance Checks

This examples slice is not done until:
- the examples tree exists at the repo root
- the examples README names what is covered and what is intentionally deferred
- examples are wired into Zig verification
- `zig build`
- `zig build test --summary all`
- `handoff.md` records the examples lane as the active next work floor

## Accepted Slice

Implemented on 2026-03-15:
- `examples/README.md`
- `examples/examples.zig`
- `examples/common.zig`
- `examples/http_fake.zig`
- `examples/consumer_smoke.zig`
- `examples/remote_signer_recipe.zig`
- `examples/mailbox_recipe.zig`
- `examples/nip39_verification_recipe.zig`
- `examples/nip03_verification_recipe.zig`
- `examples/nip05_resolution_recipe.zig`
- `examples/group_session_recipe.zig`
- `examples/group_session_adversarial_example.zig`
- build wiring so `zig build test --summary all` exercises the examples tree

Deferred to the next examples slice:
- any live transport or durable-store examples
- richer example indexing/search posture if the examples tree outgrows the current README catalog

## Current Next Step

Treat this examples floor as accepted with the HTTP-backed recipes now included, then either:
- return to broader `NIP-29` sync/store/client refinement
- or take a Zig-native ergonomic shaping slice against the remaining audit gaps
