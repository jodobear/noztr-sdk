---
title: SDK Store Query Index Baseline Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - defining_the_shared_store_query_index_model
  - deciding_sdk_storage_interfaces
  - preparing_cli_signer_or_relay_framework_storage_work
depends_on:
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-decision.md
  - docs/plans/sdk-storage-backend-research-plan.md
  - docs/plans/implementation-quality-gate.md
  - docs/plans/noztr-sdk-ownership-matrix.md
target_findings:
  - A-NIP17-001
  - A-NIP29-001
  - A-NIP03-001
  - A-NIP39-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Store Query Index Baseline Plan

First child architecture packet under the active
[sdk-runtime-client-store-architecture-plan.md](./sdk-runtime-client-store-architecture-plan.md)
lane.

This packet exists to define the shared `noztr-sdk` store/query/index surface before:

- CLI v1 hardens around ad hoc local persistence
- signer tooling invents its own account/session store model
- relay framework work accidentally shapes SDK APIs around relay-only storage assumptions

## Scope Delta

Define the canonical backend-agnostic store/query/index baseline for `noztr-sdk`.

This packet should answer:

- what the core store/query/index interfaces are
- which responsibilities belong in SDK-core storage seams vs product-owned storage
- which bounded reference implementations are required in core
- which persistence concerns are generic enough for the SDK to own
- which questions remain backend-selection questions rather than interface questions

## Why This Is The Right Next Child

The storage research packet answered support posture and likely early backend direction.

The next high-value move is not to pick a database immediately. It is to define one backend-agnostic
surface that:

- CLI tooling can use without bespoke local schemas leaking upward
- signer tooling can use without inventing a parallel store/query model
- later relay framework work can extend without forcing relay-grade requirements into all SDK users

## In Scope

- canonical SDK vocabulary for:
  - `ClientStore`
  - `ClientQuery`
  - `QueryResultPage`
  - `EventCursor`
  - `IndexSelection`
- store responsibilities for:
  - events
  - checkpoints/cursors
  - workflow-owned remembered state where generic seams make sense
  - cache-vs-durable posture
- required bounded in-memory/reference implementations
- interface rules that keep public SDK workflows backend-agnostic
- the minimum store/query baseline needed to support:
  - CLI v1
  - signer tooling v1
  - relay framework v1 planning

## Out Of Scope

- picking the first durable backend implementation in this packet
- product-specific schemas for relay, Blossom, or signer products
- hidden runtime ownership or background sync loops
- backend-specific transaction DSLs, SQL builders, or operator configuration
- premature optimization for high-performance relay workloads

## Proof Obligations

This packet should make it possible to prove:

1. the shared store/query/index vocabulary is backend-agnostic at the SDK API boundary
2. in-memory/reference implementations can satisfy the same contracts as later durable backends
3. current workflow families can compose upward without each inventing bespoke store models
4. future CLI and signer work can depend on one stable store/query baseline

This packet cannot yet prove:

- which durable backend should be first-party first
- that one backend will fit CLI, signer, relay framework, and high-performance relay equally well
- final product-owned schemas for relay, Blossom, or high-throughput storage

## Non-Provable Assumptions To Keep Explicit

- one shared store/query vocabulary will reduce product fragmentation more than it constrains
  product-specific optimization
- a first embedded durable backend can be added later without reshaping the public SDK workflow
  APIs
- relay-grade storage needs can remain adapter-first long enough to keep the SDK core clean

## Seam-Contract Audit

### Store Boundary

SDK-core should own:

- storage/query interfaces
- bounded reference stores
- generic cursor/checkpoint/value types
- generic event/query result paging

SDK-core should not own:

- mandatory schemas for all downstream applications
- backend-specific transaction semantics
- operator deployment posture
- high-performance relay storage specialization

### Session / Runtime Boundary

Store/query/index contracts must stay usable from:

- relay-local session helpers
- future relay-pool helpers
- runtime plan/step layers

without forcing those layers to absorb persistence-engine details.

### Kernel Boundary

`noztr` should continue to own deterministic protocol parsing, validation, serialization, and
bounded reducers.

`noztr-sdk` should own:

- storage seams for protocol objects and workflow-owned state
- query/index posture above those deterministic kernel objects

## State-Machine Note

This is not a session-state packet.

The required output is interface architecture and ownership baseline, not a new runtime state
machine.

## Required Output

This child packet should produce:

1. one baseline decision for the shared store/query/index vocabulary
2. one explicit support split between:
   - memory/reference stores
   - generic durable store seams
   - product-owned specialized stores
3. the minimum follow-on implementation slices needed to pressure-test that baseline in the SDK

## Expected Follow-On Slices

The first pressure-test slice is now landed:

- the store/query/index baseline decision exists
- a bounded in-memory event/query/checkpoint reference seam exists
- shared query/result/cursor/index types exist under the public `store` namespace
- one compile-verified public recipe now exercises event persistence, query paging, and named
  checkpoints explicitly

Next likely slices:

1. pressure-test one real SDK workflow or first CLI-facing surface against the shared store seams
2. decide how relay-pool/runtime state should compose with the shared store layer
3. decide when the first durable backend implementation should land against the now-tested seam

## Review Lenses To Emphasize

- Zig-native:
  - caller-owned storage
  - bounded query/result posture
  - no hidden backend worldview leakage
- boundary/ownership:
  - SDK seam vs product schema vs kernel object ownership
- product-surface:
  - whether the baseline actually helps CLI/signer/client work
- performance/memory:
  - only at the level of boundedness and accidental copying for now, not backend benchmarking

## Current References

- [sdk-store-query-index-baseline-decision.md](./sdk-store-query-index-baseline-decision.md)
- [sdk-runtime-client-store-architecture-decision.md](./sdk-runtime-client-store-architecture-decision.md)
- [sdk-storage-backend-research-plan.md](./sdk-storage-backend-research-plan.md)
