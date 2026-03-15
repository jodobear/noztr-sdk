# noztr-sdk

Higher-level Zig Nostr SDK built on top of `noztr`.

This repo started from seed artifacts copied from `noztr`, but now has its own accepted planning
baseline for SDK work.

`noztr-sdk` exists to make building Nostr applications, relays, signers, clients, bots, services,
and CLIs simple, explicit, and straightforward in Zig.

## Current posture

- use `noztr` explicitly as the Zig Nostr protocol kernel dependency
- start against the local `../noztr` checkout first
- keep protocol parsing/validation/building in `noztr`
- keep relay/session/store/sync/workflow composition in `noztr-sdk`
- model SDK ergonomics primarily after applesauce where that improves clarity
- treat applesauce and rust-nostr-sdk as implementation references, not as protocol authority
- treat `/workspace/projects/noztr/examples` as the kernel recipe reference set
- grow `noztr-sdk`’s own examples as structured workflow recipes above the kernel boundary

## Planning baseline

- canonical execution baseline: `docs/plans/build-plan.md`
- kickoff scope: `docs/plans/sdk-kickoff.md`
- package layout: `docs/plans/package-layout-plan.md`
- `noztr` integration: `docs/plans/noztr-integration-plan.md`
- testing/parity strategy: `docs/plans/testing-parity-strategy.md`
- ownership decisions: `docs/plans/api-ownership-map.md`

## Build

```bash
zig build
zig build test --summary all
```

Import/module naming uses `noztr_sdk` in Zig-facing package metadata.
