# v1 Protocol Reference (Phase B)

Date: 2026-03-05

Scope note: this document covers only Phase A H1-selected NIPs:
01, 02, 09, 11, 12, 13, 16, 19, 20, 21, 33, 40, 42, 44, 45, 50, 59, 65, 70, 77.

Out-of-scope exclusion note: NIP-04, NIP-05, and NIP-17 are deferred to H2 and are not
analyzed here beyond this explicit scope exclusion.

## Decisions

- `B-001`: Keep `D-003` strict-by-default behavior for all parse/verify boundaries.
- `B-002`: Treat NIP-12, NIP-16, NIP-20, and NIP-33 as NIP-01 behavior aliases only.
- `B-003`: Require explicit typed failure outcomes for malformed message shapes and invalid
  cryptographic material.
- `B-004`: Freeze NIP-44 v2 as the only accepted NIP-44 payload version for v1.
- `B-005`: Keep NIP-77 v1 support at wrapper/protocol framing level in v1; full negentropy
  optimization strategy remains implementation-phase constrained.
- `B-006`: Set minimum extension parity gate defaults for optional NIPs (02/19/21/45/50/65/77)
  to prevent optional-profile drift in later phases.

## Per-NIP Canonical Reference

### NIP-01 Basic protocol flow description

- Canonical rules:
  - Event fields are `id`, `pubkey`, `created_at`, `kind`, `tags`, `content`, `sig`.
  - `id` is SHA-256 over canonical serialized event array `[0,pubkey,created_at,kind,tags,content]`.
  - Canonical serialization requires UTF-8, no extra whitespace, and required escape behavior.
  - `pubkey`, `id`, `sig` are lowercase hex with fixed lengths (32-byte, 32-byte, 64-byte).
  - Client->relay verbs: `EVENT`, `REQ`, `CLOSE`; relay->client verbs: `EVENT`, `OK`, `EOSE`,
    `CLOSED`, `NOTICE`.
  - Filter semantics: per-filter fields are logical AND; multiple filters are logical OR.
- Limits:
  - `kind` range: `0..65535`.
  - `subscription_id` max length: 64 chars, non-empty.
  - `ids`, `authors`, `#e`, `#p` filter values must be exact 64-char lowercase hex.
  - `limit` is initial-query-only behavior and must be ignored afterwards.
- Rejection/failure criteria:
  - Reject invalid canonical event JSON shape or invalid field typing at trust boundaries.
  - Reject invalid `id` recomputation mismatch.
  - Reject invalid Schnorr signature / invalid pubkey material.
  - Reject malformed relay message arrays and unknown command names in strict mode.
- Acceptance criteria:
  - Accept event only when structural parse, canonical hash check, and signature verification pass.
  - Accept filter only when all declared fields are type-valid and bounded.
  - Accept replaceable/addressable tie-break using `created_at`, then lexical lowest `id`.

### NIP-02 Follow List

- Canonical rules:
  - Follow list is `kind:3` event with `p` tags of form
    `['p', <pubkey>, <relay-url-or-empty>, <petname-optional>]`.
  - New list overwrites previous list for same author.
  - `content` is unused.
- Limits:
  - No explicit protocol numeric caps in spec; apply implementation caps from build plan.
- Rejection/failure criteria:
  - Reject non-`p`-tag entries for strict follow-list extraction API.
  - Reject malformed pubkey hex in `p` tags.
- Acceptance criteria:
  - Accept as valid kind-3 follow list when event validity passes NIP-01 and `p` tags parse.

### NIP-09 Event Deletion Request

- Canonical rules:
  - Deletion request is `kind:5` with one or more `e` or `a` tags.
  - `k` tags are recommended for referenced kind declarations.
  - Relays should delete/stop publishing referenced events only when pubkey matches deleter.
  - Deletion requests should continue to be published.
- Limits:
  - At least one `e` or `a` reference tag is required by intent.
  - For `a` tags, deletion coverage should apply up to deleter `created_at` timestamp.
- Rejection/failure criteria:
  - Reject empty-reference deletion events in strict policy path.
  - Reject/ignore delete effect when referenced event pubkey differs from deleter pubkey.
  - Reject "delete deletion request" as no-op per NIP behavior.
- Acceptance criteria:
  - Accept deletion request event object if NIP-01 valid and at least one valid target reference.

### NIP-11 Relay Information Document

- Canonical rules:
  - HTTP `Accept: application/nostr+json` on relay endpoint returns relay metadata JSON.
  - Any known field may be omitted; unknown fields must be ignored by clients.
  - Relay must send CORS headers.
  - `supported_nips` advertises relay-supported NIPs.
- Limits:
  - `name` should be <30 chars (recommendation).
  - `limitation` object may expose practical relay limits (message size, subscriptions, etc.).
- Rejection/failure criteria:
  - Reject invalid types for structured fields in strict parser mode.
  - Ignore unsupported/unknown fields instead of failing parse.
- Acceptance criteria:
  - Accept partial documents with any subset of known keys if JSON is valid.

### NIP-12 Generic Tag Queries (moved)

- Canonical rules: moved to NIP-01 filter model.
- Limits: NIP-01 filter limits apply.
- Rejection/failure criteria: same as NIP-01 tag filter parsing failures.
- Acceptance criteria: same as NIP-01 filter acceptance path.

### NIP-13 Proof of Work

- Canonical rules:
  - Difficulty is leading zero bit count over NIP-01 `id`.
  - PoW uses `['nonce', <counter>, <target-difficulty-optional>]` tag.
  - Third nonce value should commit target difficulty.
- Limits:
  - Event `id` is fixed 32-byte hash input for zero-bit counting.
  - Difficulty commitment value must parse as non-negative integer.
- Rejection/failure criteria:
  - Reject malformed nonce tag shape/integers.
  - Reject when required minimum difficulty not met.
  - Compatibility decision: allow missing third nonce element by default but do not treat as
    difficulty commitment.
- Acceptance criteria:
  - Accept PoW check when counted leading zero bits >= required threshold and nonce tag is valid.

### NIP-16 Event Treatment (moved)

- Canonical rules: moved to NIP-01 event kind treatment.
- Limits: NIP-01 replaceable/ephemeral/addressable kind ranges apply.
- Rejection/failure criteria: NIP-01 replacement/tie-break failure paths apply.
- Acceptance criteria: NIP-01 event-treatment acceptance applies.

### NIP-19 bech32-encoded entities

- Canonical rules:
  - Bare entities: `npub`, `nsec`, `note`.
  - TLV entities: `nprofile`, `nevent`, `naddr`, `nrelay`.
  - TLV type meanings: `0=special`, `1=relay`, `2=author`, `3=kind`.
  - Unknown TLVs should be ignored on decode.
  - NIP-19 strings are display/input codec, not core NIP-01 wire fields.
- Limits:
  - `T` and `L` are uint8; each TLV value max 255 bytes.
  - `kind` TLV value is 32-bit unsigned big-endian for applicable entities.
- Rejection/failure criteria:
  - Reject invalid bech32 checksum/prefix/payload for requested entity decode.
  - Reject structural violations for required TLVs per entity type.
- Acceptance criteria:
  - Accept decode when prefix is known and required TLVs are present and well-formed.
  - Accept with unknown TLVs ignored.

### NIP-20 Command Results (moved)

- Canonical rules: moved to NIP-01 `OK`/`CLOSED` response format and prefixes.
- Limits: machine-readable prefix format `<prefix>: <message>` for denial reasons.
- Rejection/failure criteria: reject malformed `OK`/`CLOSED` shape.
- Acceptance criteria: accept response when array arity/type and prefix formatting are valid.

### NIP-21 `nostr:` URI scheme

- Canonical rules:
  - URI format is `nostr:<nip19-identifier>`.
  - Allowed identifiers are NIP-19 entities except `nsec`.
- Limits:
  - No additional numeric limits beyond NIP-19 payload constraints.
- Rejection/failure criteria:
  - Reject non-`nostr:` scheme.
  - Reject `nostr:nsec...` in strict mode.
  - Reject invalid underlying NIP-19 encoding.
- Acceptance criteria:
  - Accept URI when scheme, allowed identifier prefix, and embedded NIP-19 decode all pass.

### NIP-33 Parameterized Replaceable Events (moved)

- Canonical rules: renamed/moved to NIP-01 addressable event behavior.
- Limits: address key is `(kind,pubkey,d-tag)`.
- Rejection/failure criteria: reject malformed address coordinates.
- Acceptance criteria: accept replacement semantics exactly as NIP-01 addressable rules.

### NIP-40 Expiration Timestamp

- Canonical rules:
  - `['expiration', <unix-seconds>]` tag marks event expiry point.
  - Clients should ignore expired events.
  - Relays should not send expired events and should drop already-expired published events.
  - Expiration does not affect storage of ephemeral events.
- Limits:
  - Tag requires one timestamp value in seconds.
- Rejection/failure criteria:
  - Reject malformed expiration tag values for strict validator APIs.
  - Treat already-expired incoming event as failed relay-accept policy.
- Acceptance criteria:
  - Accept non-expired event with valid expiration tag parse.

### NIP-42 Authentication of clients to relays

- Canonical rules:
  - Relay->client challenge: `['AUTH', <challenge>]`.
  - Client->relay auth event: `['AUTH', <signed-event>]` with `kind:22242`.
  - Auth event must include `relay` and `challenge` tags.
  - Client AUTH must receive `OK` response.
  - Challenges are connection-scoped and replaced by newer challenge.
- Limits:
  - Auth event is ephemeral and must not be broadcast to clients.
  - `created_at` should be close to current time (example ~10 minutes).
- Rejection/failure criteria:
  - Reject auth event if kind != 22242.
  - Reject if challenge mismatches current connection challenge.
  - Reject if relay tag does not match relay URL policy.
  - Reject stale timestamps beyond relay policy window.
- Acceptance criteria:
  - Accept when kind/tags/time/signature/pubkey checks all pass and challenge matches.

### NIP-44 Encrypted Payloads (Versioned)

- Canonical rules:
  - v2 payload frame is base64 of `version||nonce||ciphertext||mac`.
  - Conversation key via secp256k1 ECDH x-coordinate and HKDF-extract salt `nip44-v2`.
  - Message keys via HKDF-expand L=76 split into ChaCha key, ChaCha nonce, HMAC key.
  - Padding is deterministic and length-prefix based (`u16` big-endian).
  - MAC is HMAC-SHA256 over `nonce||ciphertext`; MAC compare must be constant-time.
  - Outer NIP-01 signature/pubkey validation must pass before decrypting.
- Limits:
  - Plaintext length: `1..65535` bytes.
  - Base64 payload length: `132..87472` chars.
  - Decoded payload length: `99..65603` bytes.
  - Version accepted in v1: `0x02` only.
- Rejection/failure criteria:
  - Reject payload starting with `#` as unsupported encoding/version path.
  - Reject invalid base64 length/decoded length ranges.
  - Reject unknown version.
  - Reject invalid MAC, invalid padding, invalid key material.
- Acceptance criteria:
  - Accept decrypt only when all checks pass in specified order and UTF-8 decode succeeds.

### NIP-45 Event Counts

- Canonical rules:
  - `COUNT` request shape: `['COUNT', <query_id>, <filter>...]` using NIP-01 filters.
  - Response shape: `['COUNT', <query_id>, {'count': <int>}]`.
  - Optional fields: `approximate`, `hll`.
  - If refused, relay must return `CLOSED`.
- Limits:
  - HLL (if present) is 256 uint8 registers encoded as 512-char hex.
  - HLL offset defined only for filters with a tag attribute first element.
- Rejection/failure criteria:
  - Reject malformed request/response array or malformed count object.
  - Reject invalid hll hex length/format in strict parser mode.
  - For unsupported count, fail via `CLOSED` handling path.
- Acceptance criteria:
  - Accept count response with valid `count` integer and optional validated metadata.

### NIP-50 Search Capability

- Canonical rules:
  - Adds `search` string filter field in `REQ` filters.
  - Search results should be ordered by quality score (not created_at).
  - `limit` should be applied after score sorting.
  - `key:value` query fragments are relay extensions; unsupported extensions should be ignored.
- Limits:
  - No fixed numeric protocol limits in spec.
- Rejection/failure criteria:
  - Reject non-string `search` value in strict mode.
  - Ignore unsupported extension tokens rather than failing entire query.
- Acceptance criteria:
  - Accept search filter when base NIP-01 filter parse passes and `search` is valid string.

### NIP-59 Gift Wrap

- Canonical rules:
  - Rumor is unsigned event payload.
  - Seal is `kind:13`, signed by real author, encrypted rumor in `content`, tags must be empty.
  - Gift wrap is `kind:1059`, signed by random one-time key, encrypted seal in `content`.
  - Gift wrap should include recipient routing data (`p` tag).
  - Encryption uses NIP-44.
- Limits:
  - Seal `tags` must always be empty.
  - Inner rumor must be unsigned.
- Rejection/failure criteria:
  - Reject seal with non-empty tags.
  - Reject wrap with unparseable inner encrypted payload.
  - Reject unwrap when cryptographic checks fail at any layer.
- Acceptance criteria:
  - Accept unwrap when gift-wrap decrypt -> seal verify/decrypt -> rumor parse chain passes.

### NIP-65 Relay List Metadata

- Canonical rules:
  - Replaceable `kind:10002` event with `r` tags and optional marker `read|write`.
  - Marker omitted means both read and write.
  - `content` empty.
- Limits:
  - Spec recommends small lists (2-4 per category) but does not require hard cap.
- Rejection/failure criteria:
  - Reject invalid relay URL or invalid marker token in strict mode.
  - Reject non-`r` tags in strict relay-list extraction API.
- Acceptance criteria:
  - Accept valid replaceable event and extract relay permissions deterministically.

### NIP-70 Protected Events

- Canonical rules:
  - Presence of tag `['-']` marks event as protected.
  - Default relay behavior must reject protected events.
  - Relay may accept only after NIP-42 AUTH and pubkey equality between authenticated key and
    event author pubkey.
- Limits:
  - Tag form is exactly one-item array `['-']`.
- Rejection/failure criteria:
  - Reject by default when protected tag exists and no successful auth context is present.
  - Reject if authenticated pubkey != event pubkey.
- Acceptance criteria:
  - Accept protected event only when authenticated author identity matches event pubkey.

### NIP-77 Negentropy Syncing

- Canonical rules:
  - Uses `NEG-OPEN`, `NEG-MSG`, `NEG-CLOSE`, `NEG-ERR` message family.
  - Initial `NEG-OPEN` carries subscription id, NIP-01 filter, and hex-encoded negentropy message.
  - `NEG-MSG` is bidirectional continuation.
  - Negentropy subscription ID namespace is separate from `REQ` subscription IDs.
  - Binary protocol is wrapped as hex string for Nostr transport.
- Limits:
  - Protocol v1 byte is `0x61`; items sorted by timestamp ascending then ID lexical ascending.
  - Timestamp value `2**64 - 1` reserved and must not appear in records.
  - IDs are 32 bytes.
- Rejection/failure criteria:
  - Reject malformed hex payload framing.
  - Reject unsupported protocol version (reply with highest supported version semantics).
  - Reject oversized/blocked stateful queries via `NEG-ERR` and close subscription.
- Acceptance criteria:
  - Accept session when message framing, filter parse, version, and state transitions are valid.

## Interaction Matrix

| Primary NIP | Interacts With | Interaction Type | Implementation Order Constraint |
| --- | --- | --- | --- |
| 01 | 09, 12, 13, 16, 20, 33, 42, 45, 50, 59, 70, 77 | Core event/message/filter semantics | Must be implemented first |
| 12/16/20/33 | 01 | Moved/alias behavior | No independent module semantics |
| 02 | 01, 65 | Kind-3 social graph and relay-hint overlap | After NIP-01 event parse |
| 09 | 01, 33 | Deletion references event IDs and addresses | After NIP-01/33 address parsing |
| 11 | 13, 40, 42, 50, 70, 77 | Capability and limit discovery | Independent parser, influences policy |
| 13 | 01, 59 | PoW over NIP-01 id; optional wrap anti-spam | Needs canonical NIP-01 id path |
| 19 | 21, 33, 65 | Human-facing references and coordinates | Independent codec after core hex model |
| 21 | 19 | URI wrapper around NIP-19 entities | After NIP-19 codec |
| 40 | 01, 59 | Expiry policy for events and wrapped layers | After tag parsing in NIP-01 |
| 42 | 01, 70, 59 | AUTH state for protected writes and wrapped access | Before NIP-70 enforcement |
| 44 | 01, 59 | Encrypted payload primitive for wrapped events | Before NIP-59 unwrap support |
| 45 | 01 | COUNT reuses NIP-01 filters and reason prefixes | After NIP-01 filter parser |
| 50 | 01, 11 | Search filter extension with optional discovery hints | After NIP-01 filter parser |
| 59 | 01, 13, 40, 42, 44, 70 | Layered wrapping, optional PoW/expiry/auth policies | After NIP-44 and NIP-01 verify path |
| 65 | 01, 02, 11 | Replaceable relay list and discovery tie-ins | After NIP-01 replaceable handling |
| 70 | 01, 42 | Protected publish gate by authenticated author | Requires NIP-42 state model |
| 77 | 01, 11 | Negentropy filter sync with relay policy limits | After NIP-01 filter parser |

## Ambiguity Register

| ID | Topic | Impact | Status | Recommended Default |
| --- | --- | --- | --- | --- |
| `A-B-001` | Strict lowercase hex enforcement for `id/pubkey/sig` and filter hex lists | high | resolved | Require exact lowercase hex in strict mode; reject uppercase/mixed input. |
| `A-B-002` | Missing NIP-13 nonce difficulty commitment (`nonce[2]`) handling | medium | resolved | Accept PoW if hash difficulty passes; do not infer committed target when missing. |
| `A-B-003` | NIP-11 unknown/extra fields behavior | low | resolved | Ignore unknown fields, enforce only known-field type checks when present. |
| `A-B-004` | NIP-19 unknown TLV behavior | medium | resolved | Ignore unknown TLVs per spec; enforce required TLVs per entity type. |
| `A-B-005` | NIP-40 relay deletion timing strictness | low | resolved | Treat expiry as serve/publish policy gate; do not require immediate physical deletion. |
| `A-B-006` | NIP-42 relay URL matching strictness for `relay` tag | medium | resolved | Normalize minimally by scheme/host/port policy; reject clear mismatch. |
| `A-B-007` | NIP-45 HLL behavior for unsupported filter shapes | medium | resolved | Accept `count` without `hll`; require `hll` only for defined deterministic-offset cases. |
| `A-B-008` | NIP-50 extension token support variance | low | resolved | Ignore unsupported `key:value` tokens, preserve base search query behavior. |
| `A-B-009` | NIP-59 timestamp randomization requirement strictness | low | resolved | Treat as compatibility recommendation, not validity failure condition. |
| `A-B-010` | NIP-77 v1 depth in v1 scope (wrapper vs full optimization strategy) | medium | resolved | Implement wrapper framing and correctness; optimize incrementally in later phases. |
| `A-B-011` | Optional-NIP parity gate minimum vector counts | medium | resolved | Require at least 3 valid + 3 invalid vectors per optional NIP module in Phase D. |

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Tradeoffs

## Tradeoff T-B-001: Strict lowercase hex enforcement versus permissive normalization

- Context: ecosystem messages sometimes include uppercase hex, while NIP-01 text specifies lowercase.
- Options:
  - O1: strict lowercase-only acceptance.
  - O2: accept mixed-case and normalize to lowercase.
- Decision: O1.
- Benefits: deterministic canonical behavior and lower parser ambiguity.
- Costs: compatibility friction with permissive clients.
- Risks: some real-world events rejected despite otherwise valid bytes.
- Mitigations: make compatibility mode explicit and out-of-default path only.
- Reversal Trigger: verified parity corpus shows broad mixed-case dependence.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIP-01, NIP-13, NIP-42, all filter parsing surfaces.

## Tradeoff T-B-002: NIP-44 version exclusivity versus multi-version acceptance

- Context: NIP-44 documents versioned payloads but v2 is the only defined secure profile.
- Options:
  - O1: accept only v2 (`0x02`) in v1.
  - O2: add compatibility support for unknown/legacy versions.
- Decision: O1.
- Benefits: reduced cryptographic risk and simpler deterministic test corpus.
- Costs: no backward compatibility for deprecated/undefined variants.
- Risks: interop failures with outdated implementations.
- Mitigations: provide explicit unsupported-version error and migration guidance.
- Reversal Trigger: mandatory ecosystem interop requires another standardized version.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIP-44, NIP-59 unwrap path.

## Tradeoff T-B-003: NIP-70 default reject versus implicit trust publish

- Context: protected events can be abused if relays allow unauthenticated republish.
- Options:
  - O1: default reject protected events; accept only with authenticated author match.
  - O2: accept protected events without strict author-auth binding.
- Decision: O1.
- Benefits: explicit trust boundary and reduced unauthorized replay/republish risk.
- Costs: additional AUTH flow and state management complexity.
- Risks: relays without NIP-42 may reject legitimate protected writes.
- Mitigations: explicit `auth-required`/`restricted` response mapping and transcript tests.
- Reversal Trigger: standards update redefines protected-event acceptance contract.
- Principles Impacted: P01, P03, P04, P06.
- Scope Impacted: NIP-42, NIP-70, relay message flows.

## Tradeoff T-B-004: NIP-19 unknown TLV ignore versus strict fail-fast

- Context: NIP-19 allows unknown TLVs for forward compatibility.
- Options:
  - O1: ignore unknown TLVs, enforce required known TLVs only.
  - O2: fail decode on any unknown TLV.
- Decision: O1.
- Benefits: forward compatibility and ecosystem interop.
- Costs: more nuanced parser logic and test matrix.
- Risks: hidden unsupported metadata may be silently dropped.
- Mitigations: expose parsed-known fields and preserve strict structural checks.
- Reversal Trigger: security issue tied to unknown TLV acceptance.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: NIP-19, NIP-21.

## Tradeoff T-B-005: NIP-77 framing correctness versus full algorithmic optimization in v1

- Context: Negentropy allows deep optimization, but v1 scope prioritizes protocol kernel stability.
- Options:
  - O1: implement full wrapper framing correctness first; defer advanced optimization tactics.
  - O2: require full optimization strategy in initial v1 parity set.
- Decision: O1.
- Benefits: bounded implementation risk and faster deterministic conformance coverage.
- Costs: potential early performance inefficiency in large sync sets.
- Risks: perception of partial feature depth.
- Mitigations: keep wire-compatibility complete and schedule optimization in later phase gates.
- Reversal Trigger: measured bandwidth/cpu regressions exceed acceptable parity thresholds.
- Principles Impacted: P02, P03, P05, P06.
- Scope Impacted: NIP-77, Phase C/D implementation sequencing.

## Open Questions

- `OQ-B-001`: Verify in Phase D whether optional-NIP minimum vector gate (`3 valid + 3 invalid`)
  is sufficient to prevent drift under real corpus diversity. Status: accepted-risk.
- `OQ-B-002`: Validate in Phase C studies whether URL normalization policy for NIP-42 relay-tag
  matching should be host-only or host+normalized-path. Status: accepted-risk.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01` integrity boundary preserved by strict event verification, AUTH checks, and protected-event
  author binding (`B-001`, `B-004`, `T-B-003`).
- `P02` protocol-kernel scope preserved by keeping codec and sync primitives transport-agnostic
  and deferring non-essential optimization policy depth (`B-005`, `T-B-005`).
- `P03` interop-first behavior parity preserved through NIP-01-centric aliases and explicit
  optional-extension handling (`B-002`, `B-006`).
- `P04` explicit relay routing/trust semantics preserved through NIP-11 capability signaling,
  NIP-42 auth flow, and NIP-70 gate policy (`T-B-003`).
- `P05` deterministic outputs preserved by canonical serialization, tie-break rules, strict parsing,
  and fixed NIP-44 v2 framing requirements (`B-001`, `B-004`).
- `P06` bounded work/memory posture preserved by explicit size/range checks, typed failure modes,
  and constrained phase defaults (`B-003`, `T-B-005`).
- Ambiguity checkpoint gate: pass, with high-impact `decision-needed` count = 0.
