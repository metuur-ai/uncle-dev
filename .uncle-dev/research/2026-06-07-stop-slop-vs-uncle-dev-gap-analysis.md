# Gap Analysis: stop-slop vs uncle-dev

**Date:** 2026-06-07
**Question:** Analyze the gap of skills, rules, and commands in `/Users/javierbenavides/others/ai-agents/stop-slop-main` against uncle-dev.
**Scope:** Documents what each package contains and where they overlap or diverge. This is a documentation pass, not a recommendation.

---

## TL;DR

The two packages do not compete. They sit in different domains:

- **stop-slop** is a single-purpose **prose-quality** skill: one `SKILL.md` plus three reference files that strip AI writing tells from text.
- **uncle-dev** is a full **engineering-lifecycle framework**: 40 skills, 23 commands, 9 agents, 14 hooks, a rules file, and a config system covering Define → Build → Verify → Review → Ship → Capture.

There is exactly one real gap, and it runs one direction: **uncle-dev generates large amounts of prose (research docs, ADRs, HLD/LLD, handoffs, knowledge captures, EARS spec descriptions) but has zero writing-quality enforcement.** stop-slop covers precisely that hole. In the other direction there is no gap to speak of — stop-slop is intentionally a single skill and was never meant to carry engineering machinery.

---

## Inventory: stop-slop

Located at `/Users/javierbenavides/others/ai-agents/stop-slop-main`. Total footprint: 7 files, ~440 lines.

| Component | Count | Files |
|-----------|-------|-------|
| Skills | 1 | `SKILL.md` (`name: stop-slop`) |
| Reference files | 3 | `references/phrases.md`, `references/structures.md`, `references/examples.md` |
| Commands | 0 | — |
| Rules files | 0 | — |
| Hooks | 0 | — |
| Agents | 0 | — |
| Config | 0 | — |
| Meta | 3 | `README.md`, `CHANGELOG.md`, `LICENSE` |

**Domain:** prose writing quality. Author: Hardik Pandya. License: MIT.

**What the skill does** (`SKILL.md:13-30`): 8 core rules — cut filler phrases, break formulaic structures, active voice, be specific, put the reader in the room, vary rhythm, trust readers, cut quotables. Plus a 12-item "Quick Checks" list (`SKILL.md:33-46`) and a 5-dimension scoring rubric (Directness, Rhythm, Trust, Authenticity, Density; revise below 35/50) at `SKILL.md:48-60`.

**Reference depth:**
- `phrases.md` — banned phrase catalog: throat-clearing openers, emphasis crutches, a business-jargon replacement table, an adverb kill-list, meta-commentary, performative emphasis, vague declaratives.
- `structures.md` — banned structural patterns: binary contrasts, negative listing, dramatic fragmentation, rhetorical setups, false agency (inanimate things doing human verbs), narrator-from-a-distance, passive voice, Wh- sentence starters, rhythm/word patterns.
- `examples.md` — 5 before/after transformations.

**Format note:** stop-slop's frontmatter uses `metadata: { trigger, author }`. It has no `When to Use / Process / Red Flags / Verification` sections — it is a rules-and-references skill, not a process skill.

---

## Inventory: uncle-dev

Located at `/Users/javierbenavides/others/ai-agents/production-grade-agent-skills`.

| Component | Count | Notes |
|-----------|-------|-------|
| Skills | 40 | `skills/uncle-dev-*` + `uncle-senior` |
| Commands | 23 | `.claude/commands/uncle-dev-*.md` + `uncle-senior.md` |
| Agents | 9 | reviewers, security auditor, test engineer, graph analyst, repo-research, synthesizer, uncle-lead/po/senior personas |
| Hooks | 14 | session-start, guards (destructive, openspec, spec-coherence, pre-commit), nudges (knowledge-capture, wrap), notifiers, simplify-ignore |
| Rules | 1 | `AGENT_RULES.md` (203 lines) — safety, delegation, memory, scout-not-explore, graphify-first |
| Config | 1 | `scripts/uncle-dev-config.sh` over `.agents/uncle-dev-setup.yaml` |

**Domain:** software engineering lifecycle. Skills are organized by phase (per `CLAUDE.md`):
Define · Brownfield · Evaluate · Plan · Build · Verify · Review · Ship · Capture · Handoff · Maintain.

**Skill format** (per `CLAUDE.md` conventions): every skill has Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification. Frontmatter is `name` + `description` where the description starts third-person then states triggers ("Use when...").

---

## Overlap map

| Dimension | stop-slop | uncle-dev | Overlap? |
|-----------|-----------|-----------|----------|
| Prose / writing quality | **Yes** (core purpose) | **No** | None — uncle-dev has no equivalent |
| Documentation *structure* (ADRs, HLD/LLD templates) | No | Yes (`documentation-and-adrs`, `design-architecture-docs`) | Adjacent, not overlapping — uncle-dev defines *what goes in a doc*, stop-slop defines *how the sentences read* |
| Code lifecycle (spec, plan, build, test, review, ship) | No | Yes (35+ skills) | None |
| Rules / hooks / agents / config | No | Yes | None |
| Scoring rubric | Yes (prose: 5 dims) | Yes (e.g. code-review axes) | Conceptually similar device, different subject |

Searching uncle-dev for any prose-quality coverage (`anti-slop`, `adverb`, `passive voice`, `throat-clear`, `em dash`, `ai writing`, `writing style`) returns only two incidental hits — `uncle-dev-acknowledge/note-schema.yaml` and `uncle-senior/references/duck-reference.md` — neither is a writing-style skill. uncle-dev has **no** prose-quality skill.

---

## The gap (uncle-dev ← stop-slop)

uncle-dev produces prose at almost every phase, and none of it is style-checked:

| uncle-dev artifact | Generated by | Style-checked today? |
|--------------------|--------------|----------------------|
| Research docs (`.uncle-dev/research/`) | `uncle-dev-research` | No |
| ADRs / decision records | `uncle-dev-documentation-and-adrs` | No |
| HLD / LLD / arrow docs | `uncle-dev-design-architecture-docs` | No |
| EARS spec descriptions | `uncle-dev-spec-driven-development` | No |
| Knowledge-capture entries (`.uncle-dev/learns/`) | `uncle-dev-knowledge-capture` | No |
| Handoff docs (`.devlocal/handoffs/`) | `uncle-dev-wrap` | No |
| PR descriptions / commit messages | `uncle-dev-git-workflow-and-versioning` | No |

This is the substantive finding: stop-slop's domain is the one engineering-adjacent surface uncle-dev leaves uncovered. The two are complementary, not redundant.

## The reverse direction (stop-slop ← uncle-dev)

stop-slop is missing everything uncle-dev has — commands, rules, hooks, agents, config, and all 40 engineering skills. This is not a defect: stop-slop is a deliberately scoped single skill distributed for drop-in use (Claude Code skill folder, Projects knowledge upload, or system-prompt paste, per its README). It carries no framework ambitions, so "gaps" here are out of scope by design.

---

## Format / convention differences

If stop-slop were ever absorbed into uncle-dev, these are the concrete deltas to reconcile (documented, not recommended):

1. **Frontmatter** — stop-slop uses `metadata: { trigger, author }`; uncle-dev uses `name` + trigger-prefixed `description`, no `metadata` block.
2. **Section anatomy** — stop-slop lacks the mandated `When to Use / Process / Common Rationalizations / Red Flags / Verification` sections uncle-dev requires of every skill.
3. **Naming** — uncle-dev namespaces every skill `uncle-dev-*`; stop-slop is bare `stop-slop`.
4. **No command/hook wiring** — stop-slop has no slash command, no phase placement, and no entry in `CLAUDE.md`'s "Skills by Phase" map.

---

## Evidence index

- stop-slop skill rules: `stop-slop-main/SKILL.md:13-60`
- stop-slop phrase catalog: `stop-slop-main/references/phrases.md`
- stop-slop structure catalog: `stop-slop-main/references/structures.md`
- uncle-dev skill list: `skills/` (40 dirs)
- uncle-dev command list: `.claude/commands/` (23 files)
- uncle-dev rules: `AGENT_RULES.md` (203 lines)
- uncle-dev conventions: `CLAUDE.md` ("Skills by Phase", "Conventions")
- Absence of prose coverage: grep for writing-quality terms across `skills/`, `docs/`, `AGENT_RULES.md` → only 2 incidental, non-style hits
