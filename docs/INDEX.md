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

If you are evaluating `noztr-sdk` for another Zig SDK, read the downstream boundary guide early:
- what stays in `noztr`
- what should start in `noztr-sdk`
- why downstream libraries should not rebuild a parallel generic Nostr relay/runtime layer locally

## Start Here

- [README.md](../README.md)
  - short overview, posture, and build/test commands
- [CONTRIBUTING.md](../CONTRIBUTING.md)
  - public contributor and LLM route for working in this repo
- [getting-started.md](./getting-started.md)
  - shortest public route from install/import to first workflow examples
- [public contract map](./reference/contract-map.md)
  - task-to-symbol route for the current public workflow surface
- [downstream SDK boundary](./reference/downstream-sdk-boundary.md)
  - explicit `noztr` versus `noztr-sdk` split for another Zig SDK
- [release process](./reference/release-process.md)
  - project versioning, RC criteria, tagging guidance, and first-release framing
- [CHANGELOG.md](../CHANGELOG.md)
  - project-level release line and notable changes
- [remote signer naming migration](./reference/remote-signer-naming-migration.md)
  - short pre-`1.0` migration note for direct `remote_signer` submodule imports
- [workflow submodule naming migration](./reference/workflow-submodule-naming-migration.md)
  - short pre-`1.0` migration note for direct `group_session` and `mailbox` submodule imports
- [grouped public namespace migration](./reference/grouped-public-namespace-migration.md)
  - short pre-`1.0` migration note for the breaking grouped-route cleanup in `client` and
    `workflows`
- [local state client migration](./reference/local-state-client-migration.md)
  - short pre-`1.0` migration note for `RelayWorkspaceClientConfig` and the new canonical
    local-state route
- [examples/README.md](../examples/README.md)
  - workflow recipes and teaching routes

## Current Public Scope

The current public floor is grouped and broad:

- `client.local.*`
  - local operator, local jobs, local state, and CLI-shaped local composition
- `client.relay.*`
  - relay auth, query, exchange, replay, publish, response, workspace, and session composition
- `client.signer.*`
  - signer capability, thin browser signer, signer session, and signer job composition above the
    remote-signer workflow
- `client.dm.*`
  - DM capability, mailbox, and legacy-DM runtime, replay, subscription, and orchestration
    composition
- `client.identity.*`
  - `NIP-05` and `NIP-39` client-facing identity flows
- `client.social.*`
  - profile, note, thread, long-form, reaction, list, contact-graph, and starter-only WoT
    client-facing social/content composition
- `client.proof.*`
  - `NIP-03` proof verification and remembered-proof planning
- `client.groups.*`
  - multi-relay `NIP-29` group client composition
- `workflows.signer.*`
  - `NIP-46` remote signer workflow
- `workflows.dm.*`
  - `NIP-17` mailbox and legacy `NIP-04` private-message workflows
- `workflows.identity.*`
  - `NIP-05` and `NIP-39` identity workflows
- `workflows.proof.*`
  - `NIP-03` OpenTimestamps verification workflow
- `workflows.groups.*`
  - relay-local and multi-relay `NIP-29` group workflows
- `store`, `runtime`, and `transport`
  - shared bounded storage, relay runtime, and HTTP seam foundations

## Important Note On Internal Docs

This repo may also contain local-only maintainer docs under `.private-docs/`.

That material is not part of the public SDK documentation route.

In general:

- `docs/` is public-facing SDK documentation
- `examples/` is public-facing usage material
- `.private-docs/` is a local maintainer override when present

If you are not actively contributing to `noztr-sdk`, start with the public docs and examples
first.
