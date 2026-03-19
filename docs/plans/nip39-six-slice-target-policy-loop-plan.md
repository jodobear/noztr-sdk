---
title: NIP-39 Six-Slice Target Policy Loop
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - reviewing_the_next_identity_policy_loop
  - planning_broader_watched_target_policy_work
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/nip39-six-slice-target-discovery-loop-plan.md
  - docs/plans/nip39-ten-slice-policy-loop-plan.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Six-Slice Target Policy Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md) parent packet.

`NIP-39` already has explicit watched-target helpers for:
- grouped remembered discovery
- grouped freshness-classified discovery
- latest-per-target selection
- preferred-per-target selection
- watched-target freshness inspection
- watched-target refresh planning
- watched-target runtime inspection

What it still does not have is one explicit grouped policy layer that lets an app consume a watched
target set as stable action buckets instead of only as one selected next step or raw grouped
entries. The current surfaces are good for bounded driving, but longer-lived identity policy still
requires apps to regroup targets by action above the SDK.

This loop should add that grouped policy layer without taking hidden refresh scheduling, HTTP
ownership, or daemon/runtime ownership.

The intended six slices are:

1. add bounded watched-target policy-group vocabulary and caller-owned storage above the current
   watched-target runtime surface
2. add `inspectStoredProfilePolicyForTargets(...)`
3. add one explicit grouped usable-preferred view for watched targets
4. add one explicit grouped verify-now view for watched targets
5. add one explicit grouped refresh-needed view for watched targets
6. close out the recipe, audits, and active docs around the broader watched-target policy surface

This loop does not include:
- hidden background refresh
- implicit HTTP ownership
- durable watched-target stores
- hidden priority daemons above remembered identity state

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

## Slice-Specific Proof Gaps

- The SDK can group watched identities by explicit action posture, but it still cannot guarantee
  freshness or liveness without caller-owned scheduling and storage policy.
- It still cannot prove provider truth beyond the fetched proof documents.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered identity state stays on caller-owned profile-store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make watched-target policy easier

## Slice-Specific Tests

- prove grouped policy buckets stay deterministic and stable in caller order
- prove mixed fresh/stale/missing target sets classify into the correct buckets
- prove examples make watched-target policy preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing watched-target runtime and remembered-profile surfaces
- prefer grouped policy buckets over hidden autonomous loops

2. Tests
- cover mixed watched target sets with usable, missing, stale, and verify-now cases
- cover storage pressure on grouped policy output

3. Examples
- extend the `NIP-39` recipe only if the grouped policy surface materially improves one real
  watched-target driving flow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the grouped policy layer removes real caller stitching instead of only renaming current
  next-step helpers

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the next likely execution packet under the active parent `NIP-39` plan until
  promoted
