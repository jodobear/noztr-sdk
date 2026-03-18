---
title: NIP-39 Runtime Policy Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_runtime_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Runtime Policy Plan

## Scope Delta

- Broaden the current remembered-identity workflow with one explicit runtime-policy helper above
  the caller-owned profile-store seam.
- Add:
  - one typed runtime action enum for remembered identities
  - one caller-owned runtime storage wrapper over freshness-classified discovery
  - one runtime plan that returns the discovered remembered entries plus the preferred action
  - one helper that classifies one provider identity as:
    - verify now
    - refresh existing
    - use preferred
    - use stale and refresh
- Keep hidden fetch, hidden refresh, autonomous provider discovery, eviction, and background loops
  out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- Runtime classification still uses remembered timestamps only; it does not prove live provider
  validity or fetch freshness.
- This slice still does not own autonomous discovery, background refresh, or store eviction.
- Telegram remains unsupported for full verification correctness.

## Slice-Specific Seam Constraints

- The profile-store seam remains explicit and caller-owned.
- Runtime inspection must remain a pure helper above stored records; it must not fetch or mutate
  state implicitly.
- The helper should reuse existing remembered discovery/freshness logic instead of introducing a
  parallel store index or background runtime layer.

## Slice-Specific Tests

- runtime policy returns `verify_now` when no remembered profile exists
- runtime policy returns `use_preferred` when a fresh remembered profile exists
- runtime policy returns `use_stale_and_refresh` when only stale entries exist and stale fallback
  is allowed
- runtime policy returns `refresh_existing` when only stale entries exist and fresh data is
  required
- the public recipe teaches explicit remembered-profile runtime inspection on the same identity
  workflow path

## Staged Execution Notes

1. Code: add runtime-policy types and one helper above freshness-classified remembered discovery.
2. Tests: prove missing, fresh, stale-fallback, and strict-refresh outcomes.
3. Example: extend the `NIP-39` recipe to inspect remembered runtime policy explicitly.
4. Review/audits: rerun `A-NIP39-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-identity-verifier-plan.md`
- Update `docs/plans/nip39-remembered-discovery-plan.md`
- Update `docs/plans/nip39-freshness-policy-plan.md`
- Update `docs/plans/nip39-discovery-freshness-plan.md`
- Update `docs/plans/nip39-preferred-selection-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `IdentityStoredProfileRuntimeAction`
- `IdentityStoredProfileRuntimeStorage`
- `IdentityStoredProfileRuntimeRequest`
- `IdentityStoredProfileRuntimePlan`
- `IdentityVerifier.inspectStoredProfileRuntime(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches explicit remembered
  runtime inspection over the same stored discovery surface

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `190/190`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit stale-profile refresh planning for this workflow now lives in
[nip39-refresh-plan.md](./nip39-refresh-plan.md).
