---
title: SDK Store Query Index Baseline Decision
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - implementing_store_query_index_architecture
  - deciding_sdk_storage_seams
  - preparing_cli_signer_or_relay_framework_storage_work
depends_on:
  - docs/plans/sdk-store-query-index-baseline-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-decision.md
  - docs/plans/sdk-storage-backend-research-plan.md
---

# SDK Store Query Index Baseline Decision

This doc defines the first concrete baseline for the shared `noztr-sdk` store/query/index layer.

It exists to answer the architectural question before backend implementation work starts:

- what shape should the SDK expose?
- what should remain backend-agnostic?
- what should remain workflow-local or product-owned?

## Core Decision

`noztr-sdk` should not converge on one monolithic database trait.

Instead, the baseline should be:

1. one thin aggregate vocabulary for client-facing storage
2. several narrow explicit storage/query seams underneath it
3. backend-agnostic query and cursor types at the SDK boundary
4. workflow-local remembered-state traits unless a shared cross-workflow value is already clear

So:

- `ClientStore` should be an aggregate concept, not a god-interface that every workflow must depend
  on directly
- workflows should depend on the narrow seams they actually need
- public workflow APIs must not expose backend-specific schemas, SQL fragments, transaction models,
  or index names

## Why This Baseline

Two bad outcomes need to be avoided at the same time:

1. every workflow invents its own local store/query model
2. the SDK overreacts by introducing one oversized universal persistence trait

The baseline should instead unify the parts that are truly generic:

- event persistence and replay
- query/result/cursor posture
- checkpoints and sync cursors
- generic cache-vs-durable boundaries

while leaving these out of the shared core for now:

- product-specific schemas
- high-performance relay storage tuning
- domain-specific remembered-state generalization that has not proved cross-workflow value yet

## Baseline Layer Shape

### 1. Aggregate Vocabulary

The SDK should converge on these top-level concepts:

- `ClientStore`
- `ClientQuery`
- `QueryResultPage`
- `EventCursor`
- `IndexSelection`

But this is vocabulary, not a requirement that one single trait own everything.

Purpose:

- give CLI, signer tooling, and later products one shared language
- let multiple narrower seams compose into one client-facing storage model

### 2. Narrow Core Seams

The baseline should split storage into explicit seam families.

#### Event Store Seam

Owns:

- persisting protocol events
- retrieving protocol events
- replaying stored events
- deduplicated storage identity where needed

Does not own:

- backend-specific schema details at the public SDK layer
- product-specific account/session metadata

#### Query / Read Seam

Owns:

- backend-agnostic event selection
- bounded paging
- cursor-driven continuation
- declared index intent

Does not own:

- SQL/LMDB/Postgres query dialects
- mandatory backend-specific planner hints

#### Checkpoint / Cursor Seam

Owns:

- sync/replay checkpoints
- workflow cursors where the shape is generic enough to be shared
- durable progress markers

Does not own:

- every workflow-local remembered-state model

#### Generic Key/Value or Record Seam

Owns:

- small generic SDK-level durable values where the concept is cross-workflow and backend-agnostic

Does not own:

- arbitrary downstream application schemas
- product-specific stores disguised as SDK infrastructure

## Workflow-State Rule

Not every current workflow store should be absorbed into the first shared store baseline.

Rule:

- if a remembered-state seam is clearly workflow-local, it should remain workflow-local for now
- only generalize it into the shared store layer when at least one of these is true:
  - two or more product families need the same abstraction
  - the same concept already appears in multiple workflow families
  - keeping it local creates real duplication or bad API fragmentation

Implication:

- current `NIP-03` and `NIP-39` remembered-state helpers are useful architectural input
- but they should not automatically become the template for the whole client store layer

## Query Baseline

### ClientQuery

`ClientQuery` should express the caller's logical selection, not the backend's execution language.

It should support the shared SDK-level dimensions that are product-useful and backend-agnostic,
such as:

- authors
- kinds
- ids
- time windows
- tags where the SDK can model them generically
- paging/cursor posture

It should avoid:

- backend-specific query operators
- raw SQL fragments
- backend-specific transaction handles
- storage-engine-specific tuning knobs in generic public APIs

### QueryResultPage

`QueryResultPage` should be the bounded common result container for SDK query surfaces.

It should include:

- caller-owned result storage
- result count/fill posture
- continuation posture
- any explicit truncation/incompleteness signal needed for bounded use

It should avoid:

- hidden heap ownership
- backend-owned iterators escaping into the public SDK surface

### EventCursor

`EventCursor` should be an SDK-level continuation token, not a leaked backend cursor type.

Rule:

- callers may persist or pass it back
- callers should not have to understand how the backend derived it
- the SDK may let backends encode their continuation state, but not in a way that shapes the rest
  of the public workflow APIs around one engine's semantics

### IndexSelection

`IndexSelection` should express requested access posture, not a mandatory planner contract.

Purpose:

- let products declare intent such as favoring id lookup, author/time lookup, or checkpoint replay
- keep that intent visible for bounded performance reasoning

It should not become:

- backend-specific index names
- a promise that the backend will expose or honor every exact index hint

## Cache vs Durable Rule

The shared baseline should distinguish:

- ephemeral in-memory caches
- durable persisted stores

without requiring every public API to care about which one sits underneath.

Rule:

- cache/durable posture belongs in store construction and store capability decisions
- public workflow APIs should usually depend on seams/capabilities, not on whether the underlying
  store is “a cache” or “a database”

## Support Split

### SDK-Core Must Own

- in-memory/reference event/query/checkpoint stores
- the shared query/result/cursor/index vocabulary
- the narrow seam contracts needed by CLI/signer/client work

### SDK-Core May Own Later

- one embedded durable backend implementation once the seam baseline is pressure-tested
- likely SQLite first, but only after the interface baseline is stable

### Product Repos Should Own Or Specialize

- relay-grade storage specializations
- Blossom metadata plus object-storage composition
- product-specific account/session schemas
- backend-specific operator posture

## Anti-Goals

The baseline must not:

- force every downstream developer onto one persistence backend
- expose backend-specific transaction or schema semantics in public workflow APIs
- over-generalize every workflow-local store immediately
- optimize first for the high-performance relay case at the expense of SDK-core usability
- treat “query support” as permission to smuggle a full ORM or DB planner layer into the SDK

## First Follow-On Implementation Pressure Tests

The next implementation slices should prove this baseline with small, bounded work:

1. bounded in-memory event/query/checkpoint reference seam
2. query/result/cursor baseline types
3. one integration slice that exercises the baseline from a real SDK workflow or first CLI-facing
   surface

That sequence should come before first durable backend implementation.

## Open Questions That Remain Open On Purpose

- whether the first durable backend should expose one aggregate `ClientStore` wrapper or multiple
  composable backend adapters
- how much generic tag-query posture belongs in the shared SDK core versus later product layers
- how generic checkpoint/value stores should be before they become too abstract to be useful
- where relay-pool state storage should sit relative to event/query storage in the eventual client
  architecture
