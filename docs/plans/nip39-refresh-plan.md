---
title: NIP-39 Refresh Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_refresh_policy
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

# NIP-39 Refresh Plan

## Scope Delta

- Broaden the current remembered-identity workflow with one explicit refresh-plan helper above the
  caller-owned profile-store seam.
- Add:
  - one typed refresh entry for stale remembered profiles
  - one caller-owned refresh storage wrapper
  - one refresh plan that returns all stale remembered entries for one provider identity
- Keep hidden fetch, hidden refresh execution, autonomous discovery, eviction, and background loops
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

- Refresh planning still uses remembered timestamps only; it does not prove live provider validity.
- The helper will identify stale entries to refresh, but it will not fetch or mutate them.
- Autonomous provider discovery and longer-lived eviction policy remain above this slice.

## Slice-Specific Seam Constraints

- The profile-store seam remains explicit and caller-owned.
- Refresh planning must reuse the existing freshness-classified remembered discovery path.
- The helper must not introduce hidden network or store side effects.

## Slice-Specific Tests

- refresh planning returns only stale remembered profiles for one provider identity
- refresh planning returns an empty result when all remembered profiles are fresh
- refresh planning preserves matched-claim details and newest-first ordering for stale entries
- the public recipe teaches explicit refresh planning above remembered discovery/runtime policy

## Staged Execution Notes

1. Code: add refresh-plan types and one helper above freshness-classified remembered discovery.
2. Tests: prove stale-only filtering, empty fresh result, and entry ordering.
3. Example: extend the `NIP-39` recipe to plan refresh after remembered runtime inspection.
4. Review/audits: rerun `A-NIP39-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-remembered-discovery-plan.md`
- Update `docs/plans/nip39-discovery-freshness-plan.md`
- Update `docs/plans/nip39-preferred-selection-plan.md`
- Update `docs/plans/nip39-runtime-policy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `IdentityStoredProfileRefreshEntry`
- `IdentityStoredProfileRefreshStorage`
- `IdentityStoredProfileRefreshRequest`
- `IdentityStoredProfileRefreshPlan`
- `IdentityVerifier.planStoredProfileRefresh(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches explicit stale-profile
  refresh planning above remembered runtime inspection

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `204/204`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`
