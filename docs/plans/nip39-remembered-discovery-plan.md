---
title: NIP-39 Remembered Discovery Plan
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

# NIP-39 Remembered Discovery Plan

## Scope Delta

- Broaden the current `NIP-39` workflow from explicit verification plus separate remember/discover
  calls into a more complete remembered-identity path.
- Add:
  - one explicit verify-and-remember helper above the current cache and profile-store seams
  - one hydrated stored-discovery helper that returns stored profile records directly instead of
    only `pubkey + created_at` matches
  - one latest-match helper for the common remembered-identity lookup path
- Keep transport, cache, and profile-store ownership explicit and caller-owned.
- Keep hidden background discovery, provider-specific DOM parsing, and trust-policy expansion out of
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

- Telegram remains unsupported for full verification correctness.
- Stored discovery still reflects only previously verified profile summaries; it is not autonomous
  network discovery.
- The store seam remains explicit and bounded; this slice does not introduce hidden persistence or
  background sync.

## Slice-Specific Seam Constraints

- Claim extraction, proof URL derivation, expected-text derivation, and claim validation remain on
  `noztr.nip39_external_identities`.
- The cache seam and profile-store seam remain caller-owned and explicit.
- Hydrated discovery must not bypass store boundaries with hidden global indexing or implicit fetch.

## Slice-Specific Tests

- verify-and-remember stores one newly verified profile and reports the store outcome
- hydrated discovery returns stored profile records directly for a provider-plus-identity lookup
- latest-match discovery prefers the newest stored profile for the requested provider identity
- mismatched claims remain non-discoverable through the remembered-profile workflow
- examples teach verify, remember, and direct stored discovery on the same explicit surface

## Staged Execution Notes

1. Code: add verify-and-remember plus hydrated discovery helpers above the current cache/store
   seams.
2. Tests: prove store write outcome, hydrated lookup, newest-match selection, and mismatch
   exclusion.
3. Example: teach one profile verification remembered and discovered through the higher-level
   workflow.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP39-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-39` reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip39-identity-verifier-plan.md`
- Update `docs/plans/nip39-store-discovery-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md` only if the active lane routing changes
- Update `docs/index.md` only if packet discovery changes
- Update `AGENTS.md` and `agent-brief` only if startup routing changes

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `IdentityVerifier.verifyProfileCachedAndRemember(...)`
- `IdentityStoredProfileDiscoveryEntry`
- `IdentityStoredProfileDiscoveryStorage`
- `IdentityStoredProfileDiscoveryRequest`
- `IdentityLatestStoredProfileRequest`
- `IdentityVerifier.discoverStoredProfileEntries(...)`
- `IdentityVerifier.getLatestStoredProfile(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches verify, remember,
  hydrated stored discovery, and cached replay on the same explicit public surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `157/157`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on:
- freshness-policy broadening for the remembered profile path now lives in
  [nip39-freshness-policy-plan.md](./nip39-freshness-policy-plan.md)
- freshness-classified remembered-discovery broadening for the remembered profile path now lives in
  [nip39-discovery-freshness-plan.md](./nip39-discovery-freshness-plan.md)
- explicit preferred remembered-profile selection for the remembered profile path now lives in
  [nip39-preferred-selection-plan.md](./nip39-preferred-selection-plan.md)
- explicit remembered runtime-policy inspection for the remembered profile path now lives in
  [nip39-runtime-policy-plan.md](./nip39-runtime-policy-plan.md)
