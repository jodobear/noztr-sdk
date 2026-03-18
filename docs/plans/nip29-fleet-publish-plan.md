---
title: NIP-29 Fleet Publish Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_fleet_publish
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

# NIP-29 Fleet Publish Plan

## Scope Delta

- Broaden the current multi-relay `NIP-29` fleet surface with one explicit caller-owned publish-
  planning layer for moderation events.
- Add:
  - caller-owned per-relay publish storage for one fleet fanout
  - one explicit publish context for fleet-wide authored events
  - `GroupFleet.beginPutUserForAll(...)`
  - `GroupFleet.beginRemoveUserForAll(...)`
- Keep hidden publish retries, automatic network delivery, merge conflict resolution, and
  background runtime loops out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- This slice still does not resolve divergent relay state automatically; it only plans one explicit
  authored moderation publish per relay.
- The fanout plan does not prove delivery or cross-relay convergence after publish.
- Relay ordering and retry policy remain caller-owned above this slice.

## Slice-Specific Seam Constraints

- Each relay-local publish must still go through the existing `GroupClient.begin...` path and its
  relay-local previous-ref selection.
- The new fleet layer must stay caller-owned and bounded; no allocations or hidden publish queue.
- Per-relay event JSON must continue to borrow from caller-owned buffers only.
- The helper must not hide delivery policy; it may only return explicit relay-local outbound events.

## Slice-Specific Tests

- build one `put-user` publish plan across all relays in a fleet
- build one `remove-user` publish plan across all relays in a fleet
- feed the relay-local fanout events back through the fleet and verify state changes land on the
  intended relays
- surface bounded publish-storage pressure as typed errors
- the fleet recipe teaches persist/restore plus one explicit moderation fanout path

## Staged Execution Notes

1. Code: add fleet publish storage/context types and explicit fanout helpers for moderation events.
2. Tests: prove `put-user`, `remove-user`, replay of the returned events, and bounded storage
   errors.
3. Example: teach one explicit fleet moderation publish after restore, making all relay-readiness
   preconditions explicit.
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
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- Classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `GroupFleetPublishStorage`
- `GroupFleetPublishContext`
- `GroupFleetPutUserDraft`
- `GroupFleetRemoveUserDraft`
- `GroupFleet.beginPutUserForAll(...)`
- `GroupFleet.beginRemoveUserForAll(...)`
- recipe coverage in `examples/group_fleet_recipe.zig` now teaches explicit fleet persistence,
  restore, and one moderation fanout path

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `168/168`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  with `93/93`

Follow-on explicit merge-policy broadening for this workflow now lives in
[nip29-merge-policy-plan.md](./nip29-merge-policy-plan.md).

Follow-on fleet runtime-policy broadening for this workflow now lives in
[nip29-runtime-policy-plan.md](./nip29-runtime-policy-plan.md).
