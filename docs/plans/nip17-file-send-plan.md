---
title: NIP-17 File Send Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [17]
read_when:
  - refining_nip17
  - broadening_mailbox_workflow
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP17-001
  - Z-WORKFLOWS-001
  - Z-EXAMPLES-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-17 File Send Plan

## Scope Delta

- Broaden the current mailbox workflow from direct-message-only outbound authoring into one explicit
  `NIP-17` file-message send path.
- Add:
  - one typed outbound file-message request
  - one explicit current-relay outbound file-message builder
  - one explicit recipient-relay and sender-copy delivery planner for file-message wraps
- Keep background polling, retry, durable mailbox sync/runtime, multi-recipient fanout, and file
  transfer I/O out of scope.
- Keep file-message `subject` and `reply` authoring out of scope for this slice.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP17-001`
- `Z-WORKFLOWS-001`
- `Z-EXAMPLES-001`

This slice is product-surface broadening with secondary workflow-shape and teaching-surface
cleanup.

## Slice-Specific Proof Gaps

- The mailbox workflow still does not own polling, retry, or durable mailbox runtime state.
- Outbound file-message authoring still remains one-recipient only because the upstream kernel
  outbound wrap helper is intentionally one-recipient only.

## Slice-Specific Seam Constraints

- Deterministic `rumor -> seal -> wrap` staging stays on
  `noztr.nip59_wrap.nip59_build_outbound_for_recipient(...)`.
- File-message parse/validation stays on
  `noztr.nip17_private_messages.nip17_file_message_parse(...)`.
- Canonical recipient and kind-15 file metadata tag building stays on
  `noztr.nip17_private_messages.nip17_build_*_tag(...)`.
- Recipient relay-list extraction and sender-copy relay-list verification stay on `noztr`.
- The SDK layer may assemble the explicit one-recipient file-message request, validate the built
  rumor through the kernel parse helper, and plan relay delivery above that deterministic
  boundary.

## Slice-Specific Tests

- mailbox session builds one outbound file message that recipient session can unwrap
- file-message delivery planning unions recipient and sender-copy relay lists over one built wrap
- file-message builder rejects malformed metadata through typed mailbox errors
- the public mailbox recipe now teaches outbound file-message delivery plus intake on one explicit
  workflow surface

## Staged Execution Notes

1. Code: add one outbound file-message request plus build and delivery-planning entrypoints.
2. Tests: prove outbound file-message build, recipient unwrap, relay-fanout planning, and invalid
   metadata rejection.
3. Example: teach outbound file-message build plus delivery planning and intake directly on the
   mailbox workflow surface.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP17-001`,
   `Z-WORKFLOWS-001`, and `Z-EXAMPLES-001`.
5. Docs/closeout: update the mailbox packet chain, examples catalog, handoff, and startup routing
   docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip17-mailbox-plan.md`
- Update `docs/plans/nip17-outbound-mailbox-plan.md`
- Update `docs/plans/nip17-relay-fanout-plan.md`
- Update `docs/plans/nip17-sender-copy-plan.md`
- Update `docs/plans/nip17-file-intake-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- Update `agent-brief` only if startup routing changes
- classify compatibility rerun result

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `MailboxFileMessageRequest`
- `MailboxFileDimensions`
- `MailboxSession.beginFileMessage(...)`
- `MailboxSession.planFileMessageRelayFanout(...)`
- `MailboxSession.planFileMessageDelivery(...)`
- recipe coverage in `examples/mailbox_recipe.zig` now teaches outbound file-message planning plus
  intake on the same explicit mailbox workflow surface

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `173/173`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on mailbox runtime broadening for this workflow now lives in
[nip17-runtime-plan.md](./nip17-runtime-plan.md).
