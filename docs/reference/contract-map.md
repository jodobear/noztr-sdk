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

## Namespace Note

The stable top-level public namespaces remain `noztr_sdk.workflows`, `noztr_sdk.client`,
`noztr_sdk.store`, `noztr_sdk.runtime`, and `noztr_sdk.transport`.

Within `workflows` and `client`, the canonical grouped discovery route is now:
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
namespace cleanup. This map uses only the grouped public discovery shape.

## Downstream SDK Foundation

If you are building another Zig SDK layer above Nostr, the accepted route is mixed:

- keep the true protocol-kernel floor in `noztr`
- use `noztr-sdk` for the production-ready non-kernel relay/runtime/workflow layer above it

Use [downstream-sdk-boundary.md](./downstream-sdk-boundary.md) when you need the explicit line
between those two layers.

The public `noztr-sdk` foundation to target today is:

- `noztr_sdk.client.local.operator.LocalOperatorClient` for SDK-owned local operator composition
  above kernel event, entity, key, and local crypto helpers
- `noztr_sdk.transport.HttpClient` for explicit HTTP-backed jobs
- `noztr_sdk.runtime.RelayPool` plus relay specs/plans for shared relay-state inspection and
  next-step selection
- `noztr_sdk.client.relay.session.RelaySessionClient` for explicit relay-session composition above shared relay
  runtime, auth, outbound request shaping, receive-side intake, and bounded member/checkpoint
  export-restore
- `noztr_sdk.client.local.state.LocalStateClient` for neutral local archive, remembered-relay, checkpoint, and
  replay composition above the shared store and relay-runtime seams
- the relay auth/query/exchange/replay/publish and response client family for narrower explicit
  relay-backed composition
- `noztr_sdk.client.relay.workspace.RelayWorkspaceClient` for remembered relay/workspace state plus checkpoint and
  replay planning
- the remote-signer workflow/client family for reusable relay-session/auth/session-state
  composition
- caller-owned stores and checkpoints for durable state

This foundation is relay-centric, explicit, and caller-driven.

For arbitrary downstream event kinds and tags, the intended route is:
- keep deterministic kernel event and tag shaping in `noztr`
- use the local-operator floor when you want SDK-owned local composition above that kernel floor
- hand signed events into the publish, relay-session, replay, or subscription surfaces here

It should absorb broadly reusable Nostr-facing heavy lifting so downstream apps and SDKs do not
have to restitch the same relay/runtime substrate above `noztr-sdk`.

It does not currently include:
- a generic public websocket transport API
- hidden connection ownership
- hidden background runtime or product policy

Downstream SDKs should build their own higher-level contracts above this surface instead of
depending on `noztr-sdk` to act like a generic socket framework.

They also should not build a third parallel generic Nostr relay/runtime layer locally unless they
find a real missing generic gap in `noztr-sdk`.

## Routing Table

Use the `Start here` column as the canonical grouped public route.

This table is intentionally route-first.
Supporting symbol inventories were removed here because they were overcompeting with the grouped
route instead of helping discovery.

| Job | Start here | Example |
| --- | --- | --- |
| Build another Zig SDK above a production-grade generic Nostr relay/workflow foundation | `noztr_sdk.client.relay.session.RelaySessionClient` | [downstream_mixed_route.zig](../../examples/downstream_mixed_route.zig) |
| Command-ready local `NIP-19` entity encode-decode over the local operator floor | `noztr_sdk.client.local.entities.LocalEntityJobClient` | [local_entity_job_client.zig](../../examples/local_entity_job_client.zig) |
| Command-ready local event inspect plus draft-sign-verify over the local operator floor | `noztr_sdk.client.local.events.LocalEventJobClient` | [local_event_job_client.zig](../../examples/local_event_job_client.zig) |
| Command-ready local key generation and public-key derivation over the local operator floor | `noztr_sdk.client.local.keys.LocalKeyJobClient` | [local_key_job_client.zig](../../examples/local_key_job_client.zig) |
| Command-ready local `nip44` encrypt-decrypt over the local operator floor | `noztr_sdk.client.local.nip44.LocalNip44JobClient` | [local_nip44_job_client.zig](../../examples/local_nip44_job_client.zig) |
| Local operator tooling for keys, `NIP-19` entities, local event signing/inspection, and local `NIP-44` crypto | `noztr_sdk.client.local.operator.LocalOperatorClient` | [local_operator_client.zig](../../examples/local_operator_client.zig) |
| Social profile, note, thread, and long-form composition plus explicit archive-backed latest-profile, note-page, and long-form selection above the local operator, publish, relay-query, and event-archive floors | `noztr_sdk.client.social.profile_content.SocialProfileContentClient` | [social_profile_content_client.zig](../../examples/social_profile_content_client.zig) |
| Social reply composition for kind-`1` notes plus `NIP-22` comment publish and explicit stored comment-page inspection above the local operator, publish, relay-query, and event-archive floors | `noztr_sdk.client.social.comment_reply.SocialCommentReplyClient` | [social_comment_reply_client.zig](../../examples/social_comment_reply_client.zig) |
| Social highlight composition plus explicit stored highlight-page inspection above the local operator, publish, relay-query, and event-archive floors | `noztr_sdk.client.social.highlight.SocialHighlightClient` | [social_highlight_client.zig](../../examples/social_highlight_client.zig) |
| Social reaction composition plus public-list publish, query, inspection, and explicit stored latest-list selection above the local operator, publish, relay-query, and event-archive floors | `noztr_sdk.client.social.reaction_list.SocialReactionListClient` | [social_reaction_list_client.zig](../../examples/social_reaction_list_client.zig) |
| Social contact-list publish/query/storage plus verified latest-contact inspection and a starter-only WoT heuristic above the local operator, publish, relay-query, and event-archive floors | `noztr_sdk.client.social.graph_wot.SocialGraphWotClient` | [social_graph_wot_client.zig](../../examples/social_graph_wot_client.zig) |
| One-shot publish composition over local operator tooling plus shared relay runtime | `noztr_sdk.client.relay.publish.PublishClient` | [publish_client.zig](../../examples/publish_client.zig) |
| Command-ready publish job composition over auth-aware publish turns | `noztr_sdk.client.relay.publish_job.PublishJobClient` | [publish_job_client.zig](../../examples/publish_job_client.zig) |
| Bounded publish turn composition over local drafts, relay-targeted `EVENT`, and validated publish `OK` replies | `noztr_sdk.client.relay.publish_turn.PublishTurnClient` | [publish_turn_client.zig](../../examples/publish_turn_client.zig) |
| Auth-gated publish turn recovery over shared relay auth state plus bounded publish turns | `noztr_sdk.client.relay.auth_publish_turn.AuthPublishTurnClient` | [auth_publish_turn_client.zig](../../examples/auth_publish_turn_client.zig) |
| Auth-gated count turn recovery over shared relay auth state plus bounded count turns | `noztr_sdk.client.relay.auth_count_turn.AuthCountTurnClient` | [auth_count_turn_client.zig](../../examples/auth_count_turn_client.zig) |
| Command-ready count job composition over auth-aware count turns | `noztr_sdk.client.relay.count_job.CountJobClient` | [count_job_client.zig](../../examples/count_job_client.zig) |
| Auth-gated replay turn recovery over shared relay auth state plus bounded replay turns | `noztr_sdk.client.relay.auth_replay_turn.AuthReplayTurnClient` | [auth_replay_turn_client.zig](../../examples/auth_replay_turn_client.zig) |
| Command-ready replay job composition over auth-aware replay turns plus checkpoint saves | `noztr_sdk.client.relay.replay_job.ReplayJobClient` | [replay_job_client.zig](../../examples/replay_job_client.zig) |
| Auth-gated subscription turn recovery over shared relay auth state plus bounded subscription turns | `noztr_sdk.client.relay.auth_subscription_turn.AuthSubscriptionTurnClient` | [auth_subscription_turn_client.zig](../../examples/auth_subscription_turn_client.zig) |
| Command-ready bounded subscription job composition over auth-aware subscription turns | `noztr_sdk.client.relay.subscription_job.SubscriptionJobClient` | [subscription_job_client.zig](../../examples/subscription_job_client.zig) |
| Bounded count turn composition over explicit `COUNT` requests and validated `COUNT` replies | `noztr_sdk.client.relay.count_turn.CountTurnClient` | [count_turn_client.zig](../../examples/count_turn_client.zig) |
| Bounded subscription turn composition over explicit `REQ`, validated transcript intake, and explicit `CLOSE` | `noztr_sdk.client.relay.subscription_turn.SubscriptionTurnClient` | [subscription_turn_client.zig](../../examples/subscription_turn_client.zig) |
| One-shot relay auth composition for `NIP-42` challenge handling over shared relay runtime | `noztr_sdk.client.relay.auth.RelayAuthClient` | [relay_auth_client.zig](../../examples/relay_auth_client.zig) |
| One-shot relay exchange composition for publish, count, and subscription jobs over the shared relay floor | `noztr_sdk.client.relay.exchange.RelayExchangeClient` | [relay_exchange_client.zig](../../examples/relay_exchange_client.zig) |
| One-shot relay query composition for `REQ`, `COUNT`, and `CLOSE` over shared relay readiness | `noztr_sdk.client.relay.query.RelayQueryClient` | [relay_query_client.zig](../../examples/relay_query_client.zig) |
| One-shot relay replay composition over shared relay runtime plus checkpoint-backed query state | `noztr_sdk.client.relay.replay.RelayReplayClient` | [relay_replay_client.zig](../../examples/relay_replay_client.zig) |
| One-shot replay exchange composition over checkpoint-backed replay plus receive-side transcript intake | `noztr_sdk.client.relay.replay_exchange.RelayReplayExchangeClient` | [relay_replay_exchange_client.zig](../../examples/relay_replay_exchange_client.zig) |
| Explicit replay checkpoint advancement over replay transcript outcomes plus the shared relay-checkpoint seam | `noztr_sdk.client.relay.replay_checkpoint_advance.ReplayCheckpointAdvanceClient` | [replay_checkpoint_advance_client.zig](../../examples/replay_checkpoint_advance_client.zig) |
| Bounded replay turn composition over replay exchange plus explicit checkpoint advancement | `noztr_sdk.client.relay.replay_turn.RelayReplayTurnClient` | [relay_replay_turn_client.zig](../../examples/relay_replay_turn_client.zig) |
| Receive-side relay response intake for subscription transcripts, count replies, publish `OK`, `NOTICE`, and `AUTH` | `noztr_sdk.client.relay.response.RelayResponseClient` | [relay_response_client.zig](../../examples/relay_response_client.zig) |
| Generic relay-session composition over shared runtime, relay auth, outbound request shaping, receive-side transcript intake, and bounded member/checkpoint export-restore | `noztr_sdk.client.relay.session.RelaySessionClient` | [relay_session_client.zig](../../examples/relay_session_client.zig) |
| Command-ready remembered detached-proof `NIP-03` verification plus bounded runtime and refresh planning over explicit HTTP, proof-store, verification-store, and event-archive seams | `noztr_sdk.client.proof.nip03.Nip03VerifyClient` | [nip03_verify_client.zig](../../examples/nip03_verify_client.zig) |
| Command-ready remembered `NIP-05` lookup and verify composition plus bounded resolution freshness and refresh planning over the explicit HTTP seam | `noztr_sdk.client.identity.nip05.Nip05VerifyClient` | [nip05_verify_client.zig](../../examples/nip05_verify_client.zig) |
| Command-ready remembered `NIP-39` profile verification plus bounded freshness and watched-target planning over explicit HTTP, cache, verification-store, and profile-store seams | `noztr_sdk.client.identity.nip39.Nip39VerifyClient` | [nip39_verify_client.zig](../../examples/nip39_verify_client.zig) |
| Bounded event storage, backend-agnostic querying, and named checkpoint persistence | `noztr_sdk.store` | [store_query.zig](../../examples/store_query.zig) |
| One embedded durable local-storage baseline over the shared event/query/checkpoint seam | `noztr_sdk.store.SqliteClientStore` | [sqlite_client_store.zig](../../examples/sqlite_client_store.zig) |
| Minimal CLI-facing event archive over the shared store seam | `noztr_sdk.store.EventArchive` | [store_archive.zig](../../examples/store_archive.zig) |
| Remembered relay-registry storage and bounded relay listing over the relay-info store seam | `noztr_sdk.store.RelayRegistryArchive` | [relay_registry_archive.zig](../../examples/relay_registry_archive.zig) |
| Minimal CLI-facing client composition over shared store plus relay runtime | `noztr_sdk.client.local.archive.CliArchiveClient` | [cli_archive_client.zig](../../examples/cli_archive_client.zig) |
| Neutral local archive, remembered-relay, checkpoint, runtime, and replay composition over the shared store and relay seams | `noztr_sdk.client.local.state.LocalStateClient` | [local_state_client.zig](../../examples/local_state_client.zig) |
| Persist relay-local runtime cursors over the shared checkpoint seam | `noztr_sdk.store.RelayCheckpointArchive` | [relay_checkpoint.zig](../../examples/relay_checkpoint.zig) |
| Bounded relay-local archive plus checkpoint-backed replay planning over the shared event and checkpoint seams | `noztr_sdk.store.RelayLocalArchive` | [relay_local_archive.zig](../../examples/relay_local_archive.zig) |
| Restore one relay-local `NIP-29` group snapshot over the shared event seam | `noztr_sdk.store.RelayLocalGroupArchive` | [relay_local_group_archive.zig](../../examples/relay_local_group_archive.zig) |
| Command-ready relay metadata refresh over the explicit HTTP seam plus remembered relay-registry storage | `noztr_sdk.client.relay.directory.RelayDirectoryJobClient` | [relay_directory_job_client.zig](../../examples/relay_directory_job_client.zig) |
| Remembered relay workspace specialization over the neutral local-state client for relay add/list/runtime/checkpoint/replay planning | `noztr_sdk.client.relay.workspace.RelayWorkspaceClient` | [relay_workspace_client.zig](../../examples/relay_workspace_client.zig) |
| Inspect shared multi-relay readiness, derive bounded subscription targets, and select typed next runtime or subscription steps | `noztr_sdk.runtime.RelayPool` | [relay_pool.zig](../../examples/relay_pool.zig) |
| Export and restore shared relay-pool membership plus per-relay cursors over the shared checkpoint seam, then derive bounded replay steps | `noztr_sdk.runtime.RelayPool` | [relay_pool_checkpoint.zig](../../examples/relay_pool_checkpoint.zig) |
| Remote signing, request/response orchestration, relay switching, durable session resume, and explicit signer-session policy/cadence over the shared relay floor | `noztr_sdk.workflows.signer.remote.Session` | [remote_signer.zig](../../examples/remote_signer.zig) |
| Explicit `NIP-57` zap request publish plus pay-endpoint fetch, callback invoice fetch, and receipt-validation inputs over the shared publish and HTTP seams | `noztr_sdk.workflows.zaps.ZapFlow` | [zap_flow.zig](../../examples/zap_flow.zig) |
| App-facing mailbox relay-list and reply-route helpers above the shared publish/query/archive seams | `noztr_sdk.client.dm.capability.DmCapabilityClient` | [dm_capability_client.zig](../../examples/dm_capability_client.zig) |
| App-facing mixed DM intake and outbound authoring over the mailbox and legacy DM workflow floors plus the DM capability route | `noztr_sdk.client.dm.mixed.MixedDmClient` | [mixed_dm_client.zig](../../examples/mixed_dm_client.zig) |
| Native legacy `NIP-04` direct-message build, JSON serialization, strict kind-`4` parse, and local plaintext recovery | `noztr_sdk.workflows.dm.legacy.LegacyDmSession` | [legacy_dm_workflow.zig](../../examples/legacy_dm_workflow.zig) |
| Command-ready auth-aware legacy `NIP-04` publish posture over the legacy DM workflow floor plus shared relay runtime | `noztr_sdk.client.dm.legacy.publish_job.Client` | [legacy_dm_publish_job_client.zig](../../examples/legacy_dm_publish_job_client.zig) |
| Bounded checkpoint-backed legacy `NIP-04` replay with parsed plaintext intake | `noztr_sdk.client.dm.legacy.replay_turn.Client` | [legacy_dm_replay_turn_client.zig](../../examples/legacy_dm_replay_turn_client.zig) |
| Command-ready auth-aware legacy `NIP-04` replay posture with explicit checkpoint saves | `noztr_sdk.client.dm.legacy.replay_job.Client` | [legacy_dm_sync_runtime_client.zig](../../examples/legacy_dm_sync_runtime_client.zig) |
| Bounded live legacy `NIP-04` subscription composition with parsed plaintext intake | `noztr_sdk.client.dm.legacy.subscription_turn.Client` | [legacy_dm_subscription_turn_client.zig](../../examples/legacy_dm_subscription_turn_client.zig) |
| Command-ready auth-aware legacy `NIP-04` live subscription posture over bounded subscription turns | `noztr_sdk.client.dm.legacy.subscription_job.Client` | [legacy_dm_sync_runtime_client.zig](../../examples/legacy_dm_sync_runtime_client.zig) |
| Bounded legacy `NIP-04` sync-runtime planning with explicit resume, reconnect, subscribe, and receive posture | `noztr_sdk.client.dm.legacy.sync_runtime.Client` | [legacy_dm_sync_runtime_client.zig](../../examples/legacy_dm_sync_runtime_client.zig) |
| Shared signer capability vocabulary plus local remote and browser adapter composition above existing local-operator `NIP-46` and thin browser signer surfaces | `noztr_sdk.client.signer.capability.SignerCapabilityProfile` | [signer_capability.zig](../../examples/signer_capability.zig) |
| Thin browser signer presence supported-method reporting and shared signer-capability completion above the reusable browser seam | `noztr_sdk.client.signer.browser.Nip07BrowserProvider` | [nip07_browser_signer.zig](../../examples/nip07_browser_signer.zig) |
| Command-ready signer connect job composition above the bounded signer client plus explicit relay auth acceptance | `noztr_sdk.client.signer.connect_job.SignerConnectJobClient` | [signer_connect_job_client.zig](../../examples/signer_connect_job_client.zig) |
| First signer-tooling client composition above the remote-signer workflow plus shared relay runtime, durable resume, and explicit signer-session policy/cadence | `noztr_sdk.client.signer.session.SignerClient` | [signer_client.zig](../../examples/signer_client.zig) |
| Command-ready signer `nip44_encrypt` job composition above the bounded signer client plus explicit relay auth acceptance | `noztr_sdk.client.signer.nip44_encrypt_job.SignerNip44EncryptJobClient` | [signer_nip44_encrypt_job_client.zig](../../examples/signer_nip44_encrypt_job_client.zig) |
| Command-ready signer public-key job composition above the bounded signer client plus explicit relay auth acceptance | `noztr_sdk.client.signer.pubkey_job.SignerPubkeyJobClient` | [signer_pubkey_job_client.zig](../../examples/signer_pubkey_job_client.zig) |
| Private-message send, receive, delivery planning, mailbox workflow stepping, and shared relay-pool inspection | `noztr_sdk.workflows.dm.mailbox.MailboxSession` | [mailbox.zig](../../examples/mailbox.zig) |
| Mailbox envelope intake over parsed wrap-event objects without JSON reserialization | `noztr_sdk.workflows.dm.mailbox.MailboxSession` | [mailbox_event_intake.zig](../../examples/mailbox_event_intake.zig) |
| Bounded mailbox receive-turn composition over ready-relay selection plus wrapped-envelope intake | `noztr_sdk.workflows.dm.mailbox.MailboxSession` | [mailbox_receive_turn.zig](../../examples/mailbox_receive_turn.zig) |
| Mailbox sync-turn composition over mailbox workflow ordering, explicit publish steps, and bounded receive turns | `noztr_sdk.workflows.dm.mailbox.MailboxSession` | [mailbox_sync_turn.zig](../../examples/mailbox_sync_turn.zig) |
| Command-ready mailbox auth, publish, and receive posture over mailbox sync turns plus local auth-event signing | `noztr_sdk.client.dm.mailbox.job.Client` | [mailbox_job_client.zig](../../examples/mailbox_job_client.zig) |
| Command-ready signer-backed mailbox direct-message authoring above the bounded signer client plus explicit mailbox delivery planning | `noztr_sdk.client.dm.mailbox.signer_job.MailboxSignerJobClient` | [mailbox_signer_job_client.zig](../../examples/mailbox_signer_job_client.zig) |
| Bounded live mailbox subscription composition with parsed envelope intake | `noztr_sdk.client.dm.mailbox.subscription_turn.Client` | [mailbox_subscription_turn_client.zig](../../examples/mailbox_subscription_turn_client.zig) |
| Command-ready auth-aware mailbox subscription posture over bounded mailbox subscription turns | `noztr_sdk.client.dm.mailbox.subscription_job.Client` | [mailbox_subscription_job_client.zig](../../examples/mailbox_subscription_job_client.zig) |
| Bounded mailbox sync-runtime planning with explicit resume, reconnect, subscribe, and receive posture | `noztr_sdk.client.dm.mailbox.sync_runtime.Client` | [mailbox_sync_runtime_client.zig](../../examples/mailbox_sync_runtime_client.zig) |
| Bounded checkpoint-backed mailbox replay with parsed envelope intake | `noztr_sdk.client.dm.mailbox.replay_turn.Client` | [mailbox_replay_turn_client.zig](../../examples/mailbox_replay_turn_client.zig) |
| Command-ready auth-aware mailbox replay posture with explicit checkpoint saves | `noztr_sdk.client.dm.mailbox.replay_job.Client` | [mailbox_replay_job_client.zig](../../examples/mailbox_replay_job_client.zig) |
| Detached OpenTimestamps proof verification plus remembered-proof reuse and bounded refresh planning | `noztr_sdk.workflows.proof.nip03.OpenTimestampsVerifier` | [nip03_verification.zig](../../examples/nip03_verification.zig) |
| Identity verification plus remembered discovery, freshness, and watched-target planning | `noztr_sdk.workflows.identity.verify.IdentityVerifier` | [nip39_verification.zig](../../examples/nip39_verification.zig) |
| `NIP-05` address resolution plus remembered successful resolutions and bounded freshness/refresh planning over the public HTTP seam | `noztr_sdk.workflows.identity.nip05.Nip05Resolver` | [nip05_resolution.zig](../../examples/nip05_resolution.zig) |
| Relay-local group replay, checkpointing, and moderation publish | `noztr_sdk.workflows.groups.local.GroupClient` | [group_session.zig](../../examples/group_session.zig) |
| Multi-relay groups routing, reconciliation, merge policy, checkpoints, and background runtime inspection | `noztr_sdk.workflows.groups.fleet.GroupFleet` | [group_fleet.zig](../../examples/group_fleet.zig) |
| Client-facing multi-relay groups runtime, consistency, checkpoint-store persistence, targeted reconcile, merge build/apply, publish planning, and background inspection composition above `GroupFleet` | `noztr_sdk.client.groups.fleet.GroupFleetClient` | [group_fleet_client.zig](../../examples/group_fleet_client.zig) |

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
