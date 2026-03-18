---
title: NIP-03 Discovery Freshness Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [3]
read_when:
  - refining_nip03
  - broadening_opentimestamps_workflow
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

# NIP-03 Discovery Freshness Plan

## Scope Delta

- Broaden the current remembered-verification workflow with one explicit freshness-classified
  discovery path over all stored verifications for a target event.
- Add:
  - one typed stored-verification freshness entry
  - one caller-owned storage wrapper for freshness-classified discovery
  - one helper that returns all remembered verifications plus fresh/stale classification
- Keep Bitcoin inclusion verification, hidden refresh, and durable proof/runtime policy out of
  scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP03-001`
- `Z-ABSTRACTION-001`

This is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- Freshness classification still uses remembered attestation timestamps only; it does not prove
  Bitcoin inclusion freshness or current chain state.
- This slice still does not own Bitcoin RPC/SPV verification, refresh loops, or durable proof
  strategy.

## Slice-Specific Seam Constraints

- Local proof validation remains on `noztr.nip03_opentimestamps`.
- The remembered-verification store seam remains explicit and caller-owned.
- Discovery freshness must remain a pure helper above stored verification summaries; it must not
  fetch, revalidate, or mutate state implicitly.

## Slice-Specific Tests

- stored verification discovery freshness returns all remembered verifications with fresh/stale
  classification
- freshness discovery preserves the remembered verification summary for each match
- missing remembered verifications return an empty result
- the public recipe teaches remembered verification discovery plus freshness classification on one
  explicit path

## Staged Execution Notes

1. Code: add freshness-classified stored-verification discovery types and one helper above the
   verification-store seam.
2. Tests: prove mixed fresh/stale remembered matches, preserved verification summaries, and empty
   results.
3. Example: extend the remembered verification recipe to classify discovered entries for one target
   event.
4. Review/audits: rerun `A-NIP03-001` and `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-03` packet chain, examples catalog, handoff, and discovery docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip03-opentimestamps-verifier-plan.md`
- Update `docs/plans/nip03-remote-proof-plan.md`
- Update `docs/plans/nip03-proof-store-plan.md`
- Update `docs/plans/nip03-remembered-verification-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/index.md`
- classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- `OpenTimestampsStoredVerificationFreshness`
- `OpenTimestampsStoredVerificationDiscoveryFreshnessEntry`
- `OpenTimestampsStoredVerificationDiscoveryFreshnessStorage`
- `OpenTimestampsStoredVerificationDiscoveryFreshnessRequest`
- `OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(...)`
- recipe coverage in `examples/nip03_verification_recipe.zig` now teaches freshness-classified
  remembered verification discovery on the same explicit public surface

Compatibility result:
- `green`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `177/177`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `93/93`

Follow-on explicit remembered runtime-policy inspection for this workflow now lives in
[nip03-runtime-policy-plan.md](./nip03-runtime-policy-plan.md).
