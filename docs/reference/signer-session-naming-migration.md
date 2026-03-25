---
title: Signer Session Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_signer_session_imports
---

# Signer Session Naming Migration

This is the pre-`1.0` cleanup for the canonical route:

- `noztr_sdk.client.signer.session.*`

The grouped route already carries signer-session context, so type names should be concise.

## Renamed Types

| Old name | Canonical name |
| --- | --- |
| `SignerClientError` | `Error` |
| `SignerClientCapabilityError` | `CapabilityError` |
| `SignerClientConfig` | `Config` |
| `SignerClientRequestStorage` | `RequestStorage` |
| `SignerClientStorage` | `Storage` |
| `SignerClientResumeStorage` | `ResumeStorage` |
| `SignerClientResumeState` | `ResumeState` |
| `SignerClientSessionPolicyAction` | `PolicyAction` |
| `SignerClientSessionPolicyStep` | `PolicyStep` |
| `SignerClientSessionPolicyPlan` | `PolicyPlan` |
| `SignerClientSessionCadenceRequest` | `CadenceRequest` |
| `SignerClientSessionCadenceWaitReason` | `CadenceWaitReason` |
| `SignerClientSessionCadenceWait` | `CadenceWait` |
| `SignerClientSessionCadenceStep` | `CadenceStep` |
| `SignerClientSessionCadencePlan` | `CadencePlan` |
| `SignerClient` | `Client` |
| `inspectSessionPolicy` | `inspectPolicy` |
| `inspectSessionCadence` | `inspectCadence` |

## Impact

- Breaking pre-`1.0` cleanup for downstreams using old route-local names.
- Scope is limited to `noztr_sdk.client.signer.session.*`.
- `workflows.signer.remote.*` naming is unchanged by this migration.

## Example

Before:

```zig
const session = noztr_sdk.client.signer.session;
var storage = session.SignerClientStorage{};
const client = try session.SignerClient.initFromBunkerUriText(.{}, uri_text, scratch);
```

After:

```zig
const session = noztr_sdk.client.signer.session;
var storage = session.Storage{};
const client = try session.Client.initFromBunkerUriText(.{}, uri_text, scratch);
```
