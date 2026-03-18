# Noztr SDK NIP-29 Next-Slice Evaluation

Post-loop evaluation for what should follow the first accepted `NIP-29` group-session slice.

Date: 2026-03-15

## Current Floor

The accepted first `NIP-29` slice already proves:
- one pinned group reference plus one validated relay URL
- explicit connect/auth/disconnect handling
- typed intake of reducer-relevant state events only
- wrong-group rejection before reducer mutation
- explicit reset and replay of caller-supplied canonical state

The kernel side is also now in a better place than when the slice first landed:
- `noztr` reducer replay accepts moderation events carrying bounded `previous` tags
- `noztr` now has reducer and adversarial `NIP-29` recipes

## What A Broader NIP-29 Slice Would Actually Require

Broadening `NIP-29` meaningfully now is not just "add a few more event kinds". A credible next slice
would require at least one of:
- transcript intake for snapshot-plus-incremental relay feeds
- local ordering and replay policy
- local history or snapshot replacement policy for `previous`-aware moderation flows
- store-backed reduced state or sync cursors
- multi-relay or fork reconciliation

Those are not `NIP-29` parser concerns. They are new SDK substrate decisions.

## Boundary Assessment

Why this should not move into `noztr`:
- relay transcript handling, history retention, sync cursors, and fork policy are orchestration and
  storage concerns

Why this should not jump straight into `noztr-sdk` next:
- the current workflow set still lacks a top-level examples tree that teaches the accepted slices
- broader `NIP-29` would force new generic seams before the existing workflow layer is documented
  and exercised through example-grade usage
- examples are the lower-risk way to pressure-test the current workflow API before freezing
  store/history seams that later slices will have to live with

## Recommendation

Do not start broader `NIP-29` sync/store work as the immediate next lane.

The next accepted lane should be:
- the first structured `examples/` tree for the completed workflow set

Then, only after the examples lane is green, start a dedicated `NIP-29` sync/store packet that
answers these before implementation:
- what transcript shape enters the workflow
- whether ordering is caller-owned or SDK-owned
- what minimal history seam is required for `previous` validation
- whether the first store seam is snapshot-only, cursor-only, or both
- whether the first expansion stays single-relay or introduces multi-relay reconciliation

## Proposed Next NIP-29 Slice

When `NIP-29` resumes, the smallest credible next slice is:
- single-relay snapshot-plus-incremental sync over caller-supplied canonical event streams
- optional snapshot reset plus incremental apply
- no multi-relay merge yet
- no durable store yet
- explicit non-goal: automatic canonical ordering

That slice should still require a fresh planning packet before implementation.
