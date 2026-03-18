---
title: Noztr SDK LLM-Agent Audit
doc_type: audit
status: reference
owner: noztr-sdk
posture: llm-agent
read_when:
  - evaluating_agent_discoverability
  - changing_teaching_posture
---

# Noztr SDK LLM-Agent Audit

Audit date: 2026-03-15

Scope:
- `AGENTS.md`
- `agent-brief`
- `handoff.md`
- `README.md`
- `examples/README.md`
- `src/root.zig`
- `src/workflows/mod.zig`
- `docs/plans/implementation-quality-gate.md`
- `docs/plans/examples-tree-plan.md`
- applesauce reference structure under `/workspace/pkgs/nostr/applesauce`

## Summary

`noztr-sdk` is already better than a raw codebase from an LLM-agent perspective because it has:
- strong startup instructions
- an explicit ownership matrix
- a narrow public root
- compile-verified examples
- handoff and planning docs that make boundary decisions explicit

It is not yet as structured as applesauce for agents.

The main difference is not protocol quality. It is discoverability:
- applesauce has a real docs plus examples navigation layer
- applesauce has agent-oriented documentation and MCP search posture
- our repo still expects an agent to cross-reference several docs manually to find the right recipe
  or next lane

## Findings

### 1. Medium: no single example catalog mapped the public SDK surface to the examples tree

Observed friction:
- an agent had to read `README.md`, `examples/README.md`, and `src/workflows/mod.zig` together to
  answer “what is public and where is the matching recipe?”
- applesauce is materially ahead here because its examples are indexed through a manifest-like
  layer and broader docs navigation

Resolution in this pass:
- tighten `examples/README.md` into the canonical examples catalog
- require examples/catalog updates in the implementation gate

### 2. Medium: example authoring expectations were implicit rather than forced by the gate

Observed friction:
- the existing quality gate covered examples generally, but not the concrete failure modes already
  seen in this repo:
  - over-generalized example helpers
  - fixture key/pubkey mismatch risk
  - examples that could accidentally teach internal seams

Resolution in this pass:
- add explicit example structure requirements to
  [implementation-quality-gate.md](./implementation-quality-gate.md)
- backfill those rules into [examples-tree-plan.md](./examples-tree-plan.md)

### 3. Low: startup guidance did not yet point agents directly at the next broader `NIP-29` packet

Observed friction:
- after the first examples slice, an agent still had to infer that the next real lane was broader
  `NIP-29` work from `handoff.md` and the earlier evaluation doc

Resolution in this pass:
- add the dedicated broader `NIP-29` packet to startup/current-lane docs

## Assessment Versus Applesauce

No, the current `noztr-sdk` examples are not yet as structured as applesauce.

Applesauce is ahead in:
- docs-site integration
- manifest/index style example discovery
- explicit agent-oriented onboarding and search posture

`noztr-sdk` is now credible but still earlier-stage:
- smaller compile-verified recipe pack
- explicit workflow boundary
- no docs-site integration
- no search/index layer beyond the repo docs and examples catalog

That is acceptable for the current repo stage, but only if we keep improving:
- startup pointers
- examples catalog quality
- agent-facing mapping from public workflows to recipes and active plans

## Accepted Direction

Short term:
- keep the examples tree narrow and precise
- make `examples/README.md` the canonical recipe catalog
- keep startup docs pointing at the active packet and the examples floor

Later, when the SDK surface grows:
- consider a richer examples manifest or docs-site posture
- consider agent-searchable docs/examples infrastructure if the repo volume starts to justify it
