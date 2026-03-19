# noztr-sdk

Higher-level Zig Nostr SDK built on top of `noztr`.

This repo started from seed artifacts copied from `noztr`, but now has its own accepted planning
baseline for SDK work.

`noztr-sdk` exists to make building Nostr applications, relays, signers, clients, bots, services,
and CLIs simple, explicit, and straightforward in Zig.

## Public Docs Route

If you are evaluating or consuming `noztr-sdk` publicly, start here:

- `docs/release/README.md`
- `docs/release/getting-started.md`
- `docs/release/contract-map.md`
- `examples/README.md`

The product target is now explicit:
- `noztr-sdk` should become the Zig SDK analogue to applesauce in real-world usefulness
- it should be opinionated in the same broad way applesauce is opinionated: clear workflow layers,
  strong defaults, structured examples, and app-facing ergonomics that help real products ship
- it should be ecosystem-compatible rather than repo-local or bespoke
- it should achieve that without collapsing the `noztr` kernel boundary or copying applesauce API
  shapes blindly
- it should not mechanically port TypeScript patterns into Zig; it should use Zig's strengths to
  make the SDK more deterministic, explicit, bounded, easy to reason about, and easier to verify
  than a direct applesauce translation would be

## Current posture

- use `noztr` explicitly as the Zig Nostr protocol kernel dependency
- start against the local `../noztr` checkout first
- keep protocol parsing/validation/building in `noztr`
- keep relay/session/store/sync/workflow composition in `noztr-sdk`
- model SDK ergonomics, real-world teaching posture, and opinionated workflow shape primarily after
  applesauce where that improves clarity and downstream usability
- treat applesauce and rust-nostr-sdk as implementation references, not as protocol authority
- treat `/workspace/projects/noztr/examples` as the kernel recipe reference set
- grow `noztr-sdk`’s own examples as structured workflow recipes above the kernel boundary

## Internal Planning Baseline

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

## Examples

The structured SDK examples tree now lives under `examples/`.

Start here:
- `examples/consumer_smoke.zig`
- `examples/remote_signer_recipe.zig`
- `examples/mailbox_recipe.zig`
- `examples/nip03_verification_recipe.zig`
- `examples/group_session_recipe.zig`

The first examples slice intentionally defers `NIP-05` and `NIP-39` until the HTTP seam teaching
posture is explicit.

For the agent-readable recipe catalog, use `examples/README.md`.
