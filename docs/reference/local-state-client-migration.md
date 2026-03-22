---
title: Local State Client Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - updating_pre_1_0_local_state_callers
canonical: true
---

# Local State Client Migration

Pre-`1.0` local archive/workspace route update.

## What Changed

- the new canonical neutral local archive/workspace surface is
  `noztr_sdk.client.LocalStateClient`
- `RelayWorkspaceClientConfig` now uses `.local_state` instead of `.cli_archive`

## Before

```zig
var client = noztr_sdk.client.RelayWorkspaceClient.init(
    .{ .cli_archive = .{ .relay_checkpoint_scope = "tooling" } },
    client_store.asClientStore(),
    relay_info_store.asRelayInfoStore(),
    &storage,
);
```

## After

```zig
var client = noztr_sdk.client.RelayWorkspaceClient.init(
    .{ .local_state = .{ .relay_checkpoint_scope = "tooling" } },
    client_store.asClientStore(),
    relay_info_store.asRelayInfoStore(),
    &storage,
);
```

If you do not specifically need the narrower remembered-relay workspace view, prefer
`noztr_sdk.client.LocalStateClient` as the canonical public route.
