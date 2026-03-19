---
title: SDK Storage Backend Research
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - deciding_sdk_storage_support
  - defining_store_query_index_architecture
  - choosing_first_party_backends
depends_on:
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-decision.md
  - docs/plans/zig-nostr-ecosystem-phased-plan.md
  - docs/plans/zig-nostr-ecosystem-readiness-matrix.md
touches_teaching_surface: no
touches_audit_state: yes
touches_startup_docs: yes
---

# SDK Storage Backend Research

Focused research packet under the active
[sdk-runtime-client-store-architecture-plan.md](./sdk-runtime-client-store-architecture-plan.md)
lane.

This packet answers:

- which storage workloads the Zig Nostr ecosystem actually needs
- which Zig-usable backend options exist today
- what other serious Nostr projects use, and why
- what `noztr-sdk` should support out of the box, via adapters, or not yet
- when those decisions should affect implementation order

## Research Questions

1. Does `noztr-sdk` need to care about databases, caches, and durable stores?
2. Which storage classes matter for:
   - SDK core
   - CLI
   - signer tooling
   - relay framework
   - high-performance relay
   - Blossom
3. Which Zig-usable libraries are credible enough to matter architecturally?
4. What are other Nostr projects using, and what does that imply for our support posture?
5. How do we avoid locking downstream developers into one backend?

## Core Conclusion

Yes, `noztr-sdk` needs a storage and cache architecture.

But it should own:

- storage seams
- query/index contracts
- support tiers
- reference implementations

and it should avoid owning:

- one mandatory database worldview
- one forced persistence engine
- backend-specific public APIs

In short:

- backend-agnostic interfaces should be canonical
- in-memory reference stores should be first-class
- one embedded durable backend should probably get first-party support early
- relay-grade and product-grade specialized backends should mostly stay adapter-first or
  product-specific

## Workload Classes

Storage should be decided workload-first, not backend-first.

### 1. SDK Reference / Tests / Examples

Needs:

- bounded in-memory stores
- deterministic fixtures
- low setup friction

Best fit:

- in-repo memory stores

### 2. CLI Tooling

Needs:

- local durable cache/store
- single-user operation
- low deployment friction
- simple install story
- useful query/read posture

Best fit:

- one embedded local store

### 3. Signer Tooling/Product

Needs:

- local durable state
- secure key/session metadata boundaries
- explicit account/session/query model
- possibly later sync/export/import posture

Best fit:

- one embedded local store first
- later optional remote/service adapters depending on product shape

### 4. SDK Client Foundations

Needs:

- event/query/index posture
- cache layers
- relay-state and sync checkpoints
- possibly multiple backends depending on platform

Best fit:

- backend-agnostic contracts
- at least one embedded durable default
- later platform-specific adapters

### 5. Relay Framework

Needs:

- durable event/index storage
- query-heavy workload support
- operator-friendly configuration
- clear storage seams for custom relay implementations

Best fit:

- no single default should be assumed yet
- framework should expose storage interfaces

### 6. High-Performance Relay

Needs:

- write throughput
- efficient range/index queries
- durability under sustained ingest
- operator tuning

Best fit:

- specialized backend, likely not the same default backend as CLI/signer

### 7. Blossom

Needs:

- metadata store
- file/object storage
- upload/download lifecycle state

Best fit:

- metadata DB plus object/file storage
- not one monolithic SDK-core event store

## Zig-Usable Backend Options

This is not a generic database survey. These are the relevant options visible from the current Zig
and Nostr ecosystem posture.

### A. In-Memory Reference Stores

Role:

- canonical for tests, examples, and bounded reference behavior

Assessment:

- required
- should remain first-class
- not controversial

Recommendation:

- always ship these in `noztr-sdk`

### B. SQLite

Evidence:

- `zig-sqlite` exists as a thin Zig wrapper around SQLite's C API and supports prepared
  statements, bind checking, and bundled/system SQLite options:
  <https://github.com/vrischmann/zig-sqlite>
- `nostr-rs-relay` persists data with SQLite and has experimental PostgreSQL support:
  <https://github.com/scsibug/nostr-rs-relay>

Strengths:

- ubiquitous
- embedded
- single-file deployment
- low operational friction
- good fit for CLI, signer tooling, and local/client-oriented durability
- well understood query model

Weaknesses:

- not the obvious best fit for highest-throughput relay workloads
- Zig wrapper maturity is useful but not yet “boring infrastructure” in the same way the DB
  itself is

Assessment:

- strongest candidate for first embedded durable backend support in `noztr-sdk`

Recommendation:

- likely first-party supported early
- especially for CLI, signer tooling, and local/client durability

### C. PostgreSQL

Evidence:

- `pg.zig` exists as a native PostgreSQL driver/client for Zig and includes pooling plus `LISTEN`
  support:
  <https://github.com/karlseguin/pg.zig>
- `nostr-rs-relay` explicitly mentions experimental PostgreSQL support:
  <https://github.com/scsibug/nostr-rs-relay>

Strengths:

- strong remote/service DB story
- mature external database model
- useful for server products or service deployments

Weaknesses:

- not embedded
- increases operational complexity
- not the right default for CLI or local-first signer/client use

Assessment:

- useful adapter target
- not a likely first out-of-box SDK default

Recommendation:

- adapter-tier support later
- probably more relevant for relay framework or service products than for early SDK core

### D. LMDB / MDBX

Evidence:

- `strfry` stores all data locally in LMDB:
  <https://github.com/hoytech/strfry>
- `rnostr` stores events in LMDB and explicitly positions that as part of its high-performance
  relay story:
  <https://github.com/rnostr/rnostr>
- `nostrdb` describes itself as an embedded Nostr database backed by LMDB:
  <https://docs.rs/crate/nostrdb/0.2.0/source/Cargo.toml.orig>
- William Casarin’s writeup says `nostrdb` was designed for embedded native clients and that it
  follows the general design direction of `strfry`; this is a useful precedent but should be read
  as project-author perspective rather than neutral benchmark:
  <https://nostr.com/naddr1qqxnzd3ex5eryvfkx56nydesqgsr9cvzwc652r4m83d86ykplrnm9dg5gwdvzzn8ameanlvut35wy3grqsqqqa282m6u3g>
- `libmdbx` documents Zig bindings (`mdbx-zig`) and positions itself as an extremely fast embedded
  transactional key/value database:
  <https://github.com/erthink/libmdbx>

Strengths:

- strong fit for embedded high-performance key/value and index workloads
- proven in serious relay/client systems
- likely a better fit than SQLite for performance-specialized relay engines

Weaknesses:

- lower-level storage model
- more backend-specific indexing work pushed onto us
- easier to leak backend assumptions upward if used too early as the canonical SDK model
- current Zig ergonomics are less obviously standardized than SQLite

Assessment:

- very important for relay-grade and maybe specialized client/embedded products
- not the best default first-party SDK-core backend for all consumers

Recommendation:

- keep backend-agnostic SDK interfaces
- consider LMDB/MDBX adapters or product-specific backends later
- do not let LMDB-style assumptions become the public default API shape for the SDK core

### E. nostrdb

Evidence:

- `nostrdb` is described as an embedded Nostr database backed by LMDB:
  <https://docs.rs/crate/nostrdb/0.2.0/source/Cargo.toml.orig>
- Rust Nostr exposes `nostr-database` with `nostr-lmdb`, `nostr-ndb`, and `nostr-indexeddb`
  backends, which shows a serious ecosystem precedent for abstract database traits plus multiple
  implementations:
  <https://github.com/rust-nostr/nostr>

Strengths:

- domain-specific precedent
- already shaped around Nostr workloads rather than generic SQL tables
- strong signal for local-client/event-store use cases

Weaknesses:

- not Zig-native
- would come in as an external specialized backend, not a foundational SDK-core store shape
- risks overfitting the SDK architecture to another project’s storage worldview

Assessment:

- highly relevant precedent
- useful future adapter or product integration target
- not a good candidate for early canonical out-of-box SDK backend

Recommendation:

- study it
- do not make it the default
- use it as evidence that domain-specific event stores matter

### F. IndexedDB / Platform-Specific Client Stores

Evidence:

- Rust Nostr has separate `nostr-indexeddb` and browser-signer pieces:
  <https://github.com/rust-nostr/nostr>

Assessment:

- relevant later if `noztr-sdk` grows browser/wasm-facing or cross-platform client targets
- not a current top priority for the Zig-native CLI/signer/relay path

Recommendation:

- keep room for platform-specific adapters
- do not treat this as an early core backend target

### G. Specialized Sync-Oriented Structures

Evidence:

- `okra` is a Zig library built on LMDB with set-reconciliation-oriented structure:
  <https://github.com/canvasxyz/okra>

Assessment:

- interesting for future sync/index experimentation
- not a default application store

Recommendation:

- keep as a strategic reference, not an early default backend

## Nostr Ecosystem Precedent

### Precedent 1: One Abstraction, Multiple Backends

The strongest ecosystem precedent is Rust Nostr:

- one database abstraction
- one in-memory implementation
- several backend implementations (`LMDB`, `nostrdb`, `IndexedDB`)

Source:

- <https://github.com/rust-nostr/nostr>

Implication for `noztr-sdk`:

- canonical interfaces plus multiple backends is the right shape
- not one mandatory backend

### Precedent 2: High-Performance Relays Favor Memory-Mapped KV

`strfry` and `rnostr` both use LMDB for serious relay workloads.

Sources:

- <https://github.com/hoytech/strfry>
- <https://github.com/rnostr/rnostr>

Implication:

- relay-grade storage likely should not be forced through the same default backend as CLI or
  signer tooling

### Precedent 3: Simpler Relays Still Use SQL

`nostr-rs-relay` uses SQLite and has experimental PostgreSQL support.

Source:

- <https://github.com/scsibug/nostr-rs-relay>

Implication:

- SQLite is still viable and useful
- especially for simpler operator stories or non-highest-throughput lanes

### Precedent 4: Embedded Clients Benefit From Domain Stores

`nostrdb` is explicitly positioned as an embedded Nostr database for native clients and is backed
by LMDB.

Sources:

- <https://docs.rs/crate/nostrdb/0.2.0/source/Cargo.toml.orig>
- <https://nostr.com/naddr1qqxnzd3ex5eryvfkx56nydesqgsr9cvzwc652r4m83d86ykplrnm9dg5gwdvzzn8ameanlvut35wy3grqsqqqa282m6u3g>

Implication:

- there is real value in Nostr-specialized storage layers
- but we should not rush to copy one storage worldview into the SDK core

## Architectural Rules Confirmed By This Research

### 1. Public SDK APIs Must Be Backend-Agnostic

Do not shape workflow APIs around:

- SQL joins
- LMDB key layout
- nostrdb-specific query model
- one backend’s transaction vocabulary

The canonical surface should be:

- store traits
- query traits
- index/query result shapes
- explicit capability limits

### 2. Support Tiers Must Be Explicit

Recommended tiers:

#### Tier A. Required In Core

- in-memory/reference stores

#### Tier B. First-Party Early Support

- one embedded durable backend

Current best candidate:

- SQLite

#### Tier C. First-Party Optional Or Adapter-Oriented

- PostgreSQL
- LMDB/MDBX
- future platform-specific client stores

#### Tier D. Product-Owned Or Specialized Integrations

- `nostrdb`
- high-performance relay-specific engines
- Blossom object/file storage backends

### 3. Different Product Phases Need Different Defaults

- CLI and signer tooling do not need the same default backend as the fastest relay
- Blossom storage is not the same problem as event-store/query storage

### 4. Research Should Drive Support, Not Library Availability Alone

Just because a Zig binding exists does not mean it should be first-party supported.

The decision should be based on:

- workload fit
- Zig integration quality
- maintenance posture
- platform friction
- how much backend-specific leakage it introduces

## Recommended Support Posture

### Out Of The Box In `noztr-sdk`

Definitely:

- in-memory stores
- backend-agnostic store/query/cache interfaces

Probably:

- one SQLite-backed durable implementation for early SDK/tooling work

Not yet:

- multiple first-party durable backends in the SDK core

### Via Adapters Or Later Optional Modules

- PostgreSQL
- LMDB/MDBX
- platform-specific stores such as IndexedDB-style targets

### In Later Product Repos

- relay-optimized persistence engines
- Blossom metadata + object storage composition
- `nostrdb`-style specialized integrations if they prove worthwhile

## Sequencing Recommendation

### Do Now

- keep this research as reference under the active architecture lane
- encode backend-agnostic and support-tier rules into the architecture decision

### Do Next

- create the first child architecture packet for store/query/index baseline
- use this research to define:
  - canonical interfaces
  - minimum query/index vocabulary
  - support-tier boundaries

### Do Before CLI Gets Deep

- decide whether SQLite is the first embedded durable backend
- define the minimum persistent shape for CLI and signer tooling

### Do Before Relay Framework Hardens

- decide how LMDB/MDBX-class backends fit:
  - adapter
  - optional first-party module
  - later product-owned implementation

## Recommendation Summary

1. `noztr-sdk` should not marry itself to one DB.
2. Storage interfaces should be canonical.
3. In-memory/reference stores must remain first-class.
4. SQLite is the strongest early first-party durable candidate.
5. LMDB/MDBX-class backends matter a lot, but mostly for relay-grade and specialized workloads.
6. `nostrdb` is a valuable precedent and possible future adapter target, not an early core default.
7. The next architecture child lane should be store/query/index baseline, informed by this packet.
