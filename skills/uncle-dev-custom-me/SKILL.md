---
name: uncle-dev-custom-me
description: Authors and registers user-defined override or companion skills that the uncle-dev runtime loads in place of (or alongside) bundled skills. Use when you want to replace `uncle-dev-<X>` with your own version, or layer team-specific rules on top of an uncle-dev skill without duplicating its content.
---
## Overview

uncle-dev ships ~35 bundled skills. Teams often need to customize one — e.g., add a corporate TDD policy to `uncle-dev-test-driven-development`, or replace `uncle-dev-frontend-ui-engineering` with one that knows your design system. This skill teaches you the two supported customization patterns, where the file lives, and how to register it so the runtime actually loads it.

The runtime mechanism is a single loader script (`scripts/uncle-dev-load-skill.sh`) called by 14 wired commands. When you register an override or companion in `.agents/uncle-dev-setup.yaml`, the loader emits `SKILL:` and `COMPANION:` lines the agent honors per the directive in your project CLAUDE.md.

## Process

### Pattern 1 — Override

Replace an uncle-dev skill with your own full SKILL.md. The override's body is loaded instead of the base.

```
/uncle-dev-custom-me override <base-skill> <new-name>
```

1. Pick the base skill name (e.g., `uncle-dev-test-driven-development`).
2. Pick a short new name (e.g., `tdd-plus`).
3. The slash command scaffolds `.agents/skills/<new-name>/SKILL.md` from `templates/override-skill.md` and prints the YAML registration block.
4. Paste the YAML block into `.agents/uncle-dev-setup.yaml` under `skills.overrides`.
5. Validate: `bash scripts/uncle-dev-config.sh --validate` → exit 0.
6. Edit `.agents/skills/<new-name>/SKILL.md` and fill in every TODO section. Your override must include all 6 standard sections per `docs/skill-anatomy.md` — there is no partial override; missing sections are gone.
7. Verify loading: `bash scripts/uncle-dev-load-skill.sh <base-skill>` should print `SKILL: .agents/skills/<new-name>/SKILL.md`.

### Pattern 2 — Companion

Add a delta on top of an uncle-dev skill. The base skill loads first, then the companion's `## Companion Additions` merges into context. The companion does not restate the base.

```
/uncle-dev-custom-me companion <base-skill> <new-name>
```

1. Pick the base skill name and a short new name (e.g., `team-tdd-rules`).
2. The slash command scaffolds `.agents/skills/<new-name>/SKILL.md` from `templates/companion-skill.md` — a strict template containing only the frontmatter and a `## Companion Additions` heading. There is no Overview, no Process placeholder, not even commented-out.
3. The slash command prints the YAML block. Paste it into `.agents/uncle-dev-setup.yaml` under `skills.companions`.
4. Validate: `bash scripts/uncle-dev-config.sh --validate` → exit 0.
5. Edit `.agents/skills/<new-name>/SKILL.md` and add your delta inside `## Companion Additions`. Optionally add `## Additional Red Flags`, `## Project-Specific Patterns`, or `## Local Verification Steps` — these are the only other sections allowed.
6. Verify loading: `bash scripts/uncle-dev-load-skill.sh <base-skill>` should print `SKILL: agent-skills:<base>` (or your override) followed by `COMPANION: .agents/skills/<new-name>/SKILL.md`.

### Validation loop (every customization ends here)

```
edit SKILL.md → bash scripts/uncle-dev-config.sh --validate
            → bash scripts/uncle-dev-load-skill.sh <base-skill>
            → confirm SKILL:/COMPANION: line matches expectation
            → if not, fix the registration or the file path and rerun
```

The slash command prints these steps after scaffolding. Do not declare "done" until the loader prints the expected lines.

## Registration Format (reference)

### Override

```yaml
skills:
  overrides:
    uncle-dev-test-driven-development:
      path: .agents/skills/tdd-plus/SKILL.md
      name: tdd-plus
```

### Companion (per-skill form — v1 loaded)

```yaml
skills:
  companions:
    uncle-dev-test-driven-development:
      - path: .agents/skills/team-tdd-rules/SKILL.md
        name: team-tdd-rules
```

Multiple companions on the same base are allowed; the loader emits one `COMPANION:` line per registered entry, in array order.

## Gotchas

- `SKILL: agent-skills:<name>` is a literal sentinel — not a file path. The `agent-skills:` prefix means "use the bundled skill." Treat anything else as a project-relative file path.
- `.agents/uncle-dev-setup.yaml` is YAML, not JSON. The slash command prints the registration block ready to paste. Do not reformat or re-indent it.
- Per-phase `skills.companions.<phase>` (e.g., `build`, `ship`) is permitted by the schema but not loaded in v1. Use the per-skill form keyed by base skill name.
- Codex and OpenCode commands do not run shell, so they do not emit `SKILL:`/`COMPANION:` lines. Off Claude Code, your customization does not load — read the file yourself.
- Override fully replaces the base. There is no merging at the section level. If you omit `## Verification`, the base's `## Verification` is gone.
- Companions are loaded only by the 14 wired commands. A skill invoked ad-hoc (e.g., from inside a different prompt) falls through to the base.
- The loader checks the registered path exists on disk. If it doesn't, you get `WARN: missing skill file <path>` on stderr and the loader falls back to the base. Always check the loader output after registering.
- Do not commit `.agents/uncle-dev-setup.yaml` if it contains team-secret rules — keep team-only customizations in a private branch or use `.devlocal/` overrides for individual experiments.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just copy the base skill and edit it — easier than a companion." | The override path is fine for genuine replacements. But if you only need a few extra rules, the companion is shorter, easier to review, and survives base-skill updates. Pick override when you disagree with the base; pick companion when you extend it. |
| "I'll add `## Overview` to my companion so it's self-contained." | A companion is not self-contained by design — the base loads first. Restating `## Overview` is a red flag: it duplicates content, drifts over time, and confuses the agent about which Overview is authoritative. Use only `## Companion Additions` plus the four allowed optional sections. |
| "I'll edit the YAML by hand to skip the slash command." | You can. The slash command's value is the strict template and the correct registration block — bypassing it is the easiest way to land a typo or a missing field. If you do hand-edit, run `--validate` and the loader before you commit. |
| "The override doesn't need all 6 sections — the base had them." | The base is replaced, not inherited. Whatever section you omit is missing at runtime. The override template ships all 6 as TODOs so you don't skip one by accident. |
| "I'll just stick `path` on whatever YAML key — uncle-dev-config will figure it out." | The schema is strict on the location: `skills.overrides.<base>.path` for overrides, `skills.companions.<base>[].path` for companions. Anywhere else and `--validate` fails or the loader emits no lines. |

## Red Flags

- Your companion SKILL.md contains a `## Overview`, `## When to Use`, or `## Process` heading. Anti-duplication violation — those belong to the base.
- Your companion frontmatter lacks `companion_to: <base-skill>`. Orphan companion — readers can't tell which base it augments.
- Your override SKILL.md is missing one of the 6 standard sections. Incomplete replacement — the agent will see a skill without a Process or Verification step.
- `bash scripts/uncle-dev-load-skill.sh <base>` emits `WARN: missing skill file <path>` on stderr. Your `path` is wrong or the file isn't on disk.
- You hand-edited `.agents/uncle-dev-setup.yaml` and didn't run `--validate`. Schema drift is silent until a downstream command fails to read the key.
- You registered the same base under both `skills.overrides` AND `skills.companions`. That's legal (override + companion compose), but it's also the most common source of "why is the agent reading the wrong skill" — verify the loader output matches your intent.
- You're invoking a skill outside the 14 wired commands and expecting your customization to load. It won't in v1. Either invoke through a wired command or read your file manually.

## Verification

After authoring a customization, confirm each item before considering it shipped:

- [ ] `.agents/skills/<new-name>/SKILL.md` exists.
- [ ] For overrides: all 6 standard sections present per `docs/skill-anatomy.md`. Frontmatter has `overrides: <base-skill>`.
- [ ] For companions: only `## Companion Additions` plus any of the four allowed optional sections. Frontmatter has `companion_to: <base-skill>`. `grep -E "^## (Overview|When to Use|Process|Common Rationalizations|Red Flags|Verification)" .agents/skills/<new-name>/SKILL.md` returns nothing.
- [ ] `bash scripts/uncle-dev-config.sh --validate` → exit 0.
- [ ] `bash scripts/uncle-dev-load-skill.sh <base-skill>` prints the expected `SKILL:` and/or `COMPANION:` line(s), no `WARN:` on stderr.
- [ ] Running the relevant wired command (e.g., `/uncle-dev-test`) in a session prints the same `SKILL:` / `COMPANION:` lines and the agent reads your file.
- [ ] If team-shared: the YAML registration is in version control; your `.agents/skills/<new-name>/` directory is in version control.
