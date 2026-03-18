---
title: NIP-39 Freshness Policy Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_freshness_policy
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

# NIP-39 Freshness Policy Plan

## Scope Delta

- Broaden the current remembered-identity workflow with one explicit freshness-policy helper over
  the latest stored profile for a provider identity.
- Add:
  - one typed freshness enum for remembered profiles
  - one latest-stored-profile freshness request/result surface
  - one helper that returns the latest remembered profile plus freshness classification
- Keep hidden background refresh, autonomous provider discovery, and store eviction policy out of
  scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- Freshness classification uses stored event timestamps only; it does not prove the profile is still
  valid on the provider side.
- This slice still does not own autonomous refresh behavior or durable eviction policy.
- Telegram remains unsupported for full verification correctness.

## Slice-Specific Seam Constraints

- The profile-store seam remains explicit and caller-owned.
- Freshness policy must stay a pure SDK helper above stored records; it must not fetch or mutate
  state implicitly.
- The helper should reuse the existing latest stored profile path instead of introducing a parallel
  discovery stack.

## Slice-Specific Tests

- latest stored profile freshness returns `fresh` when the remembered profile age is within the
  requested max age
- latest stored profile freshness returns `stale` when the remembered profile age exceeds the
  requested max age
- missing stored profiles still return `null`
- the public recipe teaches remembered profile lookup plus freshness classification on the same
  explicit surface

## Staged Execution Notes

1. Code: add freshness types and one latest remembered-profile freshness helper.
2. Tests: prove fresh, stale, and missing behavior.
3. Example: extend the remembered profile recipe to classify the latest stored profile as fresh or
   stale explicitly.
4. Review/audits: rerun `A-NIP39-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` packet chain, examples catalog, handoff, and startup
   discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-identity-verifier-plan.md`
- Update `docs/plans/nip39-store-discovery-plan.md`
- Update `docs/plans/nip39-remembered-discovery-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- Classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `IdentityStoredProfileFreshness`
- `IdentityLatestStoredProfileFreshnessRequest`
- `IdentityLatestStoredProfileFreshness`
- `IdentityVerifier.getLatestStoredProfileFreshness(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches remembered profile
  freshness classification on the same explicit public surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `170/170`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  with `93/93`

Follow-on remembered-discovery freshness broadening for this workflow now lives in
[nip39-discovery-freshness-plan.md](./nip39-discovery-freshness-plan.md).

Follow-on explicit preferred remembered-profile selection for this workflow now lives in
[nip39-preferred-selection-plan.md](./nip39-preferred-selection-plan.md).

Follow-on explicit remembered runtime-policy inspection for this workflow now lives in
[nip39-runtime-policy-plan.md](./nip39-runtime-policy-plan.md).
