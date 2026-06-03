---
sidebar_position: 5
---

# FAQ

Short answers to common questions. For step-by-step fixes, see [Troubleshooting](../02-user-guide/troubleshooting.md).

## What is Uncle Dev?

A pack of engineering skills that make an AI coding agent follow a disciplined, spec-driven workflow instead of writing unreviewed code from a single prompt. See [What is Uncle Dev?](what-is-uncle-dev.md).

## Which tools does it support?

Claude Code, Codex, Cursor, OpenCode, GitHub Copilot, and Gemini CLI. Because every skill is a Markdown file, you can also paste a `SKILL.md` into any other agent by hand. See [Installation](installation.md).

## Do I have to load every skill?

No. Load only the skills relevant to the current task — loading all of them wastes context. Use the `using-agent-skills` meta-skill to pick the right one for each task.

## What is the difference between a skill, an agent, and a command?

- A **skill** is a workflow for a phase — for example, `spec-driven-development` or `code-review-and-quality`.
- An **agent** is a persona you summon for one perspective — for example, `code-reviewer` or `uncle-lead`. See the [Agent Guide](../03-agent-guide/available-agents.md).
- A **command** is a slash-command shortcut that runs a skill — for example, `/uncle-dev-spec` runs `spec-driven-development`. See the [commands and skills reference](../05-reference/commands-and-skills.md).

## Do I need OpenSpec?

Spec-driven development runs in one of two modes. OpenSpec mode tracks change artifacts in `openspec/changes/`. LID+EARS mode uses a `docs/hld` → `docs/lld` → `docs/ears` documentation chain. The project config selects the mode, so you do not have to use OpenSpec if your project uses the other mode.

## Where do specs and tasks live?

- `openspec/specs/` — the project's current source of truth, tracked in git.
- `openspec/changes/<change-id>/` — proposal, design, and tasks for work in progress.
- `.devlocal/` — the agent's disposable, gitignored scratchpad. See [The `.devlocal` directory](../02-user-guide/devlocal-directory.md).

## Do I need Graphify?

No, it is optional. When a `graphify-out/graph.json` exists, Uncle Dev skills use semantic graph traversal instead of grep for architecture, dependency, and impact questions. Install it with the steps in [Installation](installation.md).

## Can I use it without slash commands?

Yes. Slash commands are a Claude Code convenience. In other tools, invoke a skill by name (for example, "Use the `uncle-dev-security-and-hardening` skill") or load its `SKILL.md` into your rules file.

## How do I update Uncle Dev?

Re-run the install for your tool, then re-run project setup so hooks, rules, and config stay current. See [Troubleshooting](../02-user-guide/troubleshooting.md) if a command or hook stops working after an update.

## Is the configuration shared with my team?

The project config at `.agents/uncle-dev-setup.yaml` is meant to be committed and shared. The `.devlocal/` directory is personal and gitignored — it never ships with the project.
