# NZDK Build Plan

Seed planning baseline for `nzdk`.

This file is intentionally a template copied at bootstrap time. It exists so `nzdk` can replace it
with its own accepted execution baseline instead of inheriting `noztr`'s process by implication.

## Current Role

- temporary canonical planning baseline until `nzdk` writes its own real plan
- ties startup and handoff to an explicit planning artifact
- keeps research, scope, and milestone work from drifting into undocumented execution

## Immediate Required Replacements

Before broad implementation begins, replace this template with an `nzdk`-specific plan covering:

1. SDK purpose and target users
2. dependency and tooling posture
3. package / module layout
4. first milestone scope
5. parity / reference strategy
6. testing strategy
7. `noztr` boundary rules
8. review and documentation workflow

## Current Boundary Reminder

- `noztr` owns deterministic protocol parsing, validation, serialization, and cryptographic
  boundaries that are already implemented there.
- `nzdk` owns orchestration, workflow composition, network fetches, stores, session handling, sync,
  and higher-level client/server SDK ergonomics.

## Primary SDK Reference

- applesauce is the primary SDK ergonomics/modeling input
- rust-nostr-sdk is a secondary ecosystem/reference input
- neither overrides NIP text or the `noztr` / `nzdk` ownership boundary
