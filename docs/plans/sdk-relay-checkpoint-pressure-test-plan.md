---
title: SDK Relay Checkpoint Pressure Test Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - pressure_testing_relay_state_over_shared_storage
  - deciding_how_relay_runtime_state_persists
depends_on:
  - docs/plans/sdk-store-query-index-baseline-plan.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
  - docs/plans/implementation-quality-gate.md
target_findings:
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Relay Checkpoint Pressure Test Plan

Narrow relay-pool/store composition slice under the active
[sdk-store-query-index-baseline-plan.md](./sdk-store-query-index-baseline-plan.md) lane.

## Scope Delta

Prove that relay-local runtime progress can ride the shared checkpoint seam cleanly.

The slice should:

- keep the internal relay pool module out of the public API
- use explicit relay URL identity rather than pool indexes
- avoid adding hidden runtime or subscription ownership

## Chosen Pressure Test

Add one minimal `RelayCheckpointArchive` helper above `ClientStore`.

That helper should:

- persist one named cursor per relay URL and scope
- reload that cursor through the shared checkpoint seam
- prove that relay-local progress can compose with the shared store layer without forcing a
  backend-specific schema into the public surface

## Why This Target

This is the narrowest honest relay/store composition slice because:

- relay-local runtime state is a real future product need
- the helper validates the shared checkpoint seam directly
- it does not prematurely expose a public relay pool module
- it keeps relay identity explicit at the API boundary
