# Nostr Principles

Canonical design principles for noztr planning and implementation.

## Frozen Defaults

These defaults are frozen for the current planning cycle.
Change requires a new entry in `docs/plans/decision-log.md`.

- `D-001` Parity baseline source:
  - applesauce
    - local: `/workspace/pkgs/applesauce`
    - upstream: `git@github.com:hzrd149/applesauce.git`
    - commit: `5f152fc98e5baa97e8176e54ce9b9345976c8b32`
  - rust-nostr
    - local: `/workspace/pkgs/nostr`
    - upstream: `git@github.com:rust-nostr/nostr.git`
    - commit: `9bcc6cd779a7c6eb41509b37aee4575fa5ae47b9`
  - libnostr-z
    - local: `/workspace/pkgs/libnostr-z`
    - upstream: `git@github.com:privkeyio/libnostr-z.git`
    - commit: `a849dc804521801971f42d71c172aa681ecdc573`
  - pin date: `2026-03-04`
  - parity sources are strong implementation references and ecosystem signals, not protocol
    authority.
- `D-002` Parity definition:
  - parity means behavior parity (parse, validate, serialize, verify, and tests),
    not API shape parity.
  - `rust-nostr` is the primary active parity lane because it is a strong production reference and a
    useful ecosystem-compatibility proxy, not because it is cardinal truth.
  - parity review is intended to improve compatibility confidence and teach implementation lessons;
    it does not forbid a better Zig-native contract when the NIPs and explicit reasoning support it.
- `D-036` Deterministic-and-compatible protocol posture:
  - Layer 1 chooses the narrowest deterministic behavior that remains correct, bounded, explicit,
    and ecosystem-compatible.
  - malformed, cryptographically invalid, ambiguity-creating, or safety-eroding input is rejected
    at trust boundaries.
  - compatibility behavior remains explicit when it would otherwise blur Layer 1 contracts, but the
    project does not optimize for strictness as an end in itself.
- `D-004` Phase gate policy:
  - no phase closes without tradeoff records and ambiguity checkpoint results.

## Decisions

- `P01` Rule: reject cryptographically invalid events (`id`, `pubkey`, `sig`) at all
  trust boundaries.
  - Rationale: signed data is the minimum integrity contract that preserves
    authenticity without trusted intermediaries.
- `P02` Rule: keep core protocol modules minimal, composable, and transport-agnostic.
  - Rationale: simple primitives maximize implementability and reduce hidden coupling.
- `P03` Rule: optimize for interop convergence and behavior parity before stylistic purity or
  convenience.
  - Rationale: network effects depend on shared behavior, and correctness is stronger when explicit
    bounds do not create avoidable ecosystem friction.
- `P07` Rule: keep Zig-native API and implementation guarantees as a first-class feature, not a
  concession.
  - Rationale: behavior parity does not require foreign API mimicry, and Zig's explicit,
    bounded-system style is part of the library's value.
- `P04` Rule: encode relay routing as explicit heuristics and inputs, never implicit
  resolver magic.
  - Rationale: predictability and auditability are required for partition-tolerant
    discovery.
- `P05` Rule: require deterministic outputs for parse/serialize/verify operations for
  identical inputs.
  - Rationale: deterministic behavior is required for reproducible signatures, vectors,
    and cross-implementation parity.
- `P06` Rule: enforce bounded memory and bounded work for all runtime paths.
  - Rationale: static limits and explicit failure modes are required for safe,
    production-grade Zig systems.

## Anti-Goals And Forbidden Shortcuts

- Anti-goal: treat relay/network convenience as more important than user agency and
  verifiable data ownership.
- Anti-goal: add broad compatibility behavior that silently rewrites or normalizes
  invalid protocol data.
- Anti-goal: reject valid or widely interoperable input solely to express implementation purity.
- Anti-goal: optimize for one mega-relay or hidden global resolver assumptions.
- Forbidden shortcut: accepting invalid signatures "for UX" or "for compatibility".
- Forbidden shortcut: auto-repairing malformed fields during parse without emitting a
  typed error or explicit compatibility branch.
- Forbidden shortcut: narrowing accepted behavior beyond the NIP or real ecosystem need without a
  documented tradeoff and compatibility review.
- Forbidden shortcut: reinventing functionality already provided by Zig stdlib, approved backend
  boundaries, or existing in-repo utilities unless a concrete bounded-contract gap is documented.
- Forbidden shortcut: coupling core APIs to one transport stack, one relay provider,
  or one app-specific workflow.
- Forbidden shortcut: introducing dynamic, unbounded allocation growth in hot paths.
- Forbidden shortcut: closing a phase with high-impact ambiguity tagged
  `decision-needed`.

## Ambiguity Checkpoint

`A-0-001`
- Topic: `D-001` snapshot refresh cadence.
- Impact: medium.
- Status: accepted-risk.
- Default: update pinned commits only when parity-impacting upstream changes are
  required by the active phase scope.
- Owner: active phase owner.

`A-0-002`
- Topic: remote URL normalization in planning artifacts.
- Impact: low.
- Status: resolved.
- Default: retain source-authentic upstream URLs in canonical records; normalize only
  in explanatory prose.
- Owner: active phase owner.

`A-0-003`
- Topic: deterministic trust-boundary posture and compatibility boundary.
- Impact: high.
- Status: resolved.
- Default: hard-reject malformed, cryptographically invalid, ambiguity-creating, or unsafe input;
  prefer the narrowest deterministic behavior that remains ecosystem-compatible, and document any
  meaningful narrowing or widening with explicit tradeoffs and forcing tests.
- Owner: active phase owner.

## Tradeoffs

## Tradeoff T-0-001: Deterministic trust boundaries versus broad compatibility

- Context: ecosystem data quality varies, but NIPs also intentionally leave room for multiple valid
  implementations; a kernel can become correct-yet-isolated if it rejects every broader shape.
- Options:
  - O1: deterministic, explicit, bounded defaults with compatibility-preserving behavior where the
    input remains unambiguous and safe.
  - O2: broad permissive acceptance with minimal rejection and post-hoc normalization.
- Decision: O1.
- Benefits: predictable semantics, lower attack surface, stronger conformance, and lower risk of
  needless ecosystem incompatibility.
- Costs: more judgment is required when deciding whether a broader shape is valid compatibility or
  unacceptable ambiguity.
- Risks: some ecosystem inputs may still be rejected if the project over-narrows the boundary.
- Mitigations: require parity review, real compatibility evidence, and explicit documented rationale
  before freezing narrower behavior.
- Reversal Trigger: the posture still produces recurring unnecessary incompatibility or, in the
  other direction, starts to blur trust-boundary guarantees.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: phase A classification, phase B parsing policy, phase D APIs.

## Tradeoff T-0-002: Behavioral parity versus API parity

- Context: libnostr-z API choices include dependency and allocation assumptions.
- Options:
  - O1: match behavior and vectors; keep Zig-native API.
  - O2: clone external API shapes for easier migration.
- Decision: O1.
- Benefits: Zig-native, bounded interfaces aligned with project constraints.
- Costs: migration from external APIs needs adapters.
- Risks: parity claims could be interpreted ambiguously.
- Mitigations: define parity as behavior+tests in scope and decision log, and state explicitly that
  reference libraries inform compatibility confidence rather than override NIP authority.
- Reversal Trigger: adopter demand for API-level parity exceeds maintenance cost.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: phase A scope semantics, C3 parity mapping, D contracts.

## Tradeoff T-0-003: Hard integrity failure versus permissive recovery

- Context: malformed and adversarial events are common in open relay ecosystems.
- Options:
  - O1: reject cryptographic invalidity and bounds violations immediately.
  - O2: attempt best-effort recovery from invalid cryptographic or structural input.
- Decision: O1.
- Benefits: prevents forgery acceptance and reduces exploit surface.
- Costs: fewer events are accepted from non-conformant producers.
- Risks: operators may perceive strict handling as reduced compatibility.
- Mitigations: document explicit compatibility exceptions and add regression vectors.
- Reversal Trigger: a standards-backed compatibility case cannot be handled without
  violating current failure policy.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: phase A scope gate, phase B parser policy, phase D error contracts.

## Tradeoff T-0-004: Mandatory phase closure gate versus execution speed

- Context: D-004 requires every phase closure to include tradeoff records and
  ambiguity checkpoint results to preserve planning traceability.
- Options:
  - O1: require both tradeoff records and ambiguity checkpoint before phase close.
  - O2: allow phase closure with partial evidence and fill gaps later.
- Decision: O1.
- Benefits: stronger audit trail, reduced decision drift, earlier detection of
  unresolved high-impact ambiguity.
- Costs: additional process overhead and slower phase close cadence.
- Risks: teams may treat required artifacts as checklists without substantive
  analysis.
- Mitigations: require explicit IDs, canonical fields, and phase closure evidence
  records in the decision log.
- Reversal Trigger: repeated evidence that mandatory closure artifacts increase
  lead time without reducing ambiguity or rework.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: all planning phases, phase closure evidence records, decision
  traceability policy.

## Open Questions

- `OQ-0-001` (from `A-0-001`): verify by end of Phase A whether parity-impact-only
  `D-001` refresh cadence remains sufficient for all selected v1 features.
- `OQ-0-002` (from `A-0-002`): decide in Phase A if a repo-wide URL style guide is
  needed beyond canonical decision records.

## Principles Compliance

Use this checklist for every phase before closure.

- Required sections present in every phase artifact: `Decisions`, `Tradeoffs`,
  `Open Questions`, `Principles Compliance`.
- Every material decision maps to at least one `T-<phase>-<number>` tradeoff entry.
- Every ambiguity has an ID and fields: topic, impact, status, default, owner.
- Phase closure gate: zero high-impact ambiguities with status `decision-needed`.
- Every principle `P01`..`P06` has at least one explicit citation in phase outputs.
- Every conformance claim is test-backed:
  - deterministic vector or transcript fixture for behavior claims,
  - explicit error-path test for rejection/compatibility claims,
  - documented bounds check for memory/work-limit claims.
