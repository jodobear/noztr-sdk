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

The workflow/facade route stayed `noztr_sdk.workflows|client.proof.nip03.Planning`; the
`Planning` members were regrouped to reduce top-level clutter:

The old flat workflow-floor planning aliases are no longer part of the public surface. Use the
grouped `Planning.Stored.*` and `Planning.Target.*` routes directly.

```zig
pub const Planning = struct {
    pub const Stored = struct {
        pub const Match = ...;
        pub const Entry = ...;
        pub const Freshness = ...;
        pub const FallbackPolicy = ...;
        pub const Fresh = struct { ... };
        pub const Latest = struct { ... };
        pub const Runtime = struct { ... };
        pub const Refresh = struct { ... };
    };

    pub const Target = struct {
        pub const Value = ...;
        pub const Latest = struct { ... };
        pub const Preferred = struct { ... };
        pub const Refresh = struct { ... };
        pub const Readiness = struct { ... };
        pub const Policy = struct { ... };
        pub const Cadence = struct { ... };
        pub const Batch = struct { ... };
        pub const Turn = struct { ... };
    };
};
```

Specific flattening moves:

- `Planning.LatestFreshnessRequest` -> `Planning.Stored.Latest.Request`
- `Planning.LatestFreshness` -> `Planning.Stored.Latest.Value`
- `Planning.StoredFreshnessEntry` -> `Planning.Stored.Fresh.Entry`
- `Planning.StoredFreshnessStorage` -> `Planning.Stored.Fresh.Storage`
- `Planning.StoredFreshnessRequest` -> `Planning.Stored.Fresh.Request`
- `Planning.RuntimeAction` -> `Planning.Stored.Runtime.Action`
- `Planning.RuntimePlan` -> `Planning.Stored.Runtime.Plan`
- `Planning.RuntimeStep` -> `Planning.Stored.Runtime.Step`
- `Planning.RuntimeStorage` -> `Planning.Stored.Runtime.Storage`
- `Planning.RuntimeRequest` -> `Planning.Stored.Runtime.Request`
- `Planning.RefreshEntry` -> `Planning.Stored.Refresh.Entry`
- `Planning.RefreshStorage` -> `Planning.Stored.Refresh.Storage`
- `Planning.RefreshRequest` -> `Planning.Stored.Refresh.Request`
- `Planning.RefreshPlan` -> `Planning.Stored.Refresh.Plan`
- `Planning.RefreshStep` -> `Planning.Stored.Refresh.Step`
- `Planning.LatestTargetRequest` -> `Planning.Target.Latest.Request`
- `Planning.PreferredTargetRequest` -> `Planning.Target.Preferred.Request`
- `Planning.PreferredTargetValue` -> `Planning.Target.Preferred.Value`
- `Planning.PreferredTargetEntry` -> `Planning.Target.Preferred.Entry`
- `Planning.PreferredTargetStorage` -> `Planning.Target.Preferred.Storage`
- `Planning.PreferredTargetsRequest` -> `Planning.Target.Preferred.EntriesRequest`
- `Planning.TargetRefreshEntry` -> `Planning.Target.Refresh.Entry`
- `Planning.TargetRefreshStorage` -> `Planning.Target.Refresh.Storage`
- `Planning.TargetRefreshRequest` -> `Planning.Target.Refresh.Request`
- `Planning.TargetRefreshPlan` -> `Planning.Target.Refresh.Plan`
- `Planning.TargetRefreshStep` -> `Planning.Target.Refresh.Step`
- `Planning.TargetReadinessAction` -> `Planning.Target.Readiness.Action`
- `Planning.TargetReadinessEntry` -> `Planning.Target.Readiness.Entry`
- `Planning.TargetReadinessGroup` -> `Planning.Target.Readiness.Group`
- `Planning.TargetReadinessStorage` -> `Planning.Target.Readiness.Storage`
- `Planning.TargetReadinessRequest` -> `Planning.Target.Readiness.Request`
- `Planning.TargetReadinessPlan` -> `Planning.Target.Readiness.Plan`
- `Planning.TargetReadinessStep` -> `Planning.Target.Readiness.Step`
- `Planning.TargetPolicyEntry` -> `Planning.Target.Policy.Entry`
- `Planning.TargetPolicyGroup` -> `Planning.Target.Policy.Group`
- `Planning.TargetPolicyStorage` -> `Planning.Target.Policy.Storage`
- `Planning.TargetPolicyRequest` -> `Planning.Target.Policy.Request`
- `Planning.TargetPolicyPlan` -> `Planning.Target.Policy.Plan`
- `Planning.TargetCadenceAction` -> `Planning.Target.Cadence.Action`
- `Planning.TargetCadenceEntry` -> `Planning.Target.Cadence.Entry`
- `Planning.TargetCadenceGroup` -> `Planning.Target.Cadence.Group`
- `Planning.TargetCadenceStorage` -> `Planning.Target.Cadence.Storage`
- `Planning.TargetCadenceRequest` -> `Planning.Target.Cadence.Request`
- `Planning.TargetCadencePlan` -> `Planning.Target.Cadence.Plan`
- `Planning.TargetCadenceStep` -> `Planning.Target.Cadence.Step`
- `Planning.TargetBatchStorage` -> `Planning.Target.Batch.Storage`
- `Planning.TargetBatchRequest` -> `Planning.Target.Batch.Request`
- `Planning.TargetBatchPlan` -> `Planning.Target.Batch.Plan`
- `Planning.TargetBatchStep` -> `Planning.Target.Batch.Step`
- `Planning.TargetTurnPolicyAction` -> `Planning.Target.Turn.Action`
- `Planning.TargetTurnPolicyEntry` -> `Planning.Target.Turn.Entry`
- `Planning.TargetTurnPolicyGroup` -> `Planning.Target.Turn.Group`
- `Planning.TargetTurnPolicyStorage` -> `Planning.Target.Turn.Storage`
- `Planning.TargetTurnPolicyRequest` -> `Planning.Target.Turn.Request`
- `Planning.TargetTurnPolicyPlan` -> `Planning.Target.Turn.Plan`
- `Planning.TargetTurnPolicyStep` -> `Planning.Target.Turn.Step`
- `Planning.Stored` remains as the role-focused bucket above.
- `Planning.Target` now resolves target-domain planning families only, and there is no legacy top-level target planning namespace.
- flat workflow-floor proof planning aliases like `OpenTimestampsStoredVerificationRuntimePlan`,
  `OpenTimestampsStoredVerificationTargetRefreshRequest`, and
  `OpenTimestampsStoredVerificationTargetTurnPolicyPlan` are removed in favor of the grouped
  `Planning.*` route

## `NIP-39` Planning Shape

Old flat names now resolve under grouped buckets:

- `Planning.Stored`
- `Planning.Target`
- `Planning.Remembered`
- `Planning.Watched`

In this route the `Planning.Stored` and `Planning.Target` families are:

```zig
pub const Planning = struct {
    pub const Stored = struct {
        pub const Entry = ...;
        pub const Freshness = ...;
        pub const FallbackPolicy = ...;
        pub const Discovery = struct {
            pub const Entry = ...;
            pub const Storage = ...;
            pub const Request = ...;
        };
        pub const Latest = struct {
            pub const Request = ...;
            pub const Value = ...;
        };
        pub const Preferred = struct {
            pub const Request = ...;
            pub const Value = ...;
        };
        pub const Fresh = struct {
            pub const Entry = ...;
            pub const Storage = ...;
            pub const Request = ...;
        };
        pub const Runtime = struct { ... };
        pub const Refresh = struct { ... };
    };

    pub const Target = struct {
        pub const Value = ...;
        pub const Discovery = struct { ... };
        pub const Fresh = struct { ... };
        pub const Latest = struct {
            pub const Entry = ...;
            pub const Storage = ...;
            pub const Request = ...;
            pub const Plan = ...;
            pub const Step = ...;
        };
        pub const Preferred = struct { ... };
        pub const Refresh = struct { ... };
        pub const Runtime = struct { ... };
        pub const Policy = struct { ... };
        pub const Cadence = struct { ... };
        pub const Batch = struct { ... };
        pub const Turn = struct { ... };
    };
};
```

Examples:

- `Planning.TargetDiscoveryRequest` -> `Planning.Target.Discovery.Request`
- `Planning.StoredProfileDiscoveryEntry` -> `Planning.Stored.Discovery.Entry`
- `Planning.StoredProfileDiscoveryStorage` -> `Planning.Stored.Discovery.Storage`
- `Planning.StoredProfileDiscoveryRequest` -> `Planning.Stored.Discovery.Request`
- `Planning.LatestFreshnessRequest` -> `Planning.Stored.Latest.Request`
- `Planning.LatestFreshness` -> `Planning.Stored.Latest.Value`
- `Planning.PreferredStoredProfileRequest` -> `Planning.Stored.Preferred.Request`
- `Planning.PreferredStoredProfileValue` -> `Planning.Stored.Preferred.Value`
- `Planning.StoredProfileDiscoveryFreshnessEntry` -> `Planning.Stored.Fresh.Entry`
- `Planning.StoredProfileDiscoveryFreshnessStorage` -> `Planning.Stored.Fresh.Storage`
- `Planning.StoredProfileDiscoveryFreshnessRequest` -> `Planning.Stored.Fresh.Request`
- `Planning.TargetLatestRequest` -> `Planning.Target.Latest.Request`
- `Planning.TargetLatestStep` -> `Planning.Target.Latest.Step`
- `Planning.PreferredTargetSelectionRequest` -> `Planning.Target.Preferred.EntriesRequest`
- `Planning.PreferredTargetValue` -> `Planning.Target.Preferred.Value`
- `Planning.RememberedCadencePlan` -> `Planning.Remembered.Cadence.Plan`
- `Planning.WatchedOrchestrationPlan` -> `Planning.Watched.Runtime.Plan`


## `NIP-39` Follow-On Cleanup

The later route-local cleanup shortened two surviving grouped subfamilies:

- `Planning.Remembered.Latest.*` -> `Planning.Remembered.Freshness.*`
- `Planning.Watched.Orchestration.*` -> `Planning.Watched.Runtime.*`

That same cleanup also shortened the main client methods:

- `inspectRememberedLatest` -> `inspectRememberedFreshness`
- `inspectWatchedOrchestration` -> `inspectWatchedRuntime`

After the grouped route was made canonical, the remaining flat stored/target workflow-floor names
were also shortened aggressively. If you were still using names like
`IdentityStoredProfileTargetRefreshCadenceStorage`, `IdentityStoredProfileTargetTurnPolicyPlan`, or
`IdentityStoredProfileDiscoveryFreshnessEntry` directly, treat that as legacy usage and move to the
grouped route instead:

- `workflows.identity.verify.Planning.Stored.*`
- `workflows.identity.verify.Planning.Target.*`
- `client.identity.nip39.Planning.*`

That same cleanup now also applies to the remembered and watched planning families. If you were
still using flat names like `IdentityRememberedIdentityRefreshCadenceStorage`,
`IdentityRememberedIdentityRefreshBatchPlan`, `IdentityStoredWatchedTargetRuntimeRequest`, or
`IdentityStoredWatchedTargetTurnPolicyPlan`, treat those as legacy usage too and move to:

- `workflows.identity.verify.Planning.Remembered.*`
- `workflows.identity.verify.Planning.Watched.*`
- `client.identity.nip39.Planning.*`

On the proof side, the stored and remembered verification family also dropped repeated
`OpenTimestamps...` route context where the grouped `workflows.proof.nip03.*` route already carries
it. If you were still using names like `OpenTimestampsStoredVerificationRecord`,
`OpenTimestampsRemoteVerificationOutcome`, or `OpenTimestampsRememberedRemoteVerificationOutcome`,
move to the shorter route-local names instead:

- `workflows.proof.nip03.StoredRecord`
- `workflows.proof.nip03.StoredMatch`
- `workflows.proof.nip03.StoredDiscoveryError`
- `workflows.proof.nip03.RemoteVerification`
- `workflows.proof.nip03.RemoteVerificationOutcome`
- `workflows.proof.nip03.RememberedRemoteVerification`
- `workflows.proof.nip03.RememberedRemoteVerificationOutcome`

## `NIP-05` Planning Shape

The old one-off client-side `Nip05RememberedResolutionPlanning` facade is gone.

The old flat workflow-floor planning aliases are also gone. Use the grouped planning route
directly instead of the former top-level `Nip05RememberedResolution...` type wall.

Use:

- `noztr_sdk.client.identity.nip05.Planning`
- `noztr_sdk.workflows.identity.nip05.Planning`

The grouped family is now:

- `Planning.Store.*`
- `Planning.Target.Value`
- `Planning.Target.Latest.*`
- `Planning.Target.Refresh.*`

Examples:

- `Nip05RememberedResolutionPlanning.StorePutOutcome` -> `Planning.Store.PutOutcome`
- `Nip05RememberedResolutionPlanning.Record` -> `Planning.Store.Record`
- `Nip05RememberedResolutionPlanning.LatestTargetRequest` -> `Planning.Target.Latest.Request`
- `Nip05RememberedResolutionPlanning.RefreshPlan` -> `Planning.Target.Refresh.Plan`
- `Nip05RememberedResolutionStore` -> `Planning.Store.Backend`
- `MemoryNip05RememberedResolutionStore` -> `Planning.Store.Memory`
- `Nip05LatestRememberedResolutionTargetRequest` -> `Planning.Target.Latest.Request`
- `Nip05RememberedResolutionRefreshRequest` -> `Planning.Target.Refresh.Request`

Route shape:

```zig
pub const Planning = struct {
    pub const Store = struct {
        pub const Error = ...;
        pub const PutOutcome = ...;
        pub const Record = ...;
        pub const Backend = ...;
        pub const Memory = ...;
    };

    pub const Target = struct {
        pub const Value = ...;
        pub const Latest = struct {
            pub const Freshness = ...;
            pub const Value = ...;
            pub const Entry = ...;
            pub const Storage = ...;
            pub const Request = ...;
            pub const Plan = ...;
            pub const Step = ...;
        };
        pub const Refresh = struct {
            pub const Action = ...;
            pub const Entry = ...;
            pub const Storage = ...;
            pub const Request = ...;
            pub const Plan = ...;
            pub const Step = ...;
        };
    };
};
```

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
