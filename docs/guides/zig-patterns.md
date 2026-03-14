# Zig Patterns For `noztr` (v1-scoped)

Date: 2026-03-05

This guide is the approved Zig implementation baseline for v1 modules. Every pattern here is
stdlib-first, bounded, deterministic, and enforceable with direct tests. Approved pinned crypto
backends remain boundary-only exceptions recorded in the decision log.

## Decisions

- `C0-P-001`: core module APIs are caller-buffer-first and return typed error sets.
- `C0-P-002`: strict parser/validator behavior is default; compatibility behavior is opt-in only.
- `C0-P-003`: runtime paths use fixed-capacity state and avoid post-init dynamic growth.
- `C0-P-004`: every public function must expose preconditions, postconditions, and forcing tests.

## Module Pattern Map (Required)

| Module | Required safe patterns | Minimum forcing tests |
| --- | --- | --- |
| `nip01_event` | canonical byte serialization; split `verify_id`/`verify_signature`/`verify`; fixed-size event fields | invalid id, invalid sig, equal-`created_at` tie-break by lexical `id`, max tags/content bounds |
| `nip01_filter` | explicit `u16/u32` counts; strict `#x` key validation; pure match function | invalid `#` key, max list bounds, `since<=until`, OR-of-filters behavior |
| `nip01_message` | typed union grammar; exact array arity checks; transcript state helper with bounded steps | malformed command, malformed arity, `REQ->EVENT*->EOSE->CLOSE`, strict unknown command reject |
| `nip42_auth` | pure auth predicate + typed failures; challenge state with bounded storage | wrong kind, relay mismatch, challenge mismatch, stale timestamp reject |
| `nip70_protected` | protected-tag detection separated from accept policy | `['-']` accepted as protected tag shape only, unauthenticated reject, pubkey mismatch reject |
| `nip09_delete` | author-bound target checks; explicit `e`/`a` tag parse stages | empty target reject, cross-author reject, timestamp-bound address delete |
| `nip40_expire` | strict integer parse for `expiration`; pure boundary helper | malformed expiration rejects, exact boundary second behavior |
| `nip13_pow` | deterministic leading-zero count; strict nonce-tag shape parser | malformed nonce tags reject, target met/not met branches |
| `nip19_bech32` | strict HRP dispatch; TLV bounded parser with required-field checks | bad checksum, mixed-case reject, malformed known optional TLV reject |
| `nip21_uri` | strict `nostr:` parser; `nsec` hard-reject in strict mode | non-`nostr:` reject, `nostr:nsec` reject, valid entity pass |
| `nip02_contacts` | strict kind-3 `p` extraction with fixed output buffer | non-`p` tag reject in strict path, malformed pubkey reject, bounded extraction |
| `nip65_relays` | strict marker token parse (`read`/`write`/empty); typed URL validation boundary | unknown marker reject, malformed URL reject, dedupe stability |
| `nip44` | staged decrypt checks (length->version->MAC->decrypt->padding); constant-time MAC compare; secret wipe via `defer` | invalid length, invalid version, invalid MAC, invalid padding, vector parity |
| `nip59_wrap` | staged unwrap (`wrap->seal->rumor`) with typed stage errors | bad outer kind, bad seal signature, sender mismatch spoof reject |
| `nip45_count` | strict COUNT grammar + optional metadata validator gates | malformed count object reject, invalid `hll` length reject, valid `count` pass |
| `nip50_search` | extension-only parser path; no core parser mutation | non-string search reject, extension token ignore policy test |
| `nip77_negentropy` | strict message family parser; bounded session state; deterministic item ordering | malformed hex reject, version reject, ordering invariant |
| `nip11` | partial-document acceptance + strict known-field type checks | unknown-field ignored, known-field type mismatch reject |

## Cross-Module Safe Patterns

1. Boundary error sets
   - Keep parse/encode/verify errors distinct.
   - Do not return broad `error.Invalid` for public APIs.

2. Explicit integer widths
   - Use `u16`/`u32`/`u64` that match protocol surfaces.
   - Never serialize or persist `usize`.

3. Staged parse and validate
   - Stage 1: input cap check.
   - Stage 2: shape parse.
   - Stage 3: semantic checks.
   - Stage 4: state mutation or cryptographic operation.

4. Caller-owned buffers
   - `output: []u8` and return `[]const u8` written length.
   - Return `error.BufferTooSmall` without truncation.

5. Assertion-pair template
   - Positive space: expected invariant (`count <= max`).
   - Negative space: forbidden branch is asserted/typed (`count > max -> error.TooManyItems`).

6. Constant-time and wipe boundaries
   - Length-check first, then branchless byte diff accumulation.
   - Wipe sensitive temporaries using dedicated helper with `defer`.

7. Deterministic vectors
   - Keep valid and invalid corpus for every module.
   - Include max/min boundaries and malformed-shape corpus.

## Tradeoffs

## Tradeoff T-C0-001: Strict typed boundaries versus convenience parsing

- Context: convenience parsing reduces call-site work but increases ambiguity.
- Options:
  - O1: permissive parser with silent normalization.
  - O2: strict parser with explicit compatibility adapters.
- Decision: O2.
- Benefits: deterministic failure contracts and safer trust boundaries.
- Costs: adapter work for permissive ecosystem inputs.
- Risks: compatibility friction in early integration.
- Mitigations: isolated compatibility entry points with forcing tests.
- Reversal Trigger: parity corpus shows strict path blocks required behavior.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: all v1 parse modules.

## Tradeoff T-C0-002: Caller-owned buffers versus allocator-returned values

- Context: allocator-return APIs are ergonomic but can hide growth and ownership ambiguity.
- Options:
  - O1: allocate outputs in library APIs.
  - O2: require caller buffers for runtime encode/decode paths.
- Decision: O2.
- Benefits: bounded memory and explicit ownership.
- Costs: larger call-site surface.
- Risks: callers may undersize buffers.
- Mitigations: size constants and `BufferTooSmall` forcing tests.
- Reversal Trigger: repeated measured overhead from buffer plumbing without safety gain.
- Principles Impacted: P02, P05, P06.
- Scope Impacted: `nip01_event`, `nip01_message`, `nip19_bech32`, `nip44`, `nip59_wrap`.

## Open Questions

- `OQ-C0-P-001`: finalize whether strict and compatibility entry points share one file or split by
  `compat/` namespace in Phase C4 (status: accepted-risk).

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: strict cryptographic and trust-boundary validation requirements are explicit.
- `P02`: module boundaries remain protocol-kernel oriented and transport-agnostic.
- `P03`: behavior parity is preserved through deterministic parser and transcript requirements.
- `P04`: auth/protected decisions are explicit in dedicated modules (`nip42_auth`, `nip70_protected`).
- `P05`: deterministic serialization, ordering, and staged checks are required across all modules.
- `P06`: bounded memory/work is enforced via fixed-capacity state and caller-owned buffers.
