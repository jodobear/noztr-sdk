---
title: Getting Started
doc_type: release_guide
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
            .path = "../nzdk",
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
| understand the public SDK workflow surface | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [examples/README.md](/workspace/projects/nzdk/examples/README.md) |
| verify install/import works | [consumer_smoke.zig](/workspace/projects/nzdk/examples/consumer_smoke.zig) | one workflow recipe |
| build local bounded event/query/checkpoint storage first | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [store_query_recipe.zig](/workspace/projects/nzdk/examples/store_query_recipe.zig) |
| build a first CLI-facing archive surface above shared storage | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [store_archive_recipe.zig](/workspace/projects/nzdk/examples/store_archive_recipe.zig) |
| build signer/session flows | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [remote_signer_recipe.zig](/workspace/projects/nzdk/examples/remote_signer_recipe.zig) |
| build mailbox/private-message flows | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [mailbox_recipe.zig](/workspace/projects/nzdk/examples/mailbox_recipe.zig) |
| build identity/proof flows | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [nip39_verification_recipe.zig](/workspace/projects/nzdk/examples/nip39_verification_recipe.zig), [nip03_verification_recipe.zig](/workspace/projects/nzdk/examples/nip03_verification_recipe.zig) |
| build group flows | [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md) | [group_session_recipe.zig](/workspace/projects/nzdk/examples/group_session_recipe.zig), [group_fleet_recipe.zig](/workspace/projects/nzdk/examples/group_fleet_recipe.zig) |

## Best First Examples

- [consumer_smoke.zig](/workspace/projects/nzdk/examples/consumer_smoke.zig)
  - minimal package/import check
- [remote_signer_recipe.zig](/workspace/projects/nzdk/examples/remote_signer_recipe.zig)
  - first signer/session route
- [store_query_recipe.zig](/workspace/projects/nzdk/examples/store_query_recipe.zig)
  - first bounded store/query/checkpoint route
- [store_archive_recipe.zig](/workspace/projects/nzdk/examples/store_archive_recipe.zig)
  - first CLI-facing archive route over the shared store seam
- [mailbox_recipe.zig](/workspace/projects/nzdk/examples/mailbox_recipe.zig)
  - first private-message workflow route
- [nip39_verification_recipe.zig](/workspace/projects/nzdk/examples/nip39_verification_recipe.zig)
  - first identity/discovery route
- [nip03_verification_recipe.zig](/workspace/projects/nzdk/examples/nip03_verification_recipe.zig)
  - first detached-proof workflow route
- [group_session_recipe.zig](/workspace/projects/nzdk/examples/group_session_recipe.zig)
  - first group workflow route

## Next Step

- for public task-to-symbol routing, go to [contract-map.md](/workspace/projects/nzdk/docs/release/contract-map.md)
- for workflow recipe routing, go to [examples/README.md](/workspace/projects/nzdk/examples/README.md)
- for the repo overview, go to [README.md](/workspace/projects/nzdk/README.md)
