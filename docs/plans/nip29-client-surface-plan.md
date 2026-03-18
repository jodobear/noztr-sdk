---
title: NIP-29 Client Surface Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_client_surface
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

# NIP-29 Client Surface Plan

## Scope Delta

- Broaden `GroupSession` from replay-and-observe into a more usable single-relay groups client
  surface by adding outbound publish helpers for:
  - join requests
  - leave requests
  - put-user moderation events
  - remove-user moderation events
- Keep relay runtime, multi-relay merge, durable cursors, and background sync out of scope.
- Keep deterministic tag validation, signing, and event serialization on `noztr` helpers.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This is both product-surface broadening and Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- This slice still will not prove canonical multi-relay ordering or durable sync correctness.
- It will not cover metadata/admin/member/role snapshot authoring yet; only dynamic request and
  moderation publish helpers.
- It can validate outgoing `previous` refs only against the recent relay context observed through
  the session.

## Slice-Specific Seam Constraints

- Publish helpers must stay blocked while the relay is disconnected or auth-gated.
- Outbound publish JSON must borrow from caller-owned storage.
- Signing must use `noztr.nostr_keys`.
- Full signed event-object JSON serialization currently stays local to `noztr-sdk` pending a small
  kernel helper.
- No hidden publish transport or retry policy is introduced.

## Slice-Specific Tests

- join-request publish helper emits signed `NIP-29` JSON for the pinned relay/group
- leave-request publish helper emits signed JSON and preserves reason text
- put-user and remove-user publish helpers emit signed moderation events using validated
  `previous` refs
- unknown `previous` refs are rejected before outbound JSON is built
- disconnected or auth-gated relay blocks the publish helpers
- generated moderation JSON is accepted by another `GroupSession` incremental replay path
- generated join/leave JSON is accepted by another `GroupSession` request intake path

## Staged Execution Notes

1. Code: add outbound publish buffer/context/types and the four publish helpers.
2. Tests: prove signed JSON shape, relay gating, previous-ref enforcement, and round-trip intake.
3. Example: extend the group-session recipe to replay state, select `previous`, and build one
   outbound moderation or request event.
4. Review/audits: rerun the applesauce and Zig-native audits for the `NIP-29` findings touched.
5. Docs/closeout: update the broader `NIP-29` reference packet, examples catalog, handoff, and
   startup/discovery docs.

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

Implemented and reviewed on 2026-03-16:
- `GroupSession.beginJoinRequest(...)`
- `GroupSession.beginLeaveRequest(...)`
- `GroupSession.beginPutUser(...)`
- `GroupSession.beginRemoveUser(...)`
- caller-owned `GroupOutboundBuffer`
- caller-owned `GroupPublishContext`
- typed outbound `GroupOutboundEvent`
- typed request drafts for join, leave, put-user, and remove-user publish
- example coverage in `examples/group_session_recipe.zig` for replay plus outbound moderation build

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `121/121`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `87/87`
