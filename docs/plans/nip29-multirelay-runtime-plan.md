---
title: NIP-29 Multi Relay Runtime Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_multirelay_runtime
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP29-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-29 Multi Relay Runtime Plan

## Scope Delta

- Add one explicit multi-relay runtime surface above the current single-relay `GroupClient`.
- Add:
  - `GroupFleet` over caller-owned `GroupClient` pointers
  - relay-url routing for event intake
  - relay-url checkpoint export and restore delegation
  - relay readiness inspection across the fleet
- Keep multi-relay merge, canonical ordering policy, hidden subscriptions, and durable on-disk
  stores out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- The fleet routes relay-local state; it still does not merge or reconcile divergent relay state.
- Checkpoint routing stays explicit and relay-local; it is not a durable store policy by itself.
- Caller-owned `GroupClient` instances remain the source of truth for actual reduced group state.

## Slice-Specific Seam Constraints

- `GroupFleet` must not bypass `GroupClient` or `GroupSession` validation.
- Relay selection remains explicit by relay URL; the fleet does not invent automatic publish or sync
  policy.
- Relay URL matching should follow the repo’s existing normalized relay-equivalence rules.

## Slice-Specific Tests

- relay-local intake routes only to the matching client
- relay-routed checkpoint export and restore work across the fleet
- duplicate relay URLs are rejected
- mismatched group references are rejected
- the public example teaches authored snapshot intake and checkpoint restore through the fleet

## Staged Execution Notes

1. Code: add `GroupFleet` plus relay-routing helpers over caller-owned clients.
2. Tests: prove routing, checkpoint delegation, and invalid-fleet rejection.
3. Example: teach one snapshot routed into one relay client and one checkpoint restored into
   another.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP29-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-sync-store-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-17:
- `src/workflows/group_fleet.zig`
- `GroupFleet`, `GroupFleetRelayStatus`, `GroupFleetEventOutcome`, `GroupFleetBatchOutcome`
- relay-url routed event intake over caller-owned `GroupClient`s
- relay-url routed checkpoint export and restore
- recipe coverage in `examples/group_fleet_recipe.zig`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with the fleet slice included

Follow-on fleet checkpoint persistence broadening for this workflow now lives in
[nip29-fleet-checkpoint-plan.md](./nip29-fleet-checkpoint-plan.md).

Follow-on explicit fleet reconciliation broadening for this workflow now lives in
[nip29-reconciliation-plan.md](./nip29-reconciliation-plan.md).

Follow-on durable fleet checkpoint-store broadening for this workflow now lives in
[nip29-durable-store-plan.md](./nip29-durable-store-plan.md).

Follow-on fleet-wide publish broadening for this workflow now lives in
[nip29-fleet-publish-plan.md](./nip29-fleet-publish-plan.md).

Follow-on explicit merge-policy broadening for this workflow now lives in
[nip29-merge-policy-plan.md](./nip29-merge-policy-plan.md).

Follow-on fleet runtime-policy broadening for this workflow now lives in
[nip29-runtime-policy-plan.md](./nip29-runtime-policy-plan.md).
