# Handoff

Current project context for `nzdk` bootstrap.

## Current Status

- `nzdk` is a fresh SDK repo bootstrapped from `noztr` seed artifacts.
- The kernel/SDK ownership boundary starts from `docs/plans/noztr-sdk-ownership-matrix.md`.
- `docs/plans/build-plan.md` is a copied seed template and must be replaced by `nzdk`'s own
  accepted execution baseline.
- `noztr` is the protocol-kernel dependency target; `nzdk` should not duplicate kernel logic.
- bootstrap should use the local `../noztr` checkout first; remote setup is not a blocker
- Applesauce is the primary SDK/reference input for modeling higher-level client ergonomics,
  stores, and workflow composition.
- Rust-nostr-sdk is a secondary ecosystem/reference input.

## Immediate Next Work

1. Do SDK-specific research refresh using the copied studies and current upstream references.
2. Create the initial `nzdk` planning docs.
3. Replace the copied `build-plan.md` template with an `nzdk`-specific planning baseline.
4. Tighten `AGENTS.md`, `agent-brief`, and this `handoff.md` from template state into real repo
   guidance.
5. Decide initial repo/package layout and milestone order.
6. Begin implementation only after the planning docs are in place.

## Boundary Reminder

For every major SDK helper, answer:
- why is this not already a `noztr` concern?
- why is this not app code above `nzdk`?
- why is this the simplest useful SDK layer?

## Open Starting Questions

- exact package layout and public API shape
- what the first supported SDK workflows should be
- what `noztr` follow-ups, if any, block the first SDK milestone
- how closely to model applesauce versus rust-nostr-sdk on stores, clients, and orchestration
