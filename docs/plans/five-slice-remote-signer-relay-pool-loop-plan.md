---
title: Five Slice Remote Signer Relay Pool Loop Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - executing_the_shared_relay_pool_runtime_baseline
  - planning_the_first_real_workflow_adaptation_over_relay_pool
depends_on:
  - docs/plans/sdk-relay-pool-runtime-baseline-plan.md
  - docs/plans/sdk-relay-pool-runtime-baseline-decision.md
  - docs/plans/five-slice-relay-pool-loop-plan.md
  - docs/plans/five-slice-relay-pool-checkpoint-loop-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - Z-ABSTRACTION-001
---

# Five Slice Remote Signer Relay Pool Loop Plan

Bounded implementation loop under the active
[sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md) child lane.

This loop exists to pressure-test one real workflow adaptation over the new shared `runtime`
surface without jumping ahead to mailbox policy, group sync, or full subscription/sync design.

## Why Remote Signer Is The Right First Adaptation

`RemoteSignerSession` is the narrowest current multi-relay workflow:

- it already owns bunker relay sets
- it already exposes explicit current-relay connection/auth transitions
- it already exposes deliberate relay switching
- it does not bring in mailbox fanout, grouped persistence, or multi-relay merge policy

So it is the cleanest place to prove that one real workflow can reuse the shared `RelayPool`
runtime floor without collapsing back into workflow-local relay runtime vocabulary.

## Loop Shape

1. remote-signer-to-relay-pool adapter vocabulary and caller-owned storage
2. `RemoteSignerSession.exportRelayPool(...)`
3. `RemoteSignerSession.inspectRelayPoolRuntime(...)`
4. typed pool-step-driven relay selection back onto the signer session
5. public recipe plus docs/audit/handoff closeout

## Explicit Non-Goals

- no subscription/sync model
- no request migration across relays
- no hidden reconnect loop
- no mailbox/groups adaptation in this loop
- no durable relay-pool persistence beyond the already-landed checkpoint composition work

## Confidence Basis

- shared `RelayPool` runtime and checkpoint composition are now landed and verified
- `RemoteSignerSession` already has bounded multi-relay state and explicit current-relay switching
- this loop only adapts one narrow workflow to the shared pool floor; it does not redesign signer
  transport or request semantics

## Expected Output

This loop should prove:

- one real SDK workflow can export and inspect shared relay-pool runtime state
- typed `RelayPoolStep` values are usable by a concrete workflow without re-inventing a second
  runtime vocabulary
- the shared pool floor helps signer tooling readiness without dragging signer-specific request
  semantics into `runtime`
