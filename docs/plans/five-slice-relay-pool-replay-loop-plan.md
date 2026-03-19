---
title: Five Slice Relay Pool Replay Loop Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - implementing_shared_relay_pool_replay_composition
  - defining_bounded_pool_level_replay_posture
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/relay-pool-subscription-boundary-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - A-NIP17-001
  - A-NIP29-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# Five Slice Relay Pool Replay Loop Plan

Next implementation loop under the active
[relay-pool-subscription-boundary-plan.md](./relay-pool-subscription-boundary-plan.md) packet.

This loop exists to prove one bounded pool-level replay surface above the shared `runtime` floor and
the existing shared store/checkpoint seams, without jumping ahead to hidden sync ownership,
workflow-local mailbox/groups policy, or product-local background execution.

## Why This Is The Right Next Loop

The current shared relay-pool lane already proves:

- shared relay membership/runtime inspection,
- bounded checkpoint export/restore composition,
- bounded subscription specification vocabulary, and
- workflow adaptation evidence from remote signer and mailbox.

The next unresolved shared question is therefore narrower:

- can the shared pool expose one bounded replay-composition plan and typed next replay step without
  absorbing full sync/runtime ownership?

That is the highest-value next proof before any broader pool-level sync model.

## Loop Shape

1. shared replay target vocabulary and caller-owned storage
2. `RelayPool.inspectReplay(...)`
3. `RelayPoolReplayPlan.nextEntry()`
4. `RelayPoolReplayPlan.nextStep()`
5. recipe, audits, release docs, index, and handoff closeout

## In Scope

- one bounded replay-spec vocabulary above pool descriptors and shared checkpoint/store seams
- one explicit side-effect-free replay plan over shared pool membership and replay targets
- deterministic `nextEntry()` and typed `nextStep()` selection
- one public recipe showing inspect-plus-next-step replay posture on the shared pool floor

## Out Of Scope

- hidden background sync loops
- workflow-local mailbox or group replay policy
- durable backend choice
- event subscription execution
- relay-framework server behavior

## Expected Outcome

After this loop, the shared relay-pool lane should have:

1. bounded runtime inspection
2. bounded subscription specification planning
3. bounded replay planning

That is enough to reassess whether the next lane should become broader sync boundary work or one
real product-facing composition slice above the shared pool floor.
