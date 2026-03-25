---
title: Signer Job Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_signer_job_imports
---

# Signer Job Naming Migration

This is the current pre-`1.0` cleanup for grouped signer job families:

- `noztr_sdk.client.signer.connect_job.*`
- `noztr_sdk.client.signer.pubkey_job.*`
- `noztr_sdk.client.signer.nip44_encrypt_job.*`

The grouped route already supplies signer/job context, so route-local names should be concise.

## Renamed Types

| Old name | Canonical name |
| --- | --- |
| `SignerConnectJobClientError` | `Error` |
| `SignerConnectJobClientConfig` | `Config` |
| `SignerConnectJobClientStorage` | `Storage` |
| `SignerConnectJobAuthEventStorage` | `AuthEventStorage` |
| `PreparedSignerConnectJobAuthEvent` | `PreparedAuthEvent` |
| `SignerConnectJobRequest` | `Request` |
| `SignerConnectJobReady` | `Ready` |
| `SignerConnectJobResult` | `Result` |
| `SignerConnectJobClient` | `Client` |
| `SignerPubkeyJobClientError` | `Error` |
| `SignerPubkeyJobClientConfig` | `Config` |
| `SignerPubkeyJobClientStorage` | `Storage` |
| `SignerPubkeyJobAuthEventStorage` | `AuthEventStorage` |
| `PreparedSignerPubkeyJobAuthEvent` | `PreparedAuthEvent` |
| `SignerPubkeyJobRequest` | `Request` |
| `SignerPubkeyJobReady` | `Ready` |
| `SignerPubkeyJobResult` | `Result` |
| `SignerPubkeyJobClient` | `Client` |
| `SignerNip44EncryptJobClientError` | `Error` |
| `SignerNip44EncryptJobClientConfig` | `Config` |
| `SignerNip44EncryptJobClientStorage` | `Storage` |
| `SignerNip44EncryptJobAuthEventStorage` | `AuthEventStorage` |
| `PreparedSignerNip44EncryptJobAuthEvent` | `PreparedAuthEvent` |
| `SignerNip44EncryptJobRequest` | `Request` |
| `SignerNip44EncryptJobReady` | `Ready` |
| `SignerNip44EncryptJobResult` | `Result` |
| `SignerNip44EncryptJobClient` | `Client` |

## Impact

- This is a breaking pre-`1.0` cleanup for downstreams using old route-local names.
- Route shape is unchanged; only public type names inside these grouped route modules changed:
  - `noztr_sdk.client.signer.connect_job.*`
  - `noztr_sdk.client.signer.pubkey_job.*`
  - `noztr_sdk.client.signer.nip44_encrypt_job.*`

## Example

Before:

```zig
const job = noztr_sdk.client.signer.connect_job;
var storage = job.SignerConnectJobClientStorage{};
var client = try job.SignerConnectJobClient.initFromBunkerUriText(.{}, &storage, bunker_uri, scratch);
```

After:

```zig
const job = noztr_sdk.client.signer.connect_job;
var storage = job.Storage{};
var client = try job.Client.initFromBunkerUriText(.{}, &storage, bunker_uri, scratch);
```
