---
title: NIP-29 Runtime Client Plan
doc_type: packet
status: reference
owner: noztr-sdk
nips: [29]
read_when:
  - refining_nip29
  - broadening_group_client_runtime
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP29-001
  - Z-ABSTRACTION-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
---

# NIP-29 Runtime Client Plan

## Scope Delta

- Add a higher-level `GroupClient` above `GroupSession` for single-relay group runtime intake.
- The client owns the previous-ref scratch it needs and accepts mixed relay events through:
  - `consumeEvent(...)`
  - `consumeEventJson(...)`
  - `consumeEvents(...)`
  - `consumeEventJsons(...)`
- Keep `GroupSession` as the bounded lower-level core for replay and explicit publish helpers.
- Keep multi-relay merge, durable cursors, retained history stores, and hidden subscription loops
  out of scope.

Declared sync flags:
- `touches_teaching_surface: yes`
- `touches_audit_state: yes`
- `touches_startup_docs: yes`

## Targeted Findings

- `A-NIP29-001`
- `Z-ABSTRACTION-001`

This is both product-surface broadening and Zig-native abstraction shaping.

## Slice-Specific Proof Gaps

- The client still does not prove canonical multi-relay ordering.
- It still does not provide durable sync storage or background runtime ownership.
- It can only classify and consume events for the currently pinned single-relay group session.

## Slice-Specific Seam Constraints

- Relay readiness and auth gating still come from `GroupSession`.
- Incoming event parsing and deterministic reduction stay in `noztr` and `GroupSession`.
- The client may summarize mixed relay intake, but it does not own transport fetch/subscription.

## Slice-Specific Tests

- mixed relay event intake routes state, join-request, leave-request, and generic flows correctly
- batch intake summarizes mixed relay events correctly
- the client still blocks on the lower-level relay/session constraints inherited from
  `GroupSession`
- outbound publish helpers remain usable through the higher-level client surface

## Staged Execution Notes

1. Code: add `GroupClient`, owned previous-ref storage, mixed-event intake, and batch summaries.
2. Tests: prove mixed intake routing and batch summary behavior on top of snapshot state.
3. Example: teach replay plus outbound moderation through the higher-level client surface.
4. Review/audits: rerun the applesauce and Zig-native audits for `A-NIP29-001` and
   `Z-ABSTRACTION-001`.
5. Docs/closeout: update the `NIP-29` reference packet, examples catalog, handoff, and startup
   routing docs.

## Closeout Checks

- Update `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
- Update `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Update `docs/plans/nip29-sync-store-plan.md`
- Update `examples/README.md`
- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `AGENTS.md`
- Update `agent-brief`

## Accepted Slice

Implemented and reviewed on 2026-03-16:
- `src/workflows/group_client.zig`
- `GroupClient`, `GroupClientStorage`, `GroupClientConfig`
- typed `GroupClientEventOutcome`
- typed `GroupClientBatchSummary`
- owned previous-ref scratch for mixed relay event intake
- batch relay-event summary helpers on top of `GroupSession`
- updated recipe coverage in `examples/group_session_recipe.zig`

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `128/128`
- `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `87/87`

Follow-on durable fleet checkpoint-store broadening for this workflow now lives in
[nip29-durable-store-plan.md](./nip29-durable-store-plan.md).

Follow-on fleet-wide publish broadening for this workflow now lives in
[nip29-fleet-publish-plan.md](./nip29-fleet-publish-plan.md).

Follow-on explicit merge-policy broadening for this workflow now lives in
[nip29-merge-policy-plan.md](./nip29-merge-policy-plan.md).

Follow-on fleet runtime-policy broadening for this workflow now lives in
[nip29-runtime-policy-plan.md](./nip29-runtime-policy-plan.md).
