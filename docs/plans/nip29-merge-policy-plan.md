---
title: NIP-29 Merge Policy Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_merge_policy
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

# NIP-29 Merge Policy Plan

## Scope Delta

- Broaden the current multi-relay `NIP-29` fleet surface with one explicit component-level merge
  layer over the existing checkpoint seam.
- Add:
  - caller-chosen relay selection per checkpoint component
  - one caller-owned merged-checkpoint storage/context
  - one typed merged-checkpoint view that records component source relays
  - one explicit helper to apply that merged checkpoint across the fleet
- Keep hidden authority choice, automatic conflict resolution, background sync loops, and automatic
  merge heuristics out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- The merge layer will not prove that the chosen source relay for each component is authoritative.
- The merged checkpoint will still be caller-directed policy, not automatic conflict resolution.
- Background runtime ownership, automatic resubscription, and relay freshness policy remain above
  this slice.

## Slice-Specific Seam Constraints

- Merge must reuse the existing relay-local checkpoint export and restore path.
- Component selection must stay explicit by relay URL; no automatic “latest wins” heuristic in this
  slice.
- The merged checkpoint must remain caller-owned and bounded.
- Applying the merged checkpoint across the fleet must still route through `GroupClient` restore,
  not bypass validation.

## Slice-Specific Tests

- build one merged checkpoint that takes metadata from one relay and members from another relay
- apply the merged checkpoint across the fleet and verify all relays converge on the selected
  component mix
- omitted component relay URLs fall back to the chosen baseline relay
- unknown component relay URLs still return the typed fleet error
- the fleet recipe teaches detect, merge by explicit component selection, then apply

## Staged Execution Notes

1. Code: add explicit merge-selection, merge-storage, merged-checkpoint, and apply helpers on
   `GroupFleet`.
2. Tests: prove mixed-source merge, baseline fallback, and typed unknown-relay failures.
3. Example: update the fleet recipe to teach merge-by-selection rather than only reconcile-from-one
   relay.
4. Review/audits: rerun `A-NIP29-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` packet chain, examples catalog, handoff, and startup
   discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-runtime-client-plan.md`
- Update `docs/plans/nip29-multirelay-runtime-plan.md`
- Update `docs/plans/nip29-reconciliation-plan.md`
- Update `docs/plans/nip29-durable-store-plan.md`
- Update `docs/plans/nip29-fleet-publish-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- Classify the `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `GroupFleetMergeSelection`
- `GroupFleetMergeStorage`
- `GroupFleetMergeContext`
- `GroupFleetMergedCheckpoint`
- `GroupFleetMergeApplyOutcome`
- `GroupFleet.buildMergedCheckpoint(...)`
- `GroupFleet.applyMergedCheckpointToAll(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches explicit component selection for
  merged fleet state before one later moderation fanout

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `179/179`
- `/workspace/projects/noztr`: `green` via
  `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`

Follow-on fleet runtime-policy broadening for this workflow now lives in
[nip29-runtime-policy-plan.md](./nip29-runtime-policy-plan.md).

Follow-on explicit targeted baseline-to-target reconcile stepping for this workflow now lives in
[nip29-targeted-reconcile-plan.md](./nip29-targeted-reconcile-plan.md).
