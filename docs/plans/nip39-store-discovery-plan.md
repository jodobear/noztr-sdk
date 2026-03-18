---
title: NIP-39 Store Discovery Plan
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

# NIP-39 Store Discovery Plan

## Scope Delta

- Add one explicit identity-profile store layer above the current `NIP-39` verifier/cache slices.
- Add:
  - a caller-owned profile-store seam
  - an in-memory reference store
  - one explicit store-write helper for verified profile summaries
  - one provider-plus-identity lookup helper over stored verified claims
- Keep live provider fetches, redirect policy, hidden background discovery, and provider-specific DOM
  parsing out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This slice is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- Stored discovery still only reflects previously verified profile summaries; it is not autonomous
  network discovery.
- The store is bounded and in-memory in this reference slice; longer-lived store strategy remains
  above the current workflow.
- Telegram remains unsupported for full verification correctness and therefore should not appear as
  a verified stored claim through the normal verifier path.

## Slice-Specific Seam Constraints

- Claim extraction, proof URL derivation, expected-text derivation, and claim validation remain on
  `noztr.nip39_external_identities`.
- The store only records verified claims plus summary counters; mismatches and fetch failures are
  retained as counts, not as discoverable identities.
- Discovery stays explicit and caller-driven through a provider-plus-identity query; no hidden
  background scan or network expansion is introduced.

## Slice-Specific Tests

- verified profile summaries can be stored and later discovered by provider-plus-identity
- mismatched claims are not discoverable from the store
- stale older summaries for the same pubkey do not overwrite newer stored state
- summaries with too many verified claims for the bounded store are rejected
- the public example teaches verify, remember, and discover on the same explicit surface

## Staged Execution Notes

1. Code: add profile-store types, in-memory reference store, and explicit remember/discover helpers.
2. Tests: prove storage, stale-summary rejection, discovery behavior, and bounded-claim rejection.
3. Example: teach one verified profile stored and later discovered by provider identity.
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

Implemented and reviewed on 2026-03-17:
- explicit `IdentityProfileStore` seam
- `MemoryIdentityProfileStore`
- `IdentityVerifier.rememberProfileSummary(...)`
- `IdentityVerifier.getStoredProfile(...)`
- `IdentityVerifier.discoverStoredProfiles(...)`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches verify, remember,
  discover, and cached replay on the same explicit public surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `140/140`
- `/workspace/projects/noztr`: later compatibility reruns are green again after the upstream
  remediation sync

## Follow-On Slice

Longer-lived remembered-profile broadening for this workflow now lives in
[nip39-remembered-discovery-plan.md](./nip39-remembered-discovery-plan.md).

Freshness-policy broadening for that remembered path now lives in
[nip39-freshness-policy-plan.md](./nip39-freshness-policy-plan.md).

Freshness-classified remembered-discovery broadening for that workflow now lives in
[nip39-discovery-freshness-plan.md](./nip39-discovery-freshness-plan.md).
