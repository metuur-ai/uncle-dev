---
sidebar_position: 8
---

# Documentation Roadmap

This documentation set covers what exists today. The sections below are planned but not yet written. They are listed here, rather than as empty pages, so the structure stays honest and navigable.

Each planned page maps to a real coverage gap. Contributions are welcome.

## Planned sections

### Getting Started

| Page | Why it is planned |
|------|-------------------|
| FAQ | Common first-run questions are not yet collected in one place. |

### User Guide

| Page | Why it is planned |
|------|-------------------|
| Troubleshooting | No single guide exists for diagnosing failed installs, missing hooks, or skills that do not trigger. |
| Worked examples | End-to-end example projects would show the workflow on real code. |

### Agent Guide

[Available agents](03-agent-guide/available-agents.md) is written. These deeper topics are still planned.

| Page | Source that exists today |
|------|--------------------------|
| Orchestration | Multi-agent / subagent patterns. |
| Memory | `uncle-dev-knowledge-capture` and `uncle-dev-knowledge-maintenance`. |
| Context management | `uncle-dev-context-engineering` skill. |

### Customization

| Page | Source that exists today |
|------|--------------------------|
| Settings | `.agents/uncle-dev-setup.yaml` configuration. |
| Hooks | `hooks/` directory, undocumented. |
| Workflows | Workflow orchestration, undocumented. |

### Reference

| Page | Why it is planned |
|------|-------------------|
| Configuration reference | A field-by-field reference for `uncle-dev-setup.yaml`. |
| Variables reference | Template and prompt placeholders. |
| Events reference | Hook lifecycle events. |
| Schema reference | OpenSpec artifact schemas. |

### Architecture

A deeper section on internals. Some of this may stay thin, because a skills pack is Markdown loaded by a host agent rather than a standalone runtime.

| Page | Notes |
|------|-------|
| Overview | How skills, agents, hooks, and commands fit together. |
| Lifecycle | Partly covered by [Common workflows](01-getting-started/common-workflows.md). |
| Execution model | How the host agent loads and runs skills. |
| Memory model | How `.uncle-dev/learns/` and handoffs persist context. |
| Context pipeline | How context is assembled and trimmed. |
| Diagrams | Visual references for the above. |

### Examples

Runnable example projects. One solid example is worth more than several empty folders, so these are deferred until at least one exists.

| Example | Status |
|---------|--------|
| Simple project | Planned |
| Software project | Planned |
| Product management | Planned |
| Support team | Planned |
| Enterprise example | Planned |
