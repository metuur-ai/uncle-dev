# Research: Does uncle-dev follow the "software fundamentals matter more with AI" principles?

**Date:** 2026-06-02
**Question:** Map the 6 fundamental principles ("software fundamentals matter now more than ever" in the AI era) against the uncle-dev skill collection. Document where each principle is embodied, with file:line evidence, and where gaps exist.
**Scope:** `skills/`, `agents/`, `.claude/commands/` in this repo.

> **Note on mindset:** The uncle-dev-research skill is normally a pure documentarian. The user's question is explicitly evaluative ("is uncle dev following these principles?"), so this document maps principles → evidence and renders a verdict per principle. Verdicts are grounded in cited file:line evidence, not opinion.

---

## Executive Summary

| # | Principle | Verdict | Primary homes |
|---|-----------|---------|---------------|
| 1 | Code is not cheap / resist software entropy | ✅ **Strong (practice)**, 🟡 framing implicit | `code-review-and-quality`, `dev-code-simplification`, `incremental-implementation` |
| 2 | Shared design concept via "Grill Me" | 🟡 **Partial** | `idea-refine`, `spec-driven-development`, `research`, `acknowledge` |
| 3 | Ubiquitous language (DDD) | ❌ **Gap** | *(none)* |
| 4 | Small feedback loops via TDD | ✅✅ **Strong** | `test-driven-development`, `incremental-implementation`, `browser-testing-with-devtools` |
| 5 | Deep modules (Ousterhout) | 🟡 **Partial** | `api-and-interface-design`, `dev-code-simplification` reference, `idea-refine` |
| 6 | Design the interface, delegate implementation | ✅✅ **Strong** | `design-architecture-docs`, `spec-driven-development`, `api-and-interface-design`, `spec-annotations` |

**Tally:** 3 strong, 2 partial, 1 gap. The collection's backbone (principles 4 and 6 — spec-driven discipline + tight feedback loops) is fully realized. The single clear gap is **ubiquitous language / DDD glossary** (principle 3).

---

## Principle 1 — Code is Not Cheap & Must Resist "Software Entropy"

**Claim:** Bad code is the most expensive it has ever been because a messy codebase prevents AI from assisting. Resist drift; don't make isolated changes that degrade the whole.

**Evidence — present in practice:**
- `skills/uncle-dev-code-review-and-quality/SKILL.md:12` — approval standard is explicitly "improves overall **code health**… the goal is continuous improvement." Multi-axis review (correctness, readability, architecture, security, performance) gates every merge.
- `skills/uncle-dev-code-review-and-quality/SKILL.md:6` — "Every change gets reviewed before merge — no exceptions."
- `skills/uncle-dev-incremental-implementation/SKILL.md:10,224` — each increment "leaves the system in a working, testable state"; red flag at "more than 100 lines of code written without running tests" — directly counters the "blindly run the compiler on specs and let it rot" failure mode.
- `skills/uncle-dev-dev-code-simplification/` — entire skill dedicated to reducing accumulated complexity.
- `skills/uncle-dev-ci-cd-and-automation/SKILL.md:227` — names "technical debt" explicitly (flag lifecycle / cleanup dates).

**Gap / nuance:**
- The *practice* of resisting entropy is well covered, but the *vocabulary* from The Pragmatic Programmer ("software entropy", "broken windows") is essentially absent — only `ci-cd` says "technical debt" by name. The discipline is enforced; the narrative framing ("bad code is expensive *because it blocks the AI*") is not stated as a first-class motivation anywhere.

**Verdict: ✅ Strong in practice, framing implicit.**

---

## Principle 2 — Shared "Design Concept" via the "Grill Me" Method

**Claim:** Humans and AI start without a shared design concept. A "Grill Me" prompt relentlessly interviews the user (40–100 questions), walking every branch of the design tree, turning the AI into a helpful adversary, producing a solid PRD.

**Evidence — partial coverage:**
- `skills/uncle-dev-idea-refine/SKILL.md:12-13` — divergent/convergent loop: "Restate the idea, ask sharpening questions… Cluster ideas, stress-test them, and surface hidden assumptions."
- `skills/uncle-dev-idea-refine/SKILL.md:48` — "Challenge every assumption. 'How it's usually done' is not a reason."
- `skills/uncle-dev-idea-refine/SKILL.md:106` — "Be honest, not supportive… A good ideation partner is not a yes-machine. Push back… point out when the emperor has no clothes." (adversarial posture is present)
- `skills/uncle-dev-idea-refine/examples.md:140` — example shows the AI scanning the codebase, then asking targeted questions before proposing — the "resolve dependencies one by one" behavior in miniature.
- `skills/uncle-dev-spec-driven-development/SKILL.md` (LID+EARS) and `uncle-dev-acknowledge` carry the "reach shared understanding before code" intent.
- `skills/uncle-dev-dev-code-simplification/reference/request-refactor-plan-SKILL.md:3` — "Create a detailed refactor plan… via **user interview**" — the interview pattern exists, scoped to refactors.

**Gap / nuance:**
- The adversarial *intensity* is deliberately capped, not maximized. `idea-refine/SKILL.md:62` instructs "Ask **3-5 sharpening questions** — **no more**." That is the opposite of the "40–100 questions, walk every branch" Grill Me method.
- No skill is named or designed as a relentless interrogation that exhaustively walks the design tree until dependencies are resolved. The collection converges politely and quickly rather than grilling.
- PRD output exists in spirit (HLD/EARS, idea one-pager) but no "Grill Me → PRD" pipeline is named as such.

**Verdict: 🟡 Partial.** The intent (shared understanding before code, adversarial honesty) is present and distributed across `idea-refine` / `spec-driven-development` / `acknowledge`, but the *exhaustive interrogation* mechanic is explicitly avoided.

---

## Principle 3 — Implement a "Ubiquitous Language" (DDD)

**Claim:** Bridge the human↔AI communication gap with a Domain-Driven Design ubiquitous language. Script-scan the codebase to produce a markdown glossary of core terminology; keep it open during planning so the AI thinks in domain terms and generates aligned code.

**Evidence:**
- `grep -rli "ubiquitous|domain-driven|bounded context|domain model"` across `skills/`, `agents/`, `.claude/` → **zero matches.**
- No skill produces or maintains a domain glossary. `code-context` / `context-engineering` manage AGENTS.md and code context, but not a terminology table.
- Untracked draft exists at `tmp/ubiquitous-language-SKILL.md` (not integrated into `skills/`).

**Verdict: ❌ Gap.** This is the one principle with no representation in the shipped collection. It also fits the project's stated bar ("actionable processes, not vague advice") and the **Define** phase cleanly — a scan-to-glossary skill would be scriptable and concrete.

---

## Principle 4 — Small Feedback Loops via TDD

**Claim:** AI "outruns its headlights" by writing too much unverified code. "The rate of feedback is your speed limit." Force TDD (test-first → pass → refactor), plus static types and browser access as additional loops.

**Evidence — strong, multi-skill:**
- `skills/uncle-dev-test-driven-development/SKILL.md:14` — "Write a failing test before writing the code that makes it pass." + "a codebase without tests is a liability."
- `skills/uncle-dev-test-driven-development/SKILL.md:63-107` — explicit **RED → GREEN → REFACTOR** cycle with TypeScript examples (lines 75, 93, 143) — matches the static-types feedback loop too.
- `skills/uncle-dev-incremental-implementation/SKILL.md:10,17,224` — "thin vertical slices"; red flag at ">~100 lines before testing" — this *is* "rate of feedback is your speed limit" operationalized.
- `skills/uncle-dev-browser-testing-with-devtools/SKILL.md:10` — "give your agent eyes into the browser… Instead of guessing what's happening at runtime, **verify it**." — the "give the LLM access to the browser to look around" loop, verbatim in spirit.
- Supporting: `uncle-dev-mutation-testing` (verifies test quality), `uncle-dev-debug-error` (reproduce-first).

**Verdict: ✅✅ Strong.** All three named feedback loops (TDD, static types, browser) are present. This is arguably the most fully-realized principle in the collection.

---

## Principle 5 — Organize Code into "Deep Modules" (Ousterhout)

**Claim:** Per *A Philosophy of Software Design*, prefer deep modules (simple interface hiding large functionality) over shallow ones. AI navigates deep, well-bounded modules easily; it drowns in tiny shallow blobs.

**Evidence — partial:**
- `skills/uncle-dev-dev-code-simplification/reference/design-an-interface-SKILL.md:87` — names it exactly: "**Depth**: Small interface hiding significant complexity = **deep module (good)**. Large interface with thin implementation = **shallow module (avoid)**." This is the clearest direct hit.
- `skills/uncle-dev-api-and-interface-design/SKILL.md:10` — "interfaces that are **hard to misuse**… make the right thing easy and the wrong thing hard."
- `skills/uncle-dev-api-and-interface-design/SKILL.md:22,31,270` — Hyrum's Law treated as first-class (interface = commitment), reinforcing strict boundaries.

**Gap / nuance:**
- "Deep vs shallow modules" lives in a **reference file** of the simplification skill, not as a top-level, enforced design principle across the **Build** phase. It is mentioned, not systematically applied.
- `idea-refine/SKILL.md:144,160` uses "shallow" only in the unrelated sense of "shallow ideas" — not module depth.
- No skill instructs "wrap related code into deep modules with strict boundaries" as a build-time discipline, nor connects module depth to AI navigability.

**Verdict: 🟡 Partial.** The concept is named and correct where it appears, but it is not a first-class, consistently-enforced principle.

---

## Principle 6 — Design the Interface, Delegate the Implementation

**Claim:** The human stays the strategic architect; the AI is the tactical programmer. Treat modules as "gray boxes" — rigorously design/review the outer interface, delegate the inner "blob." Define interface changes in the PRD; manage the high-level map.

**Evidence — strong, foundational:**
- `skills/uncle-dev-spec-driven-development/SKILL.md:14` — "**Design is the single source of truth.** Intent flows downstream: **HLD → LLD → EARS → code/tests**. If all code were deleted, the spec documents must be sufficient to regenerate the project entirely." — this is precisely "architect owns design, implementation is downstream/delegable."
- `skills/uncle-dev-design-architecture-docs/SKILL.md` — owns the upstream half (HLD = product intent, per-segment LLD = system approach); explicitly hands the downstream half (EARS, tests, code) to `spec-annotations`. The separation of "design layer (human-owned)" vs "implementation layer (delegated)" is the skill's architecture.
- `skills/uncle-dev-api-and-interface-design/SKILL.md:10` — interface-first design as a dedicated skill (the "outer interface of the gray box").
- `skills/uncle-dev-spec-driven-development/SKILL.md:147-149` — pre-mortem gate before locking the design — reinforces "invest in design every day."
- CLAUDE.md project convention: "Architecture intent flows HLD → LLD → EARS specs → tests → code. Code and tests reference durable behavior via `@spec` annotations." — institutionalized at the repo level.

**Gap / nuance:**
- The "gray box" framing and the explicit "for **non-critical** parts, delegate the blob entirely; for critical parts, design rigorously" risk-tiering is not stated. The collection tends toward rigor everywhere rather than triaging where to delegate fully vs. review closely.

**Verdict: ✅✅ Strong.** The HLD→LLD→EARS→code chain *is* "design the interface, delegate the implementation," institutionalized as the spine of the whole methodology.

---

## Consolidated Gaps (what's missing or thin)

1. **Ubiquitous language / DDD glossary (P3) — the only true gap.** No scan-to-glossary skill. Draft exists at `tmp/ubiquitous-language-SKILL.md`, unintegrated. Natural fit: **Define** phase.
2. **"Grill Me" intensity (P2).** Adversarial questioning is present but deliberately capped at 3–5 questions; no exhaustive design-tree interrogation. Could be a mode/flag on `idea-refine` or `acknowledge` rather than a new skill.
3. **Deep-module discipline (P5) is a reference footnote**, not a Build-phase principle. Could be promoted into `api-and-interface-design` or `incremental-implementation` as an enforced check.
4. **Entropy framing (P1) and gray-box risk-tiering (P6)** are practiced but not named — narrative/motivation gaps rather than capability gaps.

---

## Key File References

| Principle | Strongest evidence |
|-----------|--------------------|
| 1 | `skills/uncle-dev-code-review-and-quality/SKILL.md:12`; `skills/uncle-dev-incremental-implementation/SKILL.md:224` |
| 2 | `skills/uncle-dev-idea-refine/SKILL.md:12-13,62,106`; `…/request-refactor-plan-SKILL.md:3` |
| 3 | *(none — confirmed absent)*; draft at `tmp/ubiquitous-language-SKILL.md` |
| 4 | `skills/uncle-dev-test-driven-development/SKILL.md:14,63-107`; `skills/uncle-dev-incremental-implementation/SKILL.md:10,17`; `skills/uncle-dev-browser-testing-with-devtools/SKILL.md:10` |
| 5 | `skills/uncle-dev-dev-code-simplification/reference/design-an-interface-SKILL.md:87`; `skills/uncle-dev-api-and-interface-design/SKILL.md:10,22` |
| 6 | `skills/uncle-dev-spec-driven-development/SKILL.md:14,147-149`; `skills/uncle-dev-design-architecture-docs/SKILL.md` (whole) |
