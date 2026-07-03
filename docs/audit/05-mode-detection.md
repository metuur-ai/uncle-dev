# 05 — Centralize SDD-mode detection; close mode gaps (P1)

## Problem

The ~20-line Step-0 SDD-mode detection bash block is copy-pasted verbatim
into 8 command files, has a divergent 9th variant, a detection blindspot, a
prose/code contradiction, and two commands are entirely mode-blind.

### Finding A — duplicated 8× (+7 stale fork copies)

Identical block (including the same 4-line comment) in:
`commands/uncle-dev-spec.md`, `uncle-dev-plan.md`, `uncle-dev-build.md`,
`uncle-dev-next-task.md`, `uncle-dev-review.md`, `uncle-dev-ship.md`,
`uncle-dev-acknowledge.md`, `uncle-dev-openspec-sync.md`. Any semantic change
requires 8 synchronized edits — 16 counting the plugin fork (audit file 03).

### Finding B — autodetect blindspot: plural `docs/llds` tree

Two lid-ears doc trees exist in the ecosystem:

- **Singular per-slug**: `docs/hld/ lld/ ears/ tasks/` — used by spec, plan,
  build, review, ship, acknowledge.
- **Plural per-segment**: `docs/llds/ specs/ arrows/` — used by
  `uncle-dev-brownfield.md` (3 refs), `uncle-dev-design-docs.md`,
  `uncle-dev-spec-graph.md`.

Step-0 autodetect checks only `docs/{ears,hld,lld}`. A repo that adopted only
the segment tree (via /uncle-dev-brownfield or /uncle-dev-design-docs) will
NOT autodetect lid-ears and may fall through to openspec.

### Finding C — "(default)" prose contradicts the code

Every Step-0 script defaults to `lid-ears` when nothing is detected
(`commands/uncle-dev-spec.md:21`), but each Path B header says "If sdd_mode
is `openspec` **or missing**: follow this path" and is labeled "(default)"
(`uncle-dev-spec.md:200-202`; same in plan/build/ship). Since Step 0 always
yields a value, "missing" is unreachable — but a model that skips the bash
step follows the prose and lands in openspec mode.

### Finding D — next-task SKILL Phase 0 has no fallback

`skills/uncle-dev-next-task/SKILL.md:76-86` reads sdd_mode with default `""`
and the routing table has no row for empty — undefined behavior when the
skill is invoked directly rather than via the command wrapper.

### Finding E — mode-blind commands

- `commands/uncle-dev-test.md` — never reads sdd_mode; never points tests at
  `docs/ears/` requirements or openspec acceptance criteria (0 grep hits).
- `commands/uncle-dev-wrap.md` — same; handoffs don't record the mode or link
  mode-specific artifacts.

### Finding F — acknowledge gate is openspec-only

The non-bypassable gate lives in `openspec/acknowledge/`
(`skills/uncle-dev-next-task/acknowledge-gate.md`,
`commands/uncle-dev-build.md:134`). lid-ears mode gets ADRs with no gating
(`commands/uncle-dev-acknowledge.md:31-33`); lid-ears next-task Path A has no
ack step — pending design decisions never block work in lid-ears.

### Finding G — live demonstration in this repo

This repo has both `docs/{hld,ears}` and `openspec/`; config+autodetect
resolve to lid-ears; the openspec change
`openspec/changes/companion-modes-foundation/` has **29 unchecked tasks that
are permanently invisible** to `/uncle-dev-next-task` (which reports "all
tasks complete; run /uncle-dev-ship"). The change's ID also fails the
`^[0-9]{3}-` format required by `commands/uncle-dev-spec.md:216` and
`hooks/openspec-guard.sh`, and it is missing `execution.md` and `handoff.md`
of the required 5 artifacts. Additionally,
`commands/uncle-dev-next-task.md:71`'s lid-ears "all complete" exit says run
`/uncle-dev-ship` — jumping Build→Ship past the documented Verify/Review
phases.

## Change instructions

1. **Create `scripts/uncle-dev-detect-mode.sh`** — single owner of the
   logic: config value via `uncle-dev-config.sh preferences.sdd_mode` →
   filesystem autodetect → default. Autodetect must include the plural tree:
   `docs/ears`, `docs/hld`, `docs/lld`, **`docs/llds`, `docs/specs`** for
   lid-ears; `openspec/` for openspec. Print exactly `lid-ears` or
   `openspec`. Document tie-breaking (both trees present → config wins; no
   config → prefer lid-ears, matching today's default) in the script header.
2. **Replace the 8 inline blocks** with a short call:
   `_mode=$(bash "$_scripts/uncle-dev-detect-mode.sh")` (reuse the loader
   resolution convention from audit file 04). Keep one line of comment
   pointing at the script for semantics.
3. **Fix the prose**: change every Path B header from "openspec or missing
   (default)" to "If sdd_mode is `openspec`". Add one sentence after Step 0:
   "If you could not run Step 0, treat the mode as `lid-ears`." (matches the
   code default).
4. **Fix next-task SKILL Phase 0**
   (`skills/uncle-dev-next-task/SKILL.md:76-86`): route empty →
   `lid-ears` (or call the new script), so direct skill invocation is
   defined.
5. **Add mode awareness to test and wrap**:
   - `uncle-dev-test.md`: after mode detection, in lid-ears point test
     mapping at `docs/ears/<slug>.md` requirement IDs; in openspec at the
     change's acceptance criteria/tasks.
   - `uncle-dev-wrap.md`: record resolved mode in the handoff and link the
     mode's artifacts (docs/tasks vs openspec/changes/<id>/).
6. **Decide the lid-ears acknowledge gap** (scope decision — smallest viable
   fix): add a lid-ears equivalent check to next-task Path A ("if
   `docs/adr/` has entries with status `proposed`, surface them before
   picking a story"), or explicitly document the asymmetry in
   `commands/uncle-dev-acknowledge.md` as intended.
7. **Fix the next-task lid-ears exit** (`commands/uncle-dev-next-task.md:71`):
   "all tasks complete" should route to `/uncle-dev-review` (then ship), not
   straight to ship.
8. **Clean this repo's own state** (Finding G): either complete/archive
   `openspec/changes/companion-modes-foundation/` (rename to `NNN-slug`
   format, add missing artifacts, or archive it), or delete it if
   abandoned — so the repo stops demonstrating the dual-mode hazard.
9. **Regenerate the plugin fork** (audit file 03) after these edits.

## Expected result after

- One place defines mode semantics; a future change is a one-file edit.
- A brownfield project with only `docs/llds`/`docs/specs` correctly resolves
  to lid-ears.
- A model that skips the bash step no longer lands in openspec by prose
  default.
- `/uncle-dev-test` maps tests to the active mode's requirement source;
  `/uncle-dev-wrap` handoffs say which mode they were produced under.
- This repo's own `/uncle-dev-next-task` output is truthful (no invisible
  29-task change).

## Verification

```bash
grep -rln 'docs/ears.*docs/hld\|Step 0' commands/ | xargs grep -l 'sdd_mode detection' \
  # expect: the inline block appears 0 times; all call uncle-dev-detect-mode.sh
tmp=$(mktemp -d) && mkdir -p "$tmp/docs/llds" && (cd "$tmp" && bash /path/to/scripts/uncle-dev-detect-mode.sh)
  # expect: lid-ears
grep -n 'or missing' commands/uncle-dev-*.md        # expect: no matches
bash scripts/tests/run-all.sh                       # includes mode-branch-split.test.sh — green
```
