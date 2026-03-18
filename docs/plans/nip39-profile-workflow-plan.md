---
title: NIP-39 Profile Workflow Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_workflow
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

# NIP-39 Profile Workflow Plan

## Scope Delta

- Broaden `IdentityVerifier` from one-claim verification into profile-event claim extraction plus
  batch verification.
- Add:
  - `IdentityProfileVerificationStorage`
  - `IdentityProfileVerificationRequest`
  - `IdentityProfileVerificationSummary`
  - `IdentityClaimVerification`
  - `IdentityClaimVerificationOutcome`
- Keep transport explicit and caller-owned through the public HTTP seam.
- Keep provider-specific DOM parsing, identity caches, retries, and trust-policy layers out of
  scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This is product-surface broadening with a secondary Zig-native abstraction cleanup.

## Slice-Specific Proof Gaps

- Telegram still remains unsupported as a fully verified provider.
- Batch verification still uses deterministic containment checks rather than provider-specific DOM
  or API semantics.
- No cache or trust-policy layer is introduced in this slice.

## Slice-Specific Seam Constraints

- The batch workflow still depends on the explicit public `transport.HttpClient` seam.
- Claim extraction, proof URL derivation, and expected-text derivation must stay on
  `noztr.nip39_external_identities`.
- Unsupported providers must be classified explicitly rather than treated as verified.

## Slice-Specific Tests

- profile verification extracts multiple ordered claims from a kind-10011 event
- batch verification classifies verified and mismatch claims independently
- unsupported providers are reported inside profile verification rather than aborting the whole
  workflow
- fetch failures are reported per claim inside profile verification
- invalid identity events still propagate the authoritative `noztr` error

## Staged Execution Notes

1. Code: add profile verification storage/request/result types and batch verification.
2. Tests: prove ordered extraction, per-claim outcomes, unsupported classification, and fetch
   failure handling.
3. Example: teach one identity profile event verified over the explicit HTTP seam.
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
- `IdentityVerifier.verifyProfile(...)`
- profile-event claim extraction over `noztr.nip39_external_identities.identity_claims_extract(...)`
- per-claim typed `verified`, `mismatch`, `fetch_failed`, and `unsupported` classification
- caller-owned profile verification storage and results
- updated profile-oriented example coverage in `examples/nip39_verification_recipe.zig`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `128/128`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `87/87`
