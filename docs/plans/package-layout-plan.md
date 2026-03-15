# Noztr SDK Package Layout Plan

Proposed package and module layout for the first implementation cycle.

Date: 2026-03-14

## Goals

- organize SDK code by workflow responsibility instead of re-copying `noztr`'s per-NIP structure
- keep public API entrypoints narrow and discoverable
- preserve room for caller-supplied transports/stores without freezing a large backend surface

## Proposed Source Layout

```text
examples/
  remote_signer_recipe.zig
  mailbox_recipe.zig
  relay_client_recipe.zig
src/
  root.zig
  config.zig
  client/
    mod.zig
    builder.zig
    error.zig
  relay/
    pool.zig
    session.zig
    directory.zig
    auth.zig
  policy/
    liveness.zig
  sync/
    loader.zig
  store/
    traits.zig
    memory.zig
  workflows/
    remote_signer.zig
    mailbox.zig
    identity_verifier.zig
    opentimestamps_verifier.zig
  transport/
    interfaces.zig
    websocket.zig
    http.zig
  testing/
    fake_relay.zig
    fake_http.zig
    fake_store.zig
    transcripts.zig
```

This plan is directional. File splits may change during `M1` and `M2`, but the layer boundaries
should not drift without updating this document.

## Layer Responsibilities

### `src/root.zig`

- the only public package entrypoint
- stays minimal until a workflow/client surface is accepted
- does not contain session logic itself
- Phase 3 keeps substrate modules internal; Phase 4 is the first phase expected to add stable SDK
  namespaces

### `examples/`

- structured downstream recipes modeled after `/workspace/projects/noztr/examples`
- show complete SDK workflows for apps, relays, signers, and clients
- should stay educational and explicit, not hide orchestration behind framework magic

### `src/client/`

- thin top-level SDK configuration and composition once Phase 4 lands
- the place where relay, store, and workflow dependencies are wired together
- should remain thin and explicit, not the home for all session logic

### `src/relay/`

- relay pool and relay session state
- `NIP-11` relay info fetch/cache helpers
- `NIP-42` auth sequencing as session orchestration, not protocol parsing
- pure `NIP-65` extraction remains in `noztr` until `noztr-sdk` grows a richer routing/policy layer

### `src/store/`

- traits for cache/store responsibilities needed by SDK workflows
- small in-memory reference adapters for tests and minimal adopters
- no commitment to persistent database engines in the first milestone

### `src/policy/`

- explicit liveness/backoff and other reusable policy modules
- split out here instead of bloating `relay.pool` once policy becomes stateful or reusable

### `src/sync/`

- loader-style helpers that bridge relay/store misses without collapsing fetch logic into the store
- the first place to split transcript-driven sync code that does not belong inside one workflow

### `src/workflows/`

- orchestration layers that compose `noztr` NIP modules with relay/store adapters
- initial targets: `remote_signer`, `mailbox`, `identity_verifier`, `opentimestamps_verifier`
- each workflow file should explain why it is not kernel logic and not app-specific policy

### `src/transport/`

- caller-facing transport seams
- reference adapters may live here if they remain small and replaceable
- no hidden network startup or background runtime

### `src/testing/`

- fakes and transcript fixtures for deterministic workflow tests
- should be reusable across multiple workflow modules

## Public API Shape

During the substrate phase, the public root should stay minimal and avoid freezing placeholder
namespaces.

Phase 4 landed the first public workflow namespace:
- `noztr_sdk.workflows`
- `noztr_sdk.workflows.RemoteSignerSession`

`noztr_sdk.client` remains deferred until a second workflow proves the composition shape well enough to
freeze.

Relay/store/transport substrate modules may remain internal until the first real workflow proves
which seams are stable enough to publish.

## Rejected Layout Options

- flat per-NIP SDK files mirroring `noztr`
  - rejected because SDK work is cross-NIP orchestration
- app/framework folders in the root package
  - rejected because the first cycle is a Zig SDK, not a UI/runtime framework
- large backend matrix at bootstrap
  - rejected because it would force transport/storage decisions before the workflow seams are proven

## Guardrails

- do not add modules that only proxy through to `noztr` without adding real SDK value
- do not introduce hidden singleton state
- do not freeze backend-specific adapters as the core API
