---
title: Social And DM Stored-Read Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_social_dm_stored_read_imports
---

# Social And DM Stored-Read Migration

Pre-`1.0` social and DM stored-read cleanup:

## What Changed

The grouped routes stayed the same:
- `noztr_sdk.client.dm.capability.*`
- `noztr_sdk.client.social.profile_content.*`
- `noztr_sdk.client.social.reaction_list.*`
- `noztr_sdk.client.social.graph_wot.*`

The read-side helper families were renamed away from archive-mechanics wording and toward
task-first names like `Latest...`, `NotePage`, and `latest`.

## DM Capability

- `StoredMailboxRelayListSelectionRequest` -> `LatestMailboxRelayListRequest`
- `StoredMailboxRelayListSelection` -> `LatestMailboxRelayList`
- `StoredMailboxRelayListInspection` -> `LatestMailboxRelayListResult`
- `inspectLatestStoredMailboxRelayList` -> `inspectLatestMailboxRelayList`
- result field `selection` -> `latest`

## Social Profile / Note / Long-Form

- `StoredSocialProfileSelectionRequest` -> `LatestProfileRequest`
- `StoredSocialProfileSelection` -> `LatestProfile`
- `StoredSocialProfileResult` -> `LatestProfileResult`
- `inspectLatestStoredProfile` -> `inspectLatestProfile`
- result field `selection` -> `latest`

- `StoredSocialNotePageRequest` -> `NotePageRequest`
- `StoredSocialNoteRecord` -> `NoteRecord`
- `StoredSocialNotePage` -> `NotePage`
- `inspectStoredNotePage` -> `inspectNotePage`

- `StoredSocialLongFormSelectionRequest` -> `LatestLongFormRequest`
- `StoredSocialLongFormSelection` -> `LatestLongForm`
- `StoredSocialLongFormResult` -> `LatestLongFormResult`
- `inspectLatestStoredLongForm` -> `inspectLatestLongForm`
- result field `selection` -> `latest`

## Social Lists

- `StoredSocialListSelectionRequest` -> `LatestListRequest`
- `StoredSocialListSelection` -> `LatestList`
- `StoredSocialListInspection` -> `LatestListResult`
- `inspectLatestStoredList` -> `inspectLatestList`
- result field `selection` -> `latest`

## Social Contact Graph / Starter WoT

- `StoredSocialContactSelectionRequest` -> `LatestContactListRequest`
- `StoredSocialContactSelection` -> `LatestContactList`
- `StoredSocialContactInspection` -> `LatestContactListResult`
- `inspectLatestStoredContacts` -> `inspectLatestContactList`
- starter-WoT root payload now uses `LatestContactList`
- result field `selection` -> `latest`

## Before

```zig
const stored = try client.inspectLatestStoredMailboxRelayList(
    archive,
    &.{ .author = author_hex, .limit = 1 },
    &page,
    relay_urls[0..],
    arena.allocator(),
);
try std.testing.expect(stored.selection != null);
```

## After

```zig
const stored = try client.inspectLatestMailboxRelayList(
    archive,
    &.{ .author = author_hex, .limit = 1 },
    &page,
    relay_urls[0..],
    arena.allocator(),
);
try std.testing.expect(stored.latest != null);
```

## Reason

These helpers are read-side convenience routes, not archive-internals. The older names kept
teaching `stored`, `selection`, and `inspection` mechanics. This cleanup makes the public nouns
describe what the caller is actually asking for:
- latest mailbox relay list
- latest profile
- note page
- latest long-form entry
- latest list
- latest contact list
