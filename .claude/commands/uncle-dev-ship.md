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
_cfg="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[[ ! -f "$_cfg" ]] && _cfg=$(find "${HOME}/.claude/plugins" -name "uncle-dev-config.sh" 2>/dev/null | head -1)
SDD_MODE=$(bash "$_cfg" preferences.sdd_mode 2>/dev/null || echo "")
# Auto-detect from filesystem when config doesn't set a mode
if [[ -z "$SDD_MODE" ]]; then
  [[ -d "openspec" ]] && SDD_MODE="openspec" || SDD_MODE="lid-ears"
fi
echo "$SDD_MODE"
```

**Route based on result — pick exactly one path:**

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path. Do NOT run any `openspec` command.**

Invoke the agent-skills:uncle-dev-shipping-and-launch skill.

Pre-ship verification (run before the checklist):

1. **Tasks complete** — Read `docs/tasks/*.md`; confirm all items are `- [x]`. List any unchecked items and stop if found.
2. **EARS coverage** — Read `docs/ears/*.md`; for each requirement (R-x.y), confirm at least one test asserts it. List any uncovered requirements and stop if found.
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

**If sdd_mode is `openspec` or missing: follow this path.**

Invoke the agent-skills:uncle-dev-shipping-and-launch skill.

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
