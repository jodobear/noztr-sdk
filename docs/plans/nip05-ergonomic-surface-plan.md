---
title: Noztr SDK NIP-05 Ergonomic Surface Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 5
read_when:
  - refining_nip05
  - closing_z_buffer_001_for_nip05
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
target_findings:
  - Z-BUFFER-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Noztr SDK NIP-05 Ergonomic Surface Plan

Refinement packet for the `NIP-05` portion of `Z-BUFFER-001`.

Date: 2026-03-16

## Scope Delta

This slice changes the public `NIP-05` workflow shape so callers no longer pass raw lookup/body
buffers directly into `Nip05Resolver.lookup(...)` and `verify(...)`.

This slice does:
- add a small caller-owned storage wrapper for `NIP-05`
- add explicit lookup and verification request wrappers that keep the scratch allocator visible
- update the recipe and tests to teach the wrapper shape first

This slice does not:
- broaden `NIP-05` into cache, reverse-discovery, or `NIP-46` composition workflows
- widen the HTTP seam
- change the written redirect-policy proof gap

Declared touchpoints:
- `touches_teaching_surface`: yes
- `touches_audit_state`: yes
- `touches_startup_docs`: yes

## Targeted Findings

- `Z-BUFFER-001`

This slice is Zig-native API/ergonomics shaping only.

## Slice-Specific Proof Gaps

Unchanged accepted gaps:
- the current `HttpClient` seam still cannot prove `NIP-05` redirect prohibition
- the resolver remains a stateless fetch/parse/verify shell rather than a broader identity workflow

No new proof claims are added by this slice.

## Slice-Specific Seam Constraints

- the HTTP seam remains the narrow public `noztr_sdk.transport.HttpClient`
- the allocator remains explicit because parsed profile lifetimes depend on caller-managed scratch
- the storage wrapper must stay caller-owned and bounded; it must not hide dynamic allocation

## Slice-Specific Tests

- existing `NIP-05` lookup and verify behavior remains green through the new request/storage path
- wrapper shape is exported through `workflows`
- root smoke continues to expose only the intended public workflow surface

## Staged Execution Notes

- Stage 1 code:
  - add `Nip05LookupStorage`
  - add `Nip05LookupRequest`
  - add `Nip05VerificationRequest`
  - move the public resolver entrypoints to the wrapper shape
- Stage 2 tests:
  - update all resolver tests to the new request/storage path
  - keep existing fetch, mismatch, malformed-document, and mismatch-semantics coverage
- Stage 3 example:
  - update `examples/nip05_resolution_recipe.zig` to teach the wrapper shape
- Stage 4 review and audits:
  - rerun the Zig-native audit against `Z-BUFFER-001`
  - confirm no product-surface claims changed
- Stage 5 docs and handoff:
  - update audits, examples catalog, build-plan/handoff/index/agent-brief as needed

## Closeout Checks

- update:
  - `src/workflows/nip05_resolver.zig`
  - `src/workflows/mod.zig`
  - `src/root.zig`
  - `examples/nip05_resolution_recipe.zig`
  - `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
  - `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md` if wording needs narrowing
  - `docs/plans/nip05-resolver-plan.md`
  - `examples/README.md`
  - `handoff.md`
  - `docs/plans/build-plan.md`
  - `docs/index.md`
  - `agent-brief`
- rerun:
  - `zig build`
  - `zig build test --summary all`
  - local `noztr` compatibility check

## Accepted Slice

Implemented on 2026-03-16:
- `src/workflows/nip05_resolver.zig` now exposes `Nip05LookupStorage`
- `src/workflows/nip05_resolver.zig` now exposes `Nip05LookupRequest`
- `src/workflows/nip05_resolver.zig` now exposes `Nip05VerificationRequest`
- the public resolver entrypoints now take request wrappers instead of raw buffer choreography
- the recipe in `examples/nip05_resolution_recipe.zig` now teaches the wrapper shape first
- `Z-BUFFER-001` is narrowed to the remaining `NIP-46` surface
