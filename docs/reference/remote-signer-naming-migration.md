---
title: Remote Signer Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_remote_signer_imports
---

# Remote Signer Naming Migration

This is the current pre-`1.0` breaking naming cleanup for the grouped
`noztr_sdk.workflows.signer.remote.*` route.

## Renamed Types

Canonical public names inside the grouped route are now shorter role-based names. The grouped
route already carries the remote-signer context, so the type names no longer restate
`RemoteSigner...` or `...Session...` unless that extra wording adds real meaning.

| Old name | Canonical name |
| --- | --- |
| `RemoteSignerError` | `Error` |
| `RemoteSignerMethod` | `Method` |
| `RemoteSignerSession` | `Session` |
| `RemoteSignerPubkeyTextRequest` | `PubkeyTextRequest` |
| `RemoteSignerRequestBuffer` | `RequestBuffer` |
| `RemoteSignerRequestContext` | `RequestContext` |
| `RemoteSignerOutboundRequest` | `OutboundRequest` |
| `RemoteSignerTextResponse` | `TextResponse` |
| `RemoteSignerResponseOutcome` | `ResponseOutcome` |
| `RemoteSignerRelayPoolStorage` | `RelayPoolStorage` |
| `RemoteSignerRelayPoolRuntimeStorage` | `RelayRuntimeStorage` |
| `RemoteSignerResumeStorage` | `ResumeStorage` |
| `RemoteSignerResumeState` | `ResumeState` |
| `RemoteSignerSessionPolicyAction` | `PolicyAction` |
| `RemoteSignerSessionPolicyStep` | `PolicyStep` |
| `RemoteSignerSessionPolicyPlan` | `PolicyPlan` |
| `RemoteSignerSessionCadenceRequest` | `CadenceRequest` |
| `RemoteSignerSessionCadenceWaitReason` | `CadenceWaitReason` |
| `RemoteSignerSessionCadenceWait` | `CadenceWait` |
| `RemoteSignerSessionCadenceStep` | `CadenceStep` |
| `RemoteSignerSessionCadencePlan` | `CadencePlan` |

## Impact

- This is a breaking pre-`1.0` cleanup for downstreams that imported the old longer names.
- The grouped route stays the same:
  - `noztr_sdk.workflows.signer.remote.*`
- Only the route-internal type names changed.

## Example

Before:

```zig
const remote_signer = noztr_sdk.workflows.signer.remote;
var buffer = remote_signer.RemoteSignerRequestBuffer{};
const ctx = remote_signer.RemoteSignerRequestContext.init("req-1", &buffer, scratch);
```

After:

```zig
const remote_signer = noztr_sdk.workflows.signer.remote;
var buffer = remote_signer.RequestBuffer{};
const ctx = remote_signer.RequestContext.init("req-1", &buffer, scratch);
```
