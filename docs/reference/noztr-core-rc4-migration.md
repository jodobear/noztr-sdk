---
title: Noztr Core RC4 Migration
description: Short pre-1.0 migration note for noztr-sdk changes caused by the cumulative post-rc.3 noztr-core public-surface cleanup.
---

# Noztr Core RC4 Migration

`noztr-sdk` now tracks the cumulative post-`rc.3` `noztr-core` cleanup documented in
`../noztr-core/docs/guides/migrating-from-0.1.0-rc.3.md`.

This is still pre-`1.0`, so shorter route-local names are preferred over keeping the older
ceremonial names alive.

## Main Changes

- `BuiltTag` -> `TagBuilder`
- `BuiltFileMetadataTag` -> `FileTagBuilder`
- `BuiltRequest` -> `RequestBuilder`
- `DmReplyRef` -> `ReplyRef`
- `DmMessageInfo` -> `Message`
- `FileMessageInfo` -> `FileMessage`
- `MessageInfo` -> `Message`
- `ThreadReference` -> `Reference`
- `ThreadInfo` -> `Thread`
- `ListInfo` -> `List`
- `GroupReference` -> `Reference`
- `GroupJoinRequestInfo` -> `JoinRequest`
- `GroupLeaveRequestInfo` -> `LeaveRequest`

## Where This Shows Up In `noztr-sdk`

- DM workflows and clients:
  - `workflows.dm.mailbox.*`
  - `client.dm.capability.*`
  - `client.dm.mailbox.signer_job.*`
  - `client.dm.mixed.*`
- social/content and list routes:
  - `client.social.profile_content.*`
  - `client.social.reaction_list.*`
- group workflows and local relay-group storage:
  - `workflows.groups.session.*`
  - `workflows.groups.client.*`
  - `store.RelayLocalGroupArchive`
- remote signer workflow internals:
  - `workflows.signer.remote.*`

## What To Update Downstream

1. Replace the older `noztr-core` type names with the shorter route-local names above.
2. Refresh any direct SDK references that exposed those old names through grouped routes.
3. Rerun your normal build/test gates.
4. Refresh any local symbol indexes or LLM context that still point at the older names.

This migration is naming cleanup only. It does not change wire formats, ownership, or runtime
behavior.
