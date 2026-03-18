---
title: Noztr Remediation Sync Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - syncing_nzdk_after_noztr_audit_hardening
  - reviewing_affected_nzdk_surfaces_after_noztr_contract_changes
depends_on:
  - docs/plans/implementation-quality-gate.md
  - docs/plans/noztr-feedback-log.md
target_findings: []
touches_teaching_surface: no
touches_audit_state: no
touches_startup_docs: yes
---

# Noztr Remediation Sync Plan

## Scope Delta

- Audit `noztr-sdk` against the current `noztr` remediation brief in
  `../noztr/docs/plans/noztr-sdk-remediation-brief.md`.
- Tighten only the `nzdk` surfaces actually affected by the upstream contract cleanup.
- Keep broader workflow expansion paused until this compatibility/remediation slice is resolved.
- Do not treat this slice as new product-surface broadening unless the review proves that `nzdk`
  was depending on older looser behavior.

Declared sync flags:
- `touches_teaching_surface: no`
- `touches_audit_state: no`
- `touches_startup_docs: yes`

## Targeted Findings

- no active applesauce-lens or Zig-native audit finding is the primary driver here
- this is a compatibility and boundary-sync slice driven by upstream `noztr` remediation

## Slice-Specific Proof Gaps

- This slice does not broaden what `noztr-sdk` can prove.
- It only revalidates that the current SDK wrappers and tests still match the hardened kernel
  contracts.
- If the audit uncovers any remaining deterministic kernel seam pressure, it must be logged in
  `docs/plans/noztr-feedback-log.md` rather than hidden inside local wrapper changes.

## Slice-Specific Seam Constraints

- `noztr` owns typed invalid-input handling for strict protocol helpers such as `NIP-46` request
  builders, response parsers, and direct helper misuse boundaries.
- `noztr-sdk` must not preserve old workaround assumptions that depend on panic-like behavior,
  debug assertions, or looser invalid-input handling.
- `noztr-sdk` still owns mailbox orchestration, relay/session planning, and delivery policy even
  when it adopts narrower upstream helpers.
- `NIP-29` reducer-local performance cleanup upstream should not cause `nzdk` semantic changes
  unless a local ordering or replay assumption turns out to be invalid.

## Reviewed Affected Surfaces

- `src/workflows/remote_signer.zig`
  - primary `NIP-46` wrapper surface for request building, response parsing, and invalid-input
    propagation
- `src/workflows/mailbox.zig`
  - primary mailbox surface consuming `nostr_keys`, `nip44`, and `nip59_wrap` contracts
- `src/root.zig`
  - direct smoke coverage for `noztr.nip46_remote_signing.method_parse(...)`
- `src/workflows/group_session.zig`
  - `NIP-29` replay/reducer integration rechecked for semantic drift after upstream bounded
    performance cleanup

Current review status before code changes:
- `NIP-46`: likely tests/docs recheck only unless the wrapper still assumes older assert-like
  behavior
- mailbox / `NIP-44` / `NIP-59`: likely the most plausible place for a narrow mapping cleanup if
  backend-error distinctions are still blurred locally
- `NIP-29`: currently looks like recheck-only, not a code-change surface
- `NIP-25`, `NIP-86`, delegation-signature helpers, and `NIP-47`: no active `nzdk` surface to
  adjust

## Slice-Specific Tests

- recheck `remote_signer` tests for any dependence on assertion-like invalid-input behavior
- add or adjust `remote_signer` tests only if `nzdk` was assuming looser `NIP-46` invalid-input
  contracts
- recheck mailbox outbound tests for:
  - sender pubkey matching the sender secret
  - one-recipient-only transcript building
  - unsigned event-object JSON versus canonical ID-preimage JSON
  - backend-unavailable propagation where upstream now distinguishes it more clearly
- rerun `NIP-29` replay tests to confirm the upstream reducer cleanup does not require local
  semantic changes
- classify the upstream compatibility rerun as:
  - `green`
  - `known-upstream-failure-only`
  - `new-upstream-pressure`

## Staged Execution Notes

1. Code:
   - inspect `remote_signer`, `mailbox`, and `root` for stale local workarounds or blurred
     invalid-input/backend-error handling
   - remove any exact-fit duplication now owned cleanly by `noztr`
2. Tests:
   - tighten wrapper tests where local behavior was relying on older looser contracts
   - do not add fake panic-mirroring tests
3. Example:
   - update examples only if the public teaching contract actually changes
4. Review/audits:
   - rerun the remediation review against the upstream brief after any local change
   - record any remaining deterministic kernel seam pressure in `docs/plans/noztr-feedback-log.md`
5. Docs/closeout:
   - update `handoff.md`, `build-plan.md`, and `docs/index.md`
   - update any touched reference packets for `NIP-46`, `NIP-17`, or `NIP-29`
   - keep the compatibility result classification explicit

## Closeout Checks

- Update `handoff.md`
- Update `docs/plans/build-plan.md`
- Update `docs/index.md`
- Update `docs/plans/noztr-feedback-log.md` if the review finds a real remaining kernel issue
- Update any touched workflow reference packet if a local wrapper contract changes
- Record the final compatibility classification against the local `noztr` lane

## Accepted Slice

Implemented and reviewed on 2026-03-18:
- mailbox outbound wrap construction now preserves `EntropyUnavailable` distinctly instead of
  collapsing it into `BackendUnavailable`
- `src/root.zig` now pins the hardened `noztr.nip46_remote_signing.method_parse(...)` and
  `permission_parse(...)` typed-error contracts for overlong direct helper input
- the `NIP-46` wrapper surface in `src/workflows/remote_signer.zig` did not require local
  behavioral change for this remediation pass
- `NIP-29` replay/reducer integration was rechecked and did not require local semantic changes

Verification:
- `/workspace/projects/nzdk`: `zig build`
- `/workspace/projects/nzdk`: `zig build test --summary all` with `151/151`
- `/workspace/projects/noztr`: `green` via
  `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
  with `1116/1116` tests plus examples and `93/93` package tests
