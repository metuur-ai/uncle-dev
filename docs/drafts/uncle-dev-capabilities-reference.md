---
title: "Generating Great Documentation for uncle-dev with the Docs Skills"
description: "How to combine the ten documentation skills — docs-style, the four Diataxis types, draft-docs, ensure-docs, improve-doc, review-ai-writing, and humanize-beagle — into one pipeline that produces clear, human-sounding docs for uncle-dev."
---

# Generating Great Documentation for uncle-dev

This guide explains how to use the ten documentation skills together to produce high-quality docs for the uncle-dev skill suite. It covers what each skill does, how they fit into one pipeline, and copy-paste prompt samples for every stage.

## The ten skills at a glance

The skills split into three layers. You only ever *invoke* the workflow and editorial skills — the foundation skills load automatically underneath them.

| Layer | Skill | Role | You invoke it? |
|-------|-------|------|----------------|
| Foundation | `docs-style` | Core voice, tone, structure, LLM-friendly patterns | No — auto-loaded by every other skill |
| Foundation (Diataxis types) | `tutorial-docs` | Learning-oriented: teach a beginner by guided doing | No — loaded by orchestrators |
| Foundation (Diataxis types) | `howto-docs` | Task-oriented: get a specific goal done | No — loaded by orchestrators |
| Foundation (Diataxis types) | `reference-docs` | Information-oriented: precise lookup (params, APIs) | No — loaded by orchestrators |
| Foundation (Diataxis types) | `explanation-docs` | Understanding-oriented: why it works this way | No — loaded by orchestrators |
| Workflow | `draft-docs` | Generate a first-draft Reference or How-To from code → `docs/drafts/`, then `--publish` | Yes |
| Workflow | `ensure-docs` | Audit doc coverage across the codebase, report gaps, generate missing docs | Yes |
| Workflow | `improve-doc` | Classify an existing doc by Diataxis type and refine it section by section | Yes |
| Editorial | `review-ai-writing` | Detect AI-sounding writing patterns and write findings to `.beagle/ai-writing-review.json` | Yes |
| Editorial | `humanize-beagle` | Apply the review findings to make text sound human | Yes |

### The Diataxis model these skills enforce

Every doc should be exactly **one** of four types. Mixing them is the most common reason docs feel muddled. Decide the type *before* you write.

| Type | Reader's mindset | uncle-dev example |
|------|------------------|-------------------|
| **Tutorial** | "Teach me, I'm new." | "Your first feature with uncle-dev: idea → spec → ship" |
| **How-To** | "I have a goal, show me the steps." | "How to run a spec-driven change with `/uncle-dev-spec`" |
| **Reference** | "I need the exact details." | "uncle-dev skills and commands reference" |
| **Explanation** | "Why is it built this way?" | "Why uncle-dev separates HLD → LLD → EARS → code" |

## The pipeline

```
                  ┌─────────────────────────────────────────────┐
                  │  docs-style  (loaded under everything)       │
                  └─────────────────────────────────────────────┘
                          │
   ┌──────────────┐   ┌───┴────────┐   ┌──────────────┐
   │ ensure-docs  │──▶│ draft-docs │──▶│ improve-doc  │
   │ find gaps    │   │ first pass │   │ refine       │
   └──────────────┘   └────────────┘   └──────────────┘
                          │
                          ▼
   ┌────────────────────┐     ┌──────────────────┐
   │ review-ai-writing  │────▶│ humanize-beagle  │   editorial pass
   │ detect AI patterns │     │ apply fixes      │
   └────────────────────┘     └──────────────────┘
                          │
                          ▼
                  draft-docs --publish  (move to final + update nav)
```

Read it left to right: find what's missing, draft it, refine it, strip the AI tone, publish.

## Step-by-step workflow for uncle-dev docs

### Step 1 — Find the gaps (`ensure-docs`)

Start by learning what's undocumented. `ensure-docs` detects the languages in the repo, runs a coverage verifier per language, and produces a gap report. Run it report-only first so nothing gets written before you've reviewed it.

**Prompt sample:**

```text
Invoke the ensure-docs skill with --report-only on the skills/ directory.
I want a coverage report of which uncle-dev skills and commands lack
documentation, grouped by severity. Don't generate anything yet.
```

The report tells you which docs to create and what type each should be.

### Step 2 — Draft new docs (`draft-docs`)

`draft-docs` generates Reference or How-To drafts directly from code analysis. It always loads `docs-style` plus the matching type skill, writes to `docs/drafts/`, and never publishes straight to the final location.

It only auto-detects **Reference** and **How-To**. For **Tutorial** or **Explanation** docs, write them directly while explicitly asking Claude to load that type skill (see Step 2b).

**Prompt sample — Reference doc:**

```text
Invoke the draft-docs skill: "Document the uncle-dev skill suite as an
API-style reference — every skill and slash command, what it does, its
phase, and when to use it." Treat it as a Reference doc.
```

**Prompt sample — How-To doc:**

```text
Invoke the draft-docs skill: "How to run a spec-driven change in uncle-dev
using /uncle-dev-spec then /uncle-dev-plan then /uncle-dev-build."
This is a How-To guide with prerequisites, numbered steps, and a
verification section.
```

### Step 2b — Draft Tutorial or Explanation docs (type skills directly)

`draft-docs` won't pick these, so name the skill explicitly. The orchestration is the same: `docs-style` + the type skill.

**Prompt sample — Tutorial:**

```text
Load the tutorial-docs and docs-style skills, then write a tutorial:
"Your first feature with uncle-dev." A complete beginner goes from a
one-line idea to a shipped change. One clear path, a visible result after
every step, no alternatives or detours. Save it to docs/drafts/.
```

**Prompt sample — Explanation:**

```text
Load the explanation-docs and docs-style skills, then write an explanation
doc: "Why uncle-dev separates HLD → LLD → EARS specs → tests → code."
Cover the problem it solves, the historical context, and the trade-offs.
This is for reading away from the keyboard — understanding, not steps.
Save it to docs/drafts/.
```

### Step 3 — Refine existing docs (`improve-doc`)

For docs that already exist (including the drafts you just made), `improve-doc` reads the file, classifies each section by Diataxis type, flags issues, and walks you through refining section by section. It's interactive — you approve, skip, or modify each change.

**Prompt sample:**

```text
Invoke the improve-doc skill on docs/drafts/uncle-dev-capabilities-reference.md.
Classify each section, flag anything that mixes Diataxis types or violates
docs-style, and propose fixes section by section. I'll approve each one.
```

### Step 4 — Detect AI-sounding writing (`review-ai-writing`)

Before publishing, scan for the tells that make text read like a machine wrote it — inflated language, filler, tautological docstrings, robotic cadence. The skill writes findings to `.beagle/ai-writing-review.json` so the next step can act on them.

**Prompt sample:**

```text
Invoke the review-ai-writing skill on docs/drafts/. Flag inflated language,
filler phrases, tautological descriptions, and robotic tone. Write the
findings file so I can run humanize-beagle next.
```

### Step 5 — Humanize (`humanize-beagle`)

`humanize-beagle` applies the review findings, classifying each fix as safe or risky. Run `--dry-run` first to preview before it touches anything. It stashes uncommitted changes for safety and validates each file after editing.

**Prompt sample — preview:**

```text
Invoke the humanize-beagle skill with --dry-run. Show me every fix from the
review-ai-writing findings before changing any file.
```

**Prompt sample — apply:**

```text
Invoke the humanize-beagle skill. Apply the safe fixes from the review,
and list the risky ones for me to approve individually.
```

### Step 6 — Publish (`draft-docs --publish`)

Once a draft is clean, publish it. `draft-docs --publish` moves the file to its final section, updates the navigation config, and removes the draft.

**Prompt sample:**

```text
Invoke the draft-docs skill with
--publish docs/drafts/uncle-dev-capabilities-reference.md.
Put it under the Reference section and update the navigation.
```

## A full example: documenting uncle-dev end to end

Run these in order, reviewing the output at each gate.

```text
1. Invoke ensure-docs with --report-only on skills/ — show me the doc gaps.

2. Invoke draft-docs: "Reference of every uncle-dev skill and slash command,
   organized by phase (Define, Plan, Build, Verify, Review, Ship, Capture)."

3. Load tutorial-docs + docs-style, write "Your first feature with uncle-dev"
   tutorial to docs/drafts/.

4. Load explanation-docs + docs-style, write "Why uncle-dev uses
   HLD → LLD → EARS → code" to docs/drafts/.

5. Invoke improve-doc on each draft in docs/drafts/, one at a time.

6. Invoke review-ai-writing on docs/drafts/.

7. Invoke humanize-beagle --dry-run, then humanize-beagle to apply.

8. Invoke draft-docs --publish for each finished draft.
```

## Choosing the right skill quickly

| You want to… | Use |
|--------------|-----|
| Know what's undocumented | `ensure-docs` |
| Create a Reference or How-To from code | `draft-docs` |
| Create a Tutorial or Explanation | `tutorial-docs` / `explanation-docs` + `docs-style` |
| Fix an existing doc | `improve-doc` |
| Check if text sounds AI-generated | `review-ai-writing` |
| Rewrite AI text to sound human | `humanize-beagle` |
| Get the writing fundamentals right | `docs-style` (always on) |

## Rules worth remembering

- **One Diataxis type per document.** Decide the type before writing; mixing types is the top cause of confusing docs.
- **`docs-style` is always underneath.** You never invoke it directly, but it governs voice (second person, active voice, concise), structure, and consistency in every doc.
- **`draft-docs` only auto-detects Reference and How-To.** For Tutorial and Explanation, name the type skill explicitly.
- **Drafts live in `docs/drafts/` until published.** Nothing goes to a final location until `--publish`.
- **Review before humanize.** `humanize-beagle` consumes the `.beagle/ai-writing-review.json` that `review-ai-writing` produces — run them in that order.
- **Preview destructive steps.** Use `--dry-run` with `humanize-beagle` and `--report-only` with `ensure-docs` before committing changes.
