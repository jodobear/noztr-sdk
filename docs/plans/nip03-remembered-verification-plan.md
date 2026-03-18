---
title: NIP-03 Remembered Verification Plan
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

# NIP-03 Remembered Verification Plan

## Scope Delta

- Broaden the current detached-proof and proof-store workflow with one explicit remembered-
  verification store seam.
- Add:
  - a bounded caller-owned remembered-verification store keyed by attestation event id
  - one explicit `verifyRemoteCachedAndRemember(...)` helper for the common fetch-or-reuse plus
    remember path
  - stored-verification discovery and latest-match helpers keyed by target event id
- Keep Bitcoin inclusion verification, proof freshness policy, hidden refresh loops, and autonomous
  background verification out of scope.

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
- Remembered verification records summarize prior successful verification over one detached proof
  URL; they do not upgrade the trust model above the original attestation plus proof bytes.
- Durable backend strategy remains caller-owned; only a bounded in-memory reference store is added
  here.

## Slice-Specific Seam Constraints

- Attestation extraction and local proof validation remain on `noztr.nip03_opentimestamps`.
- The HTTP seam remains explicit and caller-owned through `noztr_sdk.transport.HttpClient`.
- Proof bytes remain on the existing explicit `OpenTimestampsProofStore` seam.
- The remembered-verification store owns only summary records; it does not own proof bytes or
  background verification policy.

## Slice-Specific Tests

- `verifyRemoteCachedAndRemember(...)` stores one verified detached proof outcome through the new
  remembered-verification seam
- remembered discovery can hydrate stored verification entries by target event id
- newest remembered verification is selected deterministically by attestation event timestamp
- non-verified remote outcomes do not populate the remembered-verification store
- bounded store and discovery buffer errors surface as typed workflow errors
- the public recipe teaches verify, remember, discovery, and replay on one explicit workflow path

## Staged Execution Notes

1. Code: add remembered-verification store types, in-memory reference store, combined
   `verifyRemoteCachedAndRemember(...)`, and discovery/latest helpers.
2. Tests: prove verified remember, non-verified no-store behavior, hydrated discovery, newest-match
   lookup, and bounded-store errors.
3. Example: teach one detached-proof verification that is remembered explicitly, then discovered
   again through the stored-verification surface without hidden runtime state.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP03-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-03` reference packet chain, examples catalog, handoff, and
   startup routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip03-opentimestamps-verifier-plan.md`
- Update `docs/plans/nip03-remote-proof-plan.md`
- Update `docs/plans/nip03-proof-store-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md` only if routing changes materially
- Update `docs/index.md`
- Update `AGENTS.md` only if startup routing changes materially
- Update `agent-brief` only if startup routing changes materially
- Classify the local `noztr` compatibility rerun result explicitly

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- explicit `OpenTimestampsVerificationStore` seam
- `MemoryOpenTimestampsVerificationStore`
- `OpenTimestampsVerifier.verifyRemoteCachedAndRemember(...)`
- stored-verification discovery and latest-match helpers keyed by target event id
- recipe coverage in `examples/nip03_verification_recipe.zig` now teaches verify, remember, and
  latest remembered verification lookup on one explicit workflow path

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `165/165`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  with `93/93`

Follow-on freshness-classified remembered-discovery broadening for this workflow now lives in
[nip03-discovery-freshness-plan.md](./nip03-discovery-freshness-plan.md).

Follow-on explicit remembered runtime-policy inspection for this workflow now lives in
[nip03-runtime-policy-plan.md](./nip03-runtime-policy-plan.md).
