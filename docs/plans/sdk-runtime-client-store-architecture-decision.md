---
title: SDK Runtime Client Store Architecture Decision
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - implementing_the_shared_sdk_architecture
  - deciding_how_workflow_surfaces_compose
  - preparing_cli_signer_or_relay_framework_work
depends_on:
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
  - docs/plans/noztr-sdk-ownership-matrix.md
---

# SDK Runtime Client Store Architecture Decision

This doc defines the shared architecture baseline that the active
[sdk-runtime-client-store-architecture-plan.md](./sdk-runtime-client-store-architecture-plan.md)
is trying to establish.

It is the internal architecture reference for `noztr-sdk`.

## Core Decision

`noztr-sdk` should converge on one explicit layered model:

1. transport seams
2. relay/session layer
3. relay-pool layer
4. store/query/index layer
5. runtime-plan/step layer
6. product-facing client/workflow layer

The existing workflow families should compose into that model rather than continuing as mostly
separate local runtimes.

## Layer Definitions

### 1. Transport Seams

Owns:

- explicit HTTP client seams
- later explicit WebSocket/relay transport seams

Does not own:

- hidden reconnect loops
- hidden polling
- background global runtime

Rule:

- transports stay explicit and caller-supplied

### 2. Relay/Session Layer

Owns:

- one-relay session state
- relay readiness
- auth/connect/disconnect posture
- per-relay send/receive state machines

Current examples:

- `MailboxSession`
- `GroupSession`
- `RemoteSignerSession`

Rule:

- session layers stay bounded and relay-local

### 3. Relay Pool Layer

Owns:

- multiple relay/session handles
- relay metadata and routing
- pool-wide readiness view
- subscription/sync routing targets

Does not own:

- hidden daemon policy by default

Needed next:

- one shared relay-pool vocabulary instead of workflow-specific fleet/runtime shapes only

### 4. Store/Query/Index Layer

Owns:

- caller-owned durable state boundaries
- event/query/index surfaces
- replay/sync checkpoints where appropriate
- bounded query/read models

Rule:

- stores remain explicit seams, not hidden globals
- query/index posture should become shared where possible, not duplicated by workflow family
- public workflow APIs must stay backend-agnostic
- first-party storage support should be tiered explicitly instead of implied by whichever backend is
  easiest to prototype first

### 5. Runtime Plan / Step Layer

Owns:

- side-effect-free planning over current session, pool, and store state
- typed next-step selection
- bounded background-runtime posture without hidden threads

This is the main architectural bridge between bounded SDK helpers and real products.

Rule:

- runtime helpers should expose plans and typed next steps
- products decide when to drive those steps

### 6. Product-Facing Client / Workflow Layer

Owns:

- the opinionated app-facing composition above lower layers
- CLI-friendly and service-friendly job surfaces
- higher-level workflows for messaging, groups, signer operations, identity/discovery, and proof
  flows

Does not own:

- end-user UI
- product-specific policy that belongs in a tool/app/server above the SDK

## Shared Architectural Types To Converge Toward

These are the type families the SDK should grow toward.

### Relay Pool Vocabulary

- `RelayDescriptor`
- `RelayPoolStorage`
- `RelayPool`
- `RelayPoolPlan`
- `RelayPoolStep`

Purpose:

- unify multi-relay readiness/routing concepts across mailbox, groups, and later client products

### Subscription / Sync Vocabulary

- `SubscriptionSpec`
- `SyncCursor`
- `SyncWindow`
- `SyncPlan`
- `SyncStep`

Purpose:

- avoid each product inventing its own sync semantics above the SDK

### Store / Query Vocabulary

- `ClientStore`
- `ClientQuery`
- `QueryResultPage`
- `EventCursor`
- `IndexSelection`

Purpose:

- provide a reusable shape for CLI, signer tooling, and later clients

### Runtime Vocabulary

- `ClientRuntimeStorage`
- `ClientRuntimePlan`
- `ClientRuntimeStep`
- `BackgroundWorkClass`

Purpose:

- unify runtime planning above relay pools and store/query state

### Product Client Vocabulary

- `MessagingClient`
- `SignerClient`
- `GroupsClient`
- later broader social/client surfaces

Purpose:

- expose opinionated app-facing entry points without turning the SDK into hidden runtime magic

## Architectural Rules

### No Hidden Global Runtime

- no hidden threads
- no hidden async loop
- no implicit network side effects

If a higher-level runtime exists, it must still be explicit, bounded, and inspectable.

### One Clear Step Model

The SDK should prefer:

- inspect current state
- produce a plan
- expose a typed next step
- let the caller drive execution

This model is already working well in several workflow families and should become the broader SDK
pattern.

### Shared Pool Before More Local Helper Proliferation

Before adding many more workflow-local runtime helpers, define the shared relay-pool/runtime model.

### Shared Store/Query Posture Before Product Explosion

Before building a CLI, signer product, or relay framework, define what the shared store/query
surface is supposed to look like.

### Backend-Agnostic Public Surface

- SDK-facing workflow APIs must not leak one backend's schema, transaction, or query worldview
- backend-specific capabilities belong behind storage/query seams or explicit adapter modules
- first-party backend support is allowed, but it must not become mandatory for downstream SDK users

### Explicit Storage Support Tiers

The storage posture should converge on explicit tiers:

1. required in core:
   - bounded in-memory/reference stores
2. early first-party durable support:
   - one embedded local durable backend suitable for CLI, signer tooling, and local client state
3. adapter-first or optional first-party support:
   - remote/service databases
   - relay-grade specialized engines
   - platform-specific client stores
4. product-owned storage:
   - backends whose requirements are too product-specific to shape the SDK core

Current architectural expectation:

- SQLite is the strongest current candidate for the first embedded durable backend
- LMDB/MDBX-class engines matter most for relay-grade or specialized workloads
- product repos should be free to use other backends through stable SDK seams

### Product Work Should Pressure-Test The SDK

The SDK does not need to anticipate every product abstraction in advance.

But new product repos should validate and refine the architecture, not work around missing
foundations by inventing bespoke local runtimes.

## Product Mapping

### CLI v1 needs:

- shared relay pool
- shared query/read posture
- shared publish job posture
- explicit signer/session integration

### Signer tooling v1 needs:

- remote-signer workflow plus broader runtime/session ownership
- relay pool/session model
- durable session/account state boundaries

### Relay framework v1 needs:

- explicit server-side transport/session seams
- reusable store boundary
- reusable handler/runtime posture

## What This Deprioritizes

Until this architecture is clearer, the repo should not over-prioritize:

- deeper `NIP-03` helper proliferation
- deeper `NIP-39` helper proliferation
- narrow local ergonomic improvements that do not change product readiness

Those may still happen when they close a real blocker, but they are no longer the default highest
priority.

## Next Concrete Follow-On Packets

The first child packets under the active architecture lane should likely be:

1. relay-pool and session composition baseline
2. subscription/sync baseline
3. store/query/index baseline
4. CLI-facing client surface baseline
