---
title: NIP-29 Background Runtime Plan
doc_type: packet
status: active
owner: noztr-sdk
nips: [29]
read_when:
  - selecting_the_next_broader_product_slice
  - broadening_group_background_runtime
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip29-runtime-policy-plan.md
  - docs/plans/nip29-targeted-reconcile-plan.md
target_findings:
  - A-NIP29-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-29 Background Runtime Plan

## Scope Delta

`NIP-29` now has explicit relay-local client/session layers plus fleet checkpoint persistence,
reconciliation, merge policy, publish planning, runtime inspection, and typed next-step helpers.

The remaining gap is broader background runtime/client posture:
- bounded coordinator help above the explicit fleet runtime surfaces
- clearer cross-relay progression through connect, authenticate, reconcile, and publish phases
- app-facing runtime policy that reduces caller stitching without crossing into hidden daemon
  ownership or transport control

This packet should not:
- add hidden threads, tasks, or polling loops
- take ownership of relay transports
- add automatic merge or publish side effects
- blur the `noztr` / `noztr-sdk` boundary

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can suggest broader fleet-runtime coordination, but it still cannot prove relay liveness
  or background completion without caller-owned scheduling.
- Multi-relay authority and conflict policy remain explicit caller choices.

## Slice-Specific Seam Constraints

- any new helper must stay caller-bounded and explicit
- the fleet remains data- and plan-oriented; no slice may smuggle in a hidden runtime daemon
- publication, connection, and authentication stay caller-owned side effects

## Slice-Specific Tests

- prove any new coordinator helper preserves deterministic relay ordering
- prove multi-relay runtime helpers stay side-effect free
- prove examples make relay readiness and baseline assumptions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-29` only above the current explicit fleet runtime, reconcile, and publish-plan
  surfaces

2. Tests
- cover mixed relay states, divergence, and publish eligibility without hidden side effects

3. Examples
- extend the fleet recipe only if the new surface materially improves real app-driving control

4. Review and audit reruns
- re-evaluate `A-NIP29-001` and `Z-ABSTRACTION-001`

5. Docs and handoff closeout
- keep one commit per accepted slice
- restore the next active packet when this broader lane closes
