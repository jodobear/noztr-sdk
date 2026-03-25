---
title: Mailbox Signer Job Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_mailbox_signer_job_imports
---

# Mailbox Signer Job Naming Migration

This cleanup keeps only route-local names for `client.dm.mailbox.signer_job.*` and is implemented as:

- `noztr_sdk.client.dm.mailbox.signer_job.Error`
- `noztr_sdk.client.dm.mailbox.signer_job.Config`
- `noztr_sdk.client.dm.mailbox.signer_job.Storage`
- `noztr_sdk.client.dm.mailbox.signer_job.AuthEventStorage`
- `noztr_sdk.client.dm.mailbox.signer_job.PreparedAuthEvent`
- `noztr_sdk.client.dm.mailbox.signer_job.Ready`
- `noztr_sdk.client.dm.mailbox.signer_job.DirectMessageRequest`
- `noztr_sdk.client.dm.mailbox.signer_job.DirectMessageProgress`
- `noztr_sdk.client.dm.mailbox.signer_job.PreparedDirectMessage`
- `noztr_sdk.client.dm.mailbox.signer_job.DirectMessageResult`
- `noztr_sdk.client.dm.mailbox.signer_job.Client`

## Renamed Types

| Old name | Canonical name |
| --- | --- |
| `MailboxSignerJobClientError` | `Error` |
| `MailboxSignerJobClientConfig` | `Config` |
| `MailboxSignerJobClientStorage` | `Storage` |
| `MailboxSignerJobAuthEventStorage` | `AuthEventStorage` |
| `PreparedMailboxSignerJobAuthEvent` | `PreparedAuthEvent` |
| `MailboxSignerJobReady` | `Ready` |
| `MailboxSignerDirectMessageRequest` | `DirectMessageRequest` |
| `MailboxSignerDirectMessageProgress` | `DirectMessageProgress` |
| `PreparedMailboxSignerDirectMessage` | `PreparedDirectMessage` |
| `MailboxSignerDirectMessageResult` | `DirectMessageResult` |
| `MailboxSignerJobClient` | `Client` |

## Impact

- This is a breaking pre-`1.0` cleanup for downstreams using old route-local names.
- Route shape is unchanged; only public type names inside this grouped route module changed.

## Example

Before:

```zig
const job = noztr_sdk.client.dm.mailbox.signer_job;
var storage = job.MailboxSignerJobClientStorage{};
var client = try job.MailboxSignerJobClient.initFromBunkerUriText(.{}, &storage, bunker_uri, scratch);
```

After:

```zig
const job = noztr_sdk.client.dm.mailbox.signer_job;
var storage = job.Storage{};
var client = try job.Client.initFromBunkerUriText(.{}, &storage, bunker_uri, scratch);
```
