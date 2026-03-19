---
title: Five-Slice Step-View Loop Plan
doc_type: packet
status: active
owner: noztr-sdk
nips: [17, 3, 39, 29]
read_when:
  - selecting_the_next_autonomous_loop
  - planning_typed_step_helpers_above_runtime_and_publish_plans
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

# Five-Slice Step-View Loop Plan

## Scope Delta

This loop defines one bounded follow-on family above the newly-landed selector helpers. The shared
shape is typed step views that package the already-selected next action into one explicit SDK value
without introducing hidden polling, hidden transport ownership, background loops, or automatic
policy.

The intended five slices are:

1. `NIP-39`: add one typed remembered-runtime step view above
   `IdentityStoredProfileRuntimePlan.nextEntry()`.
2. `NIP-03`: add the parallel remembered-runtime step view above
   `OpenTimestampsStoredVerificationRuntimePlan.nextEntry()`.
3. `NIP-17`: add one typed delivery-step view above `MailboxDeliveryPlan.nextRelayIndex()`.
4. `NIP-29`: add one typed fleet-runtime step view above `GroupFleetRuntimePlan.nextEntry()`.
5. `NIP-29`: add one typed fleet-publish step view above `GroupFleet.nextPublishEvent(...)`.

This loop does not include:
- hidden background runtime ownership
- automatic subscription or polling loops
- implicit transport side effects
- automatic merge or refresh heuristics
- broader durable-store changes
- new upstream `noztr` protocol-kernel work unless a real exact-fit seam gap appears mid-slice

## Targeted Findings

- `A-NIP17-001`
- `A-NIP03-001`
- `A-NIP39-001`
- `A-NIP29-001`
- `Z-WORKFLOWS-001`
- `Z-ABSTRACTION-001`

This is mainly Zig-native workflow shaping with small product-surface broadening. The goal is to
turn “selector plus plan plus separate contextual fields” into one typed SDK step value that apps
can drive directly without crossing into hidden orchestration.

## Slice-Specific Proof Gaps

- These step views can only package one already-selected next step over existing bounded plans.
- They cannot prove liveness, background runtime correctness, delivery completion, or refresh
  success.
- They do not remove the remaining product gaps around broader mailbox sync, fuller groups-client
  ownership, or longer-lived identity/proof policy.
- If a slice reveals that the selected step still depends on context not present in the current
  plan/request boundary, the loop must pause and record that as a workflow-shape issue instead of
  smuggling hidden state into the helper.

## Slice-Specific Seam Constraints

- All step views must remain pure packaging over existing caller-owned plan/request/storage data.
- No slice may add hidden network side effects, store mutation, or transport ownership.
- No slice may invent a new global priority policy; it must reflect the already-documented plan
  semantics.
- `noztr` remains the owner of deterministic parse/validate/build logic; this loop stays above
  that boundary.

## Slice-Specific Tests

- `NIP-39`: prove the typed runtime step mirrors `inspectStoredProfileRuntime(...)` action and
  selected entry semantics, including `verify_now`.
- `NIP-03`: prove the same remembered-runtime step semantics for stored verifications.
- `NIP-17`: prove the delivery step surfaces the selected relay URL, role, and wrap payload
  without reordering.
- `NIP-29` runtime: prove the fleet runtime step mirrors the selected relay/action/baseline
  semantics.
- `NIP-29` publish: prove the publish step surfaces the selected relay URL and outbound event data
  without reordering and returns `null` on empty fanout.

## Staged Execution Notes

1. Code:
- add only typed step-view helpers above the landed selectors and plans
- keep contracts explicit about what context the step carries and what remains caller-owned

2. Tests:
- add direct tests for each step-view helper
- prove no existing selector or plan semantics regress

3. Examples:
- update the touched recipes to use the step views directly
- make the workflow preconditions explicit in each recipe

4. Review and audit reruns:
- re-evaluate `A-NIP17-001`, `A-NIP03-001`, `A-NIP39-001`, `A-NIP29-001`,
  `Z-WORKFLOWS-001`, and `Z-ABSTRACTION-001`
- check whether any step view is packaging real workflow help or just moving substrate mechanics
  around without simplifying app-driving

5. Docs and handoff closeout:
- update the examples catalog if recipe control flow changes
- update handoff if the loop lands
- link older reference packets to the new follow-on slices
- classify the `noztr` compatibility rerun as `green`, `known-upstream-failure-only`, or
  `new-upstream-pressure`

## Why This Loop Is High Confidence

- every slice is SDK-local
- every slice extends a just-landed selector helper instead of inventing a new subsystem
- the shared pattern is small, teachable, and already reflected in the remaining abstraction gap
- the loop can improve real app-driving ergonomics without forcing hidden background runtime
  decisions
