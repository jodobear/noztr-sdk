# Autonomous Loop: Phases 1-4

Autonomous execution loop for the next four `noztr-sdk` phases.

Date: 2026-03-14

This document turns the current `noztr-sdk` baseline into an execution loop that can be followed across
multiple sessions without re-deriving the process each time.

## Scope

This loop covers:
1. Phase 1: research refresh and planning update
2. Phase 2: Zig scaffold and local `noztr` integration
3. Phase 3: relay/session substrate
4. Phase 4: `NIP-46` remote signer session

It does not yet cover mailbox work, proof/identity adapters, or `NIP-29`.

## Core Rules

- Work phases in order unless a blocking dependency forces a documented reversal.
- Do not begin the next phase until the current phase has passed all review gates.
- If a phase discovers a kernel gap that belongs in `noztr`, stop broadening `noztr-sdk` and record the
  gap explicitly in `handoff.md`.
- Keep implementation slices small enough that each review pass can produce concrete findings.
- After every phase, update `handoff.md` and the affected planning docs before moving forward.

## Review Requirement

Each phase must complete at least these three reviews after implementation:

1. Boundary review
   - verify the work belongs in `noztr-sdk`, not `noztr`
   - verify the work is reusable SDK logic, not app-specific policy
2. Correctness review
   - inspect logic, failure paths, and invariants
   - run or add tests appropriate to the phase
3. API and ergonomics review
   - inspect naming, layering, coupling, and caller-facing clarity
   - compare against applesauce and rust-nostr only where useful

Recommended fourth review when the phase is large enough:

4. Documentation and handoff review
   - confirm the docs, examples, and handoff reflect the resulting behavior

If any review finds material issues:
- fix the findings
- rerun the failed review
- rerun any earlier review that the fix may have invalidated

The generic loop below is now superseded for future post-Phase-4 work by
[implementation-quality-gate.md](./implementation-quality-gate.md), but remains the accepted
closeout record for Phases 1-4.

## Generic Phase Loop

Use this loop for each phase:

1. Restate the phase goal and concrete exit criteria.
2. Write or refresh the pre-implementation packet from
   [implementation-quality-gate.md](./implementation-quality-gate.md).
3. Load only the docs and source files needed for that phase.
4. Reconfirm boundary answers before editing code.
5. Write the example-first API sketch for the slice.
6. Implement the smallest coherent slice that moves the phase forward.
7. Add or update tests immediately with the slice.
8. Run Review 1: boundary review.
9. Run Review 2: correctness review.
10. Run Review 3: API and ergonomics review.
11. Run Review 4: documentation and handoff review when needed.
12. If all required reviews pass, update `handoff.md` and move to the next phase.

## Phase 1: Research Refresh And Planning Update

### Goal

Refresh applesauce and rust-nostr references against current local mirrors and update `noztr-sdk`
planning artifacts so the next implementation phases use current evidence.

### Deliverables

- refreshed provenance in planning docs
- a concise upstream delta summary from the March 14, 2026 refresh
- any planning changes required by that delta

### Exit Criteria

- the planning baseline cites current local reference heads or explicitly states where a pinned
  snapshot remains in force
- no unresolved planning ambiguity blocks Phase 2 scaffold work

### Required Reviews

1. Boundary review
   - confirm the research changes do not push protocol behavior into `noztr-sdk`
2. Correctness review
   - verify provenance, commit hashes, and source paths are accurate
3. API and ergonomics review
   - confirm the refreshed findings still support a thin client facade with separate relay/store/
     policy layers

## Phase 2: Zig Scaffold And Local Noztr Integration

### Goal

Create the minimal `noztr-sdk` Zig package and prove it composes the local `../noztr` dependency.

### Deliverables

- `build.zig`
- `build.zig.zon`
- `src/root.zig`
- initial module directories and placeholder namespaces
- at least one smoke test proving `@import("noztr")` works from `noztr-sdk`

### Exit Criteria

- `zig build`
- `zig build test --summary all`
- local `noztr` path integration is documented and exercised

### Required Reviews

1. Boundary review
   - confirm the scaffold imports `noztr` instead of copying kernel helpers
2. Correctness review
   - verify build wiring, test step, and dependency metadata
3. API and ergonomics review
   - confirm the root namespace and module layout support a thin client facade and layered internals

## Phase 3: Relay/Session Substrate

### Goal

Build the first reusable SDK substrate for relay metadata, routing, auth/session state, and minimal
store/transport seams.

### Deliverables

- relay pool/session core
- `NIP-11` fetch/cache surface
- `NIP-65` routing-hint surface
- auth/session handling around `NIP-42`
- fake relay/http/store test helpers

### Exit Criteria

- transcript tests exist for key relay/session flows
- routing/auth behavior is explicit and documented
- no hidden singleton runtime has been introduced

### Required Reviews

1. Boundary review
   - confirm relay/session work is orchestration above `noztr`
2. Correctness review
   - inspect relay state transitions, retries, failure handling, and tests
3. API and ergonomics review
   - confirm relay, policy, sync, and store seams are distinct and caller-facing behavior is clear
4. Documentation and handoff review
   - update planning docs if the substrate forces a layout or transport decision

## Phase 4: NIP-46 Remote Signer Session

### Goal

Implement the first full SDK workflow on top of the substrate: a reusable `NIP-46` remote signer
client session.

### Deliverables

- connection-token handling
- request/response correlation
- secret validation
- relay switching
- auth challenge handling
- transcript tests covering successful and failing flows

### Exit Criteria

- the workflow composes `noztr.nip46_remote_signing` instead of re-implementing protocol messages
- the session can be exercised entirely through tests/fakes
- the public API is explicit about permissions, policy, and relay control

### Required Reviews

1. Boundary review
   - confirm only the session/orchestration logic lives in `noztr-sdk`
2. Correctness review
   - inspect correlation, secrets, auth challenge flow, and relay switching invariants
3. API and ergonomics review
   - confirm the workflow surface is reusable and does not collapse into a monolithic client
4. Documentation and handoff review
   - record usage shape, remaining gaps, and Phase 5 entry conditions

## Phase Transition Rules

- Phase 1 may modify plans only.
- Phase 2 may create scaffolding and tests, but must not silently drift into Phase 3 behavior.
- Phase 3 may introduce substrate modules, but `NIP-46` workflow specifics should stay out until
  Phase 4.
- Phase 4 may depend on the substrate, but mailbox or proof-verification helpers stay out of scope.

## Tracking

At the end of each phase, update:
- `handoff.md`
- `docs/plans/build-plan.md` if milestone order or defaults changed
- any phase-specific planning docs touched by the work

Phases 1-4 are complete.

The next unstarted milestone is `M4` (`NIP-17` mailbox/session orchestration), which is outside
this loop and should start from an explicit follow-on execution plan.

Phase 4 closeout notes:
- the final correctness rerun added coverage for malformed `sign_event` responses and oversized
  signer-declared errors
- `RemoteSignerSession` now clears pending entries when a matched response is invalid or rejected,
  so malformed terminal responses cannot leak request slots
- `NIP-46` signed-event results are still surfaced as caller-owned JSON text, but they are now
  protocol-validated through `noztr` before being returned
