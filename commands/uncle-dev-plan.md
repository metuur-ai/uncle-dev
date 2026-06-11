---
description: Break work into small verifiable tasks with acceptance criteria and dependency ordering
---

## Working Principles

1. **Think Before Coding** — Read the full spec before writing a single task. Understand the dependency graph before ordering anything.
2. **Simplicity First** — Tasks should be the minimum slices that deliver value. Don't decompose into exhaustive subtasks or predict work that isn't confirmed.
3. **Surgical Changes** — Write only what belongs in the task file. Private technical notes go in `.devlocal/`, not in shared artifacts.
4. **Goal-Driven Execution** — Every task must have explicit acceptance criteria and a verification step. A plan without checkpoints is incomplete.

---

## Step 0 — Read SDD mode (do this first)

```bash
_cfg="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[[ ! -f "$_cfg" ]] && _cfg=$(find "${HOME}/.claude/plugins" -name "uncle-dev-config.sh" 2>/dev/null | head -1)
SDD_MODE=$(bash "$_cfg" preferences.sdd_mode 2>/dev/null || echo "")
# Auto-detect from filesystem when config doesn't set a mode.
# Prefer lid-ears markers (docs/{hld,lld,ears}) over openspec/, because
# setup-project.sh previously created openspec/ unconditionally — its presence
# alone is not a reliable signal of openspec mode.
if [[ -z "$SDD_MODE" ]]; then
  if [[ -d "docs/ears" || -d "docs/hld" || -d "docs/lld" ]]; then
    SDD_MODE="lid-ears"
  elif [[ -d "openspec" ]]; then
    SDD_MODE="openspec"
  else
    SDD_MODE="lid-ears"
  fi
fi
echo "$SDD_MODE"
```

**Route based on result — pick exactly one path:**

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path. Do NOT run any `openspec` command.**

Read inputs:
- `docs/ears/<slug>.md` — EARS requirements (the source of truth for stories)
- `docs/lld/<slug>.md` — architecture constraints and key decisions

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-code-context
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md, then read `AGENTS.md` files in all directories the plan will touch.

Then write `docs/tasks/<slug>.md` using this format:

```markdown
# <Feature Title> — Tasks

## <Unit 1 name from EARS>

- [ ] 1.1 <story title> (est: ~Xm)
  - acceptance: R-1.1 — WHEN … THE SYSTEM SHALL …
  - verify: <how to confirm the requirement is met>

- [ ] 1.2 <story title> (deps: 1.1, est: ~Xm)
  - acceptance: R-1.2 — …
  - verify: …

## <Unit 2 name from EARS>

- [ ] 2.1 <story title> (est: ~Xm)
  - acceptance: R-2.1 — …
  - verify: …
```

Rules:
- One story per EARS requirement (or one story per closely related group if trivially small)
- `deps:` must match story IDs declared in this same file — no cross-file deps
- `(mutex: tag)` when two stories cannot run concurrently (e.g., both modify the same schema)
- Keep private technical breakdown in `.devlocal/<user>/<story-id>/scratchpad.md`

Present the plan for human review. **No `openspec` commands. No `execution.md`.**

---

## Path B — `openspec` mode (default)

**If sdd_mode is `openspec` or missing: follow this path.**

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-planning-and-task-breakdown
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Check if the OpenSpec CLI is available (`openspec --version`). When available, use it to read the active change:

- `openspec list` to find active changes
- `openspec show <change-id>` to read the change's proposal and design
- `openspec status <change-id>` to check current artifact completion
- `openspec instructions tasks.md` to get enriched guidance for writing task breakdowns

If not installed, recommend `npm install -g openspec` and read `proposal.md` and `design.md` directly.

Read the active OpenSpec change's `proposal.md` and `design.md`, plus the relevant codebase sections.

Resolve the code-context skill for any project overrides/companions:

```bash
bash "$_loader" uncle-dev-code-context
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md, then read `AGENTS.md` files in all directories the plan will touch — this establishes architecture boundaries before task ordering begins. Then:

1. Enter plan mode — read only, no code changes
2. Identify the dependency graph between components
3. Slice work into shared story-level items, not code-level subtasks
4. Write shared stories with acceptance criteria and verification steps into `tasks.md`
5. Record cross-story ordering, blockers, and coordination notes in `execution.md`
6. Keep private technical breakdown in `.devlocal/<user>/<story-id>/scratchpad.md`
7. When CLI is available, run `openspec validate <change-id>` to verify artifacts
8. Present the plan for human review

Do not write `tasks/uncle-dev-plan.md` or `tasks/todo.md`. The tracked outputs are `openspec/changes/<change-id>/tasks.md` and `openspec/changes/<change-id>/execution.md`.
