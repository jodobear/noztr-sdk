# Deferred Cleanup Log

Non-blocking cleanup items observed while the autonomous NIP loop is running.

Date: 2026-03-15

Use this log when work uncovers:
- stale artifacts
- unrelated dirty files
- local scratch directories
- cleanup tasks that should not stop the active NIP loop

Rule:
- do not stop the active NIP for these items
- record them here with enough context to revisit later
- ask the user about cleanup after the current multi-NIP loop finishes

## Open Items

- 2026-03-15
  - repo: `/workspace/projects/noztr`
  - path: `.beads/issues.jsonl`
  - note: unrelated dirty state observed during compatibility recheck; not touched by the SDK loop

- 2026-03-15
  - repo: `/workspace/projects/noztr`
  - path: `tools/interop/rust-nostr-parity-all/target/`
  - note: generated build artifact tree observed during compatibility recheck; not touched by the SDK loop
