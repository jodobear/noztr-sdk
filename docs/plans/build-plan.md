---
title: Noztr SDK Build Plan
doc_type: policy
status: active
owner: noztr-sdk
read_when:
  - every_session
  - selecting_active_lane
  - deciding_current_control_docs
depends_on:
  - docs/plans/implementation-quality-gate.md
---

# Noztr SDK Build Plan

Execution baseline and routing map for `noztr-sdk`.

This document is intentionally not a milestone history, packet catalog, or second process gate.
It answers:
- what controls execution now
- what the canonical build/test posture is
- where active work should route next

## Current Active Docs

- discovery index: [docs/index.md](../index.md)
- public docs route: [docs/release/README.md](../release/README.md)
- current state and next work: [handoff.md](/workspace/projects/nzdk/handoff.md)
- implementation/review gate: [implementation-quality-gate.md](./implementation-quality-gate.md)
- audit lane map: [audit-lanes.md](./audit-lanes.md)
- product-gap audit: [implemented-nips-applesauce-audit-2026-03-15.md](./implemented-nips-applesauce-audit-2026-03-15.md)
- Zig-native audit: [implemented-nips-zig-native-audit-2026-03-15.md](./implemented-nips-zig-native-audit-2026-03-15.md)
- examples teaching posture: [examples-tree-plan.md](./examples-tree-plan.md)
- active child architecture packet:
  [zig-cli-v1-command-surface-plan.md](./zig-cli-v1-command-surface-plan.md)

## Current Execution Posture

- `noztr-sdk` is the higher-level Zig Nostr SDK above local `/workspace/projects/noztr`.
- The product target is stable:
  - Zig-native analogue to applesauce
  - ecosystem-compatible and app-facing
  - explicit about ownership, boundedness, and workflow control
- The current workflow floor is already implemented.
- New work should usually be refinement or breadth work against the live audit findings, not a new
  uncontrolled workflow expansion.

## Current Routing Rules

- The current or next lane is named in [handoff.md](/workspace/projects/nzdk/handoff.md).
- The current execution order is owned canonically by
  [implementation-quality-gate.md](./implementation-quality-gate.md).
- When work touches `noztr` directly, route through
  `/workspace/projects/noztr/docs/release/README.md` and
  `/workspace/projects/noztr/examples/README.md` first.
- Workflow packet chains are reference material discoverable through [docs/index.md](../index.md).
  Load only the packet chain for the slice you are actually touching.
- Public SDK documentation should route through `docs/release/` plus `examples/README.md`, not
  through internal planning docs by default.
- Completed loops, superseded packets, and bootstrap context belong in `docs/archive/`, not in the
  active startup path.

## Packet Rule

Per-slice packets should be delta-oriented:
- inherit the generic quality bar from
  [implementation-quality-gate.md](./implementation-quality-gate.md)
- record only slice-specific scope, targeted findings, proof gaps, seam constraints, tests, and
  closeout state
- avoid restating the full gate unless the slice needs an explicit justified exception

## Canonical Defaults

- local kernel dependency:
  - primary dependency target: `/workspace/projects/noztr`
  - repo-relative path: `../noztr`
- modeling references:
  - applesauce is the primary SDK ergonomics reference
  - rust-nostr-sdk is the secondary ecosystem/reference input
- tooling posture:
  - Zig is the canonical implementation/build/test lane
  - `bun` is the only allowed JavaScript/TypeScript tooling in this repo
- runtime posture:
  - no hidden global runtime
  - no hidden threads
  - no implicit network side effects
  - stores, caches, and workflow state must remain bounded and testable

## Boundary Baseline

- `noztr` owns deterministic parse, validate, serialize, sign, verify, and bounded reduction logic.
- `noztr-sdk` owns relay/session orchestration, fetches, stores, caches, sync policy, and
  application-facing workflow composition.
- For exact boundary questions, use
  [noztr-sdk-ownership-matrix.md](./noztr-sdk-ownership-matrix.md).

## Canonical Commands

- `zig build`
- `zig build test --summary all`
- `bun test <tool-path>` only for opt-in JS interop harnesses under `tools/`

## Reference Background

Use these only when the active task needs deeper planning context:
- [sdk-kickoff.md](./sdk-kickoff.md)
- [package-layout-plan.md](./package-layout-plan.md)
- [noztr-integration-plan.md](./noztr-integration-plan.md)
- [testing-parity-strategy.md](./testing-parity-strategy.md)
- [api-ownership-map.md](./api-ownership-map.md)
- [research-refresh-2026-03-14.md](./research-refresh-2026-03-14.md)
- [zig-nostr-ecosystem-readiness-matrix.md](./zig-nostr-ecosystem-readiness-matrix.md)
- [zig-nostr-ecosystem-phased-plan.md](./zig-nostr-ecosystem-phased-plan.md)
- [sdk-runtime-client-store-architecture-decision.md](./sdk-runtime-client-store-architecture-decision.md)
- [sdk-relay-pool-runtime-baseline-decision.md](./sdk-relay-pool-runtime-baseline-decision.md)
- [sdk-store-query-index-baseline-decision.md](./sdk-store-query-index-baseline-decision.md)
- [sdk-storage-backend-research-plan.md](./sdk-storage-backend-research-plan.md)

## Historical Archive

- [docs/archive/README.md](/workspace/projects/nzdk/docs/archive/README.md)

Historical execution loops, superseded packets, and bootstrap context live under `docs/archive/`.
They are reference material, not current control docs.
