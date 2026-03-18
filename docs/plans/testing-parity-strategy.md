---
title: Noztr SDK Testing And Parity Strategy
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - designing_test_matrix
  - revisiting_parity_policy
depends_on:
  - docs/plans/implementation-quality-gate.md
---

# Noztr SDK Testing And Parity Strategy

Testing strategy for the first `noztr-sdk` implementation cycle.

Date: 2026-03-14

## Testing Goals

- prove SDK workflows compose `noztr` correctly
- keep session/store/transport behavior deterministic and replayable
- validate behavior parity where it matters without copying external API shapes
- catch protocol-boundary drift and state-machine bugs before a workflow is called complete

All new NIP-backed slices must declare their test matrix up front as required by
`docs/plans/implementation-quality-gate.md`.

## Parity Sources

Authority order:
1. NIP text
2. `noztr` kernel behavior and tests
3. local workflow evidence from applesauce
4. local workflow evidence from rust-nostr

Parity means:
- the SDK should preserve protocol-correct behavior when orchestrating kernel helpers
- the SDK should capture proven session/relay workflow invariants from reference implementations
- parity does not mean mirroring applesauce or rust-nostr naming, builders, or runtime models

## Test Layers

### Unit Tests

Use for:
- routing decisions
- cache/store reducers
- request/response correlation
- auth/session state transitions

These tests should prefer fake inputs and no network.

### Transcript Tests

Use for:
- relay message sequences
- `NIP-46` request/response and auth-challenge flows
- mailbox unwrap and inbox sync flows
- retry/failover behavior

Transcript tests should encode ordered steps and expected state transitions for identical replay.
They should also cover invalid terminal responses, relay switching, and resume/reconnect behavior
where the workflow supports those transitions.

### Adapter Tests

Use for:
- HTTP fetch adapters for `NIP-11`, `NIP-39`, and `NIP-03`
- WebSocket/relay transport adapters
- store adapters

Adapters should be tested against fake servers or fake transports before any live-network coverage
is considered.

### Integration Smoke Tests

Use for:
- import/wiring against the local `noztr` package
- end-to-end composition of one SDK workflow at a time

These tests should remain small and deterministic.

### Recipe Tests

Use for:
- structured examples that double as executable documentation
- end-to-end workflow recipes above the kernel boundary
- keeping the eventual `examples/` directory current with real SDK behavior

These should mirror the teaching posture used in `/workspace/projects/noztr/examples`, but at the
SDK orchestration layer.

## First Workflow Test Requirements

### Relay substrate

- relay metadata fetch success/failure/cache behavior
- `NIP-65` relay-list hydration and routing decision tests
- `NIP-42` auth-required transcript handling

### Remote signer session

- request id correlation
- connect secret validation
- relay switching behavior
- auth challenge hold-and-resume flow

### Mailbox session

- recipient relay discovery
- gift-wrap inbox parse and staged unwrap
- sender/room derivation checks
- explicit failure behavior for malformed or missing relay metadata

### Identity/proof adapters

- provider-specific proof URL construction input/output
- fetch failure/retry policy
- verified versus unverifiable result classification

## Fixture Strategy

- reuse `noztr` fixtures where they already cover kernel behavior
- keep SDK fixtures at the orchestration layer, not duplicated kernel-vector copies
- prefer short transcript fixtures over large opaque captures
- keep at least one negative or adversarial fixture for every public workflow slice

## Required Negative Matrix

Every workflow-level test plan should explicitly include:
- malformed protocol payloads
- signer/relay/provider rejection paths
- duplicate or replayed inputs where relevant
- state reset or recovery after failure
- limit-bound cases that could drift from `noztr`
- successful replay after an earlier rejected or malformed step

## Canonical Commands

Current status:
- `zig build`
- `zig build test --summary all`

Optional later:
- `bun test tools/...` for JS interop harnesses only

## Tradeoffs

## Tradeoff T-NOZTR_SDK-TEST-001: Transcript-heavy SDK tests versus broad live-network testing

- Context: SDK workflows are stateful, but live-network tests are flaky and policy-dependent.
- Options:
  - O1: prioritize transcript and fake-adapter tests.
  - O2: prioritize live relay/provider tests early.
- Decision: O1.
- Benefits: reproducible failures, bounded runtime, clearer state assertions.
- Costs: some real-world interoperability issues may appear later.
- Risks: fake environments can miss integration rough edges.
- Mitigations: add a small number of opt-in smoke checks only after transcript coverage is stable.

## Open Questions

- `OQ-NOZTR_SDK-TEST-001`: whether a shared transcript fixture format should be introduced in `M1` or
  only after two workflows need it
- `OQ-NOZTR_SDK-TEST-002`: whether `NIP-39` and `NIP-03` adapters need offline fixture mirrors for
  proofs/documents before any live fetch path is added
