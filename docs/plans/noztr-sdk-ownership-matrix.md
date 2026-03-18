---
title: noztr vs SDK Ownership Matrix
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - boundary_decisions
  - deciding_kernel_vs_sdk_placement
---

# noztr vs SDK Ownership Matrix

Canonical boundary guide for deciding what belongs in the `noztr` protocol kernel versus the
future higher-level SDK.

## Purpose

Use this matrix when:
- reviewing NIP scope in `noztr`
- deciding whether a proposed helper belongs in Layer 1
- planning SDK responsibilities
- challenging older scope decisions that may have been too narrow or too broad

This is not a replacement for the decision log. The decision log remains the canonical source for
accepted defaults and reversals. This matrix is the operational map that keeps `noztr` and the SDK
from drifting into each other.

## Boundary Rule

Put behavior in `noztr` only when it is all of:
- protocol-facing
- pure and deterministic
- bounded and static-capacity
- reusable across many callers
- directly about parse, validate, serialize, verify, or fixed-capacity reduction

Put behavior in the SDK when it involves any of:
- network fetches or relay orchestration
- session lifecycle or connection management
- redirect, launch, or UI handoff policy
- provider-specific availability, retries, or rate limits
- local stores, caches, or sync policy
- app-flow convenience that is not protocol-kernel reuse

## Implemented NIP Ownership Matrix

| NIP | `noztr` owns | SDK owns | SDK starter point | Current posture |
| --- | --- | --- | --- | --- |
| `01` events / filters / messages | strict event, filter, and client/relay message parse/validate/serialize helpers | publish / subscribe workflows, relay connection state, stream orchestration | high-level event builder presets plus REQ/COUNT/EOSE subscription helpers | kernel scope is correct |
| `02` contacts | bounded contact-tag extraction and contact builders | contact sync, graph views, follow recommendations, petname UX | contact-list sync plus social-graph cache | kernel scope is correct |
| `03` OpenTimestamps | event parsing, bounded proof decode, bounded local proof verification floor | networked OTS/Bitcoin verification, caching, remote proof retrieval | opt-in verifier adapters over caller-supplied HTTP / Bitcoin clients | local proof floor belongs in `noztr`; networked verification belongs in SDK |
| `05` internet identifiers | bounded address parse/validate, canonical lookup URL composition, raw `nostr.json` verify/parse for `names` plus optional `relays` / `nip46` | HTTP fetch, redirect handling, caching, trust UX | NIP-05 fetch/cache/verify flow over kernel address and document helpers | kernel scope is correct |
| `06` mnemonic / derivation | mnemonic validate, seed derivation, canonical key derivation, zeroization, typed errors | wallet UX, account selection, secret storage, import/export flows | wallet/account manager over kernel derivation helpers | current split is correct; full NFKD remains a future kernel follow-up |
| `09` deletions | delete-target extraction and checked wrappers | delete publish flows, local tombstone policy, UI confirmation | deletion compose / publish helpers and tombstone cache policy | kernel scope is correct |
| `10` threads | bounded root / reply / mention extraction | thread assembly, timeline stitching, reply composition UX | thread graph builder over extracted references | kernel scope is correct |
| `11` relay info | bounded relay-info subset parsing | relay fetch, cache, policy scoring, capability negotiation | relay-info fetch/cache layer with refresh policy | current split is correct |
| `13` PoW | checked difficulty helpers and verified-id wrapper | mining loops, publish retry policy, target selection UX | cancellable mining job wrapper using kernel checks | kernel scope is correct |
| `17` private messages | bounded kind-`14` / `15` parse, relay-list helpers, gift-wrap unwrap reuse | mailbox sync, attachment transfer flow, inbox policy, send orchestration | private-message session and mailbox pipeline | current split is correct |
| `18` reposts | bounded repost target extraction / builders | repost compose UX and publish flow | repost composer over event / coordinate pickers | kernel scope is correct |
| `19` bech32 | encode / decode helpers for Nostr entities | clipboard/share helpers, resolver UX | human-facing encode / decode helpers for apps and CLIs | kernel scope is correct |
| `21` URIs | strict `nostr:` URI parse / compose | deep-link routing, launch handling, app dispatch | URI router that resolves actions from parsed entities | kernel scope is correct |
| `22` comments | bounded comment target / linkage extraction | comment tree assembly, fetch strategy, compose workflows | comment-thread builder over extracted comment info | strict kernel scope remains intentional |
| `23` long-form | bounded metadata extraction / builders for article events | draft UX, publish workflow, editor integration | article draft/publish helper using kernel metadata tags | kernel scope is correct |
| `24` extra metadata | bounded profile metadata extras and generic tag helpers | profile editing UX, richer app-specific metadata handling | profile editor / profile sync layer using kernel metadata helpers | `i` support is correctly routed through `NIP-73` |
| `25` reactions | bounded reaction target extraction / builders | reaction compose/send UX, emoji registry / picker policy | reaction send helper using target resolution from SDK context | kernel scope is correct |
| `26` delegation | exact delegation-tag parse/build, condition parse/format, exact message construction, deterministic sign/verify, and pure event-condition validation | delegator key custody, delegation issuance UX, relay filtering, publish policy | delegation-issuance flow and author-query helpers over kernel conditions/signatures | kernel scope is correct |
| `27` references | inline `nostr:` reference extraction with spans | rich-text rendering, editor highlighting, click/open policy | rich-text tokenizer / renderer bridge | kernel scope is correct |
| `29` relay groups | relay-generated event helpers, raw references, user-event helpers, pure fixed-capacity state reduction | relay subscriptions, sync/store, authority policy, moderation workflows, full group client engine | group-sync and state-store layer over kernel reducer and parsers | pure reducer belongs in `noztr`; orchestration belongs in SDK |
| `32` labeling | bounded label/self-label extraction, namespace handling, exact target matching, and direct builders | label-management UX, moderation workflow, sync/store | label-manager and moderation adapter over kernel targets and namespace helpers | kernel scope is correct |
| `36` content warning | exact `content-warning` parse/build plus accepted NIP-32 namespace bridge | moderation/rendering policy, publish UX | moderation label and render-policy adapter over kernel tags | kernel scope is correct |
| `37` drafts | exact draft-wrap metadata parse/build, validated NIP-44 draft encrypt/decrypt, and bounded private relay-list JSON/decrypt helpers | draft sync, editor workflow, local storage, publish/delete workflow | draft-store and editor-sync layer over kernel wrap and relay-list helpers | kernel scope is correct |
| `39` external identities | claim extraction, canonical tag building, proof URL derivation, expected proof text | live provider verification, trust policy, retries, provider adapters | provider verifier adapters and identity-sync flows | live verification belongs in SDK |
| `40` expiration | expiration extraction and checked expiration helpers | scheduler / retention policy, client-side expiry filtering | event-retention policy layer using kernel expiration checks | kernel scope is correct |
| `42` auth | auth challenge parsing / compose helpers and boundary checks | relay-auth handshake state machine, retry / session policy | auth handshake manager over relay connections | kernel scope is correct |
| `44` crypto | conversation-key derivation, payload encrypt/decrypt, checked cryptographic boundaries | secret/session storage, conversation caches, key-distribution workflows | conversation crypto service using kernel v2 primitives | current split is correct |
| `45` count | bounded COUNT response parsing and HLL helpers | COUNT request orchestration, relay fanout, result aggregation | count-query orchestration layer | kernel scope is correct |
| `46` remote signing | method / permission / request / result helpers, URI handling, discovery parsing, exact template substitution, envelope validation | relay pool control, signer session lifecycle, auth flows, launching / redirect policy, connection orchestration | remote-signer client/session manager | deterministic protocol glue belongs in `noztr`; client flow belongs in SDK |
| `50` search | bounded search parse / extension extraction | query-building UX, search flow, result handling | search-query builder and relay search orchestration | kernel scope is correct |
| `51` lists | bounded public/private list parse/build helpers | list-management UX, sync/store, merge conflict policy, higher-level list semantics | list manager with sync / storage / merge policy | current split is correct |
| `56` reporting | bounded report extraction/building, typed report enums, and direct server-tag handling | reporting UX, moderation submission flow, relay-specific policy | reporting flow over kernel targets and report types | kernel scope is correct |
| `57` zaps | bounded zap request / receipt parse, build, and validation helpers | LNURL fetch, callback handling, invoice/payment flow, wallet orchestration | zap/LNURL payment pipeline over kernel request and receipt helpers | deterministic zap contracts belong in `noztr`; LNURL/payment flow belongs in SDK |
| `58` badges | bounded badge definition / award / profile-badge parse, build, and consistency helpers | badge sync, ordering policy, profile presentation, badge UX | badge-sync and profile-presentation layer over kernel badge helpers | kernel scope is correct |
| `59` gift wrap | wrap / seal / rumor boundaries and checked unwrap helpers | mailbox workflow, delivery orchestration, session handling | mailbox pipeline over kernel wrap / unwrap helpers | current split is correct |
| `65` relay metadata | bounded relay-list extraction and builders | relay preference store, routing policy, failover heuristics | relay-preference manager and router hints | kernel scope is correct |
| `70` protected events | exact protected-tag semantics and checked helpers | publish policy and protected-event UX | protected-event publish helper with policy toggles | kernel scope is correct |
| `73` external ids | bounded external-id parse/build/validate/match helpers | provider presets, richer external-id workflows, UX affordances | shared provider preset / resolver layer for external IDs | implemented and reused by `NIP-24` and `NIP-22` |
| `77` negentropy | bounded NEG-OPEN / MSG / CLOSE / ERR parsing and session helpers | full sync engine, transport scheduling, retry/session policy | negentropy sync driver over kernel message/state helpers | kernel scope is correct |
| `84` highlights | bounded highlight source / attribution / comment / context parse-build helpers | reader UX, render policy, article integration, publish flow | highlight-reader and compose layer over kernel source helpers | kernel scope is correct |
| `86` relay management | bounded relay-management request / response parse-build helpers | NIP-98 auth, HTTP transport, admin sessions, operator workflow | relay-operator client over kernel RPC helpers | deterministic RPC payloads belong in `noztr`; admin flow belongs in SDK |

## Review Questions

When a scope question comes up, answer these in order:
1. Is the behavior explicitly protocol-facing, or is it workflow around the protocol?
2. Can it be pure, deterministic, and fixed-capacity?
3. Would multiple SDK/app surfaces need the same logic?
4. Does putting it in `noztr` improve correctness or interoperability materially?
5. Would putting it in `noztr` pull in network, storage, UI, or policy concerns?

If the answer to `5` is yes, the behavior probably belongs in the SDK.

## Noztr SDK Starter Priorities

- Start the SDK with the orchestration-heavy surfaces already intentionally left out of `noztr`:
  `NIP-46`, `NIP-39`, `NIP-29`, `NIP-17`, `NIP-03`, `NIP-11`, and `NIP-65`.
- Treat `NIP-44`, `NIP-59`, and `NIP-06` as foundational SDK dependencies rather than as the first
  UX-facing modules.
- Reuse `NIP-73` as the shared starter for any SDK support involving external identifiers or
  provider-specific presets.
- Keep SDK starter work honest: if a proposed helper stays pure, deterministic, bounded, and widely
  reusable, reconsider whether it should live in `noztr` instead.

## Borderline Accepted Kernel Helpers

- `NIP-39`
  - `identity_claim_build_proof_url(...)`
  - `identity_claim_build_expected_text(...)`
  - Current call: keep them in `noztr` for now as deterministic helper glue, but revisit when the
    SDK grows provider adapters because they are the clearest currently implemented
    provider-shaped helpers.
- `NIP-46`
  - `discovery_render_nostrconnect_url(...)`
  - Current call: keep it in `noztr` as exact protocol-facing placeholder substitution, not client
    orchestration; revisit only if SDK-side redirect/launch handling makes the helper redundant.

## Requested Next-NIP Mapping

| NIP | Recommended placement | `noztr` slice | `noztr-sdk` slice | Recommended order |
| --- | --- | --- | --- | --- |
| `05` | split | identifier validation plus `/.well-known/nostr.json` parse/build helpers | HTTP fetch, cache, trust policy, verification UX | medium |
| `07` | `noztr-sdk` | none | browser / signer adapter over `window.nostr` | sdk-only |
| `26` | `noztr` | delegation tag parse / build / verify helpers | compose UX and signer workflow | high |
| `32` | `noztr` | label / content-tag parse / build / validate helpers | higher-level label-management UX | highest |
| `36` | `noztr` | content-warning tag/event helpers on top of NIP-32 | moderation / rendering policy | highest |
| `37` | `noztr` | draft event parse / build / encrypt / decrypt helpers | draft sync, storage, editor workflow | high |
| `56` | `noztr` | report event parse / build / validate helpers | reporting UX, relay submission workflow | highest |
| `57` | split | zap request / receipt parse / build / validate helpers | LNURL fetch, invoice/payment flow, wallet orchestration | medium |
| `58` | `noztr` | badge definition / award / profile-badge parse / build helpers | badge UX, profile presentation, sync | medium |
| `60` | `noztr-sdk` first | optional later offline validation helpers only | wallet state, mint interaction, spend / redeem workflow | sdk-first |
| `61` | `noztr-sdk` first | optional later offline validation helpers only | Nutzap wallet / payment workflow | sdk-first |
| `84` | `noztr` | highlight event/tag parse / build helpers | article-reader UX and highlight workflows | medium |
| `86` | split | relay-management RPC parse / build / validate helpers | admin auth, request orchestration, relay operator client flow | medium |
| `B7` | `noztr-sdk` first | at most later bounded event/tag helpers if needed | Blossom upload/download/service integration | sdk-first |

## Recommended Next Sequence

- Kernel-first: `32`, `36`, `56`, `05`, `26`, `37`, `58`, `84`
- Split later: `57`, `86`
- SDK-first: `07`, `60`, `61`, `B7`
