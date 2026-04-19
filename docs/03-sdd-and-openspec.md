# 3. Why Use Spec-Driven Development (SDD) & OpenSpec

The foundation of the Uncle Dev workflow relies on **Spec-Driven Development (SDD)** and the **OpenSpec** standard.

## Spec-Driven Development Explained
SDD flips the AI agent's timeline. Instead of:
> Goal -> Code -> Refactor -> Test

SDD enforces:
> Goal -> Specify -> Plan -> Code -> Verify

When dealing with AI, the cost of generating code is nearly zero, but the cost of *verifying, reading, and debugging* flawed AI code is extremely high for human developers. SDD ensures the AI does the heavy lifting of thinking about edge cases, data schemas, and architecture before spitting out the code. This prevents architectural drift and saves hours of developer time.

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

This systematic approach prevents your software from degrading into an undocumented mess over time.
