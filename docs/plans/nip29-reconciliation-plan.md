---
title: NIP-29 Fleet Reconciliation Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_reconciliation
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

# NIP-29 Fleet Reconciliation Plan

## Scope Delta

- Broaden the current multi-relay `NIP-29` fleet surface with one explicit reconciliation layer.
- Add:
  - bounded relay-divergence inspection across relay-local `GroupClient`s
  - one explicit source-led fleet reconciliation helper over the existing checkpoint path
- Keep hidden merge policy, hidden subscriptions, durable stores, and automatic conflict
  resolution out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- Reconciliation remains explicit and source-led; it does not prove that the chosen source relay is
  authoritative.
- The fleet still does not merge conflicting histories; it only helps the caller detect divergence
  and copy one relay-local state onto others.
- Durable sync policy and background runtime ownership remain above this slice.

## Slice-Specific Seam Constraints

- The fleet must continue to route all state handling through `GroupClient` and `GroupSession`.
- Reconciliation must reuse the accepted checkpoint export/restore path rather than inventing a new
  hidden reducer or hidden store.
- Divergence inspection should compare the public reduced view, not reach into private reducer
  internals.

## Slice-Specific Tests

- a fleet can report divergence between one authored source relay and one stale relay
- the report can use the first relay as baseline or an explicit relay URL baseline
- source-led reconciliation copies one relay-local checkpoint onto the other relays
- after reconciliation, the divergence report becomes clean
- unknown baseline or source relay URLs still return the typed fleet error
- the fleet recipe teaches detect-then-reconcile rather than only checkpoint export/restore

## Staged Execution Notes

1. Code: add one bounded divergence report plus one source-led reconciliation helper on
   `GroupFleet`.
2. Tests: prove divergence detection, reconciliation, and typed unknown-relay failures.
3. Example: update the public fleet recipe to show divergence inspection followed by
   reconciliation.
4. Review/audits: rerun `A-NIP29-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update `NIP-29` reference packets, examples catalog, handoff, and startup
   discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-sync-store-plan.md`
- Update `docs/plans/nip29-client-surface-plan.md`
- Update `docs/plans/nip29-runtime-client-plan.md`
- Update `docs/plans/nip29-multirelay-runtime-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `GroupFleet.inspectConsistency(...)`
- `GroupFleetRelayDivergence`
- `GroupFleetConsistencyReport`
- `GroupFleet.reconcileAllFromRelay(...)`
- `GroupFleetReconcileOutcome`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches detect-then-reconcile over the
  explicit fleet surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `153/153`
- `/workspace/projects/noztr`: `green` via
  `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`

Follow-on durable fleet checkpoint-store broadening for this workflow now lives in
[nip29-durable-store-plan.md](./nip29-durable-store-plan.md).

Follow-on fleet-wide publish broadening for this workflow now lives in
[nip29-fleet-publish-plan.md](./nip29-fleet-publish-plan.md).

Follow-on explicit merge-policy broadening for this workflow now lives in
[nip29-merge-policy-plan.md](./nip29-merge-policy-plan.md).

Follow-on fleet runtime-policy broadening for this workflow now lives in
[nip29-runtime-policy-plan.md](./nip29-runtime-policy-plan.md).

Follow-on explicit targeted baseline-to-target reconcile stepping for this workflow now lives in
[nip29-targeted-reconcile-plan.md](./nip29-targeted-reconcile-plan.md).
