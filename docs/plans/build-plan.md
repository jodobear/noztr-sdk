# Noztr SDK Build Plan

Accepted execution baseline for `noztr-sdk`.

Date: 2026-03-14

`noztr-sdk` is no longer operating from a copied bootstrap template. This document is the canonical
planning baseline for the repo until it is superseded by a later accepted revision.

The immediate execution loop for the next implementation cycle is defined in
[autonomous-loop-phases-1-4.md](./autonomous-loop-phases-1-4.md).

All new workflow and substrate work must also satisfy the pre-implementation and review gate in
[implementation-quality-gate.md](./implementation-quality-gate.md).

## Purpose

`noztr-sdk` is the higher-level Zig Nostr SDK that composes `noztr`'s deterministic protocol kernel into
bounded, testable SDK workflows.

Target users:
- Zig application authors building clients, relays, signers, bots, services, and CLI tools
- teams that want explicit relay/session/store orchestration over hidden runtime magic
- future bindings or apps that need a stable SDK layer above `noztr`

Non-goals for the first baseline:
- replacing `noztr` as the source of truth for protocol parsing, validation, or builders
- shipping database engines, GUI flows, or secret-storage products in the first milestone
- copying applesauce or rust-nostr API shapes directly

## Frozen Defaults

- `D-NOZTR_SDK-001` local kernel dependency:
  - primary dependency target: `/workspace/projects/noztr`
  - repo-relative path: `../noztr`
  - `noztr-sdk` starts against the local checkout first; remote/tagged dependency work is deferred
- `D-NOZTR_SDK-002` primary modeling references:
  - applesauce local mirror: `/workspace/pkgs/nostr/applesauce`
  - rust-nostr local mirror: `/workspace/pkgs/nostr/rust-nostr/nostr`
  - applesauce is the primary SDK ergonomics reference
  - rust-nostr is the secondary ecosystem/reference input
  - current refresh record: [research-refresh-2026-03-14.md](./research-refresh-2026-03-14.md)
  - note: local checked-out mirror commits still match the commit hashes used in the March 4, 2026
    studies; March 14, 2026 research also inspected fetched upstream refs without changing local
    checkouts
- `D-NOZTR_SDK-003` first workflow milestone:
  - start with orchestration-heavy surfaces intentionally left out of `noztr`
  - milestone-1 workflow targets: `NIP-46`, `NIP-11`, `NIP-65`, `NIP-17`, `NIP-39`, `NIP-03`
  - foundational dependencies reused from `noztr`: `NIP-44`, `NIP-59`, `NIP-06`, `NIP-42`
- `D-NOZTR_SDK-004` tooling posture:
  - Zig is the canonical implementation/build/test lane
  - `bun` is the only allowed JavaScript/TypeScript tooling for local interop harnesses
  - no alternate JS package manager is allowed in this repo
- `D-NOZTR_SDK-005` runtime posture:
  - no hidden global runtime, hidden threads, or implicit network side effects
  - SDK orchestration must remain explicit, bounded, and testable with fake transports/stores

## Decisions

- `NOZTR_SDK-BP-001`: keep `noztr` as the single protocol-kernel import surface and land kernel gaps in
  `noztr` first when the boundary answers are weak.
- `NOZTR_SDK-BP-002`: structure `noztr-sdk` around workflow layers instead of per-NIP file mirroring.
- `NOZTR_SDK-BP-003`: keep the top-level client facade thin; put liveness, sync, routing, and workflow
  orchestration in dedicated layers below it.
- `NOZTR_SDK-BP-004`: prefer narrow transport/store interfaces plus reference in-memory adapters over
  shipping a broad backend matrix in the first milestone.
- `NOZTR_SDK-BP-005`: define canonical build commands only when the scaffold lands; until then the plan,
  not ad hoc commands, is the source of truth.

## Boundary Rules

`noztr` owns:
- deterministic parse, validate, serialize, sign, verify, and fixed-capacity reduction logic
- exact NIP message contracts and trust-boundary helpers
- bounded typed data models that do not require network, storage, or policy orchestration

`noztr-sdk` owns:
- relay pools, connection/session state, auth sequencing, retries, and failover policy
- relay metadata fetches, relay-list hydration, mailbox sync, signer sessions, and proof retrieval
- local stores, caches, sync policy, and workflow composition
- application-facing convenience that remains reusable across multiple apps

Every major SDK helper must answer:
1. why is this not already covered by `noztr`?
2. why is this not app code above `noztr-sdk`?
3. why is this the simplest useful SDK layer?

## Baseline Module Plan

The initial package layout is defined in [package-layout-plan.md](./package-layout-plan.md). The
high-level shape is:
- `src/root.zig` as the single public namespace
- `src/client/` for thin top-level SDK entrypoints and configuration
- `src/relay/` for relay pool, relay metadata, routing, and auth/session helpers
- `src/policy/` and `src/sync/` as split points once relay liveness or workflow loading outgrows
  the relay modules
- `src/store/` for store traits and small in-memory reference adapters
- `src/workflows/` for `NIP-46`, `NIP-17`, `NIP-39`, and `NIP-03` orchestration
- `src/testing/` for fakes and transcript fixtures used by SDK state tests
- top-level `examples/` for structured workflow recipes once the first two workflows settle

## Milestone Order

1. `M0` Planning baseline
   - replace template planning files
   - freeze dependency posture and package layout
2. `M1` Scaffold and dependency wiring
   - add `build.zig`, `build.zig.zon`, `src/root.zig`, and initial test step
   - wire local `noztr` import from `../noztr`
   - establish core namespaces and test fakes
3. `M2` Relay/session substrate
   - relay pool/session state
   - `NIP-11` relay-info fetch/cache flow over kernel parsing helpers
   - `NIP-65` stays at the kernel boundary until a richer SDK routing/policy layer exists
4. `M3` Remote signer session
   - `NIP-46` connection token flow, request/response correlation, relay switching, auth challenge
     handling
5. `M4` Private mailbox session
   - `NIP-17` mailbox discovery and gift-wrap inbox workflow over `NIP-44`/`NIP-59`
6. `M5` Proof and identity fetchers
   - `NIP-39` provider verification adapters
   - `NIP-03` remote proof retrieval/verification adapters
7. `M6` Group/session expansion
   - evaluate `NIP-29` sync/store as the first larger stateful workflow after the core substrate is
     stable

## Autonomous Execution Mode

For the current cycle, milestone execution should follow the phase loop in
[autonomous-loop-phases-1-4.md](./autonomous-loop-phases-1-4.md).

Mapping:
- Phase 1 maps to research refresh and planning updates before `M1`
- Phase 2 maps to `M1`
- Phase 3 maps to `M2`
- Phase 4 maps to `M3`

The phase loop is stricter than the milestone list:
- each phase must pass at least three review gates after implementation
- a phase cannot advance until its review gates pass
- findings discovered by any review must be fixed before phase close

## Dependency And Tooling Strategy

- first implementation milestone must add a local path dependency on `/workspace/projects/noztr`
- `noztr-sdk` should import `noztr` as a package and consume `src/root.zig` exports; it should not copy
  `noztr` source files into this repo
- `noztr-sdk` should reuse `noztr`'s enabled I6 extensions by default unless an explicit SDK decision
  requires a narrower profile
- Zig-only code stays under the repo root; any JS interop harness belongs under `tools/` and uses
  `bun`
- `/workspace/projects/noztr/examples` is the kernel recipe reference set for downstream teaching
  style
- `noztr-sdk` should add its own structured examples for orchestration-heavy workflows instead of
  overloading the kernel examples with SDK behavior

Canonical commands after `M1` lands:
- `zig build`
- `zig build test --summary all`
- `bun test <tool-path>` only for opt-in JS interop harnesses added under `tools/`

## Testing And Parity Strategy

The full strategy is defined in [testing-parity-strategy.md](./testing-parity-strategy.md).

Short form:
- parity priority is behavior and workflow invariants, not API mimicry
- `noztr` plus NIP text are the authority for protocol behavior
- applesauce and rust-nostr inform workflow design, relay/session invariants, and ergonomics only
- every session/store workflow should have transcript-style tests with fake relay/http/store
  adapters

## Review And Documentation Workflow

Execution order for non-trivial work:
1. research refresh for touched NIPs and reference patterns
2. write the implementation packet required by
   [implementation-quality-gate.md](./implementation-quality-gate.md)
3. update planning docs if the scope boundary shifts
4. implement
5. review against boundary questions and tests
6. update docs, examples posture, and `handoff.md`

Minimum gate for each new NIP-backed slice:
- scope card
- NIP/kernel inventory
- explicit boundary answers
- example-first API sketch
- declared test matrix
- acceptance checks

No new workflow should be considered complete until its structured example shape and negative-path
test coverage are both defined.

Required artifacts before broad implementation expands beyond `M1`:
- accepted package layout
- accepted `noztr` integration plan
- accepted testing/parity strategy
- current handoff that names the next execution slice

## Tradeoffs

## Tradeoff T-NOZTR_SDK-BP-001: Thin kernel reuse versus SDK-local protocol duplication

- Context: `noztr` already implements the protocol contracts `noztr-sdk` needs as dependencies.
- Options:
  - O1: re-wrap and reuse `noztr` directly.
  - O2: copy protocol-shaped helpers into `noztr-sdk` for local convenience.
- Decision: O1.
- Benefits: one protocol authority, lower drift risk, clearer ownership boundary.
- Costs: some SDK work will block on kernel gaps being fixed upstream first.
- Risks: developers may try to bypass the boundary for speed.
- Mitigations: require explicit boundary answers for major helpers and keep the ownership map current.

## Tradeoff T-NOZTR_SDK-BP-002: Workflow-first module layout versus per-NIP SDK modules

- Context: SDK responsibilities are orchestration-heavy and cut across multiple NIPs.
- Options:
  - O1: mirror `noztr` with one SDK file/module per NIP.
  - O2: group SDK code by workflow responsibility and import NIP helpers from `noztr`.
- Decision: O2.
- Benefits: clearer ownership, better composition, less false pressure to duplicate protocol code.
- Costs: mapping a workflow to underlying NIPs requires more documentation.
- Risks: careless workflow modules could become too broad.
- Mitigations: keep package layout explicit and keep module-level ownership notes in planning docs.

## Tradeoff T-NOZTR_SDK-BP-003: Embedded adapters versus backend matrix in the first milestone

- Context: SDK workflows need transport/store seams, but backend sprawl would slow the bootstrap.
- Options:
  - O1: define small interfaces and provide reference in-memory adapters first.
  - O2: attempt full HTTP/WebSocket/storage backend coverage immediately.
- Decision: O1.
- Benefits: faster bootstrap, tighter tests, fewer premature abstractions.
- Costs: early adopters may need to write adapters before the SDK ships batteries-included options.
- Risks: interface design could be too narrow if not tested against real workflows.
- Mitigations: validate the seams against `M2`-`M5` workflows before freezing them.

## Open Questions

- `OQ-NOZTR_SDK-BP-001`: whether `noztr-sdk` should expose a synchronous step-driven transport interface, an
  async callback model, or both in the first implementation slice
- `OQ-NOZTR_SDK-BP-002`: whether the first reference HTTP adapter should land in `M2` using Zig stdlib
  directly or remain interface-only until a later substrate pass
- `OQ-NOZTR_SDK-BP-003`: whether `NIP-29` group sync should wait until after signer/mailbox workflows
  stabilize or grow in parallel once the relay pool substrate exists

## Principles Compliance

- `P01`: protocol integrity remains in `noztr`; SDK workflows consume verified/bounded kernel data.
- `P02`: module layout stays composable and transport-aware without hiding transport choice.
- `P03`: parity is behavioral and workflow-oriented, not API-cloning.
- `P04`: relay routing, fetch policy, and retries stay explicit.
- `P05`: session/state transitions are expected to be deterministic for identical transcripts.
- `P06`: stores, caches, and session helpers remain bounded and testable.
