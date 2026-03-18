---
title: NIP-29 Durable Store Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_durable_sync
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

# NIP-29 Durable Store Plan

## Scope Delta

- Broaden the current multi-relay `NIP-29` surface with one explicit caller-owned checkpoint-store
  seam for `GroupFleet`.
- Add:
  - a per-relay checkpoint-store interface
  - a bounded in-memory reference store
  - one fleet helper to persist all relay-local checkpoints into that store
  - one fleet helper to restore all available stored checkpoints for the current relay set
- Keep background subscriptions, hidden sync loops, merge policy, conflict resolution, and any
  automatic canonical ordering out of scope.
- Keep the store model per-relay and caller-owned; do not reintroduce the rejected
  fleet-sized embedded-checkpoint record shape.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- Stored checkpoints are relay-local reduced state, not reconciled multi-relay truth.
- Restore still does not prove that the stored checkpoint is fresh or authoritative.
- The store seam enables durable backends, but this slice does not own any on-disk backend,
  background catch-up loop, or merge policy.

## Slice-Specific Seam Constraints

- Store records must remain keyed by relay URL and reuse the accepted `GroupCheckpoint` shape.
- Fleet persistence must export through `GroupClient.exportCheckpoint(...)` and restore through
  `GroupClient.restoreCheckpoint(...)`; it must not bypass validation or authoring helpers.
- The reference store must be caller-owned and bounded, and it must not allocate internally.
- Relay URL matching in the store must follow the repo's normalized relay-equivalence rules.

## Slice-Specific Tests

- persist a multi-relay fleet into a bounded store and restore it into a fresh fleet
- restoring from the store should only touch relays present in both the store and the fleet
- normalized-equivalent relay URLs should replace earlier stored records
- bounded store errors should surface as typed errors instead of hidden fallback behavior
- the fleet recipe should teach persist-and-restore through the store seam, not only checkpoint-set
  export and restore

## Staged Execution Notes

1. Code: add the checkpoint-store interface, bounded memory reference store, and one fleet-level
   persist/restore path.
2. Tests: prove multi-relay persist-and-restore, relay-url overwrite semantics, and bounded store
   errors.
3. Example: update the fleet recipe to make the explicit persist-and-restore path the main teaching
   flow and satisfy the same relay-readiness preconditions directly.
4. Review/audits: rerun `A-NIP29-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` reference packet chain, examples catalog, handoff, and
   startup discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-sync-store-plan.md`
- Update `docs/plans/nip29-runtime-client-plan.md`
- Update `docs/plans/nip29-multirelay-runtime-plan.md`
- Update `docs/plans/nip29-fleet-checkpoint-plan.md`
- Update `docs/plans/nip29-reconciliation-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `GroupFleetCheckpointStorePutOutcome`
- `GroupFleetCheckpointStoreError`
- `GroupFleetCheckpointRecord`
- `GroupFleetCheckpointStore`
- `MemoryGroupFleetCheckpointStore`
- `GroupFleetStorePersistOutcome`
- `GroupFleetStoreRestoreOutcome`
- `GroupFleet.persistCheckpointStore(...)`
- `GroupFleet.restoreCheckpointStore(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches fleet persistence into an
  explicit caller-owned store, then restore into a fresh fleet

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `155/155`
- `/workspace/projects/noztr`: `green` via
  `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`

Follow-on:
- the broader fleet-wide publish follow-up now lives in
  [nip29-fleet-publish-plan.md](./nip29-fleet-publish-plan.md)
- the explicit merge-policy follow-up now lives in
  [nip29-merge-policy-plan.md](./nip29-merge-policy-plan.md)
- the explicit fleet runtime-policy follow-up now lives in
  [nip29-runtime-policy-plan.md](./nip29-runtime-policy-plan.md)
