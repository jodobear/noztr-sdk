---
title: Five Slice Relay Pool Subscription Spec Loop Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - implementing_the_first_shared_relay_pool_subscription_child
  - defining_bounded_pool_subscription_vocabulary
depends_on:
  - docs/plans/relay-pool-subscription-boundary-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
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

# Five Slice Relay Pool Subscription Spec Loop Plan

First implementation loop under the active
[relay-pool-subscription-boundary-plan.md](./relay-pool-subscription-boundary-plan.md) child.

This loop is intentionally narrow. It should define the first shared subscription/replay
vocabulary above `RelayPool` without inventing hidden background sync ownership.

## Why This Is The Right First Loop

The current relay-pool floor already has:

- shared relay membership and readiness vocabulary
- shared checkpoint export/restore composition
- two workflow adaptations that prove the pool floor is reusable

So the next high-confidence move is not another workflow adapter or a full sync client. It is one
bounded shared subscription-spec layer that future CLI, signer, mailbox, groups, and relay
products can all target.

## Loop Shape

1. `RelaySubscriptionSpec` and caller-owned bounded storage
2. `RelayPoolSubscriptionPlan` over pool membership plus explicit subscription targets
3. `RelayPoolSubscriptionPlan.nextEntry()`
4. `RelayPoolSubscriptionPlan.nextStep()`
5. public recipe plus docs/audit/handoff closeout

## In Scope

- shared subscription target vocabulary above `RelayPool`
- caller-owned bounded storage for subscription specs and plan entries
- side-effect-free planning over:
  - current relay membership
  - current relay readiness
  - explicit subscription targets
- one typed next-step value for driving one bounded subscribe-now action

## Out Of Scope

- hidden subscription loops
- event handling callbacks
- store-owned replay execution
- mailbox- or groups-specific subscription policy
- reconnect/backoff ownership
- full sync client behavior

## Expected Proof

This loop should prove:

1. shared subscription vocabulary can exist without collapsing into workflow-local policy
2. the shared `runtime` layer can classify one next subscription action without owning execution
3. future products can target one shared subscription-spec floor instead of inventing bespoke
   relay-by-relay subscribe wiring

## Confidence Basis

- the current pool plan/step model already works for readiness
- the current pool checkpoint model already works for bounded shared composition
- this loop does not require backend choice, durable sync, or hidden daemon ownership

