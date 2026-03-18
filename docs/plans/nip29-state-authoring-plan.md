---
title: NIP-29 State Authoring Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_state_authoring
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

# NIP-29 State Authoring Plan

## Scope Delta

- Broaden the single-relay `NIP-29` client core with explicit authored snapshot-state helpers for:
  - metadata
  - admins
  - members
  - roles
- Keep those helpers on the existing explicit publish path:
  - caller still owns relay readiness
  - caller still owns publish transport
  - outbound JSON still borrows from caller-owned storage
- Keep multi-relay merge, durable cursors, and hidden runtime loops out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with a secondary Zig-native abstraction cleanup.

## Slice-Specific Proof Gaps

- The workflow still does not prove canonical multi-relay ordering.
- It still does not provide durable sync state or hidden runtime ownership.
- Snapshot-state authoring is explicit and relay-local; it does not imply broader publish policy.

## Slice-Specific Seam Constraints

- Deterministic tag validation and signed event-object JSON serialization stay in `noztr`.
- Relay gating still comes from the current `GroupSession` / `GroupClient` session state.
- The helpers do not take over retry, fanout, or persistence policy.

## Slice-Specific Tests

- metadata snapshot authoring emits signed JSON accepted by another session replay path
- roles snapshot authoring emits signed JSON accepted by another session replay path
- members snapshot authoring emits signed JSON accepted by another session replay path
- admins snapshot authoring emits signed JSON accepted by another session replay path
- authored snapshots still respect disconnected/auth-gated relay blocking
- the public recipe teaches authored snapshot state through `GroupClient`, not manual JSON fixtures

## Staged Execution Notes

1. Code: add authored metadata/admin/member/role snapshot helpers to `GroupSession` and
   `GroupClient`.
2. Tests: prove authored snapshot JSON round-trips through another session.
3. Example: teach authored snapshot state plus moderation publish through the public `GroupClient`
   recipe.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP29-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` reference packet, examples catalog, feedback log, handoff,
   and startup routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-sync-store-plan.md`
- Update `examples/README.md`
- Update `docs/plans/noztr-feedback-log.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-16:
- `GroupSession.beginMetadataSnapshot(...)`
- `GroupSession.beginAdminsSnapshot(...)`
- `GroupSession.beginMembersSnapshot(...)`
- `GroupSession.beginRolesSnapshot(...)`
- matching `GroupClient` wrapper entrypoints
- kernel-owned signed event-object JSON serialization via
  `noztr.nip01_event.event_serialize_json_object(...)`
- recipe coverage in `examples/group_session_recipe.zig` now teaches authored snapshot state plus
  moderation publish through `GroupClient`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
