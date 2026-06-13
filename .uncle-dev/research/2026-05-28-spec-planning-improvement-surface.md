# Research: Spec & Planning Improvement Surface

**Date:** 2026-05-28  
**Question:** What is the current state of uncle-dev's spec and planning phases, and what surfaces exist for improvement?  
**Reference artifact:** `tmp/premortem-SKILL.md` (pre-mortem skill candidate)

---

## 1. Existing Spec Skills (What IS)

### Skills & Commands

| Artifact                           | Path                                                 | Role                                        | Primary Output              |
| ---------------------------------- | ---------------------------------------------------- | ------------------------------------------- | --------------------------- |
| uncle-dev-spec-driven-development  | `skills/uncle-dev-spec-driven-development/SKILL.md`  | Entry point; routes to lid-ears or openspec | HLD/LLD/EARS docs           |
| uncle-dev-design-architecture-docs | `skills/uncle-dev-design-architecture-docs/SKILL.md` | Authors HLD/LLD; manages segments           | HLD, LLDs, segment registry |
| uncle-dev-spec-annotations         | `skills/uncle-dev-spec-annotations/SKILL.md`         | `@spec` traceability; scanner/graph scripts | Code/test annotations       |
| uncle-dev-spec-scan                | `.claude/commands/uncle-dev-spec-scan.md`            | Validates `@spec` coherence                 | Orphan/missing report       |
| uncle-dev-spec-graph               | `.claude/commands/uncle-dev-spec-graph.md`           | Builds graph artifacts                      | JSON/Mermaid/HTML/report    |
| uncle-dev-design-docs              | `.claude/commands/uncle-dev-design-docs.md`          | Scaffolds HLD/LLD/arrows                    | Template files              |

### Spec Workflow Flow

```
HLD → LLD → EARS specs → @spec (code/tests) → scan → graph
```

**Hard Gate (Phase 5 of uncle-dev-spec-driven-development:132–138):**  
User must explicitly say YES before downstream work proceeds. No bypass.

**Auto-chain:** After YES, `/uncle-dev-plan` is invoked in the same turn (SKILL.md:156).

### Spec Output Artifacts

- `docs/hld/<slug>.md` — product intent
- `docs/lld/<slug>.md` — system-level approach
- `docs/ears/<slug>.md` — EARS requirements (lid-ears mode)
- `docs/specs/<segment>-specs.md` — durable EARS IDs with `[x]`/`[ ]`/`[D]` markers
- `docs/arrows/index.yaml` — segment registry
- `docs/arrows/<segment>.md` — per-segment crosslink doc
- `openspec/changes/<change-id>/proposal.md` + `design.md` (openspec mode)

---

## 2. Existing Planning Skills (What IS)

### Skills & Commands

| Artifact                              | Path                                                    | SDD Modes                   | Primary Output                    |
| ------------------------------------- | ------------------------------------------------------- | --------------------------- | --------------------------------- |
| uncle-dev-planning-and-task-breakdown | `skills/uncle-dev-planning-and-task-breakdown/SKILL.md` | openspec (lid-ears via cmd) | `tasks.md`, `execution.md`        |
| uncle-dev-acknowledge                 | `skills/uncle-dev-acknowledge/SKILL.md`                 | openspec (lid-ears → ADR)   | `openspec/acknowledge/<scope>.md` |
| uncle-dev-next-task                   | `skills/uncle-dev-next-task/SKILL.md`                   | openspec (lid-ears via cmd) | Handoff to build/test/review/ship |
| uncle-dev-incremental-implementation  | `skills/uncle-dev-incremental-implementation/SKILL.md`  | both                        | Series of commits                 |

### Planning Workflow Flow

```
spec → /uncle-dev-plan → /uncle-dev-acknowledge (gate) → /uncle-dev-next-task → /uncle-dev-build → ... → /uncle-dev-ship
```

### Gates in Planning

**Acknowledge gate (uncle-dev-next-task SKILL.md:291–301):** Non-bypassable. If any `<scope>.md` has `### D<N>` with `status: pending`, the story is blocked. No `--ignore-acknowledgements` flag exists.

**Conflict-resolution gate (uncle-dev-next-task SKILL.md:271–278):** Fires when scratchpad and `tasks.md` disagree. Halts resolution; must follow `conflict-resolution.md`.

**Parallel-safe ready set:** Only stories with satisfied deps, uncontended mutex, no active lock enter the ready set.

### Planning Output Artifacts

- `openspec/changes/<id>/tasks.md` — story-level breakdown (openspec mode)
- `openspec/changes/<id>/execution.md` — phase ordering, cross-story coordination
- `docs/tasks/<slug>.md` — lid-ears mode equivalent
- `.devlocal/<user>/<story-id>/scratchpad.md` — private (gitignored)
- `.devlocal/_locks/<change-id>/<story-id>.lock` — parallel-safe claim locks

---

## 3. What Currently Happens Before Spec (Pre-Spec Surface)

### Current pre-spec skills

| Skill                 | Path                                    | Role                                                           |
| --------------------- | --------------------------------------- | -------------------------------------------------------------- |
| uncle-dev-research    | `skills/uncle-dev-research/SKILL.md`    | Documentarian scout; writes research to `.uncle-dev/research/` |
| uncle-dev-idea-refine | `skills/uncle-dev-idea-refine/SKILL.md` | Idea exploration before spec                                   |
| uncle-dev-feature-map | `skills/uncle-dev-feature-map/SKILL.md` | Feature surface mapping                                        |

From research `2026-05-17-uncle-domain-companion-exploration.md:§3`:

> "Product/domain reasoning currently lives only in `uncle-dev-idea-refine`, `uncle-dev-feature-map`, `uncle-dev-research`"

**No skill exists today that explicitly:**

- Imagines failure before spec is locked
- Surfaces hidden risks in the proposed architecture
- Produces a risk-prioritization artifact before entering the spec phase

---

## 4. The Premortem Skill Candidate (`tmp/premortem-SKILL.md`)

**File:** `tmp/premortem-SKILL.md` (lines 1–67)

**Status:** Candidate skill — exists in `tmp/`, not yet placed in `skills/`.

**Definition:** Pre-mortem analysis that imagines a plan has failed, then works backward to identify causes and preventions.

**Output format defined in the file:**

- "The Plan" — success criteria summary
- "Time Jump" — vivid failure scene
- "What Went Wrong" — 8–12 failure causes across Execution / External / People / Technical / Assumptions
- "Risk Prioritization" — Likelihood × Impact table
- "Top 5 Risks & Mitigations" — Early warning signs, prevention, mitigation, owner
- "Pre-Mortem Insights" — What wasn't obvious before
- "Revised Confidence" — Post-analysis confidence level

**Trigger condition (from frontmatter):** "Use before launches, major decisions, or risky initiatives to surface hidden risks."

**Designated `user-invocable: true`** — means it is intended as a `/premortem` slash command.

---

## 5. Historical Context (`.uncle-dev/` State)

### `.uncle-dev/learns/`

**Status: Empty.** Directory exists, no files captured.

### `.uncle-dev/research/` — 4 files

| File                                                                | Date       | Topic                                                     | Spec/Plan Relevance                                              |
| ------------------------------------------------------------------- | ---------- | --------------------------------------------------------- | ---------------------------------------------------------------- |
| `2026-05-17-uncle-domain-companion-exploration.md`                  | 2026-05-17 | Uncle Domain companion mapping                            | §5: maps all 6 spec methodologies + artifact paths               |
| `2026-05-17-companion-modes-extended-exploration.md`                | 2026-05-17 | Companion modes extended (62-row gap table)               | §2.1–2.2: spec framework matrix; Graphify config gaps            |
| `2026-05-28-intent-layer-skill-vs-uncle-dev-context-engineering.md` | 2026-05-28 | Intent-layer vs. uncle-dev-context-engineering comparison | Token-threshold table missing; state-detect workflow missing     |
| `2026-05-28-uncle-dev-terminal-notifications.md`                    | 2026-05-28 | Terminal notification wait points                         | Lines 107–119: 8 wait points enumerated, 2 are plan-review gates |

### Notable findings from research files

**From `companion-modes-extended-exploration.md:232–242`:**  
Scanner output (`scan-spec-coherence.py`) uses engineering-coded vocabulary (`ORPHAN`, `HELPER ANNOTATION`, `MALFORMED ID`). No PM-readable format exists.

**From `companion-modes-extended-exploration.md:512–523`:**  
L1↔L2 drift mechanisms documented (ORPHAN, MISSING CODE, MISSING TEST). L3 (platform-actual behavior comparison) absent.

**From `uncle-dev-terminal-notifications.md:107–119`:**  
Two spec/plan gates that require user action — Phase 5 spec confirmation hard gate and plan-review gate — currently use "wait silently" pattern with no external signal mechanism.

---

## 6. Workflow Rules from CLAUDE.md

`CLAUDE.md:91–94`:

```
- Run `/uncle-dev-spec` before any non-trivial feature
- Run `/uncle-dev-plan` after spec, before coding
- Check `.agents/uncle-dev-setup.yaml` for project-specific overrides and sdd_mode
```

`CLAUDE.md:85–87`:

```
- Architecture flows HLD → LLD → EARS specs → tests → code
- Code and tests reference durable behavior via `@spec` annotations
- OpenSpec artifacts tracked in openspec/changes/<change-id>/
```

---

## 7. Surfaces Where the Premortem Skill Could Insert

Based on the current workflow topology, three insertion points exist where a premortem skill would have access to a complete-enough plan to analyze:

| Insertion Point                                    | What's available                              | Phase                |
| -------------------------------------------------- | --------------------------------------------- | -------------------- |
| After HLD is written, before LLD                   | HLD goals, non-goals, stakeholders            | Early spec (Phase 2) |
| After EARS specs written, before Phase 5 hard gate | Full HLD + LLD + EARS requirements            | Pre-lock (Phase 4→5) |
| After `/uncle-dev-plan` produces `tasks.md`        | Full spec + story breakdown + execution order | Pre-build            |

The Phase 5 hard gate in `uncle-dev-spec-driven-development:132–138` is the current "review and confirm" checkpoint. It presents docs and asks for YES. No risk-discovery step happens before this gate.

---

## 8. What IS vs. What the Premortem Covers

| Premortem category                        | Current uncle-dev equivalent       | File:line                                           |
| ----------------------------------------- | ---------------------------------- | --------------------------------------------------- |
| Execution failure modes                   | Not captured                       | —                                                   |
| External failure modes                    | Not captured                       | —                                                   |
| People failure modes                      | Not captured                       | —                                                   |
| Technical failure modes                   | Partially: LLD constraints section | `uncle-dev-design-architecture-docs SKILL.md:30–52` |
| Assumption failures                       | Not captured                       | —                                                   |
| Risk prioritization (Likelihood × Impact) | Not captured                       | —                                                   |
| Early warning signs                       | Not captured                       | —                                                   |
| Owner assignment for mitigations          | Not captured                       | —                                                   |

The only current risk-adjacent artifact is the LLD "Constraints" and "Key Decisions" sections — which are factual, not failure-imagining.

---

## Summary

**What IS:**

- Spec phase: 3 skills + 5 commands; HLD→LLD→EARS→@spec chain; one hard gate (Phase 5 YES)
- Planning phase: 4 skills + 3 commands; tasks.md→execution.md→acknowledge gate→next-task→build chain
- Pre-spec: 3 skills (research, idea-refine, feature-map); no risk-discovery step
- Historical: `.uncle-dev/learns/` empty; 4 research files covering companion modes and context engineering

**What the premortem candidate covers that has no current equivalent:**

- Failure-scenario generation (8–12 modes across 5 categories)
- Likelihood × Impact risk matrix
- Early warning signs per risk
- Owner assignment for mitigations
- Pre-lock insight surfacing before Phase 5 hard gate fires

**Key file references:**

- Current spec hard gate: `skills/uncle-dev-spec-driven-development/SKILL.md:132–138`
- Current plan output: `skills/uncle-dev-planning-and-task-breakdown/SKILL.md:192–213`
- Premortem candidate: `tmp/premortem-SKILL.md:1–67`
- Acknowledge gate: `skills/uncle-dev-next-task/SKILL.md:291–301`
- Workflow rules: `CLAUDE.md:91–94`
