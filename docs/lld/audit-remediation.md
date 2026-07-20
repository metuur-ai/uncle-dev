# Audit Remediation — Low-Level Design

## Architecture

Ten work units, each self-contained and commitable, executed in four waves:

- **Wave 1 (parallel-safe):** 01, 02, 04, 05 — foundational fixes with no
  inter-unit dependencies; 05 (centralized mode detection) lands here so that
  the eight command files carry the corrected mode-detection call before the
  plugin fork is frozen.
  *Intra-wave merge order for `skills/uncle-dev-setup/uncle-dev-setup.template.yaml`:*
  Unit 02 normalizes the `sdd_mode` two-line scalar at line 89–90 of this
  template. Unit 05 reads and detects from the config value produced by that
  template but does NOT edit the template file itself. Merge 02 before 05 to
  avoid any rebase conflict; if both land simultaneously, Unit 02's template
  edit takes precedence and Unit 05 needs no template change.
- **Wave 2:** 03, 08 — 03 (sync-plugin.sh + sha256 drift check) runs after
  Wave 1 so the regenerated `plugins/uncle-dev/commands/` copies inherit the
  fixed sources from 04 and 05; 08 (cache-path corrections) lands with 03
  because it edits commands that 03 will immediately re-sync.
- **Wave 3:** 06, 07 — plan/next-task handoff grammar and missing commands;
  these may edit `commands/` files, so re-run `scripts/sync-plugin.sh` after
  Wave 3 to keep the fork current (the sha256 drift check in `check-manifest.sh`
  will surface any forgotten sync).
- **Wave 4:** 09, 10 — installer safety and doc hygiene; no command-file changes
  that require another sync pass.

---

### Work Unit 01 — Rebuild the hook layer on one contract

**New component: `hooks/lib/hook-contract.sh`**

Shared library sourced by every hook that touches tool-call events:

- `hook_read_input` — reads stdin once into `HOOK_INPUT`; exports
  `HOOK_TOOL_NAME`, `HOOK_FILE_PATH`, `HOOK_COMMAND`, `HOOK_CONTENT`,
  `HOOK_NEW_STRING` from `jq -r '.tool_name // empty'`,
  `.tool_input.file_path // empty`, `.tool_input.command // empty`, etc.
  Opens with `command -v jq >/dev/null || exit 0`.
- `hook_block "message"` — prints message to **stderr**, then `exit 2` (the
  real PreToolUse block contract; not `exit 1`, not stdout JSON).
- `hook_advise "message"` — for **PreToolUse and PostToolUse** hooks: emits
  `{"hookSpecificOutput":{"additionalContext":"<message>"}}` on stdout at
  `exit 0` (the advisory output shape per current Claude Code docs).
  **Stop and SubagentStop hooks must NOT use `hook_advise`** — for those
  events the correct advisory shape is `{"priority":"…","message":"…"}` on
  stdout (as used by the existing `hooks/wrap-nudge.sh`). A separate helper
  `hook_advise_stop "message"` emits that shape.
  The legacy `{"priority","message"}` schema is NOT used in PreToolUse/PostToolUse
  hooks; it is the correct schema for Stop/SubagentStop.
- `hook_allow` — `exit 0` silently.
- `hook_require_project` — exits 0 **without any output** when
  `.agents/uncle-dev-setup.yaml` is absent in `PROJECT_DIR`. This is the
  primary safety valve for global hooks running in unrelated repos: the hook
  must allow the operation silently, not error, not print, and not create any
  directories. Used by Work Unit 10 to scope hooks to uncle-dev projects.

**Migrated inert hooks (source lib, replace env-var reads)**

- `hooks/check-agents-md.sh` (line 6) — replaces
  `FILE_PATH="${CLAUDE_TOOL_INPUT_file_path:-}"` with `hook_read_input`
  + `HOOK_FILE_PATH`.
- `hooks/openspec-guard.sh` (line 11) — same migration; advisory branches
  switch to `hook_advise`.
- `hooks/spec-coherence-guard.sh` (lines 69, 79, 129, 176) — replaces all
  `CLAUDE_TOOL_INPUT_*` / `CLAUDE_TOOL_NAME` reads with the `HOOK_*` vars;
  scanner fallback path corrected under Work Unit 08.

**Fixed wrong-exit guards**

- `hooks/pre-commit-guard.sh:61` — replaces `exit 1` + JSON on stdout with
  `hook_block`; advisory branches switch to `hook_advise`.
- `hooks/destructive-command-guard.sh:105` — same. Allowlist reworked
  (lines 17–36): split command string on `;`, `&&`, `||`, `|`, `$(`,
  backticks before allowlist matching; patterns anchored (`ls*` → exact
  `ls ` prefix, not prefix glob); `sed *` removed or special-cased to
  `sed -i`; bare `rm <path>` added as a separate pattern.

**Finding E fixes (robustness)**

- `hooks/session-start.sh:66` — adds `command -v jq >/dev/null || exit 0`
  guard before the jq call.
- `hooks/hooks.json` — all 12 command strings quote the path variable:
  `bash "${CLAUDE_PLUGIN_ROOT}/hooks/…"` (prevents space-in-path breakage).
- `hooks/hooks.json:72` — Notification matcher `"permission_prompt"` verified
  against current Claude Code docs; corrected or removed.
- `hooks/pre-commit-guard.sh:27–30` — extends commit-message extraction to
  handle heredoc style `$(cat <<'EOF'…)` or drops the fragile extraction
  with a documented comment.
- `hooks/gate-notify.sh:36–38` — scoped to last assistant message only
  (not concatenation of 200 events).
- `hooks/wrap-nudge.sh:14` — dead `CONFIG_FILE` variable pointing at
  `.agents/uncle-dev-setup.yaml` deleted.
- Executable bits normalized: `chmod +x` on `destructive-command-guard.sh`,
  `knowledge-capture-nudge.sh`, `openspec-guard.sh`, `pre-commit-guard.sh`.

**New test: `scripts/tests/hook-contract.test.sh`**

For each wired PreToolUse/PostToolUse hook: (a) pipe a synthetic tool-call
JSON on stdin; assert blocking cases exit 2 with non-empty stderr; (b) allow
cases exit 0; (c) `grep -rn 'CLAUDE_TOOL' hooks/*.sh` returns empty after
migration. Stop-event hooks (`gate-notify.sh`, `wrap-nudge.sh`) are tested
separately for their exit-code and `{"priority","message"}` output contract,
not for the `hookSpecificOutput` shape.
Added to the explicit TESTS array in `scripts/tests/run-all.sh`
(`"${SCRIPT_DIR}/hook-contract.test.sh"`) as the tenth suite entry.

**Interconnection:** `hook-contract.sh` is the single shared lib; migrated
hooks source it via `source "${BASH_SOURCE%/*}/lib/hook-contract.sh"`.
Work Unit 10's `hook_require_project` helper lives in the same lib and is
called at the top of session-start, wrap-nudge, knowledge-capture-nudge, and
the guards.

---

### Work Unit 02 — Fix setup-project.sh config writes and config boundary

**Template fix: `skills/uncle-dev-setup/uncle-dev-setup.template.yaml:89–90`**

Normalize two-line scalar to single-line:
`sdd_mode: "lid-ears"  # lid-ears | openspec`. Audit the rest of the template
for other two-line scalars and normalize them.

**Config write fix: `scripts/setup-project.sh:226`**

After template normalization the sed pattern matches. Preferred path: add an
optional `--set preferences.sdd_mode <value>` mode to
`scripts/uncle-dev-config.sh` so the write goes through the single owner.
Fallback if `--set` is deferred: keep sed but add a post-write assertion:
`[[ "$(bash scripts/uncle-dev-config.sh preferences.sdd_mode)" == "$SDD_MODE" ]] || die`.

**Config read fix: `scripts/setup-project.sh:178–186`**

Replace the five direct `grep … | awk` calls on `${CONFIG_FILE}` with
`bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.sdd_mode` etc.
Treat empty output as default explicitly:
`SDD_MODE="${SDD_MODE:-lid-ears}"` (the `|| echo "lid-ears"` fallback on the
grep was wrong because it only fires on grep failure, not empty output).

**Hook toggle enforcement (locked decision: Honor the six hooks.* toggles)**

*Schema and template status (verified):* `scripts/uncle-dev-setup.schema.json`
already defines all six `hooks.*` keys (`session_start`, `pre_commit`,
`spec_coherence`, `openspec_guard`, `destructive_command_guard`,
`knowledge_capture_nudge`) as `boolean` with `true` defaults in both the schema
`required` list and `skills/uncle-dev-setup/uncle-dev-setup.template.yaml`. The
`uncle-dev-config.sh` helper resolves them via normal scalar reads (no schema
change required). The only gap is the runtime: six hook scripts ignore the
toggle. Closing that gap:

At the top of each of the six hook scripts that currently fire
unconditionally, add — mirroring the `wrap-nudge.sh:26` pattern exactly:

```bash
[[ "$(bash "$CFG_SCRIPT" hooks.<name> true 2>/dev/null)" == "false" ]] && exit 0
```

Targets: `check-agents-md.sh` (`hooks.check_agents_md`),
`pre-commit-guard.sh` (`hooks.pre_commit`),
`spec-coherence-guard.sh` (`hooks.spec_coherence`),
`openspec-guard.sh` (`hooks.openspec_guard`),
`destructive-command-guard.sh` (`hooks.destructive_command_guard`),
`knowledge-capture-nudge.sh` (`hooks.knowledge_capture_nudge`).
These checks are added at the top of each file, after the jq guard and after
`hook_read_input` sourcing (Work Unit 01).

**Boundary fixes**

- `skills/uncle-dev-setup/SKILL.md:220,228` — prose changed to instruct
  reading via `uncle-dev-config.sh --list hooks` / scalar calls, never the
  YAML file directly.
- `hooks/wrap-nudge.sh` — adds `cd "$PROJECT_DIR"` before calling the config
  helper so the helper resolves `.agents/uncle-dev-setup.yaml` relative to the
  project root (coordinates with Work Unit 01's cwd-safe pattern).
- `CLAUDE.md` Boundaries audit guard widened to also catch grep and
  variable-path access:
  `grep -rn 'setup\.yaml' scripts/ hooks/ commands/ | grep -v uncle-dev-config.sh | grep -v '^\s*#'`

**Python dependency guard: `scripts/uncle-dev-config.sh`**

Adds a `command -v python3 && python3 -c 'import yaml' 2>/dev/null` check in
the validate path. On failure prints a one-line warning to stderr and still
returns defaults; never silently evaporates the config layer.

---

### Work Unit 03 — Eliminate the plugins/uncle-dev/commands/ content fork

**(Locked decision: Strategy 1 — Generate)**

**New script: `scripts/sync-plugin.sh`**

Single responsibility: regenerate `plugins/uncle-dev/commands/` from canonical
`commands/` by plain copy (or copy+transform if a legitimate difference exists,
in which case the transform is the documentation of the difference).
Invoked manually after any `commands/` edit, and by CI. Run immediately to
sync the 7 stale files (uncle-dev-build.md, uncle-dev-plan.md,
uncle-dev-spec.md, uncle-dev-test.md, uncle-dev-review.md, uncle-dev-ship.md,
uncle-dev-code-simplify.md).

**Content-hash drift check: `scripts/check-manifest.sh`**

New guard function added after the existing `compare_sets` name-check (around
line 220): compare the SHA-256 content hash of each `commands/*.md` against
its mirror in `plugins/uncle-dev/commands/*.md`. On any mismatch, fail with
the message: `DRIFT: <filename> — run scripts/sync-plugin.sh`.

*Portability:* macOS ships `shasum -a 256`, not `sha256sum`; the repo's
existing scripts (e.g. `hooks/simplify-ignore.sh`) use a portable resolver
pattern. The drift guard must use the same pattern:
```bash
sha256_of() { command -v sha256sum >/dev/null 2>&1 && sha256sum "$1" | awk '{print $1}' || shasum -a 256 "$1" | awk '{print $1}'; }
```
If neither `sha256sum` nor `shasum` is present, the function prints an error
to stderr and returns a non-zero exit code (fail with a clear error rather
than silently passing).

Wired into `scripts/tests/run-all.sh` automatically because run-all.sh already
invokes `check-manifest.sh` as the drift guard.

**Sequencing dependency:** Work Units 04 (loader fixes) and 05 (centralized
mode detection) are in Wave 1 and land before this unit (Wave 2), so the
regenerated copies inherit the corrected sources. If any Wave 3 unit (06 or 07)
subsequently edits `commands/` files, re-run `scripts/sync-plugin.sh` after that
wave; the sha256 drift check in `check-manifest.sh` surfaces any missed sync.

---

### Work Unit 04 — Fix the skill loader: validation, namespace, dead skill name

**Typo fix: `commands/uncle-dev-code-simplify.md:19`**

`uncle-dev-code-simplification` → `uncle-dev-dev-code-simplification`
(matches the actual `skills/uncle-dev-dev-code-simplification/` directory).

**Base-skill validation: `scripts/uncle-dev-load-skill.sh`**

After resolving the plugin root, add:
```bash
[[ -d "$plugin_root/skills/$BASE" ]] || {
  echo "ERROR: unknown skill '${BASE}'" >&2; exit 1; }
```
Fail-closed for unknown names; remain fail-open only for missing config
overrides. The plugin root is resolved via `CLAUDE_PLUGIN_ROOT` first, then
the script's own directory (`BASH_SOURCE/../..`).

**Namespace fix: `scripts/uncle-dev-load-skill.sh:63,70`**

`agent-skills:<base>` → `uncle-dev:<base>` (matching the plugin name in
`.claude-plugin/plugin.json`). The override fallback line at the bottom of the
script also updated.

**Prose references updated**

`grep -rn 'agent-skills:' commands/ skills/ scripts/` identifies all
occurrences; each replaced with `uncle-dev:`. Primary target:
`commands/uncle-dev-next-task.md:33`.

**Loader resolution canonicalization (Finding E)**

The `_loader=` resolution pattern is deduplicated across the ~24 command
files to a single canonical three-tier convention:
1. `${CLAUDE_PLUGIN_ROOT}/scripts/uncle-dev-load-skill.sh` (set by Claude Code
   for plugin content)
2. `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/../scripts/uncle-dev-load-skill.sh`
   (repo-local checkout)
3. `$(ls -1d ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/*/ 2>/dev/null | sort -V | tail -1)scripts/uncle-dev-load-skill.sh`
   (newest versioned cache — `sort -V | tail -1` instead of `find … | head -1`)

A scripted sed pass applies this uniformly; the plugin fork is regenerated via
Work Unit 03 afterwards.

**Skill-loading directive installed**

`scripts/setup-project.sh:328–351` — the injected CLAUDE.md block now includes
the Skill-loading directive (copied from
`skills/uncle-dev-setup/SKILL.md:353–355`). This repo's own CLAUDE.md
uncle-dev section also receives the directive.

**New loader test: `scripts/tests/`**

- Known-good skill name exits 0 and emits `SKILL: uncle-dev:<name>`.
- Bogus name exits non-zero with ERROR on stderr.
- Repo-lint loop: every `bash "$_loader" <name>` argument in `commands/` has
  a matching `skills/<name>/` directory (catches the original typo class).

---

### Work Unit 08 — Correct plugin-cache paths and the setup install check

**Canonical resolution snippet (documented in `scripts/README.md`)**

Priority order:
1. `${CLAUDE_PLUGIN_ROOT}` (set by Claude Code)
2. Repo-local `./scripts/…` (running inside a checkout)
3. `$(ls -1d ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/*/ 2>/dev/null | sort -V | tail -1)`
   (newest cache version — no doubled segment, no hardcoded version)

No personal paths, no `uncle-dev-agent-skills/uncle-dev-agent-skills` doubled
segment, no hardcoded version strings.

**Applied to six locations (Finding A)**

- `commands/uncle-dev-debt.md:13`
- `commands/uncle-dev-spec-scan.md:11`
- `commands/uncle-dev-overkill-detector.md:64` (also adds the missing version
  segment)
- `commands/uncle-dev-openspec-sync.md:38`
- `commands/uncle-dev-setup.md:15` (also removes hardcoded version `1.4.1`)
- `hooks/spec-coherence-guard.sh` scanner fallback

All `find … | head -1` fallbacks replaced with the `sort -V | tail -1`
pattern (Finding E, also coordinated with Work Unit 04).

**Install check fix: `commands/uncle-dev-setup.md:45–46`**

```bash
jq '.plugins | keys[]' | grep -q '^"uncle-dev@'
```
Replaces `has("uncle-dev-agent-skills@uncle-dev-agent-skills")` with a key
prefix match that survives future marketplace renames. Real key format is
`uncle-dev@uncle-dev-agent-skills` (`<plugin-name>@<marketplace-id>`).

**Personal path removed: `commands/uncle-dev-setup.md:17`**

`~/others/ai-agents/production-grade-agent-skills` deleted; the canonical
three-tier resolution covers all legitimate cases.

**Frontmatter added: `commands/uncle-dev-setup.md`**

```yaml
---
description: "Wire uncle-dev into this project — plugin check, scaffolding, config, hooks"
---
```

**Recurrence guard added to `scripts/check-manifest.sh`**

```bash
grep -rn 'uncle-dev-agent-skills/uncle-dev-agent-skills' commands/ hooks/ skills/
grep -rn 'cache/.*/1\.[0-9]' commands/ hooks/
```
Both must return empty; failure message names the offending file.

**Plugin fork regenerated** via `scripts/sync-plugin.sh` (Work Unit 03) after
all edits.

---

### Work Unit 06 — Fix plan → next-task handoff; reconcile spec universes

**Story grammar unified (locked decision: change the template)**

`skills/uncle-dev-planning-and-task-breakdown/SKILL.md:195,285` — story
templates changed from `## Story STORY-101: [Title]` (h2, non-numeric ID) to
`### Story 1.1: [Title]` (h3, numeric dotted ID matching the parser's grammar
at `skills/uncle-dev-next-task/parsing-and-annotations.md:15,33`).

**Annotations line added to plan template**

Plan skill Step 4 template gains an explicit per-story:
```
**Annotations:** [files: path/a.ts, path/b.ts] [mutex: Story-1.2] [depends: Story-1.1]
```
with a cross-reference to `parsing-and-annotations.md` for semantics, and a
note that omitting it forces sequential execution. The parallel-safe ready-set
machinery is now actually fed by the plan output.

**`handoff.md` creation removed from spec command**

`commands/uncle-dev-spec.md:217–219` — removed. The creation line and its
mention in the "required artifacts" enumeration are deleted. Real handoffs go
to `.devlocal/handoffs/` via `/uncle-dev-wrap`. References in the required
5-artifact enumeration updated to list 4 required artifacts.

**Change-ID format fixed**

`skills/uncle-dev-next-task/SKILL.md:27` — example `PF-001-foundations-cross-cutting`
replaced with a compliant `NNN-slug` example (`001-foundations-cross-cutting`).
The repo's own non-compliant change `openspec/changes/companion-modes-foundation/`
is handled per Work Unit 05 Finding G (renamed, archived, or deleted).

**Spec universes: Separate tracks (locked decision: Option 2 — Separate)**

- CLAUDE.md updated to state both tracks explicitly: EARS `R-x.y` IDs are
  reviewed manually; `@spec` annotations (`SEG-AREA-NNN` IDs) are scanner-
  enforced. The scanner's existing `[A-Z][A-Z0-9-]*-[0-9]+` ID regex is not
  extended to `R-\d+\.\d+`.
- `commands/uncle-dev-ship.md:57` — the unenforceable "for each requirement
  (R-x.y), confirm at least one test asserts it" wording is relabeled
  **MANUAL CHECK** with an explicit note that no automated mechanism exists.
  The phantom guarantee is removed.
- `docs/hld|lld|ears/` and `docs/specs/` (SEG-AREA track) documented as
  separate spec universes with no automated bridge.

**Round-trip test: `scripts/tests/plan-next-task-roundtrip.test.sh`**

Generate a plan file from the fixed template with 2 stories + annotations;
run the next-task parsing logic against it; assert both stories parse with
correct IDs and the ready-set respects the mutex annotation.
Wired into `scripts/tests/run-all.sh`.

---

### Work Unit 05 — Centralize SDD-mode detection; close mode gaps

**New script: `scripts/uncle-dev-detect-mode.sh`**

Single owner of the mode detection logic:

1. Read `uncle-dev-config.sh preferences.sdd_mode` (config tier).
2. If empty, autodetect from filesystem:
   - lid-ears: presence of any of `docs/ears`, `docs/hld`, `docs/lld`,
     `docs/llds`, `docs/specs` (plural tree added — Finding B).
   - openspec: presence of `openspec/`.
   - Tie-breaking: both present → config wins; no config → `lid-ears`
     (matching today's default). Documented in script header.
3. Print exactly `lid-ears` or `openspec` on stdout.

**8 inline blocks replaced**

`commands/uncle-dev-spec.md`, `uncle-dev-plan.md`, `uncle-dev-build.md`,
`uncle-dev-next-task.md`, `uncle-dev-review.md`, `uncle-dev-ship.md`,
`uncle-dev-acknowledge.md`, `uncle-dev-openspec-sync.md` — each replaces its
~20-line Step-0 block with:
```bash
_mode=$(bash "$_scripts/uncle-dev-detect-mode.sh")
# For mode semantics see scripts/uncle-dev-detect-mode.sh
```
where `$_scripts` uses the canonical three-tier resolution from Work Unit 04.

**Prose contradictions fixed**

Every Path B header changed from "If sdd_mode is `openspec` **or missing
(default)**:" to "If sdd_mode is `openspec`:". One sentence added after
Step 0: "If you could not run Step 0, treat the mode as `lid-ears`." This
matches the code default and eliminates the reachable-via-prose openspec
fallthrough (Finding C).

**next-task SKILL Phase 0 fixed**

`skills/uncle-dev-next-task/SKILL.md:76–86` — empty `sdd_mode` routed to
`lid-ears` (or delegates to `uncle-dev-detect-mode.sh`) so direct skill
invocation is defined behavior.

**Mode awareness added to test and wrap**

- `commands/uncle-dev-test.md` — after mode detection: lid-ears path points
  test mapping at `docs/ears/<slug>.md` requirement IDs; openspec path points
  at the change's acceptance criteria/tasks.
- `commands/uncle-dev-wrap.md` — records resolved mode in the handoff and
  links the mode's artifacts (`docs/tasks/` vs
  `openspec/changes/<id>/`).

**next-task lid-ears exit fixed**

`commands/uncle-dev-next-task.md:71` — "all tasks complete" routes to
`/uncle-dev-review` (then ship), not directly to ship.

**New test: `scripts/tests/detect-mode.test.sh`**

*Note:* `scripts/tests/mode-branch-split.test.sh` already exists and covers the
install-time skill-branch split (a separate feature). The SDD-mode detection
test uses the distinct filename `detect-mode.test.sh` to avoid collision.

Precedence rule (wording must be identical in LLD and EARS): explicit
`preferences.sdd_mode` from config wins over directory detection; directory
detection applies only when config is absent or empty.

Test cases for `scripts/tests/detect-mode.test.sh`:
- Invoke `uncle-dev-detect-mode.sh` in a temp dir containing only
  `docs/llds/`; assert output is `lid-ears`.
- Invoke in a temp dir containing only `openspec/`; assert output is
  `openspec`.
- Invoke with config value `openspec` but both `openspec/` and `docs/hld/`
  trees present; assert output is `openspec` (config wins over directory
  detection; directory detection is skipped entirely when config is set).
- Invoke in an empty dir with no config; assert output is `lid-ears`
  (default when neither config nor filesystem signals are present).
Added to the explicit TESTS array in `scripts/tests/run-all.sh`.

**Repo's stale openspec change cleaned (Finding G)**

`openspec/changes/companion-modes-foundation/` — renamed to comply with
`NNN-slug` format, missing artifacts (`execution.md`, `handoff.md`) added or
the change archived with a status note; 29 unchecked tasks made visible to
next-task.

**Plugin fork regenerated** via `scripts/sync-plugin.sh` (Work Unit 03).

---

### Work Unit 07 — Create or reroute phantom commands; fix agent identities

**Two new workflow-critical command files created**

- `commands/uncle-dev-pre-mortem.md` — thin wrapper loading the
  `uncle-dev-pre-mortem` skill, following the pattern of
  `commands/uncle-dev-changelog.md`. Mandatory Step 4.5 in
  `commands/uncle-dev-spec.md:162` now resolves.
- `commands/uncle-dev-feature-map.md` — thin wrapper loading the
  `uncle-dev-feature-map` skill. First-step reference in
  `commands/uncle-dev-brownfield.md:2,25,201` and `CLAUDE.md:11` now resolve.

Both files added to `.claude-plugin/marketplace.json`; command count in
CLAUDE.md, README, and setup-project.sh injected list updated (coordinates
with Work Unit 10 generated inventory).

**Three phantom slash commands rerouted to skill wording**

- `commands/uncle-dev-acknowledge.md:35` → "use the
  `uncle-dev-documentation-and-adrs` skill"
- `commands/uncle-dev-custom-me.md:65` → "consult the
  `uncle-dev-using-agent-skills` skill"
- `skills/uncle-dev-initiative-map/README.md:113–114` → skill wording for
  both references

**`plan-reviewer` phantom resolved**

`skills/uncle-dev-code-review-and-quality/SKILL.md:243,248,268,269` and
`agents/uncle-dev-ag-review-synthesizer.md:14,15,102,105` — references
repointed to `uncle-dev-ag-code-reviewer` with an architecture-lens prompt,
consistent with the fallback the code already uses at lines 286,292
(`general-purpose`). No new agent file created.

**Agent identity convention: keep short `name:` fields (locked decision)**

The six agents with mismatched names keep their short `name:` values
(`code-reviewer`, `graph-analyst`, `repo-research-analyst`,
`review-synthesizer`, `security-auditor`, `test-engineer`). The skill spawn
strings are fixed instead:
- `skills/uncle-dev-code-review-and-quality/SKILL.md:280,306` —
  `subagent_type="uncle-dev-ag-code-reviewer"` → `subagent_type="code-reviewer"`;
  `subagent_type="uncle-dev-ag-review-synthesizer"` → `subagent_type="review-synthesizer"`.
- Contradictory "paste the file into general-purpose" example invocations
  labeled as the fallback for non-plugin installs.

**Persona agents hardened**

`agents/uncle-lead.md` and `agents/uncle-po.md` — phantom references removed:
`~/coding-projects/project-map.yaml`, `.ai/shared-memory/`, "Dev Manager"
agent, GCP deployment lens. Grounded in repo conventions (`.uncle-dev/`,
`.devlocal/`, `openspec/`). `uncle-po.md:32–33` duplicate step numbering
fixed.

`agents/uncle-dev-ag-graph-analyst.md:25` — explicit first step added: "if
`graphify-out/graph.json` does not exist, return `GRAPH UNAVAILABLE` and
exit the agent."

**Copilot agent subset aligned**

`scripts/install-plugin.sh:262–277` — `uncle-senior` added to the copied set
alongside other persona agents.

**`scripts/check-manifest.sh` verification**

`grep -rn 'plan-reviewer' agents/ skills/ commands/` added as a manifest
check (must return empty after remediation).

---

### Work Unit 09 — Installer safety and drift

**Repo-root guard: `scripts/uninstall-hermes.sh`**

Before the `rm -rf "${PLUGIN_DEST}"` call, add the guard pattern used in
`install-hermes.sh` (function/pattern near line 200: `[[ "$WORKSPACE" != "$REPO_ROOT" ]] || fail "Refusing to install into the source repository itself."`):
refuse when the resolved destination is inside the plugin repo checkout or
equals the tracked `plugins/uncle-dev/`. Error message names the conflict.
The `y/N` confirm now only runs when the guard passes.

**`install-antigravity.sh` brought to house pattern**

Sources `scripts/lib/install-common.sh` (already used by other installers);
replaces bare `cp -r` with guarded copy helpers; adds `--force` semantics
consistent with the other installers; success message changed to "skills
installed; commands are not supported on this target"; accepts a `--dest`
override for the hardcoded `~/.gemini/antigravity/skills` path.

**`install-hermes.sh` drift fixed**

Line 8 `PLUGIN_VERSION="1.4.1"` replaced with a jq derivation from
`.claude-plugin/plugin.json` (same pattern as `install-claude.sh:27`):
`PLUGIN_VERSION="$(jq -r .version .claude-plugin/plugin.json)"`.
Duplicated `copy_file`/`copy_dir_contents` functions (lines 47–75) deleted;
`source "${SCRIPT_DIR}/lib/install-common.sh"` added.

**`scripts/install.sh` dispatcher completed**

`hermes` and `antigravity` cases added. Adapter targets (`copilot`, `cline`,
`kiro`, `pi`, `cursor`, `gemini`, `windsurf`, `getting-started`) routed
through `install-plugin.sh`. The `verify` mode extended to cover hermes and
antigravity, or explicitly prints which targets verify does not cover.

**New installer tests: `scripts/tests/`**

- `uninstall-hermes.sh` refuses when destination resolves inside a git
  checkout of the plugin repo (sandbox test in fake HOME).
- Antigravity install/overwrite-refusal case without `--force`.

---

### Work Unit 10 — Documentation drift, dead references, hygiene

**Generated inventories (Finding A)**

`scripts/check-manifest.sh` extended (or `scripts/gen-inventory.sh` created)
to emit the canonical command list and phase table from `commands/` + skill
frontmatter into marked blocks in CLAUDE.md and README:

```
<!-- BEGIN GENERATED: commands -->
…
<!-- END GENERATED: commands -->
```

`check-manifest.sh` fails when the blocks are stale ("run
`scripts/gen-inventory.sh` to refresh").

CLAUDE.md's two phase lists collapsed into one. README line 323 count
(`26`) updated to the generated value. `setup-project.sh:337–345` injected
list replaced with a reference to the generated block or a call to the
generator. AGENTS.md command table rewritten from the same generator or
replaced with a link to CLAUDE.md.

**Dead references fixed (Finding B — 14 references across 8 files)**

- `skills/uncle-dev-security-and-hardening/SKILL.md:305` →
  `./security-checklist.md`
- `skills/uncle-dev-performance-optimization/SKILL.md:304` →
  `./performance-checklist.md`
- `skills/uncle-dev-frontend-ui-engineering/SKILL.md:280` →
  `./accessibility-checklist.md`
- `skills/uncle-dev-test-driven-development/SKILL.md:364` →
  `./testing-patterns.md`
- `skills/uncle-dev-code-review-and-quality/SKILL.md:436,437` →
  `skills/uncle-dev-security-and-hardening/security-checklist.md` and
  `skills/uncle-dev-performance-optimization/performance-checklist.md`
- `skills/uncle-dev-shipping-and-launch/SKILL.md:294,295,296` → explicit
  cross-skill absolute paths
- `skills/uncle-dev-custom-me/SKILL.md:26,115` →
  `docs/originals/skill-anatomy.md`
- `skills/uncle-dev-setup/SKILL.md:15` → `docs/originals/cursor-setup.md`,
  `docs/originals/windsurf-setup.md`, `docs/originals/copilot-setup.md`
- `commands/uncle-dev-custom-me.md:151` → `docs/originals/skill-anatomy.md`
- Root `CLAUDE.md` Boundaries skill-anatomy reference → `docs/originals/skill-anatomy.md`

Link-checker loop added to `check-manifest.sh`: every relative `.md` path
mentioned in `skills/` and `commands/` must resolve on disk.

**Root-level rule violations resolved (Finding C)**

CLAUDE.md chosen as the single root instruction file (locked decision).
AGENTS.md's still-relevant content folded into CLAUDE.md; AGENTS.md deleted
or demoted to a stub with a single pointer. `setup-project.sh:289` — the
unconditional `touch CLAUDE.md` changed: skip creating CLAUDE.md when
AGENTS.md exists; warn instead.

For graphify: the CLAUDE.md instruction made conditional ("if
`graphify-out/graph.json` exists…") to match what the skills already do,
eliminating the failed check on every spawned agent.

**Orphans cleaned (Finding D)**

- `skills/uncle-dev-initiative-map/README.md` — wired into the skill's
  SKILL.md as a reference, or deleted with content merged into SKILL.md.
- `skills/uncle-dev-spec-annotations/requirements.txt` — wired into
  install/CI docs or deleted.
- `.claude/settings.json` — replaced with valid `{}` or deleted.
- `.uncle-dev/research/` — migrated to `.devlocal/research/` with a
  migration note, or legacy dir documented.
- `tmp/destructive-commands.md` — moved to `hooks/destructive-commands.md`
  (or `docs/hooks-reference.md`); `hooks/destructive-command-guard.sh:16`
  reference updated.
- `.uncle-dev/session-mode` — `hooks/session-start.sh` clears or evaluates a
  TTL on the file; or file given a documented session-scope contract.
- Scratch-stamp convention unified: pick `.devlocal/` as canonical;
  `wrap-nudge.sh`'s `.claude/.wrap-nudged` stamp migrated to
  `.devlocal/wrap-nudged`.
- `docs/README.md` created (one paragraph) declaring which of
  `docs/originals/`, `docs/improved/`, `docs/v2/` is canonical and the
  status of the others.

**Hooks scoped to uncle-dev projects (Finding E)**

`hook_require_project` from Work Unit 01's `hooks/lib/hook-contract.sh`
called at the top of: `hooks/session-start.sh` (before the `mkdir -p` call at
line 47), `hooks/wrap-nudge.sh`, `hooks/knowledge-capture-nudge.sh`.
Decision for `destructive-command-guard.sh`: remains global by design
(documented in the script header — uncle-dev policy applies regardless of
project type; config toggle from Work Unit 02 provides the opt-out).

**Skill conventions reconciled (Finding F)**

CLAUDE.md amended to state trigger conditions live in frontmatter `description`
(matching 40/46 reality); "When to Use" removed from the required section list.
Five non-conforming descriptions fixed. `skills/uncle-dev-code-context/SKILL.md`
(27-line tombstone) deleted; `marketplace.json` and installers updated.
`skills/uncle-dev-pre-mortem/SKILL.md` fleshed out to standard (especially
since Work Unit 07 promotes it to a command). Template exemption to the 100-line
rule documented in `docs/originals/skill-anatomy.md`. `scripts/nori-lint.config.json`
curated for the agreed rule set; `--enforce` enabled in CI.

---

## Constraints

- All hooks and scripts are bash-only; every changed file must pass
  `bash -n`. No Python or Node in hook-contract.sh or hook scripts.
- **macOS system bash 3.2 compatibility:** All hooks under `hooks/` and all
  scripts under `scripts/` must run without error under `/bin/bash` on macOS,
  which ships bash 3.2. This prohibits: associative arrays (`declare -A`),
  `mapfile`/`readarray`, lowercase expansion (`${var,,}`), and any other
  bash 4+ feature. Use indexed arrays or repeated `grep`/`awk` instead.
- **`set -euo pipefail` + grep guard:** Hooks that use `set -euo pipefail`
  must not let a non-matching `grep` silently kill the script mid-pipeline.
  Any `grep` whose "no match" outcome is a valid (non-error) case must either
  redirect to `/dev/null` (`grep -q … >/dev/null`) or be guarded with
  `|| true`. Example: `grep -qF "$pattern" "$file" || true` when absence of
  the pattern is not an error. This prevents spurious hook exits that would
  block or drop tool calls unnecessarily.
- `jq` and `python3` may be absent on end-user machines. Every script that
  uses jq opens with `command -v jq >/dev/null || exit 0` (never silent
  failure). python3/PyYAML absence in `uncle-dev-config.sh` must print a
  single-line warning to stderr before returning defaults; never silent
  evaporation.
- Claude Code hook contract (canonical, from current docs):
  - stdin delivers `{"tool_name":…,"tool_input":{…}}` JSON — no
    `CLAUDE_TOOL_*` env vars.
  - Block = `exit 2` + message on **stderr**.
  - PreToolUse/PostToolUse advisory = `{"hookSpecificOutput":{"additionalContext":"…"}}`
    on stdout at exit 0. `exit 1` is a non-blocking error; stdout on `exit 1`
    is not shown to the model.
  - **Stop/SubagentStop advisory** = `{"priority":"…","message":"…"}` on stdout
    at exit 0 (different shape from PreToolUse/PostToolUse; the legacy
    `{"priority","message"}` schema IS correct for Stop hooks). These events
    receive a different stdin payload (no `tool_name`/`tool_input`; instead
    carries `transcript_path`, `cwd`, and usage metrics). `hook_advise` must
    NOT be called from Stop-event hooks; use `hook_advise_stop` instead.
  - SessionStart and UserPromptSubmit: raw stdout IS injected as context.
- Config boundary: only `scripts/uncle-dev-config.sh` may open
  `.agents/uncle-dev-setup.yaml`. All other scripts, commands, hooks must go
  through the helper. The widened audit guard
  (`grep -rn 'setup\.yaml' scripts/ hooks/ commands/ | grep -v uncle-dev-config.sh`)
  must return empty (template, schema, and docs files explicitly excluded).
- Plugin namespace: installed skills resolve as `uncle-dev:<name>` (plugin
  `name` field in `.claude-plugin/plugin.json`). The `agent-skills:` namespace
  does not exist in an installed plugin.
- Plugin cache layout:
  `~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/<version>/`
  (`<marketplace-id>/<plugin-name>/<version>`). The doubled-segment path
  `uncle-dev-agent-skills/uncle-dev-agent-skills` does not exist.
- Existing 9 test suites + the manifest drift guard must remain green
  throughout. New suites: hook-contract smoke test, loader validation test,
  detect-mode test, plan→next-task round-trip test, installer refusal tests.
- **Single-command definition of done:** `bash scripts/tests/run-all.sh` must
  pass green including all new suites and the manifest drift check. This is the
  authoritative acceptance gate; individual unit completion is not sufficient
  until the full suite passes.
- Distributable plugin: no personal paths (no `~/others/ai-agents/…`),
  no hardcoded version strings in commands or hooks (always derive from
  `plugin.json` or use `sort -V | tail -1` for cache resolution), no
  machine-specific paths.

---

## Key Decisions

**1. Honor the six hooks.* toggles (Audit 02, locked)**
Each of the six hook scripts that previously fired unconditionally adds a
toggle check at the top: `[[ "$(uncle-dev-config.sh hooks.<name>)" == "false" ]] && exit 0`.
This mirrors the existing `wrap-nudge.sh:26` pattern exactly, extending the
same opt-out mechanism the template already documents. Rationale: the template
comment "Set to false to disable a specific guard" is a user-facing promise;
delivering it is a correctness fix, not a feature. The alternative (delete
the toggles) would be a breaking config schema change.

**2. Spec universe separation (Audit 06, locked)**
EARS (`R-x.y`) IDs remain a manually-reviewed track; `@spec` annotations
(`SEG-AREA-NNN`) remain the scanner-enforced track. The scanner is not
extended to parse `docs/ears/` or `R-\d+\.\d+` IDs. Rationale: extending
the scanner touches `skills/uncle-dev-spec-annotations/scanner/`, adds a
new ID grammar, and changes what `spec-coherence-guard.sh` blocks — scope
that is disproportionate to the immediate fix. The honest label (MANUAL CHECK)
in ship.md is the correct short-term fix. The bridge option remains open for a
future dedicated work unit.

**3. Generate, not delete, the plugin fork (Audit 03, locked)**
`scripts/sync-plugin.sh` is the single generation step; `check-manifest.sh`
enforces freshness via sha256 content hashes. Rationale: the fork exists
because Codex/Hermes installs consume `plugins/uncle-dev/` directly; deleting
it would require changing the install path for those targets, which is a
larger change with its own risk. Generation keeps one source of truth while
preserving the install contract.

**4. Keep short agent `name:` fields, fix skill spawn strings (Audit 07, locked)**
`name:` fields stay as `code-reviewer`, `review-synthesizer`, etc. (the values
the plugin registry exposes). The skill `subagent_type=` strings in
`uncle-dev-code-review-and-quality/SKILL.md:280,306` are corrected to match.
Rationale: renaming `name:` fields in `agents/*.md` would change the installed
plugin's agent identity, breaking any project that references them by name
today. Fixing the skill strings is a pure correctness change.

**Additional embedded recommendations adopted:**

- **Story grammar unified toward the parser**: plan templates updated to h3 +
  numeric dotted IDs (`### Story 1.1:`); parser grammar not changed.
- **`handoff.md` removed from spec command**: creation line and required-
  artifact enumeration updated; real handoffs remain in `.devlocal/handoffs/`.
- **`plan-reviewer` repointed, not created**: `review-synthesizer` and the
  quality skill repoint to existing agents; no new agent added to marketplace.
- **CLAUDE.md chosen as single root file**: AGENTS.md folded in and removed at
  project root; `setup-project.sh` fixed to not create CLAUDE.md when
  AGENTS.md is present.

---

## Out of Scope

The following items are explicitly excluded from this remediation initiative:

- **Renaming `skills/uncle-dev-dev-code-simplification/`** to the shorter
  form — touches `marketplace.json`, all install scripts, and the CLAUDE.md
  inventory; addressed separately if at all (Work Unit 04 fixes only the
  typo in the command's loader call).
- **Scanner extension for `R-x.y` IDs** — extending the `@spec` scanner
  (`skills/uncle-dev-spec-annotations/scanner/`) to accept EARS IDs and scan
  `docs/ears/` is the "bridge" option from Audit 06; explicitly deferred.
- **Creating a `plan-reviewer` agent** — the audit recommendation (and the
  locked decision) is to repoint existing references; no new agent file is in
  scope.
- **Modifying healthy components**: `marketplace.json` ↔ disk bidirectional
  match, `scripts/uncle-dev-config.sh` scalar/`--list`/`--validate` modes,
  the 9 currently-green test suites, `hooks/simplify-ignore-test.sh`
  (21/21 passing), and the 46/46 valid SKILL.md frontmatter files are not
  touched beyond what the audit fixes require.
- **Behavior changes beyond audit findings**: no new skills, no new
  architectural patterns, no performance work, no nori-lint rule authoring
  beyond curating the existing `scripts/nori-lint.config.json` for the
  agreed convention set.
