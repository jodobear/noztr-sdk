---
title: SDK CLI Client Composition Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - defining_the_first_cli_supporting_client_surface
  - composing_shared_store_and_runtime_for_tooling
depends_on:
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/relay-pool-sync-boundary-checkpoint-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# SDK CLI Client Composition Plan

Next active child under the top-level
[sdk-runtime-client-store-architecture-plan.md](./sdk-runtime-client-store-architecture-plan.md)
lane.

This packet exists because the shared store and relay-pool layers are now strong enough to support
the first real product-facing composition work, and the phased plan says the next major product
target is the Zig CLI tool.

## Scope Delta

Define the first CLI-supporting SDK client surface above:

- `noztr_sdk.store`
- `noztr_sdk.runtime`
- existing workflow/session helpers where they already fit

This client layer should pressure-test whether the current shared architecture actually composes
into one useful tooling-facing SDK surface without hidden runtime ownership.

## Why This Is The Right Next Child

The shared architecture lane now already proves:

- backend-agnostic event/query/checkpoint seams
- bounded in-memory reference storage
- CLI-facing archive pressure over the shared store seam
- shared relay-pool runtime inspection
- bounded pool checkpoint, subscription, and replay planning

So the next missing proof is:

- one CLI-facing client composition layer that reuses those seams instead of forcing the CLI repo
  to stitch them together ad hoc

## Questions This Packet Must Answer

1. What is the minimum CLI-facing client surface that belongs in `noztr-sdk`?
2. What should that client own versus what should still stay in the CLI product repo?
3. How should it compose:
   - store/query/checkpoint seams
   - relay-pool runtime planning
   - explicit publish/query/replay posture
4. What should remain explicit caller policy instead of being hidden in the client layer?

## In Scope

- one minimal tooling-facing client model above the current shared store and runtime floors
- explicit composition rules for inspect/query/replay/publish posture where already supported
- one recommended first implementation loop for that client surface

## Out Of Scope

- full CLI product design
- hidden daemon/runtime ownership
- durable backend implementation
- relay-framework server behavior
- resuming local NIP refinement loops by default

## Expected Output

This packet should produce:

1. one explicit boundary for the first CLI-supporting client surface
2. one recommended implementation loop for that surface
3. one rationale for how this reduces future CLI and signer duplication
