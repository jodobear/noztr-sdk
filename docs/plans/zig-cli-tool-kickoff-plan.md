---
title: Zig CLI Tool Kickoff Plan
doc_type: packet
status: active
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
