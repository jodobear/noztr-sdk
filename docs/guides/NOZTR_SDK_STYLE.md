# Noztr SDK Style

Project-specific style guide for `noztr-sdk`.

## Intent

`noztr-sdk` is not the protocol kernel. It should compose `noztr`'s deterministic primitives into useful
SDK workflows without becoming sloppy, magical, or hard to reason about.

## Rules

- Prefer reusing `noztr` over re-implementing protocol rules.
- Keep orchestration explicit.
- Keep state machines, caches, stores, and client flows bounded and testable.
- Favor obvious workflow layers over clever generic abstractions.
- Use applesauce as an ergonomic reference, not as a source of truth.
- When SDK behavior depends on policy, make the policy explicit instead of burying it in helpers.
