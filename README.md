# nzdk

Higher-level Zig Nostr SDK built on top of `noztr`.

This repo starts from seed artifacts copied from `noztr` so the SDK can bootstrap deliberately
instead of inventing process and scope from scratch.

## Initial inputs

- `docs/plans/noztr-sdk-ownership-matrix.md`
- `docs/plans/build-plan.md` template to replace with an `nzdk`-specific baseline
- `docs/research/` copied SDK-relevant studies
- `docs/nips/` copied NIP references
- `AGENTS.md`, `agent-brief`, and `handoff.md` as editable templates

## Initial direction

- use `noztr` explicitly as the Zig Nostr protocol kernel dependency
- start against the local `../noztr` checkout first
- use `noztr` for protocol-kernel logic
- keep orchestration, network fetches, stores, sync, and workflow composition in `nzdk`
- model SDK ergonomics primarily after applesauce where that improves client-flow clarity
- treat applesauce and rust-nostr-sdk as reference inputs, not as protocol authority
