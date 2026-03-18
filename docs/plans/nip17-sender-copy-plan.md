---
title: NIP-17 Sender Copy Delivery Plan
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

# NIP-17 Sender Copy Delivery Plan

## Scope Delta

- Broaden the current mailbox delivery workflow from recipient-relay fanout only into one explicit
  sender-copy aware delivery plan.
- Add:
  - one typed mailbox delivery plan that records which relays are recipient deliveries and which
    are sender-copy deliveries
  - verification of an optional sender relay-list event against the sender pubkey implied by the
    mailbox session secret
  - deduplicated union planning across recipient and sender relay lists over one built wrap
- Keep polling, retry, background subscriptions, file-message flows, and durable mailbox sync out
  of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP17-001`
- `Z-WORKFLOWS-001`
- `Z-EXAMPLES-001`

This slice is product-surface broadening with secondary workflow-shape and example-teaching
cleanup.

## Slice-Specific Proof Gaps

- Delivery planning still does not own polling, retry, or durable mailbox runtime state.
- The outbound transcript remains one-recipient only because the upstream kernel helper is
  intentionally one-recipient only.
- Sender-copy policy stays explicit and opt-in; the SDK does not invent hidden copy policy.

## Slice-Specific Seam Constraints

- Deterministic `rumor -> seal -> wrap` staging stays on
  `noztr.nip59_wrap.nip59_build_outbound_for_recipient(...)`.
- Relay-list parsing and signature verification stay on `noztr`.
- The SDK layer may verify sender and recipient relay-list ownership and plan the deduplicated
  publish set above that deterministic boundary.

## Slice-Specific Tests

- delivery planning unions recipient relays and sender-copy relays without duplicating equivalent
  URLs
- sender-copy relays are annotated distinctly from recipient relays
- sender relay-list author mismatch is rejected
- the older recipient-fanout entrypoint still works as a narrow wrapper
- the public mailbox recipe now teaches sender-copy delivery planning explicitly

## Staged Execution Notes

1. Code: broaden mailbox delivery storage/result types and add one sender-copy aware planning path.
2. Tests: prove relay-role annotation, sender-pubkey validation, and legacy wrapper behavior.
3. Example: teach sender build-once plus recipient delivery and sender-copy planning.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP17-001`,
   `Z-WORKFLOWS-001`, and `Z-EXAMPLES-001`.
5. Docs/closeout: update the mailbox reference packets, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip17-mailbox-plan.md`
- Update `docs/plans/nip17-outbound-mailbox-plan.md`
- Update `docs/plans/nip17-relay-fanout-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-17:
- `MailboxSession.planDirectMessageDelivery(...)`
- sender-copy-aware `MailboxDeliveryPlan` role annotation
- verified sender relay-list ownership against the mailbox actor pubkey
- deduplicated union planning across recipient relays and sender-copy relays
- recipe coverage in `examples/mailbox_recipe.zig` now teaches sender-copy delivery planning

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `146/146`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  still fails only on the known `NIP-46` upstream typed-error regression

Post-remediation note on 2026-03-18:
- outbound wrap construction in `src/workflows/mailbox.zig` now preserves
  `error.EntropyUnavailable` distinctly instead of collapsing it into `error.BackendUnavailable`
- the local `noztr` compatibility rerun for this workflow family is green again

Follow-on file-message intake broadening for this workflow now lives in
[nip17-file-intake-plan.md](./nip17-file-intake-plan.md).

Follow-on outbound file-message broadening for this workflow now lives in
[nip17-file-send-plan.md](./nip17-file-send-plan.md).

Follow-on mailbox runtime broadening for this workflow now lives in
[nip17-runtime-plan.md](./nip17-runtime-plan.md).
