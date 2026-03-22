---
title: Workflow Submodule Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_group_or_mailbox_submodule_imports
---

# Workflow Submodule Naming Migration

This is a narrow pre-`1.0` naming cleanup for direct workflow submodule imports.

Canonical public names now match the prefixed names already used by the root workflow surface for:
- `noztr_sdk.workflows.groups.session`
- `noztr_sdk.workflows.dm.mailbox`

If you already import the canonical root workflow symbols such as
`noztr_sdk.workflows.groups.session.GroupPublishContext` or
`noztr_sdk.workflows.dm.mailbox.MailboxWorkflowRequest`, nothing changes.

## Group Session Renames

| Old submodule name | Canonical name |
| --- | --- |
| `OutboundBuffer` | `GroupOutboundBuffer` |
| `PublishContext` | `GroupPublishContext` |
| `OutboundEvent` | `GroupOutboundEvent` |
| `CheckpointBuffers` | `GroupCheckpointBuffers` |
| `CheckpointContext` | `GroupCheckpointContext` |
| `Checkpoint` | `GroupCheckpoint` |

## Mailbox Renames

| Old submodule name | Canonical name |
| --- | --- |
| `FileDimensions` | `MailboxFileDimensions` |
| `OutboundBuffer` | `MailboxOutboundBuffer` |
| `DeliveryStorage` | `MailboxDeliveryStorage` |
| `DeliveryRole` | `MailboxDeliveryRole` |
| `DeliveryStep` | `MailboxDeliveryStep` |
| `DeliveryPlan` | `MailboxDeliveryPlan` |
| `RuntimeAction` | `MailboxRuntimeAction` |
| `RuntimeEntry` | `MailboxRuntimeEntry` |
| `RuntimeStep` | `MailboxRuntimeStep` |
| `RelayPoolStorage` | `MailboxRelayPoolStorage` |
| `RelayPoolRuntimeStorage` | `MailboxRelayPoolRuntimeStorage` |
| `WorkflowAction` | `MailboxWorkflowAction` |
| `WorkflowEntry` | `MailboxWorkflowEntry` |
| `WorkflowStep` | `MailboxWorkflowStep` |
| `WorkflowStorage` | `MailboxWorkflowStorage` |
| `WorkflowRequest` | `MailboxWorkflowRequest` |
| `WorkflowPlan` | `MailboxWorkflowPlan` |
| `RuntimeStorage` | `MailboxRuntimeStorage` |
| `RuntimePlan` | `MailboxRuntimePlan` |
| `ReceiveTurnStorage` | `MailboxReceiveTurnStorage` |
| `ReceiveTurnRequest` | `MailboxReceiveTurnRequest` |
| `ReceiveTurnResult` | `MailboxReceiveTurnResult` |
| `SyncTurnStorage` | `MailboxSyncTurnStorage` |
| `SyncTurnRequest` | `MailboxSyncTurnRequest` |
| `SyncTurnResult` | `MailboxSyncTurnResult` |
| `DirectMessageRequest` | `MailboxDirectMessageRequest` |
| `FileMessageRequest` | `MailboxFileMessageRequest` |
| `OutboundMessage` | `MailboxOutboundMessage` |

## Example

Before:

```zig
const mailbox = noztr_sdk.workflows.dm.mailbox;
var buffer = mailbox.OutboundBuffer{};
const request = mailbox.WorkflowRequest{
    .pending_delivery = null,
    .storage = &storage,
};
```

After:

```zig
const mailbox = noztr_sdk.workflows.dm.mailbox;
var buffer = mailbox.MailboxOutboundBuffer{};
const request = mailbox.MailboxWorkflowRequest{
    .pending_delivery = null,
    .storage = &storage,
};
```
