---
title: SDK Relay Pool Runtime Baseline Decision
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - implementing_the_shared_relay_pool_runtime_layer
  - deciding_how_multi_relay_sdk_surfaces_compose
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-decision.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
---

# SDK Relay Pool Runtime Baseline Decision

This doc defines the first concrete baseline for the shared relay-pool/runtime layer.

It exists to answer the architectural question before pool-level implementation work hardens:

- what should the shared relay-pool API shape be?
- what should remain workflow-local?
- how should the pool layer relate to shared store/query/checkpoint seams?

## Core Decision

`noztr-sdk` should not let workflow-local multi-relay helpers become the accidental public
relay-pool architecture.

Instead, the baseline should be:

1. one shared public relay-pool vocabulary
2. explicit composition upward from relay-local sessions
3. explicit reuse of shared store/checkpoint/event seams where they already fit
4. runtime plans and typed next steps above the pool, not hidden background runtime

So:

- current workflow-local fleet/runtime helpers are architectural input, not the final shared pool
  contract
- current relay-local store helpers are reusable reference shapes, not proof that the pool layer
  should absorb all of them directly

## Why This Baseline

Two bad outcomes need to be avoided:

1. every product grows its own multi-relay runtime layer
2. the SDK overreacts by turning one workflow-local fleet helper into the public universal pool API

The right middle ground is:

- one shared pool vocabulary
- explicit plan/step driving
- workflow-specific clients still free to build richer policy above it

## Baseline Layer Shape

### 1. Relay Descriptor

The shared pool layer should expose one small backend-agnostic relay descriptor shape.

Purpose:

- stable relay identity in shared pool APIs
- route selection and persistence references without leaking session internals upward

It should include only:

- validated relay URL identity
- maybe stable slot/index identity where needed for bounded storage

It should avoid:

- backend/session internals
- workflow-specific policy bits

### 2. RelayPoolStorage

The shared pool layer should use caller-owned bounded storage.

Purpose:

- make relay-count limits explicit
- keep multi-relay state deterministic and inspectable

It should hold only the minimum session/pool state needed for:

- session handles
- relay descriptors
- bounded runtime planning scratch

### 3. RelayPool

`RelayPool` should be the shared multi-relay coordinator layer above relay-local sessions.

It should own:

- multiple relay/session handles
- pool-wide readiness/routing state
- pool-level selection helpers

It should not own:

- hidden network loops
- product-specific sync policy
- workflow-specific publish/receive policy

### 4. RelayPoolPlan

`RelayPoolPlan` should be the shared side-effect-free runtime view over the pool.

It should classify work like:

- connect
- authenticate
- ready
- maybe replay/restore/select depending on the shared layer boundary

But it should not:

- smuggle mailbox/groups/signer semantics into the shared pool vocabulary
- become a workflow-local union in disguise

### 5. RelayPoolStep

`RelayPoolStep` should be the typed next-step value above the shared pool plan.

Purpose:

- one explicit next relay/action choice
- one stable value that CLI and future products can drive

It should package:

- selected relay descriptor
- selected pool action
- any minimal shared context needed to drive that step

It should avoid:

- backend-owned iterators
- hidden session mutation

## Relationship To Existing Helpers

### Relay-Local Session Helpers

Current session helpers remain the relay-local substrate.

Examples:

- mailbox session
- remote signer session
- group session

The shared pool layer should compose them upward, not replace their local state machines.

### Workflow-Local Fleet Helpers

Current workflow-local fleet/runtime helpers remain valid product/workflow layers.

They should be treated as:

- reference inputs
- proof that explicit plan/step driving works

They should not automatically define the shared pool API shape.

### Shared Store Helpers

Current store helpers should be treated as:

- `RelayCheckpointArchive`
  - proof that relay-local progress can ride the shared checkpoint seam
- `RelayLocalGroupArchive`
  - proof that one real relay-local workflow replay can ride the shared event seam

The future pool layer may:

- reuse them directly
- or absorb their naming/derivation logic

But should decide that explicitly, not by accidental duplication.

## Store Relationship Rule

The shared pool layer should reuse the shared store/query/checkpoint seams, but only where the
concept is already generic enough.

This means:

- relay-local cursor/checkpoint persistence is pool-adjacent and likely reusable
- relay-local event replay helpers are valid reference inputs
- workflow-local remembered-state stores still remain outside the shared pool baseline

The pool layer should not force:

- one backend
- one schema
- one durable-runtime worldview

## Runtime Rule

The shared pool layer should follow the same explicit runtime model already working elsewhere:

1. inspect current state
2. produce a plan
3. expose a typed next step
4. let the caller drive execution

No hidden background daemon should be required by the baseline.

## Immediate Architectural Consequences

1. the next implementation work should not add more isolated workflow-local runtime helpers first
2. the next implementation work should start from shared pool vocabulary and bounded storage
3. workflow-specific fleet/runtime surfaces should later adapt to the shared pool model where it
   actually reduces duplication

## Still Deferred

This decision does not yet settle:

- the full subscription/sync model
- final reconnect/retry policy
- pool-level durable backend shape
- final product-facing client surfaces above the pool
