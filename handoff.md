# Handoff

Current project context for `nzdk` bootstrap.

## Current Status

- `nzdk` is a fresh SDK repo bootstrapped from `noztr` seed artifacts.
- The kernel/SDK ownership boundary starts from `docs/plans/noztr-sdk-ownership-matrix.md`.
- `noztr` is the protocol-kernel dependency target; `nzdk` should not duplicate kernel logic.
- Applesauce is an important SDK/reference input for modeling higher-level client ergonomics,
  stores, and workflow composition.

## Immediate Next Work

1. Do SDK-specific research refresh using the copied studies and current upstream references.
2. Create the initial `nzdk` planning docs.
3. Tighten `AGENTS.md`, `agent-brief`, and this `handoff.md` from template state into real repo
   guidance.
4. Decide initial repo/package layout and milestone order.
5. Begin implementation only after the planning docs are in place.

## Open Starting Questions

- exact package layout and public API shape
- what the first supported SDK workflows should be
- what `noztr` follow-ups, if any, block the first SDK milestone
- how closely to model applesauce versus rust-nostr-sdk on stores, clients, and orchestration
