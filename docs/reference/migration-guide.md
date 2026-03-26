---
title: Pre-1.0 Migration Guide
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0
canonical: true
---

# Pre-1.0 Migration Guide

This is the canonical pre-`1.0` migration route for downstreams updating from older
`noztr-sdk` naming.

Use this first, then jump by route family.

## Route-Shape Canonicalization

- [Grouped public namespace migration](./grouped-public-namespace-migration.md)
  - canonical grouped `client.*` and `workflows.*` public routes
- [Workflow submodule naming migration](./workflow-submodule-naming-migration.md)
  - grouped workflow submodule names now match public route context
- [Mixed DM outbound naming migration](./mixed-dm-outbound-naming-migration.md)
  - canonical `client.dm.mixed.*` outbound names
- [Mixed DM route-local naming migration](./mixed-dm-route-local-naming-migration.md)
  - observed, memory, reply, and adjacent DM route-local cleanup

## DM Family Cleanup

- [DM orchestration naming migration](./dm-orchestration-naming-migration.md)
  - grouped DM/mailbox/legacy orchestration families
- [DM sync runtime naming migration](./dm-sync-runtime-naming-migration.md)
  - grouped DM sync-runtime families
- [Social and DM stored-read migration](./social-dm-stored-read-migration.md)
  - read-side helpers renamed to task-first names

## Domain-Route Cleanups

- [Remote signer naming migration](./remote-signer-naming-migration.md)
  - `workflows.signer.remote.*` role-based cleanup
- [Signer capability naming migration](./signer-capability-naming-migration.md)
  - route-local signer-capability type names in `client.signer.capability.*`
- [Signer session naming migration](./signer-session-naming-migration.md)
  - route-local signer-session `client.signer.session.*` names
- [Mailbox signer job naming migration](./mailbox-signer-job-naming-migration.md)
  - grouped `client.dm.mailbox.signer_job.*` route-local naming
- [Signer job naming migration](./signer-job-naming-migration.md)
  - canonical route-local `client.signer.*` job naming
- [Proof, identity, and NIP-05 planning migration](./proof-identity-planning-migration.md)
  - grouped proof/identity/nip05 planning routes, including the `nip03` and `nip05` flat workflow-planning removals
- [Noztr core rc4 migration](./noztr-core-rc4-migration.md)
  - pre-`1.0` cumulative `noztr-core` type rename fallout
- [Local state client migration](./local-state-client-migration.md)
  - canonical local-state entrypoint and `RelayWorkspaceClientConfig` shape
- [Examples filename migration](./examples-filename-migration.md)
  - public example filename suffix cleanup
