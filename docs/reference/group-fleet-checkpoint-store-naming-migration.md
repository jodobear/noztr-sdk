---
title: Group Fleet Checkpoint-Store Naming Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_group_fleet
canonical: false
---

# Group Fleet Checkpoint-Store Naming Migration

`workflows.groups.fleet.*` shortened the checkpoint-store substrate to route-local nouns.

Main renames:

- `GroupFleetCheckpointStorePutOutcome` -> `CheckpointPutOutcome`
- `GroupFleetCheckpointStoreError` -> `CheckpointStoreError`
- `GroupFleetCheckpointRecord` -> `CheckpointRecord`
- `GroupFleetCheckpointStoreVTable` -> `CheckpointStoreVTable`
- `GroupFleetCheckpointStore` -> `CheckpointStore`
- `MemoryGroupFleetCheckpointStore` -> `MemoryCheckpointStore`

Example:

```zig
- var records: [2]noztr_sdk.workflows.groups.fleet.GroupFleetCheckpointRecord = ...
- var store = noztr_sdk.workflows.groups.fleet.MemoryGroupFleetCheckpointStore.init(records[0..]);
+ var records: [2]noztr_sdk.workflows.groups.fleet.CheckpointRecord = ...
+ var store = noztr_sdk.workflows.groups.fleet.MemoryCheckpointStore.init(records[0..]);
```
