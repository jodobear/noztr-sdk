---
title: Mixed DM Route Local Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0
canonical: false
---

# Mixed DM Route Local Naming Migration

The grouped route stays the same:

- `noztr_sdk.client.dm.mixed.*`

This cleanup only shortens route-local names where the grouped route already carries the DM
context.

## Mixed DM Observed And Memory Family

- `MixedDmObservedReplyRef` -> `ObservedReplyRef`
- `MixedDmObservedMessageIdentity` -> `ObservedMessageIdentity`
- `MixedDmObservedMailboxDirectMessage` -> `ObservedMailboxMessage`
- `MixedDmObservedMailboxFileMessage` -> `ObservedMailboxFile`
- `MixedDmObservedLegacyDirectMessage` -> `ObservedLegacyMessage`
- `MixedDmObservedMessage` -> `ObservedMessage`
- `MixedDmSenderProtocolMemoryRecord` -> `SenderProtocolRecord`
- `MixedDmSenderProtocolMemory` -> `SenderProtocolMemory`
- `MixedDmRememberedReplyRequest` -> `RememberedReplyRequest`
- `MixedDmRememberedReplyRoute` -> `RememberedReplyRoute`
- `MixedDmDedupRecord` -> `DedupRecord`
- `MixedDmDedupMemory` -> `DedupMemory`
- `MixedDmDedupResult` -> `DedupResult`

## Adjacent DM Route Local Cleanup

- `client.dm.capability.MailboxRelayListSubscriptionRequest` -> `MailboxRelaySubscriptionRequest`
- `client.dm.capability.MailboxRelayListSubscriptionStorage` -> `MailboxRelaySubscriptionStorage`
- `client.relay.replay_checkpoint_advance.ReplayCheckpointAdvanceClientConfig` ->
  `ReplayCheckpointAdvanceConfig`

If you were already using the grouped routes directly, this is a route-local rename only. No DM
behavior or route ownership changed in this cleanup.
