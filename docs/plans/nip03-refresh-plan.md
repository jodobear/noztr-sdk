---
title: NIP-03 Refresh Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [3]
read_when:
  - refining_nip03
  - broadening_opentimestamps_refresh_policy
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

# NIP-03 Refresh Plan

## Scope Delta

- Broaden the current remembered-verification workflow with one explicit refresh-plan helper above
  the caller-owned verification-store seam.
- Add:
  - one typed refresh entry for stale remembered verifications
  - one caller-owned refresh storage wrapper
  - one refresh plan that returns all stale remembered verifications for one target event
- Keep hidden proof fetch, hidden Bitcoin verification, durable proof mutation, and background
  refresh loops out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP03-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- Refresh planning still uses remembered attestation timestamps only; it does not prove live
  Bitcoin inclusion freshness.
- The helper will identify stale remembered verifications to refresh, but it will not fetch or
  mutate them.
- Broader Bitcoin verification and durable proof strategy remain above this slice.

## Slice-Specific Seam Constraints

- The remembered-verification store seam remains explicit and caller-owned.
- Refresh planning must reuse the existing freshness-classified remembered discovery path.
- The helper must not introduce hidden proof fetch, validation, or store mutation.

## Slice-Specific Tests

- refresh planning returns only stale remembered verifications for one target event
- refresh planning returns an empty result when all remembered verifications are fresh
- refresh planning preserves newest-first ordering for stale entries
- the public recipe teaches explicit refresh planning above remembered runtime inspection

## Staged Execution Notes

1. Code: add refresh-plan types and one helper above freshness-classified remembered discovery.
2. Tests: prove stale-only filtering, empty fresh result, and entry ordering.
3. Example: extend the `NIP-03` recipe to plan refresh after remembered runtime inspection.
4. Review/audits: rerun `A-NIP03-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-03` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip03-remembered-verification-plan.md`
- Update `docs/plans/nip03-discovery-freshness-plan.md`
- Update `docs/plans/nip03-runtime-policy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `OpenTimestampsStoredVerificationRefreshEntry`
- `OpenTimestampsStoredVerificationRefreshStorage`
- `OpenTimestampsStoredVerificationRefreshRequest`
- `OpenTimestampsStoredVerificationRefreshPlan`
- `OpenTimestampsVerifier.planStoredVerificationRefresh(...)`
- recipe coverage in `examples/nip03_verification_recipe.zig` now teaches explicit stale-proof
  refresh planning above remembered runtime inspection

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `204/204`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`
