---
title: Noztr SDK Docs Index
doc_type: index
status: active
owner: noztr-sdk
read_when:
  - locating_docs
  - deciding_what_to_read_next
---

# Noztr SDK Docs Index

Canonical discovery map for docs in this repo.

## Frontmatter Conventions

Active and reference docs use frontmatter with these fields where relevant:
- `title`
- `doc_type`: `state`, `policy`, `packet`, `audit`, `reference`, `log`, `index`, or `archive`
- `status`: `active`, `reference`, or `archived`
- `owner`
- `read_when`
- optional slice metadata such as `nips`, `posture`, `depends_on`, or `target_findings`

Use `doc_type` plus `status` first:
- `active` docs are current control docs
- `reference` docs are stable background or accepted slice records
- `archived` docs are historical context only

## Read First

- [AGENTS.md](/workspace/projects/nzdk/AGENTS.md)
- [handoff.md](/workspace/projects/nzdk/handoff.md)
- [build-plan.md](/workspace/projects/nzdk/docs/plans/build-plan.md)
- [implementation-quality-gate.md](/workspace/projects/nzdk/docs/plans/implementation-quality-gate.md)

## Active Audits

- [implemented-nips-applesauce-audit-2026-03-15.md](/workspace/projects/nzdk/docs/plans/implemented-nips-applesauce-audit-2026-03-15.md)
  Product-surface and applesauce-role posture.
- [implemented-nips-zig-native-audit-2026-03-15.md](/workspace/projects/nzdk/docs/plans/implemented-nips-zig-native-audit-2026-03-15.md)
  Zig-native API-shape and ergonomic posture.
- [docs-surface-audit.md](/workspace/projects/nzdk/docs/plans/docs-surface-audit.md)
  Docs/discoverability and control-surface drift posture.

## Supporting Audits

- [llm-agent-audit-2026-03-15.md](/workspace/projects/nzdk/docs/plans/llm-agent-audit-2026-03-15.md)
  Agent discoverability and teaching posture. Useful reference, but not currently part of the
  required refinement closeout gate.

## Active Packet Or Teaching Docs

- [sdk-runtime-client-store-architecture-plan.md](/workspace/projects/nzdk/docs/plans/sdk-runtime-client-store-architecture-plan.md)
- [examples-tree-plan.md](/workspace/projects/nzdk/docs/plans/examples-tree-plan.md)
- [examples/README.md](/workspace/projects/nzdk/examples/README.md)

## Logs

- [noztr-feedback-log.md](/workspace/projects/nzdk/docs/plans/noztr-feedback-log.md)
- [deferred-cleanup-log.md](/workspace/projects/nzdk/docs/plans/deferred-cleanup-log.md)

## Reference Docs

- [PROCESS_CONTROL.md](/workspace/projects/nzdk/docs/guides/PROCESS_CONTROL.md)
  Repo-specific process-control rules for reconciling process changes without append-only drift.
- [PROCESS_REFINEMENT_PLAYBOOK.md](/workspace/projects/nzdk/docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md)
  Generalized lessons for tightening another repo's process without copying this one mechanically.
- [audit-lanes.md](/workspace/projects/nzdk/docs/plans/audit-lanes.md)
  Canonical lane map for the repo's always-on audits, required review lanes, and conditional full
  audit programs.
- [noztr-sdk-ownership-matrix.md](/workspace/projects/nzdk/docs/plans/noztr-sdk-ownership-matrix.md)
- [sdk-kickoff.md](/workspace/projects/nzdk/docs/plans/sdk-kickoff.md)
- [package-layout-plan.md](/workspace/projects/nzdk/docs/plans/package-layout-plan.md)
- [noztr-integration-plan.md](/workspace/projects/nzdk/docs/plans/noztr-integration-plan.md)
- [testing-parity-strategy.md](/workspace/projects/nzdk/docs/plans/testing-parity-strategy.md)
- [api-ownership-map.md](/workspace/projects/nzdk/docs/plans/api-ownership-map.md)
- [research-refresh-2026-03-14.md](/workspace/projects/nzdk/docs/plans/research-refresh-2026-03-14.md)
- [zig-nostr-ecosystem-readiness-matrix.md](/workspace/projects/nzdk/docs/plans/zig-nostr-ecosystem-readiness-matrix.md)
- [zig-nostr-ecosystem-phased-plan.md](/workspace/projects/nzdk/docs/plans/zig-nostr-ecosystem-phased-plan.md)
- [noztr-remediation-sync-plan.md](/workspace/projects/nzdk/docs/plans/noztr-remediation-sync-plan.md)
- [http-workflows-public-seam-plan.md](/workspace/projects/nzdk/docs/plans/http-workflows-public-seam-plan.md)
- [nip17-outbound-mailbox-plan.md](/workspace/projects/nzdk/docs/plans/nip17-outbound-mailbox-plan.md)
- [nip17-relay-fanout-plan.md](/workspace/projects/nzdk/docs/plans/nip17-relay-fanout-plan.md)
- [nip17-sender-copy-plan.md](/workspace/projects/nzdk/docs/plans/nip17-sender-copy-plan.md)
- [nip17-file-intake-plan.md](/workspace/projects/nzdk/docs/plans/nip17-file-intake-plan.md)
- [nip17-file-send-plan.md](/workspace/projects/nzdk/docs/plans/nip17-file-send-plan.md)
- [nip17-runtime-plan.md](/workspace/projects/nzdk/docs/plans/nip17-runtime-plan.md)
- [nip17-six-slice-workflow-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip17-six-slice-workflow-loop-plan.md)
- [nip17-runtime-next-step-plan.md](/workspace/projects/nzdk/docs/plans/nip17-runtime-next-step-plan.md)
- [five-slice-selector-loop-plan.md](/workspace/projects/nzdk/docs/plans/five-slice-selector-loop-plan.md)
- [five-slice-step-view-loop-plan.md](/workspace/projects/nzdk/docs/plans/five-slice-step-view-loop-plan.md)
- [ten-slice-runtime-refresh-loop-plan.md](/workspace/projects/nzdk/docs/plans/ten-slice-runtime-refresh-loop-plan.md)
- [stored-workflow-hardening-plan.md](/workspace/projects/nzdk/docs/plans/stored-workflow-hardening-plan.md)
- [nip03-remote-proof-plan.md](/workspace/projects/nzdk/docs/plans/nip03-remote-proof-plan.md)
- [nip03-proof-store-plan.md](/workspace/projects/nzdk/docs/plans/nip03-proof-store-plan.md)
- [nip03-remembered-verification-plan.md](/workspace/projects/nzdk/docs/plans/nip03-remembered-verification-plan.md)
- [nip03-discovery-freshness-plan.md](/workspace/projects/nzdk/docs/plans/nip03-discovery-freshness-plan.md)
- [nip03-runtime-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip03-runtime-policy-plan.md)
- [nip03-refresh-plan.md](/workspace/projects/nzdk/docs/plans/nip03-refresh-plan.md)
- [nip03-six-slice-target-policy-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip03-six-slice-target-policy-loop-plan.md)
- [nip03-long-lived-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip03-long-lived-policy-plan.md)
- [nip05-ergonomic-surface-plan.md](/workspace/projects/nzdk/docs/plans/nip05-ergonomic-surface-plan.md)
- [nip39-ergonomic-surface-plan.md](/workspace/projects/nzdk/docs/plans/nip39-ergonomic-surface-plan.md)
- [nip39-profile-workflow-plan.md](/workspace/projects/nzdk/docs/plans/nip39-profile-workflow-plan.md)
- [nip39-provider-details-plan.md](/workspace/projects/nzdk/docs/plans/nip39-provider-details-plan.md)
- [nip39-cache-plan.md](/workspace/projects/nzdk/docs/plans/nip39-cache-plan.md)
- [nip39-store-discovery-plan.md](/workspace/projects/nzdk/docs/plans/nip39-store-discovery-plan.md)
- [nip39-remembered-discovery-plan.md](/workspace/projects/nzdk/docs/plans/nip39-remembered-discovery-plan.md)
- [nip39-freshness-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip39-freshness-policy-plan.md)
- [nip39-discovery-freshness-plan.md](/workspace/projects/nzdk/docs/plans/nip39-discovery-freshness-plan.md)
- [nip39-preferred-selection-plan.md](/workspace/projects/nzdk/docs/plans/nip39-preferred-selection-plan.md)
- [nip39-runtime-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip39-runtime-policy-plan.md)
- [nip39-refresh-plan.md](/workspace/projects/nzdk/docs/plans/nip39-refresh-plan.md)
- [nip39-long-lived-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip39-long-lived-policy-plan.md)
- [nip39-six-slice-refresh-batch-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-six-slice-refresh-batch-loop-plan.md)
- [nip39-six-slice-refresh-cadence-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-six-slice-refresh-cadence-loop-plan.md)
- [nip39-five-slice-turn-buckets-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-five-slice-turn-buckets-loop-plan.md)
- [nip39-six-slice-turn-policy-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-six-slice-turn-policy-loop-plan.md)
- [nip39-six-slice-target-policy-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-six-slice-target-policy-loop-plan.md)
- [nip39-six-slice-target-discovery-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-six-slice-target-discovery-loop-plan.md)
- [nip39-ten-slice-policy-loop-plan.md](/workspace/projects/nzdk/docs/plans/nip39-ten-slice-policy-loop-plan.md)
- [nip46-ergonomic-surface-plan.md](/workspace/projects/nzdk/docs/plans/nip46-ergonomic-surface-plan.md)
- [nip46-method-coverage-plan.md](/workspace/projects/nzdk/docs/plans/nip46-method-coverage-plan.md)
- [nip46-example-cleanup-plan.md](/workspace/projects/nzdk/docs/plans/nip46-example-cleanup-plan.md)
- [nip29-ergonomic-surface-plan.md](/workspace/projects/nzdk/docs/plans/nip29-ergonomic-surface-plan.md)
- [nip29-client-surface-plan.md](/workspace/projects/nzdk/docs/plans/nip29-client-surface-plan.md)
- [nip29-runtime-client-plan.md](/workspace/projects/nzdk/docs/plans/nip29-runtime-client-plan.md)
- [nip29-state-authoring-plan.md](/workspace/projects/nzdk/docs/plans/nip29-state-authoring-plan.md)
- [nip29-sync-store-plan.md](/workspace/projects/nzdk/docs/plans/nip29-sync-store-plan.md)
- [nip29-checkpoint-plan.md](/workspace/projects/nzdk/docs/plans/nip29-checkpoint-plan.md)
- [nip29-multirelay-runtime-plan.md](/workspace/projects/nzdk/docs/plans/nip29-multirelay-runtime-plan.md)
- [nip29-fleet-checkpoint-plan.md](/workspace/projects/nzdk/docs/plans/nip29-fleet-checkpoint-plan.md)
- [nip29-reconciliation-plan.md](/workspace/projects/nzdk/docs/plans/nip29-reconciliation-plan.md)
- [nip29-durable-store-plan.md](/workspace/projects/nzdk/docs/plans/nip29-durable-store-plan.md)
- [nip29-fleet-publish-plan.md](/workspace/projects/nzdk/docs/plans/nip29-fleet-publish-plan.md)
- [nip29-merge-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip29-merge-policy-plan.md)
- [nip29-runtime-policy-plan.md](/workspace/projects/nzdk/docs/plans/nip29-runtime-policy-plan.md)
- [nip29-targeted-reconcile-plan.md](/workspace/projects/nzdk/docs/plans/nip29-targeted-reconcile-plan.md)
- implemented slice records:
  - [nip46-remote-signer-plan.md](/workspace/projects/nzdk/docs/plans/nip46-remote-signer-plan.md)
  - [nip17-mailbox-plan.md](/workspace/projects/nzdk/docs/plans/nip17-mailbox-plan.md)
  - [nip39-identity-verifier-plan.md](/workspace/projects/nzdk/docs/plans/nip39-identity-verifier-plan.md)
  - [nip03-opentimestamps-verifier-plan.md](/workspace/projects/nzdk/docs/plans/nip03-opentimestamps-verifier-plan.md)
  - [nip05-resolver-plan.md](/workspace/projects/nzdk/docs/plans/nip05-resolver-plan.md)

## NIP Specs And Research

- `docs/nips/`
- `docs/research/`

## Archive

- [docs/archive/README.md](/workspace/projects/nzdk/docs/archive/README.md)

Historical loops, superseded packets, and bootstrap context live under `docs/archive/`.
