---
title: "uncle-dev Capabilities Reference"
description: "Complete reference for the uncle-dev plugin — every slash command, agent persona, and skill, organized for quick lookup."
---

# uncle-dev Capabilities Reference

`uncle-dev` is a Claude Code plugin (`version 1.4.0`, MIT) that packages production-grade engineering workflows for AI coding agents. It ships **22 slash commands**, **9 agent personas**, and **39 skills** covering the full software development lifecycle: **Define → Plan → Build → Verify → Review → Ship → Capture → Handoff → Maintain**.

This page is a lookup reference. For setup, see [docs/getting-started.md](../getting-started.md); for the conceptual flow, see [docs/05-idea-to-deploy-flow.md](../05-idea-to-deploy-flow.md).

## How the Pieces Fit

| Layer | What it is | How it activates |
|-------|------------|------------------|
| **Commands** | Explicit slash commands you type | You run `/uncle-dev-<name>` |
| **Agents** | Specialist personas spawned for focused work | Invoked by name (`@uncle-lead`) or spawned by an orchestrating command |
| **Skills** | Workflow knowledge loaded into context | Activated by a command, or auto-triggered by what you're doing |
| **Hooks** | Session lifecycle guards | Run automatically (session start, pre-commit, pre-tool-use) |

Commands orchestrate skills and agents. Skills also self-activate based on the task — designing an API triggers `uncle-dev-api-and-interface-design`, building UI triggers `uncle-dev-frontend-ui-engineering`.

---

## Commands

Slash commands map to the development lifecycle. Each activates the relevant skills automatically.

### Define and Plan

| Command | What it does |
|---------|--------------|
| `/uncle-dev-research` | Explore the codebase as-is with parallel subagents; write a documented map to `.uncle-dev/research/` |
| `/uncle-dev-spec` | Start spec-driven development — define requirements before writing code |
| `/uncle-dev-design-docs` | Scaffold HLD, LLD, and arrow docs for product behavior segments |
| `/uncle-dev-acknowledge` | Capture and manage design-decision notes (`openspec/acknowledge/` or `docs/decisions/` ADRs) |
| `/uncle-dev-plan` | Break work into small verifiable tasks with acceptance criteria and dependency ordering |
| `/uncle-dev-next-task` | Pick the next ready task from `docs/tasks/` or OpenSpec changes |

### Build and Verify

| Command | What it does |
|---------|--------------|
| `/uncle-dev-build` | Implement the next task incrementally — build, test, verify, commit |
| `/uncle-dev-test` | Run the TDD workflow — write failing tests, implement, verify; use the Prove-It pattern for bugs |
| `/uncle-dev-spec-annotations` | Connect durable behavior to specs, tests, and code via `@spec` annotations |
| `/uncle-dev-spec-scan` | Validate `@spec` annotations against `docs/specs/`; report orphans, missing tests, and missing code |
| `/uncle-dev-spec-graph` | Build the spec graph (HLD + LLDs + EARS + `@spec`) into JSON, Mermaid, HTML, and a human report |

### Review and Ship

| Command | What it does |
|---------|--------------|
| `/uncle-dev-review` | Conduct a five-axis code review — correctness, readability, architecture, security, performance |
| `/uncle-dev-code-simplify` | Reduce complexity for clarity and maintainability without changing behavior |
| `/uncle-senior` | Senior principal engineer — Challenge mode (structured verdict) or Duck mode (rubber-duck conversation) |
| `/uncle-dev-ship` | Run the pre-launch checklist and prepare for production deployment |

### Capture, Handoff, and Maintain

| Command | What it does |
|---------|--------------|
| `/uncle-dev-knowledge-capture` | Document a recently solved problem into `.uncle-dev/learns/` while context is fresh |
| `/uncle-dev-knowledge-maintenance` | Review and refresh `.uncle-dev/learns/` — update stale references, consolidate, delete obsolete docs |
| `/uncle-dev-proactive-memory` | Surface relevant organizational learnings when a memory match occurs |
| `/uncle-dev-wrap` | Compact the conversation into a handoff document under `.devlocal/handoffs/` |

### Setup and Configuration

| Command | What it does |
|---------|--------------|
| `/uncle-dev-setup` | Wire uncle-dev into a project (plugin install, directories, config, hooks, rules) |
| `/uncle-dev-custom-me` | Scaffold a user-authored override or companion skill and print the registration YAML |
| `/uncle-dev-openspec-sync` | Regenerate the OpenSpec global change tracker (openspec mode only) |

---

## Agents

Agents are specialist personas. Some you invoke directly; others are spawned by orchestrating commands and are not meant for direct invocation.

### Directly Invokable

| Agent | Role |
|-------|------|
| `uncle-senior` | Senior principal engineer for design challenges and rubber-duck thinking. Trigger on "is this over-engineered?", "should we use X or Y?", or any uncommitted design decision |
| `uncle-lead` | Technical Lead for architecture decisions, design documents, package boundaries, and technical review. Invoke with `@uncle-lead` |
| `uncle-po` | Product Owner for requirements, proposals, and acceptance criteria. Invoke with `@uncle-po` |
| `uncle-dev-ag-code-reviewer` | Senior code reviewer evaluating correctness, readability, architecture, security, and performance |
| `uncle-dev-ag-security-auditor` | Security engineer for vulnerability detection, threat modeling, and secure-coding recommendations |
| `uncle-dev-ag-test-engineer` | QA engineer for test strategy, test writing, and coverage analysis |

### Spawned by Orchestrators

These run as subagents inside larger workflows and return structured handoffs. They are not for direct user invocation.

| Agent | Role |
|-------|------|
| `uncle-dev-ag-repo-research-analyst` | Analyzes repository structure, patterns, and conventions into a structured handoff |
| `uncle-dev-ag-graph-analyst` | Multi-query semantic graph traversal via graphify; returns annotated findings with confidence levels |
| `uncle-dev-ag-review-synthesizer` | Merges parallel review-agent findings into one verdict, a deduplicated issue list, and a PR summary |

---

## Skills

Skills carry the workflow knowledge. They activate through a command, by auto-trigger, or by explicit invocation. Grouped by lifecycle phase.

### Define

| Skill | What it does |
|-------|--------------|
| `uncle-dev-research` | Documents the codebase as it exists today via parallel subagent exploration |
| `uncle-dev-idea-refine` | Refines ideas through structured divergent and convergent thinking |
| `uncle-dev-grill` | Interviews you branch-by-branch to build a shared design concept, then synthesizes a PRD |
| `uncle-dev-ubiquitous-language` | Builds a DDD-style glossary of canonical domain terms in `docs/ubiquitous-language.md` |
| `uncle-dev-feature-map` | Catalogs product features from routes, controllers, services, and frontend pages |
| `uncle-dev-spec-driven-development` | Drives spec definition before code; routes to LID+EARS mode or OpenSpec mode |
| `uncle-dev-design-architecture-docs` | Authors durable HLD and LLD documents that partition intent into segments feeding EARS specs |
| `uncle-dev-acknowledge` | Captures design-decision notes as gating decisions or ADRs |

### Evaluate

| Skill | What it does |
|-------|--------------|
| `uncle-senior` | Challenge or Duck mode review of a proposed approach before it becomes code |
| `uncle-dev-pre-mortem` | Imagines a plan has failed and works backward to surface hidden risks and preventions |

### Plan

| Skill | What it does |
|-------|--------------|
| `uncle-dev-planning-and-task-breakdown` | Breaks an approved OpenSpec change into ordered shared stories and execution notes |
| `uncle-dev-next-task` | Computes a parallel-safe ready set of tasks and surfaces conflicts |

### Build

| Skill | What it does |
|-------|--------------|
| `uncle-dev-incremental-implementation` | Delivers changes in small, verifiable slices instead of one large drop |
| `uncle-dev-test-driven-development` | Proves code works by writing tests first |
| `uncle-dev-spec-annotations` | Links durable behavior to specs, tests, and code via `@spec` annotations |
| `uncle-dev-context-engineering` | Optimizes agent context — rules files, context hierarchy, AGENTS.md setup |
| `uncle-dev-code-context` | (Now a rule.) Enforces reading local AGENTS.md and respecting architecture boundaries before edits |
| `uncle-dev-source-driven-development` | Grounds every implementation decision in official, cited documentation |
| `uncle-dev-frontend-ui-engineering` | Builds production-quality UIs — components, layouts, state, accessibility |
| `uncle-dev-api-and-interface-design` | Designs stable APIs and module boundaries — REST, GraphQL, type contracts |

### Verify

| Skill | What it does |
|-------|--------------|
| `uncle-dev-browser-testing-with-devtools` | Tests in real browsers via Chrome DevTools MCP — DOM, console, network, performance |
| `uncle-dev-debug-error` | Guides systematic root-cause debugging instead of guessing |
| `uncle-dev-mutation-testing` | Measures test-suite strength by injecting deliberate bugs and checking detection |

### Review

| Skill | What it does |
|-------|--------------|
| `uncle-dev-code-review-and-quality` | Multi-axis code review before any change merges |
| `uncle-dev-dev-code-simplification` | Reduces accumulated complexity without changing behavior |
| `uncle-dev-security-and-hardening` | Hardens code against vulnerabilities — input validation, auth, OWASP, threat modeling |
| `uncle-dev-performance-optimization` | Measures first, profiles, then fixes bottlenecks and Core Web Vitals |

### Ship

| Skill | What it does |
|-------|--------------|
| `uncle-dev-git-workflow-and-versioning` | Structures atomic commits, branching, conflict resolution, and clean history |
| `uncle-dev-ci-cd-and-automation` | Automates quality gates, CI test runners, and deployment strategies |
| `uncle-dev-deprecation-and-migration` | Sunsets old systems and migrates users while maintaining compatibility |
| `uncle-dev-documentation-and-adrs` | Records architectural decisions and durable context for future engineers |
| `uncle-dev-shipping-and-launch` | Prepares production launches — pre-launch checklist, monitoring, staged rollout, rollback |

### Capture, Handoff, and Maintain

| Skill | What it does |
|-------|--------------|
| `uncle-dev-knowledge-capture` | Captures solved problems as searchable docs in `.uncle-dev/learns/` |
| `uncle-dev-wrap` | Compacts the conversation into a handoff doc so a fresh session can continue |
| `uncle-dev-knowledge-maintenance` | Keeps `.uncle-dev/learns/` accurate over time — review, consolidate, replace, delete |
| `uncle-dev-custom-me` | Authors and registers user-defined override or companion skills |

### Meta and Infrastructure

| Skill | What it does |
|-------|--------------|
| `uncle-dev-using-agent-skills` | Meta-skill governing how all other skills are discovered and invoked |
| `uncle-dev-setup` | Wires uncle-dev into a project across Claude Code, Codex, and OpenCode |
| `uncle-dev-graphify-aware-analysis` | Shared protocol for querying the graphify knowledge graph; referenced by other skills, not invoked directly |

---

## Lifecycle Hooks

Hooks live in `hooks/` and run automatically at session lifecycle points. They are not invoked manually.

| Hook | Trigger | Purpose |
|------|---------|---------|
| `session-start.sh` | Session start | Load the skill-discovery flowchart and project context |
| `check-agents-md.sh` | Pre-edit | Ensure a source directory has an `AGENTS.md` before edits |
| `spec-coherence-guard.sh` | Pre-tool-use | Block edits/commits that cite undefined `@spec` IDs |
| `openspec-guard.sh` | Pre-tool-use | Enforce OpenSpec workflow rules |
| `pre-commit-guard.sh` | Pre-commit | Gate commits that fail quality checks |
| `destructive-command-guard.sh` | Pre-tool-use | Warn on or block destructive shell commands |
| `simplify-ignore.sh` | Code-simplify | Respect `SIMPLIFY-IGNORE` markers during simplification |
| `knowledge-capture-nudge.sh` | Post-solve | Nudge to capture a learning after a problem is solved |
| `wrap-nudge.sh` | High context | Suggest `/uncle-dev-wrap` when context fills up |
| `gate-notify.sh` / `permission-notify.sh` | Various | Surface gate and permission events |

---

## Related

- [docs/getting-started.md](../getting-started.md) — Install and first-run setup
- [docs/01-what-is-uncle-dev.md](../01-what-is-uncle-dev.md) — Concept overview
- [docs/05-idea-to-deploy-flow.md](../05-idea-to-deploy-flow.md) — End-to-end lifecycle walkthrough
- [docs/06-prompts-by-phase.md](../06-prompts-by-phase.md) — Prompts organized by phase
- [docs/skill-anatomy.md](../skill-anatomy.md) — How an individual skill is structured
- [docs/03-sdd-and-openspec.md](../03-sdd-and-openspec.md) — Spec-driven development and OpenSpec model
