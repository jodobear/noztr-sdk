---
title: Noztr SDK Audit Lanes
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - defining_audit_postures
  - planning_high_impact_audit_work
  - deciding_which_review_lenses_apply
depends_on:
  - docs/guides/NOZTR_SDK_STYLE.md
  - docs/plans/noztr-sdk-ownership-matrix.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
---

# Noztr SDK Audit Lanes

Canonical lane map for `noztr-sdk` audits and named review lenses.

This is not a demand that every slice run every lane as a full standalone audit.
It exists to make the lane set explicit:
- which lanes are always-on control lanes
- which lanes are named review lanes inside the implementation gate
- which lanes should expand into full audit programs only when the work justifies them

## Purpose

- keep audit work posture-specific instead of vague
- make lane references explicit
- prevent `noztr-sdk` from copying `noztr`'s kernel-focused audit topology mechanically
- keep future hardening work evidence-first and lane-scoped

## Always-On Audit Lanes

These lanes already have live repo artifacts and should remain the default refinement closeout
frames.

### 1. Product-Surface Lane

Question:
- does this workflow feel like a real app-facing SDK surface rather than only a bounded substrate?

Current artifact:
- [implemented-nips-applesauce-audit-2026-03-15.md](./implemented-nips-applesauce-audit-2026-03-15.md)

Primary references:
- applesauce as the main product-shape and workflow-breadth reference
- rust-nostr-sdk as a secondary ecosystem signal
- [NOZTR_SDK_STYLE.md](../guides/NOZTR_SDK_STYLE.md)

Checks:
- real-world usefulness
- workflow breadth
- ecosystem compatibility
- teaching posture
- whether remaining gaps are product gaps rather than correctness bugs

### 2. Zig-Native Lane

Question:
- does this surface use Zig well, or does it still look like translated substrate or translated
  TypeScript?

Current artifact:
- [implemented-nips-zig-native-audit-2026-03-15.md](./implemented-nips-zig-native-audit-2026-03-15.md)

Primary references:
- [TIGER_STYLE.md](../guides/TIGER_STYLE.md) as the main Zig-quality lens
- [zig-patterns.md](../guides/zig-patterns.md)
- [zig-anti-patterns.md](../guides/zig-anti-patterns.md)
- [NOZTR_SDK_STYLE.md](../guides/NOZTR_SDK_STYLE.md)
- [noztr-sdk-ownership-matrix.md](./noztr-sdk-ownership-matrix.md)

Comparison signal only, not authority:
- `libnostr-z`

Checks:
- explicit ownership
- bounded storage
- caller-owned data paths
- obvious state transitions
- helper layering clarity
- whether there is one clear safe path without hiding important policy
- whether the public surface feels like strong Zig instead of translated API ceremony

### 3. Docs/Discoverability Lane

Question:
- can a maintainer or agent find the right symbol, example, packet, and current lane without
  reconstructing repo history?

Current artifact:
- [docs-surface-audit.md](./docs-surface-audit.md)

Primary references:
- [docs/index.md](../index.md)
- [handoff.md](/workspace/projects/nzdk/handoff.md)
- [AGENTS.md](/workspace/projects/nzdk/AGENTS.md)
- [agent-brief](/workspace/projects/nzdk/agent-brief)
- [examples/README.md](/workspace/projects/nzdk/examples/README.md)

Checks:
- control-surface coherence
- startup routing
- symbol routing vs file routing
- stale ownership or duplicate authority
- whether examples and handoff reflect the shipped state

## Required Review Lanes Inside The Gate

These are not separate always-on audit docs yet, but they are named lanes that must be enforced in
implementation review.

### 4. Misuse/Invalid-Input Lane

Question:
- can invalid caller input still reach helper invariants or surface the wrong public error?

Primary references:
- [implementation-quality-gate.md](./implementation-quality-gate.md)
- current `noztr` typed-error contracts for the touched helper family

Checks:
- overlong input
- malformed input
- wrong public error class
- assertion-leak or invariant-leak paths
- convenience-helper misuse resistance

### 5. Boundary/Ownership Lane

Question:
- is this behavior in the right layer: `noztr`, `noztr-sdk`, or app code above the SDK?

Primary references:
- [noztr-sdk-ownership-matrix.md](./noztr-sdk-ownership-matrix.md)
- [NOZTR_SDK_STYLE.md](../guides/NOZTR_SDK_STYLE.md)

Checks:
- kernel vs SDK split
- SDK vs application split
- whether the helper hides workflow policy that should remain explicit

### 6. Example/Contract Lane

Question:
- do examples teach the correct contract layer and the safe path?

Primary references:
- [implementation-quality-gate.md](./implementation-quality-gate.md)
- [examples-tree-plan.md](./examples-tree-plan.md)
- [examples/README.md](/workspace/projects/nzdk/examples/README.md)

Checks:
- one direct recipe for the intended path
- one hostile or misuse-oriented example for boundary-heavy surfaces unless explicitly deferred
- explicit workflow preconditions
- correct contract layer
- explicit symbol routing in the examples catalog

## Conditional Full Audit Lanes

These should become full reports only when the work is broad enough to justify them.

### 7. Interoperability/Parity Lane

Use when:
- public compatibility or peer alignment is in question
- a release or major API revision needs explicit peer comparison

Suggested references:
- SDK-relevant peers, not only protocol-kernel libraries
- current `noztr` behavior as protocol-kernel authority where applicable

### 8. Performance/Memory Lane

Use when:
- the slice adds stores, caches, routing layers, or larger runtime posture
- boundedness or memory footprint is part of the acceptance question

Suggested references:
- Zig-native bounded-memory expectations
- caller-owned storage posture from this repo's style docs

### 9. LLM Structured Usability Lane

Use when:
- examples, symbol routing, or onboarding shape are being redesigned
- the repo grows enough that agent discoverability becomes a real productivity constraint

Suggested references:
- [llm-agent-audit-2026-03-15.md](./llm-agent-audit-2026-03-15.md)
- `docs/index.md`
- `examples/README.md`

### 10. Release/Onboarding Lane

Use when:
- packaging, release shape, import posture, or getting-started quality becomes a release blocker

Checks:
- package discoverability
- import clarity
- release notes / upgrade friction
- onboarding quality for downstream users

## High-Impact Audit Program Model

For a major hardening or cleanup program:
1. define the lanes explicitly
2. keep one coverage ledger
3. finish the lane reports first
4. do one synthesis
5. only then choose remediation

This keeps evidence gathering separate from fix selection.

## What Not To Copy From `noztr`

`noztr-sdk` should not inherit blindly:
- kernel-specific audit angles that exist only because `noztr` owns low-level crypto/protocol seams
- kernel-style strictness that would make SDK UX worse
- module- or NIP-specific kernel checklists that do not map to SDK workflow pressure

## Rule

If a new audit lane is proposed:
- name the posture
- state the question it answers
- state its primary references
- say whether it is:
  - always-on
  - a required review lane inside the gate
  - or a conditional full audit lane

If those answers are weak, the lane probably does not need to exist yet.
