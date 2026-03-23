---
title: Proof, Identity, And NIP-05 Planning Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_proof_identity_nip05_planning_imports
---

# Proof, Identity, And NIP-05 Planning Migration

This is the current pre-`1.0` breaking cleanup for the client-facing and workflow-facing planning
families in:

- `noztr_sdk.client.proof.nip03.*`
- `noztr_sdk.client.identity.nip39.*`
- `noztr_sdk.client.identity.nip05.*`
- `noztr_sdk.workflows.proof.nip03.*`
- `noztr_sdk.workflows.identity.verify.*`
- `noztr_sdk.workflows.identity.nip05.*`

The grouped routes stayed the same. The cleanup is inside those routes:

- replace flat alias walls with nested planning groups
- keep the route carrying the domain context
- keep the remaining local names role-focused

## Canonical Planning Routes

Use these grouped planning routes directly:

```zig
const proof = noztr_sdk.client.proof.nip03;
const ProofPlanning = proof.Planning;

const identity = noztr_sdk.client.identity.nip39;
const IdentityPlanning = identity.Planning;

const nip05 = noztr_sdk.client.identity.nip05;
const Nip05Planning = nip05.Planning;
```

Workflow-floor grouped planning routes are the same shape:

```zig
const proof = noztr_sdk.workflows.proof.nip03;
const ProofPlanning = proof.Planning;

const identity = noztr_sdk.workflows.identity.verify;
const IdentityPlanning = identity.Planning;

const nip05 = noztr_sdk.workflows.identity.nip05;
const Nip05Planning = nip05.Planning;
```

## `NIP-03` Planning Shape

Old flat names like:

- `Planning.LatestTargetRequest`
- `Planning.PreferredTargetEntry`
- `Planning.TargetReadinessRequest`
- `Planning.TargetCadencePlan`
- `Planning.TargetTurnPolicyPlan`

now live under grouped families:

- `Planning.Stored.*`
- `Planning.Latest.*`
- `Planning.Preferred.*`
- `Planning.Runtime.*`
- `Planning.Refresh.*`
- `Planning.TargetRefresh.*`
- `Planning.Readiness.*`
- `Planning.Policy.*`
- `Planning.Cadence.*`
- `Planning.Batch.*`
- `Planning.Turn.*`

Examples:

- `Planning.LatestTargetRequest` -> `Planning.Latest.Request`
- `Planning.PreferredTargetEntry` -> `Planning.Preferred.Entry`
- `Planning.TargetReadinessPlan` -> `Planning.Readiness.Plan`
- `Planning.TargetCadenceStorage` -> `Planning.Cadence.Storage`
- `Planning.TargetTurnPolicyRequest` -> `Planning.Turn.Request`

## `NIP-39` Planning Shape

Old flat names like:

- `Planning.TargetDiscoveryRequest`
- `Planning.StoredProfileDiscoveryFreshnessEntry`
- `Planning.TargetLatestRequest`
- `Planning.PreferredTargetSelectionRequest`
- `Planning.RememberedCadencePlan`
- `Planning.WatchedOrchestrationPlan`

now live under grouped families:

- `Planning.Match`
- `Planning.Record.*`
- `Planning.Stored.*`
- `Planning.Target`
- `Planning.Discovery.*`
- `Planning.DiscoveryFresh.*`
- `Planning.Latest.*`
- `Planning.Preferred.*`
- `Planning.Refresh.*`
- `Planning.Runtime.*`
- `Planning.Policy.*`
- `Planning.Cadence.*`
- `Planning.Batch.*`
- `Planning.Turn.*`
- `Planning.Remembered.*`
- `Planning.Watched.*`

Examples:

- `Planning.TargetDiscoveryRequest` -> `Planning.Discovery.Request`
- `Planning.StoredProfileDiscoveryFreshnessEntry` -> `Planning.Stored.FreshEntry`
- `Planning.TargetLatestRequest` -> `Planning.Latest.Request`
- `Planning.PreferredTargetSelectionRequest` -> `Planning.Preferred.EntriesRequest`
- `Planning.RememberedCadencePlan` -> `Planning.Remembered.Cadence.Plan`
- `Planning.WatchedOrchestrationPlan` -> `Planning.Watched.Orchestration.Plan`

## `NIP-05` Planning Shape

The old one-off client-side `Nip05RememberedResolutionPlanning` facade is gone.

Use:

- `noztr_sdk.client.identity.nip05.Planning`
- `noztr_sdk.workflows.identity.nip05.Planning`

The grouped family is now:

- `Planning.Store.*`
- `Planning.Target`
- `Planning.Latest.*`
- `Planning.Refresh.*`

Examples:

- `Nip05RememberedResolutionPlanning.StorePutOutcome` -> `Planning.Store.PutOutcome`
- `Nip05RememberedResolutionPlanning.Record` -> `Planning.Store.Record`
- `Nip05RememberedResolutionPlanning.LatestTargetRequest` -> `Planning.Latest.Request`
- `Nip05RememberedResolutionPlanning.RefreshPlan` -> `Planning.Refresh.Plan`

## `NIP-05` Method Renames

The resolver/client route already carries the NIP-05 remembered-resolution context, so the longer
method names were shortened too:

- `inspectLatestRememberedResolutionFreshnessForTargets` -> `inspectLatestForTargets`
- `planRememberedResolutionRefreshForTargets` -> `planRefreshForTargets`

This applies to both:

- `noztr_sdk.workflows.identity.nip05.Nip05Resolver`
- `noztr_sdk.client.identity.nip05.Nip05VerifyClient`

## Reason

The grouped routes already carry:

- proof versus identity
- `NIP-03` versus `NIP-39` versus `NIP-05`
- client versus workflow floor

The old shape kept restating too much of that context in every request, plan, storage, and entry
name. This cleanup keeps the grouped routes stable and moves the remaining names toward the
shortest sensible role-based shape inside each route.
