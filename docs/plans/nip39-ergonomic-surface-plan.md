---
title: Noztr SDK NIP-39 Ergonomic Surface Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 39
read_when:
  - refining_nip39
  - closing_z_buffer_001_for_nip39
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
target_findings:
  - Z-BUFFER-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Noztr SDK NIP-39 Ergonomic Surface Plan

Refinement packet for the `NIP-39` portion of `Z-BUFFER-001`.

Date: 2026-03-16

## Scope Delta

This slice changes the public `NIP-39` workflow shape so callers no longer pass three separate
temporary buffers directly into `IdentityVerifier.verifyClaim(...)`.

This slice does:
- add a small caller-owned storage wrapper for the `NIP-39` verifier
- add a small request wrapper that makes ownership explicit without hiding bounded storage
- update the recipe and tests to teach the wrapper shape first

This slice does not:
- broaden `NIP-39` into profile-wide or batch identity workflows
- add provider-specific parsing beyond the current accepted verifier floor
- widen the HTTP seam
- change the written Telegram proof-gap posture

Declared touchpoints:
- `touches_teaching_surface`: yes
- `touches_audit_state`: yes
- `touches_startup_docs`: yes

## Targeted Findings

- `Z-BUFFER-001`

This slice is Zig-native API/ergonomics shaping only.

## Slice-Specific Proof Gaps

Unchanged accepted gaps:
- Telegram remains intentionally unsupported until provider-specific verification exists
- the verifier still depends on caller-supplied HTTP behavior and does not prove redirect policy

No new proof claims are added by this slice.

## Slice-Specific Seam Constraints

- the HTTP seam remains the narrow public `noztr_sdk.transport.HttpClient`
- the verifier still classifies fetch failure, mismatch, and verified outcomes only
- the storage wrapper must stay caller-owned and bounded; it must not hide dynamic allocation

## Slice-Specific Tests

- existing `NIP-39` verifier behavior remains green through the new request/storage path
- wrapper shape is exported through `workflows`
- root smoke continues to expose only the intended public workflow surface

## Staged Execution Notes

- Stage 1 code:
  - add `IdentityVerificationStorage`
  - add `IdentityVerificationRequest`
  - move the primary verifier entrypoint to the wrapper shape
- Stage 2 tests:
  - update all verifier tests to the new request/storage path
  - keep existing outcome and error behavior coverage
- Stage 3 example:
  - update `examples/nip39_verification_recipe.zig` to teach the wrapper shape
- Stage 4 review and audits:
  - rerun the Zig-native audit against `Z-BUFFER-001`
  - confirm no product-surface claims changed
- Stage 5 docs and handoff:
  - update audits, examples catalog, build-plan/handoff/index/agent-brief as needed

## Closeout Checks

- update:
  - `src/workflows/identity_verifier.zig`
  - `src/workflows/mod.zig`
  - `src/root.zig`
  - `examples/nip39_verification_recipe.zig`
  - `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
  - `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md` if wording needs narrowing
  - `examples/README.md`
  - `handoff.md`
  - `docs/plans/build-plan.md`
  - `docs/index.md`
  - `agent-brief`
- rerun:
  - `zig build`
  - `zig build test --summary all`
  - local `noztr` compatibility check

## Accepted Slice

Implemented on 2026-03-16:
- `src/workflows/identity_verifier.zig` now exposes `IdentityVerificationStorage`
- `src/workflows/identity_verifier.zig` now exposes `IdentityVerificationRequest`
- the primary entrypoint is now `IdentityVerifier.verify(...)`
- the recipe in `examples/nip39_verification_recipe.zig` now teaches the wrapper shape first
- `Z-BUFFER-001` is narrowed to the remaining `NIP-46` and `NIP-05` surfaces
