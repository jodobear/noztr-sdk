---
title: NIP-29 Targeted Relay Reconcile Plan
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

# NIP-29 Targeted Relay Reconcile Plan

## Scope Delta

- Broaden the current multi-relay `NIP-29` fleet surface with one explicit targeted reconcile
  helper above the existing runtime and checkpoint seams.
- Add:
  - one typed outcome for baseline-to-target reconcile steps
  - one explicit helper that copies one chosen baseline relay-local checkpoint onto one chosen
    target relay only
- Keep hidden baseline selection, hidden merge heuristics, background loops, and transport work
  out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- The helper will not prove that the chosen baseline relay is authoritative.
- The helper remains an explicit local state-copy step; it does not fetch, subscribe, or merge.
- Broader background runtime ownership still remains above this slice.

## Slice-Specific Seam Constraints

- Targeted reconcile must reuse the existing relay-local checkpoint export and restore path.
- Baseline choice must stay explicit; this slice must not invent automatic source selection.
- Reconcile must only touch the chosen target relay, not silently update the whole fleet.

## Slice-Specific Tests

- targeted reconcile copies one chosen baseline relay-local checkpoint onto one chosen target relay
- targeted reconcile clears the reconcile action for that target on the next runtime inspection
- targeting the baseline relay itself returns a typed fleet error
- the public fleet recipe teaches one explicit targeted reconcile step over the runtime surface

## Staged Execution Notes

1. Code: add one typed targeted-reconcile outcome plus one explicit helper on `GroupFleet`.
2. Tests: prove explicit baseline-to-target reconcile, runtime cleanup, and typed same-relay
   rejection.
3. Example: teach one explicit targeted reconcile step after runtime inspection.
4. Review/audits: rerun `A-NIP29-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-runtime-policy-plan.md`
- Update `docs/plans/nip29-reconciliation-plan.md`
- Update `docs/plans/nip29-merge-policy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `GroupFleetTargetReconcileOutcome`
- `GroupFleet.reconcileRelayFromBaseline(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches one explicit targeted
  baseline-to-target reconcile step after runtime inspection and merge/apply work

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `196/196`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`
