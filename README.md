# noztr-sdk

Higher-level Zig Nostr SDK built on top of `noztr`.

`noztr-sdk` exists to make building Nostr applications, relays, signers, clients, bots, services,
and CLIs simple, explicit, and straightforward in Zig.

The objective is not the smallest possible wrapper above `noztr`. The objective is a
production-grade generic Zig Nostr SDK that absorbs broadly reusable relay/workflow heavy lifting
while keeping product-specific policy explicit and caller-owned.

## Objective And Posture

- Objective: be the production-grade non-kernel Zig SDK layer above `noztr`, so real Nostr apps,
  relays, signers, bots, services, and CLI tooling do not have to rebuild the same
  relay/session/store/workflow substrate from scratch.
- Modeled after: applesauce, primarily as an ergonomics, workflow, and store-layer reference, not
  as a protocol source of truth or something to port mechanically into Zig.
- Philosophy: keep deterministic protocol-kernel behavior in `noztr`, keep reusable non-kernel
  relay/session/store/sync/workflow composition in `noztr-sdk`, keep product-specific policy
  above the SDK, and prefer explicit caller-owned control over hidden runtime magic.
- Values: clarity, boundedness, reuse, Zig-native design, and honesty about what belongs in the
  SDK versus what belongs above it.

## What noztr-sdk is

- The higher-level Zig SDK layer above the `noztr` protocol kernel.
- Focused on workflow composition, transport seams, caller-owned stores, explicit runtime control,
  and reusable relay/workflow heavy lifting that many apps would otherwise rebuild.
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

`noztr-sdk` is also the generic downstream-targetable Zig Nostr SDK foundation for higher-level
Zig libraries that want to sit above Nostr without rebuilding the same bounded relay/workflow
substrate locally.

The accepted downstream shape is mixed on purpose:
- `noztr` remains the true protocol-kernel floor
- `noztr-sdk` is the production-ready non-kernel layer above it
- downstream SDKs should not build a third parallel generic Nostr relay/runtime layer locally

Use `docs/reference/downstream-sdk-boundary.md` when you need the explicit line between what stays
in `noztr` and what should start in `noztr-sdk`.

That means:
- `noztr-sdk` owns generic Nostr-facing transport seams, relay/runtime plans, typed next-step
  helpers, and reusable bounded orchestration substrate.
- `noztr-sdk` should absorb common relay/auth/query/exchange/replay/lifecycle heavy lifting when
  that work is generic across many Nostr apps and SDK consumers.
- `noztr-sdk` already provides reusable relay response, replay/checkpoint, neutral local-state,
  remembered workspace, and remote-signer/session composition above those shared seams.
- downstream libraries own their own protocol-specific contracts and product/runtime policy above
  that floor.
- `noztr-sdk` does not currently promise a generic public websocket framework or hidden background
  runtime.

## Public Namespace Shape

The stable top-level public namespaces are still:
- `noztr_sdk.workflows`
- `noztr_sdk.client`
- `noztr_sdk.store`
- `noztr_sdk.runtime`
- `noztr_sdk.transport`

Within `workflows` and `client`, the canonical grouped routes are now:
- `workflows.groups.*`
- `workflows.identity.*`
- `workflows.dm.*`
- `workflows.proof.*`
- `workflows.signer.*`
- `workflows.zaps.*`
- `client.local.*`
- `client.relay.*`
- `client.relay.management.*`
- `client.signer.*`
- `client.dm.*`
- `client.identity.*`
- `client.social.*`
- `client.proof.*`
- `client.groups.*`

The older flat `client.*Type` and `workflows.*Type` routes are gone. Use the grouped routes as the
canonical public namespace shape.

## Build

```bash
zig build
zig build test --summary all
```

Import/module naming uses `noztr_sdk` in Zig-facing package metadata.

## Versioning And Compatibility

`noztr-sdk` uses its own project version line.

It does not use the Zig toolchain version as the library version.

Current project line:
- `0.1.0-rc.1`
- first public release candidate

Current toolchain baseline:
- Zig `0.15.2`

For release criteria, tagging guidance, and first-release framing, use
`docs/reference/release-process.md`.

## Quick Start

1. Read `docs/getting-started.md` for the shortest public path into the SDK.
2. Use `docs/reference/contract-map.md` to find the right workflow symbols.
3. Open `examples/README.md` and choose one direct recipe for the job you want to build.

## Examples

The structured SDK examples tree now lives under `examples/`.

Start here:
- `examples/consumer_smoke.zig`
- `examples/downstream_mixed_route.zig`
- `examples/remote_signer.zig`
- `examples/signer_client.zig`
- `examples/social_profile_content_client.zig`
- `examples/social_graph_wot_client.zig`
- `examples/zap_flow.zig`
- `examples/relay_management_client.zig`
- `examples/mixed_dm_client.zig`

For one-line route guidance:
- `client.relay.*` and `client.local.*`: `publish_client.zig`
- `client.social.*`: `social_profile_content_client.zig`
- `client.dm.*`: `mixed_dm_client.zig` (and legacy mailbox flows)
- `workflows.zaps.*`: `zap_flow.zig`
- `client.relay.management.*`: `relay_management_client.zig`

For the agent-readable recipe catalog, use `examples/README.md`.
