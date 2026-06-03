---
sidebar_position: 2
---

# 3. Why Use Spec-Driven Development (SDD) & OpenSpec

The foundation of the Uncle Dev workflow relies on **Spec-Driven Development (SDD)** and the **OpenSpec** standard.

## Spec-Driven Development Explained

SDD changes the AI agent's order of work. Instead of:

> Goal -> Code -> Refactor -> Test

SDD enforces:

> Goal -> Specify -> Plan -> Code -> Verify

With AI, the cost of generating code is near zero, but the cost of *verifying, reading, and debugging* flawed AI code is high for you. SDD makes the agent reason about edge cases, data schemas, and architecture before it writes the code. This prevents architectural drift and saves development time.

## The OpenSpec Standard

OpenSpec defines a directory structure that separates the current state of a project from works in progress.

### The `openspec/specs/` Directory

This directory is the project's source of truth. It holds living documentation of how the application works *today*:

- Architecture decisions
- Domain models
- API endpoint specs

Before the agent builds a new feature, SDD makes it read `openspec/specs/` to understand the existing constraints.

### The `openspec/changes/<change-id>/` Directory

This folder holds the lifecycle of a feature under development. When you run `/uncle-dev-spec`, the agent writes these artifacts here:
- **`proposal.md`**: What are we building and why?
- **`design.md`**: How will the database tables and APIs look?
- **`tasks.md`**: A strict checklist of atomic implementation slices.
- **`execution.md`**: Tracking progress.

### The Lifecycle Benefit

Once a feature is implemented through the `tasks.md` checklist, the updates in the change folder are reconciled back into `openspec/specs/`. This keeps the project's source of truth current as the code evolves.
