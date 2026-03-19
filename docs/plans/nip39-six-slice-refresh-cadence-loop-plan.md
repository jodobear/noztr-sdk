---
title: NIP-39 Six-Slice Refresh Cadence Loop
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - reviewing_the_next_identity_refresh_policy_loop
  - planning_broader_watched_target_refresh_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/nip39-six-slice-target-policy-loop-plan.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Six-Slice Refresh Cadence Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md) parent packet.

`NIP-39` already has explicit watched-target discovery, preferred selection, refresh planning,
runtime inspection, and grouped watched-target policy buckets.

What it still does not have is one explicit refresh-cadence layer that lets an app classify a
watched identity set as:
- verify now
- refresh now
- usable while refreshing
- refresh soon
- stable

without taking hidden polling, HTTP ownership, or durable scheduling.

The intended six slices are:

1. add bounded watched-target refresh-cadence vocabulary and caller-owned storage
2. add `inspectStoredProfileRefreshCadenceForTargets(...)`
3. add `nextDueEntry()`
4. add `nextDueStep()`
5. add grouped `usableWhileRefreshingEntries()` and `refreshSoonEntries()` views
6. close out the recipe, audits, and active docs around the broader watched-target cadence surface

This loop does not include:
- hidden background refresh
- implicit HTTP ownership
- durable watched-target schedulers
- hidden daemon/runtime ownership

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can classify watched identities by explicit refresh cadence, but it still cannot
  guarantee freshness or liveness without caller-owned scheduling and storage policy.
- It still cannot prove provider truth beyond the fetched proof documents.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered identity state stays on caller-owned profile-store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make cadence policy easier

## Slice-Specific Tests

- prove cadence buckets stay deterministic and stable in caller order
- prove mixed fresh/stale/missing target sets classify into the correct cadence buckets
- prove examples make watched-target cadence preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing watched-target policy and remembered-profile surfaces
- prefer explicit cadence classification over hidden autonomous loops

2. Tests
- cover mixed watched-target sets with stable, refresh-soon, stale, and missing cases
- cover storage pressure on grouped cadence output

3. Examples
- extend the `NIP-39` recipe only if the cadence surface materially improves one watched-target
  refresh-driving flow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the cadence layer removes real caller stitching instead of only renaming current policy
  buckets

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the next likely execution packet under the active parent `NIP-39` plan until
  promoted

## Outcome

This loop is complete.

What landed:
- bounded watched-target refresh-cadence vocabulary and caller-owned storage
- `IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(...)`
- `IdentityStoredProfileTargetRefreshCadencePlan.nextDueEntry()`
- `IdentityStoredProfileTargetRefreshCadencePlan.nextDueStep()`
- `IdentityStoredProfileTargetRefreshCadencePlan.usableWhileRefreshingEntries()`
- `IdentityStoredProfileTargetRefreshCadencePlan.refreshSoonEntries()`
- recipe, audit, and active-doc closeout for the broader watched-target cadence surface

The loop materially reduced caller stitching above watched-target policy and refresh surfaces, but
it did not take hidden refresh scheduling, HTTP ownership, or daemon/runtime ownership.
`A-NIP39-001` and `Z-ABSTRACTION-001` stay open for broader autonomous discovery/refresh policy
above the current caller-owned watched-target inputs.

The active parent packet remains
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md).
