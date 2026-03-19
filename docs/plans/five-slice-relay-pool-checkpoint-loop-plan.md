---
title: Five Slice Relay Pool Checkpoint Loop Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - executing_the_shared_relay_pool_runtime_baseline
  - planning_store_aware_pool_checkpoint_composition
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/sdk-store-query-index-baseline-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Five Slice Relay Pool Checkpoint Loop Plan

Bounded implementation loop under the active
[sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md) child lane.

This loop exists to prove that the shared public `RelayPool` floor can compose with the shared
checkpoint seam before we attempt workflow adaptation or broader subscription/runtime design.

## Loop Shape

1. shared relay-pool checkpoint vocabulary plus caller-owned batch storage
2. `RelayPool.exportCheckpoints(...)` for explicit per-relay checkpoint derivation
3. `RelayPool.restoreCheckpoints(...)` for explicit pool-level restore over relay-local state
4. typed next restore/checkpoint selection helper over that bounded pool checkpoint surface
5. public recipe plus docs/audit/handoff closeout

## Explicit Non-Goals

- no workflow-specific mailbox/groups/signer adaptation
- no pool-level event replay yet
- no subscription/sync model
- no hidden persistence backend or schema choice
- no background runtime ownership

## Confidence Basis

- the shared `RelayPool` runtime floor is now landed and compile-verified
- `RelayCheckpointArchive` already proves relay-local checkpoint persistence over the shared store
  seam
- this loop only composes those two proven shapes; it does not invent a new backend or workflow
  client

## Expected Output

This loop should make the next architectural statement explicit:

- shared pool runtime plus shared checkpoint persistence can meet at one backend-agnostic SDK seam
- future CLI, signer, and relay-framework work can restore bounded relay readiness state without
  inventing separate relay-set checkpoint models

## Closeout

This loop is complete.

It landed:

1. shared relay-pool checkpoint vocabulary and caller-owned batch storage
2. explicit `RelayPool.exportCheckpoints(...)` over current pool relays plus caller-supplied cursors
3. explicit `RelayPool.restoreCheckpoints(...)` into one fresh shared pool
4. typed `nextEntry()` plus `nextExportStep()` / `nextRestoreStep()` over the bounded checkpoint set
5. one public recipe proving composition with `RelayCheckpointArchive` instead of absorbing
   persistence policy into `runtime`
