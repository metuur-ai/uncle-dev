# 1. What is Uncle Dev and Why it Works with SDD

## Overview

**Uncle Dev** is an engineering-skills pack for AI coding agents. Agents like Claude Code, Cursor, Copilot, and OpenCode tend to skip specs, omit architecture design, skip testing, and emit large unreviewed code blocks.

**Uncle Dev** applies a structured, step-by-step workflow to every phase of software development, so the agent follows senior-engineer practices instead of its default behaviors.

## The Problem with Default AI Agents
When a developer says, "Build me a login page," a vanilla AI agent will immediately output HTML, CSS, and database queries. It guesses the architecture, guesses the edge cases, and often hallucinates business logic. This leads to:
- "Prototype-quality" code that breaks in production.
- Refactoring nightmares where the developer spends more time fixing AI code than they would have spent writing it from scratch.
- Loss of project context over time.

## The Solution: Spec-Driven Development (SDD)
Uncle Dev forces the agent to use Spec-Driven Development (SDD).

### Why SDD Works:
1. **Alignment Before Execution:** SDD mandates that the AI agent must write and agree upon a specification document with the developer *before* writing a single line of application code. This acts as a quality gate.
2. **Context Retention:** Instead of relying purely on conversational history (which degrades over time and uses massive amounts of tokens), SDD externalizes memory into markdown files (like `proposal.md` and `design.md`). The AI can re-read these documents to instantly regain total context.
3. **Controlled Scope:** The agent breaks the specification into an atomic task checklist and implements one slice of the application at a time, testing each slice before moving on.
4. **Anti-Rationalization:** Uncle Dev skills contain specific "anti-rationalization tables." If an AI agent attempts to say, "This is too small for a test, I'll skip it," the Uncle Dev skill forcefully overrides this behavior, ensuring discipline is maintained.

By enforcing SDD, Uncle Dev ties implementation back to an agreed spec, which improves test coverage, security review, and architectural consistency.

---

# 2. Uncle Dev Installation Guide

Uncle Dev is modular and can be installed into a variety of popular AI coding tools. This guide details how developers can set up these skills.

## Claude Code (Recommended)
Claude Code is a CLI agent with plugin support.

**Via Marketplace:**
```bash
/plugin install uncle-dev@uncle-dev-agent-skills
```

**Local/Development Install (from cloned repo):**
```bash
git clone https://github.com/addyosmani/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

## Cursor
Cursor IDE reads instruction rules from the `.cursor/rules/` directory.

**Installation:**
You can manually copy whichever `SKILL.md` you want to use into your Cursor rules folder, or use the automated script:
```bash
./scripts/install-plugin.sh cursor ~/path/to/your/project
```
This script maps the skills (e.g., `uncle-dev-code-review-and-quality`) into `.cursor/rules/` where Cursor will pick them up automatically for review contexts.

## OpenCode
OpenCode uses an AI-agent-driven skill execution environment via an `AGENTS.md` configuration.

**Global Installation:**
```bash
./scripts/install-opencode.sh --scope global
```
**Local Project Installation:**
```bash
./scripts/install-opencode.sh --scope local .
```
This populates `.config/opencode/` with the AGENTS system prompting file, ensuring the agent routes your commands.

## GitHub Copilot
Copilot reads agent personas from `.github/` directories.

**Installation:**
```bash
./scripts/install-plugin.sh copilot ~/path/to/your/project
```
This registers the Uncle Dev personas like `@code-reviewer`, `@security-auditor`, and `@uncle-lead` into your repositories so that Copilot Chat can roleplay as these senior engineers.

## Gemini CLI
You can natively install skills to your Gemini CLI.
```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

## Manual / Other LLMs
Because Uncle Dev skills are just well-structured Markdown (`.md`) files, you can copy the contents of any `SKILL.md` and paste it directly into your chat with ChatGPT, Claude Web, or any other agent to apply the workflow.

## Graphify (Optional — Semantic Graph Search)

If you want uncle-dev skills to use semantic graph traversal instead of grep for architecture research, dependency mapping, and impact analysis, install graphify and build a graph for your project:

```bash
# Install graphify CLI
pip install graphifyy

# Build the knowledge graph (run from your project root)
graphify .
# Creates graphify-out/graph.json, GRAPH_REPORT.md, graph.html

# Keep it current after code changes (no LLM cost)
graphify update src/
```

Once `graphify-out/graph.json` exists, all uncle-dev skills activate graph-first search automatically at startup. No other configuration is needed.

---

# 3. Why Use Spec-Driven Development (SDD) & OpenSpec

The foundation of the Uncle Dev workflow relies on **Spec-Driven Development (SDD)** and the **OpenSpec** standard.

## Spec-Driven Development Explained
SDD flips the AI agent's timeline. Instead of:
> Goal -> Code -> Refactor -> Test

SDD enforces:
> Goal -> Specify -> Plan -> Code -> Verify

Generating AI code is cheap; the expensive part is verifying, reading, and debugging it. SDD makes the agent reason about edge cases, data schemas, and architecture before it writes the code. This prevents architectural drift and saves developer time.

## The OpenSpec Standard
OpenSpec provides a strict directory structure designed to separate the current state of a project from works-in-progress.

### 1. The `openspec/specs/` Directory
This directory serves as the **Project Truth**. It contains the living documentation of how the application works *today*. 
- Architecture decisions
- Domain models
- API endpoints specs

Before an AI agent builds a new feature, SDD forces it to read `openspec/specs/` to understand the existing constraints. 

### 2. The `openspec/changes/<change-id>/` Directory
This folder stores the lifecycle of a new feature undergoing development.
When you trigger `/uncle-dev-spec`, the agent will output artifacts here:
- **`proposal.md`**: What are we building and why?
- **`design.md`**: How will the database tables and APIs look?
- **`tasks.md`**: A strict checklist of atomic implementation slices.
- **`execution.md`**: Tracking progress.

### The Lifecycle Benefit
Once a feature is successfully implemented via the `tasks.md` checklist, the new updates from the *change* folder are reconciled back into the main `openspec/specs/` folder, constantly updating the single source of truth for the project.

---

# 4. The Power of the `.devlocal` Directory

In the Uncle Dev workflow, you'll encounter the `.devlocal/` workspace (sometimes referenced as localDev). Understanding its purpose is critical for clean, disciplined AI-assisted engineering.

## What is `.devlocal/`?
The `.devlocal/` directory is essentially a **private scratchpad** and sandbox tailored explicitly for the AI agent (and the human pair programmer). 

It is designed to be **excluded from version control** (always add `.devlocal/` to your `.gitignore`).

## Why We Need It

### 1. Separation of Concerns
The `openspec/` folders hold shared, canonical truth intended for the entire engineering team to read. In contrast, the `.devlocal/` directory is for messy, transient, mid-development thought processes. We do not want to pollute production repositories with a machine's brainstorming.

### 2. Private Execution Plans
When you execute `/uncle-dev-plan`, the AI agent will break down the macroscopic user-story tasks into extremely granular steps. These checklists are often placed in `.devlocal/scratchpads/` or `.devlocal/executions.md`. As the AI works, it ticks off checkboxes here. Once the task is complete, this temporary checklist becomes obsolete and can be safely ignored or deleted.

### 3. Debugging and Logs
During the **Verify** phase (`/uncle-dev-test` and `/uncle-dev-debug-error`), the AI agent might output massive command line logs, performance profiles, temporary JSON data dumps, or error tracebacks. Storing these inside `.devlocal/` keeps the root directory of your app clean.

### 4. Bypassing CI/CD Triggers
Many automated tooling environments watch the file system for changes. If the AI agent is saving temporary tracking documents continuously during its build phase, it might invoke thousands of unnecessary hot-reloads or CI test runs. Keeping these in a dedicated `.devlocal/` folder allows you to tell file-watchers to ignore them entirely.

---

# 5. The Flow: From Idea to Deploy

The Uncle Dev lifecycle enforces a strict sequence of events. Each phase must be completed before moving to the next.

```text
  DEFINE            PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────────┐     ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ OpenSpec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  Change  │     │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────────┘     └──────┘      └──────┘      └──────┘      └──────┘
   /spec           /plan          /build        /test         /review       /ship
```

### Phase 1: Idea Refinement
Before you even touch code, you might need help figuring out *what* to build. Using the `uncle-dev-idea-refine` skill, you and the AI agent challenge assumptions, discover risk factors, and settle on a minimum viable product configuration.

### Phase 2: Define (`/uncle-dev-spec`)
Instead of beginning implementation, the AI agent authors a strict `proposal.md` and `design.md` stored inside the `openspec/changes/` directory. The developer reads the architecture, the database schema design, and the edge cases. Once the human developer approves, you move forward.

### Phase 3: Plan (`/uncle-dev-plan`)
The agent takes the approved spec and decomposes it into shared story-level tasks (`tasks.md`). It also sets up a temporary checklist inside `.devlocal/` to track its own implementation steps. At this stage, you now have a step-by-step roadmap to completion.

### Phase 4: Build (`/uncle-dev-build`)
The agent executes code implementation one vertical slice at a time. This phase automatically kicks off skills like `uncle-dev-incremental-implementation`, `uncle-dev-frontend-ui-engineering`, and `uncle-dev-api-and-interface-design` depending on what part of the stack is being touched.

### Phase 5: Verify (`/uncle-dev-test` & Debugging)
The AI writes unit, integration, and end-to-end tests to verify its build slice. If the tests break, it pivots to the `uncle-dev-debug-error` skill. It uses a scientific method to reproduce, localize, reduce, and fix bugs rather than blindly guessing syntax updates.

### Phase 6: Review (`/uncle-dev-review`)
Before committing, the agent dons the persona of a Senior Staff Engineer. It scans the diff using the `uncle-dev-code-review-and-quality` and `uncle-dev-security-and-hardening` frameworks, assigning NIT, Optional, or Block tags to its own code and refactoring appropriately. (This is also the phase to invoke `/uncle-dev-code-simplify`).

### Phase 7: Ship (`/uncle-dev-ship`)
The feature reaches completion. The agent updates main `openspec/specs/` to reconcile the changes, manages deprecation lifecycles if necessary, ensures the test pipeline passes, and prepares deployment configurations.

---

# 6. Templates and Prompts: By Phase

These are prompt templates to utilize the core slash-command lifecycle from Uncle Dev inside your agent chat. Copy and paste them, filling in the bracketed metadata as needed.

## Phase 1: Define (`/uncle-dev-spec`)
**Goal:** Generate architecture, schema, and API boundaries.
> `/uncle-dev-spec`
> We need to build a new feature: [Feature Description: e.g., a real-time notification dropdown in the navbar]. 
> Key constraints: 
> 1. [Constraint 1: Must use WebSockets]
> 2. [Constraint 2: Must gracefully degrade on bad network connections]
> Create the proposal and design specs in `openspec/changes/`.

## Phase 2: Plan (`/uncle-dev-plan`)
**Goal:** Break the design down into actionable atomic checklists.
> `/uncle-dev-plan`
> Based on the approved design we just created for the [Feature name] feature, break this down into actionable, atomic tasks. Put the high-level tasks in the OpenSpec folder, and initialize a scratchpad execution checklist for yourself in `.devlocal/`.

## Phase 3: Build (`/uncle-dev-build`)
**Goal:** Write iterative vertical slices.
> `/uncle-dev-build`
> Let's implement Task [X] from our execution plan: [Task Name, e.g., "Build the backend WebSocket handler"]. Please slice this implementation thinly. Focus on safe defaults and do not move on to the next task until we have confirmed this slice works.

## Phase 4: Verify (`/uncle-dev-test`)
**Goal:** Prove the code works via tests.
> `/uncle-dev-test`
> Based on the code slice we just built, implement tests following the Testing Pyramid strategy. Ensure you have mocked the [External Service/Database Hook] and focus on edge cases like [Specific Edge Case: network timeouts]. Run the tests and confirm they pass.

## Phase 5: Review (`/uncle-dev-review`)
**Goal:** Quality gate before a merge.
> `/uncle-dev-review`
> Act as a Senior Staff Engineer and review the uncommitted changes for this codebase. Perform a 5-axis review focusing heavily on performance, readability, and security gaps. Let me know what needs fixing before we commit.
> 
> *(Optional cleanup)*: `/uncle-dev-code-simplify` Apply the Rule of 500 to the `[File name]` module. The logic is too hard to read. Simplify it while strictly maintaining exact behavior.

## Phase 6: Ship (`/uncle-dev-ship`)
**Goal:** Merge and deploy.
> `/uncle-dev-ship`
> The feature is complete. Help me walk through our pre-launch checklist. Reconcile our updates from the change artifact back into the main `openspec/specs/` directory to update our core documentation, and write a detailed commit message.

---

# 7. Templates and Prompts: By Skill

In the Uncle Dev plugin pack, skills can be explicitly invoked when you run into a specific niche problem that isn't tied directly to the main SDD flow sequence.

## Idea Refinement (`uncle-dev-idea-refine`)
**Use when refining a rough idea before you spec it.**
> `Use the uncle-dev-idea-refine skill.`
> I have a rough idea for [Idea: a real-time collaborative dashboard] but I'm not sure about the [Aspect: backend architecture]. Help me stress-test the assumptions and find the riskiest parts.

## Frontend UI Engineering (`uncle-dev-frontend-ui-engineering`)
**Use when building accessible, responsive UI.**
> `Use the uncle-dev-frontend-ui-engineering skill.`
> I need to build a responsive [Component: Dashboard Sidebar] component. Ensure that it aligns with our current design tokens, passes WCAG 2.1 AA accessibility (keyboard navigation and ARIA), and manages state cleanly without unnecessary top-level re-renders.

## API and Interface Design (`uncle-dev-api-and-interface-design`)
**Use when designing module boundaries, APIs, or database interactions.**
> `Invoke uncle-dev-api-and-interface-design.`
> Help me design the REST endpoints for a [Service/Feature: shopping cart checkout service]. Apply contract-first design principles. What should the request payloads, response bodies, and specific HTTP error semantics look like?

## Context Engineering (`uncle-dev-context-engineering`)
**Use when the AI agent starts losing track of what it's doing.**
> `Invoke uncle-dev-context-engineering.`
> We're shifting focus from the backend architecture to the frontend UI. Let's dump our current context limit. Please retrieve the necessary architectural rules from `openspec/specs/` relevant to the UI state management and summarize our current execution steps so we can continue cleanly.

## Browser Testing with DevTools (`uncle-dev-browser-testing-with-devtools`)
**Use when there is a runtime bug on the web interface.**
> `Trigger uncle-dev-browser-testing-with-devtools.`
> The web application is throwing an error when I try to submit the [Form: Payment configuration] form. Use the MCP to inspect the DOM state during the click, read the console logs, and review the failed network payloads. Describe the issue.

## Security & Hardening (`uncle-dev-security-and-hardening`)
**Use when touching auth, payments, or sensitive data.**
> `Run the uncle-dev-security-and-hardening skill.`
> Review the new [File: user-session.ts] API route we just created. Audit it for OWASP Top 10 vulnerabilities, ensure database interactions are parameterized against SQL injection, and review boundary validation logic.

## Knowledge Capture (`uncle-dev-knowledge-capture`)
**Use after an excruciating debugging session to secure the win.**
> `We finally fixed the bug! Trigger uncle-dev-knowledge-capture.`
> Document the exact root cause of the [Bug description: caching race-condition we faced in Redis] and lay out the solution as a formal learning in `.uncle-dev/learns/`.

## Graphify-Aware Analysis (`uncle-dev-graphify-aware-analysis`)
**Use to query the semantic knowledge graph for architecture research, impact analysis, and story boundary detection. Requires `graphify-out/graph.json` to exist.**
> `Use uncle-dev-graphify-aware-analysis to orient the investigation.`
> Before we spec the [Feature] change, check `graphify-out/GRAPH_REPORT.md` for god nodes, then run `graphify explain "[PrimaryModule]"` and `graphify query "[change area]"` to map the structural scope.

## Performance Optimization (`uncle-dev-performance-optimization`)
**Use when the application performs sluggishly.**
> `Use uncle-dev-performance-optimization.`
> The [Page Name: Product Listing] page is reporting bad Core Web Vitals, specifically LCP and CLS. Suggest a measurement strategy, help me profile the component's bundle, and identify React re-render anti-patterns or blocking scripts.
