# AGENTS.md — noztr-sdk

Public contributor and LLM guide for this repo.

`noztr-sdk` is the higher-level Zig SDK layer in the `noztr` ecosystem. `noztr-core` is the
complementary protocol-kernel layer underneath it.

## Start Here

Run `./agent-brief` first for the public routing snapshot.

Read these first:

- `README.md`
- `docs/INDEX.md`
- `examples/README.md`
- `CONTRIBUTING.md`

Then choose the right public guide:

- getting started and public contract routing:
  - `docs/getting-started.md`
  - `docs/reference/contract-map.md`
- public workflow recipes:
  - `examples/README.md`

## Scope

`noztr-sdk` is trying to be:

- a Zig-native SDK above `noztr-core`
- explicit about ownership, boundedness, and workflow control
- suitable for real clients, signers, relays, bots, services, and CLI tooling

`noztr-sdk` is not trying to be:

- a replacement for the `noztr-core` protocol kernel
- an app-specific product layer
- a hidden-runtime framework with implicit background behavior

If a proposed change weakens the `noztr-core` versus `noztr-sdk` boundary, challenge the scope
first.

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

## Public Docs Versus Internal Docs

This repo intentionally keeps two documentation layers:

- public tracked docs:
  - `README.md`
  - `docs/`
  - `examples/README.md`
  - `CONTRIBUTING.md`
- internal local-only docs:
  - `.private-docs/`

Do not route public readers into `.private-docs/`.

## Maintainers And Local Automation

If you are working in a local maintainer clone and `.private-docs/AGENTS.md` exists, continue
there for the internal maintainer workflow and local state.

That local maintainer route supersedes the public `./agent-brief` path for internal work.

If local `.beads/` state exists in that maintainer clone, use `br` for local issue tracking and
keep `.beads/` out of public commits.

If local tracker state does not exist yet, initialize it locally with `br init` and keep that
state untracked in public git history.
