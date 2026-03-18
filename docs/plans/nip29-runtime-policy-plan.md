---
title: NIP-29 Fleet Runtime Policy Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_runtime_policy
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

# NIP-29 Fleet Runtime Policy Plan

## Scope Delta

- Broaden the current multi-relay `NIP-29` fleet surface with one explicit runtime-policy layer.
- Add:
  - explicit relay readiness state on the relay-local group client/session surface
  - one fleet runtime view over all relays against a chosen baseline
  - one typed per-relay runtime action classification for `connect`, `authenticate`,
    `reconcile`, or `ready`
- Keep hidden subscription loops, automatic authority choice, automatic merge heuristics, and
  background reconcile execution out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- The runtime view will not prove that the selected baseline relay is authoritative.
- Runtime inspection will classify what action is needed next, but it will not execute hidden
  reconciliation or transport work.
- Longer-lived subscription ownership and automatic sync policy remain above this slice.

## Slice-Specific Seam Constraints

- Relay readiness state must come from the existing relay-session state machine, not duplicated
  heuristics.
- Divergence classification must stay consistent with the existing fleet consistency lens.
- The runtime layer may recommend `reconcile`, but actual reconciliation must still route through
  explicit fleet helpers.

## Slice-Specific Tests

- fleet runtime inspection classifies `connect`, `authenticate`, `reconcile`, and `ready`
- runtime inspection marks the chosen baseline explicitly
- unknown runtime baseline relay still returns the typed fleet error
- the public fleet recipe teaches runtime inspection before merge/apply work

## Staged Execution Notes

1. Code: add relay readiness-state exposure on the session/client layer plus one fleet runtime
   plan/storage/action surface.
2. Tests: prove full action classification, baseline marking, and unknown-baseline failure.
3. Example: teach runtime inspection explicitly before merge/apply.
4. Review/audits: rerun `A-NIP29-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-runtime-client-plan.md`
- Update `docs/plans/nip29-multirelay-runtime-plan.md`
- Update `docs/plans/nip29-reconciliation-plan.md`
- Update `docs/plans/nip29-durable-store-plan.md`
- Update `docs/plans/nip29-fleet-publish-plan.md`
- Update `docs/plans/nip29-merge-policy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- Classify the `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `GroupRelayState`
- `GroupFleetRuntimeAction`
- `GroupFleetRuntimeEntry`
- `GroupFleetRuntimeStorage`
- `GroupFleetRuntimePlan`
- `GroupFleet.inspectRuntime(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches fleet runtime inspection before
  merge/apply work

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `186/186`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit targeted baseline-to-target reconcile stepping for this workflow now lives in
[nip29-targeted-reconcile-plan.md](./nip29-targeted-reconcile-plan.md).
