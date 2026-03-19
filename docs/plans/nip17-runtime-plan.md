---
title: NIP-17 Mailbox Runtime Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [17]
read_when:
  - refining_nip17
  - broadening_mailbox_runtime
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

# NIP-17 Mailbox Runtime Plan

## Scope Delta

- Broaden the current mailbox workflow from explicit send-plus-intake helpers into one explicit
  mailbox runtime inspection layer.
- Add:
  - one public runtime view over all hydrated mailbox relays
  - one typed per-relay action classification for `connect`, `authenticate`, or `receive`
  - one explicit relay-selection helper so callers can act on the runtime view without hand-rolled
    pool scanning
- Keep hidden polling loops, retry policy, durable inbox sync, websocket ownership, and background
  subscription runtime out of scope.

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

- The mailbox workflow still does not own transport polling, retry, or durable runtime state.
- Runtime inspection remains a bounded view over the current relay pool; it does not prove remote
  delivery, inbox completeness, or subscription freshness.
- A fuller mailbox runtime still needs application-owned transport orchestration above this slice.

## Slice-Specific Seam Constraints

- Relay session states stay on the existing internal relay-session seam.
- The runtime view may classify those states into mailbox actions, but it must not invent hidden
  transition policy or background work.
- Relay selection must stay explicit and caller-directed.

## Slice-Specific Tests

- runtime inspection classifies hydrated relays as `connect`, `authenticate`, or `receive`
- runtime inspection returns session-order entries and marks the current relay explicitly
- explicit relay selection switches the current mailbox relay without mutating other relay states
- the public mailbox recipe now teaches runtime inspection plus explicit relay selection around
  mailbox intake

## Staged Execution Notes

1. Code: add mailbox runtime entry/action/storage types plus explicit runtime inspection and relay
   selection helpers.
2. Tests: prove action classification, current-relay marking, and selection semantics.
3. Example: teach runtime inspection and explicit relay selection with all workflow preconditions
   stated directly.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP17-001`,
   `Z-WORKFLOWS-001`, and `Z-EXAMPLES-001`.
5. Docs/closeout: update the mailbox packet chain, examples catalog, handoff, and startup routing
   docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip17-mailbox-plan.md`
- Update `docs/plans/nip17-file-send-plan.md`
- Update `docs/plans/nip17-file-intake-plan.md`
- Update `docs/plans/nip17-sender-copy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- Update `agent-brief` only if startup routing changes
- classify compatibility rerun result

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `MailboxRuntimeAction`
- `MailboxRuntimeEntry`
- `MailboxRuntimeStorage`
- `MailboxRuntimePlan`
- `MailboxSession.inspectRuntime(...)`
- `MailboxSession.selectRelay(...)`
- recipe coverage in `examples/mailbox_recipe.zig` now teaches runtime inspection and explicit
  relay selection around mailbox intake instead of only raw relay stepping

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `184/184`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit runtime next-step selection for this workflow now lives in
[nip17-runtime-next-step-plan.md](./nip17-runtime-next-step-plan.md).

Follow-on explicit delivery next-relay selection for this workflow now lives in
[five-slice-selector-loop-plan.md](./five-slice-selector-loop-plan.md).
