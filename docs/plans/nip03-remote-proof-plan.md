---
title: NIP-03 Remote Proof Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [3]
read_when:
  - refining_nip03
  - broadening_opentimestamps_retrieval
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP03-001
  - Z-EXAMPLES-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-03 Remote Proof Plan

## Scope Delta

- Broaden the current local-only verifier with one explicit detached-proof fetch-and-verify path
  over the public HTTP seam.
- Add:
  - `OpenTimestampsRemoteProofRequest`
  - `OpenTimestampsVerifier.verifyRemote(...)`
  - typed detached-proof fetch outcomes
- Keep Bitcoin RPC/esplora verification, caches, and background proof refresh policy out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP03-001`
- `Z-EXAMPLES-001`

This is product-surface broadening with a small teaching-surface refinement.

## Slice-Specific Proof Gaps

- This slice still proves only the local proof floor, not remote Bitcoin inclusion or freshness.
- The detached proof URL is fully caller-owned; the SDK does not infer or discover it.
- Cache/store policy for fetched proofs remains above this slice.

## Slice-Specific Seam Constraints

- Attestation extraction and local proof validation stay on `noztr.nip03_opentimestamps`.
- The HTTP seam remains explicit and caller-owned through `noztr_sdk.transport.HttpClient`.
- The fetched proof document is treated as raw detached proof bytes, not as a hidden transport or
  Bitcoin-client runtime.

## Slice-Specific Tests

- fetch and verify one detached proof document successfully
- classify detached proof fetch failures as typed outcomes
- classify malformed detached proof documents without collapsing into fetch failures
- keep local verifier tests green after hardening the attestation test fixture ownership
- update the public recipe to teach detached proof fetch plus verify

## Staged Execution Notes

1. Code: add remote proof request/result types and `verifyRemote(...)`.
2. Tests: prove detached proof fetch success, fetch failure, and malformed proof classification.
3. Example: teach one explicit detached-proof fetch-and-verify flow over the public HTTP seam.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP03-001` and
   `Z-EXAMPLES-001`.
5. Docs/closeout: update the `NIP-03` reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip03-opentimestamps-verifier-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-17:
- `OpenTimestampsRemoteProofRequest`
- `OpenTimestampsVerifier.verifyRemote(...)`
- typed detached-proof `verified`, `target_mismatch`, `invalid_attestation`,
  `invalid_local_proof`, and `fetch_failed` outcomes
- recipe coverage in `examples/nip03_verification_recipe.zig` now teaches one detached proof
  document fetched and verified over the explicit HTTP seam

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `137/137`
- `/workspace/projects/noztr`: compatibility rerun currently blocked by the unrelated open
  `nip46_remote_signing` overlong-input regression logged in `docs/plans/noztr-feedback-log.md`

Follow-on:
- the broader proof-workflow follow-up now lives in
  [nip03-proof-store-plan.md](./nip03-proof-store-plan.md)
  and [nip03-remembered-verification-plan.md](./nip03-remembered-verification-plan.md)
  plus [nip03-runtime-policy-plan.md](./nip03-runtime-policy-plan.md)
