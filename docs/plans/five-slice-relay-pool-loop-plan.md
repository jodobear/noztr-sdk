---
title: Five Slice Relay Pool Loop Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - executing_the_shared_relay_pool_runtime_baseline
  - reviewing_the_current_architecture_loop
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Five Slice Relay Pool Loop Plan

Bounded implementation loop under the active
[sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md) child lane.

This loop exists to land the minimum shared relay-pool/runtime floor with high confidence before
the architecture expands into subscription/sync or product-specific adaptation.

## Loop Shape

1. shared relay-pool namespace plus vocabulary/storage
2. public `RelayPool` wrapper above relay-local sessions
3. `inspectRuntime(...)` plus bounded `RelayPoolPlan`
4. `RelayPoolPlan.nextEntry()` and `RelayPoolPlan.nextStep()`
5. public recipe plus docs/audit/handoff closeout

## Explicit Non-Goals

- no subscription/sync model
- no durable backend for pool state
- no workflow-specific mailbox/groups/signer adaptation
- no hidden background runtime

## Confidence Basis

- relay-local session primitives already exist
- workflow-local runtime plans already prove the inspect/plan/step pattern
- shared store/query pressure tests are already landed
- this loop only extracts the shared pool floor, not a full product client

## Closeout

This loop is complete.

It landed:

1. shared public `runtime` namespace plus bounded relay-pool vocabulary and storage
2. public `RelayPool` wrapper above relay-local session state
3. side-effect-free pool runtime inspection through `inspectRuntime(...)`
4. typed `nextEntry()` and `nextStep()` selection over that bounded runtime plan
5. public recipe and release-doc routing for the shared relay-pool runtime floor
