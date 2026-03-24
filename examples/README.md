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
- [docs/reference/downstream-sdk-boundary.md](../docs/reference/downstream-sdk-boundary.md)

## Teaching Posture

- public client-composition imports come from `@import("noztr_sdk").client`
- public SDK imports come from `@import("noztr_sdk").workflows`
- grouped routes inside those namespaces are now canonical:
  - `client.local.*`, `client.relay.*`, `client.signer.*`, `client.dm.*`, `client.identity.*`,
    `client.social.*`, `client.proof.*`, `client.groups.*`
  - `workflows.groups.*`, `workflows.identity.*`, `workflows.dm.*`, `workflows.proof.*`,
    `workflows.signer.*`, `workflows.zaps.*`
- shared store/query imports come from `@import("noztr_sdk").store`
- shared relay-pool/runtime imports come from `@import("noztr_sdk").runtime`
- HTTP-backed workflow recipes also use `@import("noztr_sdk").transport`
- protocol fixture construction stays on `noztr` kernel helpers
- examples are compile-verified recipes, not hidden runtimes or framework demos
- deferred seams are named explicitly instead of being smuggled into example code
- the grouped routes are the only canonical public routes for mature surfaces in this repo

In the recipe entries below:
- treat the example file plus the grouped route from the contract map as the canonical discovery path

## If You Are Building Another Zig SDK

Use the relay/runtime examples as the reusable downstream foundation:

- [local_operator_client.zig](./local_operator_client.zig)
- [publish_client.zig](./publish_client.zig)
- [relay_pool.zig](./relay_pool.zig)
- [relay_query_client.zig](./relay_query_client.zig)
- [relay_exchange_client.zig](./relay_exchange_client.zig)
- [relay_replay_client.zig](./relay_replay_client.zig)
- [relay_auth_client.zig](./relay_auth_client.zig)
- [relay_response_client.zig](./relay_response_client.zig)
- [relay_session_client.zig](./relay_session_client.zig)
- [downstream_mixed_route.zig](./downstream_mixed_route.zig)
- [local_state_client.zig](./local_state_client.zig)
- [relay_workspace_client.zig](./relay_workspace_client.zig)
- [remote_signer.zig](./remote_signer.zig)

These examples show the current public foundation another Zig SDK can drive explicitly.

Use the mixed boundary guide first if you need the explicit split between:
- `noztr` as the true kernel floor
- `noztr-sdk` as the production-ready non-kernel layer above it

The intended arbitrary-event route is:
- deterministic event and tag shaping on `noztr`
- optional local operator composition on `noztr-sdk`
- publish or relay-session composition on `noztr-sdk`

The dedicated proof of that route is:
- `downstream_mixed_route.zig`

They do not imply:
- a hidden websocket/runtime framework
- hidden connection ownership
- product-specific policy above the relay/Nostr layer

## Start Here

- `consumer_smoke.zig`
  - goal: minimal package/import check
  - control point: verify the workflow namespace is the stable top-level entry
- `remote_signer.zig`
  - goal: explicit `NIP-46` connect plus `get_public_key`, one `nip44_encrypt` request, and one
    shared relay-pool inspect/select step
  - kernel fixture help: `noztr.nip46_remote_signing`
  - control points: caller starts connect, caller starts later signer requests, caller feeds
    responses back in explicitly, caller reuses one request context shape instead of repeating
    `buffer + id + scratch`, the shared relay-pool runtime stays explicit instead of becoming
    hidden signer policy, and the recipe keeps repetitive response JSON wiring in one small helper
    so the public session flow stays primary
- `downstream_mixed_route.zig`
  - goal: one arbitrary signed kernel event authored in `noztr`, then handed into generic SDK
    publish and relay-session composition without a duplicate downstream runtime layer
- `signer_capability.zig`
  - goal: drive one shared signer capability route through local, remote, and browser signer
    adapters while keeping backend differences explicit
  - control points: capability reporting stays honest about unsupported operations, shared request
    and result vocabulary stays bounded, local remote and browser adapters can all drive the route
    honestly, and the surface still stops short of browser-extension product ownership
- `nip07_browser_signer.zig`
  - goal: project thin browser signer presence, supported-method reporting, and shared
    signer-capability completion onto the browser seam without claiming extension or
    browser-product ownership
  - control points: browser support stays explicit about absence and partial method coverage, the
    adapter remains caller-driven, the shared signer-capability vocabulary now reaches the thin
    browser seam directly, and the SDK still stops at the reusable browser seam instead of
    expanding into extension packaging or approval UI
- `social_profile_content_client.zig`
  - goal: compose one kind-`0` profile publish, one kind-`1` note subscription, one `NIP-23`
    long-form inspection route, and explicit archive-backed latest-profile, note-page, and
    long-form selection above the local operator, publish, relay-query, and event-archive floors
  - kernel fixture help: `noztr.nip10_threads`, `noztr.nip23_long_form`,
    `noztr.nip24_extra_metadata`
  - control points: deterministic profile, thread, and long-form parsing stay on `noztr`, relay
    readiness still routes through the existing publish and query clients, archive-backed reads
    are explicit instead of hidden sync, long-form tag-building stays caller-buffered and
    explicit, and this first social route still stops short of ranking, feed sync, reactions,
    lists, or social-graph policy
- `social_reaction_list_client.zig`
  - goal: compose one `NIP-25` reaction publish route, one public `NIP-51` follow-set publish
    route, and one explicit stored latest-list selection over the local archive seam
  - kernel fixture help: `noztr.nip25_reactions`, `noztr.nip51_lists`
  - control points: deterministic reaction and list parsing still stays on `noztr`, reaction and
    list publish still routes through the existing publish floor, relay query posture stays
    bounded and caller-driven, and stored list selection stays explicit over the archive seam
    instead of becoming a hidden background sync or opaque merge engine
- `social_graph_wot_client.zig`
  - goal: compose one kind-`3` contact-list publish route, one bounded contact subscription
    posture, and one explicit starter-only WoT inspection over verified latest contact lists
  - kernel fixture help: `noztr.nip02_contacts`
  - control points: deterministic contact-tag parsing stays on `noztr`, contact-list publish and
    relay query posture still routes through the existing publish and query floors, stored latest
    contact selection stays explicit over the archive seam, contact events are verified before this
    route trusts them, and the starter-WoT route remains a bounded heuristic instead of becoming an
    opaque recommendation engine, hidden sync loop, or broader trust claim
- `social_comment_reply_client.zig`
  - goal: compose one kind-`1` reply route, one `NIP-22` comment publish route, and one explicit
    stored comment-page inspection over the shared social publish/query/archive substrate
  - kernel fixture help: `noztr.nip10_threads`, `noztr.nip22_comments`
  - control points: note-reply and comment linkage parsing still stays on `noztr`, reply and
    comment publish still route through the existing publish and query floors, and stored comment
    inspection stays explicit over the archive seam instead of becoming hidden thread policy
- `social_highlight_client.zig`
  - goal: compose one `NIP-84` address-source highlight publish route and one explicit stored
    highlight-page inspection over the shared social publish/query/archive substrate
  - kernel fixture help: `noztr.nip84_highlights`
  - control points: deterministic source, attribution, context, and comment parsing still stays on
    `noztr`, publish still routes through the existing social floor, and the route stops short of
    reader UI, annotation sync daemons, or editorial product policy
- `zap_flow.zig`
  - goal: compose one `NIP-57` zap request publish route, one explicit pay-endpoint fetch, and one
    explicit callback invoice fetch over the shared publish and HTTP seams while retaining the
    receipt-signer pubkey needed for later receipt validation
  - kernel fixture help: `noztr.nip57_zaps`
  - control points: deterministic zap request and receipt parsing still stays on `noztr`, publish
    still routes through the existing publish floor, pay-endpoint metadata remains explicit so the
    caller can retain receipt-validation inputs, and HTTP callback handling stays explicit over the
    public transport seam instead of becoming a hidden wallet runtime
- `relay_management_client.zig`
  - goal: compose `NIP-86` `supportedmethods`, `listallowedpubkeys`, `listblockedips`,
    `allowpubkey`, `listallowedkinds`, `allowkind`, `blockip`, and `banpubkey` requests over the
    explicit HTTP post seam with caller-driven `NIP-98` authorization setup, including one
    SDK-prepared convenience path and typed response parsing
  - kernel fixture help: `noztr.nip86_relay_management`, `noztr.nip98_http_auth`
  - control points: deterministic `NIP-86` request and response JSON shaping plus `NIP-98` auth-tag
    shaping stay on `noztr`, admin auth remains an explicit caller-owned secret-key precondition, and HTTP
    request ownership stays on the public transport seam instead of becoming a hidden operator
    daemon
- `signer_connect_job_client.zig`
  - goal: prepare one command-ready signer connect job that either yields one relay `AUTH` event
    or one `connect` request, then close it with one validated connect response
  - kernel fixture help: `noztr.nip46_remote_signing`, `noztr.nip42_auth`
  - control points: relay auth handling stays explicit and caller-driven, request building still
    routes through the bounded signer client floor, and this layer only exposes command-ready
    connect posture instead of inventing hidden transport or reconnect policy
- `signer_pubkey_job_client.zig`
  - goal: prepare one command-ready signer pubkey job that either yields one relay `AUTH` event
    or one `get_public_key` request, then close it with one validated public-key response
  - kernel fixture help: `noztr.nip46_remote_signing`, `noztr.nip42_auth`
  - control points: signer-session establishment still stays explicit, relay auth handling stays
    explicit and caller-driven, request building still routes through the bounded signer client
    floor, and this layer only exposes command-ready pubkey posture instead of inventing transport
    or session policy
- `signer_nip44_encrypt_job_client.zig`
  - goal: prepare one command-ready signer `nip44_encrypt` job that either yields one relay
    `AUTH` event or one `nip44_encrypt` request, then close it with one validated text response
  - kernel fixture help: `noztr.nip46_remote_signing`, `noztr.nip42_auth`
  - control points: signer-session establishment still stays explicit, relay auth handling stays
    explicit and caller-driven, request building still routes through the bounded signer client
    floor, and this layer only exposes command-ready encrypt posture instead of inventing
    transport or session policy
- `local_operator_client.zig`
  - goal: derive one local keypair, roundtrip `NIP-19` entities, sign and inspect one local
    event, and perform one explicit local `NIP-44` encrypt/decrypt roundtrip
  - kernel fixture help: `noztr.nostr_keys`, `noztr.nip19_bech32`, `noztr.nip01_event`,
    `noztr.nip44`
  - control points: the client composes deterministic kernel helpers instead of re-implementing
    them, local operator flows stay relay-free and side-effect free, caller-owned buffers and
    scratch stay explicit, and the recipe proves `znk`-class tooling can stay on SDK surfaces for
    local key/event/entity work instead of stitching kernel modules together ad hoc
- `local_key_job_client.zig`
  - goal: derive one deterministic public key and generate one fresh keypair through one
    command-ready SDK job layer
  - kernel fixture help: `noztr.nostr_keys`
  - control points: key generation and pubkey derivation still route through the local operator
    floor, the job layer adds command-ready result posture instead of secret-store policy, and
    downstream tools can build local key commands without stitching deterministic key helpers
    together ad hoc
- `local_entity_job_client.zig`
  - goal: encode one `npub`, encode one `nsec`, and decode one representative `NIP-19` entity
    through one command-ready SDK job layer
  - kernel fixture help: `noztr.nip19_bech32`
  - control points: entity encode-decode still routes through the local operator floor, the job
    layer adds command-ready result posture instead of CLI-owned bech32 wiring, and downstream
    tools can build local entity commands without stitching `NIP-19` helpers together ad hoc
- `local_event_job_client.zig`
  - goal: sign one local draft, verify that signed event, and inspect one event JSON through one
    command-ready SDK job layer
  - kernel fixture help: `noztr.nip01_event`, `noztr.nostr_keys`
  - control points: event parse, sign, and verify still route through the local operator floor,
    the job layer adds command-ready result posture instead of CLI-owned event wiring, and
    downstream tools can build local inspect/sign commands without stitching event helpers
    together ad hoc
- `local_nip44_job_client.zig`
  - goal: encrypt one plaintext to a peer and decrypt it again through one command-ready SDK job
    layer
  - kernel fixture help: `noztr.nip44`
  - control points: local crypto still routes through the local operator floor, caller-owned
    output buffers and optional nonce posture stay explicit, and downstream tools can build local
    crypto commands without stitching `NIP-44` helpers together ad hoc
- `publish_client.zig`
  - goal: sign one local event draft, inspect one explicit publish plan over the shared relay
    runtime, then pair one ready relay with one prepared outbound publish payload
  - kernel fixture help: `noztr.nip01_event`
  - control points: the client reuses the local operator floor instead of re-implementing
    signing, relay readiness still routes through the shared relay-pool layer, publish work stays
    one-shot and caller-driven without hidden transport ownership, and the recipe proves
    `znk`-class tooling can consume one SDK publish surface instead of rebuilding event-plus-relay
    glue ad hoc
- `publish_job_client.zig`
  - goal: prepare one command-ready publish job that either yields one auth event or one bounded
    publish request, then close it with one validated publish `OK`
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: auth handling still routes through the auth-aware publish turn floor, publish
    request creation still routes through the bounded publish turn floor, and this layer only
    exposes command-ready job posture instead of inventing transport or output policy
- `publish_turn_client.zig`
  - goal: begin one explicit publish turn from a local draft and close it with one validated
    publish `OK` reply
  - kernel fixture help: `noztr.nip01_message`
  - control points: local draft signing still routes through the local operator floor, relay
    publish readiness still routes through the shared relay-pool layer, publish `OK` validation
    still routes through the response floor, and this layer only closes one bounded publish turn
    without inventing retries or hidden websocket ownership
- `auth_publish_turn_client.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded publish turn
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor, publish turn
    closure still routes through the publish turn floor, and this layer only adds typed auth-first
    recovery instead of inventing implicit auth retries or background relay ownership
- `auth_count_turn_client.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded count turn
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor, count turn
    closure still routes through the count turn floor, and this layer only adds typed auth-first
    recovery instead of inventing implicit auth retries or background query ownership
- `count_job_client.zig`
  - goal: prepare one command-ready count job that either yields one auth event or one bounded
    `COUNT` request, then close it with one validated `COUNT` reply
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: auth handling still routes through the auth-aware count turn floor, count
    request creation still routes through the bounded count turn floor, and this layer only
    exposes command-ready job posture instead of inventing transport or output policy
- `auth_subscription_turn_client.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded subscription turn
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor,
    subscription transcript closure still routes through the subscription turn floor, and this
    layer only adds typed auth-first recovery instead of inventing implicit auth retries or hidden
    follow ownership
- `subscription_job_client.zig`
  - goal: prepare one command-ready bounded subscription job that either yields one auth event or
    one subscription request, then close it with bounded transcript intake and explicit `CLOSE`
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`
  - control points: auth handling still routes through the auth-aware subscription turn floor,
    transcript closure still routes through the bounded subscription turn floor, and this layer
    only exposes command-ready job posture instead of inventing hidden follow ownership
- `auth_replay_turn_client.zig`
  - goal: handle one auth-gated relay explicitly, authenticate it, then resume and close one
    bounded replay turn
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`, `noztr.nostr_keys`
  - control points: relay auth challenge handling still routes through the shared relay-pool
    state machine, auth event authoring still routes through the local operator floor, replay
    transcript plus checkpoint closure still route through the replay turn floor, and this layer
    only adds typed auth-first recovery instead of inventing implicit auth retries or hidden sync
    ownership
- `replay_job_client.zig`
  - goal: prepare one command-ready replay job that either yields one auth event or one bounded
    replay request, then close it with explicit replay transcript and checkpoint posture
  - kernel fixture help: `noztr.nip01_message`, `noztr.nip42_auth`, `noztr.nostr_keys`
  - control points: auth handling still routes through the auth-aware replay turn floor, replay
    transcript and checkpoint closure still route through the bounded replay turn floor, and this
    layer only exposes command-ready job posture instead of inventing hidden sync ownership
- `count_turn_client.zig`
  - goal: begin one explicit count turn from caller-owned count specs and close it with one
    validated `COUNT` reply
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: relay-targeted `COUNT` preparation still routes through the shared relay query
    and exchange floors, reply validation still routes through the response floor, and this layer
    only closes one bounded count turn without inventing background query ownership
- `subscription_turn_client.zig`
  - goal: begin one explicit subscription turn from caller-owned subscription specs, accept bounded
    transcript intake, then close it explicitly
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: outbound `REQ` and `CLOSE` composition still route through the shared query
    and exchange floors, transcript validation still routes through the response floor, and this
    layer only closes one bounded subscription turn without inventing long-lived follow ownership
- `relay_auth_client.zig`
  - goal: inspect one explicit relay auth challenge, build one signed `NIP-42` auth event, send it
    as one outbound `AUTH` client message, then mark the relay ready only after explicit caller
    acceptance
  - kernel fixture help: `noztr.nip42_auth`, `noztr.nip01_message`
  - control points: the shared runtime still owns relay auth-required state, the local operator
    floor still owns signing, the SDK only adds explicit auth target selection and message
    composition, and downstream tools can now handle one `AUTH` roundtrip without rebuilding
    challenge-tag authoring ad hoc
- `relay_exchange_client.zig`
  - goal: compose one publish exchange, one count exchange, and one subscription exchange on the
    same shared relay floor, then validate the matching relay replies explicitly without hidden
    transport ownership
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: the client composes the already-landed local operator, relay query, and relay
    response floors instead of replacing them, publish/count/subscription work all stay explicit
    and one-shot, and downstream tools can now consume a single SDK exchange layer for the most
    common relay roundtrips
- `relay_query_client.zig`
  - goal: inspect explicit shared relay query posture, then compose one outbound `REQ`, one
    outbound `COUNT`, and one outbound `CLOSE` payload for a ready relay without hidden
    subscription ownership
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: relay readiness still routes through the shared relay-pool layer, request
    serialization stays on the kernel, the client only pairs ready relay targets with one-shot
    request payloads, and the recipe proves `znk`-class tooling can build relay query commands on
    SDK surfaces without smuggling in a hidden streaming runtime
- `relay_replay_client.zig`
  - goal: inspect one checkpoint-backed replay step, then compose one explicit replay `REQ`
    payload for a ready relay without rebuilding checkpoint or query glue in the caller
  - kernel fixture help: `noztr.nip01_message`
  - control points: replay cursor lookup still stays on the shared checkpoint seam, relay
    readiness still routes through the shared relay-pool layer, the client only maps one
    checkpoint-backed `ClientQuery` into one outbound `REQ`, and downstream tools can now drive
    replay requests on SDK surfaces without rebuilding filter serialization ad hoc
- `relay_replay_exchange_client.zig`
  - goal: begin one checkpoint-backed replay request, accept explicit replay transcript intake,
    then compose one explicit replay `CLOSE` request without hidden sync ownership
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: replay request composition still stays on the replay client floor, transcript
    intake still stays on the response floor, this layer only binds the two into one bounded
    exchange, and downstream tools can now drive replay roundtrips on SDK surfaces without
    inventing a hidden streaming runtime
- `replay_checkpoint_advance_client.zig`
  - goal: consume one replay transcript outcome stream, derive one explicit checkpoint-advance
    candidate only after `EOSE`, then persist one explicit relay checkpoint target
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: replay transcript intake still stays on the replay exchange and response
    floors, checkpoint persistence still stays on the shared archive seam, this layer only decides
    when one replay transcript is safe to advance, and downstream tools can now save replay cursor
    progress on SDK surfaces without inventing hidden checkpoint policy
- `relay_replay_turn_client.zig`
  - goal: begin one replay turn, accept explicit replay transcript intake, then return one bounded
    close-plus-checkpoint result and persist it explicitly
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`
  - control points: replay request composition still stays on the replay exchange floor,
    checkpoint safety still stays on the replay checkpoint-advance floor, this layer only closes
    one bounded replay turn into one explicit result, and downstream tools can now drive replay
    turn loops on SDK surfaces without inventing hidden transcript or checkpoint state machines
- `relay_response_client.zig`
  - goal: start one explicit subscription transcript, accept relay `EVENT` / `EOSE` intake, then
    validate one `COUNT`, one publish `OK`, one `NOTICE`, and one `AUTH` message through typed
    receive-side SDK helpers
  - kernel fixture help: `noztr.nip01_message`, `noztr.nostr_keys`, `noztr.nip01_event`
  - control points: relay-message parsing and transcript transitions stay on the kernel, the SDK
    only adds explicit receive-side validation and typed outcomes, and downstream tools can now
    stay on SDK surfaces for the first bounded relay-response intake jobs without hiding stream
    ownership
- `relay_session_client.zig`
  - goal: drive one explicit relay session over shared runtime inspection, relay auth, outbound
    request shaping, receive-side transcript intake, and bounded member/checkpoint export-restore
  - kernel fixture help: `noztr.nip01_filter`, `noztr.nip01_message`, `noztr.nip42_auth`,
    `noztr.nostr_keys`
  - control points: shared relay runtime remains explicit instead of turning into hidden session
    ownership, auth signing still routes through the local operator floor, outbound `REQ` and
    `CLOSE` payloads still serialize on the kernel, receive-side transcript validation still
    routes through the response floor, and downstream SDKs can now build one reusable relay
    session foundation without stitching query/auth/response/checkpoint helpers together ad hoc
- `signer_client.zig`
  - goal: use one first signer-tooling client surface to drive explicit `NIP-46` connect,
    `get_public_key`, one `nip44_encrypt` request, one shared relay-runtime inspect/select step,
    and one durable resume plus reconnect-cadence check
  - kernel fixture help: `noztr.nip46_remote_signing`
  - control points: the client composes the existing remote-signer workflow instead of replacing
    it, caller still owns request storage and transport send/receive, sequential request ids are
    generated from bounded caller-owned storage instead of hidden global state, durable resume does
    not pretend a live signer session survived restart, and shared relay/session policy remains
    explicit rather than turning into signer-daemon ownership
- `store_query.zig`
  - goal: persist bounded event records, query them with one explicit cursor/page surface, and
    remember one named checkpoint
  - kernel fixture help: `noztr.nip01_event`
  - control points: caller builds event JSON on the kernel, converts it into bounded store
    records explicitly, queries through one backend-agnostic selection surface with caller-owned
    page storage, and persists one named checkpoint without committing to a durable backend yet
- `sqlite_client_store.zig`
  - goal: open one embedded durable SQLite-backed store, archive event/checkpoint state through
    the shared store seam, persist one relay-local checkpoint, and restore that state after reopen
  - kernel fixture help: `noztr.nip01_event`
  - control points: the durable baseline still satisfies the same shared store seam, higher
    archive/checkpoint helpers stay backend-agnostic, and the recipe proves serious local tooling
    can adopt one honest embedded store without inventing product-local persistence first
- `store_archive.zig`
  - goal: use one minimal CLI-facing archive helper above the shared store seam to ingest event
    JSON, replay a bounded query, and restore one named checkpoint
  - kernel fixture help: `noztr.nip01_event`
  - control points: caller still owns store construction, caller still supplies bounded scratch
    for event parsing, and the archive helper proves the shared store seam is usable above raw
    event/checkpoint stores without forcing a durable backend or hidden runtime
- `relay_registry_archive.zig`
  - goal: remember one explicit relay set in bounded local storage and list it back in stable
    order
  - kernel fixture help: relay URL validation still routes through the SDK's relay URL seam
  - control points: caller still owns store construction, relay membership state stays explicit
    and side-effect free, and the helper proves `znk`-class tooling can remember a relay set on
    SDK seams without rebuilding ad hoc local registry logic
- `cli_archive_client.zig`
  - goal: compose one CLI-facing archive client over the shared store and runtime floors: ingest
    local event JSON, query it through one bounded page, persist named and per-relay checkpoints,
    inspect shared relay runtime, and derive one bounded replay step
  - kernel fixture help: none beyond the shared store/runtime surfaces
  - control points: the client composes existing seams instead of hiding them, caller still owns
    client storage and replay specs, relay runtime and replay planning remain explicit and
    side-effect free, and the recipe proves the future CLI repo can sit above one SDK client
    surface instead of rebuilding store/runtime glue ad hoc
- `local_state_client.zig`
  - goal: compose one neutral local-state client over the shared archive, relay-registry,
    checkpoint, and relay-runtime seams: archive local events, remember one explicit relay set,
    restore it into runtime, and derive one bounded replay plan
  - kernel fixture help: none beyond the shared store/runtime surfaces
  - control points: caller still owns stores, replay specs, and remembered relay state, runtime
    restore stays explicit, and the recipe proves there is now one neutral local-state route above
    the shared archive/checkpoint/runtime seams instead of forcing apps to start from a CLI-shaped
    client
- `relay_checkpoint.zig`
  - goal: persist one named cursor per relay and scope on top of the shared checkpoint seam
  - kernel fixture help: relay URL validation still routes through the SDK's relay URL seam
  - control points: caller still owns store construction and relay URL choice, and the helper
    proves relay-local runtime state can ride the shared checkpoint seam without exposing backend
    schema or forcing the internal relay pool module into the public surface
- `relay_local_archive.zig`
  - goal: archive one relay-local event set through the shared event seam, restore one scoped
    cursor, and derive one checkpoint-backed replay query explicitly
  - kernel fixture help: `noztr.nip01_event`
  - control points: caller still owns store construction and relay choice, the helper stays
    relay-local instead of pretending the shared event seam already indexes events by relay, and
    replay planning remains one explicit checkpoint-restored query step instead of hidden server
    runtime behavior
- `relay_directory_job_client.zig`
  - goal: refresh one relay's `NIP-11` metadata over the explicit HTTP seam and keep the bounded
    remembered record in the relay registry
  - kernel fixture help: `noztr.nip11`
  - control points: HTTP ownership stays explicit, URL/body/parse buffers stay caller-owned, and
    the job layer adds one command-ready metadata refresh posture instead of pulling network policy
    or file ownership into the SDK
- `relay_workspace_client.zig`
  - goal: remember one explicit relay set, restore it into the shared relay runtime, inspect the
    bounded runtime view, and derive one bounded replay plan over that remembered state
  - kernel fixture help: none beyond the shared relay runtime and relay URL seams
  - control points: remembered relay state stays explicit, runtime restore stays a separate step
    instead of hidden bootstrap, and this narrower workspace route now sits on top of the neutral
    local-state client instead of forcing apps to start from a CLI-shaped archive composition
- `relay_local_group_archive.zig`
  - goal: archive one relay-local `NIP-29` snapshot through the shared event store seam and
    restore it into a fresh group client in explicit oldest-to-newest replay order
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller still owns store construction and group-client storage, the helper
    keeps replay relay-local instead of pretending the current shared event seam is already a
    multi-relay archive model, and the restore path makes snapshot ordering explicit instead of
    hiding newest-first query behavior behind implicit reordering
- `relay_pool.zig`
  - goal: inspect one shared multi-relay runtime plan, select one typed next pool step, then
    derive one bounded shared subscription step
  - kernel fixture help: `noztr.nip01_filter`
  - control points: caller still owns bounded pool storage, relay URLs remain explicit, the pool
    surface exposes one shared inspect/plan/step model without mailbox/groups/signer semantics,
    the new subscription surface stays caller-owned and side-effect free instead of smuggling in a
    hidden sync loop, and the recipe teaches that the shared runtime floor remains explicit rather
    than hidden background coordination
- `relay_pool_checkpoint.zig`
  - goal: export one shared relay-pool checkpoint set, persist its per-relay cursors through the
    shared checkpoint seam, restore a fresh shared pool from that bounded set explicitly, then
    derive one typed replay-now step over the same shared pool plus checkpoint seam
  - kernel fixture help: none beyond the shared relay URL validation and session/runtime layer
  - control points: caller still owns cursor values, pool checkpoint records stay bounded and
    backend-agnostic, persistence still routes through the shared checkpoint seam instead of being
    absorbed into `runtime`, replay planning also stays caller-owned and side-effect free over one
    explicit checkpoint scope plus query, and restore still targets one fresh shared pool without
    hidden reset or background runtime
- `legacy_dm_workflow.zig`
  - goal: build one signed legacy kind-`4` direct message explicitly, serialize it once, then
    accept and decrypt it through the workflow floor without inventing relay or polling policy
  - kernel fixture help: `noztr.nip04`, `noztr.nostr_keys`, `noztr.nip01_event`
  - control points: strict legacy payload and kind-`4` validation still route through
    `noztr-core`, reply and relay-hint tag shaping stay explicit in the SDK workflow floor, and
    outbound serialization plus inbound plaintext recovery remain fully caller-owned
- `dm_capability_client.zig`
  - goal: prepare one kind-`10050` mailbox relay-list publish, inspect one stored latest relay
    list explicitly over the archive seam, then select one explicit mixed-DM reply protocol
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip04`
  - control points: kind-`10050` tag and relay-list parsing still route through `noztr-core`,
    relay publish/query state stays explicit on the shared SDK seams, archive-backed relay-list
    inspection verifies signatures before trust, and reply selection stays explicit instead of
    pretending the SDK owns a hidden mixed inbox runtime
- `mixed_dm_client.zig`
  - goal: start from `noztr_sdk.client.dm.mixed.MixedDmClient`, normalize one mailbox and one
    legacy inbound DM explicitly, then select one reply route, remember one sender protocol for
    later replies, dedupe one observed message, and prepare one bounded mailbox-or-legacy outbound
    DM without hand-stitching protocol selection in app code
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip04`
  - control points: mailbox and legacy intake still route through their existing workflow floors,
    the mixed layer keeps sender-protocol memory caller-owned and bounded, keeps replay/live dedup
    caller-owned and bounded, routes reply and outbound protocol selection back through explicit
    policy, and does not invent a hidden inbox runtime, unread policy, or conversation model
- `legacy_dm_publish_job_client.zig`
  - goal: drive one auth-aware legacy kind-`4` DM publish path through one bounded job surface
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: DM event shaping still routes through the legacy DM workflow floor, auth
    event authoring still stays explicit and caller-owned, and this layer only selects one
    `authenticate` or one `publish` step without inventing retry, transport, or polling policy
- `legacy_dm_replay_turn_client.zig`
  - goal: replay one checkpoint-backed legacy kind-`4` transcript explicitly, then decrypt replay
    events through one bounded intake adapter
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: replay planning and checkpoint closure still route through the shared relay
    replay floor, parsed transcript events stay as event objects, and this layer only adds
    legacy-DM plaintext intake instead of inventing polling or background sync
- `legacy_dm_subscription_turn_client.zig`
  - goal: start one live legacy kind-`4` subscription turn explicitly, then decrypt transcript
    events through one bounded intake adapter
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: live transcript close posture still routes through the shared subscription
    turn floor, parsed transcript events stay as event objects, and this layer only adds
    legacy-DM plaintext intake instead of inventing a polling loop
- `legacy_dm_sync_runtime_client.zig`
  - goal: step one bounded legacy-DM sync runtime explicitly, inspect one broader DM
    orchestration helper above that runtime plus one caller-owned replay-refresh cadence helper,
    then drive durable resume export/restore, explicit reconnect, subscribe, and live receive
    posture
  - kernel fixture help: `noztr.nip04`, `noztr.nip01_message`
  - control points: replay and live turns still route through the bounded legacy-DM turn floors,
    auth event authoring stays explicit and caller-owned, replay catch-up completion is caller-set
    instead of hidden, restored runtime still requires explicit reconnect before resumed replay or
    live subscribe work, and the broader orchestration plus cadence helpers only classify reusable
    next-phase DM posture instead of taking hidden cadence or daemon ownership
- `mailbox.zig`
  - goal: build one outbound direct message once, inspect mailbox workflow actions over pending
    delivery work, inspect one shared relay-pool runtime step explicitly, unwrap it through a
    recipient mailbox session, then build one outbound file message once, plan its delivery, and
    drive that same mailbox workflow surface explicitly
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
- `mailbox_event_intake.zig`
  - goal: parse one wrapped event object once, then feed that event object directly into the
    mailbox intake floor without reserializing it back into JSON
  - kernel fixture help: `noztr.nip01_event`, `noztr.nip17_private_messages`
  - control points: parsed relay transcript events can stay as event objects, mailbox unwrap still
    routes through the SDK workflow floor, and replay-driven inbox sync does not need to rebuild
    JSON just to reuse mailbox intake logic
- `mailbox_receive_turn.zig`
  - goal: select one ready mailbox relay explicitly, then accept one wrapped envelope through one
    bounded receive-turn floor
  - kernel fixture help: `noztr.nip17_private_messages`
  - control points: ready-relay selection still routes through mailbox runtime inspection, intake
    still routes through the mailbox unwrap floor, and this layer only closes one receive turn
    without inventing polling, sync policy, or hidden relay rotation
- `mailbox_sync_turn.zig`
  - goal: promote one pending mailbox delivery into one explicit publish step, and fall back to
    one bounded receive step when no delivery is pending
  - kernel fixture help: `noztr.nip17_private_messages`
  - control points: mailbox workflow inspection still owns next-step ordering, publish work stays
    explicit instead of hidden behind a send loop, receive work still routes through the bounded
    receive-turn floor, and this layer only exposes one typed sync step at a time instead of
    inventing a daemon or background mailbox scheduler
- `mailbox_job_client.zig`
  - goal: drive mailbox auth, publish, and receive work through one command-ready job surface
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`
  - control points: relay state stays on the mailbox workflow floor, auth creation stays
    caller-owned, and this layer only exposes command-ready mailbox posture
- `mailbox_signer_job_client.zig`
  - goal: walk one remote signer through mailbox direct-message authoring explicitly, then return
    one bounded mailbox delivery plan for caller-owned publish work
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip46_remote_signing`
  - control points: signer relay/auth state stays on the bounded signer client, relay-list trust
    stays explicit, and this surface stops at prepared wrap plus delivery planning
- `mailbox_subscription_turn_client.zig`
  - goal: start one live mailbox subscription turn explicitly, classify wrapped transcript events
    through mailbox intake, then close the live turn explicitly
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip01_filter`,
    `noztr.nip01_message`
  - control points: subscription request/close still route through the shared subscription-turn
    floor, parsed events stay as events, and this layer only closes one bounded live mailbox turn
- `mailbox_subscription_job_client.zig`
  - goal: prepare one mailbox live-subscription job that either yields one auth event or one
    bounded mailbox subscription request, then close the turn explicitly
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`,
    `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: auth handling still routes through shared relay auth state, live transcript
    work stays on the bounded mailbox subscription-turn floor, and this layer stays command-ready
- `mailbox_sync_runtime_client.zig`
  - goal: plan one bounded mailbox sync runtime explicitly, inspect one broader DM orchestration
    helper above that runtime plus one caller-owned DM cadence/backoff helper, then drive durable
    resume export/restore, explicit reconnect, resubscribe, and live receive posture without
    inventing a daemon
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`,
    `noztr.nip01_filter`, `noztr.nip01_message`
  - control points: replay/live transcript work stay on the bounded mailbox floors, relay cursors
    stay on the checkpoint seam, reconnect/resubscribe stay explicit, and cadence/orchestration
    helpers classify posture without taking daemon ownership
- `mailbox_replay_turn_client.zig`
  - goal: replay one checkpoint-backed mailbox transcript explicitly, classify wrapped replay
    events through mailbox intake, then close the replay turn with one explicit checkpoint result
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip01_message`
  - control points: replay cursor planning still routes through the shared replay-turn floor,
    parsed events stay as events, and this layer only closes one bounded mailbox replay turn
- `mailbox_replay_job_client.zig`
  - goal: prepare mailbox replay work that either yields one auth event or one bounded mailbox
    replay request, then close that replay with explicit mailbox intake and checkpoint posture
  - kernel fixture help: `noztr.nip17_private_messages`, `noztr.nip42_auth`, `noztr.nip01_message`
  - control points: auth handling still routes through shared relay auth state, replay request and
    checkpoint closure stay on the bounded mailbox replay-turn floor, and this layer stays
    command-ready
- `nip03_verification.zig`
  - goal: fetch one detached OpenTimestamps proof document, store it explicitly, remember the
    verified result, classify the latest remembered verification plus remembered verification
    entries for freshness, inspect one typed remembered runtime step explicitly, drive grouped
    remembered-target freshness, preferred-selection, refresh-cadence, bounded refresh-batch
    selection, refresh readiness over the explicit archive seam, turn-policy, and refresh policy,
    plan refresh for stale remembered verifications, and recover the latest remembered
    verification for the same target event
  - kernel fixture help: `noztr.nostr_keys`
  - control points: HTTP, proof storage, and remembered verification storage stay explicit, and
    the workflow gives bounded freshness, policy, cadence, batch, and refresh planning without
    hidden refresh ownership
- `nip03_verify_client.zig`
  - goal: prepare and run one command-ready remembered detached-proof `NIP-03` verify job over
    the explicit HTTP, proof-store, and remembered-verification seams, then inspect bounded
    remembered-proof runtime, grouped target policy, refresh-cadence, refresh-batch selection,
    refresh readiness over the explicit archive seam, turn-policy, and refresh planning through
    the client surface
  - kernel fixture help: `noztr.nostr_keys`, `noztr.nip03_opentimestamps`
  - control points: the client only assembles command-ready proof work above the workflow floor,
    HTTP and store ownership stay explicit, and runtime/refresh planning stays bounded
- `nip05_verify_client.zig`
  - goal: prepare and run one command-ready `NIP-05` verify job, remember the verified
    resolution, and inspect one bounded refresh plan over the public HTTP seam
  - kernel fixture help: none beyond the SDK result surface
  - control points: the client assembles command-ready lookup and remembered-resolution work above
    the resolver workflow, transport and storage stay explicit, and refresh planning stays bounded
- `nip39_verify_client.zig`
  - goal: prepare and run one command-ready remembered `NIP-39` profile verify job over the
    public HTTP seam with explicit cache and profile-store seams, then inspect remembered-identity
    latest freshness, refresh cadence, refresh batch, and one bounded stored watched-target
    long-lived planning route through the client surface
  - kernel fixture help: `noztr.nip39_external_identities`
  - control points: the client assembles remembered-profile verification and watched-target
    planning above the identity workflow, HTTP/cache/store ownership stays explicit, and long-lived
    planning stays bounded
- `nip39_verification.zig`
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
  - kernel fixture help: `noztr.nip39_external_identities`
  - control points: HTTP, cache, verification storage, and profile storage stay caller-owned, and
    the workflow gives explicit discovery, freshness, watched-target planning, and refresh helpers
    without hidden background policy
- `nip05_resolution.zig`
  - goal: resolve and verify one `NIP-05` address, remember the successful resolution, and inspect
    one bounded refresh plan over the public HTTP seam
  - kernel fixture help: none beyond the SDK result surface
  - control points: HTTP, lookup storage, and remembered-resolution storage stay explicit, and
    refresh work remains typed planning rather than hidden retry behavior
- `group_session.zig`
  - goal: author a canonical `NIP-29` snapshot, export one checkpoint, restore it into a receiver
    client, select valid `previous` refs, build one outbound moderation event, then replay it
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller provides named caller-owned session plus previous-ref storage, marks
    relay readiness, authors the snapshot state explicitly, exports and restores one checkpoint,
    then builds and replays one explicit outbound moderation event using refs selected from client
    history
- `group_fleet.zig`
  - goal: persist relay-local `NIP-29` checkpoints from one explicit multi-relay fleet into a
    caller-owned store, restore a fresh fleet from that stored state, inspect runtime actions plus
    one explicit next runtime step over the restored relays, inspect one explicit background-
    runtime step over pending merge and publish work, inspect one typed next consistency step,
    merge divergent relay-local components by explicit relay selection, run one explicit targeted
    baseline-to-target reconcile step, then select one next moderation publish relay and one
    explicit background relay from the resulting fanout
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
- `group_fleet_client.zig`
  - goal: drive one client-facing multi-relay groups path above `GroupFleet` to inspect runtime,
    inspect consistency, persist relay-local checkpoints through one explicit store seam, restore
    a fresh client from that store, reconcile one target relay from the chosen baseline, build and
    apply one merged checkpoint from explicit relay selection, build one explicit publish fanout,
    and inspect one explicit background-runtime step
  - kernel fixture help: `noztr.nip29_relay_groups`, `noztr.nostr_keys`
  - control points: caller still owns the relay-local `GroupClient` members and the scheduler,
    while the client layer packages bounded runtime/background/consistency plus checkpoint-store
    targeted-reconcile, merged-checkpoint, and publish-planning posture into one SDK route without
    introducing hidden relay or merge ownership

## Adversarial Examples

- `group_session_adversarial_example.zig`
  - goal: prove wrong-group `NIP-29` replay is rejected before state mutation
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
