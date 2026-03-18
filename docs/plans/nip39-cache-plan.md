---
title: NIP-39 Cache Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - refining_nip39
  - broadening_identity_cache_policy
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

# NIP-39 Cache Plan

## Scope Delta

- Add one explicit verification-cache layer to `IdentityVerifier` for profile verification.
- Add:
  - a caller-owned cache seam for deterministic `proof_url + expected_text` verification outcomes
  - an in-memory reference cache implementation
  - cached profile verification entrypoints and summary counters
- Keep transport explicit and caller-owned.
- Keep provider-specific DOM parsing, hidden trust policy, and background identity discovery out of
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

- Telegram remains unsupported for full verification correctness.
- Cached outcomes are deterministic reuse of previously computed verification matches; they are not
  stronger trust semantics than the original verification path.
- This slice still does not add broader provider/discovery policy beyond explicit verification and
  cache reuse.

## Slice-Specific Seam Constraints

- Claim extraction, proof URL derivation, and expected-text derivation stay on
  `noztr.nip39_external_identities`.
- The cache seam must be explicit and caller-owned; no hidden global cache is introduced.
- Cache writes should not silently broaden trust beyond previously verified or mismatched results.

## Slice-Specific Tests

- repeated profile verification can reuse cached verified/mismatch outcomes without network fetches
- cache misses still fall back to network fetches and populate the cache
- Telegram remains unsupported in the cached path too
- cached summary counters distinguish cache hits from network fetches
- the public example shows one profile verification followed by one cached replay

## Staged Execution Notes

1. Code: add cache seam, memory cache, and cached profile verification entrypoints.
2. Tests: prove cache hit, miss, population, and unsupported-provider behavior.
3. Example: teach one profile verification followed by one cached verification over the same public
   SDK surface.
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
- explicit `IdentityVerificationCache` seam with caller-owned `MemoryIdentityVerificationCache`
- cached profile verification via `IdentityVerifier.verifyProfileCached(...)`
- summary counters for `cache_hit_count` and `network_fetch_count`
- recipe coverage in `examples/nip39_verification_recipe.zig` now teaches one network verification
  followed by one cached replay over the same public surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `132/132`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `1096/1096`
