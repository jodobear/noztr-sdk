---
title: Noztr SDK Kickoff
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - understanding_initial_scope
  - reviewing_bootstrap_decisions
---

# Noztr SDK Kickoff

Initial scope and execution kickoff for `noztr-sdk`.

Date: 2026-03-14

## Objective

Bootstrap a deliberate Zig SDK above `noztr` that handles real Nostr workflows without eroding the
protocol-kernel boundary.

## Research Refresh Summary

Inputs reviewed during bootstrap:
- `docs/research/v1-applesauce-deep-study.md`
- `docs/research/v1-rust-nostr-deep-study.md`
- `docs/research/building-nostr-study.md`
- `docs/research/v1-protocol-reference.md`
- `docs/plans/research-refresh-2026-03-14.md`
- targeted NIPs: `01`, `03`, `06`, `11`, `17`, `29`, `39`, `44`, `46`, `59`, `65`
- local `noztr` package and root export surface in `/workspace/projects/noztr`

High-signal findings:
- applesauce is strongest as a workflow and store-layer reference, not as a protocol contract
- applesauce validates a store-first layering where relay orchestration remains a separate concern
- rust-nostr validates the value of explicit SDK strata: protocol crate, signer crates, database
  crates, gossip/storage crates, then SDK
- rust-nostr validates a thin top-level client facade over deeper relay/pool/policy layers
- the March 14, 2026 upstream refresh does not currently change milestone order or boundary calls
- the `noztr` ownership matrix already identifies the right SDK starter lane: relay/session/store
  orchestration for `NIP-46`, `NIP-17`, `NIP-11`, `NIP-65`, `NIP-39`, `NIP-03`, and later `NIP-29`

## SDK Purpose

`noztr-sdk` exists to make the following easier for Zig callers:
- build Nostr applications, relays, signers, clients, bots, services, and CLIs from a clear SDK
  substrate
- connect to relays and manage relay capability/state explicitly
- hydrate relay preferences and relay metadata into routing decisions
- run reusable signer sessions over `NIP-46`
- run private mailbox workflows over `NIP-17`, `NIP-44`, and `NIP-59`
- verify external identities and OpenTimestamps proofs with explicit fetch/policy hooks
- persist lightweight workflow state through caller-supplied store interfaces

## Initial Users

- Zig application authors building clients, bots, services, or CLI tools
- relay and signer authors who need reusable session/orchestration layers above `noztr`
- future platform adapters that need a reusable Zig SDK core
- developers who want explicit control over policy and transports instead of framework-coupled
  abstractions

## Examples Posture

- use `/workspace/projects/noztr/examples` as the recipe reference set for kernel-only usage
- add `noztr-sdk` examples as structured orchestration recipes once two workflows are stable
- keep SDK examples focused on end-to-end workflow composition, not protocol helper duplication
- treat structured examples as required implementation artifacts, not optional polish

## First Supported Workflow Set

The first useful SDK layer is:
- relay metadata fetch/cache (`NIP-11`)
- relay/session/auth substrate for subscriptions and request/response lifecycles
- defer pure `NIP-65` relay-list extraction to `noztr` until `noztr-sdk` grows a richer routing/policy
  layer
- remote signer client sessions (`NIP-46`)
- private mailbox sessions (`NIP-17` over `NIP-44` + `NIP-59`)
- external identity verification adapters (`NIP-39`)
- OpenTimestamps retrieval/verification adapters (`NIP-03`)

Not first-wave SDK surfaces:
- browser signer wrappers (`NIP-07`)
- wallets, zaps, Cashu, or Blossom clients
- database engines or large persistence stacks
- opinionated app stores, UI routing, or secret-management products

## Boundary Checks For Starter Work

### Relay/session substrate

- Why not `noztr`?
  - It requires connection state, fetch policy, retries, and session lifecycle.
- Why not app code?
  - Multiple apps will need the same relay/session mechanics.
- Why is this the simplest useful SDK layer?
  - All higher workflows depend on it.

### Remote signer session

- Why not `noztr`?
  - `noztr` already owns deterministic `NIP-46` message contracts; the SDK owns relay/session
    orchestration and permission flow.
- Why not app code?
  - Correlation, relay switching, and auth-challenge handling are reusable.
- Why is this the simplest useful SDK layer?
  - It turns exact protocol helpers into a usable signer client.

### Mailbox session

- Why not `noztr`?
  - `noztr` owns parse/build/unwrap rules; mailbox discovery and sync are orchestration.
- Why not app code?
  - Message-room derivation, inbox routing, and unwrap sequencing repeat across apps.
- Why is this the simplest useful SDK layer?
  - It is the first broadly useful private-messaging workflow.

### Identity and proof verification adapters

- Why not `noztr`?
  - Provider/network retrieval and caching are outside deterministic kernel scope.
- Why not app code?
  - The fetch/verify workflow is reusable and policy needs to stay explicit.
- Why is this the simplest useful SDK layer?
  - It keeps networked verification logic centralized without hiding policy.

## Milestone Sequence

1. planning baseline
2. scaffold and local `noztr` dependency wiring
3. relay/session substrate
4. remote signer session
5. mailbox session
6. identity/proof adapters
7. evaluate group sync/store

## Exit Criteria For Kickoff

Kickoff is complete when:
- planning docs are accepted and referenced by startup files
- the local `noztr` dependency path is frozen
- the first milestone order is explicit
- the next execution slice is narrowed to `M1` scaffold work

All later execution cycles should also satisfy `docs/plans/implementation-quality-gate.md` before
new NIP-backed work begins.
