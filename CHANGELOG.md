# Changelog

All notable project-level changes to `noztr-sdk` should be tracked here.

This changelog tracks the SDK's own release line. It does not use the Zig toolchain version as the
library version.

`noztr-sdk` is currently on the pre-`1.0` line:
- current public release candidate: `0.1.0-rc.1`

## Unreleased

## [0.1.0-rc.1] - 2026-03-25

Release type: rc

### Summary

First intentional public release candidate for `noztr-sdk`.

This RC establishes `noztr-sdk` as the higher-level Zig Nostr SDK above `noztr-core`, with a
documented public route, grouped namespace shape, verified examples, explicit migration guidance,
and a bounded pre-`1.0` compatibility posture.

### Added

- first public RC tag for the documented `noztr-sdk` surface
- public docs route under `README.md`, `docs/`, and `examples/README.md`
- grouped client, workflow, runtime, store, and transport route teaching as the canonical public
  discovery shape
- public migration guidance for the main pre-`1.0` cleanup families
- broad app-facing and SDK-facing surfaces across:
  - relay/runtime/query/replay/publish/session composition
  - local-state/archive/checkpoint/store composition
  - remote signer and signer-tooling composition
  - mailbox and legacy DM workflows and client routes
  - identity and proof verification routes
  - groups, social content, reactions/lists, comment/reply, highlight, and starter WoT routes
  - zap workflow and receipt validation
  - relay-management admin composition
  - shared HTTP and signed-post transport seams where reusable beyond one consumer

### Changed

- broad naming and surface-noise remediation is complete before the first RC rather than deferred
  until after public evaluation
- the public docs route is now route-first and migration-first instead of inventory-first
- the examples catalog now has a clearer route-first entry before the full detailed reference
- relay-management now shares `transport.nip98_post` instead of owning a private signed `POST`
  stack

### Breaking Changes

- no breaking change is introduced by the RC tag itself
- the public line remains pre-`1.0`, so compatibility should still be treated conservatively
- known pre-`1.0` cleanup breaks are documented in the migration guide:
  - `docs/reference/migration-guide.md`

### Compatibility Notes

- Zig toolchain floor for this RC line is `0.15.2`
- use local `../noztr-core` `master` until the next core tag:
  - `v0.1.0-rc.5` shipped a bad `zap_build_coordinate_tag` error-mapping form that is fixed on
    `master`
- `noztr-core` remains the deterministic kernel floor; `noztr-sdk` remains the higher-level
  reusable composition layer above it

### Docs And Examples

- public routing starts at `README.md`, `docs/INDEX.md`, `docs/getting-started.md`, and
  `docs/reference/contract-map.md`
- migration routing starts at `docs/reference/migration-guide.md`
- the examples catalog remains the route-rich public recipe surface under `examples/README.md`
