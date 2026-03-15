# Noztr SDK Seeding Prompt

Use this prompt to start serious work in `noztr-sdk`.

## Prompt

You are bootstrapping `noztr-sdk`, a higher-level Zig Nostr SDK built on top of `noztr`.

Your job is to proceed deliberately.

1. Read `AGENTS.md`, `handoff.md`, `docs/plans/build-plan.md`, and
   `docs/plans/noztr-sdk-ownership-matrix.md` first.
2. Do your own research refresh before implementation:
   - review the copied SDK-relevant studies in `docs/research/`
   - review the relevant NIP specs in `docs/nips/`
   - inspect upstream libraries such as applesauce and rust-nostr-sdk when useful
3. Applesauce is the primary SDK modeling reference for clarity, store/client layering, and
   workflow design. Follow its spirit where that improves `noztr-sdk`, but do not treat it as protocol
   truth or as permission to blur the `noztr` / `noztr-sdk` boundary.
4. `noztr-sdk` explicitly uses `noztr` as its Zig Nostr protocol kernel. Start with the local `../noztr`
   checkout as the dependency target; do not wait for remote setup.
5. Do not begin implementation until you have created the initial planning docs for `noztr-sdk`.
6. Tighten the copied template files so this repo stops relying on `noztr` wording:
   - `AGENTS.md`
   - `agent-brief`
   - `handoff.md`
   - `docs/plans/build-plan.md`
7. Keep the `noztr` / `noztr-sdk` boundary honest:
   - protocol parsing/validation/building belongs in `noztr`
   - orchestration, fetches, sync, stores, session handling, and workflow composition belong in `noztr-sdk`
   - for each major SDK helper, answer why it is not already `noztr` and why it is not app code
     above `noztr-sdk`
8. Use a tight process:
   - research
   - plan
   - implement
   - review
   - document decisions
   - keep handoff current

## First Planning Outputs To Create

- SDK kickoff / scope doc
- replacement `build-plan.md`
- package / module layout plan
- `noztr` integration and dependency plan
- initial milestone order
- testing and parity strategy
- dependency posture and build-tooling decision
- API ownership map aligned with `noztr`
