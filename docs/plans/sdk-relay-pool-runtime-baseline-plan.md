---
title: SDK Relay Pool Runtime Baseline Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - defining_the_shared_relay_pool_runtime_layer
  - preparing_cli_signer_or_relay_framework_runtime_work
depends_on:
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-decision.md
  - docs/plans/sdk-store-query-index-baseline-plan.md
  - docs/plans/sdk-store-query-index-baseline-decision.md
  - docs/plans/implementation-quality-gate.md
  - docs/plans/noztr-sdk-ownership-matrix.md
target_findings:
  - A-NIP17-001
  - A-NIP29-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Relay Pool Runtime Baseline Plan

Next child architecture packet under the active
[sdk-runtime-client-store-architecture-plan.md](./sdk-runtime-client-store-architecture-plan.md)
lane.

This packet exists to define the shared relay-pool/runtime layer before:

- CLI v1 invents its own multi-relay readiness model
- signer tooling invents its own relay-switch/runtime planner
- relay-framework work hardens around workflow-local fleet/session helpers

## Scope Delta

Define the canonical shared relay-pool/runtime baseline for `noztr-sdk`.

This packet should answer:

- what the shared public relay-pool vocabulary is
- how relay-local session helpers compose upward into one pool layer
- how the pool layer relates to the shared store/query/checkpoint seams
- what belongs in the shared pool/runtime model vs workflow-local clients
- which bounded runtime-plan/step helpers should be shared first

## Why This Is The Right Next Child

The store/query baseline is now pressure-tested enough:

- raw bounded event/query/checkpoint seams
- one CLI-facing archive helper
- one relay-local checkpoint helper
- one real relay-local workflow replay helper

The next highest-value architecture gap is no longer another store-only slice.
It is the missing shared relay-pool/runtime model above those seams.

## In Scope

- canonical SDK vocabulary for:
  - `RelayDescriptor`
  - `RelayPoolStorage`
  - `RelayPool`
  - `RelayPoolPlan`
  - `RelayPoolStep`
  - bounded relay-pool action/state classification
- composition rules between:
  - relay-local sessions
  - pool-wide readiness/routing
  - shared checkpoint/event seams
  - runtime-plan/step layers
- minimum explicit store relationship for:
  - relay-local cursors/checkpoints
  - relay-local event replay
  - future pool-level reuse of those helpers
- the minimum shared runtime shape needed to support:
  - CLI v1
  - signer tooling v1
  - relay framework v1 planning

## Out Of Scope

- subscription/sync model in full
- hidden background daemons, polling loops, or thread ownership
- final product clients for mailbox, signer, or groups
- backend-specific durable store implementation
- premature generalization of workflow-local remembered-state stores
- relay framework server architecture

## Proof Obligations

This packet should make it possible to prove:

1. the public relay-pool/runtime vocabulary is shared and backend-agnostic
2. existing relay-local session helpers can compose into one broader pool layer
3. store/checkpoint/event helpers can relate to that pool layer without backend leakage
4. the next CLI/signer/relay-framework lanes can build on one shared runtime model instead of
   inventing separate multi-relay control layers

This packet cannot yet prove:

- the final subscription/sync model
- the final reconnect/retry policy for every product
- the final durable backend layout for pool-level state

## Non-Provable Assumptions To Keep Explicit

- one shared relay-pool/runtime model will reduce product fragmentation more than it constrains
  product-specific optimizations
- current workflow-local relay helpers are mature enough to serve as architectural input
- explicit plan/step driving remains sufficient without hidden background runtime ownership

## Seam-Contract Audit

### Relay / Session Boundary

The shared pool layer should own:

- multiple relay/session handles
- pool-wide readiness and selection posture
- bounded typed next-step selection across relays

It should not own:

- protocol parsing/validation that belongs in `noztr`
- workflow-specific mailbox/groups/signer policy
- implicit send/receive side effects

### Store Boundary

The pool layer should reuse the shared store/checkpoint/event seams where they already fit.

It should not:

- collapse workflow-local remembered-state stores into the pool layer
- force one backend or schema worldview into the public pool API

### Product Boundary

The pool layer should sit below future product clients.

It should not:

- become a hidden CLI runtime
- become the relay framework itself
- absorb application policy that belongs above `noztr-sdk`

## Anti-Drift Rules

This child exists to keep the architecture sequence coherent.

So:

- do not drift back into isolated `NIP-03` / `NIP-39` helper loops unless they block this lane
- do not jump ahead to full subscription/sync design inside this packet
- do not let workflow-specific fleet/runtime helpers define the shared pool surface by accident
- do not let the first relay-pool shape leak a specific durable backend model upward

## Required Output

This child packet should produce:

1. one baseline decision for the shared relay-pool/runtime vocabulary
2. one explicit relationship between that pool layer and the shared store/query/checkpoint seams
3. the minimum follow-on implementation slices needed to pressure-test:
   - mailbox/signer reuse
   - groups/runtime reuse
   - CLI-facing relay selection/runtime inspection

## Expected Follow-On Slices

1. baseline public relay-pool vocabulary and bounded storage
2. shared pool plan/next-step model over relay-local session state
3. store-aware pool checkpoint/replay composition decision
4. one real workflow pressure test over the shared pool layer
5. only then broader subscription/sync design

## Review Lenses To Emphasize

- Zig-native:
  - bounded multi-relay state
  - explicit ownership
  - no hidden daemon drift
- boundary/ownership:
  - pool layer vs workflow layer vs product layer
- product-surface:
  - whether the result helps CLI, signer, and relay-framework work
- performance/memory:
  - bounded relay-count posture and no accidental heap-owning public iterators

## Current References

- [sdk-runtime-client-store-architecture-decision.md](./sdk-runtime-client-store-architecture-decision.md)
- [sdk-store-query-index-baseline-plan.md](./sdk-store-query-index-baseline-plan.md)
- [sdk-store-query-index-baseline-decision.md](./sdk-store-query-index-baseline-decision.md)
