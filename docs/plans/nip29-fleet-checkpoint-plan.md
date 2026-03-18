---
title: NIP-29 Fleet Checkpoint Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_fleet_persistence
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

# NIP-29 Fleet Checkpoint Plan

## Scope Delta

- Broaden the current multi-relay `GroupFleet` surface with one explicit fleet-wide checkpoint set.
- Add:
  - caller-owned `GroupFleetCheckpointStorage`
  - one typed `GroupFleetCheckpointContext`
  - one typed `GroupFleetCheckpointSet`
  - fleet-wide checkpoint export across all relay-local clients
  - fleet-wide checkpoint restore by explicit relay URL
- Keep relay merge or reconciliation, hidden background sync, and durable on-disk store policy out
  of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- Fleet checkpoints still capture relay-local reduced state, not reconciled cross-relay truth.
- The checkpoint set is caller-owned memory, not a durable storage engine by itself.
- Restore rehydrates explicit relay-local baselines; it does not imply background catch-up policy.

## Slice-Specific Seam Constraints

- Fleet checkpoint export must reuse `GroupClient.exportCheckpoint(...)` and not bypass relay-local
  validation or authoring helpers.
- Fleet restore must route by explicit relay URL and not invent merge logic.
- Relay URL matching must follow the existing normalized relay-equivalence rules.

## Slice-Specific Tests

- export one checkpoint set across multiple relay-local clients
- restore that set into a fresh fleet and reproduce per-relay local views
- fleet checkpoint set preserves relay routing and relay count explicitly
- fleet checkpoint export works without hidden merge or runtime policy
- the public fleet recipe teaches export plus restore of the full checkpoint set

## Staged Execution Notes

1. Code: add fleet checkpoint storage/context/set plus export/restore helpers.
2. Tests: prove per-relay round-trip state reproduction across a fresh fleet.
3. Example: teach fleet-wide checkpoint export and restore, not only one-relay delegation.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP29-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` reference packets, examples catalog, handoff, and startup
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
- `GroupFleetCheckpointStorage`
- `GroupFleetCheckpointContext`
- `GroupFleetCheckpointSet`
- `GroupFleet.exportCheckpointSet(...)`
- `GroupFleet.restoreCheckpointSet(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches fleet-wide checkpoint export and
  restore

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `147/147`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  now reruns green again after the upstream remediation pass

Follow-on explicit fleet reconciliation broadening for this workflow now lives in
[nip29-reconciliation-plan.md](./nip29-reconciliation-plan.md).

Follow-on durable fleet checkpoint-store broadening for this workflow now lives in
[nip29-durable-store-plan.md](./nip29-durable-store-plan.md).
