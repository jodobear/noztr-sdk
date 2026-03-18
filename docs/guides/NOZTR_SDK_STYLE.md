# Noztr SDK Style

Project-specific style guide for `noztr-sdk`.

## Intent

`noztr-sdk` is not the protocol kernel. It should compose `noztr`'s deterministic primitives into useful
SDK workflows without becoming sloppy, magical, or hard to reason about.

The intended outcome is not just “some workflows on top of `noztr`”.
It is an opinionated, real-world Zig SDK that plays the same broad role for this ecosystem that
applesauce plays in TypeScript:
- clear workflow layers
- strong but explicit defaults
- structured examples and teachable posture
- practical ergonomics for shipping apps
- ecosystem compatibility without hiding the transport/policy boundary
- and a Zig-native design that should be more deterministic, bounded, explicit, and easy to reason
  about than a direct TypeScript-to-Zig port would be

## Rules

- Prefer reusing `noztr` over re-implementing protocol rules.
- Keep orchestration explicit.
- Keep state machines, caches, stores, and client flows bounded and testable.
- Favor obvious workflow layers over clever generic abstractions.
- Use applesauce as an ergonomic reference, not as a source of truth.
- Prefer Zig-native ownership, capacity, and state-machine clarity over translated TypeScript API
  habits when the two conflict.
- When SDK behavior depends on policy, make the policy explicit instead of burying it in helpers.
- Do not stop at “technically possible”: public SDK slices should trend toward real downstream
  usability, not only internal composability.
