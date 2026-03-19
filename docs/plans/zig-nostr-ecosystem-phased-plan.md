---
title: Zig Nostr Ecosystem Phased Plan
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - triaging_major_work
  - ordering_multi_repo_execution
  - deciding_what_to_build_next
depends_on:
  - docs/plans/zig-nostr-ecosystem-readiness-matrix.md
  - docs/plans/build-plan.md
---

# Zig Nostr Ecosystem Phased Plan

This doc turns the ecosystem readiness target into execution order.

It is not a packet for one implementation slice. It is the triage and prioritization map for the
larger effort:

- `noztr`
- `noztr-sdk`
- CLI tooling
- signer tooling
- relay framework
- high-performance relay
- Blossom
- later client/product foundations

## Triage Rule

When choosing work, prefer the item that most improves the next major product layer.

That means:

- do not keep refining an already-usable local workflow if the next major product still lacks a
  more important foundation
- do not optimize for NIP count
- do not optimize for narrow ergonomic polish over missing architecture

## Current Strategic Priority

The next highest-value gap is:

- shared `noztr-sdk` client/runtime/store architecture

Why:

- CLI v1 needs it
- signer tooling needs it
- relay-framework integration points will be cleaner if the SDK runtime model is explicit first

So current narrow refinement lanes should usually pause unless they close a real blocker for that
architecture or the first tools.

## Phase Order

### Phase 1. SDK Architecture Baseline

Goal:

- make `noztr-sdk` ready to support real tools and products

Must define:

- relay pool model
- subscription/sync posture
- reconnect/retry posture
- background runtime ownership
- durable store boundary
- event/query/index posture
- how existing workflow-specific runtime helpers compose into one broader client model

Primary output:

- one accepted architecture packet

### Phase 2. SDK Readiness Closeout For Tooling

Goal:

- finish only the SDK gaps that block the first tools

Primary focus:

- `NIP-17` mailbox runtime/sync posture as needed by tools
- `NIP-46` signer workflow completeness as needed by tools
- `NIP-03` / `NIP-39` only where tool use actually depends on them

Rule:

- do not resume deeper `NIP-03` / `NIP-39` helper refinement unless it directly supports the
  first tool/product wave

### Phase 3. Zig CLI Tool

Goal:

- first broad product on top of `noztr` + `noztr-sdk`

Expected scope:

- inspect/query/publish/sign/verify
- relay interaction
- signer interaction
- scripting-friendly output
- operator/debug value

Why first:

- pressure-tests the SDK broadly
- gives immediate utility
- creates the tooling spine for later product work

### Phase 4. Signer Tooling/Product

Goal:

- usable signer product and related tooling on top of the existing `NIP-46` base

Expected scope:

- usable runtime/session/auth flow
- CLI and/or service posture
- practical developer/operator flow

### Phase 5. Relay Framework

Goal:

- khatru-like reusable relay framework in Zig

Expected scope:

- handler model
- storage/seam model
- auth/moderation hooks
- operator/dev ergonomics for building relay products

Why before the fastest relay:

- correctness and framework ergonomics first
- performance specialization after the reusable framework exists

### Phase 6. High-Performance Relay

Goal:

- most performant serious Zig relay product we can build

Expected scope:

- performance/memory posture
- durability and operator guidance
- interop and production discipline

### Phase 7. Blossom

Goal:

- credible Blossom server/client layer on top of the stronger SDK/server/tooling foundation

Expected scope:

- server behavior
- metadata/file flows
- auth/access posture where needed
- operator/deployment guidance

### Phase 8. Broader Client/Product Foundations

Goal:

- end-user clients, bots, services, and richer application foundations

This phase can expand:

- social/feed workflows
- richer publishing composition
- app/client foundations
- agent-facing products

## Current Lane Triage

### Keep Active Now

- one top-level SDK architecture lane

### Keep Open But Deprioritized

- `A-NIP17-001`
- `A-NIP29-001`
- `A-NIP03-001`
- `A-NIP39-001`
- `Z-WORKFLOWS-001`
- `Z-ABSTRACTION-001`

These remain real, but they are not all equally urgent right now.

### Resume Only If Needed For The Next Product

- broader `NIP-03` policy refinements
- broader `NIP-39` policy refinements

### Product Order

1. shared SDK architecture
2. CLI
3. signer tooling/product
4. relay framework
5. high-performance relay
6. Blossom
7. broader client/product ecosystem

## Loop Guidance

Use coherent loops only when they clearly advance the current phase.

Examples:

- Phase 1:
  - 4-6 slice loops around architecture-defined SDK runtime/store layers
- Phase 3:
  - 4-8 slice loops around CLI command families
- Phase 5:
  - 4-8 slice loops around relay-framework capabilities

Avoid:

- helper-only loops that do not materially advance the active phase
- loops that cross multiple product phases at once

## Success Condition For The Current Transition

The current transition is complete when:

- `noztr-sdk` has one explicit client/runtime/store architecture packet
- the repo routes to that lane as the main active priority
- existing narrower long-lived refinement lanes are treated as reference baselines, not the main
  next step
