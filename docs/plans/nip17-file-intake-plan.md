---
title: NIP-17 File Intake Plan
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

# NIP-17 File Intake Plan

## Scope Delta

- Broaden the current mailbox workflow from direct-message-only intake into one mailbox intake path
  that can also unwrap and parse `NIP-17` file messages.
- Add:
  - one typed mailbox file-message outcome
  - one generic wrapped-envelope intake union for direct messages vs file messages
  - one explicit file-message intake helper above the current mailbox relay/session surface
- Keep outbound file-message authoring, background polling/subscription loops, and durable mailbox
  runtime out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP17-001`
- `Z-WORKFLOWS-001`
- `Z-EXAMPLES-001`

This is product-surface broadening with secondary workflow-shape and teaching-surface cleanup.

## Slice-Specific Proof Gaps

- The mailbox workflow still does not own polling, retry, or durable mailbox runtime state.
- Outbound file-message authoring is still deferred; this slice broadens intake first.
- The generic wrapped-envelope helper still remains explicit and caller-driven; it does not invent
  hidden runtime or transport policy.

## Slice-Specific Seam Constraints

- Deterministic unwrap stays on `noztr.nip59_wrap.nip59_unwrap(...)`.
- Direct-message parse stays on `noztr.nip17_private_messages.nip17_message_parse(...)`.
- File-message parse stays on `noztr.nip17_private_messages.nip17_file_message_parse(...)` and
  `nip17_unwrap_file_message(...)`.
- The SDK layer may classify direct-message vs file-message rumor kinds and package typed mailbox
  outcomes above that deterministic boundary.

## Slice-Specific Tests

- mailbox session unwraps one wrapped file message successfully
- generic wrapped-envelope intake classifies direct messages vs file messages
- generic wrapped-envelope intake rejects unsupported rumor kinds
- duplicate-wrap suppression still applies across direct-message and file-message intake
- mailbox recipe now teaches direct-message delivery plus file-message intake on the same workflow

## Staged Execution Notes

1. Code: add file-message outcome types plus generic wrapped-envelope intake helpers.
2. Tests: prove file-message unwrap, generic classification, unsupported-kind rejection, and
   duplicate suppression across intake modes.
3. Example: teach one direct-message round trip and one file-message intake on the public mailbox
   surface.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP17-001`,
   `Z-WORKFLOWS-001`, and `Z-EXAMPLES-001`.
5. Docs/closeout: update the mailbox reference packet chain, examples catalog, handoff, and
   startup routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip17-mailbox-plan.md`
- Update `docs/plans/nip17-outbound-mailbox-plan.md`
- Update `docs/plans/nip17-relay-fanout-plan.md`
- Update `docs/plans/nip17-sender-copy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md` only if packet discovery changes
- Update `AGENTS.md` and `agent-brief` only if startup routing changes

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `MailboxFileMessageOutcome`
- `MailboxEnvelopeOutcome`
- `MailboxSession.acceptWrappedFileMessageJson(...)`
- `MailboxSession.acceptWrappedEnvelopeJson(...)`
- recipe coverage in `examples/mailbox_recipe.zig` now teaches one direct-message delivery path plus
  one file-message intake path on the same explicit mailbox workflow surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `161/161`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on outbound file-message broadening for this workflow now lives in
[nip17-file-send-plan.md](./nip17-file-send-plan.md).

Follow-on mailbox runtime broadening for this workflow now lives in
[nip17-runtime-plan.md](./nip17-runtime-plan.md).
