---
title: NIP-03 Runtime Policy Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [3]
read_when:
  - refining_nip03
  - broadening_opentimestamps_runtime_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP03-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-03 Runtime Policy Plan

## Scope Delta

- Broaden the current remembered-verification workflow with one explicit runtime-policy helper
  above the caller-owned verification-store seam.
- Add:
  - one typed runtime action enum for remembered verifications
  - one caller-owned runtime storage wrapper over freshness-classified discovery
  - one runtime plan that returns the discovered remembered verifications plus the preferred action
  - one helper that classifies one target event as:
    - verify now
    - refresh existing
    - use preferred
    - use stale and refresh
- Keep Bitcoin inclusion verification, chain-state refresh, hidden polling, and background proof
  management out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP03-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- Runtime classification still uses remembered attestation timestamps only; it does not prove live
  Bitcoin inclusion freshness or current chain state.
- This slice still does not own Bitcoin RPC/SPV verification, background refresh, or durable proof
  management.

## Slice-Specific Seam Constraints

- Local proof validation remains on `noztr.nip03_opentimestamps`.
- The remembered-verification store seam remains explicit and caller-owned.
- Runtime inspection must remain a pure helper above stored verification records; it must not fetch,
  revalidate, or mutate state implicitly.

## Slice-Specific Tests

- runtime policy returns `verify_now` when no remembered verification exists
- runtime policy returns `use_preferred` when a fresh remembered verification exists
- runtime policy returns `use_stale_and_refresh` when only stale remembered verifications exist and
  stale fallback is allowed
- runtime policy returns `refresh_existing` when only stale remembered verifications exist and
  fresh data is required
- the public recipe teaches explicit remembered-verification runtime inspection on the same proof
  workflow path

## Staged Execution Notes

1. Code: add runtime-policy types and one helper above freshness-classified remembered discovery.
2. Tests: prove missing, fresh, stale-fallback, and strict-refresh outcomes.
3. Example: extend the `NIP-03` recipe to inspect remembered runtime policy explicitly.
4. Review/audits: rerun `A-NIP03-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-03` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip03-opentimestamps-verifier-plan.md`
- Update `docs/plans/nip03-remote-proof-plan.md`
- Update `docs/plans/nip03-proof-store-plan.md`
- Update `docs/plans/nip03-remembered-verification-plan.md`
- Update `docs/plans/nip03-discovery-freshness-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `OpenTimestampsStoredVerificationFallbackPolicy`
- `OpenTimestampsStoredVerificationRuntimeAction`
- `OpenTimestampsStoredVerificationRuntimeStorage`
- `OpenTimestampsStoredVerificationRuntimeRequest`
- `OpenTimestampsStoredVerificationRuntimePlan`
- `OpenTimestampsVerifier.inspectStoredVerificationRuntime(...)`
- recipe coverage in `examples/nip03_verification_recipe.zig` now teaches explicit remembered proof
  runtime inspection over the same stored verification surface

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `194/194`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit stale-verification refresh planning for this workflow now lives in
[nip03-refresh-plan.md](./nip03-refresh-plan.md).
