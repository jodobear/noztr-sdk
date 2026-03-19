---
title: Stored Workflow Hardening Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [3, 39]
read_when:
  - hardening_public_store_backed_workflows
  - fixing_audit_findings_from_full_repo_review
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# Stored Workflow Hardening Plan

## Closeout

Completed on 2026-03-19.

Accepted slice commit:
- `Harden stored workflow seams`

## Scope Delta

This slice fixes the two technical findings from the 2026-03-19 full-codebase audit:

1. remove the hidden fixed-capacity `32`-entry limit from
   `OpenTimestampsVerifier.getPreferredStoredVerification(...)`
2. replace remembered-store `unreachable` paths in `NIP-03` and `NIP-39` discovery/freshness
   helpers with typed public inconsistency errors

This slice does not broaden product scope. It is misuse hardening and Zig-native surface cleanup.

## Targeted Findings

- `Z-ABSTRACTION-001`

This slice closes a real abstraction leak:
- caller-owned capacity should stay explicit on public helper paths
- public store-backed workflow helpers should not rely on invariant-only `unreachable` for
  externally supplied store implementations

## Slice-Specific Proof Gaps

- This slice can make remembered-store inconsistency explicit, but it cannot prove third-party
  store correctness.
- It does not remove the broader open product gaps around longer-lived identity/proof policy.

## Slice-Specific Seam Constraints

- `IdentityProfileStore` and `OpenTimestampsVerificationStore` remain caller-owned seams.
- `noztr-sdk` may classify inconsistent seam behavior, but it must not silently repair it.
- `NIP-03` preferred-selection storage must be caller-owned; no hidden helper-local fixed cap.

## Slice-Specific Tests

- prove `OpenTimestampsVerifier.getPreferredStoredVerification(...)` uses caller-owned storage and
  no longer imposes the hidden `32`-entry cap
- prove inconsistent `IdentityProfileStore` results return a typed error instead of reaching
  `unreachable`
- prove inconsistent `OpenTimestampsVerificationStore` results return a typed error instead of
  reaching `unreachable`

## Staged Execution Notes

1. Code
- add typed store inconsistency errors
- route remembered discovery/freshness hydration through those typed errors
- change `OpenTimestampsPreferredStoredVerificationRequest` to take caller-owned freshness storage

2. Tests
- add direct inconsistency tests for both remembered-store seams
- add preferred-selection storage-pressure tests on the new caller-owned request shape

3. Examples
- update the `NIP-03` recipe if the preferred-selection request shape changes public usage

4. Review and audit reruns
- re-evaluate `Z-ABSTRACTION-001`
- verify no public helper still hides fixed capacity or invariant-only store assumptions

5. Docs and handoff closeout
- update the packet chain, handoff, examples catalog, and audits
- keep one commit for the accepted remediation slice

## Closeout Checks

- update:
  - `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
  - `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
  - `examples/README.md`
  - `handoff.md`
  - `docs/index.md`
- compatibility result classification:
  - expected `green`
- planned commit subject:
  - `Harden stored workflow seams`
