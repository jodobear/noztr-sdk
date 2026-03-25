---
title: Signer Capability Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_signer_capability_imports
---

# Signer Capability Naming Migration

This is the pre-`1.0` cleanup for the grouped
`noztr_sdk.client.signer.capability.*` route.

The grouped route already carries signer-capability context, so type names should be concise.

## Renamed Types

| Old name | Canonical name |
| --- | --- |
| `SignerBackendKind` | `BackendKind` |
| `SignerOperation` | `Operation` |
| `SignerOperationMode` | `OperationMode` |
| `SignerOperationModes` | `OperationModes` |
| `SignerCapabilityProfile` | `Profile` |
| `SignerPubkeyTextRequest` | `PubkeyTextRequest` |
| `SignerOperationRequest` | `OperationRequest` |
| `SignerTextResponse` | `TextResponse` |
| `SignerOperationResult` | `OperationResult` |

## Impact

- This is a breaking pre-`1.0` cleanup for downstreams using old route-local names.
- The grouped route stays the same:
  - `noztr_sdk.client.signer.capability.*`
- Only these route-internal signer-capability type names changed.

## Example

Before:

```zig
const capability = noztr_sdk.client.signer.capability;
var request: capability.SignerOperationRequest = .{
    .get_public_key = {},
};
```

After:

```zig
const capability = noztr_sdk.client.signer.capability;
var request: capability.OperationRequest = .{
    .get_public_key = {},
};
```
