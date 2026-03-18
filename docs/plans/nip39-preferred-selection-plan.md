---
title: NIP-39 Preferred Selection Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_selection_policy
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

# NIP-39 Preferred Selection Plan

## Scope Delta

- Broaden the current remembered-identity workflow with one explicit stored-profile selection
  policy helper.
- Add:
  - one typed fallback policy for stale remembered profiles
  - one typed preferred remembered-profile result
  - one helper that selects the preferred remembered profile for one provider identity under a
    freshness window
- Keep hidden refresh, autonomous provider discovery, provider-specific DOM parsing, and store
  mutation out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary abstraction shaping.

## Slice-Specific Proof Gaps

- Preferred selection still uses remembered timestamps only; it does not prove live provider
  validity.
- This slice still does not own autonomous refresh, eviction, or background discovery.
- Telegram remains unsupported for full verification correctness.

## Slice-Specific Seam Constraints

- The profile-store seam remains explicit and caller-owned.
- Preferred selection must be a pure helper above stored records; it must not fetch or mutate
  state implicitly.
- The helper should reuse existing remembered discovery/freshness logic instead of introducing a
  parallel store index.

## Slice-Specific Tests

- preferred selection returns the newest fresh remembered profile when one exists
- preferred selection can fall back to the newest stale remembered profile when allowed
- preferred selection returns `null` when freshness is required and no fresh profile exists
- the public recipe teaches explicit remembered-profile preference selection after discovery

## Staged Execution Notes

1. Code: add preferred-selection types and one helper above the profile-store seam.
2. Tests: prove fresh preference, stale fallback, and strict-fresh rejection.
3. Example: extend the `NIP-39` recipe to select one preferred remembered profile explicitly.
4. Review/audits: rerun `A-NIP39-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-identity-verifier-plan.md`
- Update `docs/plans/nip39-remembered-discovery-plan.md`
- Update `docs/plans/nip39-freshness-policy-plan.md`
- Update `docs/plans/nip39-discovery-freshness-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `IdentityStoredProfileFallbackPolicy`
- `IdentityPreferredStoredProfileRequest`
- `IdentityPreferredStoredProfile`
- `IdentityVerifier.getPreferredStoredProfile(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches explicit preferred
  remembered-profile selection under a freshness window and stale-fallback policy

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `182/182`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit remembered runtime-policy inspection for this workflow now lives in
[nip39-runtime-policy-plan.md](./nip39-runtime-policy-plan.md).
