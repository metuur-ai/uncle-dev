# Skill Extension: Override and Companion Surface Map

**Date:** 2026-05-30
**Author:** Claude (uncle-dev-research)
**Status:** Documentation of current state. No recommendations.
**Scope:** Map what exists today to support user-authored skill overrides and companion skills, identify
gaps, and document the extension points a new skill would need to address.

---

## 1. The Research Question

The user wants a skill that allows users to:

1. **Override** an existing uncle-dev skill with a custom replacement:
   `"I want to override uncle-xyz with my custom XYZ-plus"`
2. **Add companion instructions** to an existing skill without duplicating its content:
   `"I want to add these companion rules to uncle-xyz"`

Key design constraint: Overrides and companions must not duplicate the skill's existing content.
They should augment or replace — not copy-paste and modify.

---

## 2. Repository Topology (as of 2026-05-30)

```
agent-skills/
├── skills/<name>/SKILL.md          # 35 skills, each with YAML frontmatter + body
├── .claude/commands/<name>.md      # 21 slash commands
├── skills/uncle-dev-setup/
│   ├── SKILL.md                    # Setup skill (Step 3 writes config, Step 5 injects CLAUDE.md)
│   └── uncle-dev-setup.template.yaml  # Config template for .agents/uncle-dev-setup.yaml
├── scripts/uncle-dev-config.sh     # Runtime config reader used by commands
└── .agents/uncle-dev-setup.yaml    # Per-project config (written by setup-project.sh)
```

---

## 3. What EXISTS Today for Companions and Overrides

### 3.1 The `skills.companions` field in setup.yaml

`skills/uncle-dev-setup/uncle-dev-setup.template.yaml:47-65` defines a `companions` block:

```yaml
skills:
  companions:
    build:
      - path: .agents/skills/my-design-system/SKILL.md
        name: my-design-system
    ship:
      - path: .agents/skills/openapi-doc-generator/SKILL.md
        name: openapi-doc-generator
```

- **Declared:** Yes, in the template.
- **Consumed by any command:** **No.** A grep of all `.claude/commands/*.md` files finds zero references to `companions`. No command reads this field at runtime.
- **Mentioned in injected CLAUDE.md:** Yes — `SKILL.md:362` injects the line
  `"Companion skills defined in .agents/uncle-dev-setup.yaml under skills.companions"` and `:368`
  adds `"Check .agents/uncle-dev-setup.yaml for project-specific skill overrides and companion skills"`.
  This is a passive note in a rules block — not wired to any command invocation.

**Conclusion:** `companions` is a spec-only field. It exists in the config schema but no runtime agent behavior reads or acts on it.

### 3.2 The `skills.overrides` field in setup.yaml

`uncle-dev-setup.template.yaml:43-44` defines:

```yaml
skills:
  overrides:
    uncle-dev-test-driven-development:
      test_runner: ""
      coverage_threshold: 80
```

- **Consumed:** Partially. `uncle-dev-config.sh` (the runtime reader used by build, spec, test commands)
  reads scalar preference keys (`preferences.*`). No command reads `skills.overrides.*` keys.
- **Conclusion:** `overrides` is also spec-only for per-skill config. The *mechanism* (config.sh +
  commands reading it) exists but it is not connected to skill content.

### 3.3 How commands read config today

`uncle-dev-config.sh` reads YAML keys via a positional API: `bash uncle-dev-config.sh preferences.sdd_mode`.
Commands that use it:

| Command | Keys read |
|---|---|
| `uncle-dev-build.md` | `preferences.sdd_mode`, `preferences.execution_profile`, `preferences.tdd-mode` |
| `uncle-dev-spec.md` | `preferences.sdd_mode` |
| `uncle-dev-test.md` | `preferences.tdd-mode`, `preferences.execution_profile` |
| `uncle-dev-review.md` | `preferences.execution_profile` |

**No command reads `skills.companions` or `skills.overrides.*.path`.**

### 3.4 How skills are invoked (context delivery mechanism)

uncle-dev skills are not called programmatically. A slash command (`/uncle-dev-build`) maps to a
Markdown file (`.claude/commands/uncle-dev-build.md`). The command instructs the agent to invoke a
skill by saying: *"Invoke the agent-skills:uncle-dev-incremental-implementation skill."* The agent
then reads the SKILL.md file.

This means "loading" a skill = the agent reading a SKILL.md file. Overriding a skill = pointing the
agent to a different SKILL.md. Companion = pointing the agent to an additional SKILL.md alongside
the original.

There is no import system, no composition API, no merge layer. All of it is prose read into context.

### 3.5 What CLAUDE.md knows vs. what commands know

The CLAUDE.md block injected by setup (`SKILL.md:337-370`) carries the line:
> "Check `.agents/uncle-dev-setup.yaml` for project-specific skill overrides and companion skills"

This line is always in context (CLAUDE.md is always loaded). So the agent _can_ be directed to read
the companions field — it just isn't done so in any command today.

---

## 4. What DOES NOT EXIST Today

| Capability | Status |
|---|---|
| A skill that guides users to author a custom override skill | Not present |
| A skill that guides users to author a companion skill | Not present |
| Command-side logic that reads `skills.companions[phase]` and loads those SKILL.md files | Not present |
| Command-side logic that reads `skills.overrides[name].path` and replaces the canonical SKILL.md | Not present |
| A naming convention for user-authored skill files (e.g., `uncle-xyz-plus`) | Not defined |
| A contract for what an override skill must / must not include (to avoid duplication) | Not defined |
| A contract for what a companion skill must / must not include | Not defined |
| A validation check that a companion doesn't duplicate content already in the base skill | Not present |
| A place to store user-authored skills (convention only: `.agents/skills/<name>/SKILL.md`) | Convention only (in comments) |

---

## 5. The Three Use Cases in Detail

### 5.1 Full Override — "replace uncle-xyz with my XYZ-plus"

**What it means:** The user has written their own SKILL.md that completely supersedes an existing
uncle-dev skill. When a command invokes `uncle-dev-xyz`, the agent should read the user's file
instead.

**Current gap:** No config key maps `uncle-dev-xyz → .agents/skills/xyz-plus/SKILL.md`. No command
reads such a mapping. The only path today is to manually edit the CLAUDE.md rules block to say
"use .agents/skills/xyz-plus/SKILL.md instead of uncle-dev-xyz".

**Extension points that would need to change:**
- `skills.overrides.<name>.path` in setup.yaml — add a path key
- One or more commands — read `skills.overrides.<name>.path` before invoking the default skill

### 5.2 Additive Companion — "add these rules to uncle-xyz"

**What it means:** The user wants extra instructions appended to (or read alongside) an existing
skill. They do NOT want to copy the skill's content. They write only the delta.

**Current gap:** `skills.companions.<phase>` exists in the schema but no command reads it. The
companion file would need to be read by the command after the base skill.

**Extension points:**
- `skills.companions.<phase>` already exists but needs runtime wiring in commands
- Optionally: a `skills.companions.<name>` form (per-skill rather than per-phase)

### 5.3 Phase Companion — "add this skill to all build-phase invocations"

**What it means:** The user has a team-specific skill (e.g., `my-design-system`, `company-api-contracts`)
that should always run alongside uncle-dev during a specific lifecycle phase.

**Current gap:** Same as 5.2 — field exists, no consumer.

---

## 6. The `uncle-dev-config.sh` Extension Surface

`scripts/uncle-dev-config.sh` already supports dot-path key lookup from the YAML. The schema for
extending it to companions/overrides would be:

```bash
# Already works:
bash uncle-dev-config.sh preferences.sdd_mode

# Does NOT exist yet:
bash uncle-dev-config.sh skills.overrides.uncle-dev-tdd.path
bash uncle-dev-config.sh skills.companions.build[0].path
```

Adding these reads would not require new infrastructure — only new key paths and commands that call them.

---

## 7. Skill Anatomy Contract (existing, applies to user-authored skills too)

From `CLAUDE.md:29-35`, every SKILL.md must have:
- YAML frontmatter: `name`, `description`
- Body sections: Overview / When to Use / Process / Common Rationalizations / Red Flags / Verification

A new skill-extension skill would need to define:
- What a **companion** SKILL.md is allowed to contain (delta only: additional process steps,
  additional red flags, project-specific patterns)
- What a **companion** SKILL.md must NOT contain (don't restate what the base skill already says)
- What an **override** SKILL.md must declare (which skill it overrides; why)
- Where user-authored skills live (convention: `.agents/skills/<name>/SKILL.md`)

No such contract exists today.

---

## 8. Naming Conventions (current state)

| Artifact | Convention |
|---|---|
| uncle-dev built-in skills | `skills/uncle-dev-<name>/SKILL.md` |
| User-authored skills (hinted in template comments) | `.agents/skills/<name>/SKILL.md` |
| Override skill name (no convention yet) | — |
| Companion skill name (no convention yet) | — |

The `uncle-dev-setup.template.yaml:57-60` example uses `my-design-system` and
`openapi-doc-generator` — snake-case, no prefix. No naming rule enforces that.

---

## 9. Prior Research Cross-References

Two prior research docs cover adjacent ground:

- `2026-05-17-companion-modes-extended-exploration.md` — maps **Uncle Domain**, **Uncle Framework**,
  and **Product Mode** as specialized companion _agents_ (personas, not skill files). Section §4.2
  confirms: `"All uncle-dev skills are always available — there is no opt-in/opt-out list."` The
  companion/override feature under research here is at the **skill file** level, not the agent level.
- `2026-05-17-uncle-domain-companion-exploration.md` §4.1 — covers skill anatomy and `skills.companions`
  path-registered companions as the current surface. Confirms: "the closest mechanism is
  path-registered companion skills (uncle-dev-setup.template.yaml:47-65)."

---

## 10. Summary of Gaps a New Skill Would Need to Address

A new skill (e.g., `uncle-dev-skill-authoring`) would need to document:

1. **User-authored skill file format** — frontmatter contract, which sections are required, what a
   companion is allowed to say vs. what must be left to the base skill.

2. **Override declaration** — a standard frontmatter key (e.g., `overrides: uncle-dev-tdd`) and
   instructions to register it in `.agents/uncle-dev-setup.yaml` under `skills.overrides`.

3. **Companion declaration** — a standard frontmatter key (e.g., `companion_to: uncle-dev-tdd`) and
   instructions to register it under `skills.companions`.

4. **Runtime wiring** — which commands need to be updated to read `skills.overrides` and
   `skills.companions` from config and inject the extra file into context.

5. **Anti-duplication contract** — explicit rule: a companion must reference the base skill by name
   and must not restate any section already covered in it.

6. **Verification checklist** — how the user can confirm their override or companion is being loaded.

The config schema (`skills.overrides` + `skills.companions`) already has the right shape.
The runtime gap is entirely in commands not reading those fields.
