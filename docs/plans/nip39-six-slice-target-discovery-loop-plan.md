---
title: NIP-39 Six-Slice Target Discovery Loop
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - reviewing_the_next_identity_workflow_loop
  - planning_broader_identity_discovery_work
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/nip39-ten-slice-policy-loop-plan.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Six-Slice Target Discovery Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md) parent packet.

`NIP-39` already has watched-target helpers for:
- latest freshness
- preferred selection
- stale refresh planning
- runtime inspection
- typed next-entry and next-step selection

What it still does not have is one explicit multi-target remembered-discovery layer over caller-
owned storage. The current watched-target helpers mostly collapse each target down to one latest
entry. That is useful, but it still leaves broader multi-identity remembered discovery above the
SDK when an app needs more than one latest match per target.

This loop should add that broader discovery layer without taking hidden background ownership.

The intended six slices are:

1. add bounded multi-target discovery storage and grouped-result types above the current
   single-identity hydrated discovery surface
2. add `discoverStoredProfileEntriesForTargets(...)`
3. add `discoverStoredProfileEntriesWithFreshnessForTargets(...)`
4. add `getLatestStoredProfilesForTargets(...)`
5. add `getPreferredStoredProfilesForTargets(...)`
6. close out the recipe, audits, and active docs around the broader discovery surface

This loop does not include:
- hidden background refresh
- implicit HTTP ownership
- durable watched-target stores
- hidden priority daemons above remembered identity state

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can group remembered discovery over many watched identities, but it still cannot prove
  provider truth beyond fetched proof documents.
- It cannot guarantee freshness or completeness without caller-owned scheduling and storage
  policy.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered identity state stays on caller-owned profile-store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make target discovery easier

## Slice-Specific Tests

- prove grouped target discovery stays bounded by caller-owned matches and entry storage
- prove per-target grouping is deterministic and stable in caller order
- prove freshness classification remains explicit and does not hide stale/fresh fallback policy
- prove examples make watched-target discovery preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing remembered-profile discovery surfaces
- prefer grouped caller-owned discovery over hidden runtime ownership

2. Tests
- cover mixed multi-target discovery sets with empty, fresh, stale, and multi-match targets
- cover storage pressure and inconsistent-store handling on the grouped discovery path

3. Examples
- extend the `NIP-39` recipe only if the grouped discovery surface materially improves one
  real app-driving identity workflow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the grouped discovery layer removes real caller stitching instead of only restating
  existing latest-target helpers

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the likely next execution packet under the active parent `NIP-39` plan until
  promoted

## Outcome

This loop is complete.

What landed:
- bounded grouped multi-target remembered discovery vocabulary
- `IdentityVerifier.discoverStoredProfileEntriesForTargets(...)`
- `IdentityVerifier.discoverStoredProfileEntriesWithFreshnessForTargets(...)`
- `IdentityVerifier.getLatestStoredProfilesForTargets(...)`
- `IdentityVerifier.getPreferredStoredProfilesForTargets(...)`
- recipe, audit, and active-doc closeout for the broader watched-target discovery surface

The loop materially reduced caller stitching above remembered-profile stores, but it did not take
hidden refresh scheduling, HTTP ownership, or durable watched-target store ownership.
`A-NIP39-001` and `Z-ABSTRACTION-001` stay open for broader long-lived identity/discovery policy
above the current caller-owned watched-target inputs.

The active parent packet remains
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md).
