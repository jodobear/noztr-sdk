---
title: Packet Template
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - creating_new_packet
  - refining_existing_workflow
---

# Packet Template

Use this structure for new per-slice packets.

The packet should be delta-oriented and should not restate the full implementation gate.
Reference [implementation-quality-gate.md](./implementation-quality-gate.md) for the canonical rule
set.

## Suggested Frontmatter

```yaml
---
title: <Slice Title>
doc_type: packet
status: active
owner: noztr-sdk
nips: [<nip numbers>]
read_when:
  - <when to read this packet>
depends_on:
  - docs/plans/implementation-quality-gate.md
  - <relevant audit docs>
target_findings:
  - <stable finding IDs>
touches_teaching_surface: <yes-or-no>
touches_audit_state: <yes-or-no>
touches_startup_docs: <yes-or-no>
---
```

## Suggested Body

1. Scope delta
- what this slice changes
- what it does not change
- declare:
  - `touches_teaching_surface`
  - `touches_audit_state`
  - `touches_startup_docs`

2. Targeted findings
- stable IDs from the active audit docs
- whether this slice is product-surface broadening, Zig-native shaping, or both

3. Slice-specific proof gaps
- what still cannot be proven here
- what seam/kernel help would be needed to close the gap

4. Slice-specific seam constraints
- exact transport/store/session assumptions relevant to this slice only

5. Slice-specific tests
- only the tests this slice must add or adjust

6. Staged execution notes
- what Stage 1 code work covers
- what Stage 2 test work must prove
- what Stage 3 example or teaching work must change
- which workflow preconditions the example must make explicit and satisfy directly
- what Stage 4 review and audit reruns must re-evaluate
- what Stage 5 docs and handoff closeout must update

7. Closeout checks
- docs to update
- examples to update
- audits to rerun
- startup/discovery docs to trim back after the slice closes
- older reference packets that should now point at the new follow-on slice
- compatibility result classification if the slice reruns local upstream checks
- slice mistakes or friction to record, plus whether the lesson stays local or should tighten the
  canonical process
- planned commit scope and commit subject for the accepted slice

## Synchronization Hint

If the slice changes code but also changes how the repo should be read or taught, make that explicit
up front instead of relying on memory at closeout.

If the slice changes a public recipe, also write down the preconditions that recipe must make
explicit. This catches examples that accidentally depend on hidden relay, session, cache, or store
state.

Reference [implementation-quality-gate.md](./implementation-quality-gate.md) for the canonical
staged micro-loop and synchronization expectations. Packets should only record slice-specific stage
obligations and touched docs.

## Rule

If the packet starts restating generic gate language, move that content back into
[implementation-quality-gate.md](./implementation-quality-gate.md) and keep the packet focused on
its slice delta.
