# Building Nostr study notes for noztr

This document synthesizes architecture guidance from Hodlbod's *Building Nostr* for
noztr's primary goal: a low-level, Zig-first protocol library.

## 1) Core principles from the book relevant to protocol library design

- Keep the protocol core minimal: signed events, filters, and simple relay message
  flow are the stable center; everything else should be optional layering.
- Separate identity, storage, and application behavior: keys authenticate authors,
  relays store/retransmit data, clients define product behavior.
- Treat events as immutable signed facts by default; consider replaceability and
  ephemeral behavior as explicit exceptions with clear semantics.
- Prefer small, composable conventions over monolithic schemas: more focused kinds
  and explicit tags reduce ambiguity and accidental coupling.
- Design for partition tolerance and availability, not global consistency: clients
  should assume partial views, out-of-order arrival, and conflicting timestamps.
- Prioritize practical interoperability over theoretical elegance: avoid spec purity
  that fragments implementations without measurable user benefit.

## 2) How those principles map to low-level API and module boundaries

- **Event core module**: canonical serialization, id hashing, signature verify/sign,
  event structural checks, and deterministic encode/decode primitives.
- **Kind and tag model module**: represent kinds as numeric protocol identifiers,
  expose generic tag parsing and typed helper accessors without hardcoding product
  semantics.
- **Filter module**: validate and normalize NIP-01 style filters, including tag-key
  filter support and strict handling for malformed inputs.
- **Relay protocol module**: parse/encode WebSocket frame payload types (`EVENT`,
  `REQ`, `OK`, `EOSE`, `CLOSE`, `CLOSED`, `AUTH`) as transport-agnostic data types.
- **Validation policy module**: separate hard-fail cryptographic invalidity from
  soft-fail schema ambiguity so integrators can choose strict vs tolerant behavior.
- **Routing hints module**: model outbox/inbox selections, relay hints, pubkey hints,
  and migration metadata as first-class data inputs rather than hidden heuristics.
- **Compatibility facade module**: isolate legacy decode/compat logic so new APIs can
  remain clean while still reading older event variants.

## 3) Relay/routing philosophy implications (outbox/inbox heuristics, hints, migration)

- Routing is protocol architecture, not app glue: a low-level library should expose
  reusable primitives for heuristic-based relay targeting.
- Outbox and inbox are separate heuristics and should remain separate API surfaces;
  callers must combine them per use case instead of one implicit "smart" resolver.
- Relay hints are advisory and degradable: treat them as fallback signals with trust
  weighting, never as authoritative source-of-truth.
- Pubkey hints are often more durable than relay URL hints; APIs should prefer flows
  that can re-derive current relay sets from pubkey-linked metadata.
- Relay selection changes require explicit migration support: expose deterministic
  workflows for sync planning, replay, and verification of discoverability.
- Do not encode one global routing strategy in the library; ship composable routing
  building blocks so clients can add NIP-specific heuristics safely.

## 4) Privacy/security implications for signed data and private messaging

- Signed events improve authenticity but increase attribution permanence; library
  docs should mark signed publication as effectively irreversible.
- Authentication guarantees provenance, not confidentiality; private messaging needs
  explicit encryption semantics and metadata minimization discipline.
- Metadata leakage is a first-order risk: relay choice, hints, and timing can reveal
  social graph structure even with encrypted payloads.
- Validate cryptography strictly, parse content defensively: invalid signatures must
  fail hard, while malformed non-critical fields should be safely containable.
- Identity model should encourage key compartmentalization (different keys per role
  or context) because key reuse amplifies cross-context deanonymization.
- Access control belongs to relay policy, but library APIs should make policy input
  explicit so clients do not confuse transport success with authorization success.

## 5) Interoperability and backwards-compatibility discipline

- Interop is a product feature of the low-level library; avoid convenience helpers
  that silently rewrite wire data into local, non-standard forms.
- Preserve unknown fields/tags when possible to avoid destructive round-trips during
  parse-modify-serialize workflows.
- Prefer additive evolution: new behavior should usually be opt-in capability checks
  or new kinds, not reinterpretation of existing stable formats.
- Keep parser behavior deterministic across strict/tolerant modes so integrators can
  reason about failures and cross-client divergences.
- Treat legacy support as bounded debt: isolate compatibility shims and define clear
  deprecation windows in documentation.
- Publish conformance test vectors for serialization, signature checks, filter match,
  and relay message handling to reduce ecosystem drift.

## 6) Anti-patterns to avoid in noztr

- Embedding application policy into core wire types (for example, hardcoding social
  UX assumptions in parser logic).
- One giant "universal event" abstraction that erases kind/tag specificity and makes
  validation ambiguous.
- Implicit network side effects in low-level APIs (auto-publish, auto-migrate,
  auto-relay discovery) that remove caller control.
- Overloading a single helper for incompatible behaviors, then inferring intent from
  weak context.
- Treating hints as trusted authority, or routing through one default mega-relay by
  design.
- Strict rejection of recoverable non-critical irregularities, causing unnecessary
  interop breakage for otherwise valid signed data.
- Silent acceptance of cryptographic invalidity "for UX"; this weakens the protocol
  trust model and invites spoofing.

## 7) Open questions for planning

- Which minimum NIP set defines noztr v0 scope for a low-level library (core event,
  relay protocol, auth, and DM-related primitives)?
- Should strict vs tolerant parsing be compile-time policy, runtime policy, or both,
  and how should that map to Zig error sets?
- What exact invariants should the library guarantee for round-trip preservation of
  unknown tags/content across decode and re-encode?
- Which routing heuristics should be represented in core modules vs separate opt-in
  extension modules to prevent premature coupling?
- How should migration planning be represented as data structures so higher-level
  clients can execute sync without hidden state?
- What conformance corpus is required before freeze of any public API: cross-client
  vectors, malformed corpus, relay transcript fixtures, or all of these?
- Which private messaging primitives belong in scope now given ongoing NIP churn,
  and which should remain explicitly out of scope until stabilized?
