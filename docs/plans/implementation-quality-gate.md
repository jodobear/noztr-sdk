# Noztr SDK Implementation Quality Gate

Required execution gate for new `noztr-sdk` workflow and substrate work.

Date: 2026-03-15

This document exists to reduce avoidable bugs before implementation starts. It is the canonical
pre-implementation and review checklist for new NIP or workflow work in `noztr-sdk`.

## Goal

Make new SDK work land correctly on the first pass more often by forcing:
- explicit protocol ownership
- example-first API design
- negative-path and state-transition testing
- multiple reviews before phase close

This process cannot guarantee zero defects, but it should prevent the common failure modes already
seen during early SDK work:
- re-implementing protocol-owned behavior in the SDK
- drifting from current `noztr` limits, types, or invariants
- overfitting to happy paths
- under-testing relay/session state transitions

## When It Applies

Use this gate for:
- every new SDK workflow
- every major substrate expansion
- every public API expansion
- any change that adds or changes behavior for a NIP-backed feature

Do not skip it because the change looks small. Small workflow changes can still break protocol
boundaries or state invariants.

## Required Pre-Implementation Packet

Before code edits begin, create or update a short planning packet that covers all of the following.

### 1. Scope Card

- target workflow or substrate slice
- target caller persona
- exact public entrypoints to add or change
- explicit non-goals for this slice

### 2. NIP And Kernel Inventory

For each touched NIP:
- what the NIP requires
- which `noztr` exports already cover the deterministic protocol behavior
- which parts belong in `noztr-sdk` as orchestration
- whether current `/workspace/projects/noztr/examples` already model a useful kernel recipe

If any protocol behavior is not cleanly owned by `noztr`, stop and resolve that first.

### 3. Boundary Answers

For each major helper or module, answer:
1. why is this not already a `noztr` concern?
2. why is this not application code above `noztr-sdk`?
3. why is this the simplest useful SDK layer?

If those answers are weak, the slice is not ready to implement.

### 4. Example-First Design

Write the minimal structured example the SDK should make simple.

That example must show:
- caller setup
- relay/session interaction shape
- success output
- expected failure/control points

The example should be modeled from the eventual `noztr-sdk/examples/` teaching posture, using
`/workspace/projects/noztr/examples` only as the kernel recipe reference set.

### 5. Test Matrix

Define the required tests before implementation:
- happy path
- malformed input
- rejection/error path
- replay or duplicate message behavior
- reconnect, retry, or relay-switch behavior where applicable
- limit-bound or capacity-bound behavior
- parity checks against current `noztr` behavior for the touched contracts

### 6. Acceptance Checks

Define what must be true before the slice can close:
- docs updated
- example updated or added
- tests added and passing
- `zig build`
- `zig build test --summary all`
- local `noztr` compatibility rechecked

## Implementation Rules

- Reuse `noztr` public types and validators by default.
- Do not introduce SDK-local protocol mirrors unless a written exception is recorded in planning docs.
- Keep slices vertical and small enough that tests and reviews can be specific.
- Add tests with the implementation slice, not after.
- Prefer transcript-driven state testing for session and relay workflows.
- Prefer fixed, explicit policy/control points over hidden runtime behavior.

## Required Reviews

Every qualifying slice must pass all of these reviews:

### 1. Boundary Review

Verify:
- protocol logic stayed in `noztr`
- SDK work is reusable orchestration, not app-specific policy
- new helpers match the ownership matrix

### 2. Correctness Review

Verify:
- success and failure paths
- state-machine invariants
- limit handling
- no stale assumptions versus current `noztr`
- tests cover the declared matrix

### 3. API And Ergonomics Review

Verify:
- the caller-facing surface is minimal and explicit
- applesauce and rust-nostr were used only as ergonomics references
- the API matches the example-first design instead of leaking internal substrate details

### 4. Documentation And Examples Review

Verify:
- docs match shipped behavior
- examples reflect real supported usage
- handoff names remaining gaps and next entry conditions

If any review finds a material issue:
- fix it
- rerun the failed review
- rerun any earlier review invalidated by the fix

## Definition Of Done

A NIP-backed SDK slice is not done until all of the following are true:
- the pre-implementation packet exists in planning docs
- implementation matches the approved boundary
- the declared test matrix exists and passes
- the structured example shape is documented and current
- the required review passes are complete
- `handoff.md` names the next execution slice and residual risk

## Default Workflow

Use this order unless a planning doc records a justified exception:
1. research refresh
2. planning packet
3. example-first API sketch
4. implementation slice
5. tests
6. review passes
7. docs and handoff

## Current Expectation

All new work after the completed Phase 1-4 loop should follow this gate, starting with the next
`NIP-17` mailbox/session planning cycle and the first `noztr-sdk/examples/` design pass.
