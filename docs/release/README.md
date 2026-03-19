---
title: noztr-sdk Release Docs Index
doc_type: release_index
status: active
owner: noztr-sdk
read_when:
  - onboarding_public_consumers
  - routing_public_sdk_docs
  - evaluating_noztr_sdk_publicly
canonical: true
---

# noztr-sdk Release Docs Index

This is the public-facing documentation route for `noztr-sdk`.

Use these docs if you are evaluating the SDK, trying to build on top of it, or looking for the
current public workflow contract.

`noztr` and `noztr-sdk` are complementary layers:

- `noztr` owns deterministic protocol-kernel behavior
- `noztr-sdk` owns higher-level workflow, transport, store, and application-facing composition

## Start Here

- [README.md](/workspace/projects/nzdk/README.md)
  - short overview, posture, and build/test commands
- [getting-started.md](/workspace/projects/nzdk/docs/release/getting-started.md)
  - shortest public route from install/import to first workflow examples
- [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md)
  - task-to-symbol route for the current public workflow surface
- [examples/README.md](/workspace/projects/nzdk/examples/README.md)
  - workflow recipes and teaching routes

## Current Public Scope

The current public workflow floor includes:

- shared bounded store/query/checkpoint reference surfaces
- one minimal CLI-facing archive helper over that shared store seam
- `NIP-46` remote signer workflow
- `NIP-17` mailbox workflow
- `NIP-39` identity verification workflow
- `NIP-03` OpenTimestamps verification workflow
- `NIP-05` identity resolution workflow
- `NIP-29` group workflow

## Important Note On Internal Docs

This repo also contains extensive internal engineering docs under:

- `docs/plans/`
- `docs/guides/`
- `docs/research/`
- `docs/index.md`

Those docs are valuable for planning, audits, process control, and execution history, but they are
not the primary public documentation surface.

In general:

- `docs/release/` is public-facing SDK documentation
- `examples/` is public-facing usage material
- `docs/plans/`, `docs/guides/`, and `docs/research/` are mostly internal engineering material

If you are not actively contributing to `noztr-sdk`, start with the release docs and examples
first.
