# AGENTS.md — noztr-sdk

Zig Nostr SDK built on top of `noztr`.

## Session Startup

- Run `./agent-brief` first.
- Read `AGENTS.md` and `handoff.md` every session.
- Then read only the current execution files called out by `./agent-brief`.
- Read `docs/guides/TIGER_STYLE.md`, `docs/guides/zig-patterns.md`, and
  `docs/guides/zig-anti-patterns.md` when the task touches Zig implementation or code review.
- Read `docs/guides/NOZTR_SDK_STYLE.md` for SDK-specific API and orchestration expectations.
- Read `docs/plans/noztr-sdk-ownership-matrix.md` when deciding whether behavior belongs in `noztr-sdk`
  or should remain in `noztr`.
- Read `docs/plans/build-plan.md` as the canonical `noztr-sdk` execution baseline.
- Read `docs/plans/implementation-quality-gate.md` before new workflow, substrate, or public API
  implementation.
- Read `docs/plans/sdk-kickoff.md`, `docs/plans/package-layout-plan.md`,
  `docs/plans/noztr-integration-plan.md`, `docs/plans/testing-parity-strategy.md`,
  `docs/plans/api-ownership-map.md`, and `docs/plans/research-refresh-2026-03-14.md` for active
  planning and implementation work.
- Read `docs/plans/autonomous-loop-phases-1-4.md` during the current execution cycle.

## Project Posture

- `noztr-sdk` is higher-level than `noztr`, but it must stay deliberate.
- `noztr-sdk` explicitly depends on `noztr` as its Zig Nostr protocol kernel.
- Use `noztr` for deterministic protocol parsing/validation/building whenever possible.
- Keep orchestration, network fetches, session handling, caches, and workflow composition in `noztr-sdk`.
- Do not re-implement kernel logic that already exists correctly in `noztr`.
- Use applesauce as the primary SDK ergonomics reference for clarity, stores, client layering, and
  workflow shape.
- Use rust-nostr-sdk as a secondary ecosystem/reference input.
- Treat applesauce and rust-nostr-sdk as implementation references, not as protocol authority and
  not as permission to blur the `noztr` / `noztr-sdk` boundary.
- Research first, then plan, then implement.

## Dependency Posture

- Bootstrap and develop `noztr-sdk` against the local `/workspace/projects/noztr` checkout first.
- Do not wait for a git remote or tagged release to begin SDK work.
- Move to a tagged/remote dependency model later only when release discipline requires it.

## Phase And Process

- `noztr-sdk` should follow the same tight process used in `noztr`:
  - research
  - planning
  - implementation
  - review
  - documentation
  - handoff
- The bootstrap planning baseline now exists; implementation should stay scoped to the current
  accepted milestone and update the planning docs when boundaries move.
- During the current cycle, execute Phases 1-4 using the autonomous loop and do not skip the
  required review gates after each phase.
- For any new NIP-backed slice after Phase 1-4, do not start implementation until the required
  planning packet from `docs/plans/implementation-quality-gate.md` exists.
- Keep decisions explicit. Record default changes and accepted scope boundaries in planning docs.

## Boundary Check

For every major SDK helper or module, answer these explicitly:
- why is this not already covered by `noztr`?
- why is this not application code above `noztr-sdk`?
- why is this the simplest useful SDK layer?

If those answers are weak, stop and tighten the boundary before implementing.

## Startup Work For A New Execution Lane

Before major implementation work:
- review the copied research set under `docs/research/`
- refresh the relevant NIP specs in `docs/nips/`
- create or update planning docs under `docs/plans/`
- write or refresh the implementation packet required by
  `docs/plans/implementation-quality-gate.md`
- keep `handoff.md` current
- tighten this `AGENTS.md` if the SDK scope becomes clearer

## Build & Test

- Canonical commands are documented in `docs/plans/build-plan.md`.
- Until the scaffold lands, do not invent broad toolchains outside the recorded plan.
- Use Zig as the canonical build/test lane for SDK code.

## Tooling Rule

- Use `bun` for local JavaScript/TypeScript tooling in this repo.
- Do not use `npm` for local interop harness setup or execution.

## Documentation Rule

- Keep `AGENTS.md`, `agent-brief`, and `handoff.md` aligned with the accepted planning baseline.
- Do not treat copied research or planning artifacts as final truth; refresh and tighten them as
  the SDK scope sharpens.
- Treat examples as part of implementation quality, not optional follow-up material.
