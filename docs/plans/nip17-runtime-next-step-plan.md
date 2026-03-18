---
title: NIP-17 Runtime Next Step Plan
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

# NIP-17 Runtime Next Step Plan

## Scope Delta

- Broaden the current mailbox runtime surface with one explicit next-step helper above
  `inspectRuntime(...)`.
- Add:
  - one helper that selects the next mailbox relay/action entry from a runtime plan
  - explicit priority policy for `receive`, then `authenticate`, then `connect`
- Keep hidden polling, retry logic, background loops, and durable inbox runtime out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP17-001`
- `Z-WORKFLOWS-001`
- `Z-EXAMPLES-001`

This slice is product-surface broadening with secondary workflow-shape and teaching cleanup.

## Slice-Specific Proof Gaps

- The helper selects the next local step only; it does not execute transport work.
- The helper does not prove remote delivery or inbox completeness.
- Broader mailbox sync/runtime ownership remains above this slice.

## Slice-Specific Seam Constraints

- Runtime next-step selection must remain a pure helper above `inspectRuntime(...)`.
- Priority policy must stay explicit and deterministic.
- The helper must not mutate relay state or current-relay selection.

## Slice-Specific Tests

- runtime next-step prefers `receive` over `authenticate` and `connect`
- runtime next-step falls back to `authenticate` when no relay can receive
- runtime next-step falls back to `connect` when no relay is ready or auth-required
- runtime next-step returns `null` for an empty runtime plan
- the public mailbox recipe teaches runtime inspection plus next-step selection explicitly

## Staged Execution Notes

1. Code: add one explicit next-step selector above `inspectRuntime(...)`.
2. Tests: prove action priority and empty-plan behavior.
3. Example: extend the mailbox recipe to show runtime next-step selection directly.
4. Review/audits: rerun `A-NIP17-001`, `Z-WORKFLOWS-001`, and `Z-EXAMPLES-001`.
5. Docs/closeout: update the mailbox packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip17-runtime-plan.md`
- Update `docs/plans/nip17-file-send-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify compatibility rerun result

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `MailboxRuntimePlan.nextEntry()`
- recipe coverage in `examples/mailbox_recipe.zig` now teaches explicit next-step selection above
  mailbox runtime inspection

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `204/204`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`
