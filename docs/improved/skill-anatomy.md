# Skill Anatomy

This document describes the structure and format of agent-skills skill files. Use this as a guide when contributing new skills or understanding existing ones.

## File Location

Every skill lives in its own directory under `skills/`:

```
skills/
  skill-name/
    SKILL.md             # Required: The skill definition
    references/          # Optional: spillover loaded on demand
      <topic>.md
    assets/              # Optional: templates, fixtures
    scripts/             # Optional: bundled executables
```

## SKILL.md Format

### Frontmatter (Required)

```yaml
---
name: skill-name-with-hyphens
description: Brief statement of what the skill does. Use when [specific trigger conditions].
---
```

**Rules:**
- `name`: Lowercase, hyphen-separated. Must match the directory name.
- `description`: Starts with what the skill does (third person), followed by trigger conditions. Include both *what* and *when*. Maximum 1024 characters.

**Why this matters:** Agents discover skills by reading descriptions. The description is injected into the system prompt, so it must tell the agent both what the skill provides and when to activate it. Do not summarize the workflow — if the description contains process steps, the agent may follow the summary instead of reading the full skill.

### Standard Sections

```markdown
# Skill Title

## Overview
One-two sentences explaining what this skill does and why it matters.

## When to Use
- Bullet list of triggering conditions (symptoms, task types)
- When NOT to use (exclusions)

## [Core Process / The Workflow / Steps]
The main workflow, broken into numbered steps or phases.
Include code examples where they help.
Use flowcharts (ASCII) where decision points exist.
End mutating processes with a validate → fix → re-validate loop
(see "Validation loop" under Writing Principles).

## [Specific Techniques / Patterns]
Detailed guidance for specific scenarios.
Code examples, templates, configuration.

## Gotchas
- Concrete environmental facts that defy reasonable assumptions
- One bullet per fact; include the correction inline
- Skip this section if the skill encodes no real environmental facts —
  never invent gotchas to fill space

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| Excuse agents use to skip steps | Why the excuse is wrong |

## Red Flags
- Behavioral patterns indicating the skill is being violated
- Things to watch for during review

## Verification
After completing the skill's process, confirm:
- [ ] Checklist of exit criteria
- [ ] Evidence requirements
```

## Section Purposes

### Overview
The "elevator pitch" for the skill. Should answer: What does this skill do, and why should an agent follow it?

### When to Use
Helps agents and humans decide if this skill applies to the current task. Include both positive triggers ("Use when X") and negative exclusions ("NOT for Y").

### Core Process
The heart of the skill. This is the step-by-step workflow the agent follows. Must be specific and actionable — not vague advice.

**Good:** "Run `npm test` and verify all tests pass"
**Bad:** "Make sure the tests work"

### Gotchas
The highest-value content in many skills: concrete environmental facts that defy reasonable assumptions and that the agent will get wrong without being told. Not general advice ("handle errors carefully") — concrete corrections ("the `users` table uses soft deletes; queries must include `WHERE deleted_at IS NULL`").

**Never invent gotchas.** Skip this section entirely when the skill encodes no real environmental facts. A filler Gotchas section is worse than no Gotchas section — it teaches the agent that the pattern doesn't matter.

### Common Rationalizations
The most distinctive feature of well-crafted skills. These are excuses agents use to skip important steps, paired with rebuttals. They prevent the agent from rationalizing its way out of following the process.

Think of every time an agent has said "I'll add tests later" or "This is simple enough to skip the spec" — those go here with a factual counter-argument.

### Red Flags
Observable signs that the skill is being violated. Useful during code review and self-monitoring.

### Verification
The exit criteria. A checklist the agent uses to confirm the skill's process is complete. Every checkbox should be verifiable with evidence (test output, build result, screenshot, etc.).

## Size Budget and Progressive Disclosure

Every `SKILL.md` stays **under 500 lines / 5,000 tokens**. Spillover lands in colocated directories:

- `skills/<name>/references/<topic>.md` — long reference material, examples, exhaustive tables
- `skills/<name>/assets/` — templates and fixtures
- `skills/<name>/scripts/` — bundled executables the skill drives

When `SKILL.md` references a spillover file, it **must say *when* to load it**, not just "see references/." Examples:

> "If the user wants to author a companion skill, read `references/anti-duplication.md` before scaffolding."

> "If the API returns a non-200 status, read `references/api-errors.md` for the response-code decoder."

A generic "see references/ for details" is dead weight — the agent has no trigger to load on. Tie every reference to a concrete situation.

## Supporting Files

Create supporting files only when:
- Reference material exceeds 100 lines (keep the main SKILL.md focused)
- The `SKILL.md` itself is approaching the 500-line budget
- Code tools or scripts are needed
- Checklists are long enough to justify separate files

Keep patterns and principles inline when under 50 lines.

## Writing Principles

1. **Process over knowledge.** Skills are workflows, not reference docs. Steps, not facts.
2. **Add what the agent lacks; omit what it knows.** No PDF-101 ("PDF is a file format that…"), no "HTTP is a protocol…" prose. Skip straight to the project-specific facts and procedures the agent wouldn't get right on its own.
3. **Specific over general.** "Run `npm test`" beats "verify the tests".
4. **Evidence over assumption.** Every verification checkbox requires proof.
5. **Anti-rationalization.** Every skip-worthy step needs a counter-argument in the rationalizations table.
6. **Progressive disclosure.** Main SKILL.md is the entry point. Supporting files are loaded only when needed, and only when the SKILL.md tells the agent *when* to load them.
7. **Token-conscious.** Every section must justify its inclusion. If removing it wouldn't change agent behavior, remove it.
8. **Defaults, not menus.** Pick one default plus at most one escape hatch. Don't present four equivalent libraries as "you can use X, Y, Z, or W" — pick the right one and note the single alternative that matters.
9. **Procedures over declarations.** Teach the agent *how to approach* a class of problems, not *what to produce* for a specific instance. The body of a procedure can include specific details (templates, constraints) — the surrounding *approach* must generalize.
10. **Calibrate control to fragility.** Be prescriptive (exact commands, exact order) for fragile or sequenced operations. Be flexible (explain *why*) where multiple approaches are valid. Most skills have a mix.
11. **Validation loop.** Any skill that mutates state ends its Process with the same loop: `validate → fix → re-validate`, anchored on a deterministic command (e.g., `bash scripts/uncle-dev-config.sh --validate`, `npm test`, `pytest`). The agent does not declare "done" until validation passes.

## Naming Conventions

- Skill directories: `lowercase-hyphen-separated`
- Skill files: `SKILL.md` (always uppercase)
- Supporting files: `lowercase-hyphen-separated.md`
- References: stored in `references/` inside each skill directory (`skills/<name>/references/`), not at the project root

## Cross-Skill References

Reference other skills by name:

```markdown
Follow the `test-driven-development` skill for writing tests.
If the build breaks, use the `debugging-and-error-recovery` skill.
```

Don't duplicate content between skills — reference and link instead.
