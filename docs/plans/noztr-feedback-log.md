---
title: Noztr Feedback Log
doc_type: log
status: active
owner: noztr-sdk
read_when:
  - sharing_kernel_feedback
  - checking_open_cross_repo_items
---

# Noztr Feedback Log

Cross-repo log for `noztr-sdk` findings that should be shared back to the `noztr` lane.

Date: 2026-03-15

Use this log when `noztr-sdk` work uncovers:
- kernel gaps
- example/documentation improvements
- deterministic behavior issues
- public export or type-shape improvements
- test gaps worth fixing in `noztr`

This is not a replacement for `handoff.md`. It is the durable cross-repo issue and improvement log.

## How To Use This Log

For each item, record:
- status: `open`, `shared`, `resolved`, or `wontfix`
- date discovered
- source slice in `noztr-sdk`
- concise problem statement
- why it belongs in `noztr`
- suggested fix or question

If an item is fixed upstream, move it to the historical section with the resolution note.

## Open Items

- none currently

## Historical Items

- 2026-03-18
  - status: `resolved`
  - source slice: public-docs reroute and `noztr` release-surface audit from `noztr-sdk`
  - note: the public release docs had routed group replay through stale `noztr.nip29_groups`
    naming even though the exported root symbol is `noztr.nip29_relay_groups`
  - resolution: resolved by `2e9fe61` `Address nzdk feedback on NIP-17 builders`; the public docs
    routing now uses `noztr.nip29_relay_groups`

- 2026-03-18
  - status: `resolved`
  - source slice: `NIP-17` outbound file-message send broadening in `noztr-sdk`
  - note: `noztr-sdk` had still been staging canonical kind-15 file-message metadata tags locally
    even though those pieces are deterministic kernel behavior
  - resolution: resolved by `2e9fe61` `Address nzdk feedback on NIP-17 builders`; `noztr` now
    exports the exact-fit `nip17_build_file_*_tag` helpers and `noztr-sdk` now uses them for local
    file-message tag staging

- 2026-03-17
  - status: `resolved`
  - source slice: `NIP-17` relay-fanout closeout compatibility check in `noztr-sdk`
  - note: the local `noztr` compatibility lane had regressed in
    `nip46_remote_signing.test.nip46 public uri and builder paths reject overlong caller input with typed errors`
    because `validate_unsigned_event_json(...)` hit a debug assertion on overlong input
  - resolution: resolved by the later `noztr` hardening pass present at local head `ae57fc6`;
    the compatibility rerun is green again

- 2026-03-16
  - status: `resolved`
  - source slice: `NIP-17` outbound mailbox follow-up in `noztr-sdk`
  - note: upstream now exports a bounded public helper for the exact-fit one-recipient outbound
    `NIP-17` / `NIP-59` transcript
  - resolution: resolved by `55aba83` `Add deterministic NIP-59 outbound builder`

- 2026-03-16
  - status: `resolved`
  - source slice: `NIP-17` outbound mailbox and `NIP-29` client/state-authoring refinements in
    `noztr-sdk`
  - note: upstream now exports the bounded signed event-object JSON serialization helper through
    `noztr.nip01_event.event_serialize_json_object(...)`
  - resolution: resolved by `f413f27` `Export signed event JSON serializer`

- 2026-03-15
  - status: `resolved`
  - source slice: audit follow-up during `NIP-46` SDK stabilization
  - note: the `/workspace/projects/noztr/examples` wallet recipe failure was rechecked and is now
    fixed upstream; the examples lane is green again

- 2026-03-15
  - status: `resolved`
  - source slice: `NIP-17` mailbox workflow tests in `noztr-sdk`
  - note: upstream added a canonical signed wrap-build recipe in
    `/workspace/projects/noztr/examples/nip17_wrap_recipe.zig`
  - resolution: resolved by `7fb1804` `Address nzdk kernel feedback on recipes and keys`

- 2026-03-15
  - status: `resolved`
  - source slice: `NIP-03` local verifier tests in `noztr-sdk`
  - note: upstream added a canonical local verification recipe in
    `/workspace/projects/noztr/examples/nip03_verification_recipe.zig`
  - resolution: resolved by `7fb1804` `Address nzdk kernel feedback on recipes and keys`

- 2026-03-15
  - status: `resolved`
  - source slice: `NIP-17` mailbox audit in `noztr-sdk`
  - note: upstream added the public `noztr.nostr_keys` helper surface plus a usage example in
    `/workspace/projects/noztr/examples/nostr_keys_example.zig`
  - resolution: resolved by `7fb1804` `Address nzdk kernel feedback on recipes and keys`

- 2026-03-15
  - status: `resolved`
  - source slice: `NIP-29` group session in `noztr-sdk`
  - note: upstream reducer replay now accepts moderation events carrying bounded `previous` tags
  - resolution: resolved by `79d8050` `Address nzdk feedback on NIP-29 reducer replay`

- 2026-03-15
  - status: `resolved`
  - source slice: `NIP-29` group session planning in `noztr-sdk`
  - note: upstream now includes reducer and adversarial `NIP-29` recipes in
    `/workspace/projects/noztr/examples/nip29_reducer_recipe.zig` and
    `/workspace/projects/noztr/examples/nip29_adversarial_example.zig`
  - resolution: resolved by `79d8050` `Address nzdk feedback on NIP-29 reducer replay`
