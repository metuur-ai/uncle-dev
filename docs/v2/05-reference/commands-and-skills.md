---
sidebar_position: 1
---

# 8. Skill and Command Reference

This reference lists every Uncle Dev skill and slash command, grouped by lifecycle phase. Use it to find which skill or command applies to a task.

For copy-paste prompt templates, see [Prompts by Phase](prompts-by-phase.md) and [Prompts by Skill](prompts-by-skill.md). This page is the complete index; those pages hold the fill-in-the-blank prompts.

## How to invoke

- **Skills:** ask the agent to use the skill by name — for example, `Use the uncle-dev-security-and-hardening skill.`
- **Commands:** type the slash command — for example, `/uncle-dev-spec`.

Some skills are also wired to a slash command (shown in the Command column below). Running the command is the same as invoking the skill.

## Skills by phase

### Define

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-research` | Documents the codebase as it exists today; spawns parallel subagents and writes a research map to `.uncle-dev/research/`. | `/uncle-dev-research` |
| `uncle-dev-idea-refine` | Refines a rough idea through divergent and convergent thinking. | — |
| `uncle-dev-grill` | Interviews you to pin down requirements, then synthesizes a PRD that feeds `/uncle-dev-spec`. | — |
| `uncle-dev-ubiquitous-language` | Builds and maintains a DDD-style glossary of canonical domain terms in `docs/ubiquitous-language.md`. | — |
| `uncle-dev-feature-map` | Catalogs product features by reading backend routes, controllers, services, and frontend pages; outputs a user-facing feature map. | — |
| `uncle-dev-spec-driven-development` | Defines requirements before coding; routes to LID+EARS mode or OpenSpec mode. | `/uncle-dev-spec` |
| `uncle-dev-design-architecture-docs` | Authors durable HLD and LLD documents that partition product intent into segments and feed EARS specs. | `/uncle-dev-design-docs` |
| `uncle-dev-acknowledge` | Captures design-decision notes — as gating notes in OpenSpec mode, or as ADRs in LID+EARS mode. | `/uncle-dev-acknowledge` |
| `uncle-dev-pre-mortem` | Imagines a plan has failed, then works backward to surface causes and preventions before a launch or risky decision. | — |

### Plan

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-planning-and-task-breakdown` | Breaks an approved OpenSpec change into ordered shared stories and execution notes. | `/uncle-dev-plan` |

### Build

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-incremental-implementation` | Delivers changes one verifiable slice at a time. | `/uncle-dev-build` |
| `uncle-dev-test-driven-development` | Drives development with tests written before implementation. | `/uncle-dev-test` |
| `uncle-dev-spec-annotations` | Connects durable product behavior to specs, tests, and code via `@spec` annotations. | `/uncle-dev-spec-annotations` |
| `uncle-dev-context-engineering` | Optimizes the agent's context setup — rules files, context hierarchy, and confusion recovery. | — |
| `uncle-dev-source-driven-development` | Grounds every implementation decision in official, source-cited documentation. | — |
| `uncle-dev-frontend-ui-engineering` | Builds production-quality UIs — components, layouts, state, and accessibility. | — |
| `uncle-dev-api-and-interface-design` | Designs stable APIs and module boundaries — REST, GraphQL, and type contracts. | — |

### Verify

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-browser-testing-with-devtools` | Tests in real browsers via Chrome DevTools MCP — DOM, console, network, performance. | — |
| `uncle-dev-debug-error` | Guides systematic root-cause debugging: reproduce, localize, fix, and guard against regression. | — |
| `uncle-dev-mutation-testing` | Assesses test-suite strength by introducing deliberate bugs and checking whether tests catch each one. | — |

### Review

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-code-review-and-quality` | Conducts a five-axis code review — correctness, readability, architecture, security, performance. | `/uncle-dev-review` |
| `uncle-dev-dev-code-simplification` | Simplifies code for clarity without changing behavior. | `/uncle-dev-code-simplify` |
| `uncle-dev-security-and-hardening` | Hardens code against vulnerabilities — input validation, auth, OWASP, threat modeling. | — |
| `uncle-dev-performance-optimization` | Optimizes performance — measure first, profile, fix bottlenecks, Core Web Vitals. | — |

### Ship

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-git-workflow-and-versioning` | Structures git workflow — atomic commits, branching, conflict resolution, clean history. | — |
| `uncle-dev-ci-cd-and-automation` | Automates CI/CD pipelines — quality gates, test runners, deployment strategies. | — |
| `uncle-dev-deprecation-and-migration` | Manages deprecation and migration — sunset old systems, migrate users, keep compatibility. | — |
| `uncle-dev-documentation-and-adrs` | Records decisions and documentation — ADRs, API docs, context for future engineers. | — |
| `uncle-dev-shipping-and-launch` | Prepares production launches — pre-launch checklist, monitoring, staged rollout, rollback. | `/uncle-dev-ship` |

### Capture

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-knowledge-capture` | Documents a recently solved problem into `.uncle-dev/learns/` while context is fresh. | `/uncle-dev-knowledge-capture` |

### Handoff

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-wrap` | Compacts the conversation into a handoff document under `.devlocal/handoffs/` so a fresh session can continue. | `/uncle-dev-wrap` |

### Maintain

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-knowledge-maintenance` | Reviews and refreshes `.uncle-dev/learns/` — update stale references, consolidate overlap, delete obsolete docs. | `/uncle-dev-knowledge-maintenance` |
| `uncle-dev-custom-me` | Authors and registers a user-defined override or companion skill without duplicating the bundled skill's content. | `/uncle-dev-custom-me` |

### Meta and tooling

| Skill | Purpose | Command |
|-------|---------|---------|
| `uncle-dev-setup` | Wires Uncle Dev into a project for Claude Code, Codex, or OpenCode — plugin install, directories, config, hooks, rules. | `/uncle-dev-setup` |
| `uncle-dev-using-agent-skills` | The meta-skill that governs how all other skills are discovered and invoked. | — |
| `uncle-dev-next-task` | Picks the next actionable task — from `docs/tasks/` in LID+EARS mode, or from OpenSpec changes in OpenSpec mode. | `/uncle-dev-next-task` |
| `uncle-dev-graphify-aware-analysis` | Shared protocol for querying the graphify semantic knowledge graph inside other skills. | — |
| `uncle-dev-code-context` | Converted to the "Code Context" rule in CLAUDE.md. See `uncle-dev-context-engineering` for the context hierarchy strategy. | — |

## Commands

Every slash command, alphabetized. Commands not paired with a phase skill above are listed here in full.

| Command | Purpose |
|---------|---------|
| `/uncle-dev-acknowledge` | Capture and manage design-decision notes (OpenSpec or ADR mode). |
| `/uncle-dev-build` | Implement the next task incrementally — build, test, verify, commit. |
| `/uncle-dev-code-simplify` | Simplify code for clarity without changing behavior. |
| `/uncle-dev-custom-me` | Scaffold a user-authored override or companion skill and print the registration YAML for `.agents/uncle-dev-setup.yaml`. |
| `/uncle-dev-design-docs` | Scaffold HLD, LLD, and arrow docs for product behavior segments. |
| `/uncle-dev-knowledge-capture` | Document a recently solved problem into `.uncle-dev/learns/` while context is fresh. |
| `/uncle-dev-knowledge-maintenance` | Review and refresh `.uncle-dev/learns/` for accuracy. |
| `/uncle-dev-next-task` | Pick the next ready task (LID+EARS or OpenSpec mode). |
| `/uncle-dev-openspec-sync` | Regenerate the OpenSpec global change tracker (OpenSpec mode only). |
| `/uncle-dev-plan` | Break work into small verifiable tasks with acceptance criteria and dependency ordering. |
| `/uncle-dev-proactive-memory` | Surface organizational learnings from past memory when a memory match occurs. |
| `/uncle-dev-research` | Research the codebase as-is and write a documented map to `.uncle-dev/research/`. |
| `/uncle-dev-review` | Conduct a five-axis code review. |
| `/uncle-dev-setup` | Wire Uncle Dev into the current project (plugin, directories, config, hooks, rules). |
| `/uncle-dev-ship` | Run the pre-launch checklist and prepare for production deployment. |
| `/uncle-dev-spec` | Start spec-driven development — define requirements before writing code. |
| `/uncle-dev-spec-annotations` | Add, verify, or audit `@spec` traceability links between behavior, specs, tests, and code. |
| `/uncle-dev-spec-graph` | Build the spec graph from HLD, LLDs, EARS specs, and `@spec` annotations into `graphify-out/`. |
| `/uncle-dev-spec-scan` | Validate `@spec` annotations and report orphans, missing tests, and missing code. |
| `/uncle-dev-test` | Run the TDD workflow; for bugs, use the Prove-It pattern. |
| `/uncle-dev-wrap` | Compact the conversation into a handoff document under `.devlocal/handoffs/`. |
| `/uncle-senior` | Senior principal engineer in Challenge mode (structured verdict) or Duck mode (rubber-duck conversation). Usage: `/uncle-senior [--duck | duck]`. |
