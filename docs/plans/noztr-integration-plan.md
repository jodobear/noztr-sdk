---
title: Noztr SDK Noztr Integration Plan
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - changing_noztr_dependency_posture
  - revisiting_kernel_integration_rules
---

# Noztr SDK Noztr Integration Plan

Dependency and ownership plan for integrating `noztr-sdk` with the local `noztr` checkout.

Date: 2026-03-14

## Goal

Make `noztr` the explicit kernel dependency for `noztr-sdk` without copying protocol logic or leaking
kernel internals into SDK policy code.

## Current Dependency Target

- local path: `/workspace/projects/noztr`
- repo-relative path: `../noztr`
- current observed package surface:
  - single Zig package rooted at `src/root.zig`
  - package name `noztr`
  - static library build plus test step in `/workspace/projects/noztr/build.zig`

## Integration Rules

- `noztr-sdk` imports `noztr` as a package and consumes its root exports
- `noztr-sdk` does not copy NIP modules, crypto backends, or trust-boundary helpers into this repo
- when SDK work exposes a missing kernel primitive, fix `noztr` first unless the missing behavior
  clearly belongs above the kernel boundary
- `noztr-sdk` should treat `noztr`'s public root export surface as the stable dependency seam

## Initial Import Strategy

The first scaffold should establish:
- `build.zig.zon` entry for the local `../noztr` package
- package import under the name `noztr`
- `src/root.zig` re-export patterns that keep `noztr` visible as a dependency, not hidden magic

Expected usage shape:

```zig
const noztr = @import("noztr");
```

SDK modules should then compose exported helpers such as:
- `noztr.nip01_message`
- `noztr.nip11`
- `noztr.nip17_private_messages`
- `noztr.nip39_external_identities`
- `noztr.nip46_remote_signing`
- `noztr.nip44`
- `noztr.nip59_wrap`
- `noztr.nip65_relays`

## Dependency Boundaries

`noztr-sdk` may rely on `noztr` for:
- event and message parsing
- exact NIP data models/builders
- gift-wrap and encrypted payload primitives
- mnemonic/key-derivation helpers
- deterministic reducer/helper logic

`noztr-sdk` must own:
- relay selection and connection lifecycle
- request correlation and retry policy
- HTTP/WebSocket fetch adapters and timeouts
- stores/caches and sync policy
- provider-specific proof retrieval and verification flows

## Feature Posture

- keep `noztr`'s default extension posture unless an explicit SDK reason requires disabling it
- avoid introducing an SDK-local feature matrix that redefines kernel scope
- if `noztr-sdk` narrows optional behavior, that narrowing must be documented in planning docs

## Integration Risks

- local path coupling can drift if `noztr`'s package surface changes unexpectedly
- SDK authors may be tempted to wrap private `noztr` internals instead of public exports
- transport/store abstractions may accidentally mirror app-specific needs instead of reusable SDK
  requirements

Mitigations:
- keep this plan and the API ownership map current
- prefer small adapter interfaces
- promote boundary gaps back into `noztr` instead of growing duplicate helpers

## Implementation Entry Checklist

Before `M1` code lands:
- confirm the local `../noztr` package still builds
- add `noztr-sdk` package metadata and dependency wiring
- add a smoke test proving `noztr-sdk` can import and use a small `noztr` surface
- document any kernel gaps discovered during scaffold work in `handoff.md`
