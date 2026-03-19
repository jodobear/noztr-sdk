---
title: SDK Runtime Client Store Architecture Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - selecting_the_next_major_sdk_lane
  - defining_the_shared_sdk_architecture
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/zig-nostr-ecosystem-readiness-matrix.md
  - docs/plans/zig-nostr-ecosystem-phased-plan.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP17-001
  - A-NIP29-001
  - A-NIP03-001
  - A-NIP39-001
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Runtime Client Store Architecture Plan

## Scope Delta

This is the new top-level active lane.

The repo has multiple strong workflow families already, but they still compose only partially into
one broader app-facing SDK runtime.

Before building the first serious Zig CLI, signer tooling, relay framework, or Blossom products,
`noztr-sdk` needs one explicit architecture baseline for:

- relay pools
- subscriptions and sync
- reconnect/retry posture
- background runtime ownership
- durable store boundaries
- event/query/index posture
- how workflow-specific helpers compose into a higher-level client model

## Why This Takes Priority

The next planned products:

- Zig CLI
- signer tooling/product
- relay framework

all need this foundation more than they need another isolated `NIP-03` or `NIP-39` refinement loop.

## Targeted Findings

- `A-NIP17-001`
- `A-NIP29-001`
- `A-NIP03-001`
- `A-NIP39-001`
- `Z-WORKFLOWS-001`
- `Z-ABSTRACTION-001`

## Proof Gaps

- the SDK can already prove bounded workflow behavior inside several lanes
- it cannot yet prove that those lanes compose into one coherent higher-level client/runtime/store
  architecture
- it also cannot yet prove that the first product repos can be built cleanly without introducing
  ad hoc runtime ownership above the SDK

## Seam Constraints

- keep deterministic protocol/kernel behavior in `noztr`
- keep application/product-specific policy above `noztr-sdk`
- do not hide threads, network side effects, or global runtime state just to make the SDK feel
  higher-level
- architecture work must remain Zig-native, bounded, and explicit

## Required Output

This lane should produce:

1. one architecture decision document or packet refinement that names the shared client/runtime/
   store model
2. the minimum follow-on implementation loops needed to support:
   - CLI v1
   - signer tooling v1
   - relay framework v1

## Expected Near-Term Loop Families

1. relay pool / session architecture
2. subscription / sync model
3. storage backend posture research plus store / query / index architecture
4. background runtime ownership and step model
5. first CLI-supporting client surface

## Staged Execution Notes

1. Research
- review the currently implemented runtime/store helper families before inventing new ones
- use the ecosystem readiness and phased plans as the strategic reference

2. Planning
- write architecture decisions before broad new implementation loops
- make storage/backend support posture explicit before hardening the shared store/query/index model

3. Implementation
- prefer one coherent shared model over more isolated workflow-local helpers

4. Review and audit reruns
- explicitly revisit `Z-WORKFLOWS-001` and `Z-ABSTRACTION-001`
- check whether the architecture actually reduces the current product gaps

5. Docs and handoff closeout
- keep this packet as the top-level active lane until a more specific child architecture loop is
  accepted

## Current Architecture Reference

- [sdk-runtime-client-store-architecture-decision.md](./sdk-runtime-client-store-architecture-decision.md)
- [sdk-relay-pool-runtime-baseline-plan.md](./sdk-relay-pool-runtime-baseline-plan.md)
- [sdk-relay-pool-runtime-baseline-decision.md](./sdk-relay-pool-runtime-baseline-decision.md)
- [sdk-storage-backend-research-plan.md](./sdk-storage-backend-research-plan.md)
- [sdk-store-query-index-baseline-plan.md](./sdk-store-query-index-baseline-plan.md)
- [sdk-store-query-index-baseline-decision.md](./sdk-store-query-index-baseline-decision.md)
