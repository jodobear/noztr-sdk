# noztr-sdk Examples

Structured workflow recipes for `noztr-sdk`.

These examples sit above the kernel recipe set in
[../../noztr-core/examples/README.md](../../noztr-core/examples/README.md). They are technical and
direct, and they intentionally teach the public workflow layer rather than app UI, network
daemons, or hidden runtime loops.

This examples catalog is part of the public SDK documentation route.
Local maintainer docs, when present, live under `.private-docs/`.

## Related Public Docs

Use these docs when you need public routing or contract context before opening a file:

- [README.md](../README.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [docs/INDEX.md](../docs/INDEX.md)
- [docs/getting-started.md](../docs/getting-started.md)
- [docs/reference/contract-map.md](../docs/reference/contract-map.md)

## Teaching Posture

- public client-composition imports come from `@import("noztr_sdk").client`
- public SDK imports come from `@import("noztr_sdk").workflows`
- shared store/query imports come from `@import("noztr_sdk").store`
- shared relay-pool/runtime imports come from `@import("noztr_sdk").runtime`
- HTTP-backed workflow recipes also use `@import("noztr_sdk").transport`
- protocol fixture construction stays on `noztr` kernel helpers
- examples are compile-verified recipes, not hidden runtimes or framework demos
- deferred seams are named explicitly instead of being smuggled into example code

## Start Here

- `consumer_smoke.zig`
  - goal: minimal package/import check
  - public SDK surface: `noztr_sdk.workflows`
  - control point: verify the workflow namespace is the stable top-level entry
- `remote_signer_recipe.zig`
  - goal: explicit `NIP-46` connect plus `get_public_key`, one `nip44_encrypt` request, and one
    shared relay-pool inspect/select step
  - public SDK surface: `RemoteSignerSession`, `RemoteSignerRelayPoolRuntimeStorage`,
    `noztr_sdk.runtime.RelayPoolStep`
  - kernel fixture help: `noztr.nip46_remote_signing`
  - control points: caller starts connect, caller starts later signer requests, caller feeds
    responses back in explicitly, caller reuses one request context shape instead of repeating
    `buffer + id + scratch`, the shared relay-pool runtime stays explicit instead of becoming
    hidden signer policy, and the recipe keeps repetitive response JSON wiring in one small helper
    so the public session flow stays primary
- `local_operator_client_recipe.zig`
  - goal: derive one local keypair, roundtrip `NIP-19` entities, sign and inspect one local
    event, and perform one explicit local `NIP-44` encrypt/decrypt roundtrip
  - public SDK surface: `noztr_sdk.client`, `LocalOperatorClient`, `LocalKeypair`,
    `LocalEventDraft`, `LocalEventInspection`
  - kernel fixture help: `noztr.nostr_keys`, `noztr.nip19_bech32`, `noztr.nip01_event`,
    `noztr.nip44`
  - control points: the client composes deterministic kernel helpers instead of re-implementing
    them, local operator flows stay relay-free and side-effect free, caller-owned buffers and
    scratch stay explicit, and the recipe proves `znk`-class tooling can stay on SDK surfaces for
    local key/event/entity work instead of stitching kernel modules together ad hoc
- `publish_client_recipe.zig`
  - goal: sign one local event draft, inspect one explicit publish plan over the shared relay
    runtime, then pair one ready relay with one prepared outbound publish payload
  - public SDK surface: `noztr_sdk.client`, `PublishClient`, `PublishClientStorage`,
    `PreparedPublishEvent`, `TargetedPublishEvent`, `noztr_sdk.runtime.RelayPoolPublishPlan`,
    `noztr_sdk.runtime.RelayPoolPublishStep`
  - kernel fixture help: `noztr.nip01_event`
  - control points: the client reuses the local operator floor instead of re-implementing
    signing, relay readiness still routes through the shared relay-pool layer, publish work stays
    one-shot and caller-driven without hidden transport ownership, and the recipe proves
    `znk`-class tooling can consume one SDK publish surface instead of rebuilding event-plus-relay
    glue ad hoc
- `publish_turn_client_recipe.zig`
  - goal: begin one explicit publish turn from a local draft and close it with one validated
    publish `OK` reply
  - public SDK surface: `noztr_sdk.client`, `PublishTurnClient`, `PublishTurnClientStorage`,
    `PublishTurnRequest`, `PublishTurnResult`
  - kernel fixture help: `noztr.nip01_message`
  - control points: local draft signing still routes through the local operator floor, relay
    publish readiness still routes through the shared relay-pool layer, publish `OK` validation
    still routes through the response floor, and this layer only closes one bounded publish turn
    without inventing retries or hidden websocket ownership
- `auth_publish_turn_client_recipe.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded publish turn
  - public SDK surface: `noztr_sdk.client`, `AuthPublishTurnClient`,
    `AuthPublishTurnClientStorage`, `AuthPublishEventStorage`, `PreparedAuthPublishEvent`,
    `AuthPublishTurnStep`, `AuthPublishTurnResult`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor, publish turn
    closure still routes through the publish turn floor, and this layer only adds typed auth-first
    recovery instead of inventing implicit auth retries or background relay ownership
- `relay_auth_client_recipe.zig`
  - goal: inspect one explicit relay auth challenge, build one signed `NIP-42` auth event, send it
    as one outbound `AUTH` client message, then mark the relay ready only after explicit caller
    acceptance
  - public SDK surface: `noztr_sdk.client`, `RelayAuthClient`, `RelayAuthClientStorage`,
    `RelayAuthTarget`, `RelayAuthEventStorage`, `PreparedRelayAuthEvent`,
    `noztr_sdk.runtime.RelayPoolAuthPlan`, `noztr_sdk.runtime.RelayPoolAuthStep`
  - kernel fixture help: `noztr.nip42_auth`, `noztr.nip01_message`
  - control points: the shared runtime still owns relay auth-required state, the local operator
    floor still owns signing, the SDK only adds explicit auth target selection and message
    composition, and downstream tools can now handle one `AUTH` roundtrip without rebuilding
    challenge-tag authoring ad hoc
- `relay_exchange_client_recipe.zig`
  - goal: compose one publish exchange, one count exchange, and one subscription exchange on the
    same shared relay floor, then validate the matching relay replies explicitly without hidden
    transport ownership
  - public SDK surface: `noztr_sdk.client`, `RelayExchangeClient`,
    `RelayExchangeClientStorage`, `PublishExchangeRequest`, `PublishExchangeOutcome`,
    `CountExchangeRequest`, `CountExchangeOutcome`, `SubscriptionExchangeRequest`,
    `SubscriptionExchangeOutcome`, `CloseExchangeRequest`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: the client composes the already-landed local operator, relay query, and relay
    response floors instead of replacing them, publish/count/subscription work all stay explicit
    and one-shot, and downstream tools can now consume a single SDK exchange layer for the most
    common relay roundtrips
- `relay_query_client_recipe.zig`
  - goal: inspect explicit shared relay query posture, then compose one outbound `REQ`, one
    outbound `COUNT`, and one outbound `CLOSE` payload for a ready relay without hidden
    subscription ownership
  - public SDK surface: `noztr_sdk.client`, `RelayQueryClient`, `RelayQueryClientStorage`,
    `RelayQueryTarget`, `TargetedSubscriptionRequest`, `TargetedCountRequest`,
    `TargetedCloseRequest`, `noztr_sdk.runtime.RelayPoolSubscriptionPlan`,
    `noztr_sdk.runtime.RelayPoolCountPlan`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: relay readiness still routes through the shared relay-pool layer, request
    serialization stays on the kernel, the client only pairs ready relay targets with one-shot
    request payloads, and the recipe proves `znk`-class tooling can build relay query commands on
    SDK surfaces without smuggling in a hidden streaming runtime
- `relay_replay_client_recipe.zig`
  - goal: inspect one checkpoint-backed replay step, then compose one explicit replay `REQ`
    payload for a ready relay without rebuilding checkpoint or query glue in the caller
  - public SDK surface: `noztr_sdk.client`, `RelayReplayClient`, `RelayReplayClientStorage`,
    `RelayReplayTarget`, `TargetedReplayRequest`, `noztr_sdk.runtime.RelayReplaySpec`,
    `noztr_sdk.runtime.RelayPoolReplayPlan`, `noztr_sdk.runtime.RelayPoolReplayStep`,
    `noztr_sdk.store.ClientCheckpointStore`
  - kernel fixture help: `noztr.nip01_message`
  - control points: replay cursor lookup still stays on the shared checkpoint seam, relay
    readiness still routes through the shared relay-pool layer, the client only maps one
    checkpoint-backed `ClientQuery` into one outbound `REQ`, and downstream tools can now drive
    replay requests on SDK surfaces without rebuilding filter serialization ad hoc
- `relay_replay_exchange_client_recipe.zig`
  - goal: begin one checkpoint-backed replay request, accept explicit replay transcript intake,
    then compose one explicit replay `CLOSE` request without hidden sync ownership
  - public SDK surface: `noztr_sdk.client`, `RelayReplayExchangeClient`,
    `RelayReplayExchangeClientStorage`, `ReplayExchangeRequest`, `ReplayExchangeOutcome`,
    `ReplayCloseRequest`, `RelaySubscriptionTranscriptStorage`, `noztr_sdk.runtime.RelayReplaySpec`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: replay request composition still stays on the replay client floor, transcript
    intake still stays on the response floor, this layer only binds the two into one bounded
    exchange, and downstream tools can now drive replay roundtrips on SDK surfaces without
    inventing a hidden streaming runtime
- `replay_checkpoint_advance_client_recipe.zig`
  - goal: consume one replay transcript outcome stream, derive one explicit checkpoint-advance
    candidate only after `EOSE`, then persist one explicit relay checkpoint target
  - public SDK surface: `noztr_sdk.client`, `ReplayCheckpointAdvanceClient`,
    `ReplayCheckpointAdvanceState`, `ReplayCheckpointAdvanceCandidate`,
    `ReplayCheckpointSaveTarget`, `ReplayExchangeRequest`, `ReplayExchangeOutcome`,
    `noztr_sdk.store.RelayCheckpointArchive`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: replay transcript intake still stays on the replay exchange and response
    floors, checkpoint persistence still stays on the shared archive seam, this layer only decides
    when one replay transcript is safe to advance, and downstream tools can now save replay cursor
    progress on SDK surfaces without inventing hidden checkpoint policy
- `relay_replay_turn_client_recipe.zig`
  - goal: begin one replay turn, accept explicit replay transcript intake, then return one bounded
    close-plus-checkpoint result and persist it explicitly
  - public SDK surface: `noztr_sdk.client`, `RelayReplayTurnClient`,
    `RelayReplayTurnClientStorage`, `ReplayTurnRequest`, `ReplayTurnIntake`, `ReplayTurnResult`,
    `noztr_sdk.runtime.RelayReplaySpec`, `noztr_sdk.store.RelayCheckpointArchive`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: replay request composition still stays on the replay exchange floor,
    checkpoint safety still stays on the replay checkpoint-advance floor, this layer only closes
    one bounded replay turn into one explicit result, and downstream tools can now drive replay
    turn loops on SDK surfaces without inventing hidden transcript or checkpoint state machines
- `relay_response_client_recipe.zig`
  - goal: start one explicit subscription transcript, accept relay `EVENT` / `EOSE` intake, then
    validate one `COUNT`, one publish `OK`, one `NOTICE`, and one `AUTH` message through typed
    receive-side SDK helpers
  - public SDK surface: `noztr_sdk.client`, `RelayResponseClient`,
    `RelaySubscriptionTranscriptStorage`, `RelaySubscriptionMessageOutcome`, `RelayCountMessage`,
    `RelayPublishOkMessage`, `RelayNoticeMessage`, `RelayAuthChallengeMessage`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`, `noztr.nip01_event`
  - control points: relay-message parsing and transcript transitions stay on the kernel, the SDK
    only adds explicit receive-side validation and typed outcomes, and downstream tools can now
    stay on SDK surfaces for the first bounded relay-response intake jobs without hiding stream
    ownership
- `signer_client_recipe.zig`
  - goal: use one first signer-tooling client surface to drive explicit `NIP-46` connect,
    `get_public_key`, one `nip44_encrypt` request, and one shared relay-runtime inspect/select step
  - public SDK surface: `noztr_sdk.client`, `SignerClient`, `SignerClientStorage`,
    `noztr_sdk.runtime.RelayPoolStep`
  - kernel fixture help: `noztr.nip46_remote_signing`
  - control points: the client composes the existing remote-signer workflow instead of replacing
    it, caller still owns request storage and transport send/receive, sequential request ids are
    generated from bounded caller-owned storage instead of hidden global state, and shared relay
    runtime inspection remains explicit rather than turning into signer-daemon policy
- `store_query_recipe.zig`
  - goal: persist bounded event records, query them with one explicit cursor/page surface, and
    remember one named checkpoint
  - public SDK surface: `noztr_sdk.store`, `MemoryClientStore`, `ClientQuery`,
    `EventQueryResultPage`, `EventCursor`, `IndexSelection`
  - kernel fixture help: `noztr.nip01_event`
  - control points: caller builds event JSON on the kernel, converts it into bounded store
    records explicitly, queries through one backend-agnostic selection surface with caller-owned
    page storage, and persists one named checkpoint without committing to a durable backend yet
- `store_archive_recipe.zig`
  - goal: use one minimal CLI-facing archive helper above the shared store seam to ingest event
    JSON, replay a bounded query, and restore one named checkpoint
  - public SDK surface: `noztr_sdk.store`, `EventArchive`, `ClientStore`, `MemoryClientStore`
  - kernel fixture help: `noztr.nip01_event`
  - control points: caller still owns store construction, caller still supplies bounded scratch
    for event parsing, and the archive helper proves the shared store seam is usable above raw
    event/checkpoint stores without forcing a durable backend or hidden runtime
- `cli_archive_client_recipe.zig`
  - goal: compose one CLI-facing archive client over the shared store and runtime floors: ingest
    local event JSON, query it through one bounded page, persist named and per-relay checkpoints,
    inspect shared relay runtime, and derive one bounded replay step
  - public SDK surface: `noztr_sdk.client`, `CliArchiveClient`, `CliArchiveClientStorage`,
    `noztr_sdk.store`, `noztr_sdk.runtime`
  - kernel fixture help: none beyond the shared store/runtime surfaces
  - control points: the client composes existing seams instead of hiding them, caller still owns
    client storage and replay specs, relay runtime and replay planning remain explicit and
    side-effect free, and the recipe proves the future CLI repo can sit above one SDK client
    surface instead of rebuilding store/runtime glue ad hoc
- `relay_checkpoint_recipe.zig`
  - goal: persist one named cursor per relay and scope on top of the shared checkpoint seam
  - public SDK surface: `noztr_sdk.store`, `RelayCheckpointArchive`, `MemoryClientStore`
  - kernel fixture help: relay URL validation still routes through the SDK's relay URL seam
  - control points: caller still owns store construction and relay URL choice, and the helper
    proves relay-local runtime state can ride the shared checkpoint seam without exposing backend
    schema or forcing the internal relay pool module into the public surface
- `relay_local_group_archive_recipe.zig`
  - goal: archive one relay-local `NIP-29` snapshot through the shared event store seam and
    restore it into a fresh group client in explicit oldest-to-newest replay order
  - public SDK surface: `noztr_sdk.store`, `RelayLocalGroupArchive`, `MemoryClientStore`,
    `GroupClient`
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller still owns store construction and group-client storage, the helper
    keeps replay relay-local instead of pretending the current shared event seam is already a
    multi-relay archive model, and the restore path makes snapshot ordering explicit instead of
    hiding newest-first query behavior behind implicit reordering
- `relay_pool_recipe.zig`
  - goal: inspect one shared multi-relay runtime plan, select one typed next pool step, then
    derive one bounded shared subscription step
  - public SDK surface: `noztr_sdk.runtime`, `RelayPool`, `RelayPoolStorage`,
    `RelayPoolPlanStorage`, `RelayPoolPlan`, `RelayPoolStep`, `RelaySubscriptionSpec`,
    `RelayPoolSubscriptionStorage`, `RelayPoolSubscriptionPlan`, `RelayPoolSubscriptionStep`
  - kernel fixture help: `noztr.nip01_filter`
  - control points: caller still owns bounded pool storage, relay URLs remain explicit, the pool
    surface exposes one shared inspect/plan/step model without mailbox/groups/signer semantics,
    the new subscription surface stays caller-owned and side-effect free instead of smuggling in a
    hidden sync loop, and the recipe teaches that the shared runtime floor remains explicit rather
    than hidden background coordination
- `relay_pool_checkpoint_recipe.zig`
  - goal: export one shared relay-pool checkpoint set, persist its per-relay cursors through the
    shared checkpoint seam, restore a fresh shared pool from that bounded set explicitly, then
    derive one typed replay-now step over the same shared pool plus checkpoint seam
  - public SDK surface: `noztr_sdk.runtime`, `RelayPool`, `RelayPoolCheckpointStorage`,
    `RelayPoolCheckpointSet`, `RelayPoolCheckpointStep`, `RelayReplaySpec`,
    `RelayPoolReplayStorage`, `RelayPoolReplayPlan`, `RelayPoolReplayStep`,
    `noztr_sdk.store.RelayCheckpointArchive`
  - kernel fixture help: none beyond the shared relay URL validation and session/runtime layer
  - control points: caller still owns cursor values, pool checkpoint records stay bounded and
    backend-agnostic, persistence still routes through the shared checkpoint seam instead of being
    absorbed into `runtime`, replay planning also stays caller-owned and side-effect free over one
    explicit checkpoint scope plus query, and restore still targets one fresh shared pool without
    hidden reset or background runtime
- `mailbox_recipe.zig`
  - goal: build one outbound direct message once, inspect mailbox workflow actions over pending
    delivery work, inspect one shared relay-pool runtime step explicitly, unwrap it through a
    recipient mailbox session, then build one outbound file message once, plan its delivery, and
    drive that same mailbox workflow surface explicitly
  - public SDK surface: `MailboxSession`, `MailboxDeliveryStorage`, `MailboxDeliveryRole`,
    `MailboxDeliveryPlan`, `MailboxDeliveryStep`, `MailboxRuntimeAction`, `MailboxRuntimeStorage`,
    `MailboxRuntimePlan`, `MailboxRuntimeStep`, `MailboxWorkflowAction`, `MailboxWorkflowStorage`,
    `MailboxWorkflowPlan`, `MailboxWorkflowStep`, `MailboxRelayPoolRuntimeStorage`,
    `MailboxFileDimensions`, `MailboxFileMessageRequest`, `MailboxEnvelopeOutcome`,
    `MailboxFileMessageOutcome`, `noztr_sdk.runtime.RelayPoolStep`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip44`, `noztr.nostr_keys`
  - control points: caller verifies the recipient relay list, optionally verifies sender-copy
    relays, builds one outbound wrap explicitly, receives the deduplicated publish-relay plan with
    relay-role annotations, can ask the delivery plan for one typed next delivery step without
    hand-scanning role flags or re-stitching wrap payload context, can also ask separately for the
    next recipient-targeted step and the next sender-copy-targeted step, inspects hydrated mailbox
    relays as explicit `connect`, `authenticate`, or `receive` actions, can ask the runtime plan
    for one typed next runtime step explicitly, can also inspect one shared relay-pool runtime
    step and route it back onto the mailbox session without inventing a second multi-relay
    readiness model above the workflow, can also inspect one broader mailbox workflow plan over
    pending delivery work and select one typed workflow relay without replaying delivery-vs-receive
    stitching above the session, feeds wrapped event JSON back into a recipient mailbox session,
    can build and plan one explicit outbound file-message wrap on the same surface, can classify
    direct-message vs file-message rumors explicitly, and still owns publication and polling
    policy
- `nip03_verification_recipe.zig`
  - goal: fetch one detached OpenTimestamps proof document, store it explicitly, remember the
    verified result, classify the latest remembered verification plus remembered verification
    entries for freshness, inspect one typed remembered runtime step explicitly, drive grouped
    remembered-target freshness, preferred-selection, and refresh policy, plan refresh for stale
    remembered verifications, and recover the latest remembered verification for the same target
    event
  - public SDK surface: `OpenTimestampsVerifier`, `OpenTimestampsRemoteProofRequest`,
    `OpenTimestampsProofStore`, `MemoryOpenTimestampsProofStore`,
    `OpenTimestampsVerificationStore`, `MemoryOpenTimestampsVerificationStore`,
    `OpenTimestampsStoredVerificationDiscoveryFreshnessStorage`,
    `OpenTimestampsPreferredStoredVerificationRequest`,
    `OpenTimestampsLatestStoredVerificationTargetStorage`,
    `OpenTimestampsPreferredStoredVerificationTargetStorage`,
    `OpenTimestampsStoredVerificationTargetRefreshStorage`,
    `OpenTimestampsStoredVerificationRuntimeStorage`,
    `OpenTimestampsStoredVerificationRuntimeAction`,
    `OpenTimestampsStoredVerificationRefreshStorage`,
    `OpenTimestampsStoredVerificationRefreshStep`,
    `OpenTimestampsStoredVerificationTargetRefreshStep`, `transport.HttpClient`
  - kernel fixture help: `noztr.nostr_keys`
  - control points: caller supplies the target event, attestation event, detached proof URL,
    caller-owned proof buffer, caller-owned proof-store records, and caller-owned remembered-
    verification store records over the explicit HTTP seam, then performs one explicit
    latest-verification freshness lookup plus one explicit preferred-verification selection over
    caller-owned freshness storage plus one explicit freshness-classified remembered
    discovery lookup plus one typed remembered runtime-step helper plus one explicit stale-proof
    refresh plan plus one typed refresh step without hidden Bitcoin refresh policy, and now gets a
    typed store inconsistency error instead of an invariant-only crash if a custom remembered-
    verification store reports matches it cannot hydrate
- `nip39_verification_recipe.zig`
  - goal: verify one full kind-10011 identity event over the public HTTP seam, reuse one explicit
    cache, remember the verified profile, hydrate one stored discovery result directly, classify
    both discovered stored entries and the latest remembered profile for freshness, group
    remembered discovery plus freshness-classified remembered discovery for one explicit watched
    identity set, classify that watched set through one latest-freshness plan plus one typed next
    step, select one preferred remembered profile per watched target plus one preferred remembered
    profile across that watched set, select one preferred remembered profile explicitly for one
    identity, plan refresh across that watched set, inspect runtime policy plus grouped target-
    policy views plus refresh-cadence, refresh-batch, turn-policy, and turn-bucket views across
    that watched set, inspect one typed remembered runtime step explicitly, plan refresh for stale
    remembered profiles explicitly, and replay the same identity from remembered state
  - public SDK surface: `IdentityVerifier`, `IdentityProfileVerificationStorage`,
    `IdentityProviderDetails`, `MemoryIdentityVerificationCache`, `MemoryIdentityProfileStore`,
    `IdentityStoredProfileDiscoveryStorage`, `IdentityStoredProfileDiscoveryFreshnessStorage`,
    `IdentityStoredProfileTarget`, `IdentityStoredProfileTargetDiscoveryStorage`,
    `IdentityStoredProfileTargetDiscoveryFreshnessStorage`,
    `IdentityStoredProfileTargetLatestFreshnessStorage`,
    `IdentityPreferredStoredProfileTargetStorage`, `IdentityStoredProfileTargetRefreshStorage`,
    `IdentityStoredProfileTargetRuntimeRequest`, `IdentityStoredProfileTargetRuntimeAction`,
    `IdentityStoredProfileTargetPolicyStorage`, `IdentityStoredProfileTargetPolicyRequest`,
    `IdentityStoredProfileTargetPolicyPlan`, `IdentityStoredProfileTargetRefreshCadenceStorage`,
    `IdentityStoredProfileTargetRefreshCadenceRequest`,
    `IdentityStoredProfileTargetRefreshCadencePlan`,
    `IdentityStoredProfileTargetRefreshBatchStorage`,
    `IdentityStoredProfileTargetRefreshBatchRequest`,
    `IdentityStoredProfileTargetRefreshBatchPlan`,
    `IdentityStoredProfileTargetTurnPolicyStorage`,
    `IdentityStoredProfileTargetTurnPolicyRequest`,
    `IdentityStoredProfileTargetTurnPolicyPlan`,
    `IdentityLatestStoredProfileFreshnessRequest`,
    `IdentityPreferredStoredProfileTargetSelectionRequest`,
    `IdentityPreferredStoredProfileRequest`, `IdentityStoredProfileFallbackPolicy`,
    `IdentityStoredProfileRuntimeStorage`, `IdentityStoredProfileRuntimeAction`,
    `IdentityStoredProfileRefreshStorage`,
    `IdentityStoredProfileRefreshStep`,
    `transport.HttpClient`
  - kernel fixture help: `noztr.nip39_external_identities`
  - control points: caller provides the HTTP client, the signed identity event, the target pubkey,
    caller-owned per-claim verification storage, caller-owned cache records, caller-owned profile
    store records, inspects provider-shaped details from the verified claims, then performs one
    explicit remembered discovery lookup, one explicit freshness-classified remembered discovery
    lookup, one newest-match remembered lookup, one grouped watched-target remembered discovery
    lookup, one grouped watched-target freshness discovery lookup, one caller-owned watched-target
    latest-freshness plan plus one typed next watched-target step, one explicit watched-target
    preferred-per-target selection step, one explicit watched-target preferred-selection step, one
    explicit watched-target stale-refresh plan plus one typed next refresh step, one explicit
    preferred-profile selection step, one explicit watched-target runtime plan plus one typed next
    runtime step, one explicit watched-target policy plan plus grouped verify-now / usable-
    preferred / refresh-needed views, one explicit watched-target refresh-cadence plan plus one
    typed next-due step and grouped usable-while-refreshing / refresh-soon views, one explicit
    watched-target refresh-batch plan plus one typed next selected step and grouped selected /
    deferred views, one explicit watched-target turn-policy plan plus one typed next work step and
    grouped verify-now / refresh-selected / work / idle / cached-now / deferred-later views, one
    explicit remembered runtime inspection step plus one typed next-step helper, one explicit
    stale-profile refresh plan plus one typed refresh step, and one explicit freshness check
    without hidden background policy
- `nip05_resolution_recipe.zig`
  - goal: resolve and verify one `NIP-05` address over the public HTTP seam
  - public SDK surface: `Nip05Resolver`, `transport.HttpClient`
  - kernel fixture help: none beyond the SDK result surface
  - control points: caller provides the HTTP client, one caller-owned lookup storage wrapper, and
    the scratch allocator
- `group_session_recipe.zig`
  - goal: author a canonical `NIP-29` snapshot, export one checkpoint, restore it into a receiver
    client, select valid `previous` refs, build one outbound moderation event, then replay it
  - public SDK surface: `GroupClient`, `GroupClientStorage`, `GroupCheckpointBuffers`,
    `GroupCheckpointContext`, `GroupPublishContext`, `GroupMetadataDraft`, `GroupRolesDraft`,
    `GroupMembersDraft`
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller provides named caller-owned session plus previous-ref storage, marks
    relay readiness, authors the snapshot state explicitly, exports and restores one checkpoint,
    then builds and replays one explicit outbound moderation event using refs selected from client
    history
- `group_fleet_recipe.zig`
  - goal: persist relay-local `NIP-29` checkpoints from one explicit multi-relay fleet into a
    caller-owned store, restore a fresh fleet from that stored state, inspect runtime actions plus
    one explicit next runtime step over the restored relays, inspect one explicit background-
    runtime step over pending merge and publish work, inspect one typed next consistency step,
    merge divergent relay-local components by explicit relay selection, run one explicit targeted
    baseline-to-target reconcile step, then select one next moderation publish relay and one
    explicit background relay from the resulting fanout
  - public SDK surface: `GroupFleet`, `GroupClient`, `GroupClientStorage`,
    `GroupRelayState`, `GroupFleetRuntimeAction`, `GroupFleetBackgroundAction`,
    `GroupFleetRuntimeStorage`, `GroupFleetBackgroundRuntimeStorage`, `GroupFleetRuntimePlan`,
    `GroupFleetBackgroundRuntimePlan`,
    `GroupFleetCheckpointStorage`, `GroupFleetCheckpointContext`,
    `GroupFleetMergeStorage`, `GroupFleetMergeContext`, `GroupFleetMergeSelection`,
    `GroupFleetMergedCheckpoint`, `GroupFleetTargetReconcileOutcome`,
    `GroupFleetCheckpointRecord`, `MemoryGroupFleetCheckpointStore`,
    `GroupFleetStorePersistOutcome`, `GroupFleetStoreRestoreOutcome`,
    `GroupFleetPublishStorage`, `GroupFleetPublishContext`, `GroupFleetRuntimeStep`,
    `GroupFleetBackgroundRuntimeStep`, `GroupFleetPublishStep`
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller still owns the relay-local clients, chooses relay URLs explicitly,
    persists relay-local checkpoints into a bounded store through the fleet, restores only the
    matching relay-local checkpoints into a fresh fleet, inspects each relay as explicit
    `connect`, `authenticate`, `reconcile`, or `ready` against a chosen baseline, can ask the
    runtime plan for one typed next runtime step without hand-scanning the fleet or re-stitching
    baseline context above the workflow, can ask the background-runtime plan for one typed merge
    or publish step without hand-scanning the broader coordinator surface, can ask the consistency
    report for one typed next divergent-relay step without hand-scanning the divergent slice or
    re-stitching baseline context above the workflow, chooses which relay contributes each merged
    checkpoint component explicitly, applies that merged checkpoint across the fleet, can then
    reconcile one chosen target relay explicitly from the chosen baseline without updating the
    whole fleet, and finally plans one explicit per-relay moderation publish through caller-owned
    buffers plus one typed next-publish step and one explicit background relay selection without
    hidden merge or runtime policy

## Adversarial Examples

- `group_session_adversarial_example.zig`
  - goal: prove wrong-group `NIP-29` replay is rejected before state mutation
  - public SDK surface: `GroupSession`
  - failure control point: `error.EventGroupMismatch`

## Deferred After The HTTP-Seam Refinement

Still intentionally deferred:
- live HTTP adapters or runtime clients
- redirect-aware `NIP-05` teaching beyond the current explicit seam limit
- broader autonomous `NIP-39` discovery and refresh policy beyond the current explicit watched-
  target freshness, preferred-selection, refresh, and runtime helpers
- longer-lived autonomous identity discovery or hidden runtime policy

Reason:
- the public seam is now explicit and teachable
- richer HTTP policy and broader identity workflow breadth are still later slices

## Verification

These files are exercised by `zig build test --summary all` through `examples/examples.zig`.
