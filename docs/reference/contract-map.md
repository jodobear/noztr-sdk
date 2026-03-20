---
title: Public SDK Contract Map
doc_type: reference
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
| Local operator tooling for keys, `NIP-19` entities, local event signing/inspection, and local `NIP-44` crypto | `noztr_sdk.client`, `LocalOperatorClient`, `LocalKeypair`, `LocalEventDraft`, `LocalEventInspection` | `noztr_sdk.client.LocalOperatorClient` | [local_operator_client_recipe.zig](../../examples/local_operator_client_recipe.zig) |
| One-shot publish composition over local operator tooling plus shared relay runtime | `noztr_sdk.client`, `PublishClient`, `PublishClientStorage`, `PreparedPublishEvent`, `TargetedPublishEvent`, `noztr_sdk.runtime`, `RelayPoolPublishPlan`, `RelayPoolPublishStep` | `noztr_sdk.client.PublishClient` | [publish_client_recipe.zig](../../examples/publish_client_recipe.zig) |
| One-shot relay exchange composition for publish, count, and subscription jobs over the shared relay floor | `noztr_sdk.client`, `RelayExchangeClient`, `RelayExchangeClientStorage`, `PublishExchangeRequest`, `PublishExchangeOutcome`, `CountExchangeRequest`, `CountExchangeOutcome`, `SubscriptionExchangeRequest`, `SubscriptionExchangeOutcome`, `CloseExchangeRequest` | `noztr_sdk.client.RelayExchangeClient` | [relay_exchange_client_recipe.zig](../../examples/relay_exchange_client_recipe.zig) |
| One-shot relay query composition for `REQ`, `COUNT`, and `CLOSE` over shared relay readiness | `noztr_sdk.client`, `RelayQueryClient`, `RelayQueryClientStorage`, `RelayQueryTarget`, `TargetedSubscriptionRequest`, `TargetedCountRequest`, `TargetedCloseRequest`, `noztr_sdk.runtime`, `RelayPoolSubscriptionPlan`, `RelayPoolCountPlan` | `noztr_sdk.client.RelayQueryClient` | [relay_query_client_recipe.zig](../../examples/relay_query_client_recipe.zig) |
| Receive-side relay response intake for subscription transcripts, count replies, publish `OK`, `NOTICE`, and `AUTH` | `noztr_sdk.client`, `RelayResponseClient`, `RelaySubscriptionTranscriptStorage`, `RelaySubscriptionMessageOutcome`, `RelayCountMessage`, `RelayPublishOkMessage`, `RelayNoticeMessage`, `RelayAuthChallengeMessage` | `noztr_sdk.client.RelayResponseClient` | [relay_response_client_recipe.zig](../../examples/relay_response_client_recipe.zig) |
| Bounded event storage, backend-agnostic querying, and named checkpoint persistence | `noztr_sdk.store`, `MemoryClientStore`, `ClientQuery`, `EventQueryResultPage`, `EventCursor`, `IndexSelection` | `noztr_sdk.store` | [store_query_recipe.zig](../../examples/store_query_recipe.zig) |
| Minimal CLI-facing event archive over the shared store seam | `noztr_sdk.store`, `EventArchive`, `ClientStore`, `MemoryClientStore` | `noztr_sdk.store.EventArchive` | [store_archive_recipe.zig](../../examples/store_archive_recipe.zig) |
| Minimal CLI-facing client composition over shared store plus relay runtime | `noztr_sdk.client`, `CliArchiveClient`, `CliArchiveClientStorage`, `noztr_sdk.store`, `noztr_sdk.runtime` | `noztr_sdk.client.CliArchiveClient` | [cli_archive_client_recipe.zig](../../examples/cli_archive_client_recipe.zig) |
| Persist relay-local runtime cursors over the shared checkpoint seam | `noztr_sdk.store`, `RelayCheckpointArchive`, `MemoryClientStore` | `noztr_sdk.store.RelayCheckpointArchive` | [relay_checkpoint_recipe.zig](../../examples/relay_checkpoint_recipe.zig) |
| Restore one relay-local `NIP-29` group snapshot over the shared event seam | `noztr_sdk.store`, `RelayLocalGroupArchive`, `MemoryClientStore`, `GroupClient` | `noztr_sdk.store.RelayLocalGroupArchive` | [relay_local_group_archive_recipe.zig](../../examples/relay_local_group_archive_recipe.zig) |
| Inspect shared multi-relay readiness, derive bounded subscription targets, and select typed next runtime or subscription steps | `noztr_sdk.runtime`, `RelayPool`, `RelayPoolStorage`, `RelayPoolPlanStorage`, `RelayPoolPlan`, `RelayPoolStep`, `RelaySubscriptionSpec`, `RelayPoolSubscriptionStorage`, `RelayPoolSubscriptionPlan`, `RelayPoolSubscriptionStep` | `noztr_sdk.runtime.RelayPool` | [relay_pool_recipe.zig](../../examples/relay_pool_recipe.zig) |
| Export and restore shared relay-pool membership plus per-relay cursors over the shared checkpoint seam, then derive bounded replay steps | `noztr_sdk.runtime`, `RelayPool`, `RelayPoolCheckpointStorage`, `RelayPoolCheckpointSet`, `RelayPoolCheckpointStep`, `RelayReplaySpec`, `RelayPoolReplayStorage`, `RelayPoolReplayPlan`, `RelayPoolReplayStep`, `noztr_sdk.store.RelayCheckpointArchive` | `noztr_sdk.runtime.RelayPool` | [relay_pool_checkpoint_recipe.zig](../../examples/relay_pool_checkpoint_recipe.zig) |
| Remote signing, request/response orchestration, relay switching, and shared relay-pool inspection | `RemoteSignerSession`, `RemoteSignerRequestContext`, `RemoteSignerPubkeyTextRequest`, `RemoteSignerTextResponse`, `RemoteSignerRelayPoolRuntimeStorage`, `noztr_sdk.runtime.RelayPoolStep` | `noztr_sdk.workflows.RemoteSignerSession` | [remote_signer_recipe.zig](../../examples/remote_signer_recipe.zig) |
| First signer-tooling client composition above the remote-signer workflow plus shared relay runtime | `noztr_sdk.client`, `SignerClient`, `SignerClientStorage`, `SignerClientRequestStorage`, `noztr_sdk.runtime.RelayPoolStep` | `noztr_sdk.client.SignerClient` | [signer_client_recipe.zig](../../examples/signer_client_recipe.zig) |
| Private-message send, receive, delivery planning, mailbox workflow stepping, and shared relay-pool inspection | `MailboxSession`, `MailboxDeliveryPlan`, `MailboxRuntimePlan`, `MailboxWorkflowPlan`, `MailboxRelayPoolRuntimeStorage`, `MailboxFileMessageRequest`, `noztr_sdk.runtime.RelayPoolStep` | `noztr_sdk.workflows.MailboxSession` | [mailbox_recipe.zig](../../examples/mailbox_recipe.zig) |
| Detached OpenTimestamps proof verification, remembered proof reuse, and grouped remembered-proof policy | `OpenTimestampsVerifier`, `OpenTimestampsProofStore`, `OpenTimestampsVerificationStore`, `OpenTimestampsStoredVerificationRuntimePlan`, `OpenTimestampsStoredVerificationTargetRefreshPlan` | `noztr_sdk.workflows.OpenTimestampsVerifier` | [nip03_verification_recipe.zig](../../examples/nip03_verification_recipe.zig) |
| Identity verification, remembered profile discovery, watched-target policy, and remembered runtime stepping | `IdentityVerifier`, `MemoryIdentityVerificationCache`, `MemoryIdentityProfileStore`, `IdentityStoredProfileTargetRuntimePlan`, `IdentityStoredProfileTargetPolicyPlan` | `noztr_sdk.workflows.IdentityVerifier` | [nip39_verification_recipe.zig](../../examples/nip39_verification_recipe.zig) |
| `NIP-05` address resolution and verification over the public HTTP seam | `Nip05Resolver`, `Nip05LookupRequest`, `Nip05LookupStorage` | `noztr_sdk.workflows.Nip05Resolver` | [nip05_resolution_recipe.zig](../../examples/nip05_resolution_recipe.zig) |
| Relay-local group replay, checkpointing, and moderation publish | `GroupClient`, `GroupSession`, `GroupCheckpointContext`, `GroupPublishContext` | `noztr_sdk.workflows.GroupClient` | [group_session_recipe.zig](../../examples/group_session_recipe.zig) |
| Multi-relay groups routing, reconciliation, merge policy, checkpoints, and background runtime inspection | `GroupFleet`, `GroupFleetRuntimePlan`, `GroupFleetBackgroundRuntimePlan`, `MemoryGroupFleetCheckpointStore`, `GroupFleetPublishStep` | `noztr_sdk.workflows.GroupFleet` | [group_fleet_recipe.zig](../../examples/group_fleet_recipe.zig) |

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
