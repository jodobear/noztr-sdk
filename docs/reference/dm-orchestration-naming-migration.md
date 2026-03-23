---
title: DM Orchestration Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_dm_orchestration_imports
---

# DM Orchestration Naming Migration

Pre-`1.0` DM orchestration cleanup:

## What Changed

The grouped routes stayed the same:
- `noztr_sdk.client.dm.mailbox.job.*`
- `noztr_sdk.client.dm.mailbox.replay_turn.*`
- `noztr_sdk.client.dm.mailbox.replay_job.*`
- `noztr_sdk.client.dm.mailbox.subscription_turn.*`
- `noztr_sdk.client.dm.mailbox.subscription_job.*`
- `noztr_sdk.client.dm.legacy.publish_job.*`
- `noztr_sdk.client.dm.legacy.replay_turn.*`
- `noztr_sdk.client.dm.legacy.replay_job.*`
- `noztr_sdk.client.dm.legacy.subscription_turn.*`
- `noztr_sdk.client.dm.legacy.subscription_job.*`

The route-internal names were shortened so the grouped namespace carries the route context.

## Type Renames

Most of these grouped routes now use the same role-based shape:

- `...ClientError` -> `Error`
- `...ClientConfig` -> `Config`
- `...ClientStorage` -> `Storage`
- `...Request` -> `Request`
- `...Intake` -> `Intake`
- `...Ready` -> `Ready`
- `...Result` -> `Result`
- `...Client` -> `Client`

Auth-aware job routes also shortened their auth helpers:

- `...AuthEventStorage` -> `AuthStorage`
- `Prepared...AuthEvent` -> `PreparedAuthEvent`

That applies to:
- mailbox job
- mailbox replay job
- mailbox subscription job
- legacy publish job
- legacy replay job
- legacy subscription job

Turn routes shortened to:
- `Error`
- `Config`
- `Storage`
- `Request`
- `Intake`
- `Result`
- `Client`

That applies to:
- mailbox replay turn
- mailbox subscription turn
- legacy replay turn
- legacy subscription turn

## Before

```zig
var storage = noztr_sdk.client.dm.mailbox.replay_job.MailboxReplayJobClientStorage{};
var client = noztr_sdk.client.dm.mailbox.replay_job.MailboxReplayJobClient.init(.{
    .recipient_private_key = secret,
}, &storage);

var auth_storage = noztr_sdk.client.dm.mailbox.replay_job.MailboxReplayJobAuthEventStorage{};
```

## After

```zig
var storage = noztr_sdk.client.dm.mailbox.replay_job.Storage{};
var client = noztr_sdk.client.dm.mailbox.replay_job.Client.init(.{
    .recipient_private_key = secret,
}, &storage);

var auth_storage = noztr_sdk.client.dm.mailbox.replay_job.AuthStorage{};
```

## Reason

The grouped namespace already tells you:
- DM versus non-DM
- mailbox versus legacy
- job versus turn
- replay versus subscription versus publish

The older names kept restating that route in every symbol. This cleanup keeps the route as the
context and shortens the remaining nouns to the role that actually matters.
