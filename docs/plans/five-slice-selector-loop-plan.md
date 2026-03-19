---
title: Five-Slice Selector Loop Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [17, 3, 39, 29]
read_when:
  - selecting_the_next_autonomous_loop
  - planning_bounded_runtime_policy_helpers
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP17-001
  - A-NIP03-001
  - A-NIP39-001
  - A-NIP29-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Five-Slice Selector Loop Plan

## Scope Delta

This loop defines one bounded follow-on family above already-landed runtime, delivery, and publish
plans. The shared shape is small selector helpers that remove hand-scanning of existing SDK plan
objects without introducing hidden polling, background loops, transport ownership, or automatic
policy.

The intended five slices are:

1. `NIP-39`: add one explicit next-step selector above `IdentityStoredProfileRuntimePlan`.
2. `NIP-03`: add the parallel next-step selector above
   `OpenTimestampsStoredVerificationRuntimePlan`.
3. `NIP-17`: add one explicit next-relay selector above mailbox delivery planning so callers can
   step publish fanout without hand-scanning relay-role plans.
4. `NIP-29`: add one explicit next-step selector above `GroupFleetRuntimePlan`.
5. `NIP-29`: add one explicit next-relay selector above fleet moderation publish planning so
   callers can step per-relay publish work without hand-scanning fanout plans.

This loop does not include:
- hidden background runtime ownership
- automatic subscription or polling loops
- automatic merge or refresh heuristics
- durable store broadening
- new upstream `noztr` protocol-kernel work unless a real exact-fit seam gap appears mid-slice

## Targeted Findings

- `A-NIP17-001`
- `A-NIP03-001`
- `A-NIP39-001`
- `A-NIP29-001`
- `Z-WORKFLOWS-001`
- `Z-ABSTRACTION-001`

This is mainly Zig-native workflow shaping with small product-surface broadening. The goal is to
make the already-landed bounded runtime and delivery surfaces easier to drive from real apps
without crossing into hidden orchestration.

## Slice-Specific Proof Gaps

- These selectors can only recommend one bounded next step over already-computed plans.
- They cannot prove liveness, subscription completeness, or background runtime correctness.
- They do not remove the remaining product gap around broader mailbox sync or fuller groups-client
  ownership.
- If a slice reveals that the underlying plan object is missing necessary stable ordering data, the
  loop must pause and record that as an SDK-local reshaping issue rather than silently inventing
  unstable selector policy.

## Slice-Specific Seam Constraints

- All selectors must operate only on existing caller-owned plan/storage objects.
- No slice may add hidden network side effects or store mutation.
- No slice may add implicit global ordering policy; any priority must be explicit and documented in
  the selector contract.
- `noztr` remains the owner of deterministic parse/validate/build logic; this loop stays above
  that boundary.

## Slice-Specific Tests

- `NIP-39`: prove runtime next-step selection priority and empty-plan behavior.
- `NIP-03`: prove the same runtime next-step behavior for remembered verification plans.
- `NIP-17`: prove deterministic relay selection over delivery plans, including sender-copy and
  recipient-role cases.
- `NIP-29` runtime: prove deterministic fleet runtime next-step priority and empty-plan behavior.
- `NIP-29` publish: prove deterministic per-relay moderation publish selection and empty-plan
  behavior.

## Staged Execution Notes

1. Code:
- add only selector helpers above existing plan objects
- keep contracts explicit about priority and tie-breaking

2. Tests:
- add direct selector tests for priority, tie-breaking, and empty plans
- verify no existing plan semantics regress

3. Examples:
- update the touched recipes to call the new selector helpers directly
- make the workflow preconditions explicit in each recipe

4. Review and audit reruns:
- re-evaluate `A-NIP17-001`, `A-NIP03-001`, `A-NIP39-001`, `A-NIP29-001`,
  `Z-WORKFLOWS-001`, and `Z-ABSTRACTION-001`
- check whether any selector crosses from SDK workflow help into hidden orchestration

5. Docs and handoff closeout:
- update the examples catalog if recipe control flow changes
- update handoff if the loop lands
- link older reference packets to the new follow-on slices
- classify the `noztr` compatibility rerun as `green`, `known-upstream-failure-only`, or
  `new-upstream-pressure`

## Why This Loop Is High Confidence

- every slice is SDK-local
- every slice extends an already-landed plan object instead of inventing a new subsystem
- the shared pattern is small and already proven by `MailboxRuntimePlan.nextEntry()`
- the loop can materially improve app-driving ergonomics without forcing hidden background runtime
  decisions

## Closeout

Status: completed on 2026-03-18.

Landed slices:
1. `NIP-39`: `IdentityStoredProfileRuntimePlan.nextEntry()`
2. `NIP-03`: `OpenTimestampsStoredVerificationRuntimePlan.nextEntry()`
3. `NIP-17`: `MailboxDeliveryPlan.nextRelayIndex()`
4. `NIP-29`: `GroupFleetRuntimePlan.nextEntry()`
5. `NIP-29`: `GroupFleet.nextPublishEvent(...)`

Closeout notes:
- examples now call the selector helpers directly on the touched workflow surfaces
- audits and handoff were reconciled in the same loop
- compatibility rerun status: `green`
