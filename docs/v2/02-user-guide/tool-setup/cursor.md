---
sidebar_position: 2
---

# How to Use agent-skills with Cursor

## Prerequisites

Before you begin, ensure you have:

- A local clone of the agent-skills repository
- Cursor installed
- A target project where you want to install the rules

## Option 1: Install into the rules directory (Recommended)

Cursor supports a `.cursor/rules/` directory for project-specific rules. From this repository, install the recommended Cursor rules into your project:

```bash
./scripts/install-plugin.sh cursor /path/to/your-project
```

Cursor loads rules in this directory into its context automatically.

## Option 2: Create a .cursorrules file

Create a `.cursorrules` file in your project root with the essential skills inlined:

```bash
cat /path/to/agent-skills/skills/uncle-dev-test-driven-development/SKILL.md > .cursorrules
printf '\n---\n' >> .cursorrules
cat /path/to/agent-skills/skills/uncle-dev-code-review-and-quality/SKILL.md >> .cursorrules
```

## Option 3: Store skills as Notepads

Cursor's Notepads feature stores reusable context. Create a notepad for each skill you use frequently:

1. Open Cursor, then go to Settings > Notepads.
2. Create a new notepad named "swe: Test-Driven Development".
3. Paste the content of `skills/uncle-dev-test-driven-development/SKILL.md`.
4. Reference it in chat with `@notepad swe: Test-Driven Development`.

## Recommended Configuration

### Essential Skills (Always Load)

Add these to `.cursor/rules/`:

1. `test-driven-development.md` — TDD workflow and Prove-It pattern
2. `code-review-and-quality.md` — Five-axis review
3. `incremental-implementation.md` — Build in small verifiable slices

### Phase-Specific Skills (Load as Notepads)

Create notepads for skills you use contextually:

- "swe: Spec Development" → `spec-driven-development/SKILL.md`
- "swe: Frontend UI" → `frontend-ui-engineering/SKILL.md`
- "swe: Security" → `security-and-hardening/SKILL.md`
- "swe: Performance" → `performance-optimization/SKILL.md`

Reference them with `@notepad` when working on relevant tasks.

## Verify it worked

Confirm the installation:

1. Check that `.cursor/rules/` in your project contains the installed rule files (for example, `test-driven-development.md`).
2. In Cursor chat, ask it to "follow the test-driven-development rules" and confirm it references the loaded rule.

## Usage Tips

1. **Don't load all skills at once** — Cursor has context limits. Load 2-3 skills as rules and keep others as notepads.
2. **Reference skills explicitly** — Tell Cursor "Follow the test-driven-development rules for this change" to ensure it reads the loaded rules.
3. **Use agents for review** — Copy `agents/uncle-dev-ag-code-reviewer.md` content and tell Cursor to "review this diff using this code review framework."
4. **Load references on demand** — When working on performance, reference `@notepad performance-checklist` or paste the checklist content.
