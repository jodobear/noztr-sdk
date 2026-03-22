---
title: Grouped Public Namespace Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_public_imports
---

# Grouped Public Namespace Migration

This is the pre-`1.0` breaking namespace cleanup that removed the old flat public type routes from
`noztr_sdk.client` and `noztr_sdk.workflows`.

## What Changed

- flat routes like `noztr_sdk.client.RelaySessionClient` were removed
- flat routes like `noztr_sdk.workflows.RemoteSignerSession` were removed
- grouped routes are now the only canonical public shape

## Canonical Public Routes

- `noztr_sdk.client.local.*`
- `noztr_sdk.client.relay.*`
- `noztr_sdk.client.signer.*`
- `noztr_sdk.client.dm.*`
- `noztr_sdk.client.identity.*`
- `noztr_sdk.client.proof.*`
- `noztr_sdk.client.groups.*`
- `noztr_sdk.workflows.groups.*`
- `noztr_sdk.workflows.identity.*`
- `noztr_sdk.workflows.dm.*`
- `noztr_sdk.workflows.proof.*`
- `noztr_sdk.workflows.signer.*`

## Examples

Before:

```zig
const RelaySessionClient = noztr_sdk.client.RelaySessionClient;
const MailboxSession = noztr_sdk.workflows.MailboxSession;
```

After:

```zig
const RelaySessionClient = noztr_sdk.client.relay.session.RelaySessionClient;
const MailboxSession = noztr_sdk.workflows.dm.mailbox.MailboxSession;
```

## Guidance

When you need a public symbol, start from the grouped module route first and then select the type
inside that module. Use the public contract map for the current canonical route.
