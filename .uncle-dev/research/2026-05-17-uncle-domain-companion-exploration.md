# Uncle Domain / Product Behavioral OS — Existing Surface Map

**Date:** 2026-05-17
**Author:** Claude (uncle-dev-research)
**Status:** Documentation of current state. No recommendations.
**Scope:** Map what already exists in this repo that is relevant to the user's proposed "Uncle Domain" companion and the broader vision of evolving uncle-dev into a Product Behavioral Operating System.

---

## 1. The Research Question

The user is exploring four interlocking ideas:

1. A new specialized companion ("Uncle Domain" / "Uncle Expert") that reasons about **product, business, and domain** before specs are written — and continuously polices alignment between _expected_ product behavior, _currently documented_ behavior, and _actually implemented_ behavior.
2. A **configurable, extensible** model where teams declare per-domain "flavors": domain skills, business rules, frameworks, policies, behavior maps, operational resources.
3. **Graphify integration via configurable JSON paths**, so Uncle Domain can query relationships across specs / annotations / code / APIs / tests / events / rules / platform behaviors.
4. An expanded annotation vocabulary — `@spec`, `@feature`, `@rule`, `@api`, `@test`, `@behavior`, `@adr` — feeding that graph and powering impact analysis, traceability, and drift detection.

The remainder of this document maps what is **already in place** for each idea and what is **missing**.

---

## 2. Repository Topology (as of this snapshot)

```
production-grade-agent-skills/
├── .claude/commands/              # 19 slash-command entry points (uncle-dev-*)
├── .claude-plugin/                # plugin.json + marketplace.json (Claude Code bundle)
├── plugins/uncle-dev/             # Codex plugin manifest (mirrors commands)
├── .agents/plugins/marketplace.json  # Codex local registry
├── agents/                        # 6 reusable agent personas
├── hooks/                         # hooks.json + guard scripts (session/pre-tool/post-tool)
├── skills/                        # 32 SKILL.md skills, colocated resources/scripts
├── docs/                          # Setup guides
├── scripts/                       # Install scripts (claude-code / codex / opencode)
├── .uncle-dev/research/           # Empty (prior research doc deleted in current branch)
└── (no openspec/, no docs/specs/, no graphify-out/ — this repo doesn't dogfood its own SDD)
```

Skills are organized by phase (CLAUDE.md:18-25): **Define → Plan → Build → Verify → Review → Ship → Capture → Maintain**.

`graphify-out/graph.json` is **OFF** in this repo (the project documents and ships the skills; it doesn't self-graph). Every cited file:line below was verified via grep/Read.

---

## 3. Where Product / Domain Reasoning Currently Lives

The user's vision asks for a layer that sits _before_ specs and reasons in product terms. Today, that layer is **thin and code-shaped**, not product-shaped.

### 3.1 Skills that touch product/domain at all

| Skill                                     | What it does                                                                                                                                                             | Domain coverage today                                                                                                                               |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `uncle-dev-idea-refine` (`SKILL.md:1-50`) | Divergent → convergent refinement of a raw idea into a one-pager (`docs/ideas/<name>.md`) with Problem / Recommended Direction / Key Assumptions / MVP Scope / Not Doing | Ideation mechanics. **No** explicit business-rule or behavior-map outputs. Domain lens mentioned only as a brainstorming prompt (`SKILL.md:70-78`). |
| `uncle-dev-feature-map` (`SKILL.md:1-84`) | Reverse-engineers a product feature catalog from code (routes + pages); groups features by domain (`auth, billing, dashboard, settings, admin, etc.`)                    | Discovers **existing** product capability from code. **Does not** validate intent or business rules.                                                |
| `uncle-dev-research` (`SKILL.md`)         | Documents WHAT IS in the codebase via parallel scouts                                                                                                                    | Architectural map. Product framing only when user asks.                                                                                             |

### 3.2 What sits between idea-refine and spec

Nothing. `/uncle-dev-idea-refine` → `/uncle-dev-spec` is a direct hand-off. The proposed Uncle Domain slot is empty.

### 3.3 What does NOT exist today

- A skill or command that takes a feature request / bug report and **frames it in product terms** (expected behavior, affected business rules, affected user journeys).
- A persistent **business-rules catalog** the system can read and check against.
- A **behavior-map artifact** (a durable view of "what the product is supposed to do") separate from the spec catalog.
- **Drift detection** between an expected-behavior view and what the EARS specs / code annotations currently declare.

---

## 4. Skill Anatomy and the Configuration / "Flavor" Surface

### 4.1 What a skill is

Every skill lives at `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) and a fixed body shape: Overview / When to Use / Process / Common Rationalizations / Red Flags / Verification (`CLAUDE.md:29-35`, `AGENT_RULES.md`). Reference files (templates, checklists, scripts) sit beside the SKILL.md in the same directory once content exceeds ~100 lines.

### 4.2 Plugin packaging (three layers)

1. **`.claude-plugin/plugin.json`** (Claude Code) — points `commands → ./.claude/commands`.
2. **`plugins/uncle-dev/.codex-plugin/plugin.json`** — Codex manifest with `skills → ./skills/`, displayName, longDescription, defaultPrompts.
3. **`.agents/plugins/marketplace.json`** — Codex local registry, populated by `install-codex.sh`.

Multiple plugins coexist by registering separately per tool. Uncle Dev ships as one plugin bundle today.

### 4.3 Project-level configuration: `.agents/uncle-dev-setup.yaml`

Template: `skills/uncle-dev-setup/uncle-dev-setup.template.yaml`. Generated by `/uncle-dev-setup`. The sections it offers:

- `project.{name,type,language,framework}` — inferred
- `tool.active: [claude-code, codex, opencode]` — detected
- `skills.overrides.<skill-name>.*` — per-skill kv (e.g., `test_runner: jest`, `coverage_threshold: 80`)
- `skills.companions: {<phase>: [{path, name}]}` — external SKILL.md files registered by path, slotted into a phase
- `preferences.{sdd_required, spec_annotations, graphify, knowledge_capture, destructive_guard}` — boolean toggles
- `hooks.{session_start, pre_commit, spec_coherence, openspec_guard, destructive_command_guard, knowledge_capture_nudge}` — boolean toggles
- `openspec.{change_id_format, required_artifacts}` — OpenSpec conventions

Template header is explicit (`uncle-dev-setup.template.yaml:36-37`):

> "All uncle-dev skills are always available — there is no opt-in/opt-out list."

### 4.4 What "flavors" look like today

There is **no flavor / profile / domain-pack system**. The closest mechanism is **companion skills** — external SKILL.md files registered by path under a phase (`uncle-dev-setup.template.yaml:47-65`):

```yaml
skills:
  companions:
    build:
      - path: .agents/skills/my-design-system/SKILL.md
        name: my-design-system
```

This is a flat path-registry, not a domain pack. There is no notion of:

- A bundle that groups several skills + rules + frameworks + resources under one named flavor.
- Selecting between flavors at session start.
- Domain-specific business rules attached to a flavor.
- A way for a companion to declare what business domain or operational resources it provides.

---

## 5. Spec System: Methodologies, Artifacts, Annotations

### 5.1 Methodologies in play

`CLAUDE.md:35` defines the canonical cascade: **HLD → LLD → EARS specs → tests → code**.

| Methodology                                                          | Status      | Artifact path                                                        |
| -------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------- |
| **HLD** (product intent)                                             | Implemented | `docs/high-level-design.md`                                          |
| **LLD** (per-segment system approach)                                | Implemented | `docs/llds/<segment>.md`                                             |
| **EARS** (durable behavior specs with stable IDs like `AUTH-UI-001`) | Implemented | `docs/specs/<segment>-specs.md`                                      |
| **Arrow docs** (HLD↔LLD↔EARS↔test↔code crosslinks)                   | Implemented | `docs/arrows/<segment>.md`, `docs/arrows/index.yaml`                 |
| **OpenSpec** (transient change artifacts)                            | Implemented | `openspec/changes/<id>/{proposal,design,tasks,execution,handoff}.md` |
| **Acknowledge / LID-style decisions**                                | Implemented | `openspec/acknowledge/<scope>.md`                                    |
| **SpecKit**                                                          | Not present | —                                                                    |

Skills involved: `uncle-dev-design-architecture-docs` (HLD/LLD/arrows/EARS scaffolding), `uncle-dev-spec-driven-development` (OpenSpec change flow, 5-phase gated), `uncle-dev-acknowledge` (decision gating).

### 5.2 Annotations: what exists today

Implemented (single tag): **`@spec`** only.

`skills/uncle-dev-spec-annotations/SKILL.md` and `resources/annotation-examples.md` define the surface:

```
// @spec AUTH-UI-001
// @spec AUTH-UI-001, AUTH-UI-002    (comma-separated)
# @spec AUTH-UI-001                  (Python)
<!-- @spec MKT-SITE-045 -->          (HTML)
```

Placement rules (`SKILL.md:97-137`): on behavior entry points only — functions, classes, components, routes, `it()` / `test()` / `describe()`. Helpers are not annotated.

### 5.3 Annotations on the user's wishlist — gap analysis

| Annotation | Status today       | Notes                             |
| ---------- | ------------------ | --------------------------------- | ---------------------------------------------------------------------------- |
| `@spec`    | ✅ Implemented     | Links code/test to EARS ID        |
| `@feature` | ❌ Not implemented | No catalog, no scanner support    |
| `@rule`    | ❌ Not implemented | No business-rules registry exists | (referenced by `uncle-dev-acknowledge/SKILL.md:25`), not as inline code tags |

### 5.4 Scanner + tracker (what reads the annotations today)

- **`skills/uncle-dev-spec-annotations/scan-spec-coherence.py`** — tree-sitter per language (ts/tsx/js/jsx/py/go/rs/java/html) with regex fallback. Extracts `@spec` from comments, classifies `owner_kind` (function|class|method|route|component|module|test|none), reports ORPHAN (code cites unknown ID → BLOCKING), MISSING TEST, MISSING CODE, HELPER ANNOTATION, MALFORMED ID. Exit 0/1/2 (`scanner-design.md:1-22`).
- **`generate-tracker.py`** — fuses `proposal.md` (declared EARS IDs) + `tasks.md` (checkbox state) + `handoff.md` (shipped) + scanner output into `openspec/tracker/changes.yaml` with per-change `spec_coverage: {declared, with_code, with_test, coverage_pct, missing}`.
- **`/uncle-dev-spec-scan`** (`.claude/commands/uncle-dev-spec-scan.md`) — read-only audit entry point.
- **`/uncle-dev-openspec-sync`** — regenerates the global tracker.

### 5.5 Spec graph builder (`build-spec-graph.py`)

`skills/uncle-dev-spec-annotations/build-spec-graph.py` (21.5KB) fuses five inputs into three outputs:

```
Inputs                                       Outputs
docs/high-level-design.md          ─┐
docs/arrows/index.yaml             ─┤
docs/llds/<segment>.md             ─┼─► docs/arrows/spec-graph.json
docs/specs/<segment>-specs.md      ─┤    docs/arrows/spec-graph.mmd
scan-spec-coherence.py JSON output ─┘    docs/arrows/SPEC_GRAPH_REPORT.md
                                         + graphify-out/spec-edges.json (if dir exists)
```

Node types: `hld`, `lld`, `spec`, `test`, `code`. Edge types: `decomposes_to` (HLD→LLD), `specifies` (LLD→spec), `verified_by` (spec→test), `implemented_by` (spec→code). Schema version 1.

### 5.6 Acknowledge mechanism (deterministic LID-style routing)

`skills/uncle-dev-acknowledge/SKILL.md` + `inference-rules.md` (`:11-25`):

- Captures design decisions as `openspec/acknowledge/<scope>.md` notes with status `pending` → `acknowledged` / `rejected` / `superseded`.
- Routes a decision to one or more scopes via **deterministic regex on signals** (HTTP paths, schema keywords, React keywords, type names, cross-cutting tags) — NOT via LLM call.
- Example routing (`inference-rules.md:40-72`): D5 "constant-time login with argon2" → signals `login` + `security` → scopes `[api, general]`.
- Gates `/uncle-dev-build`: if `list --status pending` returns any decisions in a story's touched scopes, build is blocked.
- Lock mechanism: `openspec/acknowledge/_meta.yaml.acquiring` sentinel (mkdir-style, 30s timeout) for ID allocation.

---

## 6. Graphify Integration: What's Built, What's Hardcoded

### 6.1 The graphify-aware protocol

`skills/uncle-dev-graphify-aware-analysis/SKILL.md`:

- Triggered indirectly by research / spec / planning / debug / review skills — not a standalone command.
- Activated only when `graphify-out/graph.json` exists; availability check is run once at skill start.
- CLI commands: `graphify explain "<node>"`, `graphify path "A" "B"`, `graphify query "<question>" [--dfs] [--budget N]`, `graphify update <path>`.
- Confidence ladder: `EXTRACTED` (1.0, ground truth), `INFERRED` (0.6-0.9, verify), `AMBIGUOUS` (0.1-0.3, ignore).
- Fallback: empty graph result → grep/Read.

### 6.2 Mandatory subagent gate

`CLAUDE.md:48-64` and `AGENTS.md:48-67` make graphify checking **mandatory for every spawned subagent**:

> "Every spawned agent or subagent MUST check and use it before grep/Glob/Read."
> "Applies to: inline scouts, repo-research-analyst, code reviewers, investigate sessions — every agent spawned in this repo."

### 6.3 Graph analyst agent

`agents/uncle-dev-ag-graph-analyst.md` — specialist for multi-hop traversal when ≥3 graph queries are needed. Receives `{question, focus_nodes, context: research|spec|planning|debug|review}`. Returns structured handoff with commands run, key relationships, low-confidence claims flagged for verification.

### 6.4 Spec-graph ↔ Graphify bridge

`build-spec-graph.py` writes `graphify-out/spec-edges.json` **only if `graphify-out/` already exists**. The bridge is one-way (spec-graph writes for graphify to consume), and the graphify CLI does **not** currently expose a way to query that spec-edges projection. The two graphs coexist but don't interoperate at the query layer.

### 6.5 Configuration today: hardcoded, not pluggable

Every consumer assumes fixed paths:

- `graphify-out/graph.json` — gate file
- `graphify-out/GRAPH_REPORT.md` — pre-query reading
- `docs/arrows/spec-graph.{json,mmd}`, `docs/arrows/SPEC_GRAPH_REPORT.md` — spec-graph outputs
- `docs/high-level-design.md`, `docs/llds/`, `docs/specs/`, `docs/arrows/index.yaml` — spec-graph inputs (`build-spec-graph.py:47-71`)
- Spec-coherence guard searches three locations for the script (`CLAUDE_PLUGIN_ROOT`, plugin cache, repo root) — `hooks/spec-coherence-guard.sh:123-126`

**There is no project-level configuration to point uncle-dev at:**

- Alternative graphify JSON paths
- Multiple graphify graphs (e.g., one per domain)
- Alternative spec roots
- A registry mapping graph names → file paths

This is the most concrete gap relative to the user's idea of "define paths to JSON files containing graphs generated by Graphify."

### 6.6 Hooks that enforce the spec/graph contract

`hooks/hooks.json` + `hooks/spec-coherence-guard.sh`:

- **PreToolUse Edit|Write**: extracts `@spec` IDs from new content; blocks (exit 2) on unknown IDs (lines 56-105).
- **PreToolUse Bash (`git commit`)**: runs full `scan-spec-coherence.py`; blocks commit on non-zero exit (lines 111-148).
- **Graceful adoption**: skips silently when `docs/specs/` does not exist (line 18).
- Other guards in `hooks.json`: `check-agents-md.sh`, `openspec-guard.sh`, `pre-commit-guard.sh`, `destructive-command-guard.sh`, `knowledge-capture-nudge.sh`, `session-start.sh`.

---

## 7. The Phase Model and Where a New Companion Would Slot

`CLAUDE.md:18-25` and `README.md:8-14` define phases. The relevant front-of-funnel today:

```
(no formal slot)  →  /uncle-dev-idea-refine  →  /uncle-dev-spec  →  /uncle-dev-design-docs  →  /uncle-dev-acknowledge  →  /uncle-dev-plan  →  /uncle-dev-next-task  →  /uncle-dev-build
                                                                                                                   ↑
                                                                                                  gates if pending acks exist in touched scopes
```

Specific findings on the "before specs" position:

- `/uncle-dev-idea-refine` produces a one-pager — ideation only.
- `/uncle-dev-spec-driven-development` starts at the **BASELINE phase** (`SKILL.md:40-154`), which assumes you already know what behavior you want to deliver; its own Phase 0 doesn't ask product questions, it captures current implementation state.
- `/uncle-dev-design-docs` scaffolds HLD/LLD/EARS — but assumes the segment and intent are already known.
- The acknowledge gate is **after** design, not before specs.

No skill currently:

- Reads a bug report or feature request and reframes it as "expected behavior" vs. "current behavior" before the spec is written.
- Cross-checks a proposed change against a durable business-rules registry.
- Detects drift between an external product-truth (PRDs, behavior maps) and the EARS catalog.

---

## 8. Agents in Place

`agents/` contains six persona files:

| Agent                                   | Spawned by                                                       | Purpose                                                                |
| --------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `uncle-dev-ag-repo-research-analyst.md` | `/uncle-dev-research`                                            | Pattern/structure analysis, writes handoff into `.uncle-dev/research/` |
| `uncle-dev-ag-graph-analyst.md`         | research / spec / planning / debug / review (when graph present) | Multi-hop graphify traversal, confidence-annotated handoff             |
| `uncle-dev-ag-code-reviewer.md`         | review workflows                                                 | Five-axis review                                                       |
| `uncle-dev-ag-test-engineer.md`         | build / test workflows                                           | Test strategy & coverage                                               |
| `uncle-dev-ag-security-auditor.md`      | review / security workflows                                      | Vulnerability / threat-model audit                                     |
| `uncle-dev-ag-review-synthesizer.md`    | review aggregation                                               | Consolidates multi-agent review                                        |

There is **no persona for product / domain reasoning** (e.g., "product analyst", "behavior auditor", "business-rules guardian").

---

## 9. Surfaces Relevant to Each Pillar of the Uncle Domain Vision

### Pillar A — "Domain & product companion sitting before specs"

- **Exists:** `uncle-dev-idea-refine` (ideation), `uncle-dev-feature-map` (reverse-engineered feature catalog).
- **Missing:** dedicated product-framing entry point; business-rules registry; behavior-map artifact; drift detector between expected vs. implemented behavior.

### Pillar B — "Configurable per-domain flavors"

- **Exists:** `.agents/uncle-dev-setup.yaml` with `skills.overrides.*`, `skills.companions.<phase>`, `preferences.*`, `hooks.*`.
- **Missing:** the notion of a _flavor_ / _domain pack_ that bundles skills + rules + frameworks + behavior maps + operational resources behind a single name; ability to activate a flavor; flavor-aware skill resolution.

### Pillar C — "Graphify integration with configurable JSON paths"

- **Exists:** mandatory subagent gate, graphify-aware protocol, graph-analyst persona, spec-graph builder, spec-edges.json projection into `graphify-out/`.
- **Missing:** any configuration mechanism to point uncle-dev at alternative or multiple graphify outputs; CLI ability to query the spec-edges projection; named-graph registry.

### Pillar D — "Annotation vocabulary (@spec @feature @rule @api @test @behavior @adr)"

- **Exists:** `@spec` only; scanner with multi-language AST adapters; ORPHAN/MISSING-TEST/MISSING-CODE classification; commit-time hook enforcement.
- **Missing:** every other annotation in the wishlist; the registries those annotations would point at (feature catalog, rules catalog, API contracts, behavior catalog, ADR index); scanner extensions; spec-graph node-type extensions; tracker coverage extensions.

### Pillar E — "Product Behavioral Operating System: continuous alignment"

- **Exists:** point-in-time coherence (spec-coherence-guard at edit + commit), point-in-time tracker regen (`/uncle-dev-openspec-sync`), point-in-time spec-graph build (`/uncle-dev-spec-graph`).
- **Missing:** any _continuous_ drift detection — there is no scheduled job, no background skill, no diffing artifact that asks "has expected behavior diverged from implemented behavior since last reconciliation?". The existing hooks are reactive guards (block bad edits/commits), not proactive alignment monitors.

---

## 10. Key Files Cited

- Configuration template: `skills/uncle-dev-setup/uncle-dev-setup.template.yaml:36-65`
- Skill anatomy convention: `CLAUDE.md:29-35`, `AGENT_RULES.md`
- Phase model: `CLAUDE.md:18-25`, `README.md:8-14`
- Pre-spec skills: `skills/uncle-dev-idea-refine/SKILL.md:1-50`, `skills/uncle-dev-feature-map/SKILL.md:1-84`
- Annotation surface: `skills/uncle-dev-spec-annotations/SKILL.md:1-315`, `resources/annotation-examples.md`, `resources/scanner-design.md`
- Scanner: `skills/uncle-dev-spec-annotations/scan-spec-coherence.py`
- Spec-graph builder: `skills/uncle-dev-spec-annotations/build-spec-graph.py` (esp. lines 5-11, 19-20, 47-71, 59-315, 330)
- Spec-graph command: `.claude/commands/uncle-dev-spec-graph.md`
- Design-architecture-docs: `skills/uncle-dev-design-architecture-docs/SKILL.md:56-76, 100-127, 154-192`
- Acknowledge mechanism: `skills/uncle-dev-acknowledge/SKILL.md:1-111`, `acknowledge-workflow.md`, `inference-rules.md:1-95`
- Graphify protocol: `skills/uncle-dev-graphify-aware-analysis/SKILL.md` (esp. lines 14-27, 91-101, 114-150, 167-173)
- Graphify mandatory rules: `CLAUDE.md:48-64`, `AGENTS.md:48-67`
- Graph analyst: `agents/uncle-dev-ag-graph-analyst.md` (lines 21-61)
- Hooks: `hooks/hooks.json`, `hooks/spec-coherence-guard.sh:1-160`
- Plugin packaging: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/uncle-dev/.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`
- Commands: `.claude/commands/uncle-dev-*.md` (19 files)
- Personas: `agents/uncle-dev-ag-*.md` (6 files)

---

## 11. Summary Table

| Pillar of Uncle Domain Vision           | Exists Today                                                                                                | Missing Today                                                                        |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Pre-spec product/domain reasoning skill | Ideation (`idea-refine`); feature reverse-discovery (`feature-map`)                                         | Product-framing skill; rules/behavior registry; drift detection                      |
| Per-domain "flavor" configuration       | Per-skill overrides; companion-skill path registry; boolean preference toggles                              | Flavor bundle concept; activation mechanism; flavor-aware resolution                 |
| Graphify integration                    | Mandatory subagent gate; query/explain/path protocol; graph-analyst persona; one-way spec-edges.json bridge | Configurable JSON paths; multi-graph registry; CLI query of spec-edges               |
| Annotation vocabulary                   | `@spec` only, with AST scanner + commit-time enforcement                                                    | `@feature`, `@rule`, `@api`, `@test`, `@behavior`, `@adr` and their backing catalogs |
| Continuous behavioral alignment         | Reactive coherence hooks at edit + commit; on-demand tracker/graph regen                                    | Continuous / scheduled drift detection between expected vs. implemented behavior     |

---

_End of research document. This file describes current state only; it does not propose how to close the gaps identified above._
