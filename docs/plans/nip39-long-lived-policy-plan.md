---
title: NIP-39 Long-Lived Policy Plan
doc_type: packet
status: active
owner: noztr-sdk
nips: [39]
read_when:
  - selecting_the_next_broader_product_slice
  - broadening_identity_workflow_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP39-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-39 Long-Lived Policy Plan

## Status

This broader lane is active again after the bounded `NIP-17` mailbox workflow loop closeout.
Treat the older
[nip39-ten-slice-policy-loop-plan.md](./nip39-ten-slice-policy-loop-plan.md) as reference
execution history under this broader parent packet.

## Scope Delta

`NIP-39` already has explicit verify, cache, remember, discover, freshness, preferred-selection,
runtime, and refresh-plan helpers.

The remaining gap is broader long-lived identity/discovery policy:
- explicit multi-identity remembered discovery over caller-owned storage
- explicit refresh candidates for a remembered identity set
- explicit policy helpers that help an app choose which remembered identities to refresh first
  without jumping straight to hidden autonomous loops

This packet is the next broader product lane above the current bounded per-identity helpers.

This lane should not:
- add hidden background polling
- add implicit HTTP ownership
- add hidden durable caches beyond caller-owned store seams
- move provider verification into `noztr`

## Targeted Findings

- `A-NIP39-001`
- `Z-ABSTRACTION-001`

This slice family should make `NIP-39` feel more like a usable long-lived SDK workflow while
staying explicit and Zig-native.

## Slice-Specific Proof Gaps

- The SDK can classify remembered identity policy and refresh priority, but it still cannot prove
  provider truth beyond the fetched proof documents.
- It cannot guarantee liveness or freshness without caller-owned scheduling and storage policy.

## Slice-Specific Seam Constraints

- HTTP stays an explicit caller-owned seam through `noztr_sdk.transport`.
- Remembered identity state stays on caller-owned cache/store surfaces.
- No slice may invent hidden daemon/runtime ownership just to make selection easier.

## Slice-Specific Tests

- prove any new remembered-discovery or refresh-selection helper remains caller-bounded
- prove stale/fresh ordering is explicit and deterministic
- prove examples make refresh/discovery preconditions explicit instead of relying on hidden state

## Staged Execution Notes

1. Code
- broaden `NIP-39` only above the existing remembered-profile surfaces
- prefer explicit multi-identity planning helpers over hidden runtime ownership

2. Tests
- cover mixed fresh/stale remembered identity sets
- cover storage pressure and inconsistent-store handling on the broader helper path

3. Examples
- teach one broader remembered-identity policy flow without implying hidden background refresh

4. Review and audit reruns
- re-evaluate `A-NIP39-001` and `Z-ABSTRACTION-001`

5. Docs and handoff closeout
- keep one commit per accepted slice
- keep the packet chain and examples catalog aligned with the broadened identity surface
