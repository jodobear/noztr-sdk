---
title: NIP-29 Checkpoint Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_client_durable_sync
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

# NIP-29 Checkpoint Plan

## Scope Delta

- Add one explicit single-relay durable checkpoint shape above the current `GroupClient` /
  `GroupSession` replay-and-publish core.
- Add:
  - checkpoint export from current reduced state into caller-owned buffers
  - checkpoint restore into a fresh client without requiring live relay readiness
- Keep multi-relay merge, hidden subscription/runtime loops, and durable on-disk stores out of
  scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- This slice still will not prove canonical multi-relay ordering or durable merge correctness.
- The checkpoint only captures one pinned relay group's authored snapshot state, not arbitrary live
  relay backlog.
- The restored client will regain a valid single-relay snapshot baseline, not a full background
  sync runtime.

## Slice-Specific Seam Constraints

- Checkpoint export and restore must stay local and deterministic; they should not require network
  fetches.
- Deterministic event building/signing stays on `noztr` plus the existing `GroupSession`
  publish/replay helpers.
- Restore should not depend on live relay readiness, because checkpoint import is local state
  hydration rather than network intake.

## Slice-Specific Tests

- exporting a checkpoint from current reduced group state yields four signed snapshot events
- restoring that checkpoint into a fresh client reproduces the reduced group view
- restored checkpoint state rehydrates selectable `previous` refs for later moderation publish
- checkpoint export does not require live relay readiness
- checkpoint restore does not require live relay readiness

## Staged Execution Notes

1. Code: add checkpoint buffer/context/result types plus export/restore helpers.
2. Tests: prove round-trip state reproduction and follow-on moderation readiness.
3. Example: teach snapshot export and restore through the public group-client surface.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP29-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the broader `NIP-29` reference packet, examples catalog, handoff, and
   startup routing docs.

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
- `GroupSession.exportCheckpoint(...)`
- `GroupSession.restoreCheckpointEventJsons(...)`
- `GroupClient.exportCheckpoint(...)`
- `GroupClient.restoreCheckpoint(...)`
- public checkpoint buffer/context/result exports through `workflows`
- recipe coverage in `examples/group_session_recipe.zig` now teaches checkpoint export, restore,
  and follow-on moderation publish through `GroupClient`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `132/132`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `1096/1096`
