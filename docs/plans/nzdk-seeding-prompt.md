# NZDK Seeding Prompt

Use this prompt to start serious work in `nzdk`.

## Prompt

You are bootstrapping `nzdk`, a higher-level Zig Nostr SDK built on top of `noztr`.

Your job is to proceed deliberately.

1. Read `AGENTS.md`, `handoff.md`, and `docs/plans/noztr-sdk-ownership-matrix.md` first.
2. Do your own research refresh before implementation:
   - review the copied SDK-relevant studies in `docs/research/`
   - review the relevant NIP specs in `docs/nips/`
   - inspect upstream libraries such as applesauce and rust-nostr-sdk when useful
3. Do not begin implementation until you have created the initial planning docs for `nzdk`.
4. Tighten the copied template files so this repo stops relying on `noztr` wording:
   - `AGENTS.md`
   - `agent-brief`
   - `handoff.md`
5. Keep the `noztr` / `nzdk` boundary honest:
   - protocol parsing/validation/building belongs in `noztr`
   - orchestration, fetches, sync, stores, session handling, and workflow composition belong in `nzdk`
6. Use a tight process:
   - research
   - plan
   - implement
   - review
   - document decisions
   - keep handoff current

## First Planning Outputs To Create

- SDK kickoff / scope doc
- package / module layout plan
- initial milestone order
- testing and parity strategy
- dependency posture and build-tooling decision
- API ownership map aligned with `noztr`
