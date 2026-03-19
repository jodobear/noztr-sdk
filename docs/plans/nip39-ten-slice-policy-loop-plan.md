---
title: NIP-39 Ten-Slice Long-Lived Policy Loop
doc_type: packet
status: active
owner: noztr-sdk
nips: [39]
read_when:
  - executing_the_next_autonomous_loop
  - broadening_long_lived_identity_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Ten-Slice Long-Lived Policy Loop

## Scope Delta

This loop turns the broader `NIP-39` long-lived policy lane into one bounded execution family.
It stays above the current remembered-profile helpers and does not add hidden background refresh or
implicit HTTP ownership.

The intended ten slices are:

1. add target-set request/storage types plus latest-freshness discovery across a caller-owned
   remembered target set
2. add a typed next-entry selector over that target-set latest-freshness view
3. add a typed next-step wrapper over that same target-set latest-freshness view
4. add preferred remembered-profile selection across a caller-owned target set
5. add refresh-candidate planning across a caller-owned target set
6. add a typed next refresh-candidate entry over that set plan
7. add a typed next refresh-candidate step over that set plan
8. add runtime policy across a caller-owned remembered target set
9. add typed next-entry driving over that target-set runtime plan
10. add typed next-step driving over that target-set runtime plan and close out the teaching/audit
    surface

This loop does not include:
- hidden background refresh loops
- implicit store scans without caller-owned target input
- implicit transport ownership
- provider verification changes in `noztr`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This loop is about broadening from one remembered identity at a time toward explicit multi-identity
policy, while keeping capacity and selection caller-owned and deterministic.

## Slice-Specific Proof Gaps

- The SDK can classify and prioritize remembered identities, but it still cannot guarantee liveness
  or provider truth beyond fetched proofs.
- Multi-identity policy here still depends on caller-owned watched-target input; it does not infer
  or enumerate every possible identity in a store.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and explicit
- target-set helpers must not hide store iteration beyond the caller-supplied watched target set
- no slice may add hidden polling, background queues, or implicit HTTP fetch ownership

## Slice-Specific Tests

- prove target-set helpers preserve caller-owned capacity
- prove stale/fresh ordering is deterministic across mixed target sets
- prove typed next-step helpers mirror the underlying set plan instead of changing policy
- prove examples make watched-target input and freshness windows explicit

## Staged Execution Notes

1. Code
- add only set-level helpers above the existing single-identity remembered-profile surfaces
- keep new types small and policy-carrying, not runtime-owning

2. Tests
- add direct mixed-target tests for every new helper
- prove storage pressure and inconsistent-store handling stay typed

3. Examples
- evolve the `NIP-39` recipe toward one explicit multi-identity remembered-policy flow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the loop removes real caller stitching instead of just renaming it

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep `handoff.md`, `docs/index.md`, audits, and `examples/README.md` aligned with the landed
  set-level helpers

## Progress

- slice 1 accepted on 2026-03-19:
  - `IdentityStoredProfileTarget`
  - `IdentityStoredProfileTargetLatestFreshnessStorage`
  - `IdentityStoredProfileTargetLatestFreshnessRequest`
  - `IdentityStoredProfileTargetLatestFreshnessEntry`
  - `IdentityVerifier.discoverLatestStoredProfileFreshnessForTargets(...)`
  - compatibility result: `green`
- slice 2 accepted on 2026-03-19:
  - `IdentityStoredProfileTargetLatestFreshnessPlan`
  - `IdentityVerifier.inspectLatestStoredProfileFreshnessForTargets(...)`
  - `IdentityStoredProfileTargetLatestFreshnessPlan.nextEntry()`
  - compatibility result: `green`
- slice 3 accepted on 2026-03-19:
  - `IdentityStoredProfileTargetLatestFreshnessStep`
  - `IdentityStoredProfileTargetLatestFreshnessPlan.nextStep()`
  - compatibility result: `green`
