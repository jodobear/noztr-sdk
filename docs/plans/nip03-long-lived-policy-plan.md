---
title: NIP-03 Long-Lived Policy Plan
doc_type: packet
status: active
owner: noztr-sdk
nips: [3]
read_when:
  - selecting_the_next_broader_proof_slice
  - broadening_remembered_proof_policy
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

# NIP-03 Long-Lived Policy Plan

## Status

This broader lane is active after the recent `NIP-39` watched-target loop family closeout.

## Scope Delta

`NIP-03` already has explicit detached-proof fetch, remembered verification storage, freshness
classification, preferred remembered-verification selection, remembered runtime inspection, refresh
planning, and typed next-step helpers.

The remaining gap is broader long-lived proof policy:
- explicit multi-proof remembered policy above the current per-target helpers
- explicit current-turn proof refresh/verification selection without hidden background loops
- broader remembered-proof views that make stored-proof workflow feel like an app-facing SDK layer

This packet is the next broader product lane above the current remembered-proof helpers.

This lane should not:
- add hidden background polling
- add implicit HTTP ownership
- add hidden durable caches beyond caller-owned proof and verification stores
- move Bitcoin/proof verification into `noztr`

## Targeted Findings

- `A-NIP03-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can classify remembered proof policy, but it still cannot prove blockchain truth beyond
  the explicit proof and attestation material the caller provides.
- It cannot guarantee liveness or freshness without caller-owned scheduling and storage policy.

## Slice-Specific Seam Constraints

- HTTP stays an explicit caller-owned seam through `noztr_sdk.transport`.
- Remembered proof state stays on caller-owned proof and verification store surfaces.
- No slice may invent hidden daemon/runtime ownership just to make proof selection easier.

## Slice-Specific Tests

- prove any new remembered-proof selection helper remains caller-bounded
- prove stale/fresh ordering is explicit and deterministic
- prove examples make remembered-proof preconditions explicit instead of relying on hidden state

## Staged Execution Notes

1. Code
- broaden `NIP-03` only above the existing remembered-proof surfaces
- prefer explicit multi-proof planning helpers over hidden runtime ownership

2. Tests
- cover mixed fresh/stale remembered proof sets
- cover storage pressure and inconsistent-store handling on the broader helper path

3. Examples
- teach one broader remembered-proof policy flow without implying hidden background refresh

4. Review and audit reruns
- re-evaluate `A-NIP03-001` and `Z-ABSTRACTION-001`

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep the packet chain and examples catalog aligned with the broadened proof surface
