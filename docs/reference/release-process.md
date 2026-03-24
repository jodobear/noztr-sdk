---
title: Release Process
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - evaluating_public_release_readiness
  - preparing_a_tag
  - understanding_versioning_and_toolchain_compatibility
canonical: true
---

# Release Process

This document defines the public release baseline for `noztr-sdk`.

## Versioning

`noztr-sdk` uses its own project version line.

It does not use the Zig toolchain version as the library version.

Current project line:
- development line: `0.1.0-dev.0`
- first intended public release candidate: `0.1.0-rc.1`

Toolchain compatibility is tracked separately from the project version.

Current baseline:
- Zig `0.15.2`

That toolchain floor should be stated in release notes and public docs for each release, but it is
not the package version.

## First Public Release Target

The first intended public release target is:
- `v0.1.0-rc.1`

That release should mean:
- the public docs route exists
- the public namespace and usage shape are documented
- examples exist for the major current surfaces
- the verification gates are green
- downstream consumers can evaluate the repo honestly as a release candidate

It does not mean:
- every NIP in the ecosystem is already implemented
- the SDK is feature-complete for all future scope
- product/runtime policy is hidden inside the SDK

## Release Criteria

Before cutting a public tag, all of these should be true:

1. Public docs route exists and is coherent.
   - `README.md`
   - `docs/INDEX.md`
   - `docs/getting-started.md`
   - `docs/reference/contract-map.md`
   - `examples/README.md`

2. The public API and usage surface are documented honestly.
   - grouped public namespace shape is documented
   - current coverage is described without implying unimplemented breadth
   - ownership relative to `noztr-core` is explicit

3. Examples or end-to-end usage paths exist for the major currently supported surfaces.

4. Verification gates are green.
   - `zig build`
   - `zig build test --summary all`
   - `git diff --check` for docs-only release prep

5. Release notes are ready.
   - first-release framing is broad and honest
   - current limitations and tradeoffs are stated
   - toolchain floor is stated explicitly

6. The repo is evaluable as an RC by downstream users.
   - package metadata uses the project version line
   - changelog or release-notes surface exists
   - migration notes exist for known pre-`1.0` breaks that matter to evaluation
   - the canonical migration route is published:
     - `docs/reference/migration-guide.md`

## Tagging Guidance

- prefer annotated tags such as `v0.1.0-rc.1`
- tag from a clean verified commit
- do not move public tags casually
- if a release candidate must be superseded, cut a new tag instead of rewriting the old one

Example:

```bash
git tag -a v0.1.0-rc.1 -m "noztr-sdk v0.1.0-rc.1"
```

## Release Notes Shape

Release notes should summarize the release as a repo state, not only the latest slice.

For the first public RC, cover:
- what `noztr-sdk` is
- what layer it owns relative to `noztr-core`
- what it currently covers
- key tradeoffs and limitations
- toolchain compatibility
- adoption guidance

## First Release Notes Template

Use this shape for `v0.1.0-rc.1`:

```text
noztr-sdk v0.1.0-rc.1

What it is
- Higher-level Zig Nostr SDK above noztr-core.
- Owns relay/session/store/workflow composition, not protocol-kernel parsing and validation.

What it currently covers
- Generic relay/session foundation
- Local-state foundation
- NIP-46 remote signer
- NIP-17 mailbox DM
- Legacy NIP-04 DM
- social content, reaction/list, comment/reply, and highlight client/workflow support
- NIP-57 zap workflow and receipt validation
- NIP-86 relay management
- NIP-03 OpenTimestamps verification
- NIP-05 identity resolution
- NIP-29 groups
- NIP-39 identity verification
- shared HTTP and signed-post transport seams where reusable beyond one consumer

Tradeoffs and limits
- Explicit caller-owned runtime posture
- No hidden websocket framework
- Not every NIP is implemented yet
- Pre-1.0 namespace and surface cleanup may still happen when justified

Compatibility
- Zig 0.15.2 baseline for this RC

Adoption guidance
- Start with README.md, docs/INDEX.md, docs/getting-started.md, docs/reference/contract-map.md,
  and examples/README.md.
- Prefer grouped client/workflow routes.
```

## Recommendation

`noztr-sdk` is close to `0.1.0-rc.1`, but a tag should wait until:
- the first actual RC notes are written from the template above
- maintainers do one final downstream-evaluation pass from the public docs route
- the release commit is intentionally chosen and tagged

## Current Stabilization State

The current repo state should be treated as the downstream-evaluation baseline.

That means:
- the broad cleanup/remediation campaign is finished
- the recent breadth wave is landed and audited
- the first Blossom-forced shared substrate seam is landed
- migration notes are now routed through one canonical guide

It does not mean a tag should be cut immediately.

The remaining work before `v0.1.0-rc.1` is still:
- final downstream-evaluation pass
- actual RC release notes
- one intentionally chosen clean release commit and annotated tag

Many NIPs still remain unimplemented. That does not block `0.1.0-rc.1` by itself if the release
notes and docs describe current coverage honestly.
