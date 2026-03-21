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
- `signer_connect_job_client_recipe.zig`
  - goal: prepare one command-ready signer connect job that either yields one relay `AUTH` event
    or one `connect` request, then close it with one validated connect response
  - public SDK surface: `noztr_sdk.client`, `SignerConnectJobClient`,
    `SignerConnectJobClientStorage`, `SignerConnectJobAuthEventStorage`,
    `PreparedSignerConnectJobAuthEvent`, `SignerConnectJobRequest`,
    `SignerConnectJobReady`, `SignerConnectJobResult`
  - kernel fixture help: `noztr.nip46_remote_signing`, `noztr.nip42_auth`
  - control points: relay auth handling stays explicit and caller-driven, request building still
    routes through the bounded signer client floor, and this layer only exposes command-ready
    connect posture instead of inventing hidden transport or reconnect policy
- `signer_pubkey_job_client_recipe.zig`
  - goal: prepare one command-ready signer pubkey job that either yields one relay `AUTH` event
    or one `get_public_key` request, then close it with one validated public-key response
  - public SDK surface: `noztr_sdk.client`, `SignerPubkeyJobClient`,
    `SignerPubkeyJobClientStorage`, `SignerPubkeyJobAuthEventStorage`,
    `PreparedSignerPubkeyJobAuthEvent`, `SignerPubkeyJobRequest`, `SignerPubkeyJobReady`,
    `SignerPubkeyJobResult`
  - kernel fixture help: `noztr.nip46_remote_signing`, `noztr.nip42_auth`
  - control points: signer-session establishment still stays explicit, relay auth handling stays
    explicit and caller-driven, request building still routes through the bounded signer client
    floor, and this layer only exposes command-ready pubkey posture instead of inventing transport
    or session policy
- `signer_nip44_encrypt_job_client_recipe.zig`
  - goal: prepare one command-ready signer `nip44_encrypt` job that either yields one relay
    `AUTH` event or one `nip44_encrypt` request, then close it with one validated text response
  - public SDK surface: `noztr_sdk.client`, `SignerNip44EncryptJobClient`,
    `SignerNip44EncryptJobClientStorage`, `SignerNip44EncryptJobAuthEventStorage`,
    `PreparedSignerNip44EncryptJobAuthEvent`, `SignerNip44EncryptJobRequest`,
    `SignerNip44EncryptJobReady`, `SignerNip44EncryptJobResult`
  - kernel fixture help: `noztr.nip46_remote_signing`, `noztr.nip42_auth`
  - control points: signer-session establishment still stays explicit, relay auth handling stays
    explicit and caller-driven, request building still routes through the bounded signer client
    floor, and this layer only exposes command-ready encrypt posture instead of inventing
    transport or session policy
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
- `local_key_job_client_recipe.zig`
  - goal: derive one deterministic public key and generate one fresh keypair through one
    command-ready SDK job layer
  - public SDK surface: `noztr_sdk.client`, `LocalKeyJobClient`, `LocalKeyJobClientStorage`,
    `LocalKeyJobRequest`, `LocalKeyJobResult`
  - kernel fixture help: `noztr.nostr_keys`
  - control points: key generation and pubkey derivation still route through the local operator
    floor, the job layer adds command-ready result posture instead of secret-store policy, and
    downstream tools can build local key commands without stitching deterministic key helpers
    together ad hoc
- `local_entity_job_client_recipe.zig`
  - goal: encode one `npub`, encode one `nsec`, and decode one representative `NIP-19` entity
    through one command-ready SDK job layer
  - public SDK surface: `noztr_sdk.client`, `LocalEntityJobClient`,
    `LocalEntityJobClientStorage`, `LocalEntityJobRequest`, `LocalEntityJobResult`
  - kernel fixture help: `noztr.nip19_bech32`
  - control points: entity encode-decode still routes through the local operator floor, the job
    layer adds command-ready result posture instead of CLI-owned bech32 wiring, and downstream
    tools can build local entity commands without stitching `NIP-19` helpers together ad hoc
- `local_event_job_client_recipe.zig`
  - goal: sign one local draft, verify that signed event, and inspect one event JSON through one
    command-ready SDK job layer
  - public SDK surface: `noztr_sdk.client`, `LocalEventJobClient`,
    `LocalEventJobClientStorage`, `LocalEventJobRequest`, `LocalEventJobResult`
  - kernel fixture help: `noztr.nip01_event`, `noztr.nostr_keys`
  - control points: event parse, sign, and verify still route through the local operator floor,
    the job layer adds command-ready result posture instead of CLI-owned event wiring, and
    downstream tools can build local inspect/sign commands without stitching event helpers
    together ad hoc
- `local_nip44_job_client_recipe.zig`
  - goal: encrypt one plaintext to a peer and decrypt it again through one command-ready SDK job
    layer
  - public SDK surface: `noztr_sdk.client`, `LocalNip44JobClient`,
    `LocalNip44JobClientStorage`, `LocalNip44JobRequest`, `LocalNip44JobResult`
  - kernel fixture help: `noztr.nip44`
  - control points: local crypto still routes through the local operator floor, caller-owned
    output buffers and optional nonce posture stay explicit, and downstream tools can build local
    crypto commands without stitching `NIP-44` helpers together ad hoc
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
- `publish_job_client_recipe.zig`
  - goal: prepare one command-ready publish job that either yields one auth event or one bounded
    publish request, then close it with one validated publish `OK`
  - public SDK surface: `noztr_sdk.client`, `PublishJobClient`, `PublishJobClientStorage`,
    `PublishJobAuthEventStorage`, `PreparedPublishJobAuthEvent`, `PublishJobRequest`,
    `PublishJobReady`, `PublishJobResult`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: auth handling still routes through the auth-aware publish turn floor, publish
    request creation still routes through the bounded publish turn floor, and this layer only
    exposes command-ready job posture instead of inventing transport or output policy
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
- `auth_count_turn_client_recipe.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded count turn
  - public SDK surface: `noztr_sdk.client`, `AuthCountTurnClient`,
    `AuthCountTurnClientStorage`, `AuthCountEventStorage`, `PreparedAuthCountEvent`,
    `AuthCountTurnStep`, `AuthCountTurnResult`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor, count turn
    closure still routes through the count turn floor, and this layer only adds typed auth-first
    recovery instead of inventing implicit auth retries or background query ownership
- `count_job_client_recipe.zig`
  - goal: prepare one command-ready count job that either yields one auth event or one bounded
    `COUNT` request, then close it with one validated `COUNT` reply
  - public SDK surface: `noztr_sdk.client`, `CountJobClient`, `CountJobClientStorage`,
    `CountJobAuthEventStorage`, `PreparedCountJobAuthEvent`, `CountJobRequest`, `CountJobReady`,
    `CountJobResult`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: auth handling still routes through the auth-aware count turn floor, count
    request creation still routes through the bounded count turn floor, and this layer only
    exposes command-ready job posture instead of inventing transport or output policy
- `auth_subscription_turn_client_recipe.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded subscription turn
  - public SDK surface: `noztr_sdk.client`, `AuthSubscriptionTurnClient`,
    `AuthSubscriptionTurnClientStorage`, `AuthSubscriptionEventStorage`,
    `PreparedAuthSubscriptionEvent`, `AuthSubscriptionTurnStep`, `AuthSubscriptionTurnResult`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor,
    subscription transcript closure still routes through the subscription turn floor, and this
    layer only adds typed auth-first recovery instead of inventing implicit auth retries or hidden
    follow ownership
- `subscription_job_client_recipe.zig`
  - goal: prepare one command-ready bounded subscription job that either yields one auth event or
    one subscription request, then close it with bounded transcript intake and explicit `CLOSE`
  - public SDK surface: `noztr_sdk.client`, `SubscriptionJobClient`,
    `SubscriptionJobClientStorage`, `SubscriptionJobAuthEventStorage`,
    `PreparedSubscriptionJobAuthEvent`, `SubscriptionJobRequest`, `SubscriptionJobIntake`,
    `SubscriptionJobReady`, `SubscriptionJobResult`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: auth handling still routes through the auth-aware subscription turn floor,
    transcript closure still routes through the bounded subscription turn floor, and this layer
    only exposes command-ready job posture instead of inventing hidden follow ownership
- `auth_replay_turn_client_recipe.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded replay turn
  - public SDK surface: `noztr_sdk.client`, `AuthReplayTurnClient`,
    `AuthReplayTurnClientStorage`, `AuthReplayEventStorage`, `PreparedAuthReplayEvent`,
    `AuthReplayTurnStep`, `AuthReplayTurnResult`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`, `noztr.nostr_keys`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor, replay
    transcript plus checkpoint closure still route through the replay turn floor, and this layer
    only adds typed auth-first recovery instead of inventing implicit auth retries or hidden sync
    ownership
- `replay_job_client_recipe.zig`
  - goal: prepare one command-ready replay job that either yields one auth event or one bounded
    replay request, then close it with explicit replay transcript and checkpoint posture
  - public SDK surface: `noztr_sdk.client`, `ReplayJobClient`, `ReplayJobClientStorage`,
    `ReplayJobAuthEventStorage`, `PreparedReplayJobAuthEvent`, `ReplayJobRequest`,
    `ReplayJobIntake`, `ReplayJobReady`, `ReplayJobResult`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`, `noztr.nostr_keys`
  - control points: auth handling still routes through the auth-aware replay turn floor, replay
    transcript and checkpoint closure still route through the bounded replay turn floor, and this
    layer only exposes command-ready job posture instead of inventing hidden sync ownership
- `count_turn_client_recipe.zig`
  - goal: begin one explicit count turn from caller-owned count specs and close it with one
    validated `COUNT` reply
  - public SDK surface: `noztr_sdk.client`, `CountTurnClient`, `CountTurnClientStorage`,
    `CountTurnRequest`, `CountTurnResult`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: relay-targeted `COUNT` preparation still routes through the shared relay query
    and exchange floors, reply validation still routes through the response floor, and this layer
    only closes one bounded count turn without inventing background query ownership
- `subscription_turn_client_recipe.zig`
  - goal: begin one explicit subscription turn from caller-owned subscription specs, accept bounded
    transcript intake, then close it explicitly
  - public SDK surface: `noztr_sdk.client`, `SubscriptionTurnClient`,
    `SubscriptionTurnClientStorage`, `SubscriptionTurnState`, `SubscriptionTurnRequest`,
    `SubscriptionTurnIntake`, `SubscriptionTurnResult`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: outbound `REQ` and `CLOSE` composition still route through the shared query
    and exchange floors, transcript validation still routes through the response floor, and this
    layer only closes one bounded subscription turn without inventing long-lived follow ownership
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
- `relay_registry_archive_recipe.zig`
  - goal: remember one explicit relay set in bounded local storage and list it back in stable
    order
  - public SDK surface: `noztr_sdk.store`, `RelayRegistryArchive`, `RelayInfoStore`,
    `RelayInfoRecord`, `RelayInfoResultPage`, `MemoryRelayInfoStore`
  - kernel fixture help: relay URL validation still routes through the SDK's relay URL seam
  - control points: caller still owns store construction, relay membership state stays explicit
    and side-effect free, and the helper proves `znk`-class tooling can remember a relay set on
    SDK seams without rebuilding ad hoc local registry logic
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
- `relay_directory_job_client_recipe.zig`
  - goal: refresh one relay's `NIP-11` metadata over the explicit HTTP seam and keep the bounded
    remembered record in the relay registry
  - public SDK surface: `noztr_sdk.client`, `RelayDirectoryJobClient`,
    `RelayDirectoryJobClientStorage`, `RelayDirectoryRefreshJob`, `RelayDirectoryRefreshJobResult`,
    `noztr_sdk.transport.HttpClient`, `noztr_sdk.store.RelayRegistryArchive`
  - kernel fixture help: `noztr.nip11`
  - control points: HTTP ownership stays explicit, URL/body/parse buffers stay caller-owned, and
    the job layer adds one command-ready metadata refresh posture instead of pulling network policy
    or file ownership into the SDK
- `relay_workspace_client_recipe.zig`
  - goal: remember one explicit relay set, restore it into the shared relay runtime, inspect the
    bounded runtime view, and derive one bounded replay plan over that remembered state
  - public SDK surface: `noztr_sdk.client`, `RelayWorkspaceClient`,
    `RelayWorkspaceClientStorage`, `RelayWorkspaceRestoreResult`, `noztr_sdk.store.RelayRegistryArchive`,
    `noztr_sdk.store.RelayCheckpointArchive`, `noztr_sdk.runtime.RelayPoolPlan`,
    `noztr_sdk.runtime.RelayPoolReplayPlan`
  - kernel fixture help: none beyond the shared relay runtime and relay URL seams
  - control points: remembered relay state stays explicit, runtime restore stays a separate step
    instead of hidden bootstrap, and replay/checkpoint inspection reuse the shared SDK seams
    instead of forcing `znk` to rebuild another local relay workspace model
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
- `legacy_dm_workflow_recipe.zig`
  - goal: build one signed legacy kind-`4` direct message explicitly, serialize it once, then
    accept and decrypt it through the workflow floor without inventing relay or polling policy
  - public SDK surface: `LegacyDmSession`, `LegacyDmDirectMessageRequest`,
    `LegacyDmOutboundStorage`, `PreparedLegacyDmEvent`, `LegacyDmMessageOutcome`
  - kernel fixture help: `noztr.nip04`, `noztr.nostr_keys`, `noztr.nip01_event`
  - control points: strict legacy payload and kind-`4` validation still route through
    `noztr-core`, reply and relay-hint tag shaping stay explicit in the SDK workflow floor, and
    outbound serialization plus inbound plaintext recovery remain fully caller-owned
- `legacy_dm_publish_job_client_recipe.zig`
  - goal: drive one auth-aware legacy kind-`4` DM publish path through one bounded job surface
  - public SDK surface: `noztr_sdk.client`, `LegacyDmPublishJobClient`,
    `LegacyDmPublishJobClientStorage`, `LegacyDmPublishJobAuthEventStorage`,
    `PreparedLegacyDmPublishJobAuthEvent`, `LegacyDmPublishJobRequest`,
    `LegacyDmPublishJobReady`, `LegacyDmPublishJobResult`
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: DM event shaping still routes through the legacy DM workflow floor, auth
    event authoring still stays explicit and caller-owned, and this layer only selects one
    `authenticate` or one `publish` step without inventing retry, transport, or polling policy
- `legacy_dm_replay_turn_client_recipe.zig`
  - goal: replay one checkpoint-backed legacy kind-`4` transcript explicitly, then decrypt replay
    events through one bounded intake adapter
  - public SDK surface: `noztr_sdk.client`, `LegacyDmReplayTurnClient`,
    `LegacyDmReplayTurnClientStorage`, `LegacyDmReplayTurnRequest`,
    `LegacyDmReplayTurnIntake`, `LegacyDmReplayTurnResult`, `LegacyDmMessageOutcome`,
    `noztr_sdk.runtime.RelayReplaySpec`, `noztr_sdk.store.RelayCheckpointArchive`
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: replay planning and checkpoint closure still route through the shared relay
    replay floor, parsed transcript events stay as event objects, and this layer only adds
    legacy-DM plaintext intake instead of inventing polling or background sync
- `legacy_dm_subscription_turn_client_recipe.zig`
  - goal: start one live legacy kind-`4` subscription turn explicitly, then decrypt transcript
    events through one bounded intake adapter
  - public SDK surface: `noztr_sdk.client`, `LegacyDmSubscriptionTurnClient`,
    `LegacyDmSubscriptionTurnClientStorage`, `LegacyDmSubscriptionTurnRequest`,
    `LegacyDmSubscriptionTurnIntake`, `LegacyDmSubscriptionTurnResult`,
    `LegacyDmMessageOutcome`, `noztr_sdk.runtime.RelaySubscriptionSpec`
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: live transcript close posture still routes through the shared subscription
    turn floor, parsed transcript events stay as event objects, and this layer only adds
    legacy-DM plaintext intake instead of inventing a polling loop
- `legacy_dm_sync_runtime_client_recipe.zig`
  - goal: step one bounded legacy-DM sync runtime explicitly, inspect one broader DM
    orchestration helper above that runtime plus one caller-owned replay-refresh cadence helper,
    then drive durable resume export/restore, explicit reconnect, subscribe, and live receive
    posture
  - public SDK surface: `noztr_sdk.client`, `LegacyDmReplayJobClient`,
    `LegacyDmSubscriptionJobClient`, `LegacyDmSyncRuntimeClient`,
    `LegacyDmSyncRuntimeClientStorage`, `LegacyDmSyncRuntimeResumeStorage`,
    `LegacyDmSyncRuntimeResumeState`, `LegacyDmSyncRuntimePlanStorage`,
    `LegacyDmSyncRuntimePlan`, `LegacyDmSyncRuntimeStep`,
    `LegacyDmLongLivedDmPolicyStorage`, `LegacyDmLongLivedDmPolicyPlan`,
    `LegacyDmLongLivedDmPolicyStep`, `LegacyDmOrchestrationStorage`,
    `LegacyDmOrchestrationPlan`, `LegacyDmOrchestrationStep`,
    `LegacyDmRuntimeCadenceRequest`, `LegacyDmRuntimeCadenceStorage`,
    `LegacyDmRuntimeCadenceWaitReason`, `LegacyDmRuntimeCadencePlan`,
    `LegacyDmRuntimeCadenceStep`,
    `LegacyDmSyncRuntimeAuthEventStorage`, `PreparedLegacyDmSyncRuntimeAuthEvent`,
    `LegacyDmSyncRuntimeReplayRequest`, `LegacyDmSyncRuntimeSubscriptionRequest`,
    `noztr_sdk.runtime.RelayReplaySpec`, `noztr_sdk.runtime.RelaySubscriptionSpec`,
    `noztr_sdk.store.RelayCheckpointArchive`
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: replay and live turns still route through the bounded legacy-DM turn floors,
    auth event authoring stays explicit and caller-owned, replay catch-up completion is caller-set
    instead of hidden, restored runtime still requires explicit reconnect before resumed replay or
    live subscribe work, and the broader orchestration plus cadence helpers only classify reusable
    next-phase DM posture instead of taking hidden cadence or daemon ownership
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
- `mailbox_event_intake_recipe.zig`
  - goal: parse one wrapped event object once, then feed that event object directly into the
    mailbox intake floor without reserializing it back into JSON
  - public SDK surface: `MailboxSession`, `MailboxEnvelopeOutcome`
  - kernel fixture help: `noztr.nip01_event`, `noztr.nip17_private_messages`
  - control points: parsed relay transcript events can stay as event objects, mailbox unwrap still
    routes through the SDK workflow floor, and replay-driven inbox sync does not need to rebuild
    JSON just to reuse mailbox intake logic
- `mailbox_receive_turn_recipe.zig`
  - goal: select one ready mailbox relay explicitly, then accept one wrapped envelope through one
    bounded receive-turn floor
  - public SDK surface: `MailboxSession`, `MailboxReceiveTurnStorage`,
    `MailboxReceiveTurnRequest`, `MailboxReceiveTurnResult`, `MailboxEnvelopeOutcome`
  - kernel fixture help: `noztr.nip17_private_messages`
  - control points: ready-relay selection still routes through mailbox runtime inspection, intake
    still routes through the mailbox unwrap floor, and this layer only closes one receive turn
    without inventing polling, sync policy, or hidden relay rotation
- `mailbox_sync_turn_recipe.zig`
  - goal: promote one pending mailbox delivery into one explicit publish step, and fall back to
    one bounded receive step when no delivery is pending
  - public SDK surface: `MailboxSession`, `MailboxSyncTurnStorage`, `MailboxSyncTurnRequest`,
    `MailboxSyncTurnResult`, `MailboxDeliveryPlan`, `MailboxReceiveTurnResult`
  - kernel fixture help: `noztr.nip17_private_messages`
  - control points: mailbox workflow inspection still owns next-step ordering, publish work stays
    explicit instead of hidden behind a send loop, receive work still routes through the bounded
    receive-turn floor, and this layer only exposes one typed sync step at a time instead of
    inventing a daemon or background mailbox scheduler
- `mailbox_job_client_recipe.zig`
  - goal: drive mailbox auth, publish, and receive work through one command-ready job surface
  - public SDK surface: `noztr_sdk.client`, `MailboxJobClient`, `MailboxJobClientStorage`,
    `MailboxJobAuthEventStorage`, `PreparedMailboxJobAuthEvent`, `MailboxJobReady`,
    `MailboxJobResult`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`
  - control points: mailbox relay state still lives in the mailbox workflow floor, auth event
    creation stays explicit and caller-owned, delivery planning still routes through the mailbox
    session floor, receive work still routes through the bounded receive-turn floor, and this
    layer only exposes command-ready mailbox posture instead of inventing transport, polling, or
    UI policy
- `mailbox_subscription_turn_client_recipe.zig`
  - goal: start one live mailbox subscription turn explicitly, classify wrapped transcript events
    through mailbox intake, then close the live turn explicitly
  - public SDK surface: `noztr_sdk.client`, `MailboxSubscriptionTurnClient`,
    `MailboxSubscriptionTurnClientStorage`, `MailboxSubscriptionTurnRequest`,
    `MailboxSubscriptionTurnIntake`, `MailboxSubscriptionTurnResult`,
    `noztr_sdk.runtime.RelaySubscriptionSpec`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip01_filter`,
    `noztr.nip01_message`
  - control points: live subscription request/close still route through the shared subscription
    turn floor, wrapped transcript events stay as parsed event objects instead of being
    reserialized back into JSON, mailbox unwrap still routes through the mailbox workflow floor,
    and this layer only closes one bounded live mailbox transcript turn without inventing polling
    or hidden follow ownership
- `mailbox_subscription_job_client_recipe.zig`
  - goal: prepare one mailbox live-subscription job that either yields one auth event or one
    bounded mailbox subscription request, then close the turn explicitly
  - public SDK surface: `noztr_sdk.client`, `MailboxSubscriptionJobClient`,
    `MailboxSubscriptionJobClientStorage`, `MailboxSubscriptionJobAuthEventStorage`,
    `PreparedMailboxSubscriptionJobAuthEvent`, `MailboxSubscriptionJobRequest`,
    `MailboxSubscriptionJobIntake`, `MailboxSubscriptionJobReady`,
    `MailboxSubscriptionJobResult`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`,
    `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: auth handling still routes through shared relay auth state, live mailbox
    transcript work still routes through the bounded mailbox subscription turn floor, and this
    layer only exposes command-ready live mailbox posture instead of inventing polling or daemon
    policy
- `mailbox_sync_runtime_client_recipe.zig`
  - goal: plan one bounded mailbox sync runtime explicitly, inspect one broader DM orchestration
    helper above that runtime plus one caller-owned DM cadence/backoff helper, then drive durable
    resume export/restore, explicit reconnect, resubscribe, and live receive posture without
    inventing a daemon
  - public SDK surface: `noztr_sdk.client`, `MailboxSyncRuntimeClient`,
    `MailboxSyncRuntimeClientStorage`, `MailboxSyncRuntimeResumeStorage`,
    `MailboxSyncRuntimeResumeState`, `MailboxSyncRuntimePlanStorage`,
    `MailboxSyncRuntimePlan`, `MailboxSyncRuntimeStep`,
    `MailboxLongLivedDmPolicyStorage`, `MailboxLongLivedDmPolicyPlan`,
    `MailboxLongLivedDmPolicyStep`, `MailboxDmOrchestrationStorage`,
    `MailboxDmOrchestrationPlan`, `MailboxDmOrchestrationStep`,
    `MailboxDmRuntimeCadenceRequest`, `MailboxDmRuntimeCadenceStorage`,
    `MailboxDmRuntimeCadenceWaitReason`, `MailboxDmRuntimeCadencePlan`,
    `MailboxDmRuntimeCadenceStep`,
    `MailboxSyncRuntimeAuthEventStorage`, `PreparedMailboxSyncRuntimeAuthEvent`,
    `MailboxSyncRuntimeReplayRequest`, `MailboxSyncRuntimeReplayIntake`,
    `MailboxSyncRuntimeSubscriptionRequest`, `MailboxSyncRuntimeSubscriptionIntake`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`,
    `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: caller still owns the decision to declare replay catch-up complete, replay and
    live transcript work still route through the bounded mailbox replay and subscription floors,
    relay cursors still stay on the shared checkpoint archive seam, restored runtime state still
    requires explicit reconnect/resubscribe driving, auth event creation stays explicit and caller-
    owned, and the broader orchestration plus cadence helpers only classify reusable next-phase DM
    posture instead of taking hidden cadence or daemon ownership
- `mailbox_replay_turn_client_recipe.zig`
  - goal: replay one checkpoint-backed mailbox transcript explicitly, classify wrapped replay
    events through mailbox intake, then close the replay turn with one explicit checkpoint result
  - public SDK surface: `noztr_sdk.client`, `MailboxReplayTurnClient`,
    `MailboxReplayTurnClientConfig`, `MailboxReplayTurnClientStorage`,
    `MailboxReplayTurnRequest`, `MailboxReplayTurnIntake`, `MailboxReplayTurnResult`,
    `noztr_sdk.runtime.RelayReplaySpec`, `noztr_sdk.store.RelayCheckpointArchive`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip01_message`
  - control points: replay cursor planning still routes through the shared replay turn floor,
    wrapped transcript events stay as parsed event objects instead of being reserialized back into
    JSON, mailbox unwrap still routes through the mailbox workflow floor, and this layer only
    closes one bounded mailbox replay turn without inventing polling or hidden sync policy
- `mailbox_replay_job_client_recipe.zig`
  - goal: prepare mailbox replay work that either yields one auth event or one bounded mailbox
    replay request, then close that replay with explicit mailbox intake and checkpoint posture
  - public SDK surface: `noztr_sdk.client`, `MailboxReplayJobClient`,
    `MailboxReplayJobClientStorage`, `MailboxReplayJobAuthEventStorage`,
    `PreparedMailboxReplayJobAuthEvent`, `MailboxReplayJobRequest`,
    `MailboxReplayJobIntake`, `MailboxReplayJobReady`, `MailboxReplayJobResult`
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`, `noztr.nip01_message`
  - control points: auth handling still routes through shared relay auth state, replay request and
    checkpoint closure still route through the bounded mailbox replay turn floor, wrapped replay
    events still flow straight into mailbox intake as parsed event objects, and this layer only
    exposes command-ready mailbox replay posture instead of inventing polling or daemon policy
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
- `nip03_verify_client_recipe.zig`
  - goal: prepare and run one command-ready remembered detached-proof `NIP-03` verify job over
    the explicit HTTP, proof-store, and remembered-verification seams
  - public SDK surface: `noztr_sdk.client`, `Nip03VerifyClient`, `Nip03VerifyClientStorage`,
    `Nip03VerifyJob`, `Nip03VerifyCachedResult`, `Nip03VerifyJobResult`
  - kernel fixture help: `noztr.nostr_keys`, `noztr.nip03_opentimestamps`
  - control points: the client only assembles remote-proof request posture above the existing
    OpenTimestamps workflow, HTTP and store ownership stay explicit, and this layer avoids
    inventing background refresh or output policy
- `nip05_verify_client_recipe.zig`
  - goal: prepare and run one command-ready `NIP-05` verify job over the public HTTP seam
  - public SDK surface: `noztr_sdk.client`, `Nip05VerifyClient`, `Nip05VerifyClientStorage`,
    `Nip05VerifyJob`, `Nip05VerifyJobResult`
  - kernel fixture help: none beyond the SDK result surface
  - control points: the client only assembles command-ready lookup storage and request posture
    above the existing resolver workflow, transport stays explicit, caller-owned buffers and
    scratch stay explicit, and this layer avoids inventing retry or output policy
- `nip39_verify_client_recipe.zig`
  - goal: prepare and run one command-ready remembered `NIP-39` profile verify job over the
    public HTTP seam with explicit cache and profile-store seams, then inspect one bounded
    remembered-target turn policy through the client surface
  - public SDK surface: `noztr_sdk.client`, `Nip39VerifyClient`, `Nip39VerifyClientStorage`,
    `Nip39VerifyJob`, `Nip39VerifySummary`, `Nip39VerifyJobResult`,
    `Nip39StoredProfilePlanning`
  - kernel fixture help: `noztr.nip39_external_identities`
  - control points: the client assembles one profile verification job plus one explicit watched-
    target turn-policy inspection above the existing identity workflow, HTTP/cache/store ownership
    stays explicit, caller-owned planning storage stays explicit, and this layer still avoids
    inventing autonomous refresh or output policy
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
- `group_fleet_client_recipe.zig`
  - goal: drive one client-facing multi-relay groups path above `GroupFleet` to inspect runtime,
    inspect consistency, persist relay-local checkpoints through one explicit store seam, restore
    a fresh client from that store, reconcile one target relay from the chosen baseline, build and
    apply one merged checkpoint from explicit relay selection, build one explicit publish fanout,
    and inspect one explicit background-runtime step
  - public SDK surface: `noztr_sdk.client`, `GroupFleetClient`, `GroupFleetClientStorage`,
    `GroupFleetClientCheckpointStorage`, `GroupFleetClientBackgroundRequest`,
    `GroupFleetClientCheckpointRequest`, `GroupFleetClientMergeSelection`,
    `GroupFleetClientMergeStorage`, `GroupFleetClientMergeRequest`,
    `GroupFleetClientPublishStorage`, `GroupFleetClientPutUserDraft`,
    `GroupFleetClientRemoveUserDraft`, `GroupFleetClientPublishRequest`,
    `GroupFleetRuntimePlan`, `GroupFleetConsistencyReport`, `GroupFleetBackgroundRuntimePlan`,
    `MemoryGroupFleetCheckpointStore`
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller still owns the relay-local `GroupClient` members and the scheduler,
    while the client layer packages bounded runtime/background/consistency plus checkpoint-store
    targeted-reconcile, merged-checkpoint, and publish-planning posture into one SDK route without
    introducing hidden relay or merge ownership

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
