# Handoff

Current project context for `noztr-sdk`.

## Current Status

- `noztr-sdk` now has an accepted planning baseline and a working Zig package scaffold.
- Phase 2 of the autonomous loop is complete: `build.zig`, `build.zig.zon`, `src/root.zig`, and
  starter namespace modules now exist.
- Phase 3 of the autonomous loop is complete: the relay/session substrate now exists as internal
  `noztr-sdk` modules with explicit HTTP/store seams, `NIP-11` relay-info fetch/cache flow, and
  `NIP-42`-adjacent relay auth/session state.
- Phase 3 review gates passed after multiple reruns for boundary, correctness, and API/ergonomics.
- Phase 4 of the autonomous loop is complete: `src/workflows/remote_signer.zig` now exposes the
  first stable SDK workflow, a step-driven `NIP-46` remote signer session built on the internal
  relay/session substrate.
- Phase 4 review gates were run for boundary, correctness, and API/ergonomics; the resulting fixes
  are now validated by the local Zig lane.
- The latest audit and fix pass tightened the Phase 3 and Phase 4 seams further:
  - `sign_event` responses now require full signed-event verification, not parse-only acceptance
  - relay URLs now follow current `noztr` bounds and normalized-equivalence behavior at the
    pool/store seams
  - regression tests now pin connect strictness, auth failure blocking, `switch_relays` `null`
    behavior, and reconnect-after-switch flow
  - malformed `NIP-46` response parse failures now also clear matched pending requests when the
    response `id` can be recovered from the raw JSON, closing a leak path for invalid
    `switch_relays` relay lists
- A follow-up audit on 2026-03-15 tightened relay URL validation further:
  - `relay.auth` and `relay.session` now reject invalid non-websocket relay URLs at init time
  - `store.memory` now rejects invalid relay URLs on both put and lookup instead of silently
    accepting impossible records or queries
  - stale duplicated `nzdk`-named style/bootstrap docs were removed so startup docs now point at
    only the current `noztr-sdk` artifacts
- `zig build` and `zig build test --summary all` currently pass in both `/workspace/projects/noztr`
  and `/workspace/projects/nzdk`.
- `/workspace/projects/noztr` is currently fully green again, including the examples lane:
  `zig build test --summary all` passed with examples included.
- the March 14, 2026 applesauce and rust-nostr refresh is captured in
  `docs/plans/research-refresh-2026-03-14.md`
- copied March 4 research docs now use the correct local mirror paths for reproducible provenance
- Phase 1 of the autonomous loop is complete: planning docs now reflect refreshed March 14, 2026
  provenance and upstream deltas.
- The kernel/SDK ownership boundary starts from `docs/plans/noztr-sdk-ownership-matrix.md`.
- `docs/plans/build-plan.md` is now the canonical execution baseline.
- Additional planning baselines exist for kickoff, package layout, `noztr` integration, testing,
  and API ownership.
- `docs/plans/autonomous-loop-phases-1-4.md` is now the canonical execution loop for Phases 1-4.
- `noztr` is the protocol-kernel dependency target; `noztr-sdk` should not duplicate kernel logic.
- bootstrap should use the local `/workspace/projects/noztr` checkout first; remote setup is not a
  blocker
- Applesauce is the primary SDK/reference input for modeling higher-level client ergonomics,
  stores, and workflow composition.
- Rust-nostr-sdk is a secondary ecosystem/reference input.
- `/workspace/projects/noztr/examples` is the current kernel recipe reference set and should inform
  the eventual `noztr-sdk` examples posture.
- The current `noztr` examples set is broader than the original bootstrap snapshot and now includes
  direct recipe references for discovery, identity proofs, wallet flows, private lists, and relay
  admin helpers in addition to the `NIP-46` recipe.
- A recheck on 2026-03-15 confirmed that the full `/workspace/projects/noztr/examples` lane is now
  green again, so the broader recipe set can be treated as current kernel reference material.
- `docs/plans/implementation-quality-gate.md` is now the canonical execution gate for new
  NIP-backed workflow and substrate work.
- The public root surface is still intentionally minimal; Phase 4 added `noztr_sdk.workflows` and
  `workflows.RemoteSignerSession`, while `client` and substrate namespaces remain internal.

## Immediate Next Work

1. Treat Phases 1-4 from `docs/plans/autonomous-loop-phases-1-4.md` as complete.
2. The next unstarted SDK milestone is mailbox/session orchestration (`NIP-17`) on top of the
   existing substrate and signer-session patterns.
3. Keep protocol message building/parsing/validation in `noztr`; `noztr-sdk` should continue to own
   only orchestration, relay control, auth/session handling, and workflow composition.
4. Keep the public root surface narrow until a second workflow proves that a broader `client`
   namespace is worth freezing.
5. Start the next cycle with an explicit follow-on loop for `NIP-17` rather than extending the
   Phase 1-4 loop ad hoc.
6. Start planning the top-level `examples/` directory so SDK workflows are taught through
   structured recipes, not only tests and planning docs.
7. For the next cycle, require the full implementation packet from
   `docs/plans/implementation-quality-gate.md` before any mailbox/session code changes.

## Boundary Reminder

For every major SDK helper, answer:
- why is this not already a `noztr` concern?
- why is this not app code above `noztr-sdk`?
- why is this the simplest useful SDK layer?

## Open Starting Questions

- should the first transport seam be step-driven, callback-driven, or both
- whether the first reference HTTP adapter should land in `M2` or remain interface-only longer
- whether `NIP-29` group sync should wait until after signer/mailbox workflows stabilize
