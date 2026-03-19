---
title: Process Refinement Playbook
doc_type: reference
status: reference
owner: noztr-sdk
read_when:
  - refining_agent_process
  - designing_repo_specific_audits
  - reducing_doc_bloat_without_losing_rigor
---

# Process Refinement Playbook

Generalized lessons from tightening the `noztr-sdk` process.

This is intentionally not a prescription to copy the exact `noztr-sdk` setup. Different repos
should define different audit postures, different packets, and different control docs.

The goal is to keep rigor high while reducing repetition, active-memory load, and process drift.

## Core Principle

Do not try to make every doc complete.

Instead:
- keep one canonical doc for each rule set
- make most other docs delta-oriented
- separate active control docs from reference docs and archive
- use audits to encode repo-specific quality pressures

Do not refine the process with vague “be more careful” language.

Instead:
- identify the exact bug class that escaped
- add one small rule, prompt, or checklist item that targets that class directly
- keep the new local rule near the canonical process owner
- reclose or re-audit recent work if the gate changed materially

## Additional Principle

Do not treat a process change as additive by default.

When the process changes materially:
- identify the canonical docs it changes
- review them together as one control surface
- remove or rewrite superseded wording
- add only the minimum new wording still required
- verify that startup docs, state docs, templates, and audits now agree

Otherwise the repo accumulates two quiet forms of drift:
- contradictory control guidance
- append-only history inside active docs

## What We Learned

### 1. A tight process can still miss things if its reviews are too generic

We found that “correctness review” by itself was not enough.

What worked better:
- define audit postures that reflect real repo risks
- keep those postures explicit
- re-audit existing slices when the gate gets smarter

Example postures from this repo:
- product-surface posture
- Zig-native API-shape posture
- agent-discoverability posture

Other repos should define their own.
Possible posture examples:
- security posture
- performance posture
- operations posture
- interoperability posture
- language-native ergonomics posture
- teaching/onboarding posture

The key is:
- one audit posture = one clear question
- not one giant “quality” document that tries to mean everything

### 1a. Narrow prompts beat broad cautionary prose

The most transferable lesson from process refinement is not “be stricter.”
It is:
- find the escaped bug class
- write the smallest prompt that would likely have caught it
- avoid turning one failure into a page of ceremonial wording

Good examples:
- add one explicit review question about disconnect cleanup
- add one packet field that makes synchronization touchpoints visible
- add one docs-surface audit finding when active docs contradict each other
- if a new upstream helper lands, add one closeout prompt to remove the local workaround and close
  the stale upstream-feedback item in the same slice
- if examples fail on hidden setup assumptions, tighten the existing example-stage wording so
  recipes must state and satisfy their own preconditions
- if new follow-on slices become hard to discover, tighten closeout wording so older reference
  packets point at the new slice instead of leaving that burden on handoff alone
- if accepted slices keep piling up in one dirty tree, tighten closeout so one accepted slice
  becomes one git commit instead of relying on docs or chat history as the checkpoint

Bad examples:
- adding general prose about quality everywhere
- duplicating the same rule in startup docs, plans, packets, and playbooks

### 2. Smaller packets are good only if rigor lives somewhere else

Making per-slice docs shorter is good.
Making them vague is bad.

The safe pattern is:
- one canonical gate doc owns the general rules
- per-slice packets record only slice-specific deltas

That means a packet should mostly contain:
- scope delta
- targeted findings
- slice-specific proof gaps
- slice-specific seam constraints
- slice-specific tests
- closeout conditions

If the packet starts restating the full process, the process is not centralized enough.

### 3. Audits need stable finding IDs if you want refinement work to stay precise

Prose-only audits are useful for reading, but weak for execution.

Once findings have stable IDs, refinement work gets sharper:
- packets can target exact findings
- handoff can point to live gaps concisely
- the repo stops pretending a paragraph is “implicitly resolved”

Good audit finding IDs should be:
- stable
- short
- meaningful enough to scan quickly

Example pattern:
- `<posture>-<area>-<number>`

The exact naming scheme does not matter much.
What matters is that the repo treats findings as trackable units.

### 4. Multiple audit docs are good when they represent different postures

Do not merge audits just to reduce file count if the merged result blurs the question being asked.

Use multiple audit docs when each one answers a distinct question.

Bad split:
- two docs that both say “quality issues” in slightly different words

Good split:
- one audit asks whether the surface is product-ready
- another asks whether it uses the language/framework well
- another asks whether it is teachable to agents or new contributors

This keeps reviews sharper, not noisier.

### 5. Active-memory load matters as much as rigor

A repo can have good docs and still feel hard to use if every session starts by reading too much.

What helped:
- a short handoff
- a docs index/manifest
- clear active/reference/archive separation
- frontmatter showing role and status

The process got better when we treated “what must be read now?” as a real design problem.

### 6. Historical material should be archived aggressively

Completed loops, superseded packets, and bootstrap context are valuable.
They should not remain in the startup path.

Good rule:
- if a doc no longer controls current work, move it to archive
- keep it available for provenance, but stop surfacing it as active guidance

### 7. Handoff docs should carry state, not history

A handoff that becomes a running session log eventually stops helping.

A better handoff contains:
- current status
- read first
- active gaps
- next work
- critical process rules

If the doc starts accumulating a long historical narrative, move that material elsewhere.

### 8. Discovery docs are worth the effort

An index or manifest sounds boring, but it reduces confusion fast.

A useful docs index should answer:
- what is active
- what is reference
- what is archived
- which audits exist
- which packet is current

This is especially helpful for agents and future maintainers.

### 9. Frontmatter is useful if it reflects real decisions

Frontmatter helps only if it captures operational metadata.

Useful fields:
- `title`
- `doc_type`
- `status`
- `owner`
- `read_when`
- optional fields like:
  - `nips`
  - `posture`
  - `depends_on`
  - `target_findings`
  - `supersedes`

Do not add frontmatter only for decoration.
Use it to make routing, filtering, and reading order clearer.

### 10. When the gate changes, old work may need to be reclosed

One of the most important lessons:
- if the process gets smarter, previously accepted work may no longer be fully accepted

That is not process failure.
That is process maturity.

So the right rule is:
- when the gate tightens materially, re-audit and backfill already-landed slices before continuing

### 10a. Process changes should reconcile, not accumulate

When the process changes materially:
- identify the canonical docs it affects
- review them together as one control surface
- remove or rewrite superseded wording
- add only the minimum new wording still needed

Otherwise the repo tends to accumulate:
- contradictory control guidance
- append-only history inside active docs
- startup routing that silently points at stale process state

### 11. Closeout consistency matters as much as implementation quality

A slice can be technically correct and still leave process drift behind if closeout is sloppy.

The common failure mode is:
- code and tests are updated
- but audits, examples catalogs, or startup docs still describe the old state

That creates a quieter kind of bug:
- future work starts from stale guidance
- startup reading gets temporarily bloated and never shrinks back
- teams lose trust in whether audit findings are actually live

The fix does not require more layers.
It requires making closeout consistency explicit:
- update the targeted audit findings immediately
- update the examples catalog if the public teaching surface changed
- update older reference packets when a new follow-on slice becomes part of that workflow's chain
- trim startup docs back to the lean post-closeout state once the slice is finished
- if a major loop or packet family just closed, restore one explicit next active packet before you
  call the repo back in steady state

This should be part of "done", not a nice-to-have cleanup pass.

One more useful refinement:
- capture mistakes and friction during closeout
- but do not automatically turn every local lesson into a permanent process rule
- promote a lesson into the canonical process only if it is recurring, broadly generalizable, or
  likely to prevent a real future escape
- otherwise keep it local to the slice packet, handoff note, or review record

## Recommended Process Shape

### A. Doc Roles

Use a small set of doc roles:
- `policy`
  Canonical rules and gates.
- `state`
  Current lane and next work.
- `packet`
  Slice-specific execution doc.
- `audit`
  Posture-specific findings.
- `reference`
  Stable background and accepted decisions.
- `log`
  Ongoing issue/feedback tracking.
- `archive`
  Historical material.

### B. Control Surface

At minimum, keep:
- one execution baseline
- one implementation gate
- one current handoff
- one docs index
- one active packet
- whichever audits are relevant for the current refinement lane

Everything else should be reference or archive.

### C. Refinement Rule

For work that improves an existing slice:
1. identify the targeted finding IDs
2. state which audit postures this work is addressing
3. run the canonical staged execution order from the repo's implementation gate
4. rerun the relevant audit frames
5. update the audit docs explicitly
6. restore the docs surface to steady state:
   - examples catalog updated if needed
   - startup docs no longer point at a just-finished packet unless it is still active
   - handoff reflects the new next slice instead of the slice that just closed

This prevents “we improved it” from meaning “we hope it’s better now.”

## Additional Lesson: Use Ordered Micro-Loops To Reduce Synchronization Errors

Trying to update code, tests, examples, audits, and docs all at once increases context switching and
makes closeout drift more likely.

What worked better in this repo:
- use one canonical staged execution order in the implementation gate
- keep other docs pointed at that order instead of restating it in full
- let packets record only slice-specific stage obligations

Why this helps:
- code answers whether the intended shape is implementable
- tests answer whether it is correct and adversarially covered
- examples answer whether it is actually teachable and usable
- audit reruns answer whether it closed the intended posture gaps
- docs closeout makes the repo truthful again

Important caveat:
- this should not become a waterfall that lets examples, audits, or docs slip into “later cleanup”
- the ordered micro-loop works only if later stages remain mandatory for done

### D. Synchronization Discipline

One of the easiest ways for a process to drift is for synchronization work to remain implicit.

The lightweight fix is to make each refinement packet declare whether it:
- changes the teaching surface
- changes audit state
- changes startup/discovery docs

That does not add a new workflow phase.
It just makes closeout touchpoints visible early enough that they are less likely to be missed.

Good pattern:
- declare the touchpoints in the packet
- keep the list short
- use it as a closeout checklist, not as new bureaucracy

Another useful small rule:
- when examples are part of the slice, state the workflow preconditions they rely on
- when compatibility reruns are part of the slice, classify the result as green,
  known-upstream-failure-only, or new-upstream-pressure
- when a repo is doing a high-impact hardening or cleanup program, finish the audit angles first,
  do one synthesis, and only then choose remediation

This helps especially in repos where code changes often imply doc-routing changes, example changes,
or audit-state changes.

Another useful review refinement:
- make misuse-path and wrong-error-class checks explicit on public surfaces
- ask whether convenience helpers hide a boundary that should remain visible
- ask whether there is one obvious safe path for the common job
- for boundary-heavy surfaces, prefer one direct example plus one hostile or misuse-oriented example

## How To Define Repo-Specific Audit Postures

Pick postures based on real failure modes, not on elegance.

Questions to ask:
1. What kind of mistake hurts this repo most?
2. What kind of mistake is easy to miss in normal code review?
3. What kind of pressure should shape API/workflow decisions beyond raw correctness?

Then define audits around those pressures.

Examples:
- a security-sensitive repo may want:
  - security posture
  - operational resilience posture
  - onboarding posture
- a library repo may want:
  - public API posture
  - language-native ergonomics posture
  - interoperability posture
- a product repo may want:
  - user-flow posture
  - observability posture
  - maintenance posture

Good audits are not generic quality checklists.
They are posture-specific lenses.

## Anti-Patterns

Avoid:
- one giant doc that tries to be gate, handoff, audit, history, and plan at once
- process updates that only append and never rewrite superseded guidance
- repeating the same doctrine in every packet
- keeping completed loops in startup reading
- audits with no stable finding IDs
- shrinking packets so much that important slice-specific assumptions disappear
- creating multiple audit docs that do not clearly differ in question or posture

## Minimal Adoption Path For Another Repo

If another repo wants the benefits without copying everything:

1. Define doc roles and add simple frontmatter.
2. Create one docs index.
3. Pick 2-3 audit postures that fit the repo.
4. Give audit findings stable IDs.
5. Make packets target those IDs instead of repeating full doctrine.
6. Archive completed loops and superseded packets.
7. Keep handoff short and current.

That is enough to improve clarity a lot without importing the full `noztr-sdk` process.
