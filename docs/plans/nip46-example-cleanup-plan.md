---
title: NIP-46 Example Cleanup Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [46]
read_when:
  - refining_nip46
  - cleaning_example_teaching_posture
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - Z-EXAMPLES-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-46 Example Cleanup Plan

## Scope Delta

- Improve the remote-signer recipe so it teaches the stable SDK path first instead of reading
  mainly like transcript plumbing.
- Add:
  - small local helper scaffolding inside the example for repetitive response wiring
  - a tighter flow that foregrounds session steps and public workflow methods
- Keep public API changes, hidden runtime ownership, and protocol behavior changes out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `Z-EXAMPLES-001`

This slice is teaching-surface cleanup only.

## Slice-Specific Proof Gaps

- The example remains compile-verified scaffolding, not a live relay integration.

## Slice-Specific Seam Constraints

- The recipe must keep explicit relay and response steps visible.
- Local helper scaffolding may reduce repetition, but it must not hide the SDK contract.

## Slice-Specific Tests

- the example still compiles and passes through the examples test lane
- the example now foregrounds connect, public-key discovery, and pubkey-text work before helper
  plumbing details

## Staged Execution Notes

1. Code: tighten the example flow and move repetitive response serialization into small helpers.
2. Tests: keep the examples lane green.
3. Review/audits: rerun `Z-EXAMPLES-001`.
4. Docs/closeout: update the examples catalog, audit wording, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md` only if packet discovery changes

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `examples/remote_signer_recipe.zig` now foregrounds the connect, public-key, and `nip44_encrypt`
  workflow path first
- repetitive response JSON wiring now sits in one small local helper instead of dominating the
  whole recipe

Verification:
- `/workspace/projects/nzdk`: `zig build test --summary all` with `204/204`
