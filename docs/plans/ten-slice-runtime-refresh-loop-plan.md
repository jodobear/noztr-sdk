---
title: Ten-Slice Runtime And Refresh Loop Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [17, 3, 39, 29]
read_when:
  - selecting_the_next_autonomous_loop
  - planning_bounded_refresh_runtime_and_consistency_driving_helpers
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP17-001
  - A-NIP03-001
  - A-NIP39-001
  - A-NIP29-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Ten-Slice Runtime And Refresh Loop Plan

## Closeout

Completed on 2026-03-19.

Accepted slice commits:
- `08a73b5` `Add NIP-39 refresh next-entry helper`
- `57b8d09` `Add NIP-39 typed refresh step view`
- `e36b616` `Add NIP-03 latest freshness helper`
- `7525576` `Add NIP-03 preferred verification helper`
- `7f35c9f` `Add NIP-03 refresh next-entry helper`
- `1607e1a` `Add NIP-03 typed refresh step view`
- `3fa18bb` `Add NIP-17 typed runtime step view`
- `09eece5` `Add NIP-17 delivery role selectors`
- `0e5b4e1` `Add NIP-29 consistency next-entry helper`
- `f946bb3` `Add NIP-29 typed consistency step view`

## Scope Delta

This loop follows the completed selector and step-view loops. It does not add hidden background
runtime ownership. Instead it fills a narrower product gap: callers still have to do too much
manual driving around remembered refresh, mailbox runtime stepping, and fleet consistency
inspection.

The intended ten slices are:

1. `NIP-39`: add `IdentityStoredProfileRefreshPlan.nextEntry()`.
2. `NIP-39`: add `IdentityStoredProfileRefreshStep` plus `nextStep()`.
3. `NIP-03`: add latest remembered-verification freshness classification.
4. `NIP-03`: add preferred remembered-verification selection with explicit stale fallback.
5. `NIP-03`: add `OpenTimestampsStoredVerificationRefreshPlan.nextEntry()`.
6. `NIP-03`: add `OpenTimestampsStoredVerificationRefreshStep` plus `nextStep()`.
7. `NIP-17`: add `MailboxRuntimeStep` plus `MailboxRuntimePlan.nextStep()`.
8. `NIP-17`: add typed recipient-only and sender-copy-only delivery-step selectors.
9. `NIP-29`: add `GroupFleetConsistencyReport.nextEntry()`.
10. `NIP-29`: add `GroupFleetConsistencyStep` plus `nextStep()`.

This loop does not include:
- hidden polling or subscription loops
- autonomous refresh execution
- transport ownership changes
- broader durable-store changes
- hidden merge heuristics
- new upstream `noztr` kernel work unless a real exact-fit seam gap appears mid-slice

## Targeted Findings

- `A-NIP17-001`
- `A-NIP03-001`
- `A-NIP39-001`
- `A-NIP29-001`
- `Z-WORKFLOWS-001`
- `Z-ABSTRACTION-001`

This loop is primarily about converting “callers can inspect a bounded plan” into “callers can
drive the next bounded step directly” on the remaining remembered-refresh and consistency surfaces.

## Slice-Specific Proof Gaps

- These helpers can only package or classify existing bounded plan/state decisions.
- They cannot prove liveness, fetch success, mailbox delivery completion, or fleet convergence.
- They do not remove the remaining open product gaps around fuller mailbox sync, broader groups
  background runtime, or autonomous identity/proof discovery policy.
- If a slice would require hidden retained state or implicit side effects to stay useful, stop and
  record it as a broader workflow gap instead of smuggling hidden runtime into the helper.

## Slice-Specific Seam Constraints

- All new helpers must remain pure over existing caller-owned plan, request, or storage data.
- No slice may add hidden network effects, store mutation, or transport ownership.
- No slice may invent a new priority policy beyond the currently documented plan semantics.
- `noztr` remains the owner of deterministic parsing, validation, and event building.

## Slice-Specific Tests

- `NIP-39`: prove refresh selection remains newest-first and the typed step mirrors that entry.
- `NIP-03`: prove latest freshness, preferred selection, and refresh-step semantics all mirror the
  existing remembered-verification policy.
- `NIP-17`: prove runtime and delivery step helpers mirror the current priority semantics and do
  not reorder relays.
- `NIP-29`: prove consistency-step helpers mirror the existing divergence report order and keep the
  baseline context explicit.

## Staged Execution Notes

1. Code:
- add only bounded helpers above existing plans or discovery surfaces
- keep the new types small and context-carrying, not policy-owning

2. Tests:
- add direct tests for every new helper
- prove existing order/priority semantics do not change

3. Examples:
- update touched recipes to use the new helpers where they make the control flow clearer
- keep workflow preconditions explicit

4. Review and audit reruns:
- re-evaluate `A-NIP17-001`, `A-NIP03-001`, `A-NIP39-001`, `A-NIP29-001`,
  `Z-WORKFLOWS-001`, and `Z-ABSTRACTION-001`
- verify that each helper removes real caller stitching instead of just renaming the same manual
  work

5. Docs and handoff closeout:
- keep one commit per accepted slice
- update examples catalog and handoff when the teaching surface changes
- classify the `noztr` compatibility rerun as `green`, `known-upstream-failure-only`, or
  `new-upstream-pressure`

## Why This Loop Is High Confidence

- every slice is SDK-local
- every slice extends an already-landed bounded surface instead of inventing a subsystem
- most slices are symmetric across already-proven `NIP-39` / `NIP-03` / `NIP-17` / `NIP-29`
  patterns
- the loop improves app-driving ergonomics without forcing hidden background runtime decisions
