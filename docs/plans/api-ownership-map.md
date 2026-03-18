---
title: Noztr SDK API Ownership Map
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - evaluating_new_public_api
  - revisiting_sdk_surface_ownership
depends_on:
  - docs/plans/noztr-sdk-ownership-matrix.md
---

# Noztr SDK API Ownership Map

Starter ownership map for public SDK surfaces above `noztr`.

Date: 2026-03-14

Use this map together with [noztr-sdk-ownership-matrix.md](./noztr-sdk-ownership-matrix.md) when
deciding whether a new helper belongs in `noztr-sdk`.

## Starter SDK Surface Map

Current public posture:
- stable public root surface today:
  - `noztr_sdk.workflows`
  - `noztr_sdk.transport` for the narrow HTTP seam used by current HTTP-backed workflows
- current stable workflow type: `noztr_sdk.workflows.RemoteSignerSession`
- relay and store seams remain internal until a later accepted API freeze

| SDK surface | What it owns | Why not `noztr` | Why not app code | Starter scope |
| --- | --- | --- | --- | --- |
| `relay.directory` | internal `NIP-11` fetch, cache, and capability view seam | requires HTTP, caching, and refresh policy | every app needs the same relay-info fetch path | internal in `M2` |
| `relay.pool` | internal connection/session lifecycle, request correlation, retries, failover | not pure or deterministic | repeated infra below many apps | internal in `M2` |
| `relay.auth` + `relay.session` | internal `NIP-42` handshake sequencing inside a relay session | protocol validator already exists in `noztr`; sequencing does not | reusable across all authenticated relay flows | internal in `M2` |
| `workflows.remote_signer` | `NIP-46` session flow, connection tokens, relay switching, auth challenge handling | `noztr` owns message contracts only | too reusable to leave in every app | `M3` |
| `workflows.mailbox` | `NIP-17` relay discovery, gift-wrap inbox sync, room/message derivation | depends on relays, stores, and sync policy | common private-message workflow | `M4` |
| `workflows.identity_verifier` | `NIP-39` provider fetch and verification policy | provider/network logic is outside kernel scope | many clients need the same proof workflow | `M5` |
| `workflows.opentimestamps_verifier` | `NIP-03` remote proof retrieval and verification orchestration | networked verification is not pure kernel work | reusable verification flow | `M5` |
| `store.traits` | internal cache/store seams for SDK state | stores are policyful and backend-specific | apps should not have to rediscover minimal seams | internal in `M1` |
| `store.memory` | internal small reference in-memory adapters | not kernel logic | useful baseline for tests and simple tools | internal in `M1` |

## Not Owned By Noztr SDK

These remain outside `noztr-sdk` unless a later plan changes the boundary:
- protocol parsing/validation/building already present in `noztr`
- pure `NIP-65` relay-list extraction until `noztr-sdk` grows a richer routing/policy layer
- broad app policy such as UI flows, notification models, or product-specific moderation rules
- secret storage products and OS wallet/keychain integrations
- large database backends in the first implementation cycle

## Acceptance Questions For New SDK APIs

Before accepting a new public API:
1. Does it combine network, session, cache, or workflow policy above `noztr`?
2. Would multiple apps otherwise need to rewrite the same logic?
3. Can the API stay explicit about policy and side effects?
4. Can the API be tested with fake transports/stores?

If the answer to `1` or `2` is no, the helper may not belong in `noztr-sdk`.
