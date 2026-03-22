---
title: Public Docs Index
doc_type: index
status: active
owner: noztr-sdk
read_when:
  - onboarding_public_consumers
  - routing_public_sdk_docs
  - evaluating_noztr_sdk_publicly
canonical: true
---

# Public Docs Index

This is the public-facing documentation route for `noztr-sdk`.

Use these docs if you are evaluating the SDK, trying to build on top of it, or looking for the
current public workflow contract.

`noztr` and `noztr-sdk` are complementary layers:

- `noztr` owns deterministic protocol-kernel behavior
- `noztr-sdk` owns higher-level workflow, transport, store, and application-facing composition

## Start Here

- [README.md](../README.md)
  - short overview, posture, and build/test commands
- [CONTRIBUTING.md](../CONTRIBUTING.md)
  - public contributor and LLM route for working in this repo
- [getting-started.md](./getting-started.md)
  - shortest public route from install/import to first workflow examples
- [public contract map](./reference/contract-map.md)
  - task-to-symbol route for the current public workflow surface
- [remote signer naming migration](./reference/remote-signer-naming-migration.md)
  - short pre-`1.0` migration note for direct `remote_signer` submodule imports
- [workflow submodule naming migration](./reference/workflow-submodule-naming-migration.md)
  - short pre-`1.0` migration note for direct `group_session` and `mailbox` submodule imports
- [local state client migration](./reference/local-state-client-migration.md)
  - short pre-`1.0` migration note for `RelayWorkspaceClientConfig` and the new canonical
    local-state route
- [examples/README.md](../examples/README.md)
  - workflow recipes and teaching routes

## Current Public Scope

The current public workflow floor includes:

- one minimal CLI-facing client composition surface above the shared store and runtime floors
- one neutral local-state client composition route above shared archive, registry, checkpoint, and
  relay-runtime seams
- shared bounded store/query/checkpoint reference surfaces
- one minimal CLI-facing archive helper over that shared store seam
- one relay-local checkpoint helper over that shared checkpoint seam
- one relay-local `NIP-29` replay helper over that shared event seam
- one shared relay-pool runtime floor over bounded relay-local sessions
- one shared relay-pool checkpoint composition path over the shared checkpoint seam
- `NIP-46` remote signer workflow
- `NIP-17` mailbox workflow
- `NIP-39` identity verification workflow
- `NIP-03` OpenTimestamps verification workflow
- `NIP-05` identity resolution workflow
- `NIP-29` group workflow

## Important Note On Internal Docs

This repo may also contain local-only maintainer docs under `.private-docs/`.

That material is not part of the public SDK documentation route.

In general:

- `docs/` is public-facing SDK documentation
- `examples/` is public-facing usage material
- `.private-docs/` is a local maintainer override when present

If you are not actively contributing to `noztr-sdk`, start with the public docs and examples
first.
