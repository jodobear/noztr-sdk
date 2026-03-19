---
title: SDK Group Replay Pressure Test Plan
doc_type: packet
status: accepted
owner: noztr-sdk
read_when:
  - reviewing_shared_store_workflow_pressure_tests
  - routing_group_replay_storage_work
depends_on:
  - docs/plans/sdk-store-query-index-baseline-plan.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
  - docs/plans/noztr-sdk-ownership-matrix.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Group Replay Pressure Test Plan

This slice pressure-tests the shared event/query store seam against one real SDK workflow:
relay-local `NIP-29` group replay.

## Why This Slice

The store/query baseline already has:

- raw bounded event/query/checkpoint seams
- a minimal CLI-facing event archive
- a relay-local checkpoint helper

The next question is whether one real SDK workflow can ride that shared seam without:

- forcing all workflow-local remembered-state stores into the shared core
- inventing hidden relay-pool runtime ownership
- reshaping the public store interfaces around one product schema

`GroupClient` replay is a good first pressure test because it already needs explicit oldest-to-newest
event restore and bounded relay-local state.

## Scope

Add one bounded helper that:

- archives canonical `NIP-29` state-event JSON through the shared `ClientStore` event seam
- restores one relay-local group snapshot into `GroupClient`
- makes the replay ordering explicit instead of hiding it

## Deliberate Limits

- relay-local only
- dedicated store view only for now
- no multi-relay merge or relay-pool ownership
- no product-specific durable backend yet

## Pressure-Test Result To Capture

The shared store seam is good enough for one relay-local workflow replay helper, but the helper
must currently assume a relay-local store boundary because `ClientEventRecord` does not yet encode
source-relay identity.
