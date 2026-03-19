---
title: Zig CLI V1 Command Surface Plan
doc_type: packet
status: active
owner: noztr-sdk
read_when:
  - defining_the_first_external_cli_repo_surface
  - deciding_which_sdk_surfaces_the_cli_should_compose_first
depends_on:
  - docs/plans/zig-cli-tool-kickoff-plan.md
  - docs/plans/sdk-cli-client-boundary-checkpoint-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
touches_teaching_surface: yes
touches_audit_state: no
touches_startup_docs: yes
---

# Zig CLI V1 Command Surface Plan

This packet defines the first concrete command surface for the separate Zig CLI repo.

It exists to turn the CLI kickoff packet into one exact v1 command map that stays aligned with the
currently proven `noztr-sdk` surface, instead of letting the future CLI drift into ad hoc command
growth.

## Scope Delta

Define:

- the exact first CLI command groups
- the first concrete subcommands in each group
- which exported `noztr-sdk` surfaces each group should compose first
- which command families stay deferred from CLI v1

Do not define:

- full flag syntax
- output-schema details beyond broad posture
- daemon/runtime ownership
- mailbox/groups product suites
- hidden network execution loops

## CLI V1 Surface

### Archive Commands

First archive commands:

1. `archive ingest`
2. `archive query`
3. `archive checkpoint save`
4. `archive checkpoint show`

Primary SDK surfaces:

- `noztr_sdk.client.CliArchiveClient`
- `noztr_sdk.store.ClientQuery`
- `noztr_sdk.store.EventCursor`
- `noztr_sdk.store.EventArchive`

Role:

- local event ingest from explicit input
- bounded local query over archived events
- explicit named checkpoint persistence and inspection

### Relay Commands

First relay commands:

1. `relay add`
2. `relay list`
3. `relay runtime`
4. `relay checkpoint show`
5. `relay replay plan`

Primary SDK surfaces:

- `noztr_sdk.client.CliArchiveClient`
- `noztr_sdk.runtime.RelayPool`
- `noztr_sdk.runtime.RelayPoolPlan`
- `noztr_sdk.runtime.RelayPoolReplayPlan`
- `noztr_sdk.store.RelayCheckpointArchive`

Role:

- maintain one explicit relay set in CLI-local state
- inspect readiness and auth state across relays
- inspect replay requirements from explicit relay checkpoints

### Verify Commands

First verify commands:

1. `verify nip05`
2. `verify nip39`
3. `verify nip03`

Primary SDK surfaces:

- `noztr_sdk.workflows.Nip05Resolver`
- `noztr_sdk.workflows.IdentityVerifier`
- `noztr_sdk.workflows.OpenTimestampsVerifier`

Role:

- run bounded fetch-and-verify flows the SDK already owns
- expose explicit verification output without inventing a higher client layer first

### Signer Commands

First signer commands:

1. `signer connect`
2. `signer pubkey`
3. `signer nip44-encrypt`

Primary SDK surfaces:

- `noztr_sdk.workflows.RemoteSignerSession`
- `noztr_sdk.workflows.RemoteSignerRelayPoolStorage`
- `noztr_sdk.workflows.RemoteSignerRelayPoolRuntimeStorage`

Role:

- provide narrow developer/operator `NIP-46` tooling
- prove one real signer-facing product flow before broader signer UX or daemon posture exists

## Output And UX Posture

CLI v1 should default to:

- explicit command verbs
- bounded one-shot execution
- scriptable text or JSON-friendly output
- no hidden background runtime

CLI v1 should not assume:

- persistent daemon ownership
- automatic subscriptions
- automatic replay execution
- interactive TUI posture

## Deferred From CLI V1

Keep these out of scope for the first repo iteration:

- generic publish/post/create commands
- mailbox suites
- groups moderation/admin suites
- live follow/stream UX
- profile/contact/social-client UX
- long-running relay-service mode
- durable backend plurality beyond the initial bootstrap posture

## First Delivery Order

Recommended implementation order in the separate CLI repo:

1. repo bootstrap and dependency/import smoke
2. `archive ingest` and `archive query`
3. archive checkpoint commands
4. `relay list` and `relay runtime`
5. relay checkpoint and replay-plan commands
6. verify commands
7. narrow signer commands

This keeps the first CLI repo aligned with the strongest proven SDK surfaces and avoids front-loading
the riskiest runtime or signer work.

## Boundary Rule

`noztr-sdk` remains responsible for:

- reusable store/runtime/client/workflow composition
- typed plans and bounded selection helpers
- protocol and workflow correctness above `noztr`

The separate CLI repo remains responsible for:

- command tree design
- argument parsing and config loading
- file-system integration
- output formatting and scripting ergonomics
- command-level workflow orchestration

## Expected Output

This packet should be considered successful when it restores one clear next product move:

1. the exact first CLI command groups are fixed
2. their first SDK dependencies are named explicitly
3. one separate CLI repo can start without re-deciding the SDK boundary
