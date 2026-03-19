---
title: Relay Pool Architecture Checkpoint Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - deciding_the_next_shared_relay_pool_child
  - reviewing_relay_pool_adaptation_progress
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/five-slice-relay-pool-loop-plan.md
  - docs/plans/five-slice-relay-pool-checkpoint-loop-plan.md
  - docs/plans/five-slice-remote-signer-relay-pool-loop-plan.md
  - docs/plans/five-slice-mailbox-relay-pool-loop-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - A-NIP17-001
  - A-NIP29-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# Relay Pool Architecture Checkpoint Plan

Checkpoint packet under the active
[sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md) child lane.

This packet exists to stop the relay-pool lane from drifting into an open-ended sequence of
workflow-by-workflow adapters now that the shared floor has been pressure-tested by both remote
signer and mailbox.

## Why This Checkpoint Exists Now

The shared relay-pool child has already proved:

- one shared public `runtime` namespace
- one bounded shared pool vocabulary and runtime plan/step model
- one bounded shared checkpoint/export/restore composition
- one narrow workflow adaptation over that floor for remote signer
- one broader workflow adaptation over that floor for mailbox

That is enough progress to justify a deliberate checkpoint before adding another workflow adapter
or jumping prematurely into subscription/sync design.

## Questions This Packet Must Answer

1. Is the current shared relay-pool/runtime baseline strong enough to become the canonical floor
   for CLI, signer tooling, and future relay-framework work?
2. What remains truly shared work vs workflow-local adaptation work?
3. Should the next child packet be:
   - pool-level replay/composition,
   - groups adaptation,
   - or broader subscription/sync boundary work?
4. Which recent relay-pool helpers are now reference-stable and should stop growing for now?

## In Scope

- review the current shared relay-pool surface against the active audit findings
- review the two workflow adaptations already landed over that floor
- decide what the next shared relay-pool child should be
- make explicit which relay-pool adaptation loops should stop unless a blocker appears

## Out Of Scope

- another immediate workflow adaptation loop
- full subscription/sync implementation
- hidden background runtime ownership
- durable backend work
- relay-framework server implementation

## Expected Output

This checkpoint should produce:

1. one explicit recommendation for the next relay-pool child packet
2. one explicit keep/stop list for further workflow adaptations
3. one reconciled state update in handoff and docs discovery

## Review Lenses To Emphasize

- product-surface:
  - is the shared floor now useful enough for the first product wave?
- boundary/ownership:
  - what remains shared runtime vs what should stay workflow-local?
- Zig-native:
  - are we keeping one bounded shared vocabulary instead of multiplying near-duplicate runtimes?

## Checkpoint Outcome

This checkpoint concludes:

1. the current shared relay-pool/runtime floor is strong enough to stand as the canonical baseline
   for CLI-facing and signer-facing multi-relay readiness work
2. the current remote-signer and mailbox adaptations are sufficient proof that the shared pool
   vocabulary composes across more than one workflow without needing another immediate adapter loop
3. the next unresolved shared question is the pool-level subscription/sync boundary, not another
   workflow adaptation

## Keep / Stop

Keep:

- the shared `RelayPool`, `RelayPoolPlan`, and `RelayPoolStep` floor
- pool checkpoint export/restore composition over the shared checkpoint seam
- the current remote-signer and mailbox relay-pool adapters as reference-stable pressure tests

Stop by default:

- more workflow-by-workflow relay-pool adaptation loops
- groups adaptation over the shared pool floor until the pool-level subscription/sync boundary is
  decided
- deeper relay-pool helper growth that tries to answer subscription/sync questions implicitly
