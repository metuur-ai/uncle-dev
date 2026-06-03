---
sidebar_position: 2
---

# 4. The `.devlocal` Directory

The Uncle Dev workflow uses a `.devlocal/` workspace.

## What is `.devlocal/`?

The `.devlocal/` directory is a **private scratchpad** and sandbox for the AI agent and the human pair programmer.

It is **excluded from version control** — always add `.devlocal/` to your `.gitignore`.

## Why It Exists

### Separation of Concerns

The `openspec/` folders hold shared, canonical truth that the whole engineering team reads. The `.devlocal/` directory holds transient, mid-development working notes. Keeping the two apart prevents the agent's intermediate work from polluting the shared repository.

### Private Execution Plans

When you run `/uncle-dev-plan`, the agent breaks user-story tasks into granular steps. It writes these checklists to `.devlocal/scratchpads/` or `.devlocal/executions.md` and ticks off items as it works. Once the task is complete, the checklist is obsolete and you can ignore or delete it.

### Debugging and Logs

During the **Verify** phase (`/uncle-dev-test` and `/uncle-dev-debug-error`), the agent may produce large command-line logs, performance profiles, temporary JSON dumps, or error tracebacks. Storing these in `.devlocal/` keeps your application's root directory clean.

### Avoiding CI/CD Triggers

Many tools watch the file system for changes. If the agent continuously saves temporary tracking documents during a build, it can trigger unnecessary hot-reloads or CI test runs. A dedicated `.devlocal/` folder lets you tell file watchers to ignore that work.
