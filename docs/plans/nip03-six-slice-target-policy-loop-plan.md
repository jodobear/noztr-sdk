---
title: NIP-03 Six-Slice Target Policy Loop
doc_type: packet
status: active
owner: noztr-sdk
nips: [3]
read_when:
  - executing_the_next_grouped_proof_loop
  - broadening_remembered_proof_target_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip03-long-lived-policy-plan.md
target_findings:
  - A-NIP03-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-03 Six-Slice Target Policy Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip03-long-lived-policy-plan.md](./nip03-long-lived-policy-plan.md) parent packet.

`NIP-03` already has explicit per-target remembered verification freshness, preferred selection,
runtime inspection, and refresh planning.

What it still does not have is one explicit grouped target-policy layer that lets an app work over
multiple remembered proof targets in one bounded pass.

The intended six slices are:

1. add grouped remembered-proof target vocabulary and caller-owned storage
2. add `discoverLatestStoredVerificationFreshnessForTargets(...)`
3. add `getPreferredStoredVerificationForTargets(...)`
4. add `planStoredVerificationRefreshForTargets(...)`
5. add grouped refresh `nextEntry()` and `nextStep()`
6. close out the recipe, audits, and active docs around the broader grouped proof-policy surface

This loop does not include:
- hidden background refresh
- implicit HTTP ownership
- durable proof schedulers
- hidden daemon/runtime ownership

## Targeted Findings

- `A-NIP03-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can classify grouped remembered proof policy, but it still cannot prove blockchain truth
  beyond the explicit proof and attestation material the caller provides.
- It still cannot guarantee liveness or freshness without caller-owned scheduling and storage
  policy.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered proof state stays on caller-owned proof and verification store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make grouped proof selection easier

## Slice-Specific Tests

- prove grouped remembered-proof helpers stay deterministic in caller order
- prove grouped refresh planning stays caller-bounded
- prove examples make grouped proof preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-03` only above the existing remembered-proof surfaces
- prefer explicit grouped planning helpers over hidden runtime ownership

2. Tests
- cover mixed fresh/stale/missing proof target sets
- cover grouped storage pressure and store inconsistency handling

3. Examples
- extend the `NIP-03` recipe only if the grouped proof surface materially improves one remembered
  proof-driving flow

4. Review and audit reruns
- re-evaluate `A-NIP03-001` and `Z-ABSTRACTION-001`

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the next likely execution packet under the active parent `NIP-03` plan until
  promoted
