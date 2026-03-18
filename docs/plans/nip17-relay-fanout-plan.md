---
title: NIP-17 Relay Fanout Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [17]
read_when:
  - refining_nip17
  - broadening_mailbox_delivery
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

# NIP-17 Relay Fanout Plan

## Scope Delta

- Broaden the current mailbox workflow from one current-relay outbound build into one
  recipient-relay fanout planning step above the existing bounded transcript builder.
- Add:
  - explicit recipient relay-list validation against the expected recipient pubkey
  - one signed wrap built once
  - one typed delivery plan that exposes the deduplicated recipient publish relays
- Keep background polling, sender-copy policy, file-message flows, and durable mailbox sync out of
  scope.

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

- The workflow still does not own mailbox polling, retry, or durable fanout state.
- The delivery plan remains one-recipient only because the upstream kernel helper is intentionally
  one-recipient only.
- Sender-copy policy and relay selection beyond the recipient mailbox relays remain above this
  slice.

## Slice-Specific Seam Constraints

- Deterministic `rumor -> seal -> wrap` staging stays on
  `noztr.nip59_wrap.nip59_build_outbound_for_recipient(...)`.
- Recipient relay-list extraction and signature verification stay on `noztr`.
- The SDK layer may validate that a relay-list event belongs to the expected recipient and may plan
  relay fanout above that deterministic boundary.

## Slice-Specific Tests

- one delivery plan builds one wrap and publishes it to all deduplicated recipient mailbox relays
- recipient relay hint is prioritized first when it matches the verified recipient relay list
- relay-list author mismatch against the expected recipient pubkey is rejected
- recipient mailbox session can still unwrap the planned wrap JSON after relay rotation
- public mailbox recipe now teaches recipient relay fanout rather than the sender's current relay

## Staged Execution Notes

1. Code: add mailbox delivery-plan storage/result types and recipient relay fanout planning.
2. Tests: prove fanout planning, recipient-pubkey validation, and unwrap after relay rotation.
3. Example: teach sender build-once plus recipient relay fanout in the mailbox recipe.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP17-001`,
   `Z-WORKFLOWS-001`, and `Z-EXAMPLES-001`.
5. Docs/closeout: update the mailbox reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip17-mailbox-plan.md`
- Update `docs/plans/nip17-outbound-mailbox-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-17:
- `MailboxSession.planDirectMessageRelayFanout(...)`
- public `MailboxDeliveryStorage` and `MailboxDeliveryPlan`
- verified recipient relay-list ownership against the expected recipient pubkey
- one-wrap recipient-relay fanout planning with normalized relay deduplication
- recipe coverage in `examples/mailbox_recipe.zig` now teaches one wrap built once and published to
  all recipient mailbox relays

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `134/134`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`

Follow-on sender-copy delivery broadening for this workflow now lives in
[nip17-sender-copy-plan.md](./nip17-sender-copy-plan.md).

Follow-on outbound file-message broadening for this workflow now lives in
[nip17-file-send-plan.md](./nip17-file-send-plan.md).
