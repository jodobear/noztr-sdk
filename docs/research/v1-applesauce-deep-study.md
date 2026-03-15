# v1 Applesauce Deep Study (Phase C1)

Date: 2026-03-05

Scope: H1-selected NIPs and v1 build-plan modules only.

## Source Provenance

- Local mirror path: `/workspace/pkgs/nostr/applesauce`
- Origin URL: `git@github.com:hzrd149/applesauce.git`
- Commit hash: `5f152fc98e5baa97e8176e54ce9b9345976c8b32`
- Pin date: `2026-03-04` (frozen by `D-001`)
- Reproducibility note:
  - Verify snapshot with:
    - `git -C /workspace/pkgs/nostr/applesauce remote get-url origin`
    - `git -C /workspace/pkgs/nostr/applesauce rev-parse HEAD`
  - Study is valid only for this pinned commit and must be re-run after any `D-001` refresh.

## Decisions

- `C1-001`: adopt applesauce edge-case patterns only when they are protocol-kernel compatible
  (bounded, deterministic, framework-agnostic).
- `C1-002`: adapt relay/auth/message flow patterns from `applesauce-relay` into strict typed
  `noztr` kernel contracts; do not adopt RxJS state machinery.
- `C1-003`: reject app-layer convenience defaults (dynamic object mutation, cached symbols,
  implicit normalization) for core modules.
- `C1-004`: treat applesauce as parity behavior evidence, not API-shape guidance (`D-002`).

## Scoped Findings (v1 Modules)

| v1 module | Applesauce evidence | Scoped finding | Enforceable recommendation |
| --- | --- | --- | --- |
| `nip01_event` | `/workspace/pkgs/applesauce/packages/core/src/helpers/event.ts`, `/workspace/pkgs/applesauce/packages/core/src/event-store/event-store.ts` | Event identity and replaceable addressing are explicit, but validation is delegated to `nostr-tools` and event objects are mutated with runtime symbols. | Keep replaceable-address semantics; implement fully local parse/hash/verify in `noztr`; forbid runtime object mutation in kernel structs. |
| `nip01_filter` | `/workspace/pkgs/applesauce/packages/core/src/helpers/filter.ts` | Filter matching includes NIP-91 extensions (`&x`) and NIP-50 `search` pass-through. | Keep strict NIP-01 parser as default; gate NIP-50/optional fields to extension modules only. |
| `nip01_message` | `/workspace/pkgs/applesauce/packages/relay/src/relay.ts` | Message handling shows robust transcript behavior (`REQ/CLOSE/EOSE`, timeouts, id correlation). | Adopt transcript-state invariants; replace dynamic arrays with typed Zig message unions and explicit error sets. |
| `nip42_auth` | `/workspace/pkgs/applesauce/packages/relay/src/relay.ts` | `auth-required:` retry flow and challenge tracking are explicit and test-covered. | Adopt challenge-state transitions and retry boundary; require strict tag/kind/time checks in kernel auth validator. |
| `nip70_protected` | `/workspace/pkgs/applesauce/packages/core/src/helpers/event.ts`, `/workspace/pkgs/applesauce/packages/core/src/operations/event.ts` | Protected status is only tag presence (`["-"]`), enforcement is relay-layer policy. | Keep tag detection primitive in `nip01_event`; enforce acceptance gate only in `nip70_protected` with authenticated pubkey equality. |
| `nip09_delete` | `/workspace/pkgs/applesauce/packages/core/src/helpers/delete.ts`, `/workspace/pkgs/applesauce/packages/core/src/event-store/delete-manager.ts` | Author-bound deletion checks are explicit for both `e` and `a` paths, including timestamp bound for replaceables. | Adopt author-binding and `until` semantics; require typed parse errors for malformed pointers before policy evaluation. |
| `nip40_expire` | `/workspace/pkgs/applesauce/packages/core/src/helpers/expiration.ts`, `/workspace/pkgs/applesauce/packages/core/src/event-store/expiration-manager.ts` | Expiration parse and scheduling exist; invalid parse may produce `NaN`, then silently behave as not-expired. | Adapt with strict integer parsing and explicit `InvalidExpirationTag`; never treat malformed timestamp as valid non-expired state. |
| `nip13_pow` | `/workspace/pkgs/applesauce/packages/relay/src/__tests__/relay.test.ts` | No dedicated PoW validator module; nonce tags appear only in fixtures. | Reject parity borrowing here; implement standalone deterministic bit-count and nonce-tag parser in `noztr`. |
| `nip19_bech32` | `/workspace/pkgs/applesauce/packages/core/src/helpers/pointers.ts` | NIP-19 decode/encode wrappers are broad and convenience-first; normalization accepts multiple forms. | Adapt entity coverage and pointer ergonomics; keep strict decode API that separates parse failure from semantic failure. |
| `nip21_uri` | `/workspace/pkgs/applesauce/packages/core/src/helpers/regexp.ts`, `/workspace/pkgs/applesauce/packages/core/src/operations/content.ts` | URI handling is mention-oriented (`nostr:` regex), not a strict NIP-21 parser contract. | Reject direct reuse; implement dedicated strict URI parser with `nsec` rejection in strict mode. |
| `nip02_contacts` | `/workspace/pkgs/applesauce/packages/core/src/helpers/contacts.ts` | Kind-3 contact parsing supports public + hidden tags and relay JSON compatibility behavior. | Adapt only public `p`-tag extraction and relay JSON parse as optional compatibility helper; kernel path must not depend on hidden-tag decrypt flow. |
| `nip65_relays` | `/workspace/pkgs/applesauce/packages/core/src/helpers/mailboxes.ts`, `/workspace/pkgs/applesauce/packages/core/src/helpers/relays.ts` | Relay list extraction handles `read/write` markers and URL normalization/dedupe. | Adopt marker semantics and normalization invariants; enforce strict marker token validation (`read|write|empty`). |
| `nip44` | `/workspace/pkgs/applesauce/packages/core/src/helpers/encryption.ts`, `/workspace/pkgs/applesauce/packages/core/src/helpers/encrypted-content.ts` | NIP-44 is delegated to upstream crypto helpers and signer capabilities. | Reject dependency pattern; implement in-kernel NIP-44 v2 primitives and constant-time checks per build-plan contract. |
| `nip59_wrap` | `/workspace/pkgs/applesauce/packages/common/src/helpers/gift-wrap.ts`, `/workspace/pkgs/applesauce/packages/common/src/operations/gift-wrap.ts` | Wrap->seal->rumor flow and parent-link integrity are explicit and heavily tested. | Adopt staged unwrap order and author-consistency checks; reject mutable symbol graph in kernel and return explicit typed stage errors instead. |
| `nip45_count` | `/workspace/pkgs/applesauce/packages/relay/src/relay.ts`, `/workspace/pkgs/applesauce/packages/relay/src/types.ts` | COUNT shape is implemented with timeout/id correlation; response type is reduced to `{count}` only. | Adapt request/response flow; extend strict parser to validate optional `approximate`/`hll` where enabled. |
| `nip50_search` | `/workspace/pkgs/applesauce/packages/core/src/helpers/filter.ts`, `/workspace/pkgs/applesauce/packages/sqlite/src/helpers/search.ts` | Search is extension field + DB-specific indexing strategy. | Keep search as optional extension module; forbid DB-coupled indexing assumptions in protocol kernel. |
| `nip77_negentropy` | `/workspace/pkgs/applesauce/packages/relay/src/negentropy.ts`, `/workspace/pkgs/applesauce/packages/relay/src/lib/negentropy.ts` | Full `NEG-OPEN/NEG-MSG/NEG-CLOSE/NEG-ERR` flow and version/frame controls are present; implementation uses dynamic buffers and async streams. | Adopt protocol state machine and abort/error semantics; adapt into bounded static buffers and explicit step functions in Zig core. |

## App-Layer Ergonomics vs Protocol-Kernel Requirements

- App-layer ergonomics observed in applesauce:
  - RxJS-driven state (`Relay`, `EventStore` streams) and mutable symbol caches.
  - Convenience normalization APIs that accept many input forms.
  - Database-backed search and high-level event projection.
- Kernel requirements for `noztr`:
  - No reactive runtime or framework coupling in core modules.
  - No dynamic post-init allocation and no hidden mutation channels.
  - Typed parse/verify/serialize boundaries with deterministic outputs.

## Edge Cases Relevant to v1

- Replaceable/addressable delete safety:
  - Delete pointer author is force-bound to deleter (`delete.ts`, `delete-manager.ts`), preventing
    cross-author deletes.
- Address parsing corner case:
  - `parseReplaceableAddress()` can return `kind: NaN` for malformed kind strings
    (`pointers.ts`); kernel parser must reject this with a typed error.
- Expiration parsing corner case:
  - Invalid `expiration` parses to `NaN` and behaves as non-expired (`expiration.ts` + tests);
    kernel path must reject malformed tags explicitly.
- AUTH retry behavior:
  - `auth-required:` transitions block REQ/EVENT until successful AUTH (`relay.ts`, relay tests).
- COUNT behavior:
  - Single-shot COUNT with timeout and `CLOSED` failure path exists; optional NIP-45 fields are not
    modeled in type (`types.ts`).
- Negentropy version/error handling:
  - Unsupported protocol version and `NEG-ERR` are explicit in implementation
    (`lib/negentropy.ts`, `negentropy.ts`).

## Adopt / Adapt / Reject Table

| Candidate | Decision | Evidence (applesauce source) | v1 modules impacted | Enforceable action |
| --- | --- | --- | --- | --- |
| Author-bound delete enforcement and timestamp-bounded address deletion | Adopt | `/workspace/pkgs/applesauce/packages/core/src/helpers/delete.ts`, `/workspace/pkgs/applesauce/packages/core/src/event-store/delete-manager.ts` | `nip09_delete`, `nip01_event` | Implement identical author-binding invariants and explicit `until` checks. |
| Relay transcript correlation (`REQ/COUNT/EVENT` id matching, timeout paths) | Adopt | `/workspace/pkgs/applesauce/packages/relay/src/relay.ts` | `nip01_message`, `nip42_auth`, `nip45_count` | Preserve transcript invariants with typed message decoder and deterministic state transitions. |
| Gift-wrap staged unwrap and parent/author integrity checks | Adopt | `/workspace/pkgs/applesauce/packages/common/src/helpers/gift-wrap.ts` | `nip59_wrap`, `nip44` | Keep unwrap order and author-match invariant; map failures to typed stage errors. |
| NIP-19 pointer normalization convenience APIs | Adapt | `/workspace/pkgs/applesauce/packages/core/src/helpers/pointers.ts` | `nip19_bech32`, `nip21_uri` | Split into strict decode API and separate convenience adapter API; strict API MUST not auto-normalize invalid forms. |
| Relay URL normalization and dedupe in relay-list/contact extraction | Adapt | `/workspace/pkgs/applesauce/packages/core/src/helpers/relays.ts`, `/workspace/pkgs/applesauce/packages/core/src/helpers/mailboxes.ts`, `/workspace/pkgs/applesauce/packages/core/src/helpers/contacts.ts` | `nip65_relays`, `nip02_contacts` | Keep normalization for optional helpers; kernel validators MUST return typed errors for malformed marker/url tokens. |
| RxJS/event-store/symbol-cache architecture in core | Reject | `/workspace/pkgs/applesauce/packages/core/src/event-store/event-store.ts`, `/workspace/pkgs/applesauce/packages/relay/src/relay.ts` | all kernel modules | Do not import reactive runtime patterns into protocol kernel modules. |
| Upstream crypto dependency pattern for NIP-44 | Reject | `/workspace/pkgs/applesauce/packages/core/src/helpers/encryption.ts`, `/workspace/pkgs/applesauce/packages/core/src/helpers/encrypted-content.ts` | `nip44`, `nip59_wrap` | Implement NIP-44 v2 crypto locally in Zig stdlib-only code path. |
| Regex-only `nostr:` handling as NIP-21 implementation | Reject | `/workspace/pkgs/applesauce/packages/core/src/helpers/regexp.ts`, `/workspace/pkgs/applesauce/packages/core/src/operations/content.ts` | `nip21_uri` | Build dedicated strict NIP-21 parser; regex mention extraction remains app-layer utility only. |

## Ambiguity Checkpoint

`A-C1-001`
- Topic: whether to copy applesauce pointer normalization behavior into kernel NIP-19/NIP-21 APIs.
- Impact: high.
- Status: resolved.
- Default: kernel stays strict; convenience normalization moves to optional adapter layer.
- Owner: active phase owner.

`A-C1-002`
- Topic: whether NIP-45 optional fields (`approximate`, `hll`) remain omitted in first parser pass.
- Impact: medium.
- Status: resolved.
- Default: include strict optional-field parsing hooks in module contract; test gating deferred to Phase D vectors.
- Owner: active phase owner.

`A-C1-003`
- Topic: depth of initial NIP-77 implementation (state-machine correctness vs optimization depth).
- Impact: medium.
- Status: accepted-risk.
- Default: implement framing/state correctness first, optimization later (aligned with `B-005`).
- Owner: active phase owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Tradeoffs

## Tradeoff T-C1-001: Reuse applesauce flow logic versus strict kernel reimplementation

- Context: applesauce has proven relay/message flows but uses reactive runtime and dynamic structures.
- Options:
  - O1: copy flow logic and runtime patterns directly.
  - O2: reuse behavioral invariants only; reimplement with strict kernel constraints.
- Decision: O2.
- Benefits: preserves behavior parity while meeting static/bounded Zig requirements.
- Costs: additional implementation work and mapping effort.
- Risks: parity drift if invariants are not captured precisely.
- Mitigations: encode transcript vectors and explicit invariants in Phase D contracts/tests.
- Reversal Trigger: repeated conformance failures tied to missing runtime behavior assumptions.
- Principles Impacted: P02, P03, P05, P06.
- Scope Impacted: `nip01_message`, `nip42_auth`, `nip45_count`, `nip77_negentropy`.

## Tradeoff T-C1-002: Convenience normalization versus strict parse boundaries

- Context: applesauce normalization accepts multiple representations for pointers/urls.
- Options:
  - O1: allow broad normalization in kernel parse functions.
  - O2: keep strict parse boundaries; expose convenience only in adapters.
- Decision: O2.
- Benefits: deterministic failures, lower ambiguity, tighter security surface.
- Costs: callers must choose explicit adapter APIs for convenience.
- Risks: perceived ergonomics reduction for app teams.
- Mitigations: provide documented adapter layer after kernel contracts are stable.
- Reversal Trigger: validated interop blockers cannot be solved without relaxing strict parser APIs.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: `nip19_bech32`, `nip21_uri`, `nip65_relays`, `nip02_contacts`.

## Tradeoff T-C1-003: Dependency delegation for crypto versus local implementation

- Context: applesauce delegates NIP-44 to external crypto helpers.
- Options:
  - O1: delegate crypto to external dependency.
  - O2: implement NIP-44 v2 primitives in local stdlib-only kernel.
- Decision: O2.
- Benefits: satisfies zero-dependency policy and deterministic control of failure paths.
- Costs: more cryptographic implementation and test burden.
- Risks: implementation bugs without mature library fallback.
- Mitigations: strict vector coverage and negative corpus from Phase D.
- Reversal Trigger: proven inability to meet correctness/performance without external dependency.
- Principles Impacted: P01, P05, P06.
- Scope Impacted: `nip44`, `nip59_wrap`.

## Tradeoff T-C1-004: Stateful unwrap reference graph versus stateless staged decoding

- Context: applesauce gift-wrap helper maintains cross-linked object graph via symbols.
- Options:
  - O1: maintain cross-linked mutable references in kernel.
  - O2: use stateless staged decode outputs and explicit return structs.
- Decision: O2.
- Benefits: simpler memory bounds, clearer ownership, easier deterministic testing.
- Costs: fewer convenience backlinks for app-level traversal.
- Risks: adapter layers may need extra bookkeeping.
- Mitigations: keep optional high-level wrappers outside kernel.
- Reversal Trigger: performance evidence that stateless staging causes unacceptable overhead.
- Principles Impacted: P02, P05, P06.
- Scope Impacted: `nip59_wrap`, `nip44`, `nip01_event`.

## Open Questions

- `OQ-C1-001`: confirm in Phase C4 whether strict NIP-21 parser should reject bare bech32 inputs
  without `nostr:` prefix in all kernel entry points (status: accepted-risk).
- `OQ-C1-002`: confirm in Phase D whether optional NIP-45 `hll` validation should be default-on or
  feature-gated under extension build options (status: accepted-risk).

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: integrity boundaries preserved via explicit reject decisions for malformed auth/delete/
  wrap paths and no crypto-dependency delegation for core checks.
- `P02`: protocol-kernel scope preserved by rejecting RxJS/framework/app-store coupling in core modules.
- `P03`: behavior-parity-first approach retained by adopting transcript and lifecycle invariants.
- `P04`: relay/auth decisions remain explicit (`auth-required` flow, protected-event gate semantics).
- `P05`: deterministic parse/serialize/verify contract emphasis preserved for all mapped modules.
- `P06`: bounded work/memory posture preserved by adapting away from dynamic mutable graph patterns.
- Phase closure gate check: high-impact ambiguities with status `decision-needed` = 0.
