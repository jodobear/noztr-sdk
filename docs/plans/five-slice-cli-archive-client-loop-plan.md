---
title: Five Slice CLI Archive Client Loop Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - implementing_the_first_cli_supporting_client_surface
  - composing_shared_store_and_runtime_for_tooling
depends_on:
  - docs/plans/sdk-cli-client-composition-plan.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# Five Slice CLI Archive Client Loop Plan

Next implementation loop under the active
[sdk-cli-client-composition-plan.md](./sdk-cli-client-composition-plan.md) child.

This loop exists to prove the first CLI-supporting SDK client surface above the current shared
`store` and `runtime` floors without drifting into CLI-product UX, command design, or hidden
runtime ownership.

## Why This Is The Right First CLI Loop

The shared architecture already proves:

- bounded event/query/checkpoint seams
- bounded relay-pool runtime inspection
- bounded pool subscription and replay planning
- CLI-facing archive pressure over the shared store seam

The next missing proof is narrower:

- can `noztr-sdk` expose one minimal tooling-facing client that composes those seams cleanly
  enough that the future CLI repo does not have to invent its own runtime/store glue layer?

That is the highest-confidence first client composition slice.

## Loop Shape

1. CLI archive client vocabulary and caller-owned storage/config
2. `CliArchiveClient.queryEvents(...)` plus explicit checkpoint helpers over the shared store seam
3. `CliArchiveClient.inspectRelayRuntime(...)`
4. `CliArchiveClient.inspectReplay(...)`
5. recipe, release docs, audits, index, and handoff closeout

## In Scope

- one minimal tooling-facing SDK client above:
  - `noztr_sdk.store.EventArchive`
  - `noztr_sdk.store.RelayCheckpointArchive`
  - `noztr_sdk.runtime.RelayPool`
- explicit local query/checkpoint composition
- explicit shared relay runtime inspection
- explicit shared replay planning
- one public recipe showing the composed client path

## Out Of Scope

- CLI command UX
- flag parsing or output formatting
- hidden background runtime ownership
- publish execution
- durable backend selection
- signer or relay-framework product policy

## Expected Outcome

After this loop, `noztr-sdk` should have one concrete CLI-supporting client surface that proves:

1. the shared store/runtime layers compose into one useful tooling-facing SDK client
2. the future CLI repo can stay thinner and more product-focused
3. the next CLI or signer composition loops can build on one reusable client boundary instead of
   ad hoc glue
