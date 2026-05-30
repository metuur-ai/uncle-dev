---
title: Durable project rules belong in tracked files, not in private auto-memory
date: 2026-05-30
category: best-practices
module: knowledge-management
problem_type: best_practice
component: documentation
severity: medium
applies_when:
  - Working in a shareable project (plugin, library, internal framework) where rules ship to others
  - About to save a rule about how scripts, commands, or contributors must behave
  - The rule is meant to apply to anyone who clones/installs the project, not just this developer
tags:
  - knowledge-management
  - uncle-dev
  - documentation
  - rules
  - claude-md
---

# Durable project rules belong in tracked files, not in private auto-memory

## Context

The uncle-dev repo (and any shareable plugin/library) ships its rules to everyone who installs the
plugin. Private auto-memory in `~/.claude/projects/.../memory/` doesn't ship with the project, isn't
reviewed, and is invisible to anyone else opening the repo. Saving a project-wide rule to memory
means it exists for *you* but not for the team — and your future fresh sessions in a clean checkout
won't have it either.

This was learned mid-session when I (the agent) saved two project rules as auto-memory:
- "Config access via `scripts/uncle-dev-config.sh` only — never read the YAML directly."
- "agentskills.io skill authoring standards (≤500 lines, Gotchas, defaults-not-menus, etc.)."

Both were project rules. The first belonged in `CLAUDE.md` (project-wide boundary). The second was
already in `docs/skill-anatomy.md` — so the memory was redundant. The user corrected the routing
explicitly: "the memory and feedback can't be on MEMORY.md, it must add to rules or skills."

## Guidance

When you encounter a durable rule, route it by audience and lifecycle:

| Rule scope | Lands in |
|---|---|
| Project-wide convention or boundary (applies to every contributor) | Root `CLAUDE.md` (`## Conventions` or `## Boundaries`) |
| How to author a SKILL.md (format, sections, size budget, anti-patterns) | `docs/skill-anatomy.md` |
| How a specific skill behaves (process, gotchas, red flags) | That skill's `SKILL.md` |
| Architecture rules for a specific source directory | `AGENTS.md` colocated with the source |
| A solved problem worth remembering at the team level | `.uncle-dev/learns/<category>/<file>.md` via `/uncle-dev-knowledge-capture` |
| **Personal collaboration preference** (how *I* like to be talked to, file-naming preferences, etc.) | Private auto-memory (`feedback_*.md`) |

Default to a tracked file unless the rule is unambiguously about my personal collaboration style.
"This project should always X" is a project rule. "I prefer terse responses" is memory.

Before saving anything to memory in a shareable project's directory:

1. Ask: would another contributor cloning this repo need this rule? If yes → tracked file.
2. Check whether `CLAUDE.md`, `docs/skill-anatomy.md`, `AGENTS.md`, or a SKILL.md already covers it.
   If yes → no new artifact needed, optionally tighten the existing one.
3. If it's a solved problem or pattern worth team-level reuse, invoke `/uncle-dev-knowledge-capture`
   to write it to `.uncle-dev/learns/` properly.

## Why This Matters

- Memory is invisible to the team and to fresh sessions in fresh checkouts. A rule in memory
  effectively does not exist for anyone but the agent that wrote it.
- Tracked files ship through git: rules are reviewed in PRs, read by new contributors, and survive
  workstation changes.
- Splitting durable rules across memory and tracked files creates two sources of truth that drift.
  One source — versioned in the repo — beats two.
- `CLAUDE.md` and `docs/skill-anatomy.md` are already designed for this — they are the project's
  built-in contract surfaces. Bypassing them with memory undermines the whole convention layer.

## When to Apply

- Always, in any project that ships to others (plugins, libraries, frameworks, internal SDKs).
- Specifically in uncle-dev: never put project-wide engineering rules in
  `~/.claude/projects/-Users-javierbenavides-others-ai-agents-production-grade-agent-skills/memory/`.
- Personal-scratch / single-developer projects can still use memory freely — the rule kicks in when
  the project's rules are meant for an audience beyond you.

## Examples

**Wrong (what happened mid-session):**

```
~/.claude/projects/.../memory/feedback_config_access_via_helper.md
~/.claude/projects/.../memory/feedback_skill_authoring_standards.md
```

Two memory files saving rules that should ship to every uncle-dev installer. Invisible to the team,
redundant with `docs/skill-anatomy.md`, and the boundary rule was missing from the project's
`CLAUDE.md` entirely.

**Right (corrected routing):**

- Config-access rule → added to root `CLAUDE.md` under `## Boundaries`, with an audit grep guard:
  ```
  - Always: Read project configuration through `scripts/uncle-dev-config.sh` (scalar or `--list`
    mode). No script, command, hook, or helper may open `.agents/uncle-dev-setup.yaml` directly.
    [...] Audit guard: `grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/
    .claude/ hooks/` should return empty.
  ```
- Skill authoring standards → already in `docs/skill-anatomy.md` (Size Budget section, Gotchas
  pattern, and Writing Principles including defaults-not-menus, procedures-over-declarations, and
  the validation loop).
- Memory entries deleted.

**Decision template for next time:**

> Before `Write`-ing to `memory/`, ask: "Would a teammate cloning this repo tomorrow need this?"
> If yes → `CLAUDE.md`, `docs/skill-anatomy.md`, `AGENTS.md`, or a `SKILL.md`.
> If no (it's about my collaboration style) → memory is fine.

## Related

- `CLAUDE.md` — root project conventions and boundaries
- `docs/skill-anatomy.md` — the canonical SKILL.md authoring contract
- `skills/uncle-dev-knowledge-capture/SKILL.md` — the skill that wrote this learning
- `skills/uncle-dev-context-engineering/SKILL.md` — `AGENTS.md` hierarchy for directory-scoped rules
