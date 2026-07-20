---
description: Implement the next task incrementally — build, test, verify, commit
---

## Working Principles

1. **Think Before Coding** — Read the acceptance criteria and existing code before writing a single line. If the story is ambiguous, stop and clarify.
2. **Simplicity First** — Implement the minimum code to pass the test. Resist "while I'm here" improvements.
3. **Surgical Changes** — Touch only what the story requires. Don't refactor adjacent code, fix unrelated issues, or clean up pre-existing style.
4. **Goal-Driven Execution** — Write a failing test first. Success means: test passes, build succeeds, no regressions, story marked complete.

---

## Step 0: Read SDD mode and execution profile, then resolve the next task

```bash
_scripts="${CLAUDE_PLUGIN_ROOT:-}/scripts"
[[ ! -f "$_scripts/uncle-dev-detect-mode.sh" ]] && \
  _scripts="$(ls -1d "${HOME}/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/"*/ 2>/dev/null | sort -V | tail -1)scripts"
_mode=$(bash "$_scripts/uncle-dev-detect-mode.sh")
# For mode semantics see scripts/uncle-dev-detect-mode.sh
_cfg="${_scripts}/uncle-dev-config.sh"
EXECUTION_PROFILE=$(bash "$_cfg" preferences.execution_profile balanced 2>/dev/null || echo "balanced")
TDD_MODE=$(bash "$_cfg" preferences.tdd-mode lite 2>/dev/null || echo "lite")
echo "$_mode"
echo "$EXECUTION_PROFILE"
echo "$TDD_MODE"
```

If you could not run Step 0, treat the mode as `lid-ears`.

Run `/uncle-dev-next-task --claim` (which is now sdd_mode-aware) to:

- In `lid-ears` mode: detect `docs/tasks/*.md`, compute the ready set, acquire a lock
- In `openspec` mode: detect OpenSpec CLI, `openspec/` dir, `.devlocal/` scratchpads, compute ready set, acquire a lock
- Recommend one story with a clear `why:` line
- If the user has already named a story, pass `--story <id>` to skip recommendation

If `uncle-dev-next-task` reports the ready set is empty or there is no tracked work, stop and follow its guidance — do not invent work.

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path.**

Resolve the active skills and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-incremental-implementation
bash "$_loader" uncle-dev-test-driven-development
bash "$_loader" uncle-dev-code-context
```

Honor every `SKILL:` and `COMPANION:` line emitted above per the skill-loading directive in your project CLAUDE.md.

For the chosen story:

0. Use the code-context skill — identify all directories to be edited, read their `AGENTS.md` files, validate architecture boundary compliance before writing any code
1. Read the story's acceptance criteria from `docs/tasks/<slug>.md`
2. Look up the full EARS statement in `docs/ears/<slug>.md` using the referenced requirement ID (e.g. R-1.1)
3. Load relevant context (existing code, patterns, types) and consult `docs/lld/<slug>.md` for design constraints
4. Break the implementation into private technical steps in `.devlocal/<user>/<story-id>/scratchpad.md`
5. Write a failing test that directly asserts the EARS requirement (RED)
6. Implement the minimum code to pass the test (GREEN)
7. Verify based on profile:
   - `strict` -> run full test suite + full build on every slice
   - `balanced` -> run targeted tests per slice; run full suite + build when story is marked complete
   - `fast` -> run targeted tests only per slice; run full suite + build before merging/releasing
8. If `tdd-mode: strict`, keep red-green proof for each behavior; if `tdd-mode: lite`, test complex/critical behavior and skip red-first for trivial changes
9. Promote shared discoveries:
   - Update `docs/tasks/<slug>.md` for shared scope/task changes
   - Update `docs/lld/<slug>.md` if implementation changes shared technical constraints
   - No `execution.md` — cross-story coordination notes go in `.devlocal/`
10. Commit with a descriptive message
11. Mark the story complete in `docs/tasks/<slug>.md` (change `- [ ]` to `- [x]`) and move to the next

If any step fails, resolve and follow the debug-error skill:

```bash
bash "$_loader" uncle-dev-debug-error
```

Honor the `SKILL:` and `COMPANION:` lines emitted above before debugging.

---

## Path B — `openspec` mode

**If sdd_mode is `openspec`: follow this path.**

Resolve the active skills and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-incremental-implementation
bash "$_loader" uncle-dev-test-driven-development
bash "$_loader" uncle-dev-code-context
```

Honor every `SKILL:` and `COMPANION:` line emitted above per the skill-loading directive in your project CLAUDE.md.

For the chosen story:

0. Use the code-context skill — identify all directories to be edited, read their `AGENTS.md` files, validate architecture boundary compliance before writing any code
1. Read the story's acceptance criteria and dependencies
2. Load relevant context (existing code, patterns, types)
3. If useful, break the implementation into private technical steps in `.devlocal/<user>/<story-id>/scratchpad.md`
4. Write a failing test for the expected behavior (RED)
5. Implement the minimum code to pass the test (GREEN)
6. Verify based on profile:
   - `strict` -> full test suite + full build on every slice
   - `balanced` -> targeted tests per slice; full suite + build when story completes
   - `fast` -> targeted tests per slice; full suite + build before merge/release
7. Apply `tdd-mode` strictness (`strict` full prove-it, `lite` focused tests for non-trivial logic)
8. Promote shared discoveries:
   - Update `execution.md` for blockers or cross-story dependencies
   - Update `tasks.md` for shared scope/task changes
   - Update `design.md` if implementation changes shared technical constraints
9. Commit with a descriptive message
10. Mark the story complete and move to the next one

If `uncle-dev-next-task` reports `BLOCKED: pending acknowledgements`, do not proceed. Print the block message verbatim. The user must run `/uncle-dev-acknowledge ack <ids>` (or `reject` / `supersede` / hand-edit `openspec/acknowledge/<scope>.md`) and then re-invoke `/uncle-dev-build` before any code is written. This gate is **non-bypassable**.

If any step fails, resolve and follow the debug-error skill:

```bash
bash "$_loader" uncle-dev-debug-error
```

Honor the `SKILL:` and `COMPANION:` lines emitted above before debugging.
