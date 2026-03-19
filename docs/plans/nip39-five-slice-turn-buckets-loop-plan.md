---
title: NIP-39 Five-Slice Turn Buckets Loop
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - executing_the_next_identity_turn_bucket_loop
  - broadening_watched_target_turn_views
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/nip39-six-slice-turn-policy-loop-plan.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Five-Slice Turn Buckets Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md) parent packet.

`NIP-39` now has one explicit watched-target turn-policy plan with:
- verify-now
- refresh-selected
- use-cached
- defer-refresh

What it still lacks is the final set of stable grouped accessors that let an app consume that plan
without re-slicing the same current-turn buckets above the SDK.

The intended five slices are:

1. add `verifyNowEntries()` over the watched-target turn-policy plan
2. add `refreshSelectedEntries()` over the watched-target turn-policy plan
3. add `workEntries()` over the watched-target turn-policy plan
4. add `idleEntries()` over the watched-target turn-policy plan
5. close out the recipe, audits, and active docs around the broader watched-target turn-bucket
   surface

This loop does not include:
- hidden background refresh
- implicit HTTP ownership
- durable watched-target schedulers
- hidden daemon/runtime ownership

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can expose stable current-turn bucket views, but it still cannot prove provider truth
  beyond the fetched proof documents.
- It still cannot guarantee liveness or freshness without caller-owned scheduling and storage
  policy.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered identity state stays on caller-owned profile-store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make turn-bucket consumption easier

## Slice-Specific Tests

- prove turn-bucket accessors preserve deterministic bucket ordering
- prove work buckets and idle buckets partition the same current-turn plan explicitly
- prove examples make watched-target turn-policy preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing watched-target turn-policy surface
- prefer explicit grouped accessors over hidden coordinator behavior

2. Tests
- cover mixed watched-target sets with each current-turn bucket present
- cover no-work and all-work boundary cases without hidden fallback behavior

3. Examples
- extend the `NIP-39` recipe only if the bucket views materially improve one watched-target
  identity-driving flow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the bucket views remove real caller slicing instead of only mirroring existing counts

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the next likely execution packet under the active parent `NIP-39` plan until
  promoted

## Outcome

This loop is complete.

It landed:
- `IdentityStoredProfileTargetTurnPolicyPlan.verifyNowEntries()`
- `IdentityStoredProfileTargetTurnPolicyPlan.refreshSelectedEntries()`
- `IdentityStoredProfileTargetTurnPolicyPlan.workEntries()`
- `IdentityStoredProfileTargetTurnPolicyPlan.idleEntries()`
- recipe, audit, and active-doc closeout for the broader watched-target turn-bucket surface

It still leaves the broader `NIP-39` long-lived policy gap open:
- no hidden autonomous discovery or refresh runtime
- no durable watched-target scheduler
- no HTTP ownership or background daemon policy

The active parent remains
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md).
