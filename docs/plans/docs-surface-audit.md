---
title: Docs Surface Audit
doc_type: audit
status: active
owner: noztr-sdk
posture: docs-discoverability
read_when:
  - refining_process
  - reducing_doc_bloat_without_losing_rigor
  - updating_control_docs
---

# Docs Surface Audit

Audit posture: docs/discoverability and control-surface drift.

Question:
Can an agent or maintainer find the current rules and next work quickly without reconciling stale or
contradictory control docs by hand?

## Findings

### DOC-ORDER-001

- Status: fixed in this pass
- Problem:
  `docs/plans/implementation-quality-gate.md` currently contains two different execution-order
  narratives: the staged implementation micro-loop and a later default workflow ordering.
- Why it hurts:
  the canonical gate is supposed to remove ambiguity, not require the reader to infer which
  ordering is pre-implementation and which is implementation/closeout.
- Fix:
  the gate now distinguishes the full default lane from the staged implementation micro-loop
  explicitly instead of presenting them as competing sequences.

### DOC-ORDER-002

- Status: fixed in this pass
- Problem:
  `docs/plans/build-plan.md` still contains an older review/documentation workflow sequence that no
  longer matches the current gate precisely.
- Why it hurts:
  the execution baseline and the gate can disagree about what “the process” means.
- Fix:
  `build-plan.md` now points at the gate for execution order and keeps only baseline framing.

### DOC-STATE-001

- Status: fixed in this pass
- Problem:
  `handoff.md` still describes the `NIP-17` workflow floor as mailbox intake even though the
  current shipped slice also includes outbound direct-message initiation.
- Why it hurts:
  the state doc should be self-consistent at a glance.
- Fix:
  `handoff.md` now describes `NIP-17` as a mailbox session rather than intake-only.

### DOC-ROUTING-001

- Status: fixed in this pass
- Problem:
  `docs/plans/build-plan.md` names `nip29-sync-store-plan.md` as the active broader workflow packet
  while `handoff.md` says the next lane is still a choice across multiple refinement targets.
- Why it hurts:
  “active lane” routing is not single-sourced yet.
- Fix:
  `build-plan.md` now treats `nip29-sync-store-plan.md` as a reference packet for when that lane is
  selected rather than claiming it is the current active packet.

### DOC-BOOTSTRAP-001

- Status: fixed in this pass
- Problem:
  `AGENTS.md` still contains bootstrap-era wording about the pre-scaffold toolchain posture.
- Why it hurts:
  startup docs should reflect current repo reality, not preserved bootstrap context.
- Fix:
  the stale pre-scaffold toolchain note was removed from `AGENTS.md`.

### DOC-AUDIT-001

- Status: fixed in this pass
- Problem:
  `docs/index.md` lists the LLM-agent audit as active, but the current refinement gate binds
  closure only to the applesauce and Zig-native audits.
- Why it hurts:
  “active” can overstate the control role of a posture that is not yet part of the required
  refinement loop.
- Fix:
  `docs/index.md` now keeps the LLM-agent audit under supporting audits instead of active-control
  audits.

### DOC-ROUTING-002

- Status: fixed in this pass
- Problem:
  `AGENTS.md` and `agent-brief` had become packet catalogs again, duplicating workflow-chain
  discovery already owned by `docs/index.md` plus current-lane routing from `handoff.md`.
- Why it hurts:
  startup docs should carry startup rules, not make a fresh reader scan long packet inventories
  before they even know the active slice.
- Fix:
  `AGENTS.md` and `agent-brief` now route workflow-packet discovery back through `docs/index.md`
  and `handoff.md` instead of restating the packet chains inline.

### DOC-BASELINE-001

- Status: fixed in this pass
- Problem:
  `docs/plans/build-plan.md` had drifted into a hybrid of execution baseline, milestone history,
  packet inventory, tradeoff log, and process recap.
- Why it hurts:
  an active execution-baseline doc should answer what controls work now, not force the reader to
  sort current routing from historical baseline material.
- Fix:
  `build-plan.md` is now trimmed to execution baseline, routing, canonical defaults, commands, and
  reference pointers only. Historical and packet-inventory detail no longer live there.
