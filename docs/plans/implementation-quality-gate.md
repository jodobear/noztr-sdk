---
title: Noztr SDK Implementation Quality Gate
doc_type: policy
status: active
owner: noztr-sdk
read_when:
  - before_new_workflow
  - before_public_api_expansion
  - before_refinement_of_existing_slice
depends_on:
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
---

# Noztr SDK Implementation Quality Gate

Required execution gate for new `noztr-sdk` workflow and substrate work.

Date: 2026-03-15

This document exists to reduce avoidable bugs before implementation starts. It is the canonical
pre-implementation and review checklist for new NIP or workflow work in `noztr-sdk`.

Named audit and review lanes for this repo are defined in
[audit-lanes.md](./audit-lanes.md). This gate owns execution and review requirements; the audit-lane
doc owns the lane taxonomy and reference basis.

## Goal

Make new SDK work land correctly on the first pass more often by forcing:
- explicit protocol ownership
- explicit alignment with `noztr-sdk`'s real-world product target:
  - the Zig SDK analogue to applesauce in broad functionality, teaching posture, and opinionated
    usefulness
  - ecosystem-compatible and app-facing rather than repo-local or bespoke
  - still disciplined about the `noztr` kernel boundary
  - Zig-native rather than translated: use explicit ownership, bounded storage, compile-checked
    surfaces, and obvious state machines where Zig can improve on the equivalent TypeScript shape
- example-first API design
- proof obligations and explicit non-provable assumptions
- seam-contract audits before code
- adversarial and boundary-case test design, not only happy-path coverage
- explicit state-machine modeling for sessioned workflows
- negative-path and state-transition testing
- multiple reviews before phase close

This process cannot guarantee zero defects, but it should prevent the common failure modes already
seen during early SDK work:
- re-implementing protocol-owned behavior in the SDK
- drifting from current `noztr` limits, types, or invariants
- overfitting to happy paths
- under-testing relay/session state transitions
- shipping slices whose correctness depends on unexamined transport or store semantics
- claiming correctness where the SDK cannot actually prove an important fact at its current boundary

## Required Execution Order

Implementation should follow a staged micro-loop instead of editing code, tests, examples, audits,
and docs in one undifferentiated pass.

Required order:
1. code
2. tests
3. example
4. review and audit reruns
5. docs and handoff closeout

Interpretation:
- Stage 1: code
  - implement only the intended slice
  - keep packet scope tight
- Stage 2: tests
  - add or update the required correctness, adversarial, parity, and seam tests immediately
  - do not defer test work to a later cleanup pass
- Stage 3: example
  - add or update the public recipe as soon as the code and tests are green enough to teach the
    real workflow shape
  - do not let the example trail behind if the public surface changed
  - make required workflow preconditions explicit in the example
  - verify the example satisfies those preconditions directly instead of relying on hidden relay,
    session, cache, or store state
- Stage 4: review and audit reruns
  - run the normal review passes
  - rerun the relevant audit frames for refinement work
  - fix findings before docs closeout
- Stage 5: docs and handoff closeout
  - update the packet, audits, examples catalog, handoff, and startup/discovery docs
  - return the repo to steady-state reading posture
  - record any important slice mistakes, friction, or escaped assumptions before closing the slice
  - classify each lesson as:
    - local to this slice
    - or general enough to tighten the canonical process
  - only promote a lesson into canonical process docs if it is recurring, broadly generalizable, or
    would likely prevent a real future escape; otherwise keep it local to the packet, handoff, or
    review note
  - if the slice closes a major loop or packet family, restore one explicit next active packet as
    part of steady state instead of leaving the repo between packets
  - cut one git commit for the accepted slice once the slice is back in steady state

This is intentionally not a waterfall that makes examples, audits, or docs optional. It is a
staged closeout rule that reduces synchronization mistakes while keeping non-code work mandatory.

## Default Lane

Use this layered order unless a planning doc records a justified exception:
1. research refresh
2. planning packet
3. example-first API sketch
4. proof-obligation and seam-contract check
5. required execution order:
   - code
   - tests
   - example
   - review and audit reruns
   - docs and handoff closeout

This is not a second execution order. It is the full lane that leads into the staged micro-loop
above.

## When It Applies

Use this gate for:
- every new SDK workflow
- every major substrate expansion
- every public API expansion
- any change that adds or changes behavior for a NIP-backed feature

Do not skip it because the change looks small. Small workflow changes can still break protocol
boundaries or state invariants.

## Additional Rule For Refinement Work

If the slice is refining an already-implemented workflow instead of landing a brand-new one:
- name the exact live findings it is intended to close by stable finding ID from:
  - `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
  - `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- state whether the slice is primarily:
  - product-surface broadening
  - Zig-native API/ergonomics shaping
  - or both
- do not mark the refinement green until the touched workflow is re-audited against both frames
  and the targeted findings are either:
  - resolved and recorded as such
  - or narrowed explicitly into still-open residual gaps
- treat closeout consistency as part of the refinement work itself:
  - update the targeted audit entries so no stale prose still describes the pre-fix state
  - update the examples catalog if the public teaching surface changed
  - update any older reference packet that should now point at the new follow-on slice
  - demote any temporary slice packet from startup-reading posture once the slice is closed
  - if the slice adopts a new upstream helper or kernel seam, remove the superseded local
    workaround and close or narrow the corresponding `noztr-feedback-log.md` item in the same
    closeout

### Synchronization Contract

Before implementation starts, the packet must declare whether this slice:
- `touches_teaching_surface`: yes or no
- `touches_audit_state`: yes or no
- `touches_startup_docs`: yes or no

Interpretation:
- `touches_teaching_surface = yes`
  means the public examples catalog, recipe docs, or example comments are expected to change
- `touches_audit_state = yes`
  means audit findings are expected to resolve, narrow, or otherwise change wording
- `touches_startup_docs = yes`
  means `handoff.md`, `docs/index.md`, `agent-brief`, `AGENTS.md`, or similar startup/discovery
  docs are expected to change

This is intentionally small. It exists to make synchronization obligations explicit without adding a
new process layer.

### Stage Expectations

The synchronization flags also imply stage expectations:
- `touches_teaching_surface = yes`
  - Stage 3 must add or update the relevant example or recipe before the slice can close
- `touches_audit_state = yes`
  - Stage 4 must rerun the targeted audit frames and update the finding text before closeout
- `touches_startup_docs = yes`
  - Stage 5 must restore `handoff.md`, `docs/index.md`, `agent-brief`, `AGENTS.md`, or other
    discovery docs to the correct post-slice steady state
  - Stage 5 should also update any older reference packet chain that now needs to point at the new
    slice

## Required Pre-Implementation Packet

Before code edits begin, create or update a short planning packet that covers all of the following.

Use [packet-template.md](./packet-template.md) as the default starting shape for new or refined
packets.

### 1. Scope Card

- target workflow or substrate slice
- target caller persona
- exact public entrypoints to add or change
- explicit non-goals for this slice
- if this is refinement work on an existing slice, list the targeted open findings by stable finding
  ID from both audit frames
- declare:
  - `touches_teaching_surface`
  - `touches_audit_state`
  - `touches_startup_docs`

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

### 5. Proof Obligations And Assumption Gaps

Write down:
- the invariants that must hold for the slice to be correct
- which invariants are proven by `noztr`
- which invariants are proven by `noztr-sdk`
- which invariants are only assumed because the current seam does not expose enough information
- what upstream helper or local seam expansion would be needed to prove those assumptions

Do not mark a slice "green enough" if a critical invariant is only assumed and the planning doc does
not say so explicitly.

### 6. Seam Contract Audit

For every transport, relay, store, or cache seam the slice depends on, record:
- what semantics the NIP or workflow requires
- whether the current seam exposes those semantics directly
- whether the slice is narrowing scope because the seam is weaker than the NIP
- whether the seam itself must be widened before implementation

Typical examples:
- redirect and final-URL policy for HTTP-based workflows
- disconnect and retry semantics for relay/session workflows
- replacement versus append semantics for store-backed lists
- timeout and pending-request cleanup expectations

If the seam contract is weak or implicit, stop and fix that before broadening behavior.

### 7. State-Machine Table

Required for any sessioned or orchestration-heavy workflow.

Write an explicit table covering:
- states
- valid transitions
- invalid transitions
- what fields or caches must be cleared on each transition
- what events drive each transition

This is mandatory for workflows like `NIP-46`, `NIP-17`, and `NIP-29`.

### 8. Test Matrix

Define the required tests before implementation:
- happy path
- malformed input
- rejection/error path
- replay or duplicate message behavior
- reconnect, retry, or relay-switch behavior where applicable
- limit-bound or capacity-bound behavior
- parity checks against current `noztr` behavior for the touched contracts
- adversarial or hostile transcript cases
- seam-contract cases, especially where the seam could hide required semantics

The matrix must include both:
- positive recipe parity, using `noztr` examples and kernel tests as reference
- negative counterexample parity, using malformed, oversized, replayed, stale, or reordered inputs

### 9. Acceptance Checks

Define what must be true before the slice can close:
- docs updated
- example updated or added
- tests added and passing
- `zig build`
- `zig build test --summary all`
- local `noztr` compatibility rechecked
- if the slice targets an existing workflow, both audit frames rerun and the targeted findings
  updated explicitly
- staged micro-loop completed in order:
  - code
  - tests
  - example
  - review and audit reruns
  - docs and handoff closeout

If the packet declared any of these as `yes`, closeout must also verify:
- `touches_teaching_surface`
  - examples catalog and any affected recipe docs/comments are synchronized with the shipped public
    surface
  - examples make required workflow preconditions explicit instead of depending on hidden state
- `touches_audit_state`
  - targeted audit entries are updated so no stale prose still describes the pre-fix state
- `touches_startup_docs`
  - startup/discovery docs are returned to steady state and point only at what remains active after
    the slice closes
  - any older reference packet chain now points at the new follow-on slice where needed

If the slice reran local upstream compatibility checks, closeout must also classify the result as:
- green
- known-upstream-failure-only
- new-upstream-pressure

Do not leave compatibility status as raw command output or vague prose.

### 10. Example Structure Requirements

Required for any slice that adds or changes `examples/`:
- every example must declare one clear recipe purpose; avoid catch-all helpers and multi-workflow
  examples unless the slice explicitly requires composition
- every signed fixture must derive its public key from the signing secret in one place instead of
  hand-typing or duplicating the key material
- every example must stay on the public SDK surface plus `noztr` kernel helpers only, unless the
  planning packet explicitly marks a teaching exception
- every example must record its control points clearly:
  - what the caller sets up
  - what the caller steps manually
  - what success looks like
  - where failure or rejection is expected
- the examples README or catalog must map each example to:
  - workflow surface
  - recipe goal
  - deferred or unsupported related paths
- if the repo exposes both a nominal and hostile/adversarial example for a workflow, both must be
  discoverable from the same examples index
- examples must compile through the aggregate examples root and be exercised by Zig verification

## Implementation Rules

- Reuse `noztr` public types and validators by default.
- Do not introduce SDK-local protocol mirrors unless a written exception is recorded in planning docs.
- Keep slices vertical and small enough that tests and reviews can be specific.
- Add tests with the implementation slice, not after.
- Prefer transcript-driven state testing for session and relay workflows.
- Prefer transcript-driven hostile-case testing for session and relay workflows, not only valid flows.
- Prefer fixed, explicit policy/control points over hidden runtime behavior.
- If a workflow depends on transport/store semantics the seam does not expose, widen the seam or
  narrow the slice explicitly before implementation.
- If a correctness claim cannot be proven at the SDK layer, record it as a proof gap instead of
  silently treating it as complete.

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
- invalid caller input cannot still reach a lower-level helper invariant before typed validation
- invalid caller input does not leak as the wrong public error class
- state-machine invariants
- limit handling
- no stale assumptions versus current `noztr`
- tests cover the declared matrix
- proof obligations are actually satisfied or recorded as open gaps
- seam contracts match the claims the slice makes

### 3. API And Ergonomics Review

Verify:
- the caller-facing surface is minimal and explicit
- applesauce and rust-nostr were used only as ergonomics references
- the API matches the example-first design instead of leaking internal substrate details
- convenience helpers do not hide a workflow boundary that should remain explicit
- there is one obvious safe path for the common job the slice is meant to make easier

### 4. Documentation And Examples Review

Verify:
- docs match shipped behavior
- examples reflect real supported usage
- examples teach the correct contract layer instead of a lower-level or misleading one
- handoff names remaining gaps and next entry conditions
- the examples index or README is sufficient for a new agent to find the right recipe without
  reading unrelated planning docs first
- file routes and symbol routes are both explicit enough for a fresh agent to find the intended
  public surface quickly
- example structure is consistent enough that an agent can distinguish:
  - public SDK usage
  - `noztr` kernel fixture usage
  - intentionally deferred seams
- boundary-heavy surfaces should expose one direct recipe and one hostile or misuse-oriented
  example unless the packet records a justified exception
- if the slice is refinement work, the targeted applesauce-lens and Zig-native findings are updated
  or explicitly kept open with a narrower reason
- packet-declared synchronization flags were actually honored during closeout
- startup/discovery docs do not stay temporarily bloated after closeout:
  - current startup docs point at active control docs, not just-finished packets
  - recently closed packets move to reference posture unless they remain the active lane

### 5. Adversarial Review

Verify:
- the slice was challenged with hostile or production-like failure cases, not only nominal flows
- malformed, oversized, reordered, replayed, stale, or partially valid inputs do not leave hidden
  state corruption
- cleanup paths, replacement semantics, and disconnect semantics are pinned by tests where relevant
- a short "how would this fail in production?" note exists in the review output or handoff
- if examples were added, at least one review question checks whether the example teaches a caller
  to misuse an internal seam, over-generalized helper, or unsupported runtime posture

If any review finds a material issue:
- fix it
- rerun the failed review
- rerun any earlier review invalidated by the fix

For high-impact implementation or cleanup work, treat these reviews as two explicit passes:
- Review A:
  - invalid-input and misuse-path review
  - assertion-leak and helper-invariant review
- Review B:
  - docs/examples/discovery correctness review
  - ownership and workflow-boundary review

This does not replace the named review categories above. It is the preferred grouping for running
them in a disciplined order.

## Definition Of Done

A NIP-backed SDK slice is not done until all of the following are true:
- the pre-implementation packet exists in planning docs
- implementation matches the approved boundary
- the declared test matrix exists and passes
- proof obligations and seam assumptions are written and current
- if the slice refines an already-landed workflow, the targeted open findings from both audit frames
  are rechecked and updated
- any required state-machine table exists and matches the implementation
- the structured example shape is documented and current
- if `examples/` changed, the examples index is current and still reflects the intended public SDK
  teaching posture
- if the packet declared synchronization flags, those declared touchpoints are updated and back in
  steady state
- if startup or discovery docs were widened for the slice, they are trimmed back to the lean
  post-closeout state
- the required review passes are complete
- one git commit exists for the accepted slice; do not leave multiple completed slices combined in
  one dirty working tree
- `handoff.md` names the next execution slice and residual risk

## Current Expectation

All current and future workflow refinement or expansion work should follow this gate.

From the 2026-03-15 audit onward, the default expectation is stricter:
- no sessioned workflow proceeds without an explicit transition table
- no networked workflow proceeds without a seam-contract audit
- no NIP closes without adversarial coverage and a production-failure review note
- if the gate itself tightens materially, all already-accepted NIP slices must be re-audited and
  their planning packets backfilled before new NIP implementation resumes
