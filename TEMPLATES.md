# Prompt Templates

Copy-paste templates for every phase of the `uncle-dev-agent-skills` plugin. Fill in the brackets and send.

**When to use which part:**
- **Part 1 — Validate**: Challenge your idea, scope, and approach before writing any code.
- **Part 2 — Per-Skill Validation**: Deeper grilling through the lens of each specific skill.
- **Part 3 — Execute**: Phase commands for when you're actually writing code.

---

## Contents

- [Part 1 — Validate](#part-1--validate)
  - [Full Gauntlet](#full-gauntlet)
  - [Grill Me — Idea Validation](#grill-me--idea-validation)
  - [Grill Me — Feature Scope](#grill-me--feature-scope)
  - [Grill Me — Tech Decision](#grill-me--tech-decision)
  - [Grill Me — Architecture Decision](#grill-me--architecture-decision)
  - [Grill Me — API Design](#grill-me--api-design)
  - [Grill Me — Implementation Plan](#grill-me--implementation-plan)
  - [Grill Me — Bug Hypothesis](#grill-me--bug-hypothesis)
  - [Grill Me — Refactor Justification](#grill-me--refactor-justification)
  - [Brainstorm — Multiple Approaches](#brainstorm--multiple-approaches)
  - [Brainstorm — What Could Go Wrong](#brainstorm--what-could-go-wrong)
- [Part 2 — Per-Skill Validation](#part-2--per-skill-validation)
  - [Define](#define)
  - [Plan](#plan)
  - [Build](#build)
  - [Verify](#verify)
  - [Review](#review)
  - [Ship](#ship)
- [Part 3 — Execute](#part-3--execute)
  - [/uncle-dev-spec — Define](#spec--define)
  - [/uncle-dev-plan — Plan](#plan--plan)
  - [/uncle-dev-build — Build](#build--build)
  - [/uncle-dev-test — Verify](#test--verify)
  - [/uncle-dev-review — Review](#review--review)
  - [/uncle-dev-code-simplify — Cleanup](#code-simplify--cleanup)
  - [/uncle-dev-ship — Ship](#ship--ship)

---

# Part 1 — Validate

Adversarial, challenge-first templates. Use before writing any code or spec. Each template pushes back on your idea from a different angle.

---

## Full Gauntlet

> Use when you want to validate an idea end-to-end before writing any code. Runs 7 skills in order — stops if the idea fails a gate.

```
I want to validate this idea before writing any code. Run a full gauntlet.

Idea: [ONE SENTENCE]
Context: [TECH STACK / TEAM SIZE / EXISTING SYSTEM IT FITS INTO]

Run these skills in order, grill me at each step, and stop if the idea fails a gate:

1. idea-refine              → Is this the right problem? Generate variations, surface assumptions.
2. security-and-hardening   → What's the threat model before I commit to an approach?
3. performance-optimization → Will this survive real load?
4. api-and-interface-design → Is the interface survivable and evolvable?
5. incremental-implementation → Can this be built in safe slices with feature flags?
6. test-driven-development  → What's the first failing test that proves the core behavior?
7. spec-driven-development  → Scaffold the OpenSpec change. Propose a change-id.

At the end, give me:
- GO / NO-GO verdict
- The 3 biggest unresolved risks
- The first slice to build if we proceed
```

---

## Grill Me — Idea Validation

> Before writing any spec. Forces you to defend the idea before committing.

```
Grill me on this idea before I spec it.

The idea: [ONE SENTENCE DESCRIPTION]

I think the problem is: [YOUR CURRENT FRAMING]
I think the solution is: [YOUR PROPOSED APPROACH]

Your job:
1. Challenge my problem framing — is this actually the pain, or a symptom?
2. Ask me the hardest question about this idea (the one I'm avoiding)
3. Tell me the most likely way this fails in production
4. Tell me the most likely way users ignore or misuse it
5. Propose a narrower version I could validate in [1 day / 1 week]

Do not be nice. I need to know if this idea is weak before I write code.
```

**Example:**
```
Grill me on this idea before I spec it.

The idea: auto-assign bugs to engineers based on git blame

I think the problem is: bugs sit in the backlog unassigned for too long
I think the solution is: parse blame history, assign automatically on creation

Your job:
1. Challenge my problem framing — is this actually the pain, or a symptom?
2. Ask me the hardest question about this idea (the one I'm avoiding)
3. Tell me the most likely way this fails in production
4. Tell me the most likely way users ignore or misuse it
5. Propose a narrower version I could validate in 1 week

Do not be nice. I need to know if this idea is weak before I write code.
```

---

## Grill Me — Feature Scope

> Use when a feature keeps expanding. Forces scope reduction before it's too late.

```
Grill me on scope before this gets out of hand.

Feature: [NAME]
What's currently planned: [LIST THE THINGS IN SCOPE]
Original goal: [ONE SENTENCE — what problem this solves]
Hard deadline: [DATE OR "flexible"]

Your job:
1. Which items in scope don't directly serve the original goal?
2. What's the minimum version that lets us learn whether this is worth building?
3. What are we building for hypothetical users vs. actual ones?
4. Which item is most likely to cause the other items to slip?
5. If I had to ship something in [HALF THE TIME], what stays and what gets cut?
6. After all that — rewrite the scope in one sentence. What are we actually building?
```

---

## Grill Me — Tech Decision

> Use when you've already picked a technology and want it stress-tested.

```
Grill me on this tech decision.

Decision: use [TECHNOLOGY/LIBRARY/PATTERN] for [USE CASE]
Alternative I rejected: [WHAT YOU DIDN'T PICK AND WHY]
Scale: [expected load / data volume / team size]
Constraints: [latency requirements / existing stack / team expertise]

Your job:
1. What does [TECHNOLOGY] do badly at [SCALE]?
2. What breaks first under load — and at what threshold?
3. What's the migration cost if we get this wrong in 6 months?
4. Name one team that made this choice and regretted it. Why did they?
5. What's the strongest argument for [ALTERNATIVE I REJECTED]?
6. After all that — do you still recommend [TECHNOLOGY]? Give me a verdict.
```

**Example:**
```
Grill me on this tech decision.

Decision: use Redis for session storage
Alternative I rejected: Postgres with a sessions table — too slow for high read volume
Scale: 50k DAU, ~500 concurrent sessions at peak
Constraints: sub-10ms session reads, existing Redis instance already in stack

Your job:
1. What does Redis do badly at this scale?
2. What breaks first under load — and at what threshold?
3. What's the migration cost if we get this wrong in 6 months?
4. Name one team that made this choice and regretted it. Why did they?
5. What's the strongest argument for Postgres sessions?
6. After all that — do you still recommend Redis? Give me a verdict.
```

---

## Grill Me — Architecture Decision

> Use when you're making a structural decision that's hard to reverse.

```
Grill me on this architecture decision.

Decision: [DESCRIBE THE ARCHITECTURAL CHOICE]
What it replaces: [CURRENT STATE]
Why I want to change it: [YOUR REASONING]

Your job:
1. Draw the data flow before and after — where does complexity move, not disappear?
2. What are the 3 failure modes this introduces that we don't have today?
3. What does this look like 18 months from now when the team is 3x larger?
4. Where is Hyrum's Law going to bite us — what implicit behavior are callers depending on?
5. What's the minimal version of this change that gives us 80% of the benefit?
6. Is there a well-known pattern name for what I'm describing? If so, what are its known failure modes?
```

**Example:**
```
Grill me on this architecture decision.

Decision: split the monolith into 3 services — auth, orders, inventory
What it replaces: single Rails app, shared Postgres DB
Why I want to change it: deployments are slow, auth changes break order logic

Your job:
1. Draw the data flow before and after — where does complexity move, not disappear?
2. What are the 3 failure modes this introduces that we don't have today?
3. What does this look like 18 months from now when the team is 3x larger?
4. Where is Hyrum's Law going to bite us — what implicit behavior are callers depending on?
5. What's the minimal version of this change that gives us 80% of the benefit?
6. Is there a well-known pattern name for what I'm describing? If so, what are its known failure modes?
```

---

## Grill Me — API Design

> Use before implementing any public-facing interface.

```
Grill me on this API design before I implement it.

Endpoint: [METHOD] [PATH]
Purpose: [WHAT IT DOES]
Request shape: [PARAMS / BODY]
Response shape: [WHAT IT RETURNS]
Consumers: [WHO CALLS THIS — internal / external / mobile / third-party]

Your job:
1. What's the Hyrum's Law trap here — what will callers depend on that I haven't guaranteed?
2. What breaks when the response shape needs to change in 6 months?
3. What's the error case I haven't modeled?
4. What happens when this is called 10x more than expected?
5. What would a developer integrating this for the first time get wrong?
6. Is there an existing standard (RFC, OpenAPI convention, REST constraint) I'm violating?
```

---

## Grill Me — Implementation Plan

> Use after `/uncle-dev-plan` runs. Stress-test the task breakdown before writing code.

```
Grill me on this implementation plan.

Plan: [PASTE tasks.md SUMMARY OR DESCRIBE THE SLICES]
Team: [solo / N engineers]
Timeline: [hard deadline or flexible]

Your job:
1. What's the most dangerous dependency in this plan — the one that blocks everything else?
2. Which story has the highest chance of scope creep and why?
3. What's the first slice I should cut if I run out of time?
4. What did I forget to spec that will bite me during implementation?
5. Is the test plan strong enough to catch a regression in [CRITICAL PATH]?
6. What would a staff engineer change about this plan before approving it?
```

---

## Grill Me — Bug Hypothesis

> Use before running `/investigate`. Force yourself to have a hypothesis first.

```
Grill me on my bug hypothesis before I start investigating.

Bug: [DESCRIPTION OF THE SYMPTOM]
My hypothesis: [WHAT YOU THINK IS CAUSING IT]
Evidence I have: [LOGS / REPRODUCTION STEPS / OBSERVATIONS]
Evidence I'm missing: [WHAT YOU HAVEN'T CHECKED YET]

Your job:
1. What's wrong with my hypothesis — what does it fail to explain?
2. What's the simplest explanation that fits all the evidence?
3. What's one test I can run in under 5 minutes that would prove or disprove my hypothesis?
4. If my hypothesis is right, what else should be broken that we haven't noticed yet?
5. What's the blast radius if I'm wrong and I go fix the wrong thing?
```

**Example:**
```
Grill me on my bug hypothesis before I start investigating.

Bug: checkout silently drops items under load — no error, item disappears from cart
My hypothesis: the inventory lock is timing out and failing silently
Evidence I have: flakes at ~50 RPS, no 500s in logs, lock timeout set to 500ms
Evidence I'm missing: haven't checked if there's a second unguarded inventory path

Your job:
1. What's wrong with my hypothesis — what does it fail to explain?
2. What's the simplest explanation that fits all the evidence?
3. What's one test I can run in under 5 minutes that would prove or disprove my hypothesis?
4. If my hypothesis is right, what else should be broken that we haven't noticed yet?
5. What's the blast radius if I'm wrong and I go fix the wrong thing?
```

---

## Grill Me — Refactor Justification

> Use before a large refactor. Make sure it's worth the risk.

```
Grill me on whether this refactor is worth doing.

What I want to refactor: [FILE / MODULE / PATTERN]
Why I think it needs it: [YOUR REASONING]
Size of the change: [estimated lines / files touched]
Test coverage today: [% or "low/medium/high"]

Your job:
1. Is this Chesterton's Fence — do I actually understand why it's written this way?
2. What's the risk-to-reward ratio? How much do we gain vs. how much can go wrong?
3. What's the smallest version of this refactor that addresses the core problem?
4. What tests need to exist before I touch this safely?
5. How do I know when I'm done — what's the exit criterion?
6. Is "the code is messy" a good enough reason to do this right now?
```

---

## Brainstorm — Multiple Approaches

> Use when you want options generated and pressure-tested before picking one.

```
Generate 3 approaches for [PROBLEM], then grill each one.

Problem: [DESCRIPTION]
Constraints: [performance / cost / team expertise / time]
Non-negotiables: [THINGS THAT CANNOT CHANGE]

For each approach:
- Name it (1-3 words)
- Describe it in 2 sentences
- Best case: what does success look like?
- Worst case: what does failure look like?
- Effort: [S / M / L / XL]
- Reversibility: [easy to undo / hard to undo / irreversible]

Then recommend one with a clear rationale.
Do not hedge. Pick one.
```

---

## Brainstorm — What Could Go Wrong

> Use after any plan, spec, or implementation to find the gaps.

```
You are a pessimist reviewing [FEATURE/PLAN/DESIGN].

Assume everything goes wrong. Walk me through:

1. HAPPY PATH FAILURE: What breaks in the normal flow that we haven't tested?
2. EDGE CASE: What input or state triggers behavior we haven't defined?
3. RACE CONDITION: What happens if two things happen at the same time?
4. DEPENDENCY FAILURE: What external system can fail and how do we degrade?
5. LOAD: What breaks at 10x current traffic?
6. SECURITY: What can a malicious actor do with this?
7. DATA LOSS: Where can we silently lose or corrupt data?
8. ROLLBACK: If we need to revert this in 2 hours, what breaks?

For each: rate severity [P0 / P1 / P2] and suggest the minimum viable mitigation.
```

---

# Part 2 — Per-Skill Validation

Use these to pressure-test an idea through the lens of each specific skill before writing a line of code. Each template activates the skill's checklist as an adversarial reviewer, not a builder.

**How to use:** Pick the skills most relevant to your idea, fill in the brackets, and fire them in sequence. Start with `idea-refine`, end with `spec-driven-development`.

---

## Define

### `idea-refine` — Is This Even the Right Idea?

```
Use the idea-refine skill. Grill me on this idea before I commit to anything.

Idea: [ONE SENTENCE]

Run all three phases:
1. Divergent — restate as a "How Might We", ask your 3-5 sharpening questions,
   then generate 5-8 variations using inversion, constraint removal, audience shift,
   combination, simplification, and 10x lenses.
2. Convergent — cluster into 2-3 directions, stress-test each on user value /
   feasibility / differentiation, surface the hidden assumptions that could kill each one.
3. Sharpen — produce the markdown one-pager: problem statement, recommended direction,
   key assumptions to validate, MVP scope, and "Not Doing" list.

Do not be supportive. Be honest. If the idea is weak, say so with specificity.
```

### `spec-driven-development` — Can This Be Properly Specified?

```
Use the spec-driven-development skill. Grill me on whether this idea is ready to spec.

Idea: [DESCRIPTION]

Before writing any artifact, challenge me on:
1. Have I read the current openspec/specs/ truth? What conflicts might exist?
2. Is this one change or three changes pretending to be one?
3. Can I write a success criteria that is specific and testable — not "works better"?
4. What assumptions am I making that belong in the proposal before code?
5. What would make this change fail at the handoff stage — what's missing from my thinking?

If the idea passes, propose a change-id and scaffold the five artifacts.
If it doesn't, tell me what I need to resolve first.
```

### `context-engineering` — Do I Have the Right Information to Build This?

```
Use the context-engineering skill. Grill me on whether I have enough context to start.

Idea: [DESCRIPTION]
What I know: [YOUR CURRENT UNDERSTANDING]
What I'm unsure about: [GAPS IN YOUR KNOWLEDGE]

Challenge me on:
1. Rules files — what project conventions exist that I need to load before touching this code?
2. Context packing — what existing code should I read before writing anything new?
3. MCP integrations — what external data sources or tools do I need access to?
4. What existing implementation in this codebase is most similar to what I'm building?
5. What would I discover if I searched the codebase for [KEY TERM] right now?
6. What context am I missing that will make my first implementation attempt wrong?

Verdict: list the 3-5 files I must read before writing the first line of this feature.
```

### `source-driven-development` — Is This Grounded in Actual Documentation?

```
Use the source-driven-development skill. Grill me on whether my approach is documented and verified.

Idea: [DESCRIPTION]
Framework / library / API I'm using: [NAME AND VERSION]
My current understanding of how it works: [DESCRIBE YOUR ASSUMPTION]

Challenge me on:
1. Have I read the official docs for this version, or am I working from memory / LLM output?
2. What's the specific API contract I'm depending on — and is it stable or experimental?
3. What differs between the version I'm using and the latest — am I using a deprecated pattern?
4. What does the official migration guide say I should do instead?
5. What behavior am I assuming that the docs don't actually guarantee?
6. Flag everything I've stated that is unverified — I'll decide what to check next.

Verdict: what must I verify in official documentation before I trust this approach?
```

---

## Plan

### `planning-and-task-breakdown` — Can This Be Broken Into Real Stories?

```
Use the planning-and-task-breakdown skill. Grill me on the decomposition of this idea.

Idea: [DESCRIPTION]
Rough implementation plan: [YOUR CURRENT THINKING]
Team: [solo / N engineers]

Challenge me on:
1. Story-level vs code-level — are my tasks "implement X" or "make Y behavior work for Z user"?
2. Dependency graph — what's the most dangerous dependency that blocks everything else?
3. Parallelism — which stories can run in parallel and which must be sequential?
4. Scope creep — which story is most likely to expand and why?
5. What did I forget to include that will appear mid-sprint as an unplanned blocker?
6. What would a staff engineer change about this breakdown before approving it?

Verdict: rewrite the first three stories with clear acceptance criteria and verification steps.
```

### `incremental-implementation` — Can This Be Built in Safe Slices?

```
Use the incremental-implementation skill. Grill me on whether this idea can be built incrementally.

Idea: [DESCRIPTION]
Rough scope: [HOW MANY FILES / SYSTEMS ARE TOUCHED]

Challenge me on:
1. Thin vertical slices — what's the thinnest slice that runs end-to-end?
2. Feature flags — what's the safe default if the flag is off? What breaks if it's on?
3. Rollback-friendly — which part of this idea is hardest to revert after merging?
4. Change size — is this one change or five changes that should ship separately?
5. What's the first slice I should cut if the deadline moves up?
6. What's the riskiest slice and should it go first (to learn early) or last (to reduce blast radius)?

Verdict: define the first slice in one sentence — what does it implement and what does it not touch?
```

---

## Build

### `api-and-interface-design` — Will This Interface Survive Contact With Users?

```
Use the api-and-interface-design skill. Grill me on the interface this idea requires.

Idea: [DESCRIPTION]
Interface I'm imagining: [ENDPOINTS / METHODS / DATA SHAPES / EVENTS]
Consumers: [internal service / external developers / mobile app / third-party]

Challenge me on:
1. Hyrum's Law — what will callers depend on that I haven't explicitly guaranteed?
2. Contract-first — have I defined the contract before the implementation, or am I guessing?
3. One-Version Rule — how do I evolve this without breaking existing callers?
4. Error semantics — what error shapes does this expose and are they actionable?
5. Boundary validation — where does untrusted input enter and is it validated there?
6. What's the hardest part of this interface to change after it's live?

Verdict: is this interface ready to implement, or does it need a redesign?
```

### `frontend-ui-engineering` — Will Users Actually Be Able to Use This?

```
Use the frontend-ui-engineering skill. Grill me on the user-facing side of this idea.

Idea: [DESCRIPTION]
Screens / flows involved: [LIST THEM]
Users: [WHO USES THIS AND ON WHAT DEVICE]

Challenge me on:
1. Component architecture — am I designing components with the right boundaries,
   or will this become a tangle of props and shared state?
2. State management — where does the state live, and what breaks when it gets stale?
3. Accessibility — does this work keyboard-only? Screen reader? WCAG 2.1 AA?
4. Responsive design — what breaks at 320px? At 1440px?
5. Design system — am I introducing new patterns when existing ones exist?
6. What's the most confusing moment in this flow for a first-time user?

Verdict: what must be resolved before I start building UI?
```

### `test-driven-development` — Can I Prove This Works?

```
Use the test-driven-development skill. Grill me on the testability of this idea.

Idea: [DESCRIPTION]
Core behavior to prove: [WHAT MUST BE TRUE WHEN THIS IS WORKING]
Edge cases I know about: [LIST THEM]

Challenge me on:
1. Test pyramid — what's the split between unit / integration / E2E for this feature?
2. Beyoncé Rule — if I don't have a test for a behavior, do I actually own that behavior?
3. DAMP vs DRY — are my tests going to be readable in isolation without shared state?
4. What's the hardest behavior to test in this idea, and why?
5. What bug would pass all my planned tests but still break in production?
6. What test do I write first, before any implementation, to prove the core behavior?

Verdict: write the first failing test for the core behavior right now.
```

---

## Verify

### `debugging-and-error-recovery` — What Happens When This Fails?

```
Use the debugging-and-error-recovery skill. Grill me on the failure modes of this idea.

Idea: [DESCRIPTION]
Known failure scenarios: [WHAT YOU EXPECT MIGHT BREAK]
Current observability: [logs / metrics / alerts / none]

Challenge me on:
1. Five-step triage — when this breaks in production, can I reproduce it locally?
2. Safe fallbacks — what's the degraded experience when a dependency fails?
3. Stop-the-line rule — what failure is severe enough to roll back immediately?
4. Error surfaces — where does this idea swallow errors silently?
5. What does the on-call engineer see when this breaks at 2am?
6. What's the minimal reproduction case for the most likely failure?

Verdict: what observability and fallback behavior must be designed before I build this?
```

### `browser-testing-with-devtools` — Will This Work in a Real Browser?

```
Use the browser-testing-with-devtools skill. Grill me on browser behavior for this idea.

Idea: [DESCRIPTION]
Browser-facing behavior: [WHAT THE USER SEES / DOES]
Known browser targets: [Chrome / Safari / Firefox / mobile]

Challenge me on:
1. DOM inspection — what DOM structure am I assuming that might not exist at runtime?
2. Console errors — what errors will appear in the console on first load that I haven't handled?
3. Network traces — what API calls does this trigger and are the payloads correct?
4. Performance profiling — what will the flamegraph show that surprises me?
5. What breaks on mobile that works on desktop?
6. What's the runtime behavior I can only verify by actually opening DevTools?

Verdict: what must I verify in a real browser before I call this done?
```

---

## Review

### `code-review-and-quality` — Will This Pass a Staff Engineer Review?

```
Use the code-review-and-quality skill. Grill me on the quality implications of this idea.

Idea: [DESCRIPTION]
Code it will touch: [FILES / MODULES / PATTERNS]

Challenge me on the five axes before I write a line:
1. Correctness — what's the edge case most likely to produce wrong output?
2. Readability — what naming or structure decision will confuse the next engineer?
3. Architecture — does this follow existing patterns or introduce a new one that needs justification?
4. Security — what's the most obvious security smell in this approach?
5. Performance — what's the obvious inefficiency I'm not seeing because I'm too close to it?

Then: what's the change size? Is this reviewable as one PR or should it be split?

Verdict: what must be resolved before I'd approve this at PR review?
```

### `dev-code-simplification` — Am I Adding Unnecessary Complexity?

```
Use the dev-code-simplification skill. Grill me on complexity before I introduce it.

Idea: [DESCRIPTION]
Complexity I'm about to introduce: [ABSTRACTIONS / LAYERS / PATTERNS]
Existing code it interacts with: [FILES / MODULES]

Challenge me — Chesterton's Fence:
1. Do I understand why the existing code is the way it is before I change it?
2. What complexity am I adding, and does it solve a problem that actually exists today?
3. What's the simpler version that gives 80% of the benefit?
4. Am I creating an abstraction for one use case, or is there real evidence I'll need three?
5. Will the next engineer thank me for this or curse it?
6. Apply Rule of 500 — what files will exceed 500 lines if I implement this as planned?

Verdict: what should I simplify or remove before I start building?
```

### `security-and-hardening` — What Can Go Wrong From a Security Perspective?

```
Use the security-and-hardening skill. Run a threat model on this idea before I spec it.

Idea: [DESCRIPTION]
Data it touches: [PII / credentials / financial / user content / none]
Entry points: [APIs / forms / file uploads / webhooks / third-party callbacks]
Auth model: [how users authenticate and what they're authorized to do]

Challenge me on:
1. OWASP Top 10 — which of the top 10 is most likely to affect this idea?
2. Input validation — where does untrusted data enter and what's the worst-case payload?
3. Auth boundaries — can a user access another user's data with a crafted request?
4. Secrets management — where are credentials stored and how are they rotated?
5. Dependency risk — what third-party code does this pull in and when was it last audited?
6. What's the concrete exploit scenario for the most likely vulnerability?

Verdict: what security decisions must be made before this is safe to build?
```

### `performance-optimization` — Will This Survive Real Load?

```
Use the performance-optimization skill. Grill me on the performance profile of this idea.

Idea: [DESCRIPTION]
Expected load: [DAU / requests per second / data volume]
Performance requirements: [latency targets / Core Web Vitals / SLA]
Current baseline: [what we have today, if known]

Challenge me on:
1. Measure-first — what metric proves this is fast enough, and how do I measure it?
2. N+1 queries — where in this idea does a loop hide a database call?
3. Unbounded operations — what operation has no upper limit on how long it can take?
4. Bundle / payload size — what does this add to the client payload?
5. Core Web Vitals — which CWV does this affect and in which direction?
6. At 10x expected load — what breaks first?

Verdict: what must be resolved before this is safe to ship at scale?
```

---

## Ship

### `git-workflow-and-versioning` — Can This Be Shipped Safely With Git?

```
Use the git-workflow-and-versioning skill. Grill me on the git strategy for this idea.

Idea: [DESCRIPTION]
Estimated change size: [lines / files]
Team: [solo / N engineers working in parallel]

Challenge me on:
1. Trunk-based development — is this change small enough to merge to main within a day?
2. Atomic commits — can I commit this as save-points, or is it one big bang at the end?
3. Change sizing — is this one PR or should it be split? What's the review burden?
4. What's the commit message for the first meaningful commit on this feature?
5. What branch naming and PR title convention does this project use?
6. If a bisect finds a regression, will my commit history make the cause obvious?

Verdict: define the first commit. What does it contain and what does it not touch?
```

### `ci-cd-and-automation` — Can This Be Deployed Without Breaking Production?

```
Use the ci-cd-and-automation skill. Grill me on the deployment strategy for this idea.

Idea: [DESCRIPTION]
Current CI/CD setup: [PIPELINE DESCRIPTION OR "none"]
Deployment target: [cloud / on-prem / edge / mobile]

Challenge me on:
1. Shift Left — what quality gate catches a bug in this feature before it reaches main?
2. Feature flags — is this behind a flag, and what's the rollout plan?
3. Faster is Safer — how do I get this to production in the smallest safe increment?
4. Failure feedback loop — how long between breaking main and knowing about it?
5. What does a failed deploy of this feature look like, and how do I detect it in < 5 minutes?
6. What's the rollback procedure if this breaks production at 2am?

Verdict: what CI/CD changes are needed before this is safe to ship?
```

### `deprecation-and-migration` — Am I Creating Technical Debt I Can't Pay Off?

```
Use the deprecation-and-migration skill. Grill me on the long-term cost of this idea.

Idea: [DESCRIPTION]
What it replaces or changes: [EXISTING CODE / API / BEHAVIOR]
Who depends on the current behavior: [INTERNAL / EXTERNAL / MOBILE]

Challenge me on:
1. Code-as-liability — what new liability am I creating, and is it worth it?
2. Compulsory vs advisory — if I deprecate the old behavior, who must migrate vs who can choose to?
3. Migration pattern — what's the migration path for existing callers?
4. Zombie code — what old code will remain after this ships that nobody will clean up?
5. What's the sunset date for the old behavior, and how do I enforce it?
6. What breaks silently if a caller doesn't migrate?

Verdict: what deprecation and migration plan must exist before I build this?
```

### `documentation-and-adrs` — Will Future Engineers Understand Why I Did This?

```
Use the documentation-and-adrs skill. Grill me on the documentation implications of this idea.

Idea: [DESCRIPTION]
Architectural decisions it involves: [KEY CHOICES YOU'RE MAKING]

Challenge me on:
1. ADR trigger — does this decision meet the threshold for an Architecture Decision Record?
2. The "why" — can I explain why I chose this approach in one paragraph, without referencing the code?
3. Alternatives considered — what did I reject and why? Is that captured anywhere?
4. API documentation — if this exposes an interface, is the contract documented before implementation?
5. Inline documentation — what's non-obvious enough to require a comment vs. what should just be readable code?
6. What will the engineer who touches this in 18 months wish I had written down?

Verdict: write the one-paragraph ADR context section for the most important decision in this idea.
```

### `shipping-and-launch` — Is This Actually Ready to Ship?

```
Use the shipping-and-launch skill. Run the pre-launch checklist against this idea before I build it.

Idea: [DESCRIPTION]
Target environment: [staging / production / both]

Before I write a line of code, grill me on whether I've thought through ship-readiness:
1. Code quality gate — what does "tests pass, build clean" look like for this feature?
2. Security gate — what must pass security review before this goes live?
3. Performance gate — what metric proves this doesn't regress performance?
4. Accessibility gate — what WCAG 2.1 AA requirements apply to the UI changes?
5. Infrastructure gate — what env vars, migrations, or monitoring changes are needed?
6. Documentation gate — what must be written before I tag a release?
7. Rollback plan — how do I revert this in under 10 minutes if it breaks production?

Verdict: what's not ready that would block a ship right now?
```

---

# Part 3 — Execute

Use these once your idea is validated and a spec is approved. Run the commands in sequence.

---

## `/uncle-dev-spec` — Define

```
/uncle-dev-spec

I want to [build/fix/refactor] [FEATURE/BUG].

Context:
- Users are experiencing: [SYMPTOM]
- Root cause (if known): [CAUSE OR "unknown"]
- Affected area: [FILES/MODULE/ENDPOINT]

Constraints:
- Must NOT change: [BEHAVIOR TO PRESERVE]
- Out of scope for v1: [THINGS TO EXCLUDE]
- Needs product sign-off on: [OPEN ASSUMPTIONS]
```

---

## `/uncle-dev-plan` — Plan

```
/uncle-dev-plan

The spec for [CHANGE-ID] is approved. Break it into story-level tasks.

Requirements:
- Each slice must be independently shippable with a feature flag
- First slice should touch the minimum files possible
- Flag cross-story dependencies in execution.md

Priority: [what must ship first and why]
```

---

## `/uncle-dev-build` — Build

```
/uncle-dev-build

Implement the next pending story from [CHANGE-ID]/tasks.md.

Rules:
- Write the failing test first (RED)
- Implement minimum code to pass (GREEN)
- Feature flag: [FLAG-NAME], default [on/off]
- Do not touch: [FILES/MODULES OUT OF SCOPE]
- If blocked, update execution.md and move to the next story
```

---

## `/uncle-dev-test` — Verify

```
/uncle-dev-test

Write the test suite for [FEATURE/MODULE].

Coverage targets:
- 80% unit: [CORE BEHAVIORS TO COVER]
- 15% integration: [SYSTEM BOUNDARIES TO TEST]
- 5% E2E: [USER FLOWS TO VERIFY]

Bug to prove (if applicable):
- Reproduce: [STEPS TO TRIGGER THE BUG]
- The test must FAIL before the fix, PASS after
```

---

## `/uncle-dev-review` — Review

```
/uncle-dev-review

Review the changes for [FEATURE/PR].

Focus areas:
- Correctness: [SPECIFIC BEHAVIOR TO VERIFY]
- Security: [INPUT SURFACES / AUTH PATHS]
- Performance: [OPERATIONS THAT COULD REGRESS]
- Change size: flag if diff exceeds ~100 lines

Auto-fix anything obvious.
Flag (don't auto-fix): [DECISIONS THAT NEED MY INPUT]
```

---

## `/uncle-dev-code-simplify` — Cleanup

```
/uncle-dev-code-simplify

Simplify [FILE/MODULE].

Rules:
- Chesterton's Fence: understand each block before removing it
- Target size: under [N] lines
- Must preserve: [EDGE CASES / BEHAVIORS TO KEEP]
- Run tests after each change — revert if anything breaks
```

---

## `/uncle-dev-ship` — Ship

```
/uncle-dev-ship

Ship [CHANGE-ID / FEATURE NAME].

Pre-launch checks:
- Feature flag default: [on/off] for [% of users]
- Rollback plan: [HOW TO REVERT — e.g. disable flag, revert commit]
- Coverage must not drop below: [N%]
- Docs to update: [README / CHANGELOG / ADR]

Staged rollout: [5% → 25% → 100% OR full release]
```
