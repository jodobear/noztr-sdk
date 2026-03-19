---
title: Zig Nostr Ecosystem Readiness Matrix
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - defining_broader_product_scope
  - selecting_major_nontrivial_lanes
  - evaluating_production_readiness
depends_on:
  - docs/plans/build-plan.md
  - docs/plans/noztr-sdk-ownership-matrix.md
---

# Zig Nostr Ecosystem Readiness Matrix

Strategic reference for the broader goal:

- `noztr` as the Zig protocol/kernel foundation
- `noztr-sdk` as the app-facing Zig SDK
- ecosystem products on top:
  - relays
  - Blossom servers/clients
  - remote signers
  - CLI tools
  - real end-user clients and services

This doc is intentionally not a packet, milestone checklist, or commit-by-commit backlog.
It defines what "production-ready usable Zig Nostr ecosystem" actually means so implementation
lanes can be selected against a complete target, not only the currently active NIP slices.

## Core Point

Counting implemented NIPs is not enough.

A production-ready Zig Nostr ecosystem needs:

- protocol/kernel correctness
- app-facing SDK workflows
- client/runtime/store layers
- server/operator products
- tooling
- docs/examples/discoverability
- release/interoperability discipline

The real missing work is mostly product and runtime surface, not only more protocol helpers.

## Readiness Levels

Use these levels when evaluating any major area.

### `R0` Research

- research-grade or experiment-grade only
- useful for validation, not for external adoption

### `R1` Developer Preview

- usable locally by repo maintainers
- incomplete workflow or operational posture
- examples and tests exist, but product expectations are still narrow

### `R2` Bounded Beta

- coherent public surface
- explicit ownership and boundedness
- useful to outside developers for a constrained set of workflows
- still missing broader runtime/store/operator posture

### `R3` Production Candidate

- complete enough for real apps or services in its target lane
- strong docs/examples
- interoperability and failure posture are well understood
- packaging/release expectations exist

### `R4` Production Ready

- stable public surface
- strong interop confidence
- operator-facing guidance exists where relevant
- release/versioning posture is real
- not only usable by repo authors

## Ecosystem Scope

The ecosystem target naturally splits into three layers.

### 1. Kernel Layer: `noztr`

Owns:

- deterministic parse/validate/build/serialize/sign/verify
- bounded reducers and low-level protocol helpers

Readiness target:

- `R4`

Why:

- every higher layer depends on this being boring, correct, and stable

### 2. SDK Layer: `noztr-sdk`

Owns:

- relay/session orchestration
- fetches and HTTP seams
- stores and caches
- app-facing workflows
- client/runtime/store policy layers

Readiness target:

- `R4`

Why:

- this is the main developer-facing Zig Nostr surface

### 3. Product Layer

Built on top of `noztr` and `noztr-sdk`.

Major product families:

- relay implementations
- Blossom server/client tooling
- remote signer products
- CLI tools, including a `nak`-class Zig tool
- app/client foundations
- operator tooling and diagnostics

Readiness target:

- individual products may ship at different readiness levels
- the ecosystem as a whole is not "production-ready" unless at least one credible product exists
  in each critical family

## Capability Matrix

### A. Protocol Kernel

Goal:

- `noztr` is strong enough that downstream products do not re-implement protocol logic

Production-ready means:

- broad protocol coverage for the ecosystem lanes we intend to own
- strong misuse/error behavior
- stable public docs and reference examples
- explicit compatibility/support posture

Current posture:

- strong foundation
- not evaluated here in detail, but this is the closest layer to production discipline already

### B. App-Facing SDK Workflows

Goal:

- `noztr-sdk` feels like the Zig analogue to applesauce, not a research wrapper

Production-ready means:

- complete client-signing-publishing-receiving workflows
- coherent runtime/store policy
- examples that teach real app paths
- consistent ownership and boundedness across workflows

Current posture:

- roughly `R2` overall
- several workflows are strong in bounded form
- still missing broader product/runtime completeness

Current strong lanes:

- `NIP-46`
- `NIP-17`
- `NIP-39`
- `NIP-03`
- `NIP-05`
- `NIP-29`

Current missing breadth:

- richer client/feed/social workflows
- richer event composition surfaces
- more complete store/runtime/client architecture

### C. Client Runtime And Store Architecture

Goal:

- real applications can build on one clear runtime/store posture

Production-ready means:

- relay pool model
- subscription model
- reconnect/retry strategy
- durable store integration
- sync model
- event/query/index posture
- clear background-runtime ownership

Current posture:

- below `R2`
- partial runtime helpers exist in workflow-specific form
- repo still lacks a broader shared client/store/runtime architecture

This is one of the biggest remaining gaps.

### D. Relay Products

Goal:

- Zig-native relay implementations and operator-facing relay tooling

Production-ready means:

- at least one credible relay implementation
- configuration, moderation, storage, observability, and operations posture
- compatibility with existing Nostr clients and relay expectations

Current posture:

- effectively not started in this repo

### E. Blossom Products

Goal:

- credible Zig Blossom server/client implementation and related workflows

Production-ready means:

- upload/download paths
- auth/access-control posture where relevant
- file metadata and server behavior compatibility
- operator/deployment guidance

Current posture:

- effectively not started in this repo

### F. CLI Tooling

Goal:

- Zig-native command-line tools comparable in practical usefulness to `nak`

Production-ready means:

- inspect, query, publish, sign, verify, relay, and debugging paths
- scripting-friendly output
- operator-friendly ergonomics

Current posture:

- effectively not started in this repo

### G. Remote Signer Products

Goal:

- not only a workflow helper, but a usable signer product/tooling story

Production-ready means:

- signer app/service/tooling
- session/auth UX
- relay/runtime posture
- operator and end-user docs

Current posture:

- protocol workflow support is meaningful
- product/tooling story is still below production scope

### H. App Client Foundations

Goal:

- enough surface to build real Zig clients, bots, services, and agents without bespoke substrate
  rebuilding

Production-ready means:

- account/profile/contact/feed/message/group primitives
- sync/store/runtime architecture
- publish/query helpers
- examples that look like real application code

Current posture:

- partial
- this is the main long-term target of `noztr-sdk`

### I. Release, Interop, And Operator Posture

Goal:

- outside users can depend on the ecosystem safely

Production-ready means:

- versioning policy
- release flow
- compatibility guarantees
- interop/parity testing
- performance and security audits where justified
- deployment and operator docs for product repos

Current posture:

- below production-ready
- process quality is strong, but release/operator discipline is still earlier-stage

## What Is Already Covered Well

These are meaningful strengths, not just partial experiments:

- deterministic kernel boundary discipline
- bounded Zig workflow design
- examples integrated into implementation quality
- strong packet/gate/audit process
- clean slice-by-slice git history
- broad early workflow floor in `noztr-sdk`

## What Is Most Missing

The largest missing areas are:

1. shared client/runtime/store architecture
2. broader app-facing workflow breadth outside the currently implemented NIP set
3. first-class product repos/tools:
   - relay
   - Blossom
   - CLI
   - signer product
4. release/interoperability/operator maturity

Those matter more than simply "adding more NIPs."

## Recommended Build Order

If the goal is to single-handedly create the Zig Nostr ecosystem, the safest order is:

### Phase 1. Finish The SDK Core

Focus:

- close the major active `noztr-sdk` workflow gaps
- define one broader client/runtime/store posture
- keep examples and audits strong

Success looks like:

- `noztr-sdk` reaches `R3` in its intended core lanes

### Phase 2. Build The Tooling Spine

Focus:

- CLI tooling
- operator/debug tooling
- signer tooling

Why:

- tools accelerate all later product work
- tools also pressure-test the SDK in real usage

### Phase 3. Build One Credible Server Product

Recommended order:

1. relay
2. Blossom

Why:

- they exercise store/runtime/operator concerns in a way SDK-only work cannot

### Phase 4. Build One Credible App/Client Foundation

Focus:

- feed/profile/message/group client foundations above the SDK

Why:

- this proves the SDK is truly app-facing, not only workflow-complete in isolation

### Phase 5. Harden For Production

Focus:

- release/versioning policy
- interop matrix
- performance/memory audit programs
- security/hardening review
- deployment/operator docs

## Near-Term Repo Implications

For `noztr-sdk`, this means:

- the repo should keep finishing the current broader workflow lanes
- but should also prepare one explicit higher-level client/runtime/store architecture lane soon
- after that, the next major strategic move should likely be a separate tooling or product repo,
  not endless local helper refinement

## Honest Readiness Estimate

If the target is "production-ready Zig Nostr ecosystem," current overall progress is still early.

Approximate posture:

- `noztr` foundation: comparatively advanced
- `noztr-sdk`: meaningful but still partial
- wider Zig Nostr ecosystem products: mostly not built yet

So the ecosystem as a whole is still far from complete.

That is fine, as long as we optimize for the right target:

- not "how many NIPs are done"
- but "how many real Zig Nostr product layers are now actually credible"
