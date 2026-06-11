---
name: uncle-dev-grill
description: >
  Builds a shared design concept by relentlessly interviewing the user — walking every
  branch of the design tree, resolving one dependency before opening the next — then
  synthesizing the answers into a PRD that feeds uncle-dev-spec. Use at the very start of
  a non-trivial feature or product when requirements live only in someone's head, when the
  user says "grill me", "interview me", "pin down the requirements", or "turn this into a
  PRD", or whenever you sense the user and you do not yet share the same picture of what is
  being built. Run before uncle-dev-spec, after uncle-dev-idea-refine has chosen a direction.
---
## Overview

At the start of a project, the human and the AI lack a shared design concept — the invisible idea of what is actually being built. Left unaddressed, the agent confidently builds something different from what the user imagined. This skill closes that gap by turning the agent into a helpful adversary: it interviews the user relentlessly, walking every branch of the design tree and resolving dependencies one at a time, until a shared understanding exists. It then synthesizes that understanding into a PRD that downstream skills (`uncle-dev-spec`) turn into HLD/LLD/EARS.

This is requirements elicitation, not ideation. Use `uncle-dev-idea-refine` first to choose what idea to pursue; use Grill to pin down exactly what it means before any spec or code.

## The Core Discipline

Depth-first, one branch at a time. Do not fire a flat list of 30 questions. Pick the highest-leverage unknown, ask about it, and follow its consequences down until that branch bottoms out — then return to the next unresolved branch. Each answer opens or closes further questions. This is why a real grill can run 40–100 questions: the tree is large, but you only ever hold one path in your head at a time.

Be a helpful adversary. Surface contradictions ("earlier you said X, but this implies not-X — which holds?"). Refuse to paper over vagueness. Do not move on from a branch while a dependency is unresolved. Honest, not supportive — but always in service of the user's goal.

Stop condition. The interview ends when every branch has bottomed out AND the user confirms the synthesized understanding back to you — not at a fixed question count.

## Process

### 1. Load context

- If `docs/ubiquitous-language.md` exists, read it and ask using its canonical terms. If the domain has real terminology and no glossary exists, note that you'll run `uncle-dev-ubiquitous-language` after the grill.
- If inside a codebase, scan relevant prior art (graphify `query`/`explain` when present, else Glob/Grep/Read) so questions are grounded in what exists.
- If `uncle-dev-idea-refine` produced a one-pager, start from its Recommended Direction.

### 2. Map the design tree (branches to walk)

Cover, in roughly this order, walking each to the bottom before the next:

1. Actors & jobs — who uses this, what job are they hiring it to do?
2. Core domain model — the central entities, their identity, lifecycle states, and relationships (cardinality).
3. Primary flows — the happy path, step by step, with the system's response at each step.
4. Boundaries & scope — what's explicitly in, what's explicitly out, what's deferred.
5. Edge cases & failure modes — what happens when inputs are bad, services fail, states conflict?
6. Non-functionals — scale, latency, security, compliance, offline, concurrency.
7. Integrations & contracts — upstream/downstream systems, existing seams to reuse.
8. Success criteria — how do we know it works? What's observable when it ships?

### 3. Interview (depth-first loop)

```
pick the highest-leverage unresolved unknown
  → ask (use AskUserQuestion for choices; open prose for discovery)
  → follow the answer's consequences down this branch
  → resolve contradictions against earlier answers as they surface
  → when the branch bottoms out, mark it resolved
repeat until no branch has an unresolved dependency
```

Track resolved vs open branches so you don't loop or drop a thread.

### 4. Confirm shared understanding

Play back a tight summary of the design concept: model, flows, scope, key decisions. Ask the user to confirm or correct. Only proceed once they accept it.

### 5. Synthesize the PRD

Write `docs/prd/<slug>.md` (or `.uncle-dev/prd/<slug>.md` if no `docs/` tree) using the template below. Use the project's ubiquitous language throughout. Do not include file paths or code snippets (they rot) — except a single inline state machine / schema / type shape when prose can't encode a decision precisely.

```markdown
# <Feature> — PRD

## Problem Statement
The problem the user faces, from the user's perspective.

## Solution
The solution, from the user's perspective.

## User Stories
A long, numbered list. Each: "As an <actor>, I want a <feature>, so that <benefit>."
Cover every aspect surfaced during the grill — happy paths and edge cases.

## Implementation Decisions
Modules to build/modify, interfaces being changed, architectural choices, schema
changes, API contracts, specific interactions. No file paths or code.

## Testing Decisions
What makes a good test here (test external behavior, not internals), which modules
get tested, and prior art for similar tests in the codebase.

## Out of Scope
What was explicitly deferred or excluded — with the reason.

## Open Questions
Anything still unresolved that must be answered before/during spec.
```

### 6. Hand off

Point the user to `uncle-dev-spec` (and `uncle-dev-ubiquitous-language` if terms still need formalizing). The PRD is the spec's input.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I get the gist, I'll just start the spec" | The gist is exactly where the agent and user diverge. The expensive failure is a confident spec built on a wrong assumption. Grill first. |
| "That's too many questions, it's annoying" | Each unanswered branch is a guess that becomes rework. Depth-first means the user only ever answers one focused thread at a time. |
| "I'll ask everything up front in one list" | Flat lists can't follow consequences. Answers reshape the tree — ask, then follow where the answer leads. |
| "We can resolve edge cases during coding" | Edge cases discovered mid-build force rearchitecture. Surface them while the design is still words. |
| "The user already wrote it up, I'll just convert it" | Write-ups have holes the author can't see. Grill the write-up — the contradictions are the value. |

## Red Flags

- Asking a flat list of questions instead of following each branch to the bottom
- Moving to the next topic while a dependency on the current one is unresolved
- Writing the PRD before the user has confirmed the played-back understanding
- Stopping at a fixed question count rather than at branch-exhaustion
- Yes-machining: accepting vague answers without pushing for precision
- PRD contains file paths or speculative code snippets that will rot

## Verification

After the grill:

- [ ] Every design-tree branch (actors, model, flows, scope, edges, non-functionals, integrations, success) was walked to resolution
- [ ] Contradictions surfaced during the interview were resolved, not ignored
- [ ] The user explicitly confirmed the played-back design concept
- [ ] `docs/prd/<slug>.md` exists and uses the project's ubiquitous language
- [ ] The PRD has an Out of Scope list and Open Questions section
- [ ] No file paths or speculative code in the PRD (except a single decision-encoding snippet where prose can't suffice)
