---
title: NIP-39 Provider Details Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_provider_details
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

# NIP-39 Provider Details Plan

## Scope Delta

- Broaden the current `NIP-39` workflow from raw verification outcomes into provider-shaped
  identity details over verified profile claims.
- Add deterministic SDK-side provider adapters for:
  - GitHub
  - Twitter
  - Mastodon
  - Telegram
- Keep live provider fetches on the explicit HTTP seam and keep cache/trust-policy layers out of
  scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with a secondary Zig-native abstraction cleanup.

## Slice-Specific Proof Gaps

- Telegram remains unsupported for full verification correctness.
- The workflow still does not add cache/store integration or broader trust policy.
- Provider details are deterministic claim parsing, not provider-specific DOM verification.

## Slice-Specific Seam Constraints

- Claim extraction, proof URL derivation, and expected-text derivation remain on
  `noztr.nip39_external_identities`.
- Provider-detail parsing is an SDK adapter layer above validated claims.
- The explicit public HTTP seam remains unchanged.

## Slice-Specific Tests

- verified claims expose provider-specific details for GitHub and Mastodon profiles
- Telegram claims still expose deterministic provider details even when verification stays
  unsupported
- the summary can return only verified claims without re-parsing the whole event
- examples teach provider-shaped inspection over verified profile results

## Staged Execution Notes

1. Code: add provider-details types plus deterministic claim parsing over the verified profile
   results.
2. Tests: prove provider detail extraction for supported and unsupported providers.
3. Example: teach provider-detail inspection after `verifyProfile(...)`.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP39-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-identity-verifier-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-16:
- provider-shaped `IdentityProviderDetails`
- `IdentityClaimVerification.providerDetails(...)`
- `IdentityProfileVerificationSummary.verifiedClaims(...)`
- profile-oriented recipe coverage in `examples/nip39_verification_recipe.zig`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
