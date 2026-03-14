# rust-nostr study for noztr

This note studies `rust-nostr` as a systems-language reference and extracts design lessons that
transfer to a low-level Zig library. The focus is architecture and protocol boundary design, not
Rust syntax or framework details.

## 1) Workspace/crate architecture and separation of concerns

- `rust-nostr` uses a large workspace with a narrow core and many satellite crates.
- The core protocol crate (`crates/nostr`) is intentionally reusable by higher layers.
- Adjacent concerns are split by responsibility, not by protocol primitive:
  - signer integration crates (`nostr-connect`, browser signer and proxy)
  - storage abstraction crate plus backend crates (memory, lmdb, sqlite, ndb)
  - gossip abstraction crate plus backend crates
  - relay builder, keyring, wallet-connect, and SDK crates
- The split lowers coupling between protocol types and environment-specific I/O.
- It also permits independent release cadence for storage/gossip/signer layers.

Transferable lesson for noztr:

- Keep a small protocol nucleus with stable wire-level types and parsing.
- Push transport, persistence, and integration concerns into separate modules or sibling packages.
- Treat storage and networking as pluggable clients of protocol types, not owners of them.

## 2) Core crate (`nostr`) module boundaries and NIP organization

- The `nostr` crate top-level modules are domain-oriented: `event`, `filter`, `key`, `message`,
  `nips`, `parser`, `signer`, `types`, and `util`.
- This creates a clean map: base protocol objects live outside `nips`, while NIP-specific logic is
  grouped under `nips::nipXX` modules.
- The `nips` directory is flat and explicit (`nip01`, `nip02`, `nip19`, etc.), which makes feature
  discovery and ownership straightforward.
- Core cross-cutting types remain centralized (for example, `Event`, `Kind`, `Tag`), while NIP
  modules attach behavior and codecs around those shared primitives.
- A `prelude` module offers convenience re-exports for app developers, while direct module imports
  still exist for strict users.

Transferable lesson for noztr:

- Keep protocol base grammar in non-NIP modules (`event`, `message`, `types`).
- Place optional or evolving behavior in one-file-per-NIP modules (`src/nip01.zig`, etc.).
- Avoid scattering NIP logic across core files; prefer one visible entry point per NIP.

## 3) Feature-gating strategy (`all-nips`, per-NIP flags) and tradeoffs

- `rust-nostr` exposes both aggregate and granular flags:
  - aggregate: `all-nips`
  - granular: `nip04`, `nip06`, `nip44`, `nip46`, `nip47`, `nip49`, `nip57`, `nip59`, `nip60`,
    `nip96`, `nip98`
- Some NIPs imply others (`nip46` depends on `nip04` and `nip44`; `nip96` depends on `nip98`).
- Feature gates are used both for dependency control (crypto crates, bip39, scrypt) and surface
  control (which modules compile and which APIs are reachable).
- CI checks many feature combinations, including `std`, `alloc`, and wasm targets, reducing hidden
  bit-rot in less common builds.

Tradeoffs to note:

- Pro: smaller binaries and reduced attack surface for focused deployments.
- Pro: enables `no_std`/embedded usage when only core types are needed.
- Con: feature matrix complexity grows quickly; combinatorial testing cost rises.
- Con: docs and examples can drift unless each feature mode is continuously validated.

Transferable lesson for noztr:

- Implement a simple capability matrix early, even without Rust-style Cargo features.
- Separate always-on protocol parsing from optional cryptographic or network helpers.
- Keep dependency chains explicit, and encode implied capabilities in one place.

## 4) Type-safety and API-shape lessons for low-level protocol work

- `rust-nostr` uses strong domain types (`EventId`, `PublicKey`, `Kind`, `Timestamp`, `RelayUrl`)
  rather than generic strings/integers at API boundaries.
- Construction APIs prefer typed builders and conversion traits over ad hoc map mutation.
- Verification APIs are explicit (`verify_id`, `verify_signature`, `verify`) and separate pure
  checks from context-dependent checks.
- `Event` is marked `non_exhaustive`, preserving forward compatibility for struct evolution.
- Unknown input tolerance exists where protocol interoperability requires it (for example, unknown
  JSON fields can be ignored while preserving canonical re-serialization of known fields).

Transferable lesson for noztr:

- Prefer distinct Zig structs and enums for wire concepts instead of primitive aliases.
- Expose parse, normalize, and verify as separate steps so callers can choose cost and trust model.
- Design APIs around invariants first (valid IDs, valid signatures, valid tag forms), then add
  convenience wrappers.

## 5) Testing/CI lessons and conformance implications

- CI in `rust-nostr` runs formatting, compilation, clippy, tests, docs checks, and no-std embedded
  build paths.
- Matrix builds cover multiple feature sets and targets, including wasm and `alloc`-only mode.
- Tests include both happy-path and adversarial protocol cases (invalid IDs, expiration logic,
  unknown fields, custom kinds, serialization round trips).
- Benchmarks exist for parse/serialize/verify hot paths, helping detect regressions in core protocol
  operations.

Conformance implication:

- Wide matrix testing acts as a protocol conformance guardrail because it exercises different
  capability profiles that real deployments use.
- For Nostr specifically, interoperability failures often hide in edge serialization and partial NIP
  support; matrix and round-trip tests reduce those failures.

Transferable lesson for noztr:

- Maintain test classes by contract: parse validity, semantic validity, canonical encoding, and
  NIP-specific behavior.
- Add compatibility fixtures for cross-implementation vectors, not just self-generated vectors.
- Keep a bounded but explicit build matrix that mirrors supported capability profiles.

## 6) Adopt / Adapt / Reject recommendations for noztr

Adopt:

- One-file-per-NIP organization with explicit registration in a central `nips` index.
- Strong domain types at boundaries, especially IDs, keys, timestamps, and URLs.
- Explicit verification APIs split by concern (`id`, `signature`, `full event`).
- CI coverage for minimal profile and maximal profile builds.

Adapt:

- Replace Cargo feature gates with Zig compile-time options or build-step feature sets.
- Replace prelude-style broad re-exports with narrow Zig module exports to keep call sites explicit.
- Use fixed-capacity buffers and compile-time limits where Rust used heap-backed collections.
- Keep optional NIP support discoverable via compile-time constants and docs tables.

Reject:

- Large convenience prelude imports as a default style for low-level library internals.
- Implicit dependency fan-out where enabling one feature silently pulls heavy transitive behavior.
- Any API shape that relies on dynamic allocation in hot protocol paths.

## 7) Risks and caveats for overfitting Rust patterns into Zig

- Rust trait-heavy ergonomics do not map 1:1 to Zig; forced emulation can hide control flow and
  weaken the explicitness required by low-level systems code.
- Rust ownership patterns can tempt over-abstraction in Zig. For noztr, simpler dataflow and small
  explicit functions are usually safer.
- Cargo feature metadata and docs.rs automation provide discovery Rust gets "for free"; Zig projects
  must build equivalent clarity intentionally in `build.zig` and docs.
- `rust-nostr` frequently relies on `alloc` or `std` in optional paths. noztr should avoid importing
  that memory model accidentally into core protocol logic.
- Some Rust APIs optimize for app developer convenience; noztr should prioritize bounded memory,
  deterministic behavior, and auditability over ergonomic breadth.

Bottom line:

- Use `rust-nostr` as an architecture reference for modularity, typed boundaries, and capability
  partitioning.
- Do not copy Rust idioms mechanically; translate intent into Zig-native, bounded, explicit design.
