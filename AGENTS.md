# AGENTS.md — nzdk

Zig Nostr SDK built on top of `noztr`.

## Session Startup

- Run `./agent-brief` first.
- Read `AGENTS.md` and `handoff.md` every session.
- Then read only the current execution files called out by `./agent-brief`.
- Read `docs/guides/TIGER_STYLE.md`, `docs/guides/zig-patterns.md`, and
  `docs/guides/zig-anti-patterns.md` when the task touches Zig implementation or code review.
- Read `docs/guides/NZDK_STYLE.md` for SDK-specific API and orchestration expectations.
- Read `docs/plans/noztr-sdk-ownership-matrix.md` when deciding whether behavior belongs in `nzdk`
  or should remain in `noztr`.
- Read `docs/plans/build-plan.md` during active execution until `nzdk` replaces it with its own
  accepted planning baseline.

## Project Posture

- `nzdk` is higher-level than `noztr`, but it must stay deliberate.
- Use `noztr` for deterministic protocol parsing/validation/building whenever possible.
- Keep orchestration, network fetches, session handling, caches, and workflow composition in `nzdk`.
- Do not re-implement kernel logic that already exists correctly in `noztr`.
- Use applesauce as the primary SDK ergonomics reference for clarity, stores, client layering, and
  workflow shape.
- Use rust-nostr-sdk as a secondary ecosystem/reference input.
- Treat applesauce and rust-nostr-sdk as implementation references, not as protocol authority and
  not as permission to blur the `noztr` / `nzdk` boundary.
- Research first, then plan, then implement.

## Phase And Process

- `nzdk` should follow the same tight process used in `noztr`:
  - research
  - planning
  - implementation
  - review
  - documentation
  - handoff
- Do not begin broad implementation from template state.
- First tighten the repo’s own planning/process docs so `nzdk` can operate autonomously on its own
  terms.
- Keep decisions explicit. Record default changes and accepted scope boundaries in planning docs.

## Startup Work For A New Execution Lane

Before major implementation work:
- review the copied research set under `docs/research/`
- refresh the relevant NIP specs in `docs/nips/`
- create or update planning docs under `docs/plans/`
- keep `handoff.md` current
- tighten this `AGENTS.md` if the SDK scope becomes clearer
- replace the copied `build-plan.md` template with `nzdk`'s own accepted execution baseline

## Build & Test

- Define and document the canonical commands as the SDK takes shape.
- Until then, do not invent broad toolchains without recording the decision in planning docs.

## Tooling Rule

- Use `bun` for local JavaScript/TypeScript tooling in this repo.
- Do not use `npm` for local interop harness setup or execution.

## Documentation Rule

- `AGENTS.md`, `agent-brief`, and `handoff.md` are templates here and should be updated by `nzdk`
  itself as the repo gains real structure.
- `docs/plans/build-plan.md` is also a template seed and should be replaced by `nzdk`'s own
  planning baseline.
- Do not treat copied planning artifacts as final truth; use them as seed inputs.
