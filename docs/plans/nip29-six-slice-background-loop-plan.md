---
title: NIP-29 Six-Slice Background Runtime Loop
doc_type: packet
status: active
owner: noztr-sdk
nips: [29]
read_when:
  - executing_the_next_autonomous_loop
  - broadening_group_background_runtime
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/nip29-background-runtime-plan.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP29-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-29 Six-Slice Background Runtime Loop

## Scope Delta

This loop turns the broader `NIP-29` background-runtime lane into one bounded execution family.
It stays above the current relay-local runtime, consistency, reconcile, merge, and publish-plan
surfaces and does not add hidden daemon ownership.

The intended six slices are:

1. add bounded background action and entry types above the current fleet runtime surfaces
2. add `inspectBackgroundRuntime(...)` with caller-owned storage and one explicit background plan
3. add `GroupFleetBackgroundRuntimePlan.nextEntry()`
4. add `GroupFleetBackgroundRuntimePlan.nextStep()`
5. add `selectBackgroundRelay(...)` for one explicit next relay/action choice
6. close out the recipe, audits, and active docs around the new background-runtime surface

This loop does not include:
- hidden threads, tasks, or polling loops
- implicit transport ownership
- automatic merge or publish side effects
- automatic authority selection across relays

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This loop is about reducing caller stitching across relay-local fleet plans while keeping runtime
control explicit, deterministic, and caller-owned.

## Slice-Specific Proof Gaps

- The SDK can classify and prioritize next background work, but it still cannot guarantee liveness
  or completion without caller-owned scheduling.
- Merge authority and publish timing remain explicit caller choices above the loop.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- the loop may read runtime, consistency, and publish-plan state, but it must not perform connect,
  auth, merge, or publish side effects itself
- no slice may smuggle in hidden runtime daemons or polling ownership

## Slice-Specific Tests

- prove background-runtime helpers preserve deterministic relay ordering
- prove mixed connect/authenticate/reconcile/publish cases remain explicit and side-effect free
- prove examples make baseline and readiness assumptions explicit

## Staged Execution Notes

1. Code
- add only bounded coordinator helpers above the current fleet runtime, consistency, and
  publish-plan surfaces

2. Tests
- cover mixed relay states, divergence, and publish readiness without hidden side effects

3. Examples
- evolve the `NIP-29` fleet recipe only if the new surface materially improves one-step app
  driving

4. Review and audit reruns
- re-evaluate `A-NIP29-001` and `Z-ABSTRACTION-001`
- verify the loop removes real caller stitching instead of just renaming it

5. Docs and handoff closeout
- keep one commit per accepted slice
- restore the next active packet when this loop closes

## Progress

- slice 1 accepted on 2026-03-19:
  - `GroupFleetBackgroundAction`
  - `GroupFleetBackgroundEntry`
  - compatibility result: `green`
- slice 2 accepted on 2026-03-19:
  - `GroupFleetBackgroundRuntimeStorage`
  - `GroupFleetBackgroundRuntimeRequest`
  - `GroupFleetBackgroundRuntimePlan`
  - `GroupFleet.inspectBackgroundRuntime(...)`
  - compatibility result: `green`
- slice 3 accepted on 2026-03-19:
  - `GroupFleetBackgroundRuntimePlan.nextEntry()`
  - compatibility result: `green`
- slice 4 accepted on 2026-03-19:
  - `GroupFleetBackgroundRuntimeStep`
  - `GroupFleetBackgroundRuntimePlan.nextStep()`
  - compatibility result: `green`
