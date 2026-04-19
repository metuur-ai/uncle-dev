# Uncle Dev: Production-Grade Agent Skills Guide

Welcome to the comprehensive guide for **Uncle Dev**, a powerful collection of production-grade engineering skills designed to elevate your AI coding agents. 

This document explains the core philosophy behind Uncle Dev, how to install and leverage its Spec-Driven Development (SDD) methodology, and provides actionable templates to use at every phase of your software development lifecycle.

---

## 1. What is Uncle Dev and why does it work with SDD?

**Uncle Dev** is an opinionated plugin pack for AI coding agents (such as Claude Code, Cursor, Copilot, and OpenCode). It provides agents with structured, senior-level engineering workflows. Instead of letting AI generate raw, untested code from a single vague prompt, Uncle Dev enforces discipline.

**Why it works with SDD (Spec-Driven Development):**
AI agents often choose the shortest path to completion, resulting in "prototype-quality" code that lacks tests, security reviews, and proper architecture. Uncle Dev binds the AI to **Spec-Driven Development**. Before any code is written, the agent is forced to define the problem in a specification document. SDD ensures the agent aligns with the developer on architecture, requirements, and edge cases *first*, dramatically reducing hallucinations and costly refactoring later.

---

## 2. Who and How to Install It?

Uncle Dev is designed for developers who want their AI agents to act like Senior Staff Engineers rather than eager junior developers. 

**Installation Methods:**

- **Claude Code (Recommended):**
  Use the marketplace or install locally:
  ```bash
  /plugin install uncle-dev@uncle-dev-agent-skills
  # OR from the cloned repo:
  claude --plugin-dir /path/to/agent-skills
  ```

- **Cursor:**
  Copy the skill files (`skills/uncle-dev-*/SKILL.md`) into your `.cursor/rules/` directory or use the provided installation scripts.

- **OpenCode:**
  Use the CLI installer:
  ```bash
  ./scripts/install-opencode.sh --scope global
  ```

- **Gemini CLI:**
  ```bash
  gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
  ```

For detailed setup guides for windsurf, copilot, and others, refer to the `docs/` directory in the repository.

---

## 3. Why use SDD and OpenSpec?

**Spec-Driven Development (SDD)** is the antidote to AI code chaos. Working with an AI agent should be approached like delegating to a team member: you need a shared understanding of the goal.

**OpenSpec** is the specific filesystem format used to maintain that shared understanding:
- **`openspec/specs/`**: Contains the current "project truth" (e.g., architecture, domain models).
- **`openspec/changes/<change-id>/`**: Contains artifacts for work-in-progress (e.g., `proposal.md`, `design.md`, `tasks.md`).

Using SDD and OpenSpec guarantees:
1. **Traceability:** You know *why* a piece of code was written.
2. **Alignment:** You approve the architecture before the agent spends tokens pumping out thousands of lines of code.
3. **Context Retention:** The AI agent can read the markdown specs at any time to regain context about the feature it's building.

---

## 4. Why should we use the `.devlocal/` directory?

In the Uncle Dev workflow, the `.devlocal/` (often referred to as local dev workspace) directory serves as the **disposable personal workspace** for your AI agent to think, plan, and calculate.

**Why use it?**
- **Scratchpads:** Agents need a place to map out algorithms, note temporary constraints, or dump research without polluting the main repository.
- **Private Execution Plans:** While `openspec/changes/tasks.md` stores shared, formal stories, the `.devlocal/` directory holds the gritty, mid-session execution checklists.
- **Git Ignored:** This folder is explicitly added to `.gitignore`. It prevents messy "AI thoughts" or mid-task artifacts from being accidentally committed to your pristine codebase.

---

## 5. The Flow: From Idea to Deploy

Uncle Dev maps perfectly to a mature Software Development Lifecycle using specific slash commands.

```text
  DEFINE            PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────────┐     ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ OpenSpec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  Change  │     │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────────┘     └──────┘      └──────┘      └──────┘      └──────┘
   /spec           /plan          /build        /test         /review       /ship
```

1. **Idea Refine:** You have a vague idea. The agent helps stress-test and refine it.
2. **Define (`/uncle-dev-spec`):** The agent generates a formal proposal and design specification in `openspec/changes/`.
3. **Plan (`/uncle-dev-plan`):** The spec is broken down into manageable, atomic tasks.
4. **Build (`/uncle-dev-build`):** Iterative, slice-by-slice coding begins. 
5. **Verify (`/uncle-dev-test`):** Tests are written and executed to prove the code works.
6. **Review (`/uncle-dev-review`):** The agent acts as a Senior Engineer to review the diff for security, performance, and best practices. (Optional: `/uncle-dev-code-simplify` to clean things up).
7. **Ship (`/uncle-dev-ship`):** Merging, documentation updates, and deployment readiness.

---

## 6. Prompts and Templates per Phase

Use these prompts directly in your agent's chat interface.

### Phase 1: Define (`/uncle-dev-spec`)
> **Prompt:** `/uncle-dev-spec I want to build a user authentication module using Better Auth. It must support Google OAuth and Email/Password logins. Please write the proposal and design specs.`

### Phase 2: Plan (`/uncle-dev-plan`)
> **Prompt:** `/uncle-dev-plan Take the authentication spec we just created and break it down into atomic tasks. Store the execution plan in my .devlocal workspace so we can track our progress.`

### Phase 3: Build (`/uncle-dev-build`)
> **Prompt:** `/uncle-dev-build Let's implement Task 1 from our plan (Setting up the Better Auth database schema). Slice it thin and let me know when it's ready.`

### Phase 4: Verify (`/uncle-dev-test`)
> **Prompt:** `/uncle-dev-test We just finished the login API route. Write unit and integration tests using our test pyramid strategy to ensure edges cases are covered.`

### Phase 5: Review / Cleanup (`/uncle-dev-review` & `/uncle-dev-code-simplify`)
> **Prompt:** `/uncle-dev-review Please act as a Senior Staff Engineer and review the uncommitted changes. Check for security vulnerabilities and give me a 5-axis review.`
>
> **Prompt:** `/uncle-dev-code-simplify Look at the 'UserSessions' component. Apply the Rule of 500 and simplify the logic without altering its behavior.`

### Phase 6: Ship (`/uncle-dev-ship`)
> **Prompt:** `/uncle-dev-ship Prepare these changes for deployment. Generate the final documentation updates and walk me through the pre-launch checklist.`

---

## 7. Prompts and Templates per Skill

Uncle Dev contains specific skills that can be triggered dynamically. Here is how to explicitly invoke them:

### Idea Refinement (`uncle-dev-idea-refine`)
> **Prompt:** `Use the uncle-dev-idea-refine skill. I have this rough idea for a real-time collaborative dashboard but I'm not sure about the backend architecture. Help me stress-test the assumptions and find the riskiest parts.`

### Frontend UI Engineering (`uncle-dev-frontend-ui-engineering`)
> **Prompt:** `Invoke uncle-dev-frontend-ui-engineering. I need to build a responsive Pricing Card component. Make sure you use a modern design system, apply WCAG 2.1 AA accessibility standards, and keep the state management clean.`

### API & Interface Design (`uncle-dev-api-and-interface-design`)
> **Prompt:** `Using uncle-dev-api-and-interface-design, help me design the REST endpoints for a shopping cart service. Follow contract-first design principles and ensure we follow the One-Version rule.`

### Browser Testing & DevTools (`uncle-dev-browser-testing-with-devtools`)
> **Prompt:** `Use uncle-dev-browser-testing-with-devtools. Something is wrong with the submit button on the staging site. Open the DevTools MCP, inspect the DOM state when clicked, and check the network request payloads.`

### Security & Hardening (`uncle-dev-security-and-hardening`)
> **Prompt:** `Run uncle-dev-security-and-hardening over the 'payments.ts' module. Check for OWASP Top 10 vulnerabilities, ensure secrets are properly scoped, and perform a three-tier boundary audit on the inputs.`

### Knowledge Capture (`uncle-dev-knowledge-capture`)
> **Prompt:** `That fix finally worked! Run uncle-dev-knowledge-capture to document the exact root cause of the caching race condition and save it to docs/solutions so the team remembers it.`

### Performance Optimization (`uncle-dev-performance-optimization`)
> **Prompt:** `Use uncle-dev-performance-optimization. The initial page load on the dashboard is taking over 3 seconds. Apply the measure-first approach, check the bundle size, and look for any React re-render anti-patterns.`
