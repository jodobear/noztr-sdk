---
title: SDK Store Archive Pressure Test Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - pressure_testing_the_shared_store_seam
  - deciding_first_cli_facing_storage_surface
depends_on:
  - docs/plans/sdk-store-query-index-baseline-plan.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
  - docs/plans/implementation-quality-gate.md
  - docs/plans/noztr-sdk-ownership-matrix.md
target_findings:
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Store Archive Pressure Test Plan

Narrow architecture pressure-test slice under the active
[sdk-store-query-index-baseline-plan.md](./sdk-store-query-index-baseline-plan.md) child lane.

## Scope Delta

Prove that the new shared store seam is usable from one real SDK-facing surface without:

- forcing workflow-local remembered-state stores into the shared core
- picking a durable backend early
- inventing a hidden runtime or subscription loop

## Chosen Pressure Test

Add one minimal CLI-facing archive helper above the shared store seam.

That helper should:

- ingest event JSON explicitly into the shared event store
- replay/query events through the shared query/page/cursor surface
- persist and reload named checkpoints through the shared checkpoint seam

## Why This Target

This is the highest-value low-risk pressure test because:

- it uses the new aggregate `ClientStore` concept directly
- it validates that the seam is useful above raw stores
- it does not require prematurely refactoring `NIP-03`, `NIP-17`, `NIP-29`, or `NIP-39` local
  stores into the shared layer
- it is directly relevant to the planned Zig CLI product wave

## Proof Obligations

This slice should prove:

1. one product-facing helper can use the shared store seam without backend leakage
2. the aggregate `ClientStore` concept is useful above the raw event/checkpoint sub-seams
3. the current bounded in-memory reference backend is sufficient to teach and test the surface

This slice should not try to prove:

- final durable backend support
- final relay-pool/store composition
- final workflow-store unification across existing NIP-specific helpers

## Seam Constraints

- keep protocol parsing and validation in `noztr`
- keep the archive helper explicit and side-effect free
- do not add hidden background ingestion or sync policy
- keep the shared store seam generic; the archive helper should be the convenience layer, not the
  store contracts themselves

## Expected Output

1. one minimal archive helper above `ClientStore`
2. one compile-verified recipe using the archive helper
3. public docs routing for the new surface
