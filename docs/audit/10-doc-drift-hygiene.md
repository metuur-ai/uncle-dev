# 10 — Documentation drift, dead references, hygiene (P2)

## Problem

Five diverging copies of the component inventory, 14 dead file references in
skills, stale AGENTS.md, the repo violating two of its own boundary rules,
orphan files, and global-install side effects.

### Finding A — five diverging inventories of the same components

1. **CLAUDE.md phase list #1** (top of file) — covers 37/46 skills.
2. **CLAUDE.md phase list #2** (uncle-dev section) — covers 32/46; drops
   `uncle-senior` (the whole Evaluate phase),
   `uncle-dev-source-driven-development`,
   `uncle-dev-dev-code-simplification`, `uncle-dev-ci-cd-and-automation`,
   `uncle-dev-deprecation-and-migration` relative to list #1.
3. **setup-project.sh injected list** (`scripts/setup-project.sh:337-345`) —
   covers 24/46; omits entire Brownfield/Evaluate/Handoff phases.
4. **AGENTS.md** — badly stale: its "Skill Commands" table (lines 27-45)
   lists 13+ slash commands that don't exist
   (`/uncle-dev-context-engineering`, `/uncle-dev-security-and-hardening`,
   `/uncle-dev-frontend-ui-engineering`, agent commands
   `/uncle-dev-code-reviewer` etc.), and omits all newer commands (setup,
   mode, wrap, spec-scan, spec-graph, uncle-senior, pro, debt, big-idea…).
5. **README.md** — line 16 says "29 commands" (correct), line 323 says
   "26 slash commands" (wrong); README:43 repeats the phantom
   `/uncle-dev-feature-map`.

Additional list drift:

- CLAUDE.md command list (line 11): lists phantom `/uncle-dev-feature-map`
  (see audit file 07); omits 9 real commands (big-idea, custom-me, debt,
  knowledge-capture, knowledge-maintenance, mode, openspec-sync, setup,
  spec-annotations).
- CLAUDE.md agents line names 3 personas; disk has 9.
- 9 skills appear in **no** phase list: business-observability, code-context,
  graphify-aware-analysis, initiative-map, next-task,
  over-engineering-audit, pre-mortem, setup, using-agent-skills.

### Finding B — 14 dead file references in 8 SKILL.md files

Root cause 1 — phantom `references/` subdir (files live at skill root, or in
a *different* skill):

- `skills/uncle-dev-security-and-hardening/SKILL.md:305` →
  `references/security-checklist.md` (actual: `./security-checklist.md`)
- `skills/uncle-dev-performance-optimization/SKILL.md:304` →
  `references/performance-checklist.md` (actual: `./performance-checklist.md`)
- `skills/uncle-dev-frontend-ui-engineering/SKILL.md:280` →
  `references/accessibility-checklist.md` (actual: `./accessibility-checklist.md`)
- `skills/uncle-dev-test-driven-development/SKILL.md:364` →
  `references/testing-patterns.md` (actual: `./testing-patterns.md`)
- `skills/uncle-dev-code-review-and-quality/SKILL.md:436,437` → checklists
  that live in the security/performance **skills**, not here
- `skills/uncle-dev-shipping-and-launch/SKILL.md:294,295,296` → three
  checklists, all in other skills

Root cause 2 — docs moved under `docs/originals/`:

- `skills/uncle-dev-custom-me/SKILL.md:26,115` → `docs/skill-anatomy.md`
  (actual: `docs/originals/skill-anatomy.md`)
- `skills/uncle-dev-setup/SKILL.md:15` → `docs/cursor-setup.md`,
  `docs/windsurf-setup.md`, `docs/copilot-setup.md` (all under
  `docs/originals/`)
- also `commands/uncle-dev-custom-me.md:151` → `docs/skill-anatomy.md`, and
  root CLAUDE.md Boundaries references `skill-anatomy.md` format

### Finding C — the repo violates its own boundaries

- **CLAUDE.md and AGENTS.md coexist at project root** — explicitly forbidden
  by the repo's own Code Context rule. Worse, `setup-project.sh:289`
  unconditionally `touch`es CLAUDE.md when Claude Code is detected even if
  AGENTS.md exists (AGENTS.md presence is itself the OpenCode detection
  signal at line 115) — the setup script manufactures the forbidden state in
  target projects.
- **CLAUDE.md mandates graphify for every subagent** ("live knowledge graph
  at graphify-out/graph.json") but `graphify-out/` **does not exist** — every
  spawned agent burns a failed check on every task.

### Finding D — orphans and stale state

- `skills/uncle-dev-initiative-map/README.md` — referenced nowhere (only
  skill dir with a README).
- `skills/uncle-dev-spec-annotations/requirements.txt` — referenced nowhere.
- `.claude/settings.json` — a single newline byte; invalid JSON.
- Legacy `.uncle-dev/research/` (8 tracked files) alongside the current
  convention `.devlocal/research/` — never migrated.
- `tmp/destructive-commands.md` — referenced by
  `hooks/destructive-command-guard.sh:16`; `tmp/` is not a durable location
  for a design source.
- Three overlapping docs trees (`docs/originals/`, `docs/improved/`,
  `docs/v2/`) with no pointer to which is canonical (spec-annotations guides
  exist in all three).
- `/uncle-dev-mode`'s "session" flag `.uncle-dev/session-mode` is never
  cleaned up — session strictness is actually sticky project state
  (`hooks/uncle-dev-mode.sh:56-60`, `scripts/uncle-dev-config.sh:159-170`).
- Two scratch-stamp conventions: `wrap-nudge.sh` writes
  `.claude/.wrap-nudged`; `knowledge-capture-nudge.sh` uses
  `.devlocal/knowledge-nudge/`.

### Finding E — global-install side effects in non-uncle-dev projects

Hooks fire unconditionally in every project the user opens:

- `session-start.sh:47` — `mkdir -p .devlocal/handoffs` in every project;
  `.devlocal/` may not be gitignored there and can get committed.
- Skill-discovery flowchart injected into every session regardless of
  project.
- wrap-nudge creates `.claude/.wrap-nudged` everywhere.
- destructive-command-guard applies uncle-dev policy (flagging `git merge`/
  `git rebase`) everywhere.

No hook checks "is this an uncle-dev project" (e.g. presence of
`.agents/uncle-dev-setup.yaml`).

### Finding F — skill convention conformance (decide, then enforce)

- Only 6/46 skills have all six required sections; **40/46 lack a
  "When to Use" heading** (trigger info lives in frontmatter). The convention
  text and reality must be reconciled — either fix skills or amend CLAUDE.md.
- 5 descriptions violate the "third person + Use when…" rule:
  business-observability (no trigger), uncle-senior, pre-mortem,
  graphify-aware-analysis (noun starts), idea-refine (redundant double
  opening).
- `skills/uncle-dev-code-context/SKILL.md` is a 27-line tombstone
  ("CONVERTED TO RULE") — delete the skill (and update marketplace.json +
  installers) or exempt it explicitly.
- `skills/uncle-dev-pre-mortem/SKILL.md` — missing all 6 sections (65
  lines); bring to standard, especially since audit file 07 promotes it to a
  command.
- 18 supporting files under the 100-line threshold (worst:
  `custom-me/templates/companion-skill.md` at 21 lines) — templates arguably
  exempt; decide and write the exemption down.
- `nori-lint` reports 367 violations across 46/46 skills (report-only) —
  after deciding conventions, curate `scripts/nori-lint.config.json` and
  consider gating with `--enforce` in CI.

## Change instructions

1. **Generate inventories from disk.** Extend `scripts/check-manifest.sh` (or
   add `scripts/gen-inventory.sh`) to emit the canonical command list and
   phase table from `commands/` + skill frontmatter into marked blocks
   (`<!-- BEGIN GENERATED -->`) in CLAUDE.md and README; check-manifest fails
   when the blocks are stale. Collapse CLAUDE.md's two phase lists into one.
   Rewrite AGENTS.md's command table from the same generator or delete the
   table and link to CLAUDE.md. Fix README line 323 ("26" → generated count).
   Make `setup-project.sh` inject the generated list (or a link) instead of
   its own third copy.
2. **Fix the 14 dead references** (Finding B): point at the real paths;
   for cross-skill checklists use explicit
   `skills/uncle-dev-security-and-hardening/security-checklist.md` style
   paths. Add a link-checker loop to check-manifest: every relative `.md`
   path mentioned in skills/ and commands/ must exist.
3. **Resolve the root-level rule violations** (Finding C): pick CLAUDE.md as
   the root file, fold AGENTS.md's still-relevant content in, and delete or
   demote AGENTS.md; fix `setup-project.sh:289` to skip creating CLAUDE.md
   when AGENTS.md exists (warn instead). For graphify: either commit a
   generated `graphify-out/` or make the CLAUDE.md instruction conditional
   ("if graphify-out/graph.json exists…") — matching what the skills already
   do.
4. **Clean orphans** (Finding D): delete or wire
   `initiative-map/README.md` and `spec-annotations/requirements.txt`; make
   `.claude/settings.json` valid (`{}`) or delete it; migrate
   `.uncle-dev/research/` → `.devlocal/research/` (or document the legacy
   dir); move `tmp/destructive-commands.md` → `hooks/` or `docs/` and update
   the guard's reference; give `.uncle-dev/session-mode` a TTL or clear it in
   `session-start.sh`; pick one scratch-stamp convention.
5. **Scope hooks to uncle-dev projects** (Finding E): at the top of
   session-start, wrap-nudge, knowledge-capture-nudge and the guards, exit 0
   unless `.agents/uncle-dev-setup.yaml` exists (destructive-command-guard
   may deliberately stay global — decide and document). Coordinate with
   audit file 01's shared lib (`hook_require_project`).
6. **Reconcile skill conventions** (Finding F): amend CLAUDE.md to say
   trigger conditions live in frontmatter `description` (matching 40/46
   reality) and drop "When to Use" from the required list — or mass-add the
   heading; fix the 5 non-conforming descriptions; delete or exempt
   code-context; flesh out pre-mortem; write down the template exemption to
   the 100-line rule; then curate nori-lint rules and enable `--enforce` in
   CI for the agreed set.
7. **Add docs-tree signpost**: one paragraph in `docs/README.md` (create it)
   declaring which of originals/improved/v2 is canonical and the status of
   the others.

## Expected result after

- One generated source of truth for the component inventory; drift turns CI
  red instead of accumulating.
- No skill or command references a file that doesn't exist; a new dead link
  fails check-manifest.
- The repo obeys its own boundary rules (single root instruction file;
  graphify instruction matches reality).
- Opening an unrelated project with the plugin installed no longer creates
  `.devlocal/` dirs or injects uncle-dev context.
- Skill conventions are enforceable because they match reality, and
  nori-lint gates on the agreed rule set.

## Verification

```bash
bash scripts/check-manifest.sh                       # green, incl. inventory + link checks
# dead-link sweep
grep -rn 'references/security-checklist\|references/performance-checklist\|references/accessibility-checklist\|references/testing-patterns\|docs/skill-anatomy\.md\|docs/cursor-setup\.md' skills/ commands/ CLAUDE.md
                                                     # expect: none
ls AGENTS.md 2>/dev/null                             # expect: gone (or documented exception)
python3 -c 'import json;json.load(open(".claude/settings.json"))'   # valid or file absent
# hook scoping
cd "$(mktemp -d)" && echo '{}' | bash /path/to/hooks/session-start.sh; ls .devlocal 2>/dev/null
                                                     # expect: no .devlocal created outside uncle-dev projects
bash scripts/lint-skills.sh --enforce                # green on the curated rule set
```
