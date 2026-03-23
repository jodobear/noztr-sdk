---
title: Proof And Identity Planning Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_nip03_nip39_client_planning_imports
---

# Proof And Identity Planning Migration

This is the current pre-`1.0` breaking cleanup for the client-facing:

- `noztr_sdk.client.proof.nip03.*`
- `noztr_sdk.client.identity.nip39.*`

The grouped routes stayed the same. The cleanup shortens the planning families inside those routes
so the namespace carries more of the context and the route-internal names stay role-focused.

## `NIP-03` Client Planning

### Renamed Type Family

| Old name | Canonical name |
| --- | --- |
| `Nip03StoredVerificationPlanning` | `Planning` |
| `TargetRefreshReadinessAction` | `TargetReadinessAction` |
| `TargetRefreshReadinessEntry` | `TargetReadinessEntry` |
| `TargetRefreshReadinessGroup` | `TargetReadinessGroup` |
| `TargetRefreshReadinessStorage` | `TargetReadinessStorage` |
| `TargetRefreshReadinessRequest` | `TargetReadinessRequest` |
| `TargetRefreshReadinessPlan` | `TargetReadinessPlan` |
| `TargetRefreshReadinessStep` | `TargetReadinessStep` |
| `TargetRefreshCadenceAction` | `TargetCadenceAction` |
| `TargetRefreshCadenceEntry` | `TargetCadenceEntry` |
| `TargetRefreshCadenceGroup` | `TargetCadenceGroup` |
| `TargetRefreshCadenceStorage` | `TargetCadenceStorage` |
| `TargetRefreshCadenceRequest` | `TargetCadenceRequest` |
| `TargetRefreshCadencePlan` | `TargetCadencePlan` |
| `TargetRefreshCadenceStep` | `TargetCadenceStep` |
| `TargetRefreshBatchStorage` | `TargetBatchStorage` |
| `TargetRefreshBatchRequest` | `TargetBatchRequest` |
| `TargetRefreshBatchPlan` | `TargetBatchPlan` |
| `TargetRefreshBatchStep` | `TargetBatchStep` |

### Renamed Client Methods

| Old method | Canonical method |
| --- | --- |
| `getLatestStoredVerificationFreshness` | `getLatestFreshness` |
| `discoverLatestStoredVerificationFreshnessForTargets` | `discoverLatestForTargets` |
| `getPreferredStoredVerification` | `getPreferred` |
| `getPreferredStoredVerificationForTargets` | `getPreferredForTargets` |
| `inspectStoredVerificationRuntime` | `inspectRuntime` |
| `planStoredVerificationRefresh` | `planRefresh` |
| `planStoredVerificationRefreshForTargets` | `planTargetRefresh` |
| `inspectStoredVerificationRefreshReadinessForTargets` | `inspectTargetReadiness` |
| `inspectStoredVerificationPolicyForTargets` | `inspectTargetPolicy` |
| `inspectStoredVerificationRefreshCadenceForTargets` | `inspectTargetCadence` |
| `inspectStoredVerificationRefreshBatchForTargets` | `inspectTargetBatch` |
| `inspectStoredVerificationTurnPolicyForTargets` | `inspectTargetTurnPolicy` |

## `NIP-39` Client Planning

### Renamed Type Family

| Old name | Canonical name |
| --- | --- |
| `Nip39StoredProfilePlanning` | `Planning` |
| `TargetLatestFreshnessEntry` | `TargetLatestEntry` |
| `TargetLatestFreshnessStorage` | `TargetLatestStorage` |
| `TargetLatestFreshnessRequest` | `TargetLatestRequest` |
| `RememberedIdentityLatestFreshnessStorage` | `RememberedLatestStorage` |
| `RememberedIdentityLatestFreshnessRequest` | `RememberedLatestRequest` |
| `RememberedIdentityLatestFreshnessPlan` | `RememberedLatestPlan` |
| `TargetRefreshCadenceAction` | `TargetCadenceAction` |
| `TargetRefreshCadenceEntry` | `TargetCadenceEntry` |
| `TargetRefreshCadenceGroup` | `TargetCadenceGroup` |
| `TargetRefreshCadenceStorage` | `TargetCadenceStorage` |
| `TargetRefreshCadenceRequest` | `TargetCadenceRequest` |
| `TargetRefreshCadencePlan` | `TargetCadencePlan` |
| `TargetRefreshCadenceStep` | `TargetCadenceStep` |
| `RememberedIdentityRefreshCadenceStorage` | `RememberedCadenceStorage` |
| `RememberedIdentityRefreshCadenceRequest` | `RememberedCadenceRequest` |
| `RememberedIdentityRefreshCadencePlan` | `RememberedCadencePlan` |
| `TargetRefreshBatchStorage` | `TargetBatchStorage` |
| `TargetRefreshBatchRequest` | `TargetBatchRequest` |
| `TargetRefreshBatchPlan` | `TargetBatchPlan` |
| `TargetRefreshBatchStep` | `TargetBatchStep` |
| `RememberedIdentityRefreshBatchStorage` | `RememberedBatchStorage` |
| `RememberedIdentityRefreshBatchRequest` | `RememberedBatchRequest` |
| `RememberedIdentityRefreshBatchPlan` | `RememberedBatchPlan` |
| `StoredWatchedTargetPolicyError` | `WatchedPolicyError` |
| `StoredWatchedTargetPolicyStorage` | `WatchedPolicyStorage` |
| `StoredWatchedTargetPolicyRequest` | `WatchedPolicyRequest` |
| `StoredWatchedTargetPolicyPlan` | `WatchedPolicyPlan` |
| `StoredWatchedTargetRefreshCadenceError` | `WatchedCadenceError` |
| `StoredWatchedTargetRefreshCadenceStorage` | `WatchedCadenceStorage` |
| `StoredWatchedTargetRefreshCadenceRequest` | `WatchedCadenceRequest` |
| `StoredWatchedTargetRefreshCadencePlan` | `WatchedCadencePlan` |
| `StoredWatchedTargetRefreshBatchError` | `WatchedBatchError` |
| `StoredWatchedTargetRefreshBatchStorage` | `WatchedBatchStorage` |
| `StoredWatchedTargetRefreshBatchRequest` | `WatchedBatchRequest` |
| `StoredWatchedTargetRefreshBatchPlan` | `WatchedBatchPlan` |
| `StoredWatchedTargetOrchestrationError` | `WatchedOrchestrationError` |
| `StoredWatchedTargetOrchestrationStorage` | `WatchedOrchestrationStorage` |
| `StoredWatchedTargetOrchestrationRequest` | `WatchedOrchestrationRequest` |
| `StoredWatchedTargetOrchestrationPlan` | `WatchedOrchestrationPlan` |
| `StoredWatchedTargetTurnPolicyError` | `WatchedTurnPolicyError` |
| `StoredWatchedTargetTurnPolicyStorage` | `WatchedTurnPolicyStorage` |
| `StoredWatchedTargetTurnPolicyRequest` | `WatchedTurnPolicyRequest` |
| `StoredWatchedTargetTurnPolicyPlan` | `WatchedTurnPolicyPlan` |

### Renamed Client Methods

| Old method | Canonical method |
| --- | --- |
| `discoverStoredProfileEntriesForTargets` | `discoverTargets` |
| `discoverStoredProfileEntriesWithFreshnessForTargets` | `discoverTargetsWithFreshness` |
| `inspectLatestStoredProfileFreshnessForTargets` | `inspectTargetLatest` |
| `inspectRememberedIdentityLatestFreshness` | `inspectRememberedLatest` |
| `getPreferredStoredProfilesForTargets` | `getPreferredForTargets` |
| `getPreferredStoredProfileForTargets` | `getPreferredTarget` |
| `planStoredProfileRefreshForTargets` | `planTargetRefresh` |
| `inspectStoredProfileRuntimeForTargets` | `inspectTargetRuntime` |
| `inspectStoredProfilePolicyForTargets` | `inspectTargetPolicy` |
| `inspectStoredProfileRefreshCadenceForTargets` | `inspectTargetCadence` |
| `inspectStoredProfileRefreshBatchForTargets` | `inspectTargetBatch` |
| `inspectStoredProfileTurnPolicyForTargets` | `inspectTargetTurnPolicy` |
| `inspectStoredWatchedTargetPolicy` | `inspectWatchedPolicy` |
| `inspectStoredWatchedTargetRefreshCadence` | `inspectWatchedCadence` |
| `inspectRememberedIdentityRefreshCadence` | `inspectRememberedCadence` |
| `inspectStoredWatchedTargetRefreshBatch` | `inspectWatchedBatch` |
| `inspectRememberedIdentityRefreshBatch` | `inspectRememberedBatch` |
| `inspectStoredWatchedTargetTurnPolicy` | `inspectWatchedTurnPolicy` |
| `inspectStoredWatchedTargetOrchestration` | `inspectWatchedOrchestration` |

## Reason

The grouped routes already carry:

- proof versus identity
- `NIP-03` versus `NIP-39`
- verify client versus lower workflow floors

The older client-facing names kept restating too much of that route in every planning type and
method name. This cleanup keeps the grouped routes stable and shortens the remaining names to the
role that matters at the client layer.
