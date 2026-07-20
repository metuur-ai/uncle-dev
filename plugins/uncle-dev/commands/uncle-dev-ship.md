---
description: Run the pre-launch checklist and prepare for production deployment
---

## Working Principles

1. **Think Before Coding** — Know the deployment target and rollback plan before starting the checklist. Don't begin a launch you can't reverse.
2. **Simplicity First** — Report actual failing checks, not hypothetical risks. Don't block launch on "nice to have" improvements.
3. **Surgical Changes** — Fix only what is blocking the launch. Improvements that aren't launch-critical go in a follow-up task.
4. **Goal-Driven Execution** — Success means every checklist item passes and a tested rollback path exists before deployment proceeds.

---

## Step 0 — Read SDD mode (do this first)

```bash
_scripts="${CLAUDE_PLUGIN_ROOT:-}/scripts"
[[ ! -f "$_scripts/uncle-dev-detect-mode.sh" ]] && \
  _scripts="$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts"
_mode=$(bash "$_scripts/uncle-dev-detect-mode.sh")
# For mode semantics see scripts/uncle-dev-detect-mode.sh
```

If you could not run Step 0, treat the mode as `lid-ears`.

**Route based on result — pick exactly one path:**

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path. Do NOT run any `openspec` command.**

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-shipping-and-launch
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Pre-ship verification (run before the checklist):

1. **Tasks complete** — Read `docs/tasks/*.md`; confirm all items are `- [x]`. List any unchecked items and stop if found.
2. **EARS coverage** *(MANUAL CHECK — no automated mechanism exists)* — Read `docs/ears/*.md`; for each requirement (R-x.y), manually verify that at least one test or observable behaviour asserts it. EARS `R-x.y` IDs are a manually-reviewed track; the `@spec` scanner does not validate them. List any uncovered requirements and flag them before proceeding. (Contrast: `@spec` annotations using `SEG-AREA-NNN` IDs are scanner-enforced via `scan-spec-coherence.py`.)
3. **Docs current** — Confirm `docs/hld/<slug>.md`, `docs/lld/<slug>.md`, `docs/ears/<slug>.md` reflect the shipped implementation. Flag any stale sections.

Then run the standard pre-launch checklist:

1. **Code Quality** — Tests pass, build clean, lint clean, no TODOs, no console.logs
2. **Security** — audit clean, no secrets in code, auth in place
3. **Performance** — no N+1 queries, bundle sized appropriately
4. **Accessibility** — keyboard nav works, screen reader compatible, contrast adequate
5. **Infrastructure** — env vars set, migrations ready, monitoring configured
6. **Documentation** — README current, ADRs written, changelog updated

Report any failing checks and help resolve them before deployment.
Define the rollback plan before proceeding.

---

## Path B — `openspec` mode (default)

**If sdd_mode is `openspec`: follow this path.**

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-shipping-and-launch
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

Check if the OpenSpec CLI is available (`openspec --version`). When available, use it to verify the change is ready to ship:

- `openspec validate <change-id>` to confirm all artifacts are well-formed
- `openspec status <change-id>` to verify all artifacts are complete
- After successful launch, `openspec archive <change-id>` to finalize the change and reconcile into main specs
- `openspec list --specs` to verify specs were updated after archiving

If not installed, recommend `npm install -g openspec` and proceed with manual checks.

Run through the complete pre-launch checklist:

1. **Code Quality** — Tests pass, build clean, lint clean, no TODOs, no console.logs
2. **Security** — npm audit clean, no secrets in code, auth in place, headers configured
3. **Performance** — Core Web Vitals good, no N+1 queries, images optimized, bundle sized
4. **Accessibility** — Keyboard nav works, screen reader compatible, contrast adequate
5. **Infrastructure** — Env vars set, migrations ready, monitoring configured
6. **Documentation** — README current, ADRs written, changelog updated

Report any failing checks and help resolve them before deployment.
Define the rollback plan before proceeding.
