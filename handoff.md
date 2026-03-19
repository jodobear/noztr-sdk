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
    inspection and typed next-step selection, explicit mailbox workflow inspection and typed
    workflow-step selection, explicit typed next delivery-step selection, and file-message
    send/intake
- `NIP-39` identity verification plus remembered stored discovery and freshness-classified
  discovery plus preferred remembered-profile selection, explicit remembered runtime policy and
  typed next-step selection, explicit watched-target policy and refresh-cadence classification,
  refresh-batch selection, turn-policy classification, turn-bucket views, plus explicit stale-
  profile refresh planning
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
  - `zig build test --summary all` with `330/330`
  - last `/workspace/projects/noztr` compatibility lane remained green: `zig build test --summary all --cache-dir /tmp/noztr-sdk-noztr-cache --global-cache-dir /tmp/noztr-sdk-zig-global` with `113/113`, `1222/1222`, and examples

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
  explicit mailbox runtime inspection and next-step selection, explicit mailbox workflow
  inspection and typed next-step selection, explicit next delivery-relay selection, and file-
  message send/intake, but it is still not a higher-level mailbox sync/runtime workflow.
- `A-NIP03-001`: `NIP-03` now covers detached proof retrieval plus explicit stored-proof reuse and
  freshness-classified remembered verification plus explicit remembered runtime inspection and
  next-entry selection plus stale-verification refresh planning over the explicit HTTP seam, but
  it is still not a complete proof workflow.
- `A-NIP39-001`: `NIP-39` now verifies full identity events, exposes provider-shaped claim
  details, reuses explicit cached verification outcomes, remembers verified identities, and
  supports hydrated stored discovery plus freshness-classified remembered discovery, preferred
  remembered-profile selection, explicit watched-target latest-freshness discovery, explicit
  watched-target preferred-selection, watched-target stale-refresh planning, watched-target
  runtime policy plus typed next-step driving, explicit remembered runtime inspection and next-
  entry selection, and stale-profile refresh planning, but still lacks broader autonomous
  discovery/refresh policy above the current caller-owned watched-target inputs.

## Current Slice Notes

- the new top-level active lane is
  [docs/plans/sdk-runtime-client-store-architecture-plan.md](./docs/plans/sdk-runtime-client-store-architecture-plan.md):
  - `noztr-sdk` now explicitly prioritizes one shared client/runtime/store architecture baseline
    above deeper local `NIP-03` / `NIP-39` refinement
  - this lane is intended to make the SDK ready for the first serious product wave:
    Zig CLI, signer tooling, and later relay-framework work
  - the first focused child architecture research packet is now
    [docs/plans/sdk-storage-backend-research-plan.md](./docs/plans/sdk-storage-backend-research-plan.md)
  - its current conclusions are:
    - storage support should be workload-first, not backend-first
    - public SDK workflow APIs must stay backend-agnostic
    - in-memory/reference stores are required in core
    - one embedded durable backend should likely get early first-party support
    - SQLite is the strongest current candidate for that first embedded durable backend
    - relay-grade or product-grade specialized backends should stay adapter-first or product-owned
      until product pressure justifies tighter first-party support
  - the store/query/index child is now reference architecture context:
    [docs/plans/sdk-store-query-index-baseline-plan.md](./docs/plans/sdk-store-query-index-baseline-plan.md)
    and
    [docs/plans/sdk-store-query-index-baseline-decision.md](./docs/plans/sdk-store-query-index-baseline-decision.md)
  - that child now makes explicit:
    - `ClientStore` is aggregate vocabulary, not one mandatory god-interface
    - the shared baseline should split into narrow event-store, query/read, checkpoint/cursor, and
      limited generic value seams
    - workflow-local remembered-state stores should not be generalized into SDK-core prematurely
    - query/result/cursor/index posture must stay backend-agnostic at the public SDK boundary
  - the relay-pool/runtime child and its subscription/replay follow-on packets are now reference
    architecture context:
    [docs/plans/sdk-relay-pool-runtime-baseline-plan.md](./docs/plans/sdk-relay-pool-runtime-baseline-plan.md),
    [docs/plans/sdk-relay-pool-runtime-baseline-decision.md](./docs/plans/sdk-relay-pool-runtime-baseline-decision.md),
    [docs/plans/relay-pool-subscription-boundary-plan.md](./docs/plans/relay-pool-subscription-boundary-plan.md),
    and
    [docs/plans/relay-pool-sync-boundary-checkpoint-plan.md](./docs/plans/relay-pool-sync-boundary-checkpoint-plan.md)
  - the active child architecture packet is now
    [docs/plans/sdk-cli-client-composition-plan.md](./docs/plans/sdk-cli-client-composition-plan.md)
  - the first bounded implementation loop under that child is now complete in
    [docs/plans/five-slice-relay-pool-loop-plan.md](./docs/plans/five-slice-relay-pool-loop-plan.md)
  - that child still exists to keep the sequence coherent:
    - shared relay-pool/runtime vocabulary before another round of workflow-local runtime growth
    - explicit reuse of the shared store/query/checkpoint seams instead of another isolated pool
      storage model
    - one broader runtime layer that can support CLI, signer tooling, and later relay-framework
      work
  - the store/query/index child now proves:
    - `src/root.zig` now exports `noztr_sdk.store` as a stable public store/query reference
      namespace
    - `src/store/client_traits.zig` now defines the first shared event/query/checkpoint baseline:
      `ClientStore`, `ClientEventStore`, `ClientCheckpointStore`, `ClientQuery`,
      `EventQueryResultPage`, `EventCursor`, and `IndexSelection`
    - `src/store/client_memory.zig` now provides one bounded in-memory reference implementation
      through `MemoryClientStore`
    - `examples/store_query_recipe.zig` now pressure-tests the baseline publicly by persisting
      bounded event records, paging one backend-agnostic query, and restoring one named checkpoint
    - the next architecture move should therefore be shared relay-pool/runtime composition rather
      than more store-only theory
  - the next pressure-test is now also landed through
    [docs/plans/sdk-store-archive-pressure-test-plan.md](./docs/plans/sdk-store-archive-pressure-test-plan.md):
    - `src/store/archive.zig` now exposes `EventArchive` as one minimal CLI-facing helper above the
      shared `ClientStore` seam
    - the archive helper ingests event JSON explicitly, replays bounded queries through
      `ClientQuery` plus `EventQueryResultPage`, and persists named checkpoints without adding a
      durable backend or hidden runtime
    - `examples/store_archive_recipe.zig` now teaches that higher-level path explicitly
    - this pressure-test confirms the aggregate `ClientStore` concept is useful above raw event and
      checkpoint sub-seams instead of being only a theoretical vocabulary
  - the relay/store composition pressure-test is now also landed through
    [docs/plans/sdk-relay-checkpoint-pressure-test-plan.md](./docs/plans/sdk-relay-checkpoint-pressure-test-plan.md):
    - `src/store/relay_checkpoint.zig` now exposes `RelayCheckpointArchive` above the shared
      `ClientStore` seam
    - the helper persists one named cursor per relay URL and scope through the shared checkpoint
      store without exposing the internal relay pool module publicly
    - `examples/relay_checkpoint_recipe.zig` now teaches that relay-local checkpoint path
    - this confirms that relay-local runtime progress can compose with the shared checkpoint seam
      before the broader public relay-pool layer exists
  - the first real workflow pressure-test is now also landed through
    [docs/plans/sdk-group-replay-pressure-test-plan.md](./docs/plans/sdk-group-replay-pressure-test-plan.md):
    - `src/store/relay_local_group_archive.zig` now exposes `RelayLocalGroupArchive` above the
      shared `ClientStore` event seam
    - the helper archives canonical relay-local `NIP-29` state-event JSON and restores one fresh
      `GroupClient` snapshot in explicit oldest-to-newest replay order
    - `examples/relay_local_group_archive_recipe.zig` now teaches that path explicitly
    - this confirms the shared event seam can support one real SDK workflow without forcing
      workflow-local remembered-state stores into the shared core, while also making the current
      relay-local limitation explicit until the broader relay-pool layer hardens
- the first shared relay-pool/runtime loop is now complete:
  - `src/root.zig` now exports a stable public `noztr_sdk.runtime` namespace
  - `src/runtime/relay_pool.zig` now exposes `RelayPool`, `RelayPoolStorage`,
    `RelayPoolPlanStorage`, `RelayPoolPlan`, and `RelayPoolStep`
  - `RelayPool` now wraps bounded relay-local session state into one shared multi-relay floor and
    exposes explicit `addRelay(...)`, readiness transitions, and `inspectRuntime(...)`
  - `RelayPoolPlan` now exposes bounded `nextEntry()` and typed `nextStep()` selection over
    shared `connect` / `authenticate` / `ready` state without pulling mailbox, signer, or groups
    semantics into the shared layer
  - `examples/relay_pool_recipe.zig` now teaches one explicit inspect-plan-step path over two
    relays on that shared runtime floor
  - the next active implementation loop under that child is now
    [docs/plans/five-slice-relay-pool-checkpoint-loop-plan.md](./docs/plans/five-slice-relay-pool-checkpoint-loop-plan.md)
  - that loop exists to prove shared pool plus shared checkpoint composition before broader
    workflow adaptation or subscription/sync expansion
- the shared relay-pool checkpoint loop is now complete:
  - `src/runtime/relay_pool.zig` now also exposes bounded `RelayPoolCheckpointRecord`,
    `RelayPoolCheckpointStorage`, `RelayPoolCheckpointSet`, and `RelayPoolCheckpointStep`
  - `RelayPool.exportCheckpoints(...)` now derives one bounded relay-url-plus-cursor record per
    current pool relay from caller-supplied cursor values
  - `RelayPool.restoreCheckpoints(...)` now restores relay membership into one fresh shared pool
    from that bounded checkpoint set without inventing hidden reset or persistence behavior
  - `RelayPoolCheckpointSet` now also exposes `nextEntry()`, `nextExportStep()`, and
    `nextRestoreStep()` so callers can drive one explicit checkpoint action without rebuilding
    step typing above the runtime layer
  - `examples/relay_pool_checkpoint_recipe.zig` now proves that this shared pool checkpoint shape
    composes with `noztr_sdk.store.RelayCheckpointArchive` instead of absorbing store policy into
    `runtime`
- the remote-signer relay-pool loop is now complete:
  - `src/workflows/remote_signer.zig` now exposes caller-owned relay-pool export/runtime storage
    plus `exportRelayPool(...)`, `inspectRelayPoolRuntime(...)`, and `selectRelayPoolStep(...)`
  - that gives `RemoteSignerSession` one explicit adaptation path over the shared
    `noztr_sdk.runtime` floor instead of requiring signer tooling to invent its own separate
    multi-relay readiness model
  - `examples/remote_signer_recipe.zig` now teaches connect, `get_public_key`, `nip44_encrypt`,
    then one explicit shared relay-pool inspect/select step on the same signer workflow surface
- the mailbox relay-pool loop is now complete:
  - `src/workflows/mailbox.zig` now exposes caller-owned relay-pool export/runtime storage plus
    `exportRelayPool(...)`, `inspectRelayPoolRuntime(...)`, and `selectRelayPoolStep(...)`
  - that gives `MailboxSession` one explicit adaptation path over the shared `noztr_sdk.runtime`
    floor instead of requiring mailbox clients to invent a second multi-relay readiness model
  - `examples/mailbox_recipe.zig` now teaches one shared relay-pool inspect/select step on the
    same mailbox workflow surface without replacing mailbox delivery or workflow planning
- the relay-pool architecture checkpoint is now complete:
  - the current shared relay-pool/runtime floor is now considered strong enough for CLI-facing and
    signer-facing multi-relay readiness work
  - remote-signer and mailbox are now enough workflow adaptation evidence for this lane; another
    immediate adaptation loop would be drift, not the highest-value shared next step
  - the next active packet under the shared relay-pool child is now
    [docs/plans/relay-pool-subscription-boundary-plan.md](./docs/plans/relay-pool-subscription-boundary-plan.md)
  - that packet exists to decide what pool-level subscription, replay, and sync posture belongs in
    the shared runtime layer before groups adaptation or broader relay-framework work continue
- the relay-pool subscription-spec loop is now complete:
  - `src/runtime/relay_pool.zig` now exposes `RelaySubscriptionSpec`,
    `RelayPoolSubscriptionStorage`, `RelayPoolSubscriptionPlan`, and
    `RelayPoolSubscriptionStep`
  - `RelayPool.inspectSubscriptions(...)` now combines caller-owned kernel `Filter` targets with
    current relay readiness into one bounded shared plan instead of leaving early multi-relay
    subscribe wiring to product-local bespoke loops
  - `examples/relay_pool_recipe.zig` now teaches one explicit shared subscription-spec plan and
    one typed next subscribe-now step on the same shared runtime floor
- the next active implementation packet under the shared relay-pool subscription boundary lane is
  now [docs/plans/five-slice-relay-pool-replay-loop-plan.md](./docs/plans/five-slice-relay-pool-replay-loop-plan.md)
  - that loop exists to prove one bounded shared replay-composition plan and typed next replay step
    above the pool/runtime floor plus shared checkpoint/store seams
  - it is intentionally narrower than full sync ownership, workflow-local replay policy, or
    product-local background execution
- the relay-pool replay loop is now complete:
  - `src/runtime/relay_pool.zig` now also exposes `RelayReplaySpec`,
    `RelayPoolReplayStorage`, `RelayPoolReplayPlan`, and `RelayPoolReplayStep`
  - `RelayPool.inspectReplay(...)` now combines caller-owned checkpoint scope plus `ClientQuery`
    intent with stored per-relay checkpoint cursors and current relay readiness into one bounded
    shared replay plan
  - `RelayPoolReplayPlan` now also exposes `nextEntry()` and `nextStep()` so callers can follow
    one explicit replay-now target without hand-scanning the derived plan above the shared pool
  - `examples/relay_pool_checkpoint_recipe.zig` now teaches that replay-composition path on top of
    the same shared checkpoint seam instead of pushing replay stitching back into product-local
    code
- the relay-pool sync-boundary checkpoint is now complete:
  - the shared relay-pool layer should stop at bounded planning surfaces for now
  - shared `runtime` should not absorb pool-owned subscription execution, replay execution, hidden
    background sync loops, or product-local scheduling/runtime ownership yet
  - the next active child is now
    [docs/plans/sdk-cli-client-composition-plan.md](./docs/plans/sdk-cli-client-composition-plan.md)
    so the architecture lane can pressure-test one real CLI-facing client surface above the shared
    store and runtime floors instead of growing shared `runtime` further by default
- the CLI archive client loop is now complete:
  - `src/root.zig` now also exports a stable public `noztr_sdk.client` namespace
  - `src/client/cli_archive_client.zig` now exposes `CliArchiveClient`,
    `CliArchiveClientConfig`, and `CliArchiveClientStorage`
  - that client now composes the shared store seam through explicit event ingest, bounded query,
    named checkpoints, and per-relay checkpoints without forcing the future CLI repo to rebuild
    store glue above `noztr-sdk`
  - that same client now also composes the shared relay runtime floor through explicit relay
    membership helpers, shared runtime inspection, and shared replay inspection instead of
    inventing a second tooling-local relay/runtime model
  - `examples/cli_archive_client_recipe.zig` now teaches the first CLI-facing client composition
    path above shared store plus runtime, not CLI command UX
- the next active packet under the CLI client composition child is now
  [docs/plans/sdk-cli-client-boundary-checkpoint-plan.md](./docs/plans/sdk-cli-client-boundary-checkpoint-plan.md)
  - that checkpoint exists to decide whether the SDK should add more CLI-facing client composition
    before the separate CLI repo starts, or whether the current `CliArchiveClient` is enough as
    the first reusable SDK floor
- `NIP-29` background-runtime loop is now complete:
  - `GroupFleetBackgroundAction` now names the bounded coordinator phases above the current fleet
    runtime, consistency, reconcile, merge, and publish-plan surfaces
  - `GroupFleetBackgroundEntry` now provides the stable SDK-facing relay-target shape that later
    background-runtime slices will drive
  - `GroupFleet.inspectBackgroundRuntime(...)` now exposes one explicit caller-owned background
    plan over relay runtime state, divergence, and pending merge/publish inputs instead of leaving
    that broader coordinator posture implicit above the fleet
  - `GroupFleetBackgroundRuntimePlan` now also exposes `nextEntry()` so callers can select one
    bounded next background relay/action without hand-scanning that broader plan above the fleet
  - `GroupFleetBackgroundRuntimePlan` now also exposes `nextStep()` so callers can package that
    next background relay/action together with baseline context into one typed SDK step
  - `GroupFleet.selectBackgroundRelay(...)` now also validates and normalizes the relay target for
    one typed background step instead of forcing callers to redo relay lookup above the fleet
  - `examples/group_fleet_recipe.zig` now teaches one explicit background merge step and one
    explicit background publish step on top of the existing fleet runtime, consistency, targeted
    reconcile, and publish-plan surfaces
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
  - the active `NIP-17` workflow loop is now started, and `MailboxWorkflowAction` plus
    `MailboxWorkflowEntry` now provide the bounded mailbox workflow vocabulary above the existing
    runtime and delivery-plan surfaces without taking inspect/selector behavior early
  - `MailboxSession.inspectWorkflow(...)` now exposes one explicit caller-owned mailbox workflow
    plan over runtime state plus optional pending delivery work, so callers no longer need to
    hand-compose pending publish-vs-receive posture above the mailbox session
  - `MailboxWorkflowPlan.nextEntry()` now follows pending delivery order while preserving actual
    relay readiness preconditions, so callers can select one next mailbox workflow relay without
    flattening auth/connect/publish differences above the session
  - `MailboxWorkflowPlan.nextStep()` now packages that selected mailbox workflow action plus its
    relay context into one typed SDK step instead of forcing callers to restitch workflow entry
    state above the plan
  - `MailboxSession.selectWorkflowRelay(...)` now turns that typed mailbox workflow step into one
    explicit relay selection on the session instead of forcing callers to extract and replay the
    selected relay index above the workflow
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
    recipient relay list plus sender-copy delivery, one broader mailbox workflow plan over that
    pending delivery work, explicit next-relay selection over both the delivery plan and the typed
    workflow step, runtime inspection plus explicit next-step selection, then one explicit
    file-message send-plus-receive path on the same mailbox surface, rather than pretending the
    sender's current relay is the real delivery target or that mailbox intake is direct-message-only
- the `NIP-39` grouped target-discovery loop is now complete:
  - caller-owned grouped target-discovery, grouped freshness-discovery, latest-per-target, and
    preferred-per-target storage/request types now exist as the stable vocabulary for the broader
    long-lived identity-discovery lane
  - `IdentityVerifier.discoverStoredProfileEntriesForTargets(...)` now hydrates all remembered
    profile matches for one watched target set into grouped caller-owned slices in target order
    instead of leaving broader multi-identity remembered discovery entirely above the SDK
  - `IdentityVerifier.discoverStoredProfileEntriesWithFreshnessForTargets(...)` now also groups
    freshness-classified remembered profile entries for one watched target set instead of leaving
    multi-identity age classification entirely above the SDK
  - `IdentityVerifier.getLatestStoredProfilesForTargets(...)` now selects one newest remembered
    profile per watched target in caller order instead of forcing apps to collapse grouped target
    discovery back down to latest-per-target policy above the SDK
  - `IdentityVerifier.getPreferredStoredProfilesForTargets(...)` now selects one preferred
    remembered profile per watched target in caller order instead of forcing apps to restitch
    per-target stale-fallback policy above the same grouped watched-target discovery surface
- the `NIP-39` watched-target policy loop is now complete:
  - caller-owned watched-target policy storage and grouped policy entry/group vocabulary now exist
    as the stable surface for longer-lived watched-target identity policy
  - `IdentityVerifier.inspectStoredProfilePolicyForTargets(...)` now groups one watched identity
    set into explicit verify-now, usable-preferred, and refresh-needed policy buckets instead of
    leaving that longer-lived watched-target policy entirely above the SDK
  - `IdentityStoredProfileTargetPolicyPlan.usablePreferredEntries()` now exposes the watched
    identities with usable remembered profiles without forcing apps to restitch that grouped view
    above the policy plan
  - `IdentityStoredProfileTargetPolicyPlan.verifyNowEntries()` now exposes the watched identities
    that still require verification now without forcing apps to filter the grouped policy plan
    themselves
  - `IdentityStoredProfileTargetPolicyPlan.refreshNeededEntries()` now exposes the watched
    identities that still need refresh under the chosen fallback policy without forcing apps to
    rebuild that grouped view above the same policy plan
- the `NIP-39` watched-target refresh-cadence loop is now complete:
  - caller-owned watched-target refresh-cadence storage and grouped cadence entry/group
    vocabulary now exist as the stable surface for explicit watched-target refresh timing policy
  - `IdentityVerifier.inspectStoredProfileRefreshCadenceForTargets(...)` now groups one watched
    identity set into explicit verify-now, refresh-now, usable-while-refreshing, refresh-soon,
    and stable cadence buckets instead of leaving that cadence policy entirely above the SDK
  - `IdentityStoredProfileTargetRefreshCadencePlan.nextDueEntry()` now exposes the next watched
    identity due for work under that cadence plan without forcing apps to restitch urgency order
    above the grouped cadence surface
  - `IdentityStoredProfileTargetRefreshCadencePlan.nextDueStep()` now packages that next-due
    cadence choice as one typed SDK value instead of requiring apps to restitch the selected
    target and action above the cadence plan
  - `IdentityStoredProfileTargetRefreshCadencePlan.usableWhileRefreshingEntries()` now exposes
    watched identities that remain usable while refresh is still due, and
    `refreshSoonEntries()` now exposes watched identities nearing refresh, instead of forcing apps
    to slice those grouped cadence buckets themselves
  - the outbound round-trip path now uses `noztr.nip59_wrap.nip59_build_outbound_for_recipient(...)`
    and `noztr.nip01_event.event_serialize_json_object_unsigned(...)` instead of SDK-local
    transcript staging
  - outbound file-message authoring now also uses
    `noztr.nip17_private_messages.nip17_build_file_*_tag(...)` for exact-fit canonical kind-15
    metadata tags instead of staging those tag shapes locally
- the `NIP-39` watched-target refresh-batch loop is now complete:
  - caller-owned watched-target refresh-batch storage and bounded selected-now vs deferred-later
    vocabulary now exist as the stable surface for turn-level watched-target refresh selection
  - `IdentityVerifier.inspectStoredProfileRefreshBatchForTargets(...)` now selects one bounded
    current-turn refresh batch from watched-target cadence instead of leaving that selection policy
    above the SDK
  - `IdentityStoredProfileTargetRefreshBatchPlan.nextBatchEntry()` now exposes the next selected
    watched identity for this turn without forcing apps to re-scan the same batch split
  - `IdentityStoredProfileTargetRefreshBatchPlan.nextBatchStep()` now packages that selected
    watched-target refresh choice as one typed SDK step instead of requiring apps to restitch it
    above the batch plan
  - `IdentityStoredProfileTargetRefreshBatchPlan.selectedEntries()` and `deferredEntries()` now
    expose the selected-now vs deferred-later split explicitly instead of forcing apps to rebuild
    that grouped batch view above the same cadence surface
- the `NIP-39` watched-target turn-policy loop is now complete:
  - caller-owned watched-target turn-policy storage and grouped current-turn vocabulary now exist
    as the stable surface for explicit current-turn identity policy
  - `IdentityVerifier.inspectStoredProfileTurnPolicyForTargets(...)` now combines watched-target
    policy and refresh-batch selection into one current-turn view instead of forcing apps to
    restitch verify-now, refresh-selected, use-cached, and deferred-refresh choice above the SDK
  - `IdentityStoredProfileTargetTurnPolicyPlan.nextWorkEntry()` now exposes the next actionable
    watched identity for the current turn without forcing apps to rescan the grouped turn plan
  - `IdentityStoredProfileTargetTurnPolicyPlan.nextWorkStep()` now packages that current-turn
    action as one typed SDK step instead of requiring apps to restitch the selected action and
    target above the plan
  - `IdentityStoredProfileTargetTurnPolicyPlan.useCachedEntries()` and `deferredEntries()` now
    expose cached-now vs deferred-later identity groups explicitly instead of forcing apps to
    rebuild that split above the same watched-target helpers
- the `NIP-39` watched-target turn-buckets loop is now complete:
  - `IdentityStoredProfileTargetTurnPolicyPlan.verifyNowEntries()` now exposes the current-turn
    verify-now bucket explicitly instead of forcing apps to reslice it above the same turn-policy
    plan
  - `IdentityStoredProfileTargetTurnPolicyPlan.refreshSelectedEntries()` now exposes the current-
    turn refresh-selected bucket explicitly instead of forcing apps to reslice it above that same
    turn-policy plan
  - `IdentityStoredProfileTargetTurnPolicyPlan.workEntries()` now exposes the whole current-turn
    actionable slice explicitly instead of forcing apps to concatenate verify-now and refresh-
    selected buckets themselves
  - `IdentityStoredProfileTargetTurnPolicyPlan.idleEntries()` now exposes the complementary cached-
    or-deferred slice explicitly instead of forcing apps to restitch idle identities above the same
    turn-policy surface
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
  - `IdentityVerifier` now also exposes `discoverLatestStoredProfileFreshnessForTargets(...)` so
    callers can classify the newest remembered profile for one explicit watched identity set in
    caller order instead of hand-looping one provider identity at a time above the same store
    seam
  - `IdentityVerifier` now also exposes `inspectLatestStoredProfileFreshnessForTargets(...)`, and
    `IdentityStoredProfileTargetLatestFreshnessPlan` now exposes `nextEntry()`, so callers can
    identify the first non-fresh watched identity in caller order without hand-scanning that
    watched-target latest-freshness surface above the workflow
  - `IdentityStoredProfileTargetLatestFreshnessPlan` now also exposes `nextStep()` so callers can
    consume that watched-target selection as one typed SDK value instead of restitching the
    selected target above the workflow
  - `IdentityVerifier` now also exposes `getPreferredStoredProfileForTargets(...)` so callers can
    select one preferred remembered profile across a caller-owned watched identity set instead of
    rebuilding that set-level fresh-vs-stale choice above the same watched-target surface
  - `IdentityVerifier` now also exposes `planStoredProfileRefreshForTargets(...)` so callers can
    collect stale watched identities newest-first instead of rebuilding bounded set-level refresh
    targeting above the same watched-target surface
  - `IdentityStoredProfileTargetRefreshPlan` now also exposes `nextEntry()` so callers can follow
    the next watched identity to refresh without hand-scanning that set-level refresh plan above
    the workflow
  - `IdentityStoredProfileTargetRefreshPlan` now also exposes `nextStep()` so callers can consume
    that watched-target refresh selection as one typed SDK value instead of restitching the
    selected target above the workflow
  - `IdentityVerifier` now also exposes `inspectStoredProfileRuntimeForTargets(...)` so callers
    can classify one watched identity set as `verify_now`, `use_preferred`, `refresh_existing`,
    or `use_stale_and_refresh` instead of leaving that set-level verify-vs-use-vs-refresh
    decision above the same watched-target surfaces
  - `IdentityStoredProfileTargetRuntimePlan` now also exposes `nextEntry()` so callers can follow
    the next watched identity selected by that runtime policy without hand-scanning the set-level
    runtime plan above the workflow
  - `IdentityStoredProfileTargetRuntimePlan` now also exposes `nextStep()` so callers can consume
    that watched-target runtime choice as one typed SDK value instead of restitching the selected
    target and action above the workflow
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
    classified once more through one explicit watched-target latest-freshness plan plus one typed
    next step, selected once more through explicit watched-target preferred selection, selected
    once through explicit remembered-profile policy, planned once more through explicit watched-
    target stale refresh targeting plus one typed next refresh step, inspected once through
    explicit watched-target runtime policy plus one typed next runtime step, inspected once
    through explicit remembered runtime policy plus one typed next step, planned once for stale
    refresh plus one typed refresh step, and then replayed from the explicit cache
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
  - `OpenTimestampsVerifier.discoverLatestStoredVerificationFreshnessForTargets(...)` now
    classifies newest remembered verification freshness across one caller-owned proof target set
    instead of forcing apps to hand-loop per-target latest-age policy above the same store seam
  - `OpenTimestampsVerifier.getPreferredStoredVerificationForTargets(...)` now selects one
    preferred remembered verification across that grouped target set instead of rebuilding grouped
    fresh-vs-stale fallback policy above the same remembered-proof surface
  - `OpenTimestampsVerifier.planStoredVerificationRefreshForTargets(...)` now collects stale
    remembered proof targets newest-first across one caller-owned target set, and
    `OpenTimestampsStoredVerificationTargetRefreshPlan` now also exposes `nextEntry()` and
    `nextStep()` so grouped refresh driving no longer has to be reconstructed above the same
    latest-freshness surface
  - remembered-verification discovery, freshness, and preferred-selection helpers now return
    `error.InconsistentStoreData` instead of relying on invariant-only `unreachable` behavior when
    a custom verification store reports matches it cannot hydrate
  - `examples/nip03_verification_recipe.zig` now teaches verify, remember, freshness-classified
    discovery, one typed remembered runtime step, grouped target freshness/preferred/refresh
    policy, stale refresh planning, and latest remembered lookup on the same explicit public
    surface
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
4. The `NIP-39` ten-slice policy loop is complete in
   [docs/plans/nip39-ten-slice-policy-loop-plan.md](./docs/plans/nip39-ten-slice-policy-loop-plan.md).
   Treat it as reference.
5. The recent-loops audit is complete in
   [docs/plans/recent-loops-audit-plan.md](./docs/plans/recent-loops-audit-plan.md). Treat it as
   reference.
6. Treat
   [docs/plans/nip29-six-slice-background-loop-plan.md](./docs/plans/nip29-six-slice-background-loop-plan.md)
   as completed reference context for the just-closed `NIP-29` loop.
7. Treat
   [docs/plans/nip29-background-runtime-plan.md](./docs/plans/nip29-background-runtime-plan.md)
   as the broader reference baseline behind that completed loop.
8. The remaining `NIP-39` gap is now autonomous discovery/refresh policy above the current
   caller-owned watched-target inputs; do not reopen already-landed watched-target freshness,
   preferred-selection, refresh, or runtime helpers unless a real bug appears.
9. The `NIP-17` six-slice workflow loop is complete in
   [docs/plans/nip17-six-slice-workflow-loop-plan.md](./docs/plans/nip17-six-slice-workflow-loop-plan.md).
   Treat it as reference.
10. The active top-level packet is
    [docs/plans/sdk-runtime-client-store-architecture-plan.md](./docs/plans/sdk-runtime-client-store-architecture-plan.md).
11. The `NIP-39` grouped target-discovery loop is
    [docs/plans/nip39-six-slice-target-discovery-loop-plan.md](./docs/plans/nip39-six-slice-target-discovery-loop-plan.md).
    Treat it as reference.
12. The `NIP-39` watched-target policy loop is
    [docs/plans/nip39-six-slice-target-policy-loop-plan.md](./docs/plans/nip39-six-slice-target-policy-loop-plan.md).
    Treat it as reference.
13. The `NIP-39` watched-target refresh-cadence loop is
    [docs/plans/nip39-six-slice-refresh-cadence-loop-plan.md](./docs/plans/nip39-six-slice-refresh-cadence-loop-plan.md).
    Treat it as reference.
14. The `NIP-39` watched-target refresh-batch loop is
    [docs/plans/nip39-six-slice-refresh-batch-loop-plan.md](./docs/plans/nip39-six-slice-refresh-batch-loop-plan.md).
    Treat it as reference.
15. The `NIP-39` watched-target turn-policy loop is
    [docs/plans/nip39-six-slice-turn-policy-loop-plan.md](./docs/plans/nip39-six-slice-turn-policy-loop-plan.md).
    Treat it as reference.
16. The `NIP-39` watched-target turn-buckets loop is
    [docs/plans/nip39-five-slice-turn-buckets-loop-plan.md](./docs/plans/nip39-five-slice-turn-buckets-loop-plan.md).
    Treat it as reference.
17. The broader `NIP-03` proof-policy parent packet is
    [docs/plans/nip03-long-lived-policy-plan.md](./docs/plans/nip03-long-lived-policy-plan.md).
    Treat it as reference unless it directly supports the active top-level SDK architecture lane.
18. The `NIP-03` grouped target-policy loop is
    [docs/plans/nip03-six-slice-target-policy-loop-plan.md](./docs/plans/nip03-six-slice-target-policy-loop-plan.md).
    Treat it as reference.
19. Keep protocol parsing, validation, building, signing, and deterministic reduction in `noztr`.
20. Keep `examples/README.md` current whenever the public teaching surface changes.
21. Record any new kernel issue in [docs/plans/noztr-feedback-log.md](./docs/plans/noztr-feedback-log.md).
22. Treat `docs/archive/` as historical context only, not startup reading.
23. Keep `NIP-03` scoped to broader proof workflow work only:
   `OpenTimestampsVerifier.verifyRemote(...)` and `verifyRemoteCached(...)` already cover the
   explicit detached-proof HTTP seam plus bounded proof-store reuse, and the current slice now also
   covers remembered runtime inspection plus typed next-step selection; the remaining gap is broader
   Bitcoin verification, freshness, and durable proof-store policy.
24. Use
    [docs/plans/zig-nostr-ecosystem-readiness-matrix.md](./docs/plans/zig-nostr-ecosystem-readiness-matrix.md)
    when selecting broader nontrivial lanes so we keep optimizing for a real Zig Nostr ecosystem,
    not only incremental NIP count.
25. Use
    [docs/plans/zig-nostr-ecosystem-phased-plan.md](./docs/plans/zig-nostr-ecosystem-phased-plan.md)
    to keep implementation ordered as:
    shared SDK architecture -> CLI -> signer tooling -> relay framework -> performant relay ->
    Blossom -> broader client ecosystem.
26. Treat [docs/release/README.md](./docs/release/README.md) plus
    [examples/README.md](./examples/README.md) as the public SDK documentation route, and keep
    `docs/plans/` / `docs/guides/` / `docs/index.md` as internal engineering docs.
