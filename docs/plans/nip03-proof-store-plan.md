---
title: NIP-03 Proof Store Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [3]
read_when:
  - refining_nip03
  - broadening_opentimestamps_store_policy
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

# NIP-03 Proof Store Plan

## Scope Delta

- Broaden the current detached-proof workflow with one explicit caller-owned proof-store seam.
- Add:
  - a bounded proof-store seam keyed by proof URL
  - an in-memory reference proof store
  - `OpenTimestampsVerifier.verifyRemoteCached(...)` that reuses stored proof bytes before falling
    back to network fetch
- Keep Bitcoin RPC/esplora verification, proof freshness policy, hidden refresh loops, and durable
  backend integrations out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP03-001`
- `Z-ABSTRACTION-001`

This is product-surface broadening with secondary Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- This slice still does not prove Bitcoin inclusion or proof freshness.
- Stored proof bytes are keyed only by proof URL; they do not imply stronger trust than the proof
  contents themselves.
- The reference store is still bounded and in-memory; durable backend policy remains above this
  slice.

## Slice-Specific Seam Constraints

- Attestation extraction and local proof validation remain on `noztr.nip03_opentimestamps`.
- The HTTP seam remains explicit and caller-owned through `noztr_sdk.transport.HttpClient`.
- The proof store is explicit and caller-owned; no hidden global cache or background fetcher is
  introduced.
- The store owns detached proof bytes only; it does not own verification-policy decisions above
  those bytes.

## Slice-Specific Tests

- a cached remote verification reuses stored proof bytes without a second network fetch
- a cache miss fetches, stores, and then replays the proof deterministically on the next call
- malformed stored proof bytes still produce typed invalid-proof outcomes instead of fetch failures
- bounded store errors are surfaced as typed workflow errors
- the public recipe teaches detached-proof fetch plus cached replay on the same explicit surface

## Staged Execution Notes

1. Code: add proof-store types, in-memory store, and `verifyRemoteCached(...)`.
2. Tests: prove store hit, miss, invalid-proof replay, and bounded-store errors.
3. Example: teach one detached-proof fetch followed by one cached replay over the same public SDK
   surface.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP03-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-03` reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip03-opentimestamps-verifier-plan.md`
- Update `docs/plans/nip03-remote-proof-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-17:
- explicit `OpenTimestampsProofStore` seam
- `MemoryOpenTimestampsProofStore`
- `OpenTimestampsVerifier.verifyRemoteCached(...)`
- recipe coverage in `examples/nip03_verification_recipe.zig` now teaches detached-proof fetch plus
  stored-proof replay on the same explicit public surface

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `150/150`
- `/workspace/projects/noztr`: `known-upstream-failure-only` via
  `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  because the existing `nip46_remote_signing` overlong-input typed-error regression still hits a
  debug assertion upstream

Follow-on:
- the broader remembered-verification follow-up now lives in
  [nip03-remembered-verification-plan.md](./nip03-remembered-verification-plan.md)
- the explicit remembered runtime-policy follow-up now lives in
  [nip03-runtime-policy-plan.md](./nip03-runtime-policy-plan.md)
