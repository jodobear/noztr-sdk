---
title: NIP-17 Six-Slice Workflow Loop
doc_type: packet
status: reference
owner: noztr-sdk
nips: [17]
read_when:
  - reviewing_the_next_mailbox_workflow_loop
  - planning_broader_mailbox_runtime_work
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/nip17-runtime-plan.md
  - docs/plans/nip17-file-send-plan.md
target_findings:
  - A-NIP17-001
  - Z-WORKFLOWS-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-17 Six-Slice Workflow Loop

## Scope Delta

This loop is the next likely broader `NIP-17` lane after the active `NIP-29` background-runtime
work closes.

It stays above the current mailbox runtime inspection, delivery planning, typed next-step
selectors, and file-message send/intake surfaces. The goal is to give callers one clearer
workflow-driving layer without crossing into hidden mailbox daemons, relay subscription ownership,
or transport control.

The intended six slices are:

1. add bounded mailbox workflow action and entry types above the current runtime and delivery
   surfaces
2. add `inspectWorkflow(...)` with caller-owned storage and one explicit workflow plan over
   runtime state plus pending send/receive work
3. add `MailboxWorkflowPlan.nextEntry()`
4. add `MailboxWorkflowPlan.nextStep()`
5. add `selectWorkflowRelay(...)` for one explicit next relay/action choice
6. close out the recipe, audits, and active docs around the broader mailbox workflow surface

This loop does not include:
- hidden polling or subscription loops
- transport ownership
- persistent inbox cursors or mailbox stores
- automatic receive or publish side effects

## Targeted Findings

- `A-NIP17-001`
- `Z-WORKFLOWS-001`

## Slice-Specific Proof Gaps

- The SDK can classify the next mailbox workflow step, but it still cannot guarantee liveness or
  inbox completion without caller-owned scheduling and relay I/O.
- Delivery policy and receive cadence remain explicit caller choices above the loop.

## Slice-Specific Seam Constraints

- all new helpers must stay caller-bounded and side-effect free
- the loop may read runtime and delivery-plan state, but it must not perform receive, auth, or
  publish side effects itself
- no slice may smuggle in hidden mailbox daemons, subscriptions, or store ownership

## Slice-Specific Tests

- prove workflow helpers preserve deterministic relay ordering
- prove mixed connect/authenticate/receive/publish cases stay explicit and side-effect free
- prove examples make relay hydration and sender-copy assumptions explicit

## Staged Execution Notes

1. Code
- add only bounded workflow-driving helpers above the current mailbox runtime and delivery-plan
  surfaces

2. Tests
- cover mixed relay states, sender-copy delivery, and receive-vs-publish choices without hidden
  side effects

3. Examples
- extend the mailbox recipe only if the new surface materially improves one-step app-driving
  control

4. Review and audit reruns
- re-evaluate `A-NIP17-001` and `Z-WORKFLOWS-001`
- verify the loop removes real caller stitching instead of just renaming it

5. Docs and handoff closeout
- keep one commit per accepted slice
- promote this packet to active only when the current `NIP-29` lane closes
