---
title: Getting Started
doc_type: guide
status: active
owner: noztr-sdk
read_when:
  - onboarding_public_consumers
  - installing_noztr_sdk
  - choosing_a_first_sdk_example
canonical: true
---

# Getting Started

This is the shortest public path from "I want to try `noztr-sdk`" to the right workflow and
example.

## What You Get

`noztr-sdk` is the higher-level Zig SDK built on top of `noztr`.

It gives you:

- app-facing Nostr workflow layers
- explicit transport seams
- caller-owned store and cache seams
- typed runtime/step helpers over bounded workflow state
- workflow recipes above the lower-level protocol kernel

It does not try to hide ownership, background runtime, or network side effects behind global magic.

## If You Are Building Another Zig SDK Layer

`noztr-sdk` is intended to be reusable from another Zig SDK layer, not only from end-user apps.

Use it as:
- a production-grade generic Nostr-facing foundation
- explicit transport/store/cache seams
- relay-centric runtime plans and typed next-step helpers
- reusable relay/auth/query/exchange/replay and checkpoint/resume heavy lifting when those shapes
  are generic across many Nostr apps

Do not assume:
- a hidden websocket/runtime framework
- hidden background threads
- product-specific connection policy

The goal is not the smallest possible relay floor. The goal is one obvious, caller-driven generic
Nostr foundation that downstream SDKs can build on without reimplementing the same workflow
substrate again.

Today, the downstream-targetable foundation is relay-centric:
- HTTP-backed work starts from `noztr_sdk.transport.HttpClient`
- shared relay runtime planning starts from `noztr_sdk.runtime.RelayPool`
- explicit relay-session composition starts from `noztr_sdk.client.RelaySessionClient`
- explicit relay-backed composition extends through the relay auth/query/exchange/replay/publish,
  local-state, workspace, and remote-signer client/workflow families
- inbound relay message ownership and transcript validation start from
  `noztr_sdk.client.RelayResponseClient`
- neutral local archive/checkpoint/remembered-relay/runtime composition starts from
  `noztr_sdk.client.LocalStateClient`
- narrower remembered relay workspace composition starts from `noztr_sdk.client.RelayWorkspaceClient`

If you are building another Zig SDK above `noztr-sdk`, start with the public contract map and the
relay/runtime examples rather than expecting a generic socket ownership layer.

## Build And Test

```bash
zig build test --summary all
zig build
```

## Add As A Local Dependency

`build.zig.zon`:

```zig
.{
    .dependencies = .{
        .noztr_sdk = .{
            .path = "../noztr-sdk",
        },
    },
}
```

`build.zig`:

```zig
const sdk_dependency = b.dependency("noztr_sdk", .{});
const sdk_module = sdk_dependency.module("noztr_sdk");
exe.root_module.addImport("noztr_sdk", sdk_module);
```

## Choose Your Starting Point

| If you want to... | Open first | Then open |
| --- | --- | --- |
| understand the public SDK workflow surface | [public contract map](./reference/contract-map.md) | [examples/README.md](../examples/README.md) |
| verify install/import works | [consumer_smoke.zig](../examples/consumer_smoke.zig) | one workflow recipe |
| build local bounded event/query/checkpoint storage first | [public contract map](./reference/contract-map.md) | [store_query_recipe.zig](../examples/store_query_recipe.zig) |
| build a first CLI-facing archive surface above shared storage | [public contract map](./reference/contract-map.md) | [store_archive_recipe.zig](../examples/store_archive_recipe.zig) |
| build a first CLI-facing client surface above shared store plus runtime | [public contract map](./reference/contract-map.md) | [cli_archive_client_recipe.zig](../examples/cli_archive_client_recipe.zig) |
| persist relay-local runtime cursors over shared storage | [public contract map](./reference/contract-map.md) | [relay_checkpoint_recipe.zig](../examples/relay_checkpoint_recipe.zig) |
| restore one relay-local group snapshot over shared storage | [public contract map](./reference/contract-map.md) | [relay_local_group_archive_recipe.zig](../examples/relay_local_group_archive_recipe.zig) |
| inspect a shared multi-relay runtime floor and derive bounded subscription targets | [public contract map](./reference/contract-map.md) | [relay_pool_recipe.zig](../examples/relay_pool_recipe.zig) |
| persist and restore a shared relay-pool checkpoint set, then derive bounded replay steps | [public contract map](./reference/contract-map.md) | [relay_pool_checkpoint_recipe.zig](../examples/relay_pool_checkpoint_recipe.zig) |
| build signer/session flows | [public contract map](./reference/contract-map.md) | [remote_signer_recipe.zig](../examples/remote_signer_recipe.zig) |
| build a first signer-tooling client surface above the remote-signer workflow | [public contract map](./reference/contract-map.md) | [signer_client_recipe.zig](../examples/signer_client_recipe.zig) |
| build mailbox/private-message flows | [public contract map](./reference/contract-map.md) | [mailbox_recipe.zig](../examples/mailbox_recipe.zig) |
| build identity/proof flows | [public contract map](./reference/contract-map.md) | [nip39_verification_recipe.zig](../examples/nip39_verification_recipe.zig), [nip03_verification_recipe.zig](../examples/nip03_verification_recipe.zig) |
| build group flows | [public contract map](./reference/contract-map.md) | [group_session_recipe.zig](../examples/group_session_recipe.zig), [group_fleet_recipe.zig](../examples/group_fleet_recipe.zig) |
| build another Zig SDK above a production-grade generic Nostr relay/workflow foundation | [public contract map](./reference/contract-map.md) | [relay_session_client_recipe.zig](../examples/relay_session_client_recipe.zig), [relay_pool_recipe.zig](../examples/relay_pool_recipe.zig), [local_state_client_recipe.zig](../examples/local_state_client_recipe.zig), [remote_signer_recipe.zig](../examples/remote_signer_recipe.zig) |

## Best First Examples

- [consumer_smoke.zig](../examples/consumer_smoke.zig)
  - minimal package/import check
- [remote_signer_recipe.zig](../examples/remote_signer_recipe.zig)
  - first signer/session route
- [signer_client_recipe.zig](../examples/signer_client_recipe.zig)
  - first signer-tooling client route over the remote-signer workflow
- [store_query_recipe.zig](../examples/store_query_recipe.zig)
  - first bounded store/query/checkpoint route
- [store_archive_recipe.zig](../examples/store_archive_recipe.zig)
  - first CLI-facing archive route over the shared store seam
- [cli_archive_client_recipe.zig](../examples/cli_archive_client_recipe.zig)
  - first CLI-facing client composition route over shared store plus runtime
- [relay_checkpoint_recipe.zig](../examples/relay_checkpoint_recipe.zig)
  - first relay-local checkpoint route over shared storage
- [relay_local_group_archive_recipe.zig](../examples/relay_local_group_archive_recipe.zig)
  - first relay-local workflow replay route over shared storage
- [relay_pool_recipe.zig](../examples/relay_pool_recipe.zig)
  - first shared relay-pool runtime plus subscription-spec route
- [relay_session_client_recipe.zig](../examples/relay_session_client_recipe.zig)
  - first generic relay-session composition route
- [relay_pool_checkpoint_recipe.zig](../examples/relay_pool_checkpoint_recipe.zig)
  - first shared relay-pool checkpoint plus replay-planning route
- [mailbox_recipe.zig](../examples/mailbox_recipe.zig)
  - first private-message workflow route
- [nip39_verification_recipe.zig](../examples/nip39_verification_recipe.zig)
  - first identity/discovery route
- [nip03_verification_recipe.zig](../examples/nip03_verification_recipe.zig)
  - first detached-proof workflow route
- [group_session_recipe.zig](../examples/group_session_recipe.zig)
  - first group workflow route

## Next Step

- for public task-to-symbol routing, go to [public contract map](./reference/contract-map.md)
- for workflow recipe routing, go to [examples/README.md](../examples/README.md)
- for the repo overview, go to [README.md](../README.md)
