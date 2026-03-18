---
title: HTTP Workflows Public Seam Refinement
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 39
  - 5
read_when:
  - refining_nip39
  - refining_nip05
  - closing_http_surface_findings
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-HTTP-001
  - Z-HTTP-001
---

# HTTP Workflows Public Seam Refinement

Date: 2026-03-15

## 1. Scope Delta

This slice refines the already-landed `NIP-39` and `NIP-05` workflows so their HTTP dependency is a
deliberate public SDK seam instead of an internal-only implementation detail.

This slice changes:
- the public package posture for the HTTP seam used by `IdentityVerifier` and `Nip05Resolver`
- the teaching posture for the HTTP-backed workflows
- example coverage for the `NIP-39` and `NIP-05` public workflow surfaces

This slice does not change:
- `NIP-39` provider-verification breadth
- `NIP-05` redirect-policy proof gap
- transport implementation strategy; this remains interface-only for now
- caching, retries, redirect handling, or HTTP runtime policy

## 2. Targeted Findings

- `A-HTTP-001`
  - category: product-surface broadening
  - goal: make the HTTP-backed workflows actually instantiable and teachable from the public
    package
- `Z-HTTP-001`
  - category: Zig-native API/ergonomics shaping
  - goal: expose a coherent narrow public seam instead of exporting workflow types that depend on a
    hidden internal module

## 3. Slice-Specific Proof Gaps

Still not provable after this slice:
- `NIP-05` redirect prohibition remains an HTTP policy/seam gap; the public seam still does not
  expose final-URL or redirect metadata
- `NIP-39` still intentionally refuses Telegram and remains a single-claim verifier rather than a
  broader identity workflow

This slice only proves:
- the HTTP seam is part of the public SDK story
- the public examples can use that seam without internal imports

## 4. Slice-Specific Seam Constraints

Required semantics for this slice:
- caller can provide a body buffer and receive either response bytes or a typed `HttpError`
- caller can set the request URL and optional `Accept` header explicitly

Deliberate seam limits for this slice:
- no redirect metadata
- no response headers
- no status-code exposure beyond the typed `HttpError` classification already in the seam
- no async runtime abstraction

Reason:
- this is enough to make the seam public and teachable
- it is not enough to broaden `NIP-05` correctness claims beyond the current redirect-policy note

## 5. Slice-Specific Tests

This slice must add or adjust:
- root-surface tests proving the public HTTP seam is exported intentionally
- workflow tests proving `IdentityVerifier` and `Nip05Resolver` still operate over the same seam
- example coverage for `NIP-39` and `NIP-05` that uses only public SDK imports plus kernel helpers
- doc/test coverage showing the examples index no longer defers the HTTP-backed workflows

## 6. Closeout Checks

Before this slice closes:
- update `src/root.zig`
- update examples for `NIP-39` and `NIP-05`
- update `examples/README.md`
- update `docs/index.md`, `handoff.md`, and any active control docs that name the current packet
- rerun both active audit frames for the touched workflows and update the targeted findings
- run:
  - `zig build`
  - `zig build test --summary all`
