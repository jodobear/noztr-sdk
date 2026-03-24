# Changelog

All notable project-level changes to `noztr-sdk` should be tracked here.

This changelog tracks the SDK's own release line. It does not use the Zig toolchain version as the
library version.

`noztr-sdk` is currently on the pre-`1.0` line:
- current development line: `0.1.0-dev.0`
- first intended public release candidate: `0.1.0-rc.1`

## Unreleased

### Added

- established the first explicit `noztr-sdk` release baseline:
  - project-owned pre-`1.0` version line
  - public release-process guidance
  - first-release note framing
  - release-prep integration into normal maintainer workflow
- added one canonical pre-`1.0` migration route:
  - `docs/reference/migration-guide.md`
  - grouped current breaking migration notes into one downstream entrypoint

### Changed

- stabilized the current downstream-evaluation floor instead of continuing broad cleanup churn:
  - grouped client/workflow/store/runtime/transport route shape is now the intended baseline
  - social, DM, proof, identity, groups, relay-management, and zap breadth are documented as the
    current public floor
  - relay-management now shares the generic `transport.nip98_post` seam instead of owning a
    private signed-POST stack
- public docs now route migration readers through one canonical guide instead of a long inline
  inventory
