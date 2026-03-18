---
title: NIP-39 Discovery Freshness Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_store_discovery
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

# NIP-39 Discovery Freshness Plan

## Scope Delta

- Broaden the current remembered-identity workflow from one latest-match freshness helper into one
  explicit remembered-discovery path that classifies all stored matches as fresh or stale.
- Add:
  - one typed stored-discovery freshness entry
  - one caller-owned storage wrapper for freshness-classified discovery
  - one helper that returns hydrated remembered matches plus freshness classification on one path
- Keep hidden refresh, autonomous provider discovery, eviction policy, and store mutation out of
  scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- Freshness classification still uses remembered event timestamps only; it does not prove live
  provider validity.
- This slice still does not own autonomous refresh, eviction, or hidden background discovery.
- Telegram remains unsupported for full verification correctness.

## Slice-Specific Seam Constraints

- The profile-store seam remains explicit and caller-owned.
- Discovery freshness must remain a pure helper above stored records; it must not fetch or mutate
  state implicitly.
- The helper should reuse the existing remembered-profile discovery path instead of introducing a
  parallel indexing layer.

## Slice-Specific Tests

- stored discovery freshness returns all remembered matches with fresh/stale classification
- stored discovery freshness preserves the matched claim details for each remembered entry
- missing remembered profiles return an empty result, not `null`
- the public recipe teaches hydrated remembered discovery plus freshness classification on the same
  explicit surface

## Staged Execution Notes

1. Code: add freshness-classified stored-discovery types and one helper above the profile-store
   seam.
2. Tests: prove mixed fresh/stale remembered matches, matched-claim preservation, and empty
   results.
3. Example: extend the remembered profile recipe to classify discovered entries for one provider
   identity.
4. Review/audits: rerun `A-NIP39-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-identity-verifier-plan.md`
- Update `docs/plans/nip39-store-discovery-plan.md`
- Update `docs/plans/nip39-remembered-discovery-plan.md`
- Update `docs/plans/nip39-freshness-policy-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `IdentityStoredProfileDiscoveryFreshnessEntry`
- `IdentityStoredProfileDiscoveryFreshnessStorage`
- `IdentityStoredProfileDiscoveryFreshnessRequest`
- `IdentityVerifier.discoverStoredProfileEntriesWithFreshness(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches freshness-classified
  remembered discovery on the same explicit public surface

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `175/175`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit preferred remembered-profile selection for this workflow now lives in
[nip39-preferred-selection-plan.md](./nip39-preferred-selection-plan.md).

Follow-on explicit remembered runtime-policy inspection for this workflow now lives in
[nip39-runtime-policy-plan.md](./nip39-runtime-policy-plan.md).
