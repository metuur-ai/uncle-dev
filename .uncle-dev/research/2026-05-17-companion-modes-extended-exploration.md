# Companion Modes Extended Exploration — Uncle Domain / Uncle Framework / Product Mode Agent

**Date:** 2026-05-17
**Author:** Claude (uncle-dev-research)
**Status:** Documentation of current state. No recommendations.
**Scope:** Extends `.uncle-dev/research/2026-05-17-uncle-domain-companion-exploration.md` to cover three companion-mode pillars now under exploration: **Uncle Domain**, **Uncle Framework**, and **Product Mode Agent** — plus the user's stated **reactive-invocation** constraint and the **three-context-layer** routing requirement.

This document maps what is already in this repo, with file:line citations. It does not propose how to close gaps. Where the prior research doc already covered a finding, this doc references the section rather than restating it.

---

## 1. The Research Question

The user is exploring three specialized companion modes that extend uncle-dev beyond pure code authoring:

1. **Uncle Domain** — product/domain/business expert that uses spec frameworks (OpenSpec, SpecKit, EARS, LID) to analyze intent **before** spec writing; loads Graphify JSON; routes context to three layers (**expected / current / platform**); is configured via `/.agents/uncle-dev-setup.yaml`; supports per-team "flavors" (domain-specific skill+rule bundles).
2. **Uncle Framework** — a skill encoding the team's framework/library guidance (patterns, anti-patterns) consulted during spec analysis and build; rules apply globally or to specific paths (e.g., `packages/web` → React skill, `packages/api` → Python skill).
3. **Product Mode Agent** — product-centric agent that ensures alignment between expected behavior, current code behavior, and actual platform behavior; presents results to **non-technical stakeholders** (PMs, designers) in plain language with visualizations.

A binding constraint applies to all three: **reactive invocation only**. They run only when the user invokes them via a command or at a defined checkpoint; they have no autonomous execution. Uncle-dev skills MAY recommend invoking them at high-value points in the workflow, but the user always has the final say.

---

## 2. Repository Topology Refresher

For full topology see prior doc, Section 2. Key facts that recur in this extension:

- `graphify-out/graph.json` is OFF in this repo (it ships skills; does not self-graph).
- 19 slash commands at `.claude/commands/uncle-dev-*.md`.
- 32 skills at `skills/uncle-dev-*/SKILL.md`.
- 6 agent personas at `agents/uncle-dev-ag-*.md`.
- 8 hook scripts at `hooks/*.sh`, 4 wired into `hooks/hooks.json`.
- One project config template at `skills/uncle-dev-setup/uncle-dev-setup.template.yaml`. No `.agents/uncle-dev-setup.yaml` lives in this repo (it is rendered into a consuming project by `/uncle-dev-setup`).

---

# Part I — Uncle Domain (extension of prior research)

The prior doc (`2026-05-17-uncle-domain-companion-exploration.md`) already mapped this pillar in detail. Specifically:

- **§3 (Where Product / Domain Reasoning Currently Lives)** — `uncle-dev-idea-refine`, `uncle-dev-feature-map`, `uncle-dev-research` are the only pre-spec product-touching skills; no business-rules catalog, no behavior-map artifact, no drift detector between expected vs. implemented behavior.
- **§4 (Skill Anatomy and the Configuration / "Flavor" Surface)** — `.agents/uncle-dev-setup.yaml` schema today (overrides, companions, preferences, hooks); template header at `:36-37` is explicit: "All uncle-dev skills are always available — there is no opt-in/opt-out list." There is no flavor/profile/domain-pack system; the closest mechanism is path-registered companion skills (`uncle-dev-setup.template.yaml:47-65`).
- **§5 (Spec System: Methodologies, Artifacts, Annotations)** — HLD / LLD / EARS / arrows / OpenSpec / acknowledge all implemented; SpecKit not present; annotation vocabulary is only `@spec` today.
- **§6 (Graphify Integration: What's Built, What's Hardcoded)** — graphify-aware protocol exists; mandatory subagent gate; graph-analyst persona; one-way spec-edges.json bridge. Every consumer assumes **fixed paths**: `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md`, `docs/arrows/spec-graph.{json,mmd}`, `docs/arrows/SPEC_GRAPH_REPORT.md`, `docs/high-level-design.md`, `docs/llds/`, `docs/specs/`, `docs/arrows/index.yaml`. There is no project-level config that points uncle-dev at alternative graphify JSON paths, multiple graphify graphs, alternative spec roots, or a registry mapping graph names → file paths.
- **§9 (Surfaces Relevant to Each Pillar of the Uncle Domain Vision)** — pillar-by-pillar exists/missing tally.

This Part I treats those findings as carried forward. The remainder of this document adds dimensions the prior doc did not explicitly enumerate.

### 2.1 Spec frameworks already supported

`CLAUDE.md:35` defines the canonical cascade. The matrix:

| Framework | Status in repo | Owning artifacts |
| --- | --- | --- |
| HLD | Implemented | `docs/high-level-design.md` (per `skills/uncle-dev-design-architecture-docs/SKILL.md:233`) |
| LLD | Implemented | `docs/llds/<segment>.md` (per `SKILL.md:234`) |
| EARS (durable behavior IDs) | Implemented | `docs/specs/<segment>-specs.md`; regex at `skills/uncle-dev-spec-annotations/scan-spec-coherence.py:39-41` |
| OpenSpec (transient changes) | Implemented | `openspec/changes/<id>/{proposal,design,tasks,execution,handoff}.md` (per `skills/uncle-dev-spec-driven-development/SKILL.md:213-217`) |
| Acknowledge (LID-style decisions) | Implemented | `openspec/acknowledge/<scope>.md` (per `skills/uncle-dev-acknowledge/SKILL.md:10-11`) |
| Idea one-pager | Implemented | `docs/ideas/[idea-name].md` (per `skills/uncle-dev-idea-refine/SKILL.md:32-38`) |
| SpecKit | Not present | — |

**Routing into a framework** is implicit: `/uncle-dev-idea-refine` → `docs/ideas/`; `/uncle-dev-spec` → `openspec/changes/`; `/uncle-dev-design-docs` → HLD/LLD/EARS; `/uncle-dev-acknowledge` → `openspec/acknowledge/`. There is no router that *reads* a product question and picks which framework is the right starting point — the user picks the slash command.

### 2.2 Graphify JSON path configurability (key open question for Uncle Domain)

`skills/uncle-dev-graphify-aware-analysis/SKILL.md:18-22` runs once at skill start:

```
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF — using standard search"
```

The path is hardcoded. Every consumer (graphify-aware skill, research skill, spec-graph builder's bridge at `build-spec-graph.py:533-549`) assumes `graphify-out/` exists at repo root.

`.agents/uncle-dev-setup.yaml` carries only a boolean `preferences.graphify` toggle (`uncle-dev-setup.template.yaml:68-73`). There is no field today for:

- alternative graphify output paths
- multiple graphify outputs (e.g., one per domain / per package)
- a registry mapping a name → graph file

This is reiterated from the prior doc's §6.5; called out here because it is the **direct blocker** to the user's "load Graphify JSON files at configured paths" requirement for Uncle Domain.

---

# Part II — Uncle Framework

## 3. Framework / Library Guidance Surface Today

### 3.1 Framework patterns and anti-patterns are encoded in SKILL.md prose, not data

Three Build-phase skills carry framework-flavored content, all embedded in their SKILL.md body. Quoted from the scout:

- **`uncle-dev-frontend-ui-engineering/SKILL.md`** — React + Tailwind + React Query:
  - `:21-34` example file structure (`TaskList.tsx`, `TaskList.test.tsx`, `TaskList.stories.tsx`, `use-task-list.ts`).
  - `:36-58` "Prefer composition over configuration" with JSX example.
  - `:105-112` state-management ladder: `useState → Server state (React Query, SWR) → Global store (Zustand, Redux)`.
  - `:117-132` AI-aesthetic anti-pattern table (8 rows: Purple/indigo, Excessive gradients, Rounded everything, Generic hero sections, Lorem ipsum copy, Oversized padding, Stock card grids, Shadow-heavy design).
  - `:241-287` Tailwind grids; React Query optimistic-update template.
- **`uncle-dev-api-and-interface-design/SKILL.md`** — REST + TypeScript + Zod:
  - `:24-31` Hyrum's Law as design principle.
  - `:65-83` REST status-code table (400/401/403/404/409/422/500).
  - `:92-110` Zod-flavored validation example.
  - `:212-260` Discriminated-union and branded-types patterns.
  - `:274-282` Red-flag list (endpoints with shape variance, inconsistent error formats, etc.).
- **`uncle-dev-source-driven-development/SKILL.md`** — framework-**agnostic** lookup logic:
  - `:42-50` Stack-detection table maps lockfiles → frameworks (`package.json → Node/React/Vue/Angular/Svelte`, `requirements.txt / pyproject.toml → Python/Django/Flask`, `go.mod → Go`, `Cargo.toml → Rust`, `Gemfile → Ruby/Rails`).
  - `:68-74` Source hierarchy — official docs ranked above blog posts.
  - `:106-118` Conflict-detection (e.g., `useState` vs `useActionState`).
  - `:172-181` Red flags (using "I believe", citing Stack Overflow, deprecated APIs).
- **`uncle-dev-context-engineering/SKILL.md`** — rules-file conventions:
  - `:42-72` CLAUDE.md template with `## Tech Stack`, `## Commands`, `## Code Conventions`, `## Boundaries`, `## Patterns`.
  - `:74-78` lists `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`, `AGENTS.md` as rules-file equivalents.
  - `:256-264` Anti-patterns table (Context starvation, Context flooding, Stale context, Missing examples, Implicit knowledge, Silent confusion).

**Coverage today:** React, Tailwind, React Query, REST, TypeScript, Zod. **No Vue, Svelte, Angular, Next.js, FastAPI, Django, Spring, GraphQL** patterns as first-class content. The frontend skill is named generically but is React-specific in body.

### 3.2 Path-scoped configuration today

**There is no path-scoping or glob-based rule attachment** in `.agents/uncle-dev-setup.yaml`. Confirmed by reading `skills/uncle-dev-setup/uncle-dev-setup.template.yaml`:

- `:16-22` `project.framework` is a **single string slot** (`# react | nextjs | express | fastapi | etc. (blank if none)`) for the whole project. Not per-path.
- `:36-37` "All uncle-dev skills are always available — there is no opt-in/opt-out list."
- `:42-46` `skills.overrides.<skill-name>.*` only carries per-skill kv (`test_runner`, `coverage_threshold`). No path key.
- `:47-65` `skills.companions` schema is **`<phase> → [{path, name}]`**. The `path` is the path to the SKILL.md file itself, NOT a path the skill applies to.
- `:68-73` `preferences.*` are flat booleans.
- `:78-84` `hooks.*` are flat booleans, no `matcher` or path filter at config level.

The `project.type` enum at `:19` includes `monorepo`, but no downstream consumer keys behavior off that value.

### 3.3 The closest existing path-scoping precedents

Three mechanisms in the codebase already scope behavior to paths. **None attaches framework rules today.**

#### 3.3.1 `AGENTS.md` per-directory (read-before-edit)

- `hooks/check-agents-md.sh:6-22` — on Edit|Write, extracts `$FILE_PATH`, takes `$(dirname)`, emits `priority: INFO` reminder if `AGENTS.md` exists in that directory.
- `skills/uncle-dev-code-context/SKILL.md:22-30` — workflow enforces "read AGENTS.md before editing".
- `skills/uncle-dev-incremental-implementation/SKILL.md:38` — Step 1 of every implementation slice = read AGENTS.md.
- `.claude/commands/uncle-dev-build.md:30` — Step 0 of `/uncle-dev-build` is `code-context`.

Scope: per-directory. Trigger: Edit|Write with a file path in that directory. Content: free-form markdown. **No glob, no path → skill mapping, no central index.** This is the only existing per-directory rule-injection precedent.

#### 3.3.2 Acknowledge scope inference (regex routing table)

`skills/uncle-dev-acknowledge/inference-rules.md:13-24` defines the **only** mechanism in the codebase that maps **path tokens → named scopes → behavior**. Direct quotes:

| Signal | Scopes |
| --- | --- |
| Path mention `apps/<x>/`, `packages/<x>/`, `libs/<x>/`, `services/<x>/` | scope `<x>` (lazy create) |
| `render`, `routes/`, `pages/`, `useEffect`, `useState`, `useMemo`, `useCallback`, `tailwind`, `styled-components`, `<[A-Z][A-Za-z]*[/ >]`, `className=`, `next/`, `app/`, `react`, `vite` | `web` |
| `DTO`, `Schema`, `Type`, `Interface`, `Contract`; `interface`, `Zod`, `valibot`, `shared util`, `monorepo`, `workspace` | `share` |
| HTTP path tokens, HTTP verbs, controller/route/handler/endpoint/middleware/interceptor/guard | `api` |
| Cross-cutting (`security`, `perf budget`, `observability`, `error envelope`, `naming convention`, `rate limit`, `audit`, `logging`, `telemetry`, `feature flag`) | `general` (always; in addition) |

Anti-pattern from `:90-94`: *"LLM-based routing. Don't. Two agents must agree byte-for-byte on the scope set. A regex table is auditable; an LLM call isn't."*

`skills/uncle-dev-next-task/acknowledge-gate.md:14` and `skills/uncle-dev-next-task/SKILL.md:200` show the same path-glob extraction is applied to story prose to derive a story's touched scopes.

**This is THE precedent for path → scope routing.** Today it powers the acknowledge gate, not framework-rule activation.

#### 3.3.3 File-path-aware hooks

`hooks/check-agents-md.sh:6`, `hooks/openspec-guard.sh:11`, and `hooks/spec-coherence-guard.sh` (multiple lines) all read `CLAUDE_TOOL_INPUT_file_path` and gate behavior on it. The hook layer is already wired to receive the file path; no hook today uses it to look up a framework-rules artifact.

### 3.4 Build-phase and spec-phase consultation of framework rules

- **Build phase consults `AGENTS.md` in target directories**, via `code-context` Step 0 (`.claude/commands/uncle-dev-build.md:30`, `skills/uncle-dev-incremental-implementation/SKILL.md:38`). There is no second step that consults a structured framework-rules artifact — `AGENTS.md` is free-form prose.
- **Spec phase consults nothing.** The scout verified the full `uncle-dev-spec-driven-development/SKILL.md` and `uncle-dev-design-architecture-docs/SKILL.md` and found no reference to a framework-rules artifact. Framework constraints live only in the agent's general knowledge and in whatever free-form text the user writes under `design.md > ## Constraints`.

### 3.5 Reviewer/auditor consultation

- `agents/uncle-dev-ag-code-reviewer.md:18-53` — five axes (Correctness, Readability, Architecture, Security, Performance). No framework-rules consultation.
- `agents/uncle-dev-ag-security-auditor.md`, `agents/uncle-dev-ag-test-engineer.md` — none reference any framework-rules artifact.
- `skills/uncle-dev-code-review-and-quality/SKILL.md:28-103` — five-axis review in prose, no framework axis.

### 3.6 Companion-skill registry — closest current extension point

`skills/uncle-dev-setup/uncle-dev-setup.template.yaml:47-65` (Section 3.2 above). Activation is **manual prompting** per template header at `:9`: *"Companion skills: reference them by path when prompting (/uncle-dev-build, /uncle-dev-review)"*. No mechanism today auto-injects a companion when editing files under a path.

What `skills.companions` lacks for Uncle Framework's needs:
- No `applies_to:` glob field on a companion entry.
- No automatic side-loading by the build/spec phase orchestrator.
- No precedent for a companion declaring what it applies to in its own SKILL.md frontmatter.

### 3.7 Anti-pattern catalogs as data

Anti-patterns exist as **prose tables inside SKILL.md files**, not as machine-readable rules. Locations cited in §3.1. There is no scanner, hook, or skill today that iterates over a structured anti-pattern catalog.

---

# Part III — Product Mode Agent

## 4. Existing Personas and Their Audience

All six personas in `agents/` are engineering-audience. Per scout verification:

| Agent file | Declared audience | Output form | Stakeholder framing |
| --- | --- | --- | --- |
| `uncle-dev-ag-repo-research-analyst.md` (`:3, :10, :113-199`) | Engineering subagent ("Not for direct user invocation"); "documentarian, not an evaluator" | Markdown handoff `.uncle-dev/research/repo-research-<repo-name>.md` (Overview / Architecture / Conventions / Templates / Insights / Graph-Derived Architecture) | None |
| `uncle-dev-ag-graph-analyst.md` (`:3, :46-48, :66-93`) | Engineering subagent ("Not for direct user invocation") | Inline structured text (Key Relationships / Architectural Signals / Structural Scope / Low-Confidence Claims / Suggested Follow-up Queries); confidence labels `EXTRACTED` (1.0) / `INFERRED` (0.6–0.9) | None |
| `uncle-dev-ag-code-reviewer.md` (`:7, :19, :66-89`) | Staff Engineer | Inline markdown "Verdict: APPROVE \| REQUEST CHANGES" with Critical/Important/Suggestion findings and Verification Story | None |
| `uncle-dev-ag-test-engineer.md` (`:7, :70-86`) | QA Engineer | Inline markdown "Test Coverage Analysis" with Critical/High/Medium/Low priority | None |
| `uncle-dev-ag-security-auditor.md` (`:7, :66-92`) | Security Engineer | "Security Audit Report" — severity Critical/High/Medium/Low/Info; each finding has Location/Description/Impact/PoC/Recommendation | None |
| `uncle-dev-ag-review-synthesizer.md` (`:3, :56-76`) | Senior Staff Engineer, subagent only | "Verdict: APPROVE \| REQUEST_CHANGES \| NEEDS_DISCUSSION" + Blocking / Non-Blocking / Notes for Discussion / PR Summary paragraph | The "PR Summary" line (`:74-75`) is the **closest existing artifact to stakeholder framing** — but still engineering-audience |

**No persona today is configured for PMs, designers, or business stakeholders.**

## 5. Non-Technical Outputs Today

Only one skill enforces non-engineering output formatting:

- **`uncle-dev-feature-map`** is the only skill that **declares a PM audience explicitly**.
  - `skills/uncle-dev-feature-map/SKILL.md:33` — differentiator table lists audience as "Engineers + PMs" vs `uncle-dev-research` which is "Engineers".
  - `:55` — instructs subagents: *"Name each feature as a product manager would. For each feature include: feature name (user-facing), what the user can do, entry point (route path or handler), and any visible business rules or constraints."*
  - `:90-121` — output structure: domain-grouped tables with columns `Feature | User Action | Backend Entry | Frontend Entry | Notes`; sections for "API-Only Capabilities", "Orphaned UI", "Open Questions".
  - `:143` — red flag: *"Features named after code constructs (`UserController.store`) instead of user actions (`Create user account`)."*
  - `:152` — verification: *"Feature names read as product capabilities, not code identifiers."*

Adjacent surfaces that do **not** produce stakeholder output:

- **`uncle-dev-shipping-and-launch/SKILL.md`** — engineering checklist. Mentions "Changelog updated" (`:84`) and "User-facing documentation updated (if applicable)" (`:86`); does not template a release-notes or launch-announcement format. Rollback plan (`:253-276`) is engineering-only.
- **`uncle-dev-documentation-and-adrs/SKILL.md:10`** — *"Target audience is future humans and agents working in the codebase."* ADR template (`:55-96`) and changelog template (`:240-253`) are both engineer-audience. The "Documentation for Agents" section (`:255-263`) names agents as an audience; PMs/designers appear nowhere.
- **`uncle-dev-knowledge-capture/SKILL.md`** — outputs to `.uncle-dev/learns/<category>/`. YAML frontmatter requires `problem_type`, `component`, `root_cause`, `resolution_type`, `severity`, `tags` — engineering taxonomy throughout.
- **`uncle-dev-idea-refine/SKILL.md:112-136`** — the one-pager template is the **most PM-aligned format in the repo**: Problem Statement (HMW framing), Recommended Direction, Key Assumptions to Validate, MVP Scope, Not Doing list, Open Questions. Phase 1 sharpening questions at `:62-69` are PM/founder-style ("Who is this for, specifically? / What does success look like? / Why now?"). But framed as ideation, not current-state reporting.

## 6. Alignment / Drift Detection Artifacts

The pipeline that produces drift signals today is engineering-coded.

### 6.1 Scanner output classes (`scan-spec-coherence.py`)

Per `skills/uncle-dev-spec-annotations/SKILL.md:210-217`:

- `✓` specs with both code + test annotations
- `✗ ORPHAN` — code/test cites a spec ID that doesn't exist (BLOCKING)
- `✗ MISSING TEST` — spec has code citation but no test
- `⚠ MISSING CODE` — spec has test citation but no code
- `⚠ HELPER ANNOTATION` — annotation on non-entry-point AST node
- (also) `MALFORMED ID` — fails the `SEG-AREA-NNN` regex

The text formatter at `scan-spec-coherence.py:207-251` prints lines like `✗ ORPHAN: {file}:{line} cites @spec {id} (not in docs/specs/)`. JSON summary at `:186-204`: `summary {specs_defined, specs_with_code, specs_with_test, orphans, missing_tests, missing_code, helper_annotations, malformed_ids}`.

**Vocabulary is engineering-coded** — ORPHAN, HELPER ANNOTATION, etc. presume engineering literacy.

### 6.2 `SPEC_GRAPH_REPORT.md` (build-spec-graph.py)

`build-spec-graph.py:426-500` renders the human report. Sections (`:431-498`):

- Summary (segment count, HLD topics, EARS specs, orphan @spec citations)
- Per-segment breakdown (status / specs / coverage / next)
- **Cascade Impact** section (`:474`) — *"If an LLD changes, every listed spec downstream may need to change too"*
- Orphans list
- Embedded Mermaid graph

Terminology: "HLD topics", "EARS specs", "orphan @spec citations", "Cascade Impact". The *segment names* themselves are intentionally product-readable (per `skills/uncle-dev-design-architecture-docs/resources/segment-examples.md:9`: *"The test for a good segment name: can a stakeholder who doesn't know the codebase tell you what behavior is in the segment from its name alone?"*) but **the surrounding report metadata is not**.

### 6.3 `changes.yaml` (generate-tracker.py)

`skills/uncle-dev-spec-driven-development/generate-tracker.py:1-22, 296-342`. Output schema per change:

```
title, status (not_started | in_progress | done | shipped), phase (planning | build | verify | ship),
owner, criteria_done, criteria_total, records (jira/github/linear/trello/monday/notion/custom),
created_at, updated_at, spec_coverage { declared, with_code, with_test, coverage_pct, missing }
```

`compute_spec_coverage()` at `:239-282` — `total_slots = len(declared) * 2 # each ID gets a code slot + test slot` (`:273`).

**This is the closest existing artifact to a "is the platform aligned with intent?" view** — but it is YAML, not narrative.

### 6.4 Drift field in arrow registry

`skills/uncle-dev-spec-annotations/resources/templates/arrows/index.yaml:10, :27` — status value `DRIFT — coherence audit failed; see drift field for details`; per-segment `drift: null` field.

### 6.5 Hooks that block on drift

- `hooks/spec-coherence-guard.sh:91-103` (Edit/Write) and `:139-146` (Bash → git commit) — block on unknown @spec IDs / non-zero scanner exit. Per scout, this is *the* commit-time drift enforcement.

## 7. Visualization Mechanisms

Two visualization producers exist. Both target engineers.

### 7.1 Mermaid graph (`build-spec-graph.py:357-421`)

Emits `graph TD` to `docs/arrows/spec-graph.mmd` (`:518-521`). Node types styled (`:362-368`): hldNode/lldNode/specNode/testNode/codeNode. Spec status markers (`:381`): `✓` implemented, `○` gap, `◌` deferred. Edge legend (`:497`): *"HLD→LLD `decomposes_to` (solid), LLD→spec `specifies` (solid), spec→test `verified_by` (dotted), spec→code `implemented_by` (thick)."* Embedded in `SPEC_GRAPH_REPORT.md` (`:490-498`).

### 7.2 Markdown tables (used throughout)

- HLD Segments table (`skills/uncle-dev-design-architecture-docs/resources/hld-template.md:23-27`).
- LLD Key Flows ASCII blocks terminating in `→ EARS specs: SEG-001, SEG-002` (`resources/lld-template.md:41-46, 52-56`).
- Feature-map per-domain tables (`skills/uncle-dev-feature-map/SKILL.md:106-111`).
- **Shipping rollout-decision traffic-light table** (`skills/uncle-dev-shipping-and-launch/SKILL.md:158-163`) — Metric / Advance (green) / Hold (yellow) / Roll back (red). The **only existing traffic-light visualization in the repo**.

### 7.3 ASCII / box diagrams

In SKILL.md prose (`skills/uncle-dev-spec-annotations/SKILL.md:31-66`, `skills/uncle-dev-design-architecture-docs/SKILL.md:32-52`, `skills/uncle-dev-shipping-and-launch/SKILL.md:108-114, 125-152`). Static, not generated.

**No mechanism today renders graphs as PM-friendly visualizations** (high-level dashboards, status cards keyed to product behaviors).

## 8. Stakeholder Personas in Current Skills (Grep Results)

The string-level audit returned very few hits — all in the sense of "naming heuristic", not "target audience for output":

- `skills/uncle-dev-design-architecture-docs/resources/segment-examples.md:9` — segment-naming test: *"can a stakeholder who doesn't know the codebase tell you what behavior is in the segment from its name alone?"*
- Same file `:36` — *"Each segment is a product-behavior area a non-engineer can describe."*
- Same file `:155` — table row: *"Stakeholder test | Non-engineer can describe it | Only an engineer knows what's in it"*.
- `skills/uncle-dev-spec-annotations/resources/annotation-examples.md:244` — *"Does this code implement a behavior a user, customer, or stakeholder would care about? If no, no annotation."*
- `skills/uncle-dev-feature-map/SKILL.md:55` — "Name each feature as a product manager would" (cited in §5).
- `skills/uncle-dev-spec-driven-development/SKILL.md:75` — graphify hint uses "plain language": *`graphify query "<describe the change area in plain language>" --budget 1500`*.

**"Product manager", "designer", "non-technical", "business analyst" appear nowhere else in `skills/` or `agents/`.** Stakeholders are invoked only as a *naming heuristic* (a test for whether a segment name is good), not as a target audience.

---

# Part IV — Reactive Invocation Model

## 9. Invocation Primitives

The repo has four primitives: slash command, skill, agent persona, hook script. Per scout (verified against CLAUDE.md, AGENTS.md, AGENT_RULES.md, README.md):

| Primitive | Source | Invoked by | Can invoke | Auto vs reactive |
| --- | --- | --- | --- | --- |
| **Slash command** | `.claude/commands/*.md` (19 files) | User typed (`AGENTS.md:11`: *"When the user types any `/uncle-dev-*` command, invoke the corresponding skill or agent immediately. Do not ask for clarification first."*) | Skills, agent personas, external scripts | Reactive |
| **Skill** | `skills/<name>/SKILL.md` (32 dirs) | Slash command body, another skill's recommendation prose, the skill-discovery flowchart in `skills/uncle-dev-using-agent-skills/SKILL.md:16-39` | Other skills (text recommendation), agent personas (Task spawn), shell scripts | Reactive |
| **Agent persona** | `agents/*.md` (6 personas) | A parent skill via Task tool with `subagent_type=<persona>`. Three personas also have direct slash-command wrappers: `/uncle-dev-code-reviewer`, `/uncle-dev-security-auditor`, `/uncle-dev-test-engineer` (`AGENTS.md:49-55`). Two are spawned-only (`repo-research-analyst`, `review-synthesizer` — "Not for direct user invocation") | Tools only (Read/Glob/Grep/Bash). No agent spawns other agents in this repo's design | Reactive |
| **Hook script** | `hooks/*.sh` + `hooks/hooks.json` | Claude Code runtime on declared events | Nothing directly — emits INFO/IMPORTANT messages or returns exit 1/2 to block; can redirect a Bash command via `permissionDecision: deny` per `AGENT_RULES.md:97-112` | **Automatic** — the only primitive that runs without explicit invocation |

## 10. Auto-Invoke Surface (Hooks)

`hooks/hooks.json` wires four events:

```
SessionStart     → session-start.sh
PreToolUse Edit|Write → check-agents-md.sh, openspec-guard.sh, spec-coherence-guard.sh
PreToolUse Bash       → pre-commit-guard.sh, destructive-command-guard.sh, spec-coherence-guard.sh
PostToolUse Bash      → knowledge-capture-nudge.sh
```

Per-hook behavior summary (from scout):

| Hook | Trigger | Action | Effect |
| --- | --- | --- | --- |
| `session-start.sh:1-47` | SessionStart | Injects Skill Discovery + Quick Reference from `using-agent-skills/SKILL.md`, plus recent `.uncle-dev/learns/` filenames | Informational |
| `check-agents-md.sh:1-22` | Edit/Write | If target dir has AGENTS.md, emits `priority: INFO` reminder | Non-blocking |
| `openspec-guard.sh:1-43` | Edit/Write under `openspec/changes/<id>/` | Validates slug format + presence of required artifacts | INFO only (non-blocking) |
| `spec-coherence-guard.sh:56-105` (Edit/Write) | Edit/Write | Extracts @spec IDs from new content, validates against `docs/specs/` | **Blocks** on unknown IDs (`exit 2`) |
| `spec-coherence-guard.sh:111-148` (Bash) | `git commit` | Runs `scan-spec-coherence.py`; blocks if non-zero rc | **Blocks** commit |
| `pre-commit-guard.sh:30-56` | `git commit` | Rejects placeholder messages (`fix`, `wip`); scans staged diff for `console.log`/`debugger;`/`pdb.set_trace()` | **Blocks** commit (`exit 1`) |
| `destructive-command-guard.sh:38-105` | Bash | Allowlist read-only; match destructive patterns (`rm -rf`, `git reset --hard`, `git push --force`, `DROP TABLE`, `dropDatabase()`) | **Blocks** with confirmation prompt (`exit 1`) |
| `knowledge-capture-nudge.sh:1-47` | PostToolUse Bash | If output indicates passing tests (`PASS`, `✓`, `0 failed`) and cooldown elapsed, emits INFO nudge: *"Tests passed. If this resolved a problem you have been working on, run `/uncle-dev-knowledge-capture`…"* (`:44`) | Suggests — **does not auto-invoke** |

**The auto-invoke surface is exactly: hooks → block / INFO / Bash-redirect. No hook spawns a skill.** Per scout: *"Net: hooks emit advisory messages or block tool calls. No hook spawns a skill. Auto-invocation surface is exactly: hooks → block/INFO → user/agent reacts."*

Even `uncle-dev-proactive-memory` — the only skill with "proactive" in its name — is invoked via `/uncle-dev-proactive-memory` (`.claude/commands/uncle-dev-proactive-memory.md:5-7`). Its trigger is a MEMORY MATCH already injected into system context by an upstream hook; **the skill reacts to that signal, it does not self-trigger**.

## 11. Cross-Skill Recommendation Network

Every skill-to-skill jump is a recommendation written into prose, executed only when the agent or user follows it. Full inventory (from scout, deduplicated and grouped):

### 11.1 Spec-coherence chain
- `uncle-dev-design-architecture-docs` → `/uncle-dev-spec-scan`, `/uncle-dev-spec-graph` after HLD/LLD changes (`SKILL.md:163-164`; `resources/lld-template.md:85`).
- `.claude/commands/uncle-dev-design-docs.md:49, :67-71` — chains to `/uncle-dev-spec-scan` + `/uncle-dev-spec-graph` after segment scaffold.
- Spec-template footer: `skills/uncle-dev-spec-annotations/resources/templates/specs/SEGMENT-specs.md:24`, `resources/templates/arrows/SEGMENT.md:46` — point to `/uncle-dev-spec-scan`.
- Scanner-clean as DoD checkpoint: `skills/uncle-dev-spec-annotations/SKILL.md:299`; `skills/uncle-dev-code-review-and-quality/SKILL.md:497`.

### 11.2 Knowledge / Acknowledge router
- `uncle-dev-knowledge-capture/SKILL.md:32-46` — Step 0 routes input to either `.uncle-dev/learns/` or `uncle-dev-acknowledge`.
- `uncle-dev-knowledge-capture/SKILL.md:43` → `uncle-dev-acknowledge` for design decisions; `:172-177, :343` → `uncle-dev-knowledge-maintenance` when context tight.
- `uncle-dev-acknowledge/SKILL.md:18, :23-24` — wrong-tool detection: bug → learns; ADR → `docs/decisions/`.
- `uncle-dev-documentation-and-adrs/SKILL.md:27, :33, :36` — recommends `uncle-dev-acknowledge` for per-package gating decisions instead of repo-wide ADR.
- `uncle-dev-knowledge-maintenance/SKILL.md:30, :177` → `uncle-dev-knowledge-capture` after next user encounter.

### 11.3 Next-task / build chain
- `uncle-dev-next-task/SKILL.md:19-20, :162, :279-281` → `/uncle-dev-spec`, `/uncle-dev-knowledge-capture`, `uncle-dev-spec-driven-development`, `uncle-dev-planning-and-task-breakdown`, `uncle-dev-incremental-implementation`.
- `uncle-dev-next-task/acknowledge-gate.md:50` — re-run after unblocking.

### 11.4 Research / review subagent spawns
- `uncle-dev-research/SKILL.md:89` — *"For full repository or unfamiliar codebase: Spawn `uncle-dev-ag-repo-research-analyst` to produce a structured repo handoff document first, then spawn targeted scouts… If the graph is ON, you may also spawn `uncle-dev-ag-graph-analyst` in background…"*
- `uncle-dev-code-review-and-quality/SKILL.md:286-288` — *"**When to spawn `uncle-dev-ag-graph-analyst`:** Only when graphify is ON AND the change exceeds ~300 lines OR touches a god node identified in GRAPH_REPORT.md."*
- Same file `:290` — *"For `--security` mode, add `uncle-dev-ag-security-auditor` to the parallel phase."*
- `uncle-dev-graphify-aware-analysis/SKILL.md:175-179` — *"For multi-hop traversal needs (more than 2–3 queries, cross-community analysis, or impact scoping across many modules), spawn the `uncle-dev-ag-graph-analyst` subagent rather than running queries inline."*
- `uncle-dev-test-driven-development/SKILL.md:331` — *"For complex bug fixes, spawn a subagent to write the reproduction test."*

### 11.5 Skill-discovery meta-map
- `uncle-dev-using-agent-skills/SKILL.md:16-39, :136-152` — routing map across all 21 phase skills. Not a hard recommendation; a navigation aid.

### 11.6 Workflow-chaining hints
- `AGENT_RULES.md:82-86` — *"After /explore → Ready for /build brownfield?"* pattern; suggested, not enforced.
- `uncle-dev-feature-map/SKILL.md:22-24` — "When NOT to use" router pointing to `uncle-dev-research` / `uncle-dev-source-driven-development` / `uncle-dev-spec-driven-development`.

## 12. Gating Mechanisms (Skill-to-Skill Blocks)

| Gate | Defined | Blocks | Bypassable |
| --- | --- | --- | --- |
| **Acknowledge gate** | `skills/uncle-dev-next-task/acknowledge-gate.md:1-81` (mirror `SKILL.md:79`); reflected in `.claude/commands/uncle-dev-build.md:26` and `uncle-dev-next-task.md:38` | `/uncle-dev-build` (via `/uncle-dev-next-task` Step 4b) cannot claim any story whose touched scopes intersect with `status: pending` decisions in `openspec/acknowledge/<scope>.md` | **Non-bypassable** (`acknowledge-gate.md:3, :50`: *"There is no flag to skip the gate"*) |
| Spec-coherence (Edit/Write) | `hooks/spec-coherence-guard.sh:56-105` | Edit/Write citing unknown @spec ID | Only by fixing the ID |
| Spec-coherence (commit) | `hooks/spec-coherence-guard.sh:111-148` | `git commit` while scanner returns non-zero | Only by clearing orphans |
| Destructive-command | `hooks/destructive-command-guard.sh:38-105` | rm -rf / git reset --hard / DROP TABLE / etc. | User explicit confirmation |
| Pre-commit (msg + diff) | `hooks/pre-commit-guard.sh:30-56` | Placeholder messages; staged debug statements | Amend before re-running |
| OpenSpec change-dir | `hooks/openspec-guard.sh:38-43` | Missing artifacts in change dir | Advisory only (no block) |
| CI quality gates | `skills/uncle-dev-ci-cd-and-automation/SKILL.md:26-54, :384-386` | Lint/types/tests/build/audit on every PR | External-system gate |
| Code review verdict | `agents/uncle-dev-ag-review-synthesizer.md:39-45` | `REQUEST_CHANGES` = blocking | Soft; enforcement is human/CI |

**Only the acknowledge gate is a skill-to-skill block** (`uncle-dev-next-task` against `/uncle-dev-build`'s `--claim`).

## 13. "Recommend Invoking This Agent" Pattern — Existing Precedent

The repo already has the precise pattern the user wants for the new companions. Each "recommend invocation" today follows three steps in the parent skill's prose: (a) a precondition table or "When to spawn" header, (b) the payload to pass, (c) synchronization instructions (foreground vs `run_in_background`).

Quoted instances (from scout):

- `uncle-dev-code-review-and-quality/SKILL.md:286-288` — graph-analyst conditional on graphify ON + diff size + god-node touch.
- `uncle-dev-code-review-and-quality/SKILL.md:290` — security-auditor conditional on `--security` flag.
- `uncle-dev-graphify-aware-analysis/SKILL.md:175-179` — graph-analyst conditional on multi-hop traversal need.
- `uncle-dev-research/SKILL.md:89` — repo-research-analyst conditional on "full repository / unfamiliar codebase".
- `uncle-dev-test-driven-development/SKILL.md:331` — subagent conditional on "complex bug fixes".
- `agents/uncle-dev-ag-repo-research-analyst.md:3` and `agents/uncle-dev-ag-review-synthesizer.md:3` — explicitly mark agents as "Not for direct user invocation"; only parent skills spawn them.

**This is exactly the pattern the user has stated for the new companions** (uncle-dev skills recommend invoking them at high-value workflow points; user has the final say). The precedent exists and is in active use.

## 14. Subagent Spawn Mechanism

Concrete spawn sites (verified):

- `uncle-dev-code-review-and-quality/SKILL.md:292-326` — `/uncle-dev-review` spawns three parallel Task calls + one final synthesizer.
- `uncle-dev-research/SKILL.md:89, :176` — research command spawns repo-research-analyst (and optionally graph-analyst) with `run_in_background: true`.
- `uncle-dev-graphify-aware-analysis/SKILL.md:175-179`.
- `uncle-dev-test-driven-development/SKILL.md:331`.

Canonical Task-call shape documented in `agents/uncle-dev-ag-repo-research-analyst.md:248-271`, `agents/uncle-dev-ag-review-synthesizer.md:88-112`, `agents/uncle-dev-ag-graph-analyst.md:119-123`.

**Subagents are always spawned by a parent skill** (itself reactively invoked by a slash command). There is no autonomous spawn anywhere in the codebase.

---

# Part V — Three-Context-Layer Routing

## 15. Layer Inventory (consolidated)

### Layer 1 — Expected product behavior

Densest layer. Multiple overlapping artifact classes feed it; all paths are hardcoded.

| Artifact | Path (hardcoded) | Owning skill |
| --- | --- | --- |
| HLD | `docs/high-level-design.md` | `uncle-dev-design-architecture-docs` (`SKILL.md:10-15, :130-139, :233`) |
| LLD | `docs/llds/<segment>.md` | same (`SKILL.md:142-152, :234`) |
| EARS specs | `docs/specs/<segment>-specs.md` | `uncle-dev-spec-annotations` (`SKILL.md:69-80`); regex at `scan-spec-coherence.py:39-41` |
| Arrows / segment registry | `docs/arrows/index.yaml`, `docs/arrows/<segment>.md` | same |
| OpenSpec proposal | `openspec/changes/<id>/proposal.md` | `uncle-dev-spec-driven-development` (`SKILL.md:213-217, :225-244`) |
| OpenSpec design | `openspec/changes/<id>/design.md` | same (`SKILL.md:246-268`) |
| Acknowledge notes | `openspec/acknowledge/<scope>.md` | `uncle-dev-acknowledge` (`SKILL.md:10-11`) |
| Idea one-pager | `docs/ideas/[idea-name].md` | `uncle-dev-idea-refine` (`SKILL.md:32-38, :112-136`) |

### Layer 2 — Current existing behavior

| Artifact | Path (hardcoded) | Owning skill |
| --- | --- | --- |
| `@spec` annotations in code | walks `src/`, `tests/`, `test/`, `app/`, `lib/`, `pkg/`, `cmd/`, `internal/`, `templates/` (`scan-spec-coherence.py:85`) | `uncle-dev-spec-annotations` |
| Reverse-engineered feature catalog | `.uncle-dev/feature-maps/YYYY-MM-DD-*.md` | `uncle-dev-feature-map` (`SKILL.md:9-11, :87-89`) |
| Documentarian map | `.uncle-dev/research/*.md` | `uncle-dev-research` |
| Tracker rollup | `openspec/tracker/changes.yaml` | `uncle-dev-spec-driven-development` (`generate-tracker.py:1-22, :296-342`) |
| Graphify graph (when ON) | `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md` | `uncle-dev-graphify-aware-analysis` (`SKILL.md:10-12, :18-22`) |

### Layer 3 — Actual platform-level behavior

**Not represented as a durable repo artifact today.** Distributed indirectly across:

- `uncle-dev-shipping-and-launch/SKILL.md:175-198` "What to Monitor" — error rate, p50/p95/p99 latency, request volume, active users, CWV, JS errors (checklist for humans, not an artifact)
- `uncle-dev-shipping-and-launch/SKILL.md:155-162` "Rollout Decision Thresholds" — canary vs baseline comparison (the only place observed-vs-baseline is captured)
- `uncle-dev-shipping-and-launch/SKILL.md:236-247` "Post-Launch Verification" — 1-hour window checks
- `uncle-dev-ci-cd-and-automation/SKILL.md:12-14, :230-245` — preventive (CI gates) and staged rollout described as sequence; no observation artifact
- `uncle-dev-browser-testing-with-devtools/SKILL.md:9-10, :42-54, :58-66` — Chrome DevTools MCP brings runtime data into working memory; per-session, not persisted; explicit rule that this data is *"untrusted, not durable spec material"*
- `.uncle-dev/learns/runtime-errors/`, `.uncle-dev/learns/performance-issues/`, `.uncle-dev/learns/security-issues/`, `.uncle-dev/learns/ui-bugs/`, `.uncle-dev/learns/integration-issues/`, `.uncle-dev/learns/database-issues/` (`uncle-dev-knowledge-capture/SKILL.md:201-216`) — after-the-fact incident records, not a live platform model

**There is no file in this repo today that is canonically the "platform truth" target** — no analogue to `docs/specs/<segment>-specs.md` for runtime.

## 16. Routing Mechanisms Today

Three signal-to-artifact routers exist:

### 16.1 Acknowledge inference (regex routing table) — `skills/uncle-dev-acknowledge/inference-rules.md:13-24`

Quoted from §3.3.2. This is **the** deterministic, auditable, signal-based artifact router in the codebase. Routes a free-text note → one-or-more `openspec/acknowledge/<scope>.md` files via word-boundary regex over endpoint paths, schema keywords, JSX/React tokens, type tokens, monorepo path tokens, negation patterns, and cross-cutting keywords. Explicit anti-pattern at `:90-94`: *"LLM-based routing. Don't. Two agents must agree byte-for-byte on the scope set. A regex table is auditable; an LLM call isn't."*

### 16.2 Knowledge-capture category mapping — `skills/uncle-dev-knowledge-capture/SKILL.md:197-216`

1:1 enum router: `problem_type` value → directory under `.uncle-dev/learns/<category>/`. Categories: `build_error → build-errors/`, `test_failure → test-failures/`, `runtime_error → runtime-errors/`, `performance_issue → performance-issues/`, `database_issue → database-issues/`, `security_issue → security-issues/`, `ui_bug → ui-bugs/`, `integration_issue → integration-issues/`, `logic_error → logic-errors/`, `developer_experience → developer-experience/`, `workflow_issue → workflow-issues/`, `best_practice → best-practices/`, `documentation_gap → documentation-gaps/`.

Plus the Step 0 router (`:32-46`) that routes the whole input between `.uncle-dev/learns/` and `openspec/acknowledge/` (artifact-class router).

Plus a Step 6 router (`:185-192`) — `problem_type` → reviewer agent (`performance-oracle`, `security-sentinel`, `data-integrity-guardian`, etc.).

### 16.3 Graphify question-shape router — `skills/uncle-dev-graphify-aware-analysis/SKILL.md:32-67`

| Intent | Command |
| --- | --- |
| "You have a specific concept name and want to understand its full structural neighborhood" | `graphify explain "<node>"` |
| "Tracing how module A reaches module B; validating an assumed dependency; finding cross-layer coupling" | `graphify path "A" "B"` |
| "You have a question but not a specific node name; impact analysis; finding 'what else touches this area'" | `graphify query "<question>"` |

Mirrored in project-level CLAUDE.md (the "First tool" table at the top of the file the user sees).

Confidence ladder (`SKILL.md:92-101`): `EXTRACTED` (1.0, ground truth) / `INFERRED` (0.6–0.9, verify) / `AMBIGUOUS` (0.1–0.3, ignore — *"Never file a bug, scope a story, or block a merge on AMBIGUOUS edges alone."*).

Augments-vs-replaces table (`SKILL.md:104-112`): trust EXTRACTED edges; verify INFERRED with grep/Read; fall back to grep/Read when graph is missing or returns empty.

### 16.4 Sub-routers
- `build-spec-graph.py:249-255` — `find_segment_for_id` — longest-prefix match `AUTH-UI-` → segment in `docs/arrows/index.yaml`. Routing-by-ID-prefix.

## 17. Cross-Layer Drift Mechanisms

Today the codebase has **L1↔L2 comparators only**.

| Comparison | Mechanism | Layers |
| --- | --- | --- |
| Code @spec → `docs/specs/` definition | `scan-spec-coherence.py:117-204`. `ORPHAN` when @spec ID not in any `docs/specs/<segment>-specs.md` (`:152-154`) | L2 → L1 |
| Spec `[x]` status → code citation | `scan-spec-coherence.py:179-180` MISSING CODE warning | L1 → L2 |
| Spec `[x]` status → test citation | `scan-spec-coherence.py:177-178` MISSING TEST warning | L1 → L2 |
| @spec annotation owner_kind == "none" | `scan-spec-coherence.py:159-170` HELPER ANNOTATION warning | L2 internal |
| Cross-link HLD↔LLD↔EARS↔Tests↔Code | `build-spec-graph.py:186-304` builds `decomposes_to` / `specifies` / `verified_by` / `implemented_by` edges with status `implemented` / `gap` / `deferred` | All intra-L1 + L1↔L2 |
| Per-change EARS coverage | `generate-tracker.py:239-282` `compute_spec_coverage()`; `total_slots = len(declared) * 2` (`:273`) | L1 (proposal) ↔ L1 (EARS) ↔ L2 |
| L1 or L2 vs L3 | **None** | — |

Cascade-rules contract (`skills/uncle-dev-design-architecture-docs/SKILL.md:155-175`): walking down (intent first) = HLD → LLD → EARS → tests → code → run /uncle-dev-spec-scan; walking up (code first) = @spec ID → EARS spec → LLD → HLD. *"If any layer is stale, update it before merging the code."*

## 18. Configuration for Layer Paths

**No field today** in `.agents/uncle-dev-setup.yaml` configures where each layer lives. All paths are hardcoded throughout the skills (see Section 15). The only generic extension point in the config is `skills.companions` (`uncle-dev-setup.template.yaml:47-65`).

---

# Part VI — Combined Gap Summary

| Pillar / Concept | Exists today | Missing today |
| --- | --- | --- |
| **Uncle Domain — pre-spec product framing** | `uncle-dev-idea-refine` (ideation one-pager); `uncle-dev-feature-map` (reverse catalog, PM-named) | Skill that reframes bug/feature request as expected-vs-current behavior; business-rules registry; behavior-map artifact |
| **Uncle Domain — per-domain "flavors"** | Per-skill overrides; phase-keyed companion path registry; boolean preferences/hooks toggles | Flavor-bundle concept; activation mechanism; flavor-aware skill resolution |
| **Uncle Domain — Graphify JSON paths configurable** | Fixed `graphify-out/graph.json`; boolean `preferences.graphify` toggle; one-way spec-edges.json projection | Configurable graphify path(s); multi-graph registry; per-named-graph query routing |
| **Uncle Domain — annotation vocabulary beyond @spec** | `@spec` only with AST scanner, commit-time enforcement, ORPHAN/MISSING/HELPER/MALFORMED classification | `@feature`, `@rule`, `@api`, `@test`, `@behavior`, `@adr` and the catalogs they would index |
| **Uncle Domain — continuous alignment** | Reactive coherence hooks at edit + commit; on-demand `/uncle-dev-spec-scan`, `/uncle-dev-spec-graph`, `/uncle-dev-openspec-sync` | Scheduled / continuous drift detection between expected vs implemented |
| **Uncle Framework — path-scoped rule attachment** | `AGENTS.md` per-directory (free-form prose, read-before-edit); acknowledge regex routing (`apps/<x>/`, `packages/<x>/`, `libs/<x>/`, `services/<x>/`) — used for design-decision gating, not framework rules | Central index mapping path glob → structured rules artifact; companion `applies_to:` glob field; orchestrator that auto-injects matching companion |
| **Uncle Framework — project-level framework declaration** | Single string slot `project.framework: ""` (`uncle-dev-setup.template.yaml:21`) | List/map form (e.g. `packages/web: react`, `packages/api: fastapi`); downstream consumer |
| **Uncle Framework — framework guidance content** | React/Tailwind/React Query (`frontend-ui-engineering`); REST/TypeScript/Zod (`api-and-interface-design`); stack detection (`source-driven-development`); CLAUDE.md template (`context-engineering`) | Externalization as swappable rules artifact; per-project override; FastAPI/Django/Spring/Vue/Svelte equivalents |
| **Uncle Framework — build-phase consultation** | `code-context` Step 0 reads `AGENTS.md` (`.claude/commands/uncle-dev-build.md:30`) | A second step that consults a structured framework-rules artifact |
| **Uncle Framework — spec-phase consultation** | None — spec skills do not load any framework artifact | Any reference to framework constraints during specify/design phases |
| **Uncle Framework — reviewer consultation** | Five-axis review; no framework axis | Framework-conformance axis; framework-rule-aware reviewer persona |
| **Uncle Framework — anti-pattern catalogs as data** | Anti-pattern prose tables inside multiple SKILL.md files | Structured anti-pattern rules an agent can iterate or a hook can enforce |
| **Product Mode Agent — non-technical-audience persona** | None — all 6 personas in `agents/` are engineering-audience | PM / designer / business-stakeholder persona file |
| **Product Mode Agent — product-language output enforcement** | `uncle-dev-feature-map/SKILL.md:55, :143, :152` enforces product language in one catalog | Generalized formatter that wraps existing engineering outputs in stakeholder language |
| **Product Mode Agent — drift report in stakeholder language** | `SPEC_GRAPH_REPORT.md` (engineering-coded vocabulary); `changes.yaml` (YAML); scanner text output | PM-readable rendering of the same drift signals |
| **Product Mode Agent — visualization** | Mermaid `spec-graph.mmd`; markdown tables; rollout-decision traffic-light table (`shipping-and-launch/SKILL.md:158-163`) | Dashboard / status-card rendering keyed to product behaviors |
| **Product Mode Agent — release-notes / launch comms** | `shipping-and-launch` has no PM-readable release-notes template | Template, producer |
| **Reactive invocation — primitives in place** | Slash command, skill, agent persona, hook script — all reactive except hooks | (no gap — primitive set is sufficient) |
| **Reactive invocation — "recommend invoking the agent" pattern** | Active in 7+ skills with conditional `When to spawn` headers (graph-analyst, security-auditor, repo-research-analyst, etc.) | (no gap — pattern is established and in use) |
| **Reactive invocation — checkpoint hooks block, never auto-invoke** | All 8 hooks are advisory/blocking; none spawns a skill | (no gap — design is consistent with the user's constraint) |
| **Reactive invocation — skill-to-skill blocks** | Only the acknowledge gate (`acknowledge-gate.md`); non-bypassable | (no gap — but only one such gate exists today) |
| **Three-layer routing — Layer 1 represented** | HLD, LLD, EARS, OpenSpec proposal/design, acknowledge, idea one-pager | (no gap — Layer 1 is mature) |
| **Three-layer routing — Layer 2 represented** | @spec annotations + scanner; feature-map catalog; research docs; tracker rollup; graphify (when ON) | (no gap — Layer 2 is mature) |
| **Three-layer routing — Layer 3 represented** | Distributed across `shipping-and-launch` checklists, browser-testing live DevTools, `.uncle-dev/learns/runtime-errors/`, `.uncle-dev/learns/performance-issues/` (after-the-fact) | **No durable Layer 3 artifact** equivalent to `docs/specs/<segment>-specs.md`; no L1↔L3 or L2↔L3 drift detector; no runtime ingest |
| **Three-layer routing — L1↔L2 drift detection** | `scan-spec-coherence.py` (ORPHAN/MISSING/HELPER/MALFORMED); `build-spec-graph.py` (spec→test, spec→code edges); `generate-tracker.py` (coverage_pct) | (no gap) |
| **Three-layer routing — config for layer paths** | Hardcoded paths throughout; no field in `.agents/uncle-dev-setup.yaml` | Configuration that points each layer at a custom path; multi-source ingestion |
| **Three-layer routing — deterministic signal-based routing** | Acknowledge inference regex table (`inference-rules.md:13-24`); knowledge-capture category mapping; graphify question-shape router; spec-ID-prefix → segment matcher | A unified router for product questions → which layer to consult (this does not exist as a single artifact today) |

---

## 19. Key Files Cited (this extension)

Repeats from prior doc are not relisted (see `2026-05-17-uncle-domain-companion-exploration.md` §10). New citations in this extension:

- `skills/uncle-dev-setup/uncle-dev-setup.template.yaml:9, :16-22, :36-37, :42-46, :47-65, :68-73, :78-84, :86-94`
- `skills/uncle-dev-frontend-ui-engineering/SKILL.md:21-34, :36-58, :105-112, :117-132, :241-287`
- `skills/uncle-dev-api-and-interface-design/SKILL.md:24-31, :65-83, :92-110, :212-260, :274-282`
- `skills/uncle-dev-source-driven-development/SKILL.md:42-50, :68-74, :106-118, :172-181`
- `skills/uncle-dev-context-engineering/SKILL.md:42-72, :74-78, :256-264`
- `skills/uncle-dev-code-context/SKILL.md:22-30`
- `skills/uncle-dev-incremental-implementation/SKILL.md:38`
- `skills/uncle-dev-acknowledge/inference-rules.md:9-11, :13-24, :28-36, :88, :90-94`
- `skills/uncle-dev-next-task/acknowledge-gate.md:3, :14, :50, :57-59`
- `skills/uncle-dev-next-task/SKILL.md:19-20, :79, :162, :200, :279-281`
- `skills/uncle-dev-feature-map/SKILL.md:9-11, :22-24, :27-33, :55, :87-89, :90-121, :143, :152`
- `skills/uncle-dev-idea-refine/SKILL.md:32-38, :62-69, :112-136`
- `skills/uncle-dev-shipping-and-launch/SKILL.md:84, :86, :108-114, :125-152, :155-162, :158-163, :175-198, :230-247, :253-276`
- `skills/uncle-dev-browser-testing-with-devtools/SKILL.md:9-10, :42-54, :58-66`
- `skills/uncle-dev-documentation-and-adrs/SKILL.md:10, :26-36, :55-96, :240-263`
- `skills/uncle-dev-knowledge-capture/SKILL.md:32-46, :43, :172-216, :225-300, :343`
- `skills/uncle-dev-knowledge-maintenance/SKILL.md:30, :177`
- `skills/uncle-dev-ci-cd-and-automation/SKILL.md:12-14, :26-54, :230-245, :384-386`
- `skills/uncle-dev-research/SKILL.md:89, :176`
- `skills/uncle-dev-code-review-and-quality/SKILL.md:28-103, :286-326, :497`
- `skills/uncle-dev-graphify-aware-analysis/SKILL.md:18-22, :32-67, :84-101, :104-112, :116-118, :132-149, :175-179`
- `skills/uncle-dev-test-driven-development/SKILL.md:331, :347`
- `skills/uncle-dev-design-architecture-docs/SKILL.md:10-15, :32-52, :130-152, :155-175, :233-234`
- `skills/uncle-dev-design-architecture-docs/resources/segment-examples.md:9, :36, :155`
- `skills/uncle-dev-design-architecture-docs/resources/hld-template.md:23-27`
- `skills/uncle-dev-design-architecture-docs/resources/lld-template.md:41-46, :52-56, :85`
- `skills/uncle-dev-spec-annotations/SKILL.md:31-66, :69-87, :98-148, :210-217, :220-254, :299`
- `skills/uncle-dev-spec-annotations/scan-spec-coherence.py:8-11, :39-41, :85, :91-96, :117-204, :207-251, :302-307`
- `skills/uncle-dev-spec-annotations/build-spec-graph.py:1-23, :186-304, :249-255, :260-275, :357-421, :426-500, :518-549`
- `skills/uncle-dev-spec-annotations/resources/templates/arrows/index.yaml:10, :27`
- `skills/uncle-dev-spec-annotations/resources/templates/specs/SEGMENT-specs.md:24`
- `skills/uncle-dev-spec-annotations/resources/templates/arrows/SEGMENT.md:46`
- `skills/uncle-dev-spec-annotations/resources/annotation-examples.md:244`
- `skills/uncle-dev-spec-driven-development/SKILL.md:40-345, :213-268, :336-345`
- `skills/uncle-dev-spec-driven-development/generate-tracker.py:1-22, :13-19, :71-79, :82-90, :239-342`
- `skills/uncle-dev-acknowledge/SKILL.md:10-11, :18, :23-25`
- `skills/uncle-dev-using-agent-skills/SKILL.md:16-39, :136-152`
- `agents/uncle-dev-ag-repo-research-analyst.md:3, :10, :113-199, :247-271`
- `agents/uncle-dev-ag-graph-analyst.md:3, :46-48, :66-93, :119-123`
- `agents/uncle-dev-ag-code-reviewer.md:7, :18-53, :66-89`
- `agents/uncle-dev-ag-test-engineer.md:7, :70-86`
- `agents/uncle-dev-ag-security-auditor.md:7, :66-92`
- `agents/uncle-dev-ag-review-synthesizer.md:3, :39-45, :56-76, :88-112`
- `hooks/hooks.json:1-61`
- `hooks/session-start.sh:1-47`
- `hooks/check-agents-md.sh:1-22`
- `hooks/openspec-guard.sh:1-43`
- `hooks/spec-coherence-guard.sh:56-148`
- `hooks/pre-commit-guard.sh:1-59`
- `hooks/destructive-command-guard.sh:1-109`
- `hooks/knowledge-capture-nudge.sh:1-47`
- `.claude/commands/uncle-dev-acknowledge.md:1-36`
- `.claude/commands/uncle-dev-build.md:16, :26, :30`
- `.claude/commands/uncle-dev-design-docs.md:49, :67-71`
- `.claude/commands/uncle-dev-next-task.md:29, :38`
- `.claude/commands/uncle-dev-proactive-memory.md:5-7`
- `.claude/commands/uncle-dev-research.md`, `.claude/commands/uncle-dev-spec-graph.md`, `.claude/commands/uncle-dev-spec-scan.md`
- `AGENTS.md:9-67, :11, :49-55, :198-204`
- `AGENT_RULES.md:82-86, :97-112, :160-183`
- `README.md:8-14, :216-227, :243-263, :354-386`
- `CLAUDE.md:18-25, :29-35, :35, :44, :48-64`

---

*End of extension. This file describes current state for the three companion-mode pillars and the reactive-invocation/three-layer-routing constraints; it does not propose how to close the gaps identified above.*
