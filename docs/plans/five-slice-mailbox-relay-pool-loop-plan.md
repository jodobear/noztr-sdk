---
title: Five Slice Mailbox Relay Pool Loop Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - executing_the_shared_relay_pool_runtime_baseline
  - planning_mailbox_adaptation_over_the_shared_pool_floor
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/five-slice-relay-pool-loop-plan.md
  - docs/plans/five-slice-relay-pool-checkpoint-loop-plan.md
  - docs/plans/five-slice-remote-signer-relay-pool-loop-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - A-NIP17-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# Five Slice Mailbox Relay Pool Loop Plan

Bounded implementation loop under the active
[sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md) child lane.

This loop exists to pressure-test a second real workflow adaptation over the shared `runtime`
surface after the narrower remote-signer pass, while still avoiding subscription/sync expansion.

## Why Mailbox Is The Right Next Adaptation

`MailboxSession` is the next narrowest multi-relay workflow:

- it already owns explicit relay hydration and current-relay stepping
- it already exposes workflow-local runtime and delivery planning
- it is broader than remote signer, but still much narrower than groups/fleet synchronization

So it is the right next place to prove that the shared `RelayPool` floor can help a richer
workflow without becoming a mailbox-specific runtime API.

## Loop Shape

1. mailbox-to-relay-pool adapter vocabulary and caller-owned storage
2. `MailboxSession.exportRelayPool(...)`
3. `MailboxSession.inspectRelayPoolRuntime(...)`
4. typed `RelayPoolStep`-driven selection back onto the mailbox session
5. public recipe plus docs/audit/handoff closeout

## Explicit Non-Goals

- no mailbox subscription/sync model
- no inbox persistence redesign
- no delivery-plan redesign
- no hidden reconnect loop
- no groups adaptation in this loop

## Confidence Basis

- the shared relay-pool runtime floor is landed and verified
- pool checkpoint composition is landed and verified
- one real workflow adaptation over that shared floor is already landed for remote signer
- mailbox already exposes explicit relay readiness and relay selection, so the adaptation boundary
  is clear

## Expected Output

This loop should prove:

- a broader workflow can still export and inspect shared relay-pool runtime state
- typed `RelayPoolStep` values can drive mailbox relay selection without inventing a second
  mailbox-specific runtime vocabulary for the same shared concern
- the shared pool floor scales to another workflow without leaking mailbox delivery policy into
  `runtime`
