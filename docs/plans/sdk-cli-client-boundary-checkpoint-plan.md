---
title: SDK CLI Client Boundary Checkpoint Plan
doc_type: packet
status: reference
owner: noztr-sdk
read_when:
  - deciding_the_next_cli_supporting_sdk_child
  - reassessing_sdk_vs_cli_repo_boundary
depends_on:
  - docs/plans/sdk-cli-client-composition-plan.md
  - docs/plans/five-slice-cli-archive-client-loop-plan.md
  - docs/plans/implementation-quality-gate.md
touches_teaching_surface: yes
touches_audit_state: yes
touches_startup_docs: yes
target_findings:
  - Z-WORKFLOWS-001
  - Z-ABSTRACTION-001
---

# SDK CLI Client Boundary Checkpoint Plan

Next active packet under the
[sdk-cli-client-composition-plan.md](./sdk-cli-client-composition-plan.md) child.

This packet exists because `noztr-sdk` now already proves one first CLI-facing client surface:

- explicit event ingest/query/checkpoint helpers
- explicit per-relay checkpoint composition
- explicit relay runtime inspection
- explicit replay planning

So the next question is no longer "can the SDK compose one more helper?"

It is:

- what should the SDK keep owning for CLI support,
- what should move to the future CLI repo,
- and whether the next best move is another SDK client loop or the first external CLI repo work.

## Questions This Packet Must Answer

1. Is the current `CliArchiveClient` enough as the first reusable CLI-supporting SDK client floor?
2. What additional client composition, if any, still belongs in `noztr-sdk` before CLI repo work
   starts?
3. What should remain in the separate CLI repo as command UX, output policy, and operator
   workflows?

## In Scope

- reassess the SDK/CLI boundary after the first CLI client loop
- decide whether another SDK client loop is justified now
- recommend the next active packet or repo move

## Out Of Scope

- implementing CLI commands
- starting the external CLI repo here
- hidden runtime ownership
- unrelated workflow refinement loops

## Expected Output

This packet should produce:

1. one explicit keep/stop decision for CLI-facing SDK client growth
2. one recommended next active packet or next repo-level move
3. one rationale tied to the phased ecosystem order

## Checkpoint Outcome

Keep in `noztr-sdk` for now:

- one minimal CLI-facing client composition surface
- explicit local ingest/query/checkpoint helpers
- explicit per-relay checkpoint composition
- explicit relay runtime inspection
- explicit replay planning

Stop before adding more CLI-specific SDK surface:

- command vocabulary
- output formatting policy
- flag/argument posture
- operator workflow orchestration
- hidden relay execution loops
- product-specific publish/query UX

## Decision

`CliArchiveClient` is enough as the first reusable CLI-supporting SDK floor.

The next move should not be another SDK client loop by default.

It should be the first CLI product kickoff packet, because the remaining work is now mostly about:

- command surface selection
- operator/developer UX
- which existing SDK surfaces the separate CLI repo should compose first

That work belongs at the product boundary, not as more speculative SDK client growth.
