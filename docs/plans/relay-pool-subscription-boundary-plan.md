---
title: Relay Pool Subscription Boundary Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - defining_the_next_shared_relay_pool_child
  - deciding_pool_owned_subscription_and_sync_scope
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/relay-pool-architecture-checkpoint-plan.md
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

# Relay Pool Subscription Boundary Plan

Next child packet under the active
[sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md) lane.

This packet exists because the shared relay-pool/runtime floor is now strong enough for CLI and
signer foundations, and the biggest remaining shared relay question is no longer another adapter.
It is the boundary between:

- pool-owned multi-relay subscription or replay posture
- workflow-local mailbox/groups policy
- and product-local background runtime ownership

## Why This Is The Right Next Child

The current shared relay-pool layer already proves:

- one backend-agnostic public `runtime` namespace
- one bounded shared pool vocabulary and plan/step model
- one bounded checkpoint export/restore composition
- one narrow workflow adaptation for remote signer
- one broader workflow adaptation for mailbox

So the next unresolved shared question is:

- what subscription, replay, and sync posture should belong to the shared pool at all?

That question matters more now than another workflow adaptation loop.

## Questions This Packet Must Answer

1. What subscription/sync responsibilities, if any, belong in the shared `RelayPool` layer?
2. What must remain workflow-local for mailbox and groups?
3. What must remain product-local for CLI, signer tooling, and relay-framework products?
4. How should pool-level replay/subscription posture relate to the shared store/query/checkpoint
   seams without forcing one backend or hidden daemon model?

## In Scope

- define the boundary between:
  - pool-level relay membership/runtime
  - pool-level replay/subscription coordination
  - workflow-local mailbox/groups policy
  - product-local background execution ownership
- decide whether the next implementation child should be:
  - bounded pool replay helpers,
  - bounded subscription specification vocabulary,
  - or a smaller pool restore/replay composition slice first
- make explicit what not to absorb into shared `runtime`

## Out Of Scope

- implementing full subscriptions or hidden background loops
- relay-framework server behavior
- durable backend implementation
- another workflow adaptation loop unless this packet finds a hard blocker

## Expected Output

This packet should produce:

1. one explicit boundary decision for pool-level subscription/sync scope
2. one explicit recommendation for the next implementation child
3. one clear keep/stop list so the lane does not drift back into adapter-by-adapter growth

## Review Lenses To Emphasize

- boundary/ownership:
  - pool vs workflow vs product
- product-surface:
  - what CLI, signer, and relay-framework work actually need next
- Zig-native:
  - bounded explicit plans and no hidden daemon creep

