---
title: Research Refresh 2026-03-14
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - refreshing_reference_inputs
  - checking_applesauce_and_rust_nostr_provenance
---

# Research Refresh 2026-03-14

Research refresh summary for `noztr-sdk` planning.

Date: 2026-03-14

## Purpose

Record the first post-bootstrap refresh of the local applesauce and rust-nostr reference mirrors and
capture whether that upstream movement changes `noztr-sdk`'s current planning baseline.

## Provenance

### Applesauce

- local mirror path: `/workspace/pkgs/nostr/applesauce`
- origin URL: `git@github.com:hzrd149/applesauce.git`
- checked-out local `HEAD`: `5f152fc98e5baa97e8176e54ce9b9345976c8b32`
- fetched upstream `origin/master`: `c4637f300a2c88e48de87972f6e7e324836faf7d`
- non-merge delta summary from pinned snapshot:
  - `35edf69f` `feat: support address in emoji tags`
  - `f19d0de3` `feat: use AddressPointer instead of string for emoji set address`
  - `9183c310` `fix: test`
  - `b75703f2` `add changeset`

### Rust Nostr

- local mirror path: `/workspace/pkgs/nostr/rust-nostr/nostr`
- origin URL: `git@github.com:rust-nostr/nostr.git`
- checked-out local `HEAD`: `9bcc6cd779a7c6eb41509b37aee4575fa5ae47b9`
- fetched upstream `origin/master`: `493b230aa7308fba416989ae63625da4132cf496`
- non-merge delta summary from pinned snapshot:
  - `49e91eda` `relay-builder: add convenience constructors for LocalRelayBuilderNip42`
  - `086e444b` `build(deps): bump flume from 0.11.1 to 0.12.0`
  - `ac7044ff` `build(deps): bump webbrowser from 1.0.6 to 1.1.0`
  - `9f4c6498` `build(deps): bump tempfile from 3.24.0 to 3.26.0`
  - `98f3e1f8` `nostr: add support for nevent parsing in EventId::from_bech32`
  - `aacaa8b3` `Bump edition from 2021 to 2024`
  - `3df940bd` `nostr: bump deps in embedded example`

## Scoped Delta Review

### Applesauce

Observed architecture impact:
- no meaningful shift in relay/store/session layering since the March 4 snapshot
- current upstream movement is narrow and mostly content/emoji-address handling in core helpers
- no new evidence that `noztr-sdk` should move away from a thin client facade over separate relay/store/
  policy layers

Planning impact:
- none to milestone order
- none to `noztr` / `noztr-sdk` boundary
- continue treating applesauce primarily as an ergonomics and layering reference

### Rust Nostr

Observed architecture impact:
- the workspace still follows the same layered pattern: protocol crate, signer crates, database/
  gossip crates, then SDK facade
- current upstream movement is broader than applesauce but still does not materially change the SDK
  architecture lessons relevant to `noztr-sdk`
- the most relevant protocol-facing delta for `noztr-sdk` planning is `nevent` support in
  `EventId::from_bech32`, which reinforces that protocol parse evolution remains a kernel concern

Planning impact:
- none to milestone order
- none to the decision to keep `NIP-19`/`NIP-46` protocol handling in `noztr`
- continue treating rust-nostr as a secondary ecosystem/reference input with a thin client facade
  over deeper pool/policy layers

## Accepted Conclusion

The March 14, 2026 refresh does not currently require a change to the `noztr-sdk` phase order:

1. planning refresh
2. scaffold and local `noztr` integration
3. relay/session substrate
4. `NIP-46` remote signer session

The refresh strengthens, rather than weakens, the current baseline:
- keep the client facade thin
- keep relay/store/policy/sync concerns split
- keep protocol evolution in `noztr`

## Open Question

- whether the local mirror checkouts should be fast-forwarded to the fetched upstream heads during a
  later maintenance pass, or whether retaining the older checked-out commits while researching
  against fetched refs remains the preferred posture
