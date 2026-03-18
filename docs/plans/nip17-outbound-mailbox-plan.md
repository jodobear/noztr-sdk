---
title: Noztr SDK NIP-17 Outbound Mailbox Refinement
doc_type: packet
status: reference
owner: noztr-sdk
nips:
  - 17
phase: refinement
posture:
  - product
  - zig-native
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/implemented-nips-applesauce-audit-2026-03-15.md
  - docs/plans/implemented-nips-zig-native-audit-2026-03-15.md
target_findings:
  - A-NIP17-001
  - Z-WORKFLOWS-001
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
read_when:
  - refining_nip17
  - broadening_mailbox_workflow
---

# Noztr SDK NIP-17 Outbound Mailbox Refinement

Date: 2026-03-15

This packet covers the next accepted `NIP-17` refinement slice: broadening `MailboxSession` from an
inbox-only intake core into a minimal round-trip mailbox workflow by adding one outbound
direct-message wrap builder.

Follow-on recipient-relay fanout broadening for this workflow now lives in
[nip17-relay-fanout-plan.md](./nip17-relay-fanout-plan.md).

Follow-on sender-copy delivery broadening for this workflow now lives in
[nip17-sender-copy-plan.md](./nip17-sender-copy-plan.md).

Follow-on outbound file-message broadening for this workflow now lives in
[nip17-file-send-plan.md](./nip17-file-send-plan.md).

## Scope Card

Target workflow slice:
- add one outbound direct-message builder on `MailboxSession` that produces a signed `NIP-17` /
  `NIP-59` wrap payload ready for caller-controlled relay publication

Target caller persona:
- app authors who already control relay transport and want the SDK to cover both mailbox intake and
  one explicit outbound direct-message path without taking over runtime policy

Public entrypoints to add or change:
- add a public outbound request type for one recipient plus explicit wrap material
- add a caller-owned outbound JSON buffer type
- add a typed outbound result that names the current relay and produced wrap id/json
- add one `MailboxSession.beginDirectMessage(...)` workflow entrypoint
- update the public mailbox recipe to show an end-to-end send-plus-receive transcript

Explicit non-goals for this slice:
- file-message send support
- runtime polling/subscription loops
- automatic multi-relay fanout
- hidden randomness or hidden time sources
- durable mailbox persistence

## Kernel Inventory

`noztr` remains authoritative for:
- `noztr.nip17_private_messages.nip17_build_recipient_tag(...)`
- `noztr.nip17_private_messages.nip17_unwrap_message(...)`
- `noztr.nip44.nip44_get_conversation_key(...)`
- `noztr.nip44.nip44_encrypt_with_nonce_to_base64(...)`
- `noztr.nostr_keys.nostr_derive_public_key(...)`
- `noztr.nostr_keys.nostr_sign_event(...)`
- `noztr.nip01_event.event_compute_id_checked(...)`
- `noztr.nip59_wrap.nip59_validate_wrap_structure(...)`

Relevant kernel recipes:
- `/workspace/projects/noztr/examples/nip17_wrap_recipe.zig`
- `/workspace/projects/noztr/examples/nip17_example.zig`

SDK-owned work in this slice:
- explicit current-relay gating before an outbound publish payload can be built
- packaging the staged kernel pieces into one mailbox send workflow
- typed relay-target plus JSON payload result for caller-controlled publication

## Boundary Answers

Why is this not already a `noztr` concern?
- the kernel already owns the deterministic cryptographic and parsing helpers; this slice only
  sequences those helpers into a mailbox workflow that matches the existing session/relay surface

Why is this not application code above `noztr-sdk`?
- otherwise every app using mailbox intake would have to duplicate the same recipient-tag,
  staged-encryption, signing, and current-relay publish targeting logic for the most common send
  path

Why is this the simplest useful SDK layer?
- it adds one explicit outbound path without taking over runtime policy, fanout policy, or hidden
  randomness

## Example-First Design

Target example shape:
1. sender mailbox session hydrates relay state and marks the current relay connected
2. sender builds one outbound direct-message wrap for a peer pubkey
3. caller treats the returned JSON as the publish payload for the current relay
4. recipient mailbox session accepts that same wrap JSON and unwraps the message

Minimal example goal:
- teach a real round-trip `NIP-17` flow while keeping transport, fanout, and subscription policy
  explicit

## Proof Obligations And Assumption Gaps

Invariants that must hold:
- outbound message construction is blocked while the current relay is disconnected or auth-gated
- recipient tags are built through kernel validation
- outer wrap structure is cryptographically valid and can be unwrapped by the recipient path
- the outbound result names the current relay actually selected by the session

Proven by `noztr`:
- recipient-tag validation
- conversation-key derivation and `NIP-44` encryption
- event signing and event id computation
- wrap structural validation on the recipient side

Proven by `noztr-sdk`:
- current-relay gating
- outbound workflow packaging and result targeting

Accepted proof/boundary gap for this slice:
- none at the deterministic transcript-building boundary after the 2026-03-16 upstream helper
  additions; relay selection, fanout, sender-copy policy, and runtime orchestration remain SDK/app
  responsibilities by design

## Seam Contract Audit

Required seam semantics:
- identical to the current mailbox receive seam for relay readiness:
  - disconnected relays cannot send
  - auth-required relays cannot send
- caller controls publication of the returned JSON payload

Current seam status:
- sufficient for one-relay-at-a-time publish targeting
- no transport widening is required for this slice

Scope-narrowing note:
- multi-relay recipient fanout remains above this slice

## State-Machine Notes

This slice does not add new relay/session states.

It reuses the accepted mailbox state machine:
- outbound construction requires the current relay to be ready
- auth-required and disconnected states block both intake and outbound construction
- relay rotation changes the publish target because the current relay URL changes

## Test Matrix

Required tests:
- build one outbound direct-message wrap and unwrap it successfully through a recipient mailbox
  session
- outbound builder returns the current relay URL as the publish target
- outbound builder blocks while the current relay is disconnected
- outbound builder blocks while auth is required
- invalid recipient pubkeys are rejected on the builder path
- returned wrap JSON parses as a valid event and passes `nip59_validate_wrap_structure(...)`
- mailbox recipe updated to show send-plus-receive round trip

## Acceptance Checks

This slice does not close until:
- `zig build`
- `zig build test --summary all`
- `/workspace/projects/noztr` compatibility is rechecked
- `A-NIP17-001` and `Z-WORKFLOWS-001` are rerun and updated explicitly
- `examples/README.md`, `handoff.md`, `docs/index.md`, and startup discovery docs reflect the
  broader mailbox workflow
- any still-real deterministic kernel gap is recorded in `noztr-feedback-log.md`

## Closeout

Accepted on 2026-03-15:
- `MailboxSession` now exposes one outbound `beginDirectMessage(...)` workflow entrypoint in
  addition to inbound relay hydration and unwrap handling
- the mailbox recipe now teaches one explicit send-plus-receive round trip on the public workflow
  surface
- the outbound transcript path now delegates exact-fit deterministic staging to
  `noztr.nip59_wrap.nip59_build_outbound_for_recipient(...)` and
  `noztr.nip01_event.event_serialize_json_object_unsigned(...)`
- `A-NIP17-001` and `Z-WORKFLOWS-001` are improved but remain open with narrower scope:
  - no longer inbox-only
  - still not a higher-level mailbox sync/fanout runtime
- no remaining deterministic kernel gap is required for the current one-recipient mailbox scope
