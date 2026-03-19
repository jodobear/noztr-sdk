---
title: Process Control
doc_type: policy
status: active
owner: noztr-sdk
read_when:
  - refining_process
  - reducing_doc_bloat_without_losing_rigor
  - updating_control_docs
---

# Process Control

Repo-specific rules for keeping `noztr-sdk` rigorous without letting the control docs drift into
append-only history.

## Core Rule

Do not treat a process change as additive by default.

When the process changes materially:
1. identify the affected control docs
2. review them together as one control surface
3. remove or rewrite superseded guidance
4. add only the minimum new wording that still needs to exist
5. verify the startup path, templates, and state docs now agree

The goal is not to preserve every past phrasing. The goal is to preserve one coherent current
process.

One accepted slice should also become one git commit.
Do not rely on `handoff.md`, packet docs, or chat history as a substitute for per-slice git
checkpoints.

When a major loop or packet family closes, restoring one explicit next active packet is part of
steady-state closeout.
Do not leave the repo between packets after a major closeout.

## Control Surface Roles

- `index`
  - discovery and doc routing
- `policy`
  - canonical local rules and gates
- `state`
  - current lane, next work, and active gaps
- `packet`
  - slice-specific execution context
- `audit`
  - posture-specific findings with stable IDs
- `log`
  - ongoing issue or feedback tracking
- `reference`
  - accepted background and reusable guidance
- `archive`
  - historical provenance, not startup guidance

## Canonical Owners

- [docs/index.md](../index.md)
  - discovery and doc routing
- [AGENTS.md](../../AGENTS.md)
  - session startup and operating rules
- [handoff.md](../../handoff.md)
  - current state, next work, and active gaps
- [build-plan.md](../plans/build-plan.md)
  - execution baseline and active-lane framing
- [implementation-quality-gate.md](../plans/implementation-quality-gate.md)
  - canonical implementation and refinement gate
- [packet-template.md](../plans/packet-template.md)
  - slice-packet structure

If another active doc starts owning one of those roles, slim it or reclassify it.

## Repo-Specific Audit Postures

`noztr-sdk` should keep audits posture-specific instead of using one vague quality pass.

The canonical lane map now lives in [audit-lanes.md](../plans/audit-lanes.md).

Current always-on postures stay:
- product-surface posture
- Zig-native posture
- docs/discoverability posture

Current required review lanes inside the gate stay:
- misuse/invalid-input
- boundary/ownership
- example/contract

Choose or revise lanes from real repo failure modes, not elegance.

## Stable Finding IDs

Audits and docs-surface reviews should use stable finding IDs.

Suggested pattern:
- `<posture>-<area>-<number>` for workflow or product audits
- `DOC-<area>-<number>` for docs-surface audits

The exact spelling matters less than keeping findings reusable across packets, handoff, and
follow-up work.

## Reconciliation Rule

When a process refinement lands:
- do not only append new bullets
- re-read the affected active docs together
- remove stale sequencing, stale phase wording, and superseded temporary guidance
- keep the full rule in one canonical owner
- keep the other docs pointing at that owner rather than paraphrasing it at length

Typical affected docs:
- `AGENTS.md`
- `handoff.md`
- `docs/plans/build-plan.md`
- `docs/plans/implementation-quality-gate.md`
- `docs/plans/packet-template.md`
- `agent-brief`

When the refinement comes from a real escaped bug class:
- add one narrow prompt, checklist item, or audit question that would have caught it
- prefer that over broader cautionary prose
- record the generalized lesson in
  [PROCESS_REFINEMENT_PLAYBOOK.md](./PROCESS_REFINEMENT_PLAYBOOK.md) only if it is worth sharing
  outside this repo

## High-Impact Audit Rule

For a high-impact hardening, cleanup, or pre-release audit program:
1. define the audit angles explicitly
2. keep one coverage ledger for what is and is not being checked
3. finish the angle reports first
4. do one explicit synthesis or meta-analysis
5. only then choose remediation

Do not let local micro-fixes replace the evidence-gathering phase when the real question is whether
the repo needs targeted fixes, a bounded redesign, or a broader rewrite.

## Steady-State Rule

After a process refinement:
- startup docs should still be lean
- packets should stay delta-oriented
- audits should reflect the live state, not pre-fix wording
- historical narrative should move to archive, reference docs, audit history, or git history
- completed slices should not accumulate uncommitted; cut the slice commit before starting the next
  accepted slice when feasible

If the repo needs a long explanation to understand the current rule, the control surface is not yet
steady.

## Docs-Surface Audit Rule

Keep one lightweight audit of the docs surface and process-control drift with stable finding IDs.

Use it when:
- the startup path feels heavy again
- active docs disagree about the current process
- a process change seems additive instead of reconciled
- control-surface drift is found during review

The audit should track:
- contradiction
- stale startup wording
- duplicate control ownership
- unnecessary repetition
- routing ambiguity

## Minimal Rule For Future Changes

When a new process lesson appears, prefer:
- one narrow rule in the canonical owner
- one matching template adjustment, if needed
- one audit update, if it changed the docs surface

Avoid:
- restating the same rule in every active doc
- leaving the old wording in place “for context”
- turning handoff or build-plan into process-history dumps

## Transfer Rule

If a process lesson is mature enough to teach another repo or agent:
- keep the canonical local rule in [PROCESS_CONTROL.md](./PROCESS_CONTROL.md)
- capture the reusable lesson in
  [PROCESS_REFINEMENT_PLAYBOOK.md](./PROCESS_REFINEMENT_PLAYBOOK.md)
- keep the playbook as reference, not as a second local process owner
