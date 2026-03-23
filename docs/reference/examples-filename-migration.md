---
title: Examples Filename Migration
doc_type: reference
status: active
owner: noztr-sdk
read_when:
  - migrating_pre_1_0_example_file_paths
---

# Examples Filename Migration

Pre-`1.0` examples cleanup:

## What Changed

Public example files under [`examples/`](../../examples/README.md) dropped the redundant
`_recipe` suffix.

Examples:

- `examples/remote_signer_recipe.zig` -> `examples/remote_signer.zig`
- `examples/mixed_dm_client_recipe.zig` -> `examples/mixed_dm_client.zig`
- `examples/social_profile_content_client_recipe.zig` -> `examples/social_profile_content_client.zig`

This was a filename cleanup only.

## What Did Not Change

- the `examples/` directory is still the public teaching route
- the examples are still compile-verified workflow recipes
- the grouped public SDK routes taught by those files did not change

## Reason

The `examples/` directory already carries the teaching context.
Keeping `_recipe` in every filename added noise without adding real meaning for humans or LLMs.
