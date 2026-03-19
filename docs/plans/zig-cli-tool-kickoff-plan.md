---
title: Zig CLI Tool Kickoff Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - preparing_the_first_external_cli_repo_move
  - deciding_which_sdk_surfaces_the_cli_should_use_first
depends_on:
  - docs/plans/zig-nostr-ecosystem-phased-plan.md
  - docs/plans/sdk-cli-client-boundary-checkpoint-plan.md
  - docs/plans/sdk-runtime-client-store-architecture-plan.md
touches_teaching_surface: yes
touches_audit_state: no
touches_startup_docs: yes
---

# Zig CLI Tool Kickoff Plan

This packet marks the next major move after the first CLI-supporting SDK client floor.

It exists to define the first external Zig CLI repo/product kickoff against the now-proven SDK
surfaces, rather than continuing to grow `noztr-sdk` without clear product pressure.

## Scope Delta

Define:

- the first CLI product goals
- the first commands/jobs it should support
- which `noztr-sdk` surfaces it should compose first
- what remains in the SDK versus what belongs in the CLI repo

## Why This Is The Right Next Packet

The phased plan says the next major product target after the current SDK architecture baseline is
the Zig CLI tool.

The SDK now already proves:

- shared store/query/checkpoint seams
- shared relay-pool runtime inspection and replay planning
- one first CLI-facing client composition surface

So the next highest-value work is no longer another SDK client loop by default.

It is the first CLI product kickoff.

## Questions This Packet Must Answer

1. What are the first CLI commands/jobs?
2. Which SDK surfaces should they build on first?
3. What should be deferred from CLI v1?
4. What repo split and handoff posture should be used when the CLI repo starts?

## Expected Output

This packet should produce:

1. one CLI v1 scope definition
2. one first command/feature order
3. one explicit SDK-to-CLI boundary statement

## Kickoff Outcome

### CLI v1 Product Goal

The first Zig CLI should be:

- a developer/operator tool,
- scriptable and explicit,
- built on `noztr` plus `noztr-sdk`,
- useful before any full end-user client exists.

It should optimize first for:

- inspect/query/debug value,
- relay/runtime visibility,
- signer interaction,
- verification workflows,
- and scripting-friendly output.

It should not try to become a full end-user client, bot framework, or hidden runtime daemon in v1.

### CLI v1 Included Command Families

Include in CLI v1:

1. archive/query commands
   - local ingest
   - bounded query
   - named checkpoint inspection
2. relay/runtime commands
   - relay set inspection
   - shared runtime readiness view
   - checkpoint and replay-plan inspection
3. verification commands
   - `NIP-05`
   - `NIP-39`
   - `NIP-03` detached proof verification where the current SDK already supports it
4. signer/debug commands
   - narrow `NIP-46` developer tooling over the current remote-signer floor

### Deferred From CLI v1

Defer from CLI v1:

- broad generic publish UX
- mailbox command suites
- groups moderation/admin suites
- live subscription/follow UX
- hidden background runtime ownership
- durable backend commitments beyond local bootstrap needs

### First Command / Feature Order

Recommended order:

1. repo bootstrap plus dependency/import smoke
2. archive/query/checkpoint commands
3. relay/runtime/checkpoint/replay-inspection commands
4. verification commands
5. narrow signer/debug commands

This order matches the currently strongest SDK surfaces and gives the CLI immediate operator value
before wider workflow UX exists.

### SDK To CLI Boundary

`noztr-sdk` should own:

- reusable client/runtime/store composition
- typed plans and next-step helpers
- bounded workflow composition above `noztr`

The separate CLI repo should own:

- command vocabulary
- flag/argument parsing
- output formatting
- config/env loading
- file I/O and shell ergonomics
- operator workflows and scripting posture

### Recommendation

The next active packet should be a CLI v1 command-surface plan.

That packet should define:

- exact first commands,
- command grouping,
- first SDK surfaces each command composes,
- and what must stay deferred from CLI v1.
