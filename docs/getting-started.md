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

## Public Namespace Shape

Use these as the stable top-level public namespaces:
- `noztr_sdk.workflows`
- `noztr_sdk.client`
- `noztr_sdk.store`
- `noztr_sdk.runtime`
- `noztr_sdk.transport`

Inside `workflows` and `client`, prefer the grouped routes when choosing a public symbol:
- `workflows.groups.*`
- `workflows.identity.*`
- `workflows.dm.*`
- `workflows.proof.*`
- `workflows.signer.*`
- `workflows.zaps.*`
- `client.local.*`
- `client.relay.*`
- `client.signer.*`
- `client.dm.*`
- `client.identity.*`
- `client.social.*`
- `client.proof.*`
- `client.groups.*`

The older flat `client.*Type` and `workflows.*Type` routes were removed in the current pre-`1.0`
namespace cleanup. Use the grouped routes as the canonical public discovery shape.

## If You Are Building Another Zig SDK Layer

`noztr-sdk` is intended to be reusable from another Zig SDK layer, not only from end-user apps.

The accepted route is mixed:
- use `noztr` for the true protocol-kernel floor
- use `noztr-sdk` for the production-ready non-kernel layer above it

Use [downstream-sdk-boundary.md](./reference/downstream-sdk-boundary.md) if you need the explicit
line between those two layers before choosing symbols.

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
- explicit relay-session composition starts from `noztr_sdk.client.relay.session.RelaySessionClient`
- explicit relay-backed composition extends through the relay auth/query/exchange/replay/publish,
  local-state, workspace, and remote-signer client/workflow families
- inbound relay message ownership and transcript validation start from
  `noztr_sdk.client.relay.response.RelayResponseClient`
- neutral local archive/checkpoint/remembered-relay/runtime composition starts from
  `noztr_sdk.client.local.state.LocalStateClient`
- narrower remembered relay workspace composition starts from `noztr_sdk.client.relay.workspace.RelayWorkspaceClient`

For arbitrary downstream event kinds and tags:
- keep deterministic event and tag shaping in `noztr`
- use `noztr_sdk.client.local.operator.LocalOperatorClient` when you want SDK-owned local
  operator composition above that kernel floor
- hand signed events into `noztr_sdk.client.relay.publish.PublishClient` or the broader
  relay-session/relay-query/relay-replay family as needed
- use [downstream_mixed_route.zig](../examples/downstream_mixed_route.zig) when you
  want one explicit proof of that kernel-to-SDK handoff

If you are building another Zig SDK above Nostr:
- keep deterministic kernel primitives in `noztr`
- start generic relay/runtime/workflow composition in `noztr-sdk`
- do not build a third local generic Nostr relay/runtime layer unless a real generic gap remains

Start with the public contract map, the downstream boundary guide, and the relay/runtime examples
rather than expecting a generic socket ownership layer.

## Build And Test

```bash
zig build test --summary all
zig build
```

## Version Line And Toolchain

- project line: `0.1.0-dev.0`
- first intended public release candidate: `0.1.0-rc.1`
- current toolchain baseline: Zig `0.15.2`

These are separate on purpose: the Zig version is compatibility information, not the SDK version.

## Pre-1.0 Migration Notes

If you are updating an older downstream, check these before assuming a route still uses the older
longer names:

- [DM sync runtime naming migration](./reference/dm-sync-runtime-naming-migration.md)
- [DM orchestration naming migration](./reference/dm-orchestration-naming-migration.md)
- [social and DM stored-read migration](./reference/social-dm-stored-read-migration.md)
- [remote signer naming migration](./reference/remote-signer-naming-migration.md)
- [proof, identity, and NIP-05 planning migration](./reference/proof-identity-planning-migration.md)
- [examples filename migration](./reference/examples-filename-migration.md)
- [noztr-core rc4 migration](./reference/noztr-core-rc4-migration.md)

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
| build local bounded event/query/checkpoint storage first | [public contract map](./reference/contract-map.md) | [store_query.zig](../examples/store_query.zig) |
| build one first embedded durable local-storage baseline | [public contract map](./reference/contract-map.md) | [sqlite_client_store.zig](../examples/sqlite_client_store.zig) |
| build a first CLI-facing archive surface above shared storage | [public contract map](./reference/contract-map.md) | [store_archive.zig](../examples/store_archive.zig) |
| build a first CLI-facing client surface above shared store plus runtime | [public contract map](./reference/contract-map.md) | [cli_archive_client.zig](../examples/cli_archive_client.zig) |
| persist relay-local runtime cursors over shared storage | [public contract map](./reference/contract-map.md) | [relay_checkpoint.zig](../examples/relay_checkpoint.zig) |
| build one relay-local archive plus checkpoint-backed replay route over shared storage | [public contract map](./reference/contract-map.md) | [relay_local_archive.zig](../examples/relay_local_archive.zig) |
| restore one relay-local group snapshot over shared storage | [public contract map](./reference/contract-map.md) | [relay_local_group_archive.zig](../examples/relay_local_group_archive.zig) |
| inspect a shared multi-relay runtime floor and derive bounded subscription targets | [public contract map](./reference/contract-map.md) | [relay_pool.zig](../examples/relay_pool.zig) |
| persist and restore a shared relay-pool checkpoint set, then derive bounded replay steps | [public contract map](./reference/contract-map.md) | [relay_pool_checkpoint.zig](../examples/relay_pool_checkpoint.zig) |
| build signer/session flows | [public contract map](./reference/contract-map.md) | [remote_signer.zig](../examples/remote_signer.zig) |
| build a first signer-tooling client surface above the remote-signer workflow | [public contract map](./reference/contract-map.md) | [signer_client.zig](../examples/signer_client.zig) |
| build a shared signer route across local remote and browser adapters | [public contract map](./reference/contract-map.md) | [signer_capability.zig](../examples/signer_capability.zig), [nip07_browser_signer.zig](../examples/nip07_browser_signer.zig) |
| build social profile, note, thread, and long-form flows with explicit archive-backed reads | [public contract map](./reference/contract-map.md) | [social_profile_content_client.zig](../examples/social_profile_content_client.zig) |
| build social reply and `NIP-22` comment flows | [public contract map](./reference/contract-map.md) | [social_comment_reply_client.zig](../examples/social_comment_reply_client.zig) |
| build social highlight flows | [public contract map](./reference/contract-map.md) | [social_highlight_client.zig](../examples/social_highlight_client.zig) |
| build social reaction and list flows | [public contract map](./reference/contract-map.md) | [social_reaction_list_client.zig](../examples/social_reaction_list_client.zig) |
| build social contact-graph and starter-only WoT flows | [public contract map](./reference/contract-map.md) | [social_graph_wot_client.zig](../examples/social_graph_wot_client.zig) |
| build explicit zap request and callback flows | [public contract map](./reference/contract-map.md) | [zap_flow.zig](../examples/zap_flow.zig) |
| build explicit relay-management admin calls | [public contract map](./reference/contract-map.md) | [relay_management_client.zig](../examples/relay_management_client.zig) |
| build app-facing DM capability flows above mailbox and legacy DM | [public contract map](./reference/contract-map.md) | [dm_capability_client.zig](../examples/dm_capability_client.zig) |
| build one simple mixed mailbox-plus-legacy DM facade for apps with bounded outbound preparation | [public contract map](./reference/contract-map.md) | [mixed_dm_client.zig](../examples/mixed_dm_client.zig) |
| build signer-backed mailbox DM authoring above the remote-signer floor | [public contract map](./reference/contract-map.md) | [mailbox_signer_job_client.zig](../examples/mailbox_signer_job_client.zig) |
| build mailbox/private-message flows | [public contract map](./reference/contract-map.md) | [mailbox.zig](../examples/mailbox.zig) |
| build identity/proof flows | [public contract map](./reference/contract-map.md) | [nip39_verification.zig](../examples/nip39_verification.zig), [nip03_verification.zig](../examples/nip03_verification.zig) |
| build group flows | [public contract map](./reference/contract-map.md) | [group_session.zig](../examples/group_session.zig), [group_fleet.zig](../examples/group_fleet.zig) |
| build another Zig SDK above a production-grade generic Nostr relay/workflow foundation | [public contract map](./reference/contract-map.md) | [downstream_mixed_route.zig](../examples/downstream_mixed_route.zig), [local_operator_client.zig](../examples/local_operator_client.zig), [publish_client.zig](../examples/publish_client.zig), [relay_session_client.zig](../examples/relay_session_client.zig), [relay_pool.zig](../examples/relay_pool.zig), [local_state_client.zig](../examples/local_state_client.zig), [remote_signer.zig](../examples/remote_signer.zig) |

## Best First Examples

- [consumer_smoke.zig](../examples/consumer_smoke.zig)
  - minimal package/import check
- [remote_signer.zig](../examples/remote_signer.zig)
  - first signer/session route
- [signer_client.zig](../examples/signer_client.zig)
  - first signer-tooling client route over the remote-signer workflow
- [signer_capability.zig](../examples/signer_capability.zig)
  - first shared signer route across local, remote, and browser adapters
- [nip07_browser_signer.zig](../examples/nip07_browser_signer.zig)
  - first thin browser signer route over the shared signer-capability seam
- [dm_capability_client.zig](../examples/dm_capability_client.zig)
  - first app-facing DM capability route above mailbox and legacy DM
- [mixed_dm_client.zig](../examples/mixed_dm_client.zig)
  - first simple DM-app route for mixed inbound normalization plus bounded outbound preparation
- [mailbox_signer_job_client.zig](../examples/mailbox_signer_job_client.zig)
  - first signer-backed mailbox DM authoring route above the bounded signer client
- [social_profile_content_client.zig](../examples/social_profile_content_client.zig)
  - first social profile, note, thread, and long-form route with explicit archive-backed read selection
- [social_comment_reply_client.zig](../examples/social_comment_reply_client.zig)
  - first social reply and `NIP-22` comment route
- [social_highlight_client.zig](../examples/social_highlight_client.zig)
  - first social highlight route
- [social_reaction_list_client.zig](../examples/social_reaction_list_client.zig)
  - first social reaction and list route
- [social_graph_wot_client.zig](../examples/social_graph_wot_client.zig)
  - first social contact-graph and starter-only WoT route over verified latest contact lists
- [zap_flow.zig](../examples/zap_flow.zig)
  - first explicit `NIP-57` publish plus callback route over the shared publish and HTTP seams
- [relay_management_client.zig](../examples/relay_management_client.zig)
  - first explicit `NIP-86` admin request/result route over the shared HTTP seam, including typed
    allowed-pubkey and blocked-IP inspection plus explicit pubkey allow-list and IP block-list mutation
- [store_query.zig](../examples/store_query.zig)
  - first bounded store/query/checkpoint route
- [sqlite_client_store.zig](../examples/sqlite_client_store.zig)
  - first embedded durable store baseline over the shared store seam
- [store_archive.zig](../examples/store_archive.zig)
  - first CLI-facing archive route over the shared store seam
- [cli_archive_client.zig](../examples/cli_archive_client.zig)
  - first CLI-facing client composition route over shared store plus runtime
- [relay_checkpoint.zig](../examples/relay_checkpoint.zig)
  - first relay-local checkpoint route over shared storage
- [relay_local_archive.zig](../examples/relay_local_archive.zig)
  - first relay-local archive plus replay-planning route over shared storage
- [relay_local_group_archive.zig](../examples/relay_local_group_archive.zig)
  - first relay-local workflow replay route over shared storage
- [relay_pool.zig](../examples/relay_pool.zig)
  - first shared relay-pool runtime plus subscription-spec route
- [relay_session_client.zig](../examples/relay_session_client.zig)
  - first generic relay-session composition route
- [downstream_mixed_route.zig](../examples/downstream_mixed_route.zig)
  - first explicit kernel-event-to-SDK mixed downstream route
- [relay_pool_checkpoint.zig](../examples/relay_pool_checkpoint.zig)
  - first shared relay-pool checkpoint plus replay-planning route
- [mailbox.zig](../examples/mailbox.zig)
  - first private-message workflow route
- [nip39_verification.zig](../examples/nip39_verification.zig)
  - first identity/discovery route
- [nip03_verification.zig](../examples/nip03_verification.zig)
  - first detached-proof workflow route
- [group_session.zig](../examples/group_session.zig)
  - first group workflow route

## Next Step

- for public task-to-symbol routing, go to [public contract map](./reference/contract-map.md)
- for workflow recipe routing, go to [examples/README.md](../examples/README.md)
- for the repo overview, go to [README.md](../README.md)
