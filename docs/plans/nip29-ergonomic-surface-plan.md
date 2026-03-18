---
title: NIP-29 Ergonomic Surface Refinement
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 29
read_when:
  - refining_nip29
  - closing_group_session_shape_findings
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP29-001
  - Z-NIP29-001
  - Z-EXAMPLES-001
---

# NIP-29 Ergonomic Surface Refinement

Date: 2026-03-15

## 1. Scope Delta

This slice refines the public `NIP-29` workflow shape without broadening the accepted replay/sync
boundary.

This slice changes:
- `GroupSession` initialization shape from positional storage slices to a named config + storage
  wrapper
- the public read surface for reduced state through a small `GroupSessionView`
- the `NIP-29` recipe so it teaches the SDK shape instead of reducer-layout mechanics first

This slice does not change:
- replay semantics
- join/leave/request observation breadth
- multi-relay behavior
- durable storage or cursors
- publish automation or background runtime loops

## 2. Targeted Findings

- `A-NIP29-001`
  - category: product-surface polish
  - expectation: narrow this finding by making the current group-session surface more client-like to
    instantiate and inspect, but not fully close the broader “not yet a full group client” gap
- `Z-NIP29-001`
  - category: Zig-native API/ergonomics shaping
  - expectation: close the raw positional storage-layout problem for the main public path
- `Z-EXAMPLES-001`
  - category: Zig-native teaching posture
  - expectation: close the specific `NIP-29` recipe issue where the example starts by teaching raw
    reducer storage arrays instead of the SDK shape

## 3. Slice-Specific Proof Gaps

Still not provable after this slice:
- caller-supplied ordering is canonical
- session-known `previous` refs represent the full relay history
- the workflow is a full groups client with publish, sync, and durable multi-relay behavior

This slice proves only:
- the bounded storage remains caller-owned and explicit
- the public path no longer forces callers to understand raw reducer storage layout immediately

## 4. Slice-Specific Seam Constraints

This slice keeps the current seams unchanged:
- relay/session stepping remains explicit
- transcript ordering remains caller-supplied
- no transport, fetch, or durable-store seam is added

The only API-shape seam change is local:
- caller-owned state storage is grouped into one explicit wrapper object

## 5. Slice-Specific Tests

This slice must add or adjust:
- `GroupSession.init(...)` coverage for the named config/storage path
- view-surface coverage for reduced state inspection
- recipe coverage proving the example stays on the new public path
- compatibility coverage for the lower-level storage-entry path if it remains public

## 6. Closeout Checks

Before this slice closes:
- update `src/workflows/group_session.zig`
- update `src/workflows/mod.zig` and root-surface tests if new public types are exported
- update `examples/group_session_recipe.zig`
- rerun both audit frames and update:
  - `A-NIP29-001`
  - `Z-NIP29-001`
  - `Z-EXAMPLES-001`
- run:
  - `zig build`
  - `zig build test --summary all`
