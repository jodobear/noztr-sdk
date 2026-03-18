---
title: NIP-46 Ergonomic Surface Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [46]
read_when:
  - refining_nip46
  - closing_z_buffer_001
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - Z-BUFFER-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-46 Ergonomic Surface Plan

## Scope Delta

- Replace the repeated `buffer + id + scratch` public method shape on `RemoteSignerSession`
  with one caller-owned request context.
- Keep request/response semantics, state transitions, and kernel ownership unchanged.
- Do not broaden workflow coverage in this slice.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `Z-BUFFER-001`

This is a Zig-native shaping slice, not product-surface broadening.

## Slice-Specific Proof Gaps

- This slice does not close any remaining higher-level `NIP-46` workflow gap beyond API shape.
- It should not introduce new request-building behavior outside `noztr`'s bounded builders.

## Slice-Specific Seam Constraints

- `RemoteSignerSession` must keep using `noztr` for request building and response validation.
- Request JSON continues to borrow from caller-owned storage.
- Scratch remains caller-provided and explicit, but should be grouped into the request context.

## Slice-Specific Tests

- Update existing `NIP-46` workflow tests to use the request context shape.
- Keep regressions for connect, disconnect, pending cleanup, pubkey+text methods, and invalid
  response handling green.
- Keep the public recipe compile-verified against the new shape.

## Staged Execution Notes

1. Code: add the request context type and move public entrypoints to it.
2. Tests: rework existing `NIP-46` tests around the new entrypoint shape.
3. Example: teach the new context shape in `examples/remote_signer_recipe.zig`.
4. Review/audits: rerun the Zig-native audit against `Z-BUFFER-001`; keep product-surface claims
   unchanged.
5. Docs/closeout: update the reference packet, audits, examples catalog, handoff, and startup docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip46-method-coverage-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Closeout

Accepted on 2026-03-16:
- `RemoteSignerSession.begin...` methods now take one caller-owned `RequestContext` instead of
  repeating `buffer + id + scratch`
- `src/workflows/mod.zig` now exports `RemoteSignerRequestContext`
- `examples/remote_signer_recipe.zig` now teaches the context shape directly
- `Z-BUFFER-001` is resolved
