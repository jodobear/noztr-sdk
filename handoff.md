---
title: Handoff
doc_type: state
status: active
owner: noztr-sdk
read_when:
  - every_session
  - determining_current_lane
depends_on:
  - docs/plans/build-plan.md
  - docs/plans/implementation-quality-gate.md
---

# Handoff

Current project context for `noztr-sdk`.

## Current Status

- `noztr-sdk` is a working Zig package on top of local `/workspace/projects/noztr`.
- The implemented workflow floor is:
  - `NIP-46` remote signer
  - `NIP-17` mailbox session plus sender-copy-aware delivery planning, explicit mailbox runtime
    inspection and typed next-step selection, explicit typed next delivery-step selection, and file-
    message send/intake
  - `NIP-39` identity verification plus remembered stored discovery and freshness-classified
    discovery plus preferred remembered-profile selection, explicit remembered runtime policy and
    typed next-step selection, plus explicit stale-profile refresh planning
  - `NIP-03` local plus detached-proof, stored-proof, and freshness-classified remembered-
    verification OpenTimestamps workflow plus explicit remembered runtime policy and typed
    next-step selection plus explicit stale-verification refresh planning
  - `NIP-05` fetch/verify
  - `NIP-29` relay-local group client core plus explicit multi-relay fleet routing, checkpoints,
    reconciliation, component-level merge policy, explicit fleet runtime inspection, durable store seams, and fleet moderation fanout
    plus explicit typed next-step views over runtime, consistency, and publish fanout
- The first structured SDK examples tree is in place and compile-verified.
- The intended product target is explicit:
  - `noztr-sdk` should become the Zig-native analogue to applesauce
  - it should be ecosystem-compatible and app-facing
  - it should preserve the `noztr` kernel boundary
  - it should use Zig's strengths to be more deterministic, bounded, explicit, and easy to reason
    about than a direct TypeScript port
- Current local verification is green in `/workspace/projects/nzdk`:
  - `zig build`
  - `zig build test --summary all` with `209/209`
  - `/workspace/projects/noztr`: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `105/105`

## Read First

- [AGENTS.md](./AGENTS.md)
- [docs/index.md](./docs/index.md)
- [docs/plans/build-plan.md](./docs/plans/build-plan.md)
- [docs/plans/implementation-quality-gate.md](./docs/plans/implementation-quality-gate.md)
- [docs/plans/implemented-nips-applesauce-audit-2026-03-15.md](./docs/plans/implemented-nips-applesauce-audit-2026-03-15.md)
- [docs/plans/implemented-nips-zig-native-audit-2026-03-15.md](./docs/plans/implemented-nips-zig-native-audit-2026-03-15.md)
- [docs/plans/docs-surface-audit.md](./docs/plans/docs-surface-audit.md) when refining process or
  control docs

## Active Gaps

- `A-NIP29-001`: `NIP-29` now has explicit authored state, checkpoint export/restore, explicit
  multi-relay routing, fleet checkpoint persistence, caller-owned durable store seams, explicit
  source-led plus targeted reconciliation, explicit component-level merge policy, explicit fleet
  runtime inspection, and fleet moderation fanout over relay-local clients, but it still lacks the
  broader background-runtime posture of a fuller groups client.
- `A-NIP17-001` and `Z-WORKFLOWS-001`: `NIP-17` now covers sender-copy-aware delivery planning,
  explicit mailbox runtime inspection and next-step selection, explicit next delivery-relay
  selection, and file-message send/intake, but it is still not a higher-level mailbox
  sync/runtime workflow.
- `A-NIP03-001`: `NIP-03` now covers detached proof retrieval plus explicit stored-proof reuse and
  freshness-classified remembered verification plus explicit remembered runtime inspection and
  next-entry selection plus stale-verification refresh planning over the explicit HTTP seam, but
  it is still not a complete proof workflow.
- `A-NIP39-001`: `NIP-39` now verifies full identity events, exposes provider-shaped claim
  details, reuses explicit cached verification outcomes, remembers verified identities, and
  supports hydrated stored discovery plus freshness-classified remembered discovery, preferred
  remembered-profile selection, explicit remembered runtime inspection and next-entry selection,
  and stale-profile refresh planning, but still lacks broader long-lived store/discovery policy.

## Current Slice Notes

- `A-HTTP-001` and `Z-HTTP-001` are now resolved:
  - `src/root.zig` exports the explicit HTTP seam intentionally through `noztr_sdk.transport`
  - `examples/nip39_verification_recipe.zig` and `examples/nip05_resolution_recipe.zig` now teach
    the HTTP-backed workflows through that public seam
- `Z-NIP29-001` is now resolved:
  - `GroupSession` now exposes named caller-owned storage and config wrappers plus a stable view
    surface
  - `examples/group_session_recipe.zig` now teaches that higher-level shape instead of raw reducer
    storage layout
- `A-NIP46-001` is now resolved:
  - `RemoteSignerSession` now covers the kernel-supported `nip04_*` and `nip44_*` pubkey-plus-text
    method family in addition to connect, key discovery, event signing, ping, and relay switching
  - `examples/remote_signer_recipe.zig` now teaches one end-to-end `nip44_encrypt` request on that
    public workflow surface
- `NIP-17` mailbox flow is broader:
  - `MailboxSession` now exposes one outbound `beginDirectMessage(...)` workflow entrypoint in
    addition to relay hydration and unwrap handling
  - `MailboxSession` now also exposes `planDirectMessageRelayFanout(...)` so the sender can build
    one wrap once and receive a deduplicated recipient publish-relay plan from a verified
    kind-10050 relay list
  - `MailboxSession` now also exposes `planDirectMessageDelivery(...)` so the sender can union
    verified sender-copy relays into that delivery plan and inspect relay roles without rebuilding
    the wrap
  - `MailboxSession` now also exposes `acceptWrappedFileMessageJson(...)` for typed `NIP-17`
    file-message intake
  - `MailboxSession` now also exposes `acceptWrappedEnvelopeJson(...)` so callers can classify
    direct-message vs file-message rumors on one explicit mailbox intake path
  - `MailboxSession` now also exposes `beginFileMessage(...)` for one explicit outbound `NIP-17`
    file-message authoring path over the current relay
  - `MailboxSession` now also exposes `planFileMessageRelayFanout(...)` and
    `planFileMessageDelivery(...)` so the sender can plan recipient relays and optional sender-copy
    delivery for one built file-message wrap without rebuilding the payload
  - `MailboxDeliveryPlan` now also exposes `nextRelayIndex()` and `nextStep()` so callers can
    select one typed next publish step without hand-scanning relay-role delivery plans or
    re-stitching wrap payload context above the mailbox workflow
  - `MailboxDeliveryPlan` now also exposes `nextRecipientRelayIndex()`,
    `nextRecipientStep()`, `nextSenderCopyRelayIndex()`, and `nextSenderCopyStep()` so callers
    can select one typed recipient-only or sender-copy-only delivery step without rebuilding that
    filtering logic above the mailbox workflow
  - `MailboxSession` now also exposes `inspectRuntime(...)` so callers can classify all hydrated
    mailbox relays as explicit `connect`, `authenticate`, or `receive` actions on one bounded
    runtime view
  - `MailboxRuntimePlan` now also exposes `nextEntry()` so callers can select the next actionable
    relay step on that bounded runtime view without hand-scanning the plan above the mailbox
    surface
  - `MailboxRuntimePlan` now also exposes `nextStep()` so callers can package that next
    recommended mailbox runtime relay/action into one typed SDK step instead of re-stitching it
    above the workflow
  - `MailboxSession` now also exposes `selectRelay(...)` so callers can act on that runtime view
    without hand-scanning relay pool state above the mailbox surface
  - `examples/mailbox_recipe.zig` now teaches one explicit send-plus-receive round trip over the
    recipient relay list plus sender-copy delivery, explicit next-relay selection over that
    delivery plan, runtime inspection plus explicit next-step selection, then one explicit
    file-message send-plus-receive path on the same mailbox surface, rather than pretending the
    sender's current relay is the real delivery target or that mailbox intake is direct-message-
    only
  - the outbound round-trip path now uses `noztr.nip59_wrap.nip59_build_outbound_for_recipient(...)`
    and `noztr.nip01_event.event_serialize_json_object_unsigned(...)` instead of SDK-local
    transcript staging
  - outbound file-message authoring now also uses
    `noztr.nip17_private_messages.nip17_build_file_*_tag(...)` for exact-fit canonical kind-15
    metadata tags instead of staging those tag shapes locally
- `NIP-39` now has a clearer Zig-native surface:
  - `IdentityVerifier` now takes `IdentityVerificationRequest` with caller-owned
    `IdentityVerificationStorage` instead of three raw temporary buffers
  - `IdentityVerifier` now also verifies full kind-10011 identity events through
    `verifyProfile(...)` with caller-owned `IdentityProfileVerificationStorage`
  - `IdentityVerifier` now reuses explicit cached verification outcomes through
    `verifyProfileCached(...)` with caller-owned `IdentityVerificationCache`
  - `IdentityVerifier` now also remembers verified profile summaries through an explicit
    `IdentityProfileStore` seam and discovers stored identities through one explicit
    provider-plus-identity query
  - `IdentityVerifier` now also exposes `verifyProfileCachedAndRemember(...)` so callers can take
    the common verify-plus-store step without re-stitching it above the cache plus store seams
  - `IdentityVerifier` now also exposes `discoverStoredProfileEntries(...)` so provider-plus-
    identity discovery can return hydrated stored profile records directly on the same explicit
    workflow surface
  - `IdentityVerifier` now also exposes `getLatestStoredProfile(...)` for the common newest-match
    remembered lookup path
  - `IdentityVerifier` now also exposes `getLatestStoredProfileFreshness(...)` so callers can
    classify the newest remembered profile as fresh or stale without inventing hidden refresh
    behavior
  - `IdentityVerifier` now also exposes `discoverStoredProfileEntriesWithFreshness(...)` so
    callers can classify all remembered matches for one provider identity as fresh or stale on one
    hydrated discovery path instead of restitching multi-match age policy above the store seam
  - `IdentityVerifier` now also exposes `getPreferredStoredProfile(...)` so callers can select one
    preferred remembered profile under a freshness window with explicit stale-fallback policy
    instead of rebuilding that policy above the store seam
  - remembered-profile discovery, freshness, and preferred-selection helpers now return
    `error.InconsistentStoreData` instead of relying on invariant-only `unreachable` behavior when
    a custom profile store reports matches it cannot hydrate
  - `IdentityVerifier` now also exposes `inspectStoredProfileRuntime(...)` so callers can classify
    one remembered identity as `verify_now`, `refresh_existing`, `use_preferred`, or
    `use_stale_and_refresh` on the same caller-owned freshness discovery path instead of
    rebuilding that common runtime decision above the store seam
  - `IdentityStoredProfileRuntimePlan` now also exposes `nextEntry()` so callers can step that
    remembered runtime policy without hand-matching the selected stored entry above the workflow
    surface
  - `IdentityStoredProfileRuntimePlan` now also exposes `nextStep()` so callers can package the
    remembered runtime action plus its selected entry into one explicit SDK step value instead of
    stitching the selector result back together above the workflow
  - `IdentityVerifier` now also exposes `planStoredProfileRefresh(...)` so callers can collect
    only stale remembered matches newest-first under one explicit freshness window without hiding
    fetch or refresh policy above the stored-profile seam
  - `IdentityStoredProfileRefreshPlan` now also exposes `nextEntry()` and `nextStep()` so callers
    can consume one typed stale-profile refresh target without re-stitching that selection above
    the refresh plan
  - verified profile claims now expose provider-shaped details through
    `IdentityClaimVerification.providerDetails(...)` and
    `IdentityProfileVerificationSummary.verifiedClaims(...)`
  - `examples/nip39_verification_recipe.zig` now teaches one full identity event verified over the
    public HTTP seam, remembered in a caller-owned profile store, hydrated directly by provider
    identity, classified for freshness both across discovered entries and for the newest match,
    selected once through explicit remembered-profile policy, inspected once through explicit
    remembered runtime policy plus one typed next step, planned once for stale refresh plus one
    typed refresh step, and then replayed from the explicit cache
- `NIP-05` now has a clearer Zig-native surface:
  - `Nip05Resolver` now takes `Nip05LookupRequest` and `Nip05VerificationRequest` with
    caller-owned `Nip05LookupStorage`
  - `examples/nip05_resolution_recipe.zig` now teaches the wrapper shape directly
- `NIP-46` now has a clearer Zig-native request-building surface:
  - `RemoteSignerSession.begin...` methods now take one caller-owned `RemoteSignerRequestContext`
    instead of repeating `buffer + id + scratch`
  - `examples/remote_signer_recipe.zig` now teaches that request-context shape directly
- `NIP-29` client breadth is broader:
  - `GroupSession` now exposes explicit outbound join, leave, put-user, and remove-user publish
    helpers through caller-owned `GroupPublishContext` and `GroupOutboundBuffer`
  - the new `GroupClient` layer now owns previous-ref scratch and consumes mixed relay events on
    top of `GroupSession`
  - `GroupSession` and `GroupClient` now also author metadata, admins, members, and roles snapshot
    state on the same explicit relay-local publish path
  - `GroupSession` and `GroupClient` now export and restore one explicit single-relay checkpoint
    without requiring live relay readiness
  - the new `GroupFleet` layer now routes event intake and checkpoint export/restore by relay URL
    across caller-owned relay-local `GroupClient`s without inventing hidden merge policy
  - `GroupFleet` now also exports and restores one caller-owned fleet checkpoint set across all
    relay-local clients without inventing reconciliation policy
  - `GroupFleet` now also inspects relay-local divergence against one chosen baseline and can
    reconcile the fleet from one explicit source relay without inventing hidden merge rules
  - `GroupFleetConsistencyReport` now also exposes `nextEntry()` so callers can select one next
    divergent relay entry without hand-scanning the consistency report above the fleet workflow
  - `GroupFleetConsistencyReport` now also exposes `nextStep()` so callers can package that next
    divergent relay together with the chosen baseline into one typed SDK step above the fleet
    workflow
  - `GroupFleet` now also persists relay-local checkpoints into one explicit caller-owned store
    seam and can restore a fresh fleet from that stored state without inventing hidden durable
    runtime policy
  - `GroupFleet` now also builds one merged fleet checkpoint from explicit per-component relay
    choices and can apply that merged checkpoint across the fleet without inventing hidden
    authority or automatic merge heuristics
  - `GroupFleet` now also exposes `inspectRuntime(...)` so callers can classify each relay as
    `connect`, `authenticate`, `reconcile`, or `ready` against a chosen baseline without
    hand-composing relay readiness plus divergence checks above the fleet
  - `GroupFleetRuntimePlan` now also exposes `nextEntry()` and `nextStep()` so callers can step
    one typed next runtime relay/action without hand-scanning the fleet runtime plan or
    re-stitching baseline context above the workflow
  - `GroupFleet` now also exposes `reconcileRelayFromBaseline(...)` so callers can converge one
    chosen divergent relay from one chosen baseline without restoring the same checkpoint across
    the whole fleet
  - `GroupFleet` now also plans `put-user` and `remove-user` moderation publishes across all
    relays through one explicit caller-owned fleet publish context and per-relay buffers
  - `GroupFleet.nextPublishEvent(...)` and `nextPublishStep(...)` now also select one typed next
    per-relay moderation publish step without hand-scanning the fleet fanout slice or
    re-stitching selected event context above the workflow
  - `examples/group_session_recipe.zig` now teaches authored snapshot state plus one outbound
    moderation publish through the higher-level client shape, with checkpoint export/restore in the
    middle
  - `examples/group_fleet_recipe.zig` now teaches explicit fleet persistence into a caller-owned
    store, restore into a fresh fleet through that fleet layer, inspect runtime actions plus one
    explicit next runtime step over the restored relays, merge divergent relay-local components by
    explicit relay choice, run one explicit targeted baseline-to-target reconcile step, then one
    explicit next moderation publish step across the reconciled relays
  - the real remaining gap is now broader background runtime/client policy above the explicit
    multi-relay routing, store, runtime inspection, targeted reconcile, reconciliation, and merge
    layer
- local `noztr` compatibility is green again after manifest maintenance:
  - `libwally-core` was repinned to a live upstream commit
  - `secp256k1`'s Zig package hash was refreshed for the current toolchain
  - the latest `/workspace/projects/noztr` compatibility rerun is green again during
    `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global`
- current `noztr` helper adoption is up to date for the implemented mailbox/group flows:
  - `noztr-sdk` now uses `noztr`'s signed event-object JSON serializer for outbound mailbox and
    group-client publish flows
  - the mailbox outbound path now also uses `noztr`'s bounded one-recipient outbound
    `NIP-17` / `NIP-59` transcript helper
  - the 2026-03-18 remediation sync is now closed in
    [docs/plans/noztr-remediation-sync-plan.md](./docs/plans/noztr-remediation-sync-plan.md):
    mailbox now preserves `EntropyUnavailable` distinctly, the root smoke pins hardened `NIP-46`
    direct-helper typed errors, and the local `noztr` compatibility lane is green again
- `NIP-03` proof workflow is broader:
  - `OpenTimestampsVerifier` now exposes an explicit caller-owned detached proof-store seam
  - `OpenTimestampsVerifier.verifyRemoteCached(...)` now reuses stored proof bytes before falling
    back to network fetch
  - `OpenTimestampsVerifier` now also exposes an explicit caller-owned remembered-verification
    store seam above the proof-store seam
  - `OpenTimestampsVerifier.verifyRemoteCachedAndRemember(...)` now covers the common verify plus
    remember path for one detached proof document
  - `OpenTimestampsVerifier.getLatestStoredVerification(...)` now recovers the newest remembered
    verification summary for one target event id without inventing hidden runtime policy
  - `OpenTimestampsVerifier.getLatestStoredVerificationFreshness(...)` now classifies that newest
    remembered verification as fresh or stale under one explicit freshness window instead of
    leaving that common latest-match age policy above the store seam
  - `OpenTimestampsVerifier.getPreferredStoredVerification(...)` now selects one preferred
    remembered verification under explicit stale-fallback policy and caller-owned freshness
    storage instead of leaving that choice entirely above the store seam or hiding a fixed local
    entry cap
  - `OpenTimestampsStoredVerificationRefreshPlan` now also exposes `nextEntry()` and `nextStep()`
    so callers can consume one typed stale-verification refresh target without re-stitching that
    selection above the refresh plan
  - `OpenTimestampsVerifier.discoverStoredVerificationEntriesWithFreshness(...)` now classifies all
    remembered verification entries for one target event as fresh or stale without inventing
    hidden refresh or Bitcoin policy
  - `OpenTimestampsVerifier.inspectStoredVerificationRuntime(...)` now classifies one target event
    as `verify_now`, `refresh_existing`, `use_preferred`, or `use_stale_and_refresh` on the same
    caller-owned freshness discovery surface instead of leaving that common runtime decision above
    the stored verification seam
  - `OpenTimestampsStoredVerificationRuntimePlan` now also exposes `nextEntry()` so callers can
    step that remembered runtime policy without hand-matching the selected stored verification
    above the workflow surface
  - `OpenTimestampsStoredVerificationRuntimePlan` now also exposes `nextStep()` so callers can
    package the remembered runtime action plus its selected verification into one explicit SDK
    step value instead of stitching the selector result back together above the workflow
  - `OpenTimestampsVerifier.planStoredVerificationRefresh(...)` now collects only stale remembered
    verification matches newest-first under one explicit freshness window without hiding fetch or
    Bitcoin policy above the stored verification seam
  - remembered-verification discovery, freshness, and preferred-selection helpers now return
    `error.InconsistentStoreData` instead of relying on invariant-only `unreachable` behavior when
    a custom verification store reports matches it cannot hydrate
  - `examples/nip03_verification_recipe.zig` now teaches verify, remember, freshness-classified
    discovery, one typed remembered runtime step, stale refresh planning, and latest remembered
    lookup on the same explicit public surface
  - the real remaining gap is broader Bitcoin verification, proof freshness, and longer-lived
    durable proof policy above the current workflow

## Process Rule

- If the next slice refines an already-landed workflow, it must:
  - name the targeted findings from both audit files before implementation
  - rerun both audit frames after implementation
  - update the audit docs explicitly before closeout
- If the process changes materially, reconcile the affected control docs together instead of
  treating the change as append-only.

## Immediate Next Work

1. Use
   [docs/plans/noztr-remediation-sync-plan.md](./docs/plans/noztr-remediation-sync-plan.md) as the
   reference packet when future `noztr` hardening passes land. It is now completed, not the active
   blocker.
2. The ten-slice runtime/refresh loop is complete in
   [docs/plans/ten-slice-runtime-refresh-loop-plan.md](./docs/plans/ten-slice-runtime-refresh-loop-plan.md).
   Treat it as reference, not the next active blocker.
3. The stored-workflow remediation slice is complete in
   [docs/plans/stored-workflow-hardening-plan.md](./docs/plans/stored-workflow-hardening-plan.md).
   Treat it as reference.
4. The next active packet should target a broader remaining product gap rather than another
   bounded selector/helper loop.
5. Continue `NIP-29` only if the next slice clearly targets broader background runtime/client
   policy or another gap above the now-landed explicit fleet store, targeted reconcile,
   reconciliation, merge, publish-planning, runtime-inspection, and typed next-step surfaces
   rather than repeating already-landed relay-local authoring, checkpoint, explicit fleet-routing,
   or merge-selection work.
6. Continue `NIP-39` only if the next slice clearly targets broader autonomous discovery, refresh,
   or longer-lived store policy beyond the now-landed remembered verify/store/discover/select and
   runtime-policy plus next-step path rather than repeating already-landed provider-detail,
   cache, or explicit store/discovery work.
7. The best broader product slice after this runtime/refresh loop is still a real background-
   runtime `NIP-29` lane, a pivot to `NIP-39` longer-lived identity/discovery policy, or broader
   `NIP-03` / `NIP-17` workflow policy. This loop should stop at bounded refresh/runtime/
   consistency driving helpers rather than jumping to hidden background loops.
8. Keep protocol parsing, validation, building, signing, and deterministic reduction in `noztr`.
9. Keep `examples/README.md` current whenever the public teaching surface changes.
10. Record any new kernel issue in [docs/plans/noztr-feedback-log.md](./docs/plans/noztr-feedback-log.md).
11. Treat `docs/archive/` as historical context only, not startup reading.
12. Keep `NIP-03` scoped to broader proof workflow work only:
   `OpenTimestampsVerifier.verifyRemote(...)` and `verifyRemoteCached(...)` already cover the
   explicit detached-proof HTTP seam plus bounded proof-store reuse, and the current slice now also
   covers remembered runtime inspection plus typed next-step selection; the remaining gap is broader
   Bitcoin verification, freshness, and durable proof-store policy.
