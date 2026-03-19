---
title: Relay Pool Sync Boundary Checkpoint Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - deciding_the_next_shared_relay_pool_child
  - reassessing_pool_owned_subscription_replay_and_sync_scope
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/relay-pool-subscription-boundary-plan.md
  - docs/plans/five-slice-relay-pool-subscription-spec-loop-plan.md
  - docs/plans/five-slice-relay-pool-replay-loop-plan.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - A-NIP17-001
  - A-NIP29-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# Relay Pool Sync Boundary Checkpoint Plan

Next active packet under the shared
[relay-pool-subscription-boundary-plan.md](./relay-pool-subscription-boundary-plan.md) lane.

This packet exists because the shared relay-pool layer now already proves:

- bounded runtime inspection and typed next-step selection
- bounded checkpoint export/restore composition
- bounded subscription-spec planning
- bounded replay planning over checkpoint-scoped `ClientQuery` values
- narrow real workflow adaptation in remote signer and mailbox

So the next question is no longer another small loop by default.

It is:

- should shared `runtime` stop at explicit planning surfaces here?
- or is one broader pool-owned sync execution boundary justified next?

## Questions This Packet Must Answer

1. What, if anything, beyond bounded subscription and replay planning belongs in shared
   `RelayPool`?
2. What must still remain workflow-local for mailbox/groups and product-local for CLI, signer, and
   relay-framework products?
3. Is the next correct move:
   - one bounded sync execution slice,
   - one product-facing composition slice above `runtime`,
   - or a pause on pool growth while CLI/signing work starts?

## In Scope

- reassess the shared relay-pool lane after the bounded subscription and replay loops
- decide whether a broader shared sync surface is justified at all
- make explicit what should not be absorbed into shared `runtime`
- recommend one next implementation packet

## Out Of Scope

- implementing hidden background sync loops
- durable backend implementation
- relay-framework server behavior
- resuming workflow-local adapter growth by default

## Expected Output

This packet should produce:

1. one explicit keep/stop decision for shared relay-pool growth
2. one recommended next active child packet
3. one clear rationale tying that recommendation back to CLI, signer, and relay-framework needs

## Checkpoint Outcome

Keep in shared `runtime`:

- bounded relay membership/runtime inspection
- bounded checkpoint export/restore composition
- bounded subscription-spec planning
- bounded replay planning over checkpoint-scoped `ClientQuery` values
- typed next-entry and next-step selection over those shared plans

Stop before absorbing into shared `runtime`:

- pool-owned subscription execution
- pool-owned replay execution or event dispatch
- hidden background sync loops
- reconnect/retry ownership beyond explicit planning surfaces
- workflow-local mailbox/groups receive policy
- product-local scheduling and operator/runtime ownership

## Decision

The shared relay-pool layer should stop at bounded planning surfaces for now.

Reason:

- CLI v1, signer tooling, and later relay-framework work now have enough shared relay/runtime
  substrate to build on
- the next missing proof is no longer "can shared runtime plan one more thing?"
- it is "can one product-facing client layer compose store plus runtime cleanly without re-
  inventing multi-relay control?"

So the next active child should be a CLI-facing composition packet, not a broader shared sync
execution packet.
