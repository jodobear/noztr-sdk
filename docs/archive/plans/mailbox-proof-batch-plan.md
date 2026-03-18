# Noztr SDK Mailbox And Proof Batch Plan

Implementation packet for the next `noztr-sdk` workflow batch after `NIP-46`.

Date: 2026-03-15

This document is the required pre-implementation packet for the next batch under
[implementation-quality-gate.md](./implementation-quality-gate.md).

## Scope Card

Target batch:
- `NIP-17` mailbox/session orchestration
- `NIP-39` external identity verification adapters
- `NIP-03` OpenTimestamps retrieval and verification adapters

Target caller personas:
- client authors building private messaging flows over explicit relay/session control
- application and service authors who need provider-backed identity verification
- app and relay operators who need OpenTimestamps verification without rebuilding the same
  retrieval flow in every project

Expected public entrypoints for this batch:
- `noztr_sdk.workflows.mailbox` namespace or a similarly narrow workflow export
- `noztr_sdk.workflows.identity_verifier` namespace or equivalent narrow verifier surface
- `noztr_sdk.workflows.opentimestamps_verifier` namespace or equivalent narrow verifier surface

Explicit non-goals for this batch:
- broad public `client` facade freeze
- database backends or durable sync engines
- browser/UI policy
- hidden background runtime or implicit network side effects
- expanding `noztr` examples with SDK orchestration behavior

## Batch Order

Execution order for this batch:
1. `NIP-17` mailbox/session planning and implementation
2. `NIP-39` provider verifier planning and implementation
3. `NIP-03` proof retrieval/verifier planning and implementation

Reason for this order:
- `NIP-17` is the next large stateful workflow and further validates the relay/session substrate
- `NIP-39` and `NIP-03` are narrower networked verifier adapters and should land after the second
  workflow clarifies public layering

## NIP And Kernel Inventory

### `NIP-17`

Relevant `noztr` ownership:
- `noztr.nip17_private_messages.nip17_message_parse(...)`
- `noztr.nip17_private_messages.nip17_relay_list_extract(...)`
- `noztr.nip44`
- `noztr.nip59_wrap`

Relevant current kernel examples:
- `/workspace/projects/noztr/examples/nip17_example.zig`

SDK-owned orchestration:
- mailbox relay discovery and relay selection
- inbox polling/subscription flow
- gift-wrap unwrap sequencing across relay/session state
- explicit local mailbox state and message staging

### `NIP-39`

Relevant `noztr` ownership:
- `noztr.nip39_external_identities.identity_claim_build_tag(...)`
- `noztr.nip39_external_identities.identity_claim_build_proof_url(...)`
- `noztr.nip39_external_identities.identity_claim_build_expected_text(...)`

Relevant current kernel examples:
- `/workspace/projects/noztr/examples/nip39_example.zig`
- `/workspace/projects/noztr/examples/identity_proof_recipe.zig`

SDK-owned orchestration:
- HTTP retrieval
- provider-specific fetch policy and result classification
- explicit verified / unverifiable / fetch-failed outcomes
- optional cache/store integration

### `NIP-03`

Relevant `noztr` ownership:
- `noztr.nip03_opentimestamps.opentimestamps_extract(...)`
- any bounded proof parsing / local verification floor already in `noztr`

Relevant current kernel examples:
- `/workspace/projects/noztr/examples/nip03_example.zig`

SDK-owned orchestration:
- remote proof retrieval
- explicit retry/fetch policy
- Bitcoin/OpenTimestamps client adapter seams
- verified / unverifiable / unavailable result modeling

## Boundary Answers

### Mailbox session

Why is this not already a `noztr` concern?
- It requires relay selection, session state, unwrap sequencing, fetch policy, and local state over
  multiple deterministic kernel helpers.

Why is this not application code above `noztr-sdk`?
- Multiple clients will need the same mailbox relay discovery, inbox flow, and unwrap orchestration.

Why is this the simplest useful SDK layer?
- It turns the existing deterministic private-message primitives into a reusable private-messaging
  workflow without freezing broader app policy.

### Identity verifier

Why is this not already a `noztr` concern?
- Live provider fetches, retries, availability classification, and cache policy are not pure kernel
  behavior.

Why is this not application code above `noztr-sdk`?
- Provider verification logic is reusable across clients, bots, services, and moderation tools.

Why is this the simplest useful SDK layer?
- It centralizes networked proof verification while keeping provider policy explicit and injectable.

### OpenTimestamps verifier

Why is this not already a `noztr` concern?
- Retrieval and networked verification orchestration are outside pure bounded protocol behavior.

Why is this not application code above `noztr-sdk`?
- Most downstream apps should not have to rediscover the same retrieval and result-classification
  flow.

Why is this the simplest useful SDK layer?
- It adds a narrow adapter workflow above the kernel verification floor without pretending to be a
  full blockchain subsystem.

## Example-First Design

### Example 1: mailbox session

Target example shape:
- caller constructs a mailbox workflow with explicit relay/http/store seams
- caller hydrates recipient relay hints from kernel data
- caller steps through inbox fetch and unwrap
- caller receives typed staged results and explicit failure outcomes

Minimal example goal:
- "fetch one private message from one relay and unwrap it through a step-driven session"

### Example 2: identity verifier

Target example shape:
- caller passes a kernel `IdentityClaim`
- verifier composes fetch URL from `noztr`
- caller-supplied HTTP adapter returns proof body
- verifier returns `.verified`, `.mismatch`, or `.fetch_failed`

Minimal example goal:
- "verify one GitHub proof using `noztr`’s expected-text helper and an explicit fake HTTP client"

### Example 3: OpenTimestamps verifier

Target example shape:
- caller passes an event or extracted proof metadata
- verifier fetches remote proof bytes via an explicit adapter
- verifier returns a typed verification classification

Minimal example goal:
- "retrieve one OTS proof and classify it as verified, unverifiable, or unavailable"

## Test Matrix

### `NIP-17`

Required tests:
- happy-path mailbox discovery and one-message unwrap
- malformed recipient / relay list input
- malformed gift-wrap payload
- duplicate or replayed wrapped message handling
- reconnect or relay-switch during mailbox session
- auth-required relay during mailbox session
- limit-bound relay list and recipient handling

### `NIP-39`

Required tests:
- happy-path provider verification
- proof text mismatch
- malformed or unsupported provider claim input
- HTTP fetch failure and retry classification
- cache hit / miss behavior if cache is introduced
- parity check that composed URL and expected proof text still match current `noztr`

### `NIP-03`

Required tests:
- happy-path proof retrieval and classification
- malformed proof body
- missing remote proof
- retry or transient fetch failure classification
- local verification mismatch
- parity check that extracted attestation metadata still matches current `noztr`

## Acceptance Checks

Each slice in this batch is not done until:
- the corresponding workflow plan is updated from this packet if the scope changes
- a structured example shape is documented
- transcript and negative-path coverage exists
- `zig build`
- `zig build test --summary all`
- `/workspace/projects/noztr` is rechecked before close
- any `noztr` issue or improvement idea discovered during implementation is written to
  [noztr-feedback-log.md](./noztr-feedback-log.md)

## Noztr Feedback Rule

If the batch uncovers:
- missing kernel helper seams
- example gaps
- determinism or limit-bound issues
- public type/export improvements

record them immediately in [noztr-feedback-log.md](./noztr-feedback-log.md) instead of leaving them
implicit in commit messages or handoff text.

## Batch Closeout

Accepted in this batch on 2026-03-15:
- first `NIP-17` mailbox/session slice
- first `NIP-39` identity-verifier slice
- first `NIP-03` local OpenTimestamps verifier slice

This batch is now closed green. The next sequential lane moves to `NIP-05` under
[nip-meta-loop-17-39-03-05-29.md](./nip-meta-loop-17-39-03-05-29.md).
