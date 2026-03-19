# AGENTS.md — noztr-sdk

Zig Nostr SDK built on top of `noztr`.

## Session Startup

- Run `./agent-brief` first.
- Read `AGENTS.md` and `handoff.md` every session.
- Read `docs/index.md` when you need to locate the right active, reference, audit, or archived doc.
- Then read only the current execution files called out by `./agent-brief` and `handoff.md`.
- Read `docs/guides/TIGER_STYLE.md`, `docs/guides/zig-patterns.md`, and
  `docs/guides/zig-anti-patterns.md` when the task touches Zig implementation or code review.
- Read `docs/guides/NOZTR_SDK_STYLE.md` for SDK-specific API and orchestration expectations.
- Read `docs/guides/PROCESS_CONTROL.md` when the task touches process refinement, control-doc
  cleanup, or docs-surface coherence.
- Read `docs/plans/audit-lanes.md` when defining, revising, or selecting audit and review lenses.
- Read `docs/plans/noztr-sdk-ownership-matrix.md` when deciding whether behavior belongs in `noztr-sdk`
  or should remain in `noztr`.
- Read `docs/plans/build-plan.md` as the canonical `noztr-sdk` execution baseline.
- Read `docs/plans/implementation-quality-gate.md` before new workflow, substrate, or public API
  implementation.
- Read `docs/plans/examples-tree-plan.md` when the task touches examples or teaching posture.
- Read `examples/README.md` when the task touches example discoverability, teaching posture, or
  SDK workflow recipes.
- Treat `/workspace/projects/nzdk/docs/release/README.md` and
  `/workspace/projects/nzdk/examples/README.md` as the canonical public-facing documentation
  route for `noztr-sdk`.
- Treat `docs/index.md`, `docs/plans/`, `docs/guides/`, and `docs/research/` as the internal
  engineering docs surface, not the primary public SDK docs route.
- Use `docs/index.md`, `handoff.md`, and `./agent-brief` to load workflow-specific packet chains
  only for the slice you are actually touching.
- Read `docs/plans/noztr-feedback-log.md` when SDK work uncovers a likely kernel issue or
  improvement idea.
- When a task touches `noztr` surfaces, use
  `/workspace/projects/noztr/docs/release/README.md` and
  `/workspace/projects/noztr/examples/README.md` as the canonical public routing surface.
- Do not treat older internal `noztr` routing notes as canonical when the public release docs cover
  the same surface.
- Read `docs/plans/sdk-kickoff.md`, `docs/plans/package-layout-plan.md`,
  `docs/plans/noztr-integration-plan.md`, `docs/plans/testing-parity-strategy.md`,
  `docs/plans/api-ownership-map.md`, and `docs/plans/research-refresh-2026-03-14.md` for active
  planning and implementation work only when the active task needs that background.
- Historical execution packets and completed loops now live under `docs/archive/` and should be read
  only when historical context is actually needed.

## Project Posture

- `noztr-sdk` is higher-level than `noztr`, but it must stay deliberate.
- `noztr-sdk` explicitly depends on `noztr` as its Zig Nostr protocol kernel.
- `noztr-sdk` is intended to become the Zig SDK analogue to applesauce for real-world Nostr app
  development:
  - opinionated enough to make real clients, relays, signers, bots, and services easier to build
  - structured and teachable enough that agents and humans can discover the right workflow quickly
  - ecosystem-compatible enough that applications built on it do not feel repo-local or bespoke
  - Zig-native enough that it uses Zig's strengths to improve determinism, boundedness, explicit
    ownership, and reasoning clarity instead of mechanically porting TypeScript patterns
- Use `noztr` for deterministic protocol parsing/validation/building whenever possible.
- Keep orchestration, network fetches, session handling, caches, and workflow composition in `noztr-sdk`.
- Do not re-implement kernel logic that already exists correctly in `noztr`.
- Use applesauce as the primary SDK ergonomics reference for clarity, stores, client layering, and
  workflow shape.
- Use rust-nostr-sdk as a secondary ecosystem/reference input.
- Treat applesauce and rust-nostr-sdk as implementation references, not as protocol authority and
  not as permission to blur the `noztr` / `noztr-sdk` boundary.
- Research first, then plan, then implement.
- When auditing or designing SDK surfaces, ask explicitly whether they are converging on that
  applesauce-like real-world usability target or are still only internal/research-grade slices.
- Also ask whether the current shape is "applesauce in Zig" in the bad sense of translated
  TypeScript, or whether it is a better Zig-native SDK surface that preserves the same broad product
  value while improving determinism and reasoning clarity.

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
- For any new NIP-backed slice after Phase 1-4, do not start implementation until the required
  planning packet from `docs/plans/implementation-quality-gate.md` exists.
- Every NIP planning packet must now also include:
  - proof obligations and any non-provable assumptions
  - a seam-contract audit for transport/store/session dependencies
  - a state-machine table for sessioned workflows
  - an adversarial test matrix, not only happy-path and normal negative-path tests
- Follow the staged micro-loop defined in
  `docs/plans/implementation-quality-gate.md`; do not defer examples, audits, or docs to a later
  cleanup pass.
- If the task is refinement of an already-implemented workflow, the planning packet must also name
  which open findings it is intended to close from:
  - `docs/plans/implemented-nips-applesauce-audit-2026-03-15.md`
  - `docs/plans/implemented-nips-zig-native-audit-2026-03-15.md`
- Do not treat a refinement slice as done until the touched workflow is re-audited against both
  audit frames and the targeted findings are updated explicitly.
- Make synchronization explicit in refinement packets:
  - say whether the slice touches the teaching surface
  - say whether it changes audit state
  - say whether it requires startup/discovery doc updates
- Record cross-repo `noztr` issues and improvement ideas in `docs/plans/noztr-feedback-log.md`
  instead of leaving them implicit in local review notes.
- Record non-blocking stale artifacts or unrelated cleanup follow-ups in
  `docs/plans/deferred-cleanup-log.md` and keep the active NIP loop moving.
- If the implementation gate tightens materially, pause new NIP work and re-audit/backfill the
  already-landed NIP slices before continuing the loop.
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
- write down what the SDK layer can prove, what it cannot prove yet, and what seam or kernel help
  would be needed to close any proof gaps
- keep `handoff.md` current
- tighten this `AGENTS.md` if the SDK scope becomes clearer

## Build & Test

- Canonical commands are documented in `docs/plans/build-plan.md`.
- Use Zig as the canonical build/test lane for SDK code.

## Tooling Rule

- Use `bun` for local JavaScript/TypeScript tooling in this repo.
- Do not use `npm` for local interop harness setup or execution.

## Documentation Rule

- Keep `AGENTS.md`, `agent-brief`, and `handoff.md` aligned with the accepted planning baseline.
- When the process changes materially, reconcile the affected control docs together instead of
  appending the new rule beside superseded wording.
- Do not treat copied research or planning artifacts as final truth; refresh and tighten them as
  the SDK scope sharpens.
- Treat examples as part of implementation quality, not optional follow-up material.
- Do not treat a green local test lane as sufficient by itself; the planning docs and handoff must
  also make adversarial coverage, seam assumptions, and residual proof gaps explicit.
- Treat the examples catalog as part of the public teaching surface; when examples change, update
  `examples/README.md` in the same slice.
