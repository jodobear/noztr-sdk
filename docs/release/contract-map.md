---
title: Public SDK Contract Map
doc_type: release_reference
status: active
owner: noztr-sdk
read_when:
  - routing_public_sdk_jobs
  - finding_workflow_symbols
  - onboarding_public_consumers
canonical: true
---

# Public SDK Contract Map

This is the public task-to-symbol map for the main `noztr-sdk` workflow surfaces.

Use it when you know the job you want to do, but do not yet know which workflow type or example to
open.

## Routing Table

| Job | Primary public symbols | Start here | Example |
| --- | --- | --- | --- |
| Bounded event storage, backend-agnostic querying, and named checkpoint persistence | `noztr_sdk.store`, `MemoryClientStore`, `ClientQuery`, `EventQueryResultPage`, `EventCursor`, `IndexSelection` | `noztr_sdk.store` | [store_query_recipe.zig](/workspace/projects/nzdk/examples/store_query_recipe.zig) |
| Minimal CLI-facing event archive over the shared store seam | `noztr_sdk.store`, `EventArchive`, `ClientStore`, `MemoryClientStore` | `noztr_sdk.store.EventArchive` | [store_archive_recipe.zig](/workspace/projects/nzdk/examples/store_archive_recipe.zig) |
| Persist relay-local runtime cursors over the shared checkpoint seam | `noztr_sdk.store`, `RelayCheckpointArchive`, `MemoryClientStore` | `noztr_sdk.store.RelayCheckpointArchive` | [relay_checkpoint_recipe.zig](/workspace/projects/nzdk/examples/relay_checkpoint_recipe.zig) |
| Remote signing, request/response orchestration, and relay switching | `RemoteSignerSession`, `RemoteSignerRequestContext`, `RemoteSignerPubkeyTextRequest`, `RemoteSignerTextResponse` | `noztr_sdk.workflows.RemoteSignerSession` | [remote_signer_recipe.zig](/workspace/projects/nzdk/examples/remote_signer_recipe.zig) |
| Private-message send, receive, delivery planning, and mailbox workflow stepping | `MailboxSession`, `MailboxDeliveryPlan`, `MailboxRuntimePlan`, `MailboxWorkflowPlan`, `MailboxFileMessageRequest` | `noztr_sdk.workflows.MailboxSession` | [mailbox_recipe.zig](/workspace/projects/nzdk/examples/mailbox_recipe.zig) |
| Detached OpenTimestamps proof verification, remembered proof reuse, and grouped remembered-proof policy | `OpenTimestampsVerifier`, `OpenTimestampsProofStore`, `OpenTimestampsVerificationStore`, `OpenTimestampsStoredVerificationRuntimePlan`, `OpenTimestampsStoredVerificationTargetRefreshPlan` | `noztr_sdk.workflows.OpenTimestampsVerifier` | [nip03_verification_recipe.zig](/workspace/projects/nzdk/examples/nip03_verification_recipe.zig) |
| Identity verification, remembered profile discovery, watched-target policy, and remembered runtime stepping | `IdentityVerifier`, `MemoryIdentityVerificationCache`, `MemoryIdentityProfileStore`, `IdentityStoredProfileTargetRuntimePlan`, `IdentityStoredProfileTargetPolicyPlan` | `noztr_sdk.workflows.IdentityVerifier` | [nip39_verification_recipe.zig](/workspace/projects/nzdk/examples/nip39_verification_recipe.zig) |
| `NIP-05` address resolution and verification over the public HTTP seam | `Nip05Resolver`, `Nip05LookupRequest`, `Nip05LookupStorage` | `noztr_sdk.workflows.Nip05Resolver` | [nip05_resolution_recipe.zig](/workspace/projects/nzdk/examples/nip05_resolution_recipe.zig) |
| Relay-local group replay, checkpointing, and moderation publish | `GroupClient`, `GroupSession`, `GroupCheckpointContext`, `GroupPublishContext` | `noztr_sdk.workflows.GroupClient` | [group_session_recipe.zig](/workspace/projects/nzdk/examples/group_session_recipe.zig) |
| Multi-relay groups routing, reconciliation, merge policy, checkpoints, and background runtime inspection | `GroupFleet`, `GroupFleetRuntimePlan`, `GroupFleetBackgroundRuntimePlan`, `MemoryGroupFleetCheckpointStore`, `GroupFleetPublishStep` | `noztr_sdk.workflows.GroupFleet` | [group_fleet_recipe.zig](/workspace/projects/nzdk/examples/group_fleet_recipe.zig) |

## Scope Note

These surfaces are SDK workflows.

They do not own:

- hidden global runtime
- hidden threads
- hidden network side effects
- product-specific UI or application policy

They do own:

- bounded runtime plans
- typed next-step helpers
- explicit transport/store/cache seams
- app-facing workflow composition above `noztr`
