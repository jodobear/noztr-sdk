# Applesauce Study for noztr

## 1) Architecture overview (packages, layering, reactive model)

Applesauce appears to be organized as a high-level ecosystem rather than a narrow protocol core.
The center of gravity is application-facing composition, not byte-level protocol mechanics.

- Packages are split by concern (state, orchestration, integration helpers, and UI-adjacent pieces),
  with APIs designed for product teams building clients quickly.
- Layering trends upward: protocol/event semantics are wrapped by domain-friendly abstractions,
  then exposed through reactive primitives and framework-compatible adapters.
- Reactive model is first-class: updates propagate through subscriptions/streams/signals, so views
  and feature modules react to store changes instead of manually polling for state.
- Event flow is typically ingest -> normalize/index -> react -> project into app state. This shape
  optimizes developer speed and composability, not minimal allocations or deterministic footprints.
- Boundaries are generally package-level and capability-level ("what app feature this enables"),
  while low-level transport/parsing details are intentionally de-emphasized.

For noztr, this is useful as a reference architecture for outer layers, but not as the template for
the low-level Zig core.

## 2) Strengths (developer ergonomics, composition patterns, event-store patterns)

Applesauce offers patterns that are strong for product velocity and multi-feature applications.

- Developer ergonomics are strong: higher-level APIs reduce repeated plumbing and make common Nostr
  workflows discoverable in one place.
- Composition is explicit: small feature modules can be assembled into larger app behavior without
  rewriting base mechanics for each screen or service.
- Event-store patterns are practical: event ingestion plus indexing/caching enables fast queries,
  timeline projection, and derived views needed by interactive clients.
- Reactive propagation reduces accidental staleness: when state changes, subscribed consumers update
  automatically, which lowers UI synchronization bugs.
- Integration paths are clear for app stacks, especially where framework lifecycle/state tools are
  already in use.

These strengths are real and should inform noztr's future adapter layers and examples, not its core
memory/layout rules.

## 3) High-level aspects that do not map to noztr core

Noztr is a low-level Zig library with strict constraints (predictable memory behavior, static design,
and protocol correctness). Several applesauce assumptions do not map directly.

- Framework-centric integration (for example React-oriented expectations) is outside core scope.
- Long-lived app stores with broad mutable graph state do not match a minimal protocol kernel.
- Implicit allocation and convenience-heavy object shaping conflict with deterministic low-level APIs.
- Rich runtime composition and plugin-style indirection can obscure cost models needed in systems code.
- UI lifecycle coupling (mount/unmount/subscription patterns tied to app runtime) should not appear in
  core transport/event parsing primitives.
- "Batteries-included" feature bundles are valuable for apps, but they blur separations required for a
  reusable protocol library.

Applesauce should be treated as an upper-layer design reference, not a direct blueprint for noztr's
foundational modules.

## 4) Adopt / Adapt / Reject table for noztr

| Topic | Decision | Why for noztr |
| --- | --- | --- |
| Clear package boundaries by capability | Adopt | Keeps modules understandable and testable even in low-level code. |
| Event pipeline thinking (ingest -> index -> project) | Adapt | Keep concept, but implement with explicit, bounded, allocation-aware data flow. |
| Reactive subscription model | Adapt | Expose optional callbacks/signals at edges, not as mandatory core runtime model. |
| App-level event stores and projections | Adapt | Useful in higher layers; core should expose primitives for others to build stores. |
| Framework adapters (React, etc.) | Reject in core | Belongs in separate integration packages, never in protocol kernel. |
| Convenience-heavy abstractions hiding cost | Reject in core | Conflicts with deterministic performance and memory predictability goals. |
| Monolithic "do everything" package style | Reject | Noztr needs small, composable protocol-focused modules first. |

## 5) Risks if copied too literally

Copying applesauce patterns directly into noztr core would likely create architectural drift.

- Core bloat: protocol primitives get mixed with app convenience layers, increasing maintenance load.
- Cost opacity: hidden allocations and indirect state updates make performance/debugging harder.
- Weaker portability: framework assumptions leak into a library that should remain runtime-agnostic.
- API instability: high-level ergonomics often evolve quickly, while low-level libraries need stable,
  durable contracts.
- Testing complexity rises: reactive graph behavior can expand test matrices beyond core correctness.
- Misaligned priorities: developer UX for app teams can displace correctness and deterministic behavior
  as primary design drivers.

## 6) How to integrate applesauce-compatible expectations later without polluting core

Noztr can support applesauce-like consumer expectations by layering outward from a strict kernel.

- Keep core narrow: parsing, encoding, validation, event semantics, relay protocol primitives, and
  explicit data structures with predictable memory behavior.
- Define stable extension seams: callback-based hooks and small adapter traits/interfaces at module
  boundaries, so higher layers can observe and compose without modifying internals.
- Build separate integration layers: add optional packages (outside core) for reactive stores,
  projections, and framework adapters.
- Maintain one-way dependency flow: integrations depend on core; core never imports app/framework code.
- Publish reference adapters/examples: demonstrate React-friendly or app-store usage in docs/examples,
  proving compatibility while preserving core purity.
- Add conformance tests at boundaries: ensure adapter layers do not alter protocol correctness or core
  resource guarantees.

Bottom line: applesauce is a valuable source of high-level product architecture ideas. Noztr should use
those ideas at the edges, while keeping the Zig core strictly low-level, deterministic, and framework-
agnostic.
