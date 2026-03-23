---
title: DM Sync Runtime Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_dm_sync_runtime_imports
---

# DM Sync Runtime Naming Migration

Pre-`1.0` DM sync-runtime cleanup:

## What Changed

The grouped routes stayed the same:
- `noztr_sdk.client.dm.mailbox.sync_runtime.*`
- `noztr_sdk.client.dm.legacy.sync_runtime.*`

But the route-internal names were shortened so the grouped namespace carries the context.

## Type Renames

Both grouped routes changed in the same way:

- `MailboxSyncRuntimeClient` / `LegacyDmSyncRuntimeClient` -> `Client`
- `MailboxSyncRuntimeClientError` / `LegacyDmSyncRuntimeClientError` -> `ClientError`
- `MailboxSyncRuntimeClientConfig` / `LegacyDmSyncRuntimeClientConfig` -> `Config`
- `MailboxSyncRuntimeClientStorage` / `LegacyDmSyncRuntimeClientStorage` -> `Storage`
- `MailboxSyncRuntimeResumeStorage` / `LegacyDmSyncRuntimeResumeStorage` -> `ResumeStorage`
- `MailboxSyncRuntimeResumeState` / `LegacyDmSyncRuntimeResumeState` -> `ResumeState`
- `MailboxSyncRuntimePlanStorage` / `LegacyDmSyncRuntimePlanStorage` -> `PlanStorage`
- `MailboxSyncRuntimePlan` / `LegacyDmSyncRuntimePlan` -> `Plan`
- `MailboxSyncRuntimeStep` / `LegacyDmSyncRuntimeStep` -> `Step`
- `MailboxLongLivedDmPolicyStorage` / `LegacyDmLongLivedDmPolicyStorage` -> `PolicyStorage`
- `MailboxLongLivedDmPolicyPlan` / `LegacyDmLongLivedDmPolicyPlan` -> `PolicyPlan`
- `MailboxLongLivedDmPolicyStep` / `LegacyDmLongLivedDmPolicyStep` -> `PolicyStep`
- `MailboxDmOrchestrationStorage` / `LegacyDmOrchestrationStorage` -> `OrchestrationStorage`
- `MailboxDmOrchestrationPlan` / `LegacyDmOrchestrationPlan` -> `OrchestrationPlan`
- `MailboxDmOrchestrationStep` / `LegacyDmOrchestrationStep` -> `OrchestrationStep`
- `MailboxDmRuntimeCadenceRequest` / `LegacyDmRuntimeCadenceRequest` -> `CadenceRequest`
- `MailboxDmRuntimeCadenceStorage` / `LegacyDmRuntimeCadenceStorage` -> `CadenceStorage`
- `MailboxDmRuntimeCadenceWaitReason` / `LegacyDmRuntimeCadenceWaitReason` -> `CadenceWaitReason`
- `MailboxDmRuntimeCadenceWait` / `LegacyDmRuntimeCadenceWait` -> `CadenceWait`
- `MailboxDmRuntimeCadencePlan` / `LegacyDmRuntimeCadencePlan` -> `CadencePlan`
- `MailboxDmRuntimeCadenceStep` / `LegacyDmRuntimeCadenceStep` -> `CadenceStep`
- `MailboxSyncRuntimeAuthEventStorage` / `LegacyDmSyncRuntimeAuthEventStorage` -> `AuthEventStorage`
- `PreparedMailboxSyncRuntimeAuthEvent` / `PreparedLegacyDmSyncRuntimeAuthEvent` -> `PreparedAuthEvent`
- `MailboxSyncRuntimeReplayRequest` / `LegacyDmSyncRuntimeReplayRequest` -> `ReplayRequest`
- `MailboxSyncRuntimeReplayIntake` / `LegacyDmSyncRuntimeReplayIntake` -> `ReplayIntake`
- `MailboxSyncRuntimeSubscriptionRequest` / `LegacyDmSyncRuntimeSubscriptionRequest` -> `SubscriptionRequest`
- `MailboxSyncRuntimeSubscriptionIntake` / `LegacyDmSyncRuntimeSubscriptionIntake` -> `SubscriptionIntake`

## Method Renames

Both grouped routes also shortened the helper names:

- `inspectLongLivedDmPolicy` -> `inspectPolicy`
- `inspectDmOrchestration` -> `inspectOrchestration`
- `inspectDmRuntimeCadence` -> `inspectCadence`

## Before

```zig
var storage = noztr_sdk.client.dm.mailbox.sync_runtime.MailboxSyncRuntimeClientStorage{};
var client = noztr_sdk.client.dm.mailbox.sync_runtime.MailboxSyncRuntimeClient.init(.{
    .recipient_private_key = secret,
}, &storage);

var cadence_storage = noztr_sdk.client.dm.mailbox.sync_runtime.MailboxDmRuntimeCadenceStorage{};
const cadence = try client.inspectDmRuntimeCadence(
    checkpoint_store,
    &.{},
    specs,
    .{ .now_unix_seconds = 120 },
    &cadence_storage,
);
```

## After

```zig
var storage = noztr_sdk.client.dm.mailbox.sync_runtime.Storage{};
var client = noztr_sdk.client.dm.mailbox.sync_runtime.Client.init(.{
    .recipient_private_key = secret,
}, &storage);

var cadence_storage = noztr_sdk.client.dm.mailbox.sync_runtime.CadenceStorage{};
const cadence = try client.inspectCadence(
    checkpoint_store,
    &.{},
    specs,
    .{ .now_unix_seconds = 120 },
    &cadence_storage,
);
```

## Reason

The grouped namespace already carries:
- DM versus non-DM
- mailbox versus legacy
- sync runtime versus other DM helpers

The older names kept restating that route in every type.
This cleanup keeps the route as the context and shortens the remaining nouns to the role that
actually matters.
