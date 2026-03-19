---
title: NIP-39 Six-Slice Turn Policy Loop
doc_type: packet
status: active
owner: noztr-sdk
nips: [39]
read_when:
  - executing_the_next_identity_policy_loop
  - broadening_watched_target_turn_selection
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/nip39-six-slice-refresh-batch-loop-plan.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Six-Slice Turn Policy Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md) parent packet.

`NIP-39` already has explicit watched-target policy, refresh cadence, and bounded refresh-batch
selection.

What it still does not have is one explicit current-turn policy layer that tells an app:
- which watched identities must be verified now
- which watched identities should be refreshed in this turn
- which watched identities are usable from remembered state right now
- which watched identities are refresh-deferred until a later turn

Right now apps still need to combine the watched-target policy and refresh-batch surfaces by hand to
derive that current-turn view.

The intended six slices are:

1. add watched-target turn-policy vocabulary and caller-owned storage
2. add `inspectStoredProfileTurnPolicyForTargets(...)`
3. add `nextWorkEntry()`
4. add `nextWorkStep()`
5. add grouped `useCachedEntries()` and `deferredEntries()` views
6. close out the recipe, audits, and active docs around the broader watched-target turn-policy
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

- The SDK can classify one current turn over watched targets, but it still cannot prove provider
  truth beyond the fetched proof documents.
- It still cannot guarantee liveness or freshness without caller-owned scheduling and storage
  policy.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered identity state stays on caller-owned profile-store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make turn selection easier

## Slice-Specific Tests

- prove current-turn action selection stays deterministic and bounded
- prove selected work is exposed before deferred work
- prove examples make watched-target turn-policy preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing watched-target policy and refresh-batch surfaces
- prefer explicit current-turn helpers over hidden autonomous loops

2. Tests
- cover mixed watched-target sets with verify-now, refresh-selected, use-cached, and deferred
  outcomes
- cover zero-selected and over-capacity turn selection without hidden fallback behavior

3. Examples
- extend the `NIP-39` recipe only if the turn-policy surface materially improves one watched-target
  refresh-driving flow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the turn-policy layer removes real caller stitching instead of only renaming existing
  batch buckets

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the next likely execution packet under the active parent `NIP-39` plan until
  promoted
