# Zig Anti-Patterns For `noztr` (v1-scoped)

Date: 2026-03-05

This guide lists high-risk Zig footguns seen in protocol and cryptography work and the required safe
replacement pattern for `noztr` modules.

## Decisions

- `C0-A-001`: every high-risk footgun has a mandatory safe replacement pattern.
- `C0-A-002`: anti-pattern checks are enforced by forcing tests, not review comments only.
- `C0-A-003`: strict defaults apply; compatibility behavior is always explicit and isolated.

## High-Risk Footguns and Safe Replacements

| Footgun | Why high risk | Forbidden pattern | Required safe pattern | Primary modules |
| --- | --- | --- | --- | --- |
| `usize` in protocol structs | architecture-dependent width leaks into wire/state contracts | serialize/store `usize` fields | use explicit `u16/u32/u64` matching protocol bounds | all modules |
| broad error funnel | root-cause loss breaks deterministic contracts | `catch |_| return error.Invalid` | map each parse/verify failure to typed error variant | all parse/verify modules |
| parse + mutate in one pass | partial state mutation on malformed input | mutate output/state before all semantic checks complete | staged parser: cap -> shape -> semantic -> mutate | `nip01_event`, `nip01_message`, `nip44`, `nip59_wrap` |
| implicit heap growth | violates bounded memory policy | `ArrayList` growth in runtime path | fixed-capacity arrays + caller slices + `BufferTooSmall` | all runtime modules |
| compatibility-in-default path | hidden semantics drift at trust boundaries | silently accept legacy/alternate shapes | strict default parser; explicit compatibility entry point | `nip01_filter`, `nip77_negentropy`, `nip19_bech32` |
| non-canonical hashing input | signature/hash mismatch across implementations | hash pretty/unsorted JSON text | hash canonical byte form only | `nip01_event`, `nip59_wrap` |
| early return without secret wipe | secret material remains in memory | return from crypto branch before wipe | `defer` + dedicated wipe helper for every secret buffer | `nip44`, `nip59_wrap` |
| non-constant-time MAC compare | side-channel leakage on mismatch position | direct `std.mem.eql` for MAC branch | branchless diff accumulation after length check | `nip44` |
| compound condition branches | branch coverage gaps and missed negative space | `if (a and b and c)` | split checks into explicit branches and typed errors | all modules |
| silent clamp/truncate | hides malformed input and changes semantics | auto-clamp lengths, truncate tags | reject with typed error (`TooLong`, `InvalidField`) | `nip01_event`, `nip01_filter`, `nip65_relays` |
| bool-only boundary validators | no observable failure reason, weak diagnostics | `fn validate(...) bool` | return typed error union with precise variants | `nip42_auth`, `nip21_uri`, `nip11` |
| shared mutable decode scratch | hidden aliasing and stale state bugs | global mutable scratch buffers | caller-provided scratch per operation | `nip01_event`, `nip01_message`, `nip77_negentropy` |

## Module-Specific Anti-Pattern Triggers

- `nip01_event`: reject duplicate-key ambiguity, mixed-case hex acceptance, and id/sig co-validation
  in one branch.
- `nip01_filter`: reject invalid `#` tag key forms, over-broad generic field acceptance.
- `nip01_message`: reject unknown command coercion and arity auto-fix behavior.
- `nip42_auth`: reject bool-only auth result and challenge overwrite without state checks.
- `nip70_protected`: reject implicit allow path when auth context is absent.
- `nip09_delete`: reject deletion effect without pubkey binding checks.
- `nip40_expire`: reject malformed expiration interpreted as not-expired.
- `nip13_pow`: reject nonce parsing that defaults malformed values to zero.
- `nip19_bech32`: reject required-field inference from malformed TLVs.
- `nip21_uri`: reject regex-only mention parsing as URI validation.
- `nip02_contacts`: reject mixed contact/event parsing in one generic helper.
- `nip65_relays`: reject unknown marker token fallback to "both".
- `nip44`: reject decrypt-before-MAC flow and heap-built payload staging.
- `nip59_wrap`: reject unwrap stages that skip outer signature verification.
- `nip45_count`: reject count payload coercion from non-object/non-int values.
- `nip50_search`: reject extension behavior leaking into core filter parser by default.
- `nip77_negentropy`: reject default acceptance of legacy `NEG-OPEN` wire shape.
- `nip11`: reject full-document failure on unknown field when known fields are valid.

## Enforceable Checks

- Add one invalid test per anti-pattern trigger for each module listed above.
- Add one positive test that demonstrates the safe pattern for the same boundary.
- Keep failure assertions precise to error variant, not just non-success.

## Tradeoffs

## Tradeoff T-C0-003: Strict anti-pattern rejection versus permissive interoperability shortcuts

- Context: permissive behavior can increase apparent interop but weakens deterministic safety.
- Options:
  - O1: permit selected anti-pattern shortcuts where common in ecosystem data.
  - O2: reject anti-patterns in strict defaults and isolate compatibility behavior.
- Decision: O2.
- Benefits: predictable contracts and reduced trust-boundary ambiguity.
- Costs: additional compatibility adapter maintenance.
- Risks: early integration friction with permissive peers.
- Mitigations: explicit compatibility modules and vector-backed policy docs.
- Reversal Trigger: standards-backed requirement that strict rejection blocks parity goals.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: all v1 modules.

## Open Questions

- `OQ-C0-A-001`: determine in Phase C4 whether anti-pattern forcing tests should be required in the
  same file as happy-path vectors or in dedicated `*_invalid` suites (status: accepted-risk).

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary footguns are explicitly blocked with safe replacements.
- `P02`: module-level anti-pattern triggers preserve kernel-only boundaries.
- `P03`: strict defaults remain interop-focused through explicit, testable compatibility boundaries.
- `P04`: relay/auth policy shortcuts are explicitly forbidden.
- `P05`: canonical and deterministic behavior protections are enforced.
- `P06`: bounded memory/work violations are explicitly identified and rejected.
