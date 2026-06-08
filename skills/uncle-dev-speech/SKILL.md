---
name: uncle-dev-speech
description: Strips AI writing tells from human-facing prose so uncle-dev's documents read like a person wrote them. Use when finalizing any prose artifact such as research docs, ADRs, HLD/LLD narrative, EARS proposal/design text, knowledge-capture entries, handoff docs, release notes, PR descriptions, or commit bodies. Use when prose sounds generic, hedged, or "AI-flavored," when a doc is full of em dashes, adverbs, throat-clearing openers, or false-agency phrasing, or before writing any document another engineer will read cold.
---

# Uncle Dev Speech

## Overview

uncle-dev produces prose at almost every phase — research syntheses, ADRs, design narratives, knowledge captures, handoffs, release notes, PR bodies. None of that prose is style-checked by default, so it drifts toward predictable AI patterns: throat-clearing openers, binary contrasts, passive voice, adverb stacks, em-dash drama, and inanimate things performing human verbs. This skill runs a deterministic edit-and-score pass that removes those tells before the document is written to disk or surfaced to a human.

It vendors the rule set from the MIT-licensed [`stop-slop`](https://github.com/hvpandya) skill by Hardik Pandya. The catalogs live in `references/`; this SKILL.md is the process that applies them.

## When to Use

Run this as a **final pass** on human-facing prose, after the content is correct and before the file is written:

- Research docs (`.uncle-dev/research/*.md`) — `uncle-dev-research`
- ADRs and decision records — `uncle-dev-documentation-and-adrs`, `uncle-dev-acknowledge`
- HLD / LLD narrative sections — `uncle-dev-design-architecture-docs`
- Proposal / design prose in OpenSpec changes — `uncle-dev-spec-driven-development`
- Knowledge-capture entries (`.uncle-dev/learns/*.md`) — `uncle-dev-knowledge-capture`
- Handoff docs (`.devlocal/handoffs/*.md`) — `uncle-dev-wrap`
- Release notes and launch comms — `uncle-dev-shipping-and-launch`
- PR descriptions and commit bodies — `uncle-dev-git-workflow-and-versioning`

**NOT for:** code, code comments, EARS requirement clauses themselves (the formal `WHEN/THE SYSTEM SHALL` syntax is fixed and must not be "de-slopped"), `@spec` annotations, config files, CLI output, structured tables, or test names. Apply it to the *narrative* sections of a document, never to syntax with a required shape.

## Core Process

Treat this as a mutating process with a `validate → fix → re-validate` loop. The validator is the 5-dimension score; the gate is **35/50**.

```
1. Isolate prose    → which paragraphs are narrative (not code/tables/EARS)?
2. Quick-scan        → run the 12 Quick Checks below, mark every hit
3. Fix by category   → load the relevant references/ file, rewrite each hit
4. Score             → rate the 5 dimensions, sum them
5. Gate              → ≥35/50 AND zero hard-rule violations? ship. else → step 3
```

### Step 1 — Isolate prose

Scan the artifact and select only the narrative spans: overview/context/rationale paragraphs, summaries, descriptions. Leave fenced code, tables, EARS clauses, frontmatter, and command snippets untouched.

### Step 2 — Quick scan

Walk the text once and flag every hit. These are the highest-frequency tells:

- Any adverb (`-ly`, plus `really`, `just`, `simply`, `actually`, `genuinely`)? Kill it.
- Any passive voice? Find the actor, make them the subject.
- Inanimate thing doing a human verb ("the decision emerges", "the data tells us")? Name the person.
- Sentence starts with a Wh- word (What/When/Why/How)? Restructure.
- Any "here's what / here's the thing" throat-clearing? Cut to the point.
- Any "not X, it's Y" contrast? State Y directly.
- Three consecutive sentences of similar length? Break one.
- Paragraph ends with a punchy one-liner? Vary it.
- **Em dash anywhere? Remove it.** (commas or periods instead)
- Vague declarative ("The implications are significant")? Name the specific thing.
- Narrator-from-a-distance ("Nobody designed this")? Put the reader in the scene.
- Meta-joiner ("The rest of this doc explains…")? Delete; let the doc move.

### Step 3 — Fix by category

Load the catalog that matches the hit, then rewrite:

- **Phrases** — throat-clearing, emphasis crutches, business jargon, adverbs, meta-commentary, vague declaratives. Load `references/phrases.md` when you hit a banned word or phrase and need the replacement.
- **Structures** — binary contrasts, negative listing, dramatic fragmentation, rhetorical setups, false agency, narrator-from-a-distance, passive voice, Wh- starters, rhythm patterns. Load `references/structures.md` when a *sentence shape* is the problem, not a single word.
- **Worked examples** — load `references/examples.md` when you need to see a full before/after transformation to calibrate how aggressive to be.

The 8 governing rules: cut filler, break formulaic structures, active voice with a human subject, be specific (name the thing), put the reader in the room, vary rhythm (two items beat three, no em dashes), trust the reader (skip softening), cut quotables.

### Step 4 — Score

Rate 1–10 on each dimension, then sum:

| Dimension | Question |
|-----------|----------|
| Directness | Statements, or announcements? |
| Rhythm | Varied, or metronomic? |
| Trust | Respects the reader's intelligence? |
| Authenticity | Sounds like a human wrote it? |
| Density | Anything left cuttable? |

### Step 5 — Gate

Ship only when **sum ≥ 35/50** AND every hard rule passes (see Red Flags). Below 35, or any hard-rule hit, return to Step 3. Do not declare the prose done until both conditions hold.

## Gotchas

- **EARS clauses are not prose.** `WHEN <trigger> THE SYSTEM SHALL <response>` is a fixed grammar. Rewriting it for "rhythm" breaks `uncle-dev-spec-scan` and `@spec` traceability. Edit the surrounding narrative, never the clause.
- **Commit subject lines have their own convention.** This repo ends commit messages with a `Co-Authored-By:` trailer and uses imperative subjects. Apply speech only to the commit *body* prose, and keep trailers and the imperative subject intact.
- **The em-dash rule is absolute here.** uncle-dev docs use em dashes heavily by habit; this skill removes all of them from narrative prose. Use commas or periods.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The content is correct, style doesn't matter." | These docs are read cold by other engineers and future agents. Slop-laden prose buries the signal and erodes trust in the doc. |
| "It's just an internal handoff / scratch note." | Handoffs are the highest-stakes prose you write — a fresh agent acts on them with no other context. Density and directness matter most there. |
| "Removing every adverb is too aggressive." | The rule is deliberate. Adverbs are where AI emphasis-padding hides. Cut first; if a sentence genuinely needs one back, that is the rare exception, not the default. |
| "Em dashes are fine, everyone uses them." | They are the single loudest AI tell in this corpus. The rule is zero in narrative prose — no judgment call. |
| "I'll de-slop the EARS specs too while I'm here." | EARS syntax is load-bearing. Touching it breaks spec scanning and annotations. Narrative only. |
| "Scoring is overhead, the edits are obviously better." | The score is the gate that stops 'good enough.' Without it you stop at the first plausible draft — exactly the AI failure mode this skill exists to break. |

## Red Flags

Hard rules — any single hit fails the gate regardless of score:

- An em dash survives in narrative prose.
- A sentence has no human (or "you") as its actor where one exists.
- An inanimate noun performs a human verb ("the report concludes", "the bet dies").
- A paragraph opens with throat-clearing ("Here's the thing", "It turns out").
- A "not X, it's Y" / "isn't X, it's Y" contrast remains.

Soft signals to watch during review:

- Three-item lists everywhere (two usually beats three).
- Every paragraph ends on a punchline.
- Lazy extremes ("always", "never", "everyone") doing vague work.
- Business jargon ("deep dive", "game-changer", "circle back", "lean into").

## Verification

After the pass, confirm:

- [ ] Ran the 12 Quick Checks against every narrative paragraph
- [ ] Zero em dashes remain in prose
- [ ] Every sentence has an actor; no inanimate human-verb constructions
- [ ] No throat-clearing openers or "not X, it's Y" contrasts remain
- [ ] Adverbs cut (any survivor is a deliberate, justified exception)
- [ ] Scored all 5 dimensions; **sum ≥ 35/50**
- [ ] EARS clauses, code, tables, frontmatter, and commit trailers left untouched
