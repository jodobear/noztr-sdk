# Noztr SDK NIP Meta Loop: 17, 39, 03, 05, 29

Canonical multi-NIP execution loop after the completed `NIP-46` workflow.

Date: 2026-03-15

This document defines the next five-NIP execution lane for `noztr-sdk`. It sits above the
per-batch implementation packet and gives each NIP the same required progression:
- research
- planning refinement
- implementation
- repeated multi-pass review
- docs/handoff/noztr feedback closeout

Use this together with:
- [implementation-quality-gate.md](./implementation-quality-gate.md)
- [mailbox-proof-batch-plan.md](./mailbox-proof-batch-plan.md)
- [noztr-feedback-log.md](./noztr-feedback-log.md)

Current progress snapshot:
- `NIP-17` first slice: closed green on 2026-03-15
- `NIP-39` first slice: closed green on 2026-03-15
- `NIP-03` first slice: closed green on 2026-03-15
- `NIP-05` first slice: closed green on 2026-03-15
- `NIP-29` first slice: closed green on 2026-03-15
- active next NIP: none; this five-NIP loop is complete

## Scope

This meta loop covers:
1. `NIP-17` mailbox/session orchestration
2. `NIP-39` provider verification adapters
3. `NIP-03` OpenTimestamps retrieval/verification adapters
4. `NIP-05` fetch/cache/verify workflow
5. `NIP-29` group/session sync evaluation and first SDK slice

Rationale for the final two additions:
- `NIP-05` is a high-leverage SDK workflow for ecosystem-compatible apps and composes naturally with
  `NIP-39`
- `NIP-29` is the next larger stateful workflow after the mailbox and proof lanes have validated
  the substrate further

## Ordered Sequence

Execute in this order unless a documented kernel blocker forces a reversal:

1. `NIP-17`
2. `NIP-39`
3. `NIP-03`
4. `NIP-05`
5. `NIP-29`

Why this order:
- `NIP-17` is the next workflow that stresses relay/session orchestration
- `NIP-39` and `NIP-03` are narrower adapter workflows that broaden the SDK without freezing a
  broad client facade too early
- `NIP-05` then strengthens identity fetch/cache/verify flows for downstream applications
- `NIP-29` waits until after the smaller workflows because it is the first materially heavier sync
  and state-management candidate

## Meta Rules

- Do not start the next NIP until the current NIP has completed its full loop and passed all green
  gates.
- Only one NIP may be active at a time.
- No parallel implementation across NIPs is allowed in this loop.
- A NIP is not "complete enough to move on" when code exists; it is complete only when all closeout
  gates are green.
- If work reveals a likely `noztr` kernel gap, stop broadening SDK code and record it in
  [noztr-feedback-log.md](./noztr-feedback-log.md).
- Every NIP must have a NIP-specific planning refinement document or section before implementation.
- Every NIP must have at least one example-first target, even if the concrete `examples/` file lands
  later in the batch.
- Every NIP must pass the same multi-pass reviews twice before close.
- If the implementation gate tightens materially during the loop, pause new NIP work and re-close
  the already-landed NIP packets against the new gate before advancing.

## The Per-NIP Loop

Run this full loop for each NIP in the sequence.

### Phase A: Research

Required work:
- refresh the relevant NIP text in `docs/nips/`
- inspect current `noztr` exports and tests for the touched area
- inspect the current `/workspace/projects/noztr/examples` reference examples and recipes
- review applesauce and rust-nostr only where they inform workflow layering or ergonomics

Required output:
- a concise research delta note in the NIP-specific plan or handoff update

Exit criteria:
- kernel ownership is clear
- current `noztr` example inputs are identified
- no major unknowns block planning refinement

### Phase B: Planning Refinement

Required work:
- extend or create a NIP-specific plan under `docs/plans/`
- refine the scope card, kernel inventory, boundary answers, example-first design, proof
  obligations, seam-contract audit, state-machine table where applicable, and test matrix
- define exact public SDK entrypoints for the slice
- define what will remain internal

Required output:
- a planning doc or accepted planning section for that NIP

Exit criteria:
- the NIP slice satisfies [implementation-quality-gate.md](./implementation-quality-gate.md)
- the public/internal split is explicit
- proof gaps and seam assumptions are explicit
- acceptance checks are written before code

### Phase C: Implementation

Required work:
- implement the smallest coherent vertical slice
- reuse `noztr` public types and validators by default
- add transcript/fake-adapter tests with the slice
- keep examples posture aligned with the plan

Exit criteria:
- the declared minimal slice exists in code and tests
- no hidden runtime or policy drift is introduced

### Phase D: Multi-Pass Review

Each NIP must pass all of these reviews twice.

Pass 1 goal:
- catch design, boundary, and test-shape issues immediately after the first implementation slice

Pass 2 goal:
- verify that the fixes from Pass 1 did not introduce drift and that the NIP is actually stable

Each pass must include all of the following reviews:

1. Boundary review
   - confirm protocol logic stayed in `noztr`
   - confirm the SDK logic is reusable orchestration
   - confirm the slice still fits the ownership matrix

2. Correctness review
   - inspect success and failure paths
   - inspect replay/reconnect/switch behavior where applicable
   - confirm the test matrix was actually implemented
   - recheck current `noztr` behavior before close
   - confirm proof obligations and seam assumptions still hold after implementation

3. API and ergonomics review
   - inspect naming, shape, and caller-facing clarity
   - compare against applesauce and rust-nostr only for ergonomics, not authority
   - confirm the API still matches the example-first target

4. Docs/examples/noztr-feedback review
   - update docs and handoff
   - confirm the example target is current
   - record any kernel issue or improvement idea in
     [noztr-feedback-log.md](./noztr-feedback-log.md)

5. Adversarial review
   - inspect hostile, oversized, replayed, stale, and disconnect/recovery paths
   - confirm cleanup and replacement semantics are pinned
   - write a short production-failure note before closeout

If any review finds material issues:
- fix them
- rerun the failed review
- rerun earlier reviews invalidated by the fix

Minimum review sequence for every NIP:
1. Boundary review pass 1
2. Correctness review pass 1
3. API and ergonomics review pass 1
4. Docs/examples/noztr-feedback review pass 1
5. Adversarial review pass 1
6. Fix pass-1 findings
7. Boundary review pass 2
8. Correctness review pass 2
9. API and ergonomics review pass 2
10. Docs/examples/noztr-feedback review pass 2
11. Adversarial review pass 2

The second pass may not be skipped just because the first pass was clean.

### Phase E: Closeout

Required work:
- update `handoff.md`
- update the NIP-specific plan with accepted decisions
- update [noztr-feedback-log.md](./noztr-feedback-log.md) if needed
- mark the next NIP as active

Exit criteria:
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` rechecked
- the next NIP is clearly named in handoff

## Green Gates

The next NIP may start only when every gate for the current NIP is green.

### Gate G1: Research Green

Required:
- relevant NIP text rechecked
- current `noztr` exports and tests rechecked
- current `noztr` examples rechecked
- research deltas recorded

### Gate G2: Planning Green

Required:
- NIP-specific planning refinement exists
- boundary answers are explicit
- example-first target is explicit
- proof obligations and seam contracts are explicit
- state-machine table exists when the workflow is sessioned
- test matrix is explicit

### Gate G3: Implementation Green

Required:
- minimal coherent slice implemented
- tests added with the slice
- no known boundary violation left unresolved

### Gate G4: Review Green

Required:
- all five reviews completed in pass 1
- adversarial review completed in pass 1
- all findings fixed
- all five reviews completed again in pass 2
- adversarial review completed again in pass 2
- no unresolved review finding remains open

### Gate G5: Verification Green

Required:
- `zig build`
- `zig build test --summary all`
- local `/workspace/projects/noztr` rechecked before closing the NIP

### Gate G6: Closeout Green

Required:
- `handoff.md` updated
- relevant planning docs updated
- `noztr-feedback-log.md` updated if needed
- next NIP explicitly named as active

If any gate is red, the loop remains on the current NIP.

## Self-Gating Rule

The agent should treat this as a hard execution rule:
- do not claim a NIP complete until Gates G1-G6 are all green
- do not begin research for the next NIP until the current NIP is closed
- if interrupted between NIPs, resume at the first red gate of the active NIP
- if interrupted after a NIP closes, resume at Gate G1 of the next NIP in sequence

## NIP-Specific Focus

### `NIP-17`

Primary goal:
- mailbox/session orchestration over `NIP-44` and `NIP-59`

Must prove:
- the relay/session substrate is reusable beyond `NIP-46`
- inbox unwrap and relay selection can stay explicit and testable

### `NIP-39`

Primary goal:
- provider-backed identity verification adapters

Must prove:
- provider fetch/verify logic can remain explicit and cache-friendly
- current `noztr` expected-text and proof-URL helpers remain sufficient

### `NIP-03`

Primary goal:
- proof retrieval and verification classification adapters

Must prove:
- remote proof handling can remain narrow and adapter-driven
- the SDK does not collapse into a blockchain subsystem

### `NIP-05`

Primary goal:
- fetch/cache/verify workflow above `noztr`’s identifier helpers

Must prove:
- HTTP fetch, redirect handling, verification result modeling, and cache policy can remain explicit
- the identity workflow composes well with `NIP-39`

### `NIP-29`

Primary goal:
- first accepted group/session sync slice above the kernel reducer

Must prove:
- sync/store/moderation state can be layered without collapsing boundaries
- the SDK can carry a larger stateful workflow without freezing too much API too early

## Transition Gates

Transition to the next NIP only when:
- the current NIP passed all review phases
- the docs/handoff are current
- any discovered `noztr` follow-ups are logged
- the next NIP has an identified planning refinement target

## Current Active Start Point

Start this meta loop at `NIP-17`.
