# Contributing To noztr-sdk

Thanks for contributing to `noztr-sdk`.

This repo is the higher-level Zig SDK layer in the `noztr` ecosystem. The best contributions keep
the `noztr` versus `noztr-sdk` boundary clear while improving workflow usability, docs, examples,
and implementation quality.

## Before You Start

Run `./agent-brief` first if you want the public startup route in one place.

Read these first:

- [README.md](README.md)
- [AGENTS.md](AGENTS.md)
- [docs/INDEX.md](docs/INDEX.md)
- [docs/getting-started.md](docs/getting-started.md)
- [docs/reference/contract-map.md](docs/reference/contract-map.md)
- [examples/README.md](examples/README.md)

If you are working in a local maintainer clone and `.private-docs/AGENTS.md` exists, continue
there for the maintainer-only workflow. Internal working material lives in local-only
`.private-docs/`, while `README.md`, `docs/`, and `examples/` are the public surface.

## Scope

`noztr-sdk` is trying to be:

- a Zig-native SDK above `noztr`
- explicit about ownership, boundedness, and workflow control
- suitable for real clients, signers, relays, bots, services, and CLI tooling

`noztr-sdk` is not trying to be:

- a replacement for the `noztr` protocol kernel
- an app-specific product layer
- a hidden-runtime framework with implicit background behavior

If a proposed change weakens the `noztr` versus `noztr-sdk` boundary, challenge the scope first.

## Public Docs Versus Internal Docs

This repo intentionally keeps two documentation layers:

- public tracked docs:
  - `README.md`
  - `docs/`
  - `examples/README.md`
  - `CONTRIBUTING.md`
- internal local-only docs:
  - `.private-docs/`

Public docs should stay suitable for users, downstream consumers, and future website publication.

Do not route public readers into `.private-docs/`.
Do not copy handoff language, private issue ids, or maintainer-only process notes into the public
docs surface.

## Build And Test

Run these after code changes:

```bash
zig build
zig build test --summary all
```

For docs-only changes, at minimum run:

```bash
git diff --check
```

## Local Issue Tracking

This repo encourages local `br` usage during development.

Typical local flow:

```bash
br ready --json
br update <id> --claim --json
# do the work
br close <id> --reason "Completed" --json
br sync --flush-only
```

Local setup note:

```bash
br init
```

`.beads/` and `.private-docs/` are local-only maintainer state. Use them locally, but do not add
them to public commits.

If your clone already has local `.beads/` state, reuse it. If it does not, initialize it locally
and keep it out of public git history.

Do not create parallel markdown TODO systems in tracked public docs.

## Commit Subjects

Prefer scoped conventional subjects.

- maintainer commits should use: `<type>:<issue-id>: <summary>`
- allowed maintainer types: `feat`, `fix`, `doc`, `ref`, `chore`
- public contributors without a maintainer-local issue id may use: `<type>: <summary>`

Examples:

```text
doc:<issue-id>: tighten public docs routing for contributors
fix:<issue-id>: correct a workflow example link
ref:<issue-id>: simplify a helper without changing the public contract
```

## Docs Contributions

If you touch public docs, prefer improving:

- `README.md`
- `AGENTS.md`
- `docs/INDEX.md`
- `docs/getting-started.md`
- `docs/reference/contract-map.md`
- `examples/README.md`
- `CONTRIBUTING.md`

Keep docs and examples linked both ways whenever that materially helps users or LLMs navigate.

## Code Contributions

For code work:

- keep functions small and explicit
- keep behavior bounded
- avoid hidden side effects and hidden runtime behavior
- preserve the `noztr` kernel boundary
- update examples or public docs when that materially improves discoverability

If a change adds transport orchestration, session policy, caches, or app-facing workflow behavior,
it may belong in `noztr-sdk`. If it adds deterministic protocol parsing or validation, it probably
belongs in `noztr` instead.
