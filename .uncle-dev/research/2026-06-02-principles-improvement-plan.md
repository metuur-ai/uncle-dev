# Improvement Plan: Closing the Partials & the Gap

**Date:** 2026-06-02
**Companion to:** `2026-06-02-software-fundamentals-principles-mapping.md`
**Goal:** Raise P2 (Grill Me) and P5 (Deep Modules) from 🟡 Partial to ✅, and close the P3 (Ubiquitous Language) ❌ gap — while reusing existing assets and respecting project conventions.

> ⚠️ **Context:** uncle-dev is a **distributable Claude plugin** — changes to `skills/` affect all installers, not just local dev. Treat each change as a product change: follow `skill-anatomy.md`, add the required sections (Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification), and wire config through `scripts/uncle-dev-config.sh` only.

---

## Priority & effort overview

| Item | Principle | Effort | Reuses | New skill? |
|------|-----------|--------|--------|------------|
| A. Ubiquitous Language skill | P3 (gap) | **M** | `tmp/ubiquitous-language-SKILL.md` | ✅ new `uncle-dev-ubiquitous-language` |
| B. Grill mode + PRD | P2 (partial) | **M** | `tmp/to-prd-SKILL.md`, `idea-refine`, `acknowledge` | ❌ mode on existing skills |
| C. Deep-module discipline | P5 (partial) | **S** | `design-an-interface` reference | ❌ promote into existing skills |
| D. Framing fixes | P1, P6 | **S** | — | ❌ wording only |

Recommended order: **C → A → B → D** (smallest/safest first; B touches the most-used flow).

---

## Item A — Close the P3 GAP: `uncle-dev-ubiquitous-language`

**Problem today:** Zero DDD/glossary coverage. A draft exists at `tmp/ubiquitous-language-SKILL.md` but it is (1) conversation-scoped only, (2) not named to convention, (3) missing the required skill-anatomy sections, (4) not wired into the Define/Plan phases.

**The principle demands more than the draft:** "use a script to **scan your codebase**… keep this file open and **pass it to the AI during planning**." So the skill needs a codebase-scan mode and planning integration, not just conversation extraction.

### Steps
1. **Create** `skills/uncle-dev-ubiquitous-language/SKILL.md` from the draft, renamed to `uncle-dev-ubiquitous-language`, `disable-model-invocation: false`.
2. **Add two extraction modes:**
   - *Conversation mode* (existing draft behavior) — extract terms from the active discussion.
   - *Codebase-scan mode* (new) — sweep source for recurring domain nouns/verbs (entity names, service names, state values, event names), cluster by subdomain. Prefer graphify when present: god nodes + community structure in `graphify-out/GRAPH_REPORT.md` are a ready-made domain-term source; fall back to ripgrep over `src/`.
3. **Canonical output location:** `docs/ubiquitous-language.md` (LID+EARS mode) or `.uncle-dev/ubiquitous-language.md` (OpenSpec mode) — decide via `scripts/uncle-dev-config.sh` (read `sdd_mode`). Keep the table/relationships/example-dialogue/flagged-ambiguities format from the draft (it's good).
4. **Wire into planning (the key step the principle cares about):**
   - `uncle-dev-spec-driven-development` Phase 0-LID and `uncle-dev-planning-and-task-breakdown`: if a glossary file exists, **load it as context** and instruct "use these canonical terms; flag any new term not in the glossary."
   - Reference the skill from CLAUDE.md **Define** phase and `.claude/commands/uncle-dev-spec.md`.
5. **Add required anatomy sections** the draft lacks: When to Use, Common Rationalizations ("we all know what an order is" → no, AI doesn't, and synonyms drift), Red Flags (same word two meanings; glossary stale vs code), Verification (glossary exists, terms appear in latest spec/PRD, zero unflagged synonyms).
6. **Audit guard:** ensure no direct `setup.yaml` reads — go through `uncle-dev-config.sh`.

**Outcome:** P3 ❌ → ✅. A scannable, planning-integrated ubiquitous language with a maintained file.

---

## Item B — Raise P2 to ✅: Grill mode → PRD

**Problem today:** `idea-refine/SKILL.md:62` caps questioning at "3-5 sharpening questions — no more." That's the opposite of "Grill Me" (walk every branch of the design tree, 40–100 questions, resolve dependencies one at a time → PRD). The adversarial *posture* exists (`idea-refine:106`), the *exhaustive interrogation mechanic* does not. No named "Grill → PRD" pipeline.

### Option B1 (recommended): a "grill" mode on `uncle-dev-acknowledge`
`uncle-dev-acknowledge` already owns "reach shared understanding before code" — the natural home.
1. Add an explicit **Grill phase**: a depth-first interrogation that traverses the design tree branch by branch (data model → states → edge cases → failure modes → non-functionals), resolving one dependency before opening the next.
2. **Lift the question cap** in grill mode — continue until each branch bottoms out (the "helpful adversary" stops when no unresolved dependency remains, not at a fixed count). Add a stop condition: "ask the user to confirm the synthesized understanding; only stop when they accept it."
3. **Emit a PRD** at the end by invoking the promoted `to-prd` flow (see below) → feeds directly into `uncle-dev-spec` (HLD/EARS).

### Option B2: keep `idea-refine` polite, add grill as a flag
Add `--grill` to `idea-refine` that overrides the 3-5 cap and switches Phase 1 into exhaustive tree-walking. Lighter touch, but `idea-refine` is about idea *quality*, not requirement *completeness* — acknowledge is the better fit.

### Promote `tmp/to-prd-SKILL.md`
Either way, formalize the PRD output: move `tmp/to-prd-SKILL.md` into the flow (a mode of `uncle-dev-spec` or a small `uncle-dev-to-prd`). Make it consume the glossary from Item A ("Use the project's domain glossary vocabulary throughout the PRD" is already line 12 of the draft — the dependency is pre-wired).

**Outcome:** P2 🟡 → ✅. A relentless, branch-walking interrogation that terminates in a PRD using the ubiquitous language.

---

## Item C — Raise P5 to ✅: Deep-module discipline (smallest, do first)

**Problem today:** "Deep vs shallow module" is correct but buried in a *reference file* (`design-an-interface-SKILL.md:87`), not enforced as a Build/Review principle.

### Steps
1. **Promote into `uncle-dev-api-and-interface-design/SKILL.md`:** add a top-level **"Module Depth"** section — define deep (small interface, large hidden complexity = good) vs shallow (large interface, thin body = avoid), with the AI-navigability rationale ("AI drowns in many tiny shallow blobs; deep modules with strict boundaries are navigable and testable at the interface").
2. **Add a review axis:** in `uncle-dev-code-review-and-quality` under *architecture*, add a depth check — "Flag shallow modules: interface surface ≈ implementation size, or a pass-through wrapper that hides nothing."
3. **Add a Red Flag** to `uncle-dev-incremental-implementation`: "Created a module whose interface is as complex as what it hides → reconsider the boundary."
4. Cross-link the existing `design-an-interface` "Design It Twice" reference from these sections (don't duplicate — reference, per project rule).

**Outcome:** P5 🟡 → ✅. Module depth becomes a first-class, checked principle across Build + Review.

---

## Item D — Framing fixes (P1, P6) — wording only

- **P1 (entropy):** Add one motivating line to `uncle-dev-code-review-and-quality` and/or `uncle-dev-dev-code-simplification` Overview: *"Bad code is more expensive than ever — a messy codebase blocks the AI from assisting. Resist software entropy: never make an isolated change that degrades the whole."* Names the Pragmatic Programmer framing the practice already follows.
- **P6 (gray-box risk tiering):** Add a note to `uncle-dev-design-architecture-docs` or `api-and-interface-design`: *"Tier by criticality — for critical modules, design and review the interface rigorously; for non-critical 'gray boxes', design the outer interface and delegate the implementation blob to the agent."* Makes the strategic-architect / tactical-programmer split explicit.

**Outcome:** P1 and P6 keep their ✅ practice and gain the explicit narrative.

---

## Integration map (so the new pieces actually get used)

```
idea-refine ──┐
              ├─▶ acknowledge (GRILL mode, exhaustive) ──▶ to-prd ──▶ uncle-dev-spec (HLD→LLD→EARS)
ubiquitous-   │                                              ▲              │
language ─────┴──────────────────────────────────────────────┘   (glossary loaded as context)
                                                                            │
                                                          api-and-interface-design (MODULE DEPTH)
                                                                            │
                                                          incremental-implementation / TDD
                                                                            │
                                                          code-review-and-quality (depth axis)
```

Touch points to update after building: `CLAUDE.md` (Define phase list), `.claude/commands/uncle-dev-spec.md`, `.claude/commands/uncle-dev-plan.md`, and the skills index.

---

## Suggested sequencing

1. **C** (deep modules) — small, self-contained, no new files.
2. **A** (ubiquitous language) — new skill from existing draft + planning wiring.
3. **B** (grill → PRD) — touches the most-used Define flow; do after A so the PRD can consume the glossary.
4. **D** (framing) — quick wording pass, can ride along with any of the above.
