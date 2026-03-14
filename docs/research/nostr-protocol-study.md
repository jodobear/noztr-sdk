# Nostr Protocol Study for noztr

This document is a low-level protocol analysis for noztr v1.
It is not a copy of NIP text.

## 1) Priority map: Must-Have / Should-Have / Later

### Must-Have

- Core event model, canonical serialization, signatures, filters, replaceable/addressable semantics.
- NIP refs: [NIP-01](../nips/01.md), [NIP-12](../nips/12.md), [NIP-16](../nips/16.md),
  [NIP-20](../nips/20.md), [NIP-33](../nips/33.md).
- Relay baseline behavior and auth/protection flow.
- NIP refs: [NIP-11](../nips/11.md), [NIP-42](../nips/42.md), [NIP-70](../nips/70.md).
- Deletion/expiration/PoW policy hooks and validators.
- NIP refs: [NIP-09](../nips/09.md), [NIP-40](../nips/40.md), [NIP-13](../nips/13.md).
- Crypto primitives for modern private transport.
- NIP refs: [NIP-44](../nips/44.md), [NIP-59](../nips/59.md).

### Should-Have

- Identity and reference codecs/resolvers.
- NIP refs: [NIP-02](../nips/02.md), [NIP-05](../nips/05.md), [NIP-19](../nips/19.md),
  [NIP-21](../nips/21.md), [NIP-65](../nips/65.md).
- Relay query extensions.
- NIP refs: [NIP-45](../nips/45.md), [NIP-50](../nips/50.md), [NIP-77](../nips/77.md).

### Later

- Full chat workflow conventions after crypto/wrap layers are stable.
- NIP refs: [NIP-17](../nips/17.md).
- Legacy DM compatibility bridge only.
- NIP refs: [NIP-04](../nips/04.md).

## 2) Functional areas

### Event model and canonicalization (NIP-01 + moved mandatory NIPs)

- NIP refs: [NIP-01](../nips/01.md), [NIP-12](../nips/12.md), [NIP-16](../nips/16.md),
  [NIP-20](../nips/20.md), [NIP-33](../nips/33.md).
- NIP-12/16/20/33 are moved into NIP-01 behavior. Implement as one core module, not split features.
- Event ID generation must be deterministic: UTF-8 JSON array form, strict escape handling, no extra
  whitespace, lowercase hex IDs/keys/signatures.
- Replaceable/addressable tie handling must be deterministic in local logic:
  same `created_at` => lowest lexical `id` wins.
- Required decision: strict parser vs compatibility parser for malformed JSON and
  duplicate object keys.
- Required decision: unknown tag forms accepted as data, or rejected under strict validation mode.

### Message protocol and relay semantics (01/11/42/70/45/50/77)

- NIP refs: [NIP-01](../nips/01.md), [NIP-11](../nips/11.md), [NIP-42](../nips/42.md),
  [NIP-70](../nips/70.md), [NIP-45](../nips/45.md), [NIP-50](../nips/50.md),
  [NIP-77](../nips/77.md).
- Build an explicit wire state machine for `EVENT`, `REQ`, `CLOSE`, `EOSE`, `OK`, `CLOSED`, `NOTICE`,
  plus extension messages.
- AUTH is connection-scoped and challenge may rotate. Store active challenge and authenticated pubkeys
  per websocket.
- NIP-70 default is reject when `['-']` tag exists. Accept only if AUTH is complete and auth pubkey
  matches event pubkey.
- NIP-77 uses subscription IDs in a separate namespace from REQ subscriptions.
- Required decision: map machine prefixes (`invalid`, `rate-limited`, `auth-required`, etc.) into
  structured errors while preserving relay text.
- Required decision: keep NIP-50 search as pass-through relay capability,
  not deterministic local ranking.

### Identity and references (02/05/19/21/65)

- NIP refs: [NIP-02](../nips/02.md), [NIP-05](../nips/05.md), [NIP-19](../nips/19.md),
  [NIP-21](../nips/21.md), [NIP-65](../nips/65.md).
- Internal canonical form should remain binary/hex. NIP-19/NIP-21 are import/export codecs.
- NIP-05 resolution must enforce no-redirect rule and require `names[name] == kind-0 pubkey` before
  trust.
- NIP-65 read/write relay metadata should drive routing; treat NIP-02 relay hints as weaker fallback.
- Required decision: merge policy for conflicting kind:10002 events seen on different relays.
- Required decision: whether `_@domain` normalization is in core logic or edge utility only.

### Deletion, expiration, PoW (09/40/13)

- NIP refs: [NIP-09](../nips/09.md), [NIP-40](../nips/40.md), [NIP-13](../nips/13.md).
- Deletion is request-based and non-global. For client behavior,
  verify author equality before applying
  hide/delete effects for `e` references.
- For `a` references, deletion up to request timestamp requires deterministic historical ordering.
- Expired events should be filtered from outputs and can be dropped on ingest if already expired.
- PoW should be split into (1) difficulty computation primitive and (2) relay policy thresholds.
- Required decision: visibility precedence when event is both expired and deleted.

### Private messaging stack (44/59/17, with 04 compatibility note)

- NIP refs: [NIP-44](../nips/44.md), [NIP-59](../nips/59.md), [NIP-17](../nips/17.md),
  [NIP-04](../nips/04.md).
- Implementation order should be: NIP-44 v2 crypto -> NIP-59 rumor/seal/wrap -> NIP-17 conventions.
- Validate outer event signature/pubkey before decryption (NIP-44 requirement).
- Validate anti-impersonation invariant from NIP-17:
  seal pubkey must match inner kind-14 pubkey.
- Timestamp jitter in seal/wrap improves privacy; APIs should also allow deterministic clock/random
  injection for vectors.
- NIP-04 should be isolated as deprecated compatibility path, not default messaging surface.

## 3) NIP interaction matrix (key dependencies and ordering)

- `Stage 1 foundation`
  - [NIP-01](../nips/01.md) is prerequisite for every protocol surface here.
  - [NIP-12](../nips/12.md), [NIP-16](../nips/16.md), [NIP-20](../nips/20.md),
    [NIP-33](../nips/33.md) are moved/renamed into NIP-01 behavior.
- `Stage 2 relay capability + access`
  - [NIP-11](../nips/11.md) advertises support/limits and gates feature toggles.
  - [NIP-42](../nips/42.md) enables authenticated reads/writes and is required by NIP-70 acceptance.
  - [NIP-70](../nips/70.md) protected events depend on NIP-42 session state.
- `Stage 3 lifecycle and anti-spam`
  - [NIP-09](../nips/09.md), [NIP-40](../nips/40.md), [NIP-13](../nips/13.md) all attach policy to
    NIP-01 events.
- `Stage 4 identity/routing`
  - [NIP-19](../nips/19.md) and [NIP-21](../nips/21.md) are codecs over core IDs.
  - [NIP-05](../nips/05.md), [NIP-02](../nips/02.md), [NIP-65](../nips/65.md)
    affect discovery and relay selection.
- `Stage 5 private transport core`
  - [NIP-44](../nips/44.md) is cryptographic prerequisite for [NIP-59](../nips/59.md).
  - [NIP-59](../nips/59.md) is structural prerequisite for [NIP-17](../nips/17.md).
  - [NIP-04](../nips/04.md) remains independent legacy compatibility.
- `Stage 6 extension channels`
  - [NIP-45](../nips/45.md) extends query semantics (`COUNT`).
  - [NIP-50](../nips/50.md) extends filter semantics (`search`).
  - [NIP-77](../nips/77.md) adds stateful sync channel with separate sub-id namespace.

## 4) Ambiguities and edge cases checklist

- NIP-01 canonicalization does not fully define behavior for duplicate JSON keys.
- NIP-01 says lowercase fixed-length hex, but ecosystem often sends mixed-case or wrong lengths.
- Replaceable winner tie rule exists, but relay behavior in the wild may diverge.
- NIP-42 challenge can change at any time, creating race windows for pending writes/queries.
- NIP-70 defines protected tag as exactly `['-']`; malformed variants are unspecified.
- NIP-45 HLL offset is undefined for some filter shapes (for example no tag filter).
- NIP-50 ranking semantics are intentionally relay-specific and non-deterministic.
- NIP-05 forbids redirects; many servers still redirect in practice.
- NIP-09 delete request may arrive before referenced event; delayed reconciliation is required.
- NIP-40 expiration interacts with relay retention differences and may produce cross-relay drift.
- NIP-44 requires payload size guards before decode/decrypt to avoid resource abuse.
- NIP-59/NIP-17 privacy guidance needs random timestamp jitter, but tests need determinism.

## 5) Recommended conformance/vector strategy

- Tier 0: NIP-01 event vectors for serialization, ID, signature verify,
  filter matching, and tie-breaks.
- Tier 1: wire transcript vectors for `REQ`/`EOSE`/`CLOSE`, `OK`/`CLOSED` prefixes, and AUTH flow.
- Tier 2: lifecycle vectors for deletion, expiration, and PoW policy combinations.
- Tier 3: NIP-44 official vectors plus negative vectors (bad MAC, bad padding, unknown version,
  malformed payload lengths).
- Tier 4: NIP-59/NIP-17 unwrap vectors enforcing seal/rumor pubkey invariant.
- Tier 5: fuzz corpus for malformed frames, invalid hex/TLV,
  oversize messages, and namespace confusion.
- Publish two profiles: `core-mandatory` and `extensions-optional`,
  each with explicit NIP feature bits.

## 6) Open questions for build planning

- Should strict-vs-compat parsing be compile-time, runtime, or both.
- Should noztr include relay policy engines, or only protocol primitives and validation.
- For NIP-77, include full negentropy algorithm now or only Nostr message framing in v1.
- For NIP-50, provide any local query parser or keep pure pass-through semantics.
- For NIP-17, ship decode/verify first and postpone outbound fan-out orchestration.
- For NIP-04, is read-only migration enough, or is outbound encode/send also needed.
- What is the standard API for deterministic clock/random injection across crypto/wrap tests.
- Which vector corpus is checked in-repo versus downloaded in CI under zero-dependency constraints.
