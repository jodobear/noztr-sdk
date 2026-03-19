---
title: NIP-39 Six-Slice Refresh Batch Loop
doc_type: packet
status: reference
owner: noztr-sdk
nips: [39]
read_when:
  - reviewing_the_next_identity_refresh_batch_loop
  - planning_broader_watched_target_refresh_selection
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip39-long-lived-policy-plan.md
  - docs/plans/nip39-six-slice-refresh-cadence-loop-plan.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Six-Slice Refresh Batch Loop

## Scope Delta

This is the next coherent execution loop under the active
[nip39-long-lived-policy-plan.md](./nip39-long-lived-policy-plan.md) parent packet.

`NIP-39` already has explicit watched-target discovery, policy, and refresh-cadence helpers.

What it still does not have is one explicit bounded batch-selection layer that lets an app choose
which watched identities to refresh in this turn under a caller-owned limit. Right now the SDK can
classify watched targets by cadence, but apps still need to rebuild the "selected now vs deferred
until later" batch split above that cadence surface.

The intended six slices are:

1. add bounded watched-target refresh-batch vocabulary and caller-owned storage
2. add `inspectStoredProfileRefreshBatchForTargets(...)`
3. add `nextBatchEntry()`
4. add `nextBatchStep()`
5. add grouped `selectedEntries()` and `deferredEntries()` views
6. close out the recipe, audits, and active docs around the broader watched-target refresh-batch
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

- The SDK can select a bounded refresh batch from watched targets, but it still cannot guarantee
  liveness or freshness without caller-owned scheduling and storage policy.
- It still cannot prove provider truth beyond the fetched proof documents.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- remembered identity state stays on caller-owned profile-store surfaces
- no slice may smuggle in hidden refresh/runtime ownership to make batch selection easier

## Slice-Specific Tests

- prove refresh batch selection stays deterministic and bounded by the caller-supplied limit
- prove due entries are selected before deferred entries in stable urgency order
- prove examples make watched-target refresh-batch preconditions explicit

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing watched-target cadence and remembered-profile surfaces
- prefer explicit bounded refresh batch selection over hidden autonomous loops

2. Tests
- cover mixed watched-target sets with selected and deferred due entries
- cover zero-capacity and over-capacity batch limits without hidden fallback behavior

3. Examples
- extend the `NIP-39` recipe only if the batch surface materially improves one watched-target
  refresh-driving flow

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`
- verify the batch layer removes real caller stitching instead of only renaming cadence buckets

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep this loop as the next likely execution packet under the active parent `NIP-39` plan until
  promoted
