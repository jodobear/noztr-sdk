---
title: Remote Signer Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_remote_signer_imports
---

# Remote Signer Naming Migration

This is a narrow pre-`1.0` naming cleanup for the remote-signer workflow module.

Canonical public names are now domain-prefixed inside `noztr_sdk.workflows.signer.remote`, to
match the names already used by the root workflow surface and public docs.

## Renamed Types

| Old module-local name | Canonical name |
| --- | --- |
| `PubkeyTextRequest` | `RemoteSignerPubkeyTextRequest` |
| `RequestBuffer` | `RemoteSignerRequestBuffer` |
| `RequestContext` | `RemoteSignerRequestContext` |
| `OutboundRequest` | `RemoteSignerOutboundRequest` |
| `TextResponse` | `RemoteSignerTextResponse` |
| `ResponseOutcome` | `RemoteSignerResponseOutcome` |

## Impact

- If you already import the canonical root workflow symbols such as
  `noztr_sdk.workflows.signer.remote.RemoteSignerRequestContext`, nothing changes.
- If you import the submodule directly, update those type names to the canonical prefixed forms.

## Example

Before:

```zig
const remote_signer = noztr_sdk.workflows.signer.remote;
var buffer = remote_signer.RequestBuffer{};
const ctx = remote_signer.RequestContext.init("req-1", &buffer, scratch);
```

After:

```zig
const remote_signer = noztr_sdk.workflows.signer.remote;
var buffer = remote_signer.RemoteSignerRequestBuffer{};
const ctx = remote_signer.RemoteSignerRequestContext.init("req-1", &buffer, scratch);
```
