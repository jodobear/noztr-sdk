---
title: Downstream SDK Boundary
doc_type: guide
status: active
owner: noztr-sdk
read_when:
  - building_another_zig_sdk_layer
  - deciding_between_noztr_and_noztr_sdk
  - evaluating_the_mixed_downstream_route
canonical: true
---

# Downstream SDK Boundary

Use this guide if you are building another Zig SDK on top of Nostr and need to know where the
`noztr` kernel stops and where `noztr-sdk` should begin.

## The Accepted Mixed Route

The stable downstream shape is mixed on purpose:

- `noztr` is the true protocol-kernel floor
- `noztr-sdk` is the production-ready non-kernel Nostr SDK layer above it

This is the intended long-term route for downstream Zig SDKs such as messaging, collaboration,
signer, or application-specific libraries.

## What Stays In `noztr`

Keep deterministic kernel work in `noztr`:

- protocol-level parsing and validation
- canonical event, tag, filter, and message primitives
- deterministic serialization and signing primitives
- relay URL validation and normalization
- other reusable protocol-kernel helpers that should stay app-agnostic and workflow-agnostic

If your work would still make sense in a lower-level Nostr kernel without any SDK workflow layer,
it likely belongs in `noztr`.

## What Starts In `noztr-sdk`

Start in `noztr-sdk` for reusable non-kernel Nostr heavy lifting:

- explicit relay/runtime planning
- publish, replay, subscription, auth, and response composition
- checkpoint, resume, remembered workspace, and local-state composition
- signer/session, DM, proof, identity, and group workflows
- caller-driven runtime and next-step helpers above the kernel floor

If many real apps or downstream SDKs would otherwise rebuild the same relay/runtime/workflow glue,
it likely belongs in `noztr-sdk`.

## Why The Split Exists

`noztr-sdk` is not trying to replace `noztr`.

The goal is:

- keep the protocol kernel deterministic and reusable on its own
- let `noztr-sdk` absorb the production-grade non-kernel Nostr substrate above it
- keep product-specific policy outside both layers

This avoids two bad outcomes:

- forcing downstream SDKs to rebuild a parallel generic Nostr relay/runtime layer locally
- collapsing `noztr` and `noztr-sdk` into one blurry library with weak boundaries

## Practical Starting Points

Use `noztr` first when you need:

- deterministic protocol fixtures
- event and tag shaping
- kernel-level relay URL work
- lower-level protocol parsing or validation

Use `noztr-sdk` first when you need:

- relay session composition
- generic publish composition for caller-authored events
- publish or replay planning
- bounded subscription or auth-aware relay turns
- remembered local state, checkpoints, or resume
- reusable higher-level Nostr workflows

For arbitrary downstream event kinds and tags, the intended route is:

1. keep the deterministic event and tag kernel floor in `noztr`
2. optionally use `noztr_sdk.client.local.operator.LocalOperatorClient` for local operator
   composition above that kernel floor
3. hand signed events into `noztr_sdk.client.relay.publish.PublishClient`,
   `noztr_sdk.client.relay.session.RelaySessionClient`, or the narrower relay replay/query/
   subscription clients as needed

The dedicated public proof of that mixed route is:
- [downstream_mixed_route.zig](../../examples/downstream_mixed_route.zig)

## Recommended Downstream Route

For another Zig SDK above Nostr:

1. Use `noztr` for the true kernel floor.
2. Use `noztr-sdk` for the reusable non-kernel relay/runtime/workflow layer.
3. Keep your own protocol-specific or product-specific semantics above both.

That means downstream SDKs should not build a third generic Nostr substrate locally unless they
find a real missing generic gap in `noztr-sdk`.

## Current Readiness

Another Zig SDK can resume on this published mixed boundary today:

- use `noztr` for the true kernel floor
- use `noztr-sdk` for the reusable non-kernel relay/runtime/workflow layer
- only drop below that route when you have found a real missing generic gap, not just because the
  boundary was unclear

## Public Entry Points

Start here when you are evaluating that mixed route:

- [getting-started.md](../getting-started.md)
- [contract-map.md](./contract-map.md)
- [local_operator_client.zig](../../examples/local_operator_client.zig)
- [downstream_mixed_route.zig](../../examples/downstream_mixed_route.zig)
- [publish_client.zig](../../examples/publish_client.zig)
- [relay_session_client.zig](../../examples/relay_session_client.zig)
- [local_state_client.zig](../../examples/local_state_client.zig)
- [remote_signer.zig](../../examples/remote_signer.zig)
