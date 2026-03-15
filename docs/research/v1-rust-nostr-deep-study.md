# v1 rust-nostr Deep Study (Phase C2)

Date: 2026-03-05

Scope: H1-selected NIPs and v1 build-plan modules only.

## Source Provenance

- Local mirror path: `/workspace/pkgs/nostr/rust-nostr/nostr`
- Origin URL: `git@github.com:rust-nostr/nostr.git`
- Commit hash: `9bcc6cd779a7c6eb41509b37aee4575fa5ae47b9`
- Pin date: `2026-03-04` (frozen by `D-001`)
- Reproducibility note:
  - Verify snapshot with:
    - `git -C /workspace/pkgs/nostr/rust-nostr/nostr remote get-url origin`
    - `git -C /workspace/pkgs/nostr/rust-nostr/nostr rev-parse HEAD`
  - Study is valid only for this pinned commit and must be re-run after any `D-001` refresh.

## Decisions

- `C2-001`: adopt rust-nostr behavioral invariants for parsing, verification ordering, and wire
  transcript handling where they map to v1 scope, while re-implementing with Zig static-memory
  constraints.
- `C2-002`: adapt rust-nostr typed domain boundaries (`EventId`, `PublicKey`, `RelayUrl`,
  `SubscriptionId`) into fixed-size Zig structs and explicit error sets; do not import Rust
  allocator-driven collection models into kernel APIs.
- `C2-003`: reject Rust convenience/compatibility patterns that weaken strict deterministic
  contracts in v1 kernel modules (for example permissive parse fallbacks and mixed old/new wire
  shape acceptance on core paths).
- `C2-004`: treat rust-nostr as conformance and boundary-architecture evidence, not as API-shape
  template (`D-002`).

## Scoped Findings (v1 Modules)

| v1 module | rust-nostr evidence | Scoped finding | Enforceable recommendation |
| --- | --- | --- | --- |
| `nip01_event` | `/workspace/pkgs/nostr/crates/nostr/src/event/mod.rs`, `/workspace/pkgs/nostr/crates/nostr/src/event/id.rs` | Event model separates `verify_id`, `verify_signature`, and `verify`; ordering for replaceable tie-break is explicit (`created_at` then lexical `id`). | Keep three-step verify APIs in Zig; require deterministic ordering helper with dedicated tests for equal timestamp tie-break. |
| `nip01_filter` | `/workspace/pkgs/nostr/crates/nostr/src/filter.rs` | Filter uses typed fields plus generic `#x` tags; unknown malformed generic keys are ignored at deserialize (`{"#":[...],"aa":[...]}` test behavior). | Keep strict parser in `noztr` core: reject invalid `#` keys with typed errors; keep optional compatibility parser only outside strict default. |
| `nip01_message` | `/workspace/pkgs/nostr/crates/nostr/src/message/client.rs`, `/workspace/pkgs/nostr/crates/nostr/src/message/relay.rs` | Client/relay messages are typed enums with explicit JSON arity parsing; COUNT and OK/CLOSED machine-readable flows are modeled. | Adopt typed message unions and explicit parse states; enforce exact arity and field typing in strict mode, with no silent fallback branches. |
| `nip42_auth` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip42.rs` | Auth validation is a pure boundary predicate: `kind`, `relay` tag match, `challenge` tag match. | Keep auth boundary as pure validator in Zig; expose typed `InvalidKind`, `RelayMismatch`, `ChallengeMismatch` style failures instead of bool-only outcome. |
| `nip70_protected` | `/workspace/pkgs/nostr/crates/nostr/src/event/mod.rs`, `/workspace/pkgs/nostr/crates/nostr/src/event/tag/mod.rs` | Protected support is tag detection (`Tag::protected`, `event.is_protected`) without built-in auth gate coupling. | Preserve split: protected-tag detection in event module, acceptance policy in dedicated `nip70_protected` gate bound to authenticated pubkey context. |
| `nip09_delete` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip09.rs` | Deletion is modeled as builder input (`ids`, `coordinates`, reason) rather than a policy validator against target author. | Do not copy builder-only shape into kernel policy module; implement explicit `deletion_can_apply` checks for author/target/timestamp semantics in Zig. |
| `nip40_expire` | `/workspace/pkgs/nostr/crates/nostr/src/event/mod.rs`, `/workspace/pkgs/nostr/crates/nostr/src/event/tag/standard.rs` | Expiration parse is standardized tag decode and runtime check helper (`is_expired_at`). | Keep expiration as deterministic pure helper in `nip40_expire`; parse errors must be typed and non-expired default must only apply when tag is absent, not malformed. |
| `nip13_pow` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip13.rs`, `/workspace/pkgs/nostr/crates/nostr/src/event/id.rs` | Core bit-count primitive is isolated and reused by `EventId::check_pow`; helper for prefix generation is convenience-oriented and allocates. | Adopt leading-zero deterministic primitive; adapt API to fixed buffers and avoid dynamic prefix-generation helpers in kernel paths. |
| `nip19_bech32` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip19.rs` | Typed entity model and TLV decode are strong; unknown TLVs are ignored, and malformed optional author in `nevent` is tolerated (`PublicKey::from_slice(bytes).ok()`). | Keep typed decode results and required-field checks; in strict mode reject malformed optional typed TLVs that are present but invalid. |
| `nip21_uri` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip21.rs` | URI parser enforces `nostr:` scheme and rejects secret-key variants via typed `UnsupportedVariant`. | Adopt strict URI parser shape and explicit unsupported-variant error; keep `nsec` hard reject in strict default. |
| `nip02_contacts` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip02.rs`, `/workspace/pkgs/nostr/crates/nostr/src/event/tag/standard.rs` | Contact object type exists, but strict extraction policy is mostly implied via tag standardization elsewhere. | Implement dedicated strict extraction API in Zig for kind-3 `p` tags with explicit malformed-pubkey and invalid-tag-kind errors. |
| `nip65_relays` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip65.rs`, `/workspace/pkgs/nostr/crates/nostr/src/types/url.rs` | Relay metadata markers are typed (`read|write`), extraction returns iterators over normalized relay URL type. | Adopt typed marker parsing and URL type boundaries; enforce strict token validation and bounded output buffers in Zig APIs. |
| `nip44` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/mod.rs`, `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/v2.rs`, `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/nip44.vectors.json` | V2 implementation and vectors are thorough, but runtime uses dynamic `Vec` and HMAC compare uses `!=` slice equality (not explicit constant-time). | Adopt vector-driven conformance and staged checks; replace heap vectors with caller-owned buffers and enforce constant-time MAC compare helper in Zig. |
| `nip59_wrap` | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip59.rs` | Unwrap order is explicit (`gift_wrap kind -> decrypt seal -> verify seal -> decrypt rumor -> sender match`), with spoofing test for sender mismatch. | Adopt staged unwrap state machine and sender-consistency invariant with typed stage errors in Zig. |
| `nip45_count` | `/workspace/pkgs/nostr/crates/nostr/src/message/client.rs`, `/workspace/pkgs/nostr/crates/nostr/src/message/relay.rs` | COUNT modeled in both directions with typed message variants; relay-side count payload currently focuses on `count` integer only. | Keep strict COUNT shape parser; add optional `approximate`/`hll` hooks in dedicated extension module per v1 protocol reference. |
| `nip50_search` | `/workspace/pkgs/nostr/crates/nostr/src/filter.rs` | Search is integrated in filter type and gated at match-time via options (`opts.nip50`). | Adapt by isolating search semantics to extension module while preserving explicit opt-in gate in matching path. |
| `nip77_negentropy` | `/workspace/pkgs/nostr/crates/nostr/src/message/client.rs`, `/workspace/pkgs/nostr/crates/nostr/src/message/relay.rs` | Wire message family is supported in message layer (`NEG-OPEN`, `NEG-MSG`, `NEG-CLOSE`, `NEG-ERR`), including old/new `NEG-OPEN` shape compatibility. | Keep protocol framing support and typed state transitions; keep strict v1 default on one canonical message shape and gate legacy shape parsing behind explicit compatibility branch. |

## Transferable Patterns

- Typed domain boundaries for protocol primitives (`EventId`, `PublicKey`, `RelayUrl`,
  `SubscriptionId`) reduce shape ambiguity and improve error locality.
- Separation of parse/verify stages in event handling (`verify_id`, `verify_signature`, `verify`)
  maps directly to strict trust-boundary sequencing.
- Message enums for client/relay channels preserve transcript grammar and reduce ad hoc JSON logic.
- Protocol conformance driven by embedded vectors and invalid-case tests (notably NIP-44 v2) is
  directly transferable to Phase D vector contracts.
- Explicit extension toggles in logic paths (for example filter `nip50` match option) provide a
  clean model for optional NIP channel behavior without mutating core semantics.

## Non-Transferable Patterns

- Heap-backed collection defaults (`Vec`, `BTreeSet`, `BTreeMap`, `String`, `Cow`) are Rust-idiomatic
  but conflict with `noztr` static-allocation runtime policy.
- Permissive compatibility branches on strict paths (for example old/new NEG-OPEN shape acceptance)
  should not be default behavior in Zig core.
- Optional-field tolerance that silently drops invalid typed values (for example malformed optional
  `nevent` author key) should not be copied into strict kernel parsing.
- Bool-return boundary validators (for example NIP-42 helper) hide failure reason granularity needed
  for deterministic Zig error contracts.

## Adopt / Adapt / Reject Table

| Candidate | Decision | Evidence (rust-nostr source) | v1 modules impacted | Enforceable action |
| --- | --- | --- | --- | --- |
| Event verify split (`id`/`signature`/full) | Adopt | `/workspace/pkgs/nostr/crates/nostr/src/event/mod.rs` | `nip01_event`, `nip59_wrap`, `nip42_auth` | Keep separate Zig APIs and force tests for each failure mode. |
| Typed message enums for relay/client grammar | Adopt | `/workspace/pkgs/nostr/crates/nostr/src/message/client.rs`, `/workspace/pkgs/nostr/crates/nostr/src/message/relay.rs` | `nip01_message`, `nip45_count`, `nip77_negentropy` | Model each verb as explicit union variant with strict arity checks. |
| NIP-44 vector corpus inclusion and invalid-case mapping | Adopt | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/v2.rs`, `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/nip44.vectors.json` | `nip44`, `nip59_wrap` | Vendor pinned vectors and require valid+invalid path tests in Phase D. |
| Search extension gating as explicit option | Adapt | `/workspace/pkgs/nostr/crates/nostr/src/filter.rs` | `nip01_filter`, `nip50_search` | Keep opt-in gate but isolate field parsing to extension module boundary. |
| NIP-19 optional-field tolerance | Adapt | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip19.rs` | `nip19_bech32`, `nip21_uri` | Accept unknown TLVs, but reject present malformed typed TLVs in strict mode. |
| Legacy NEG-OPEN dual-shape parser in default path | Reject | `/workspace/pkgs/nostr/crates/nostr/src/message/client.rs` | `nip77_negentropy`, `nip01_message` | Keep one strict default shape; require explicit compatibility switch for legacy form. |
| Heap-centric collection strategy in protocol structs | Reject | `/workspace/pkgs/nostr/crates/nostr/src/filter.rs`, `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/mod.rs` | all v1 modules | Replace with fixed-capacity arrays and caller-owned buffers in public APIs. |
| Non-constant-time MAC equality in NIP-44 v2 | Reject | `/workspace/pkgs/nostr/crates/nostr/src/nips/nip44/v2.rs` | `nip44` | Implement constant-time compare helper and test mismatch timing-independent path. |

## Ambiguity Checkpoint

`A-C2-001`
- Topic: strict handling of legacy `NEG-OPEN` 5-element shape in v1 default parser.
- Impact: high.
- Status: resolved.
- Default: strict default accepts canonical v1 shape only; legacy shape allowed only in explicit
  compatibility entry point.
- Owner: active phase owner.

`A-C2-002`
- Topic: strictness for malformed optional typed TLVs in NIP-19 decode.
- Impact: medium.
- Status: resolved.
- Default: unknown TLV types remain ignored; known optional TLVs that are present but malformed are
  rejected in strict mode.
- Owner: active phase owner.

`A-C2-003`
- Topic: depth of NIP-45 optional field parsing (`approximate`, `hll`) in first strict contract.
- Impact: medium.
- Status: accepted-risk.
- Default: include typed fields and validation hooks now; final minimum vector depth remains Phase D
  gate work.
- Owner: active phase owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Tradeoffs

## Tradeoff T-C2-001: Reuse rust-nostr protocol boundaries versus full Zig-native redesign

- Context: rust-nostr has mature protocol boundaries; `noztr` must preserve bounded/static runtime
  constraints.
- Options:
  - O1: copy boundary APIs and internals directly.
  - O2: reuse behavioral boundaries and sequencing, re-implement with Zig-native static contracts.
- Decision: O2.
- Benefits: preserves parity-critical behavior while satisfying TigerStyle and static-memory policy.
- Costs: extra translation and contract-mapping work.
- Risks: missing subtle boundary assumptions during translation.
- Mitigations: map each adopted invariant to explicit module-level forcing tests.
- Reversal Trigger: repeated parity failures show boundary translation is insufficient.
- Principles Impacted: P02, P03, P05, P06.
- Scope Impacted: all v1 build-plan modules.

## Tradeoff T-C2-002: Strict parser defaults versus compatibility fallback for legacy wire shapes

- Context: rust-nostr accepts old/new negentropy open shapes; strict default policy (`D-003`) favors
  deterministic narrow acceptance.
- Options:
  - O1: accept both legacy and current shapes in strict parser.
  - O2: strict parser accepts canonical shape only; compatibility path is explicit and isolated.
- Decision: O2.
- Benefits: deterministic parser surface and reduced ambiguity at trust boundaries.
- Costs: compatibility users must opt into separate path.
- Risks: integration friction with legacy peers.
- Mitigations: provide compatibility adapter with explicit naming and tests.
- Reversal Trigger: high-value parity targets require legacy shape in default strict profile.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: `nip01_message`, `nip77_negentropy`.

## Tradeoff T-C2-003: Optional-field tolerance versus strict typed optional validation (NIP-19)

- Context: forward-compatibility suggests ignoring unknown TLVs; malformed known optional TLVs can
  hide data-quality issues.
- Options:
  - O1: ignore malformed optional known TLVs when base required fields parse.
  - O2: ignore unknown TLV types, but reject malformed known optional TLVs.
- Decision: O2.
- Benefits: forward compatibility without silently downgrading typed integrity.
- Costs: stricter rejection than some permissive implementations.
- Risks: interop friction on malformed ecosystem data.
- Mitigations: add compatibility adapter outside strict core path if needed.
- Reversal Trigger: standards-backed interoperability requirement demands permissive optional parsing.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: `nip19_bech32`, `nip21_uri`.

## Tradeoff T-C2-004: Reuse NIP-44 algorithm flow versus reusing Rust memory/comparison mechanics

- Context: rust-nostr NIP-44 flow and vectors are valuable, but runtime uses dynamic buffers and
  non-explicit constant-time MAC equality.
- Options:
  - O1: copy algorithm and runtime mechanics as-is.
  - O2: keep algorithm order and vectors, replace memory model and MAC compare with Zig-safe
    bounded/constant-time implementation.
- Decision: O2.
- Benefits: parity-preserving cryptographic behavior with stronger bounded-runtime and side-channel
  posture.
- Costs: higher implementation complexity in Zig.
- Risks: divergence from reference behavior if translation is incomplete.
- Mitigations: exhaustive vector parity tests and invalid-corpus checks.
- Reversal Trigger: inability to match vectors with bounded implementation approach.
- Principles Impacted: P01, P05, P06.
- Scope Impacted: `nip44`, `nip59_wrap`.

## Open Questions

- `OQ-C2-001`: confirm in Phase C4 whether strict `SubscriptionId` length enforcement should be
  centralized in `nip01_message` parse boundary or shared limit primitive (`status: accepted-risk`).
- `OQ-C2-002`: confirm in Phase D whether strict NIP-19 malformed-optional-TLV rejection needs a
  compatibility test profile switch for parity-optional consumers (`status: accepted-risk`).

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary integrity preserved by strict verify ordering, strict parser defaults, and
  explicit rejection of non-constant-time MAC comparison behavior.
- `P02`: protocol-kernel scope preserved by reusing wire invariants while rejecting Rust allocator/
  async convenience patterns in core APIs.
- `P03`: behavior parity prioritized over API mimicry through module-by-module invariant mapping to
  v1 build-plan contracts.
- `P04`: relay/auth semantics remain explicit via typed NIP-42 checks and message-prefix handling.
- `P05`: deterministic outputs reinforced via canonical event id flow, strict message arity parsing,
  and vector-backed NIP-44 conformance.
- `P06`: bounded memory/work preserved by rejecting heap-centric runtime patterns and enforcing
  caller-owned buffers plus fixed-capacity Zig contracts.
- Phase closure gate check: high-impact ambiguities with status `decision-needed` = 0.
