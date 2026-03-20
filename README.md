# noztr-sdk

Higher-level Zig Nostr SDK built on top of `noztr`.

`noztr-sdk` exists to make building Nostr applications, relays, signers, clients, bots, services,
and CLIs simple, explicit, and straightforward in Zig.

## What noztr-sdk is

- The higher-level Zig SDK layer above the `noztr` protocol kernel.
- Focused on workflow composition, transport seams, caller-owned stores, and explicit runtime
  control.
- Intended for real clients, signers, relays, bots, services, and CLI tooling.
- Deliberate about ownership and boundedness rather than hiding behavior behind global runtime
  magic.

For the public docs route as a whole, start with `docs/INDEX.md`.

## Public Docs Route

If you are evaluating, consuming, or contributing to `noztr-sdk`, start here:

- `AGENTS.md`
- `docs/INDEX.md`
- `examples/README.md`
- `CONTRIBUTING.md`

Then continue with:

- `docs/getting-started.md`
- `docs/reference/contract-map.md`

## Public Docs Versus Internal Docs

This repo intentionally keeps two documentation routes:

- public SDK docs:
  - `docs/INDEX.md`
  - `docs/getting-started.md`
  - `docs/reference/contract-map.md`
  - `examples/README.md`
- internal maintainer docs:
  - `.private-docs/`

If you are consuming the SDK, stay on the public route.
If you are working in a local maintainer clone, use `.private-docs/` when present.

## Public SDK Posture

- Keep deterministic protocol parsing, validation, and event-building in `noztr`.
- Keep relay/session/store/sync/workflow composition in `noztr-sdk`.
- Model SDK ergonomics after real downstream usage, while preserving the `noztr` kernel boundary.
- Use Zig package/import naming via `noztr_sdk`.

If you are working locally with the sibling `../noztr-core` checkout, its `examples/README.md` is
the kernel recipe reference set below this SDK layer.

## Build

```bash
zig build
zig build test --summary all
```

Import/module naming uses `noztr_sdk` in Zig-facing package metadata.

## Quick Start

1. Read `docs/getting-started.md` for the shortest public path into the SDK.
2. Use `docs/reference/contract-map.md` to find the right workflow symbols.
3. Open `examples/README.md` and choose one direct recipe for the job you want to build.

## Examples

The structured SDK examples tree now lives under `examples/`.

Start here:
- `examples/consumer_smoke.zig`
- `examples/remote_signer_recipe.zig`
- `examples/mailbox_recipe.zig`
- `examples/nip03_verification_recipe.zig`
- `examples/group_session_recipe.zig`

For the agent-readable recipe catalog, use `examples/README.md`.
