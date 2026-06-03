---
sidebar_position: 1
---

# 5. How to Take a Feature From Idea to Deploy

The Uncle Dev lifecycle runs through seven phases in a fixed order. Complete each phase before moving to the next.

## Prerequisites

Before you begin, ensure you have:

- Uncle Dev installed in your AI coding tool (see the installation guide)
- A feature or change you want to build
- Access to the slash commands shown below (`/uncle-dev-spec`, `/uncle-dev-plan`, `/uncle-dev-build`, `/uncle-dev-test`, `/uncle-dev-review`, `/uncle-dev-ship`)

```text
  DEFINE            PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────────┐     ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ OpenSpec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  Change  │     │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────────┘     └──────┘      └──────┘      └──────┘      └──────┘
   /spec           /plan          /build        /test         /review       /ship
```

## Steps

### 1. Refine the idea

Run the `uncle-dev-idea-refine` skill to decide *what* to build. You and the AI agent challenge assumptions, surface risk factors, and settle on a minimum viable product configuration.

### 2. Define the spec (`/uncle-dev-spec`)

Run `/uncle-dev-spec`. The agent authors `proposal.md` and `design.md` in the `openspec/changes/` directory. Read the architecture, the database schema design, and the edge cases. Approve the spec before moving on.

### 3. Plan the tasks (`/uncle-dev-plan`)

Run `/uncle-dev-plan`. The agent decomposes the approved spec into story-level tasks in `tasks.md` and sets up a checklist in `.devlocal/` to track implementation steps. You now have a step-by-step roadmap.

### 4. Build the implementation (`/uncle-dev-build`)

Run `/uncle-dev-build`. The agent implements code one vertical slice at a time. This phase invokes skills such as `uncle-dev-incremental-implementation`, `uncle-dev-frontend-ui-engineering`, and `uncle-dev-api-and-interface-design`, depending on which part of the stack the slice touches.

### 5. Verify with tests (`/uncle-dev-test`)

Run `/uncle-dev-test`. The agent writes unit, integration, and end-to-end tests for the build slice. If tests fail, it switches to the `uncle-dev-debug-error` skill and applies a scientific method: reproduce, localize, reduce, and fix.

### 6. Review the diff (`/uncle-dev-review`)

Run `/uncle-dev-review` before committing. The agent reviews the diff using the `uncle-dev-code-review-and-quality` and `uncle-dev-security-and-hardening` frameworks, tags findings as NIT, Optional, or Block, and refactors accordingly. Invoke `/uncle-dev-code-simplify` in this phase as well.

### 7. Ship the feature (`/uncle-dev-ship`)

Run `/uncle-dev-ship`. The agent updates `openspec/specs/` to reconcile the changes, manages deprecation lifecycles if needed, confirms the test pipeline passes, and prepares deployment configurations.

## Verify it worked

After completing all seven phases, confirm:

- `openspec/changes/` contains the `proposal.md`, `design.md`, and `tasks.md` for your change
- The test pipeline passes
- The review phase reports no Block-tagged findings
