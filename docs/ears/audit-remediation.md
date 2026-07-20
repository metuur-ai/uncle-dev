# EARS Behavioral Requirements — Audit Remediation

Source: `docs/audit/01-10-*.md` (audit 2026-07-02).
Locked decisions: Audit 03 → Strategy 1 (Generate); Audit 06 → Separate universes; Audit 02 → Honor six hooks.* toggles.

---

## Unit 1: Hook Contract

**Why:** Seven of eleven wired hooks are inert or non-blocking because the repo mixes env-var and JSON-stdin input conventions and the wrong block exit code, meaning spec-coherence gating and destructive-command blocking currently do nothing at runtime.

| ID | EARS statement |
| --- | --- |
| R-1.1 | THE SYSTEM SHALL provide `hooks/lib/hook-contract.sh` exporting `HOOK_TOOL_NAME`, `HOOK_FILE_PATH`, `HOOK_COMMAND`, `HOOK_CONTENT`, and `HOOK_NEW_STRING` by reading the JSON object from stdin once via `jq`. |
| R-1.2 | WHEN a PreToolUse hook decides to block a tool call, THE SYSTEM SHALL exit with code 2 and write the human-readable reason to stderr. |
| R-1.3 | THE SYSTEM SHALL contain zero occurrences of `CLAUDE_TOOL_INPUT` or `CLAUDE_TOOL_NAME` in any file under `hooks/*.sh`. |
| R-1.4 | WHEN `hooks/destructive-command-guard.sh` receives a command string that contains a chain operator (`;`, `&&`, `||`, `|`, `$(`, or backtick), THE SYSTEM SHALL evaluate each segment of the chain independently against the allowlist before allowing the command to proceed. |
| R-1.5 | WHEN `hooks/destructive-command-guard.sh` receives a command that matches the allowlist, THE SYSTEM SHALL require the match to be anchored to the full token (e.g. `ls` and `ls ` but not `lsblk` or `lsof`). |
| R-1.6 | IF `jq` is not present on `PATH` when any hook script is invoked, THE SYSTEM SHALL exit 0 without error rather than failing the hook. |
| R-1.7 | THE SYSTEM SHALL quote `${CLAUDE_PLUGIN_ROOT}` in every command string inside `hooks/hooks.json` so that paths containing spaces do not break hook invocation. |
| R-1.8 | WHEN `hooks/gate-notify.sh` evaluates whether a gate phrase has been spoken, THE SYSTEM SHALL inspect only the most recent assistant message rather than all assistant messages in the last 200 transcript events. |
| R-1.9 | THE SYSTEM SHALL NOT define the variable `CONFIG_FILE` pointing at `.agents/uncle-dev-setup.yaml` in `hooks/wrap-nudge.sh`. |
| R-1.10 | THE SYSTEM SHALL provide `scripts/tests/hook-contract.test.sh` that, for each wired **PreToolUse and PostToolUse** hook, pipes a synthetic tool-call JSON on stdin and asserts: (a) blocking cases exit 2 with non-empty stderr, (b) allow cases exit 0, (c) no hook script reads `CLAUDE_TOOL_*` environment variables, and (d) advisory output uses the `{"hookSpecificOutput":{"additionalContext":"…"}}` shape (not `{"priority","message"}`). Stop-event hooks are tested separately: (e) `hooks/wrap-nudge.sh` emits `{"priority":"IMPORTANT","message":"…"}` on stdout at exit 0 when thresholds are crossed, and (f) `hooks/gate-notify.sh` exits 0 without stdout JSON output when no gate phrase is matched. |
| R-1.11 | WHEN `scripts/tests/hook-contract.test.sh` is run, THE SYSTEM SHALL execute it as the tenth entry in the explicit TESTS array inside `scripts/tests/run-all.sh`. |
| R-1.12 | THE SYSTEM SHALL NOT use bash 4+ features (`declare -A`, `mapfile`, `readarray`, `${var,,}`) in any file under `hooks/` or `scripts/`; all hooks and scripts SHALL run without error under `/bin/bash` version 3.2 (macOS system bash). |
| R-1.13 | WHEN any hook script uses `set -euo pipefail` and calls `grep` in a context where no match is a valid (non-error) outcome, THE SYSTEM SHALL guard the `grep` call with `>/dev/null` or `|| true` so that a non-matching result does not cause the hook to exit and block or drop tool calls. |
| R-1.14 | WHEN `hook_require_project` is called from any uncle-dev hook and `.agents/uncle-dev-setup.yaml` does not exist in the current working directory, THE SYSTEM SHALL exit 0 without producing any output (no stdout, no stderr, no file-system side effects) so that the hook is fully transparent in repositories that are not uncle-dev projects. |

---

## Unit 2: Setup and Project Config

**Why:** `setup-project.sh` never writes the user-chosen `sdd_mode` into the config (the sed pattern cannot match the two-line template form), reads the YAML directly in violation of the single-reader boundary, and six `hooks.*` toggles in the schema have no runtime effect. *Note: `scripts/uncle-dev-setup.schema.json` and `skills/uncle-dev-setup/uncle-dev-setup.template.yaml` already define all six `hooks.*` keys (`session_start`, `pre_commit`, `spec_coherence`, `openspec_guard`, `destructive_command_guard`, `knowledge_capture_nudge`) as booleans with defaults of `true`; `uncle-dev-config.sh` already resolves them. No schema or template change is required — only the six hook scripts need the toggle-check added.*

| ID | EARS statement |
| --- | --- |
| R-2.1 | WHEN `scripts/setup-project.sh` completes a fresh setup with the `openspec` answer, THE SYSTEM SHALL write a `preferences.sdd_mode` value of `"openspec"` to the project config such that `bash scripts/uncle-dev-config.sh preferences.sdd_mode` returns `openspec`. |
| R-2.2 | WHEN `scripts/setup-project.sh` is re-run on an existing `lid-ears` project, THE SYSTEM SHALL NOT create `openspec/` directories or inject the openspec CLAUDE.md block. |
| R-2.3 | THE SYSTEM SHALL read all project-config values in `scripts/setup-project.sh` exclusively via `scripts/uncle-dev-config.sh`, with no direct `grep`, `awk`, `yq`, or `cat` calls against `.agents/uncle-dev-setup.yaml`. |
| R-2.4 | WHEN the audit boundary guard runs (`grep -rn 'setup\.yaml' scripts/ hooks/ commands/ | grep -v uncle-dev-config.sh | grep -v '^\s*#'`), THE SYSTEM SHALL return no matches except template, schema, and documentation files. |
| R-2.5 | IF `hooks.pre_commit` resolves to `"false"` via `uncle-dev-config.sh`, THE SYSTEM SHALL exit 0 from `pre-commit-guard.sh` without evaluating the commit. |
| R-2.6 | IF `hooks.spec_coherence` resolves to `"false"` via `uncle-dev-config.sh`, THE SYSTEM SHALL exit 0 from `spec-coherence-guard.sh` without evaluating the file write. |
| R-2.7 | IF `hooks.openspec_guard` resolves to `"false"` via `uncle-dev-config.sh`, THE SYSTEM SHALL exit 0 from `openspec-guard.sh` without evaluating the tool call. |
| R-2.8 | IF `hooks.destructive_command_guard` resolves to `"false"` via `uncle-dev-config.sh`, THE SYSTEM SHALL exit 0 from `destructive-command-guard.sh` without evaluating the command. |
| R-2.9 | IF `hooks.knowledge_capture_nudge` resolves to `"false"` via `uncle-dev-config.sh`, THE SYSTEM SHALL exit 0 from `knowledge-capture-nudge.sh` without nudging. |
| R-2.10 | IF `hooks.session_start` resolves to `"false"` via `uncle-dev-config.sh`, THE SYSTEM SHALL exit 0 from `session-start.sh` without injecting context. |
| R-2.11 | WHEN `scripts/uncle-dev-config.sh` is invoked on a machine where `python3` is absent or `PyYAML` is not importable, THE SYSTEM SHALL print a one-line warning to stderr and return configured defaults rather than silently evaporating all configuration. |
| R-2.12 | THE SYSTEM SHALL invoke `cd "$PROJECT_DIR"` or pass the project path to `uncle-dev-config.sh` before calling it from `hooks/wrap-nudge.sh` so that the correct config file is read regardless of the shell's working directory. |

---

## Unit 3: Plugin Fork Drift

**Why:** `plugins/uncle-dev/commands/` is a stale content fork of `commands/` (7 files diverged), and the CI drift guard compares filenames only — so content drift passes green indefinitely and Codex/Hermes users receive outdated workflow commands.

| ID | EARS statement |
| --- | --- |
| R-3.1 | THE SYSTEM SHALL provide `scripts/sync-plugin.sh` that regenerates `plugins/uncle-dev/commands/` from canonical `commands/` as an exact copy. |
| R-3.2 | WHEN `scripts/sync-plugin.sh` is run, THE SYSTEM SHALL produce zero differences between `commands/` and `plugins/uncle-dev/commands/` as reported by `diff -rq`. |
| R-3.3 | WHEN `scripts/check-manifest.sh` runs and the SHA-256 content hash of any file in `commands/*.md` differs from its counterpart in `plugins/uncle-dev/commands/`, THE SYSTEM SHALL fail, name the diverging file, and suggest running `scripts/sync-plugin.sh`. The hash SHALL be computed via a portable resolver: `sha256sum` if available, else `shasum -a 256`, else fail with a clear error message naming the missing tool. |
| R-3.4 | WHEN `scripts/tests/run-all.sh` runs, THE SYSTEM SHALL execute the content-hash drift check as part of the suite. |
| R-3.5 | WHEN the canonical `commands/` directory is edited without a subsequent sync, THE SYSTEM SHALL turn `bash scripts/check-manifest.sh` red with an actionable message identifying the unsynchronized file. |

---

## Unit 4: Skill Loader

**Why:** The skill loader is fail-open with no validation, emits the wrong plugin namespace (`agent-skills:` instead of `uncle-dev:`), and `commands/uncle-dev-code-simplify.md` silently loads a nonexistent skill name, so the command runs without its skill and nobody notices.

| ID | EARS statement |
| --- | --- |
| R-4.1 | WHEN `scripts/uncle-dev-load-skill.sh` is invoked with a name that has no `skills/<name>/` directory in the plugin root, THE SYSTEM SHALL print an error to stderr and exit non-zero. |
| R-4.2 | WHEN `scripts/uncle-dev-load-skill.sh` is invoked with a valid skill name, THE SYSTEM SHALL emit `SKILL: uncle-dev:<name>` (not `agent-skills:<name>`). |
| R-4.3 | THE SYSTEM SHALL contain zero occurrences of `agent-skills:` as a namespace prefix in any file under `commands/`, `skills/`, or `scripts/`. |
| R-4.4 | THE SYSTEM SHALL pass `uncle-dev-dev-code-simplification` (not `uncle-dev-code-simplification`) as the skill name argument in `commands/uncle-dev-code-simplify.md`. |
| R-4.5 | WHEN `scripts/tests/run-all.sh` runs, THE SYSTEM SHALL execute a loader test that: (a) asserts exit 0 and `SKILL: uncle-dev:<name>` output for a known-good skill name, and (b) asserts non-zero exit and stderr output for a bogus skill name. |
| R-4.6 | WHEN a lint pass iterates every `bash "$_loader" <name>` argument in `commands/`, THE SYSTEM SHALL report any argument that has no matching `skills/<name>/` directory. |
| R-4.7 | WHEN multiple versioned copies of the plugin exist in `~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/`, THE SYSTEM SHALL resolve the loader path to the newest version using `sort -V | tail -1` rather than unordered `find | head -1`. |
| R-4.8 | THE SYSTEM SHALL inject the Skill-loading directive block into the CLAUDE.md snippet that `scripts/setup-project.sh` writes so that `SKILL:` lines have meaning in projects configured by the installer. |

---

## Unit 5: Mode Detection

**Why:** The ~20-line SDD-mode detection block is duplicated in eight command files with divergent behavior, a detection blindspot for the `docs/llds`/`docs/specs` tree, and a prose default that contradicts the code default — so a model that skips the bash step lands in the wrong mode.

| ID | EARS statement |
| --- | --- |
| R-5.1 | THE SYSTEM SHALL provide `scripts/uncle-dev-detect-mode.sh` as the single authoritative implementation of SDD-mode detection, printing exactly `lid-ears` or `openspec` to stdout. |
| R-5.2 | WHEN `scripts/uncle-dev-detect-mode.sh` runs in a directory that contains `docs/llds/` or `docs/specs/` but no `openspec/` directory, THE SYSTEM SHALL print `lid-ears`. |
| R-5.3 | WHEN `scripts/uncle-dev-detect-mode.sh` runs and neither config nor filesystem signals are present, THE SYSTEM SHALL default to `lid-ears`. |
| R-5.4 | THE SYSTEM SHALL contain zero inline SDD-mode detection bash blocks in `commands/uncle-dev-spec.md`, `uncle-dev-plan.md`, `uncle-dev-build.md`, `uncle-dev-next-task.md`, `uncle-dev-review.md`, `uncle-dev-ship.md`, `uncle-dev-acknowledge.md`, and `uncle-dev-openspec-sync.md`; each SHALL call `uncle-dev-detect-mode.sh` instead. |
| R-5.5 | THE SYSTEM SHALL contain zero occurrences of "openspec or missing (default)" or equivalent phrasing in any `commands/uncle-dev-*.md` Path B header. |
| R-5.6 | WHEN `skills/uncle-dev-next-task/SKILL.md` Phase 0 resolves `sdd_mode` to an empty string, THE SYSTEM SHALL treat it as `lid-ears`. |
| R-5.7 | WHEN `commands/uncle-dev-test.md` runs in lid-ears mode, THE SYSTEM SHALL map test output to requirement IDs in `docs/ears/<slug>.md`; when run in openspec mode, THE SYSTEM SHALL map to the active change's acceptance criteria. |
| R-5.8 | WHEN `commands/uncle-dev-wrap.md` produces a handoff document, THE SYSTEM SHALL record the resolved SDD mode and link the mode's active artifacts (`docs/tasks/` for lid-ears; `openspec/changes/<id>/` for openspec). |
| R-5.9 | WHEN `commands/uncle-dev-next-task.md` determines that all lid-ears tasks are complete, THE SYSTEM SHALL route to `/uncle-dev-review` rather than directly to `/uncle-dev-ship`. |
| R-5.10 | WHEN `scripts/tests/run-all.sh` runs, THE SYSTEM SHALL execute `scripts/tests/detect-mode.test.sh` (distinct from the existing `mode-branch-split.test.sh`, which covers install-time skill-branch splitting) that exercises both `lid-ears` and `openspec` resolution paths of `uncle-dev-detect-mode.sh`, including the `docs/llds/`-only case and the config-override-wins case. `detect-mode.test.sh` SHALL be added to the explicit TESTS array in `run-all.sh`, not discovered by glob. |
| R-5.11 | WHEN `scripts/uncle-dev-detect-mode.sh` reads a non-empty `preferences.sdd_mode` value from config, THE SYSTEM SHALL return that value immediately without inspecting the filesystem; directory detection (presence of `docs/ears/`, `openspec/`, etc.) SHALL be performed only when config is absent or empty. |

---

## Unit 6: Plan → Next-Task Handoff

**Why:** Plan output uses `## Story STORY-101` (h2, non-numeric IDs) while the next-task parser requires `### Story 1.1` (h3, dotted-numeric IDs), so plans are unparseable and the parallelism/mutex machinery silently degrades to document order; additionally, the two spec universes (EARS `R-x.y` and `@spec` `SEG-AREA-NNN`) claim to be the source of truth but never intersect.

| ID | EARS statement |
| --- | --- |
| R-6.1 | WHEN `skills/uncle-dev-planning-and-task-breakdown/SKILL.md` emits a story in its Step 4 template, THE SYSTEM SHALL use h3 headers with dotted-numeric IDs (`### Story 1.1: [Title]`) that satisfy the parser's `^[0-9]+(\.[0-9]+)*$` grammar. |
| R-6.2 | WHEN `skills/uncle-dev-planning-and-task-breakdown/SKILL.md` emits a story in its Step 4 template, THE SYSTEM SHALL include an explicit `**Annotations:** [files: …] [mutex: …] [depends: …]` line per story. |
| R-6.3 | WHEN a plan file produced by `/uncle-dev-plan` is consumed by `/uncle-dev-next-task` and that plan contains a Story with a `[mutex: Story-X.Y]` annotation, THE SYSTEM SHALL exclude the mutex story from the ready set when its dependent story is already in progress, and SHALL include it once the dependency clears — verified by the round-trip test defined in R-6.9. |
| R-6.4 | THE SYSTEM SHALL NOT create `openspec/changes/<id>/handoff.md` from `commands/uncle-dev-spec.md`; handoff artifacts SHALL be written only to `.devlocal/handoffs/` via `/uncle-dev-wrap`. |
| R-6.5 | WHEN `commands/uncle-dev-spec.md` or `hooks/openspec-guard.sh` validates a change ID, THE SYSTEM SHALL require the ID to match `^[0-9]{3}-` and reject IDs that do not conform. |
| R-6.6 | THE SYSTEM SHALL contain zero occurrences of a non-conforming change-ID example (such as `PF-001-foundations-cross-cutting`) in `skills/uncle-dev-next-task/SKILL.md`. |
| R-6.7 | WHERE EARS `R-x.y` IDs are used, THE SYSTEM SHALL treat coverage verification as a manual step; `commands/uncle-dev-ship.md` SHALL NOT imply a mechanical check for `R-x.y` test coverage that has no implementation. |
| R-6.8 | WHERE `@spec` annotations use `SEG-AREA-NNN` IDs, THE SYSTEM SHALL enforce coverage via the existing `scan-spec-coherence.py` scanner without extending the scanner to accept `R-x.y` IDs. |
| R-6.9 | WHEN `scripts/tests/run-all.sh` runs, THE SYSTEM SHALL execute `scripts/tests/plan-next-task-roundtrip.test.sh` that: (a) generates a plan file from the fixed template containing at least two stories with `[mutex:]` and `[depends:]` annotations, (b) runs the next-task parsing logic against that file, (c) asserts that both story IDs match the `^[0-9]+(\.[0-9]+)*$` grammar, and (d) asserts that the mutex story does NOT appear in the ready set when its dependency is unresolved. |

---

## Unit 7: Missing Commands and Agent Identities

**Why:** Five slash commands are referenced as mandatory workflow steps but have no command file, a `plan-reviewer` agent is referenced in four places but defined nowhere, and six of nine agent `name:` fields do not match the strings used by skills to spawn them — making the full review flow unable to resolve its subagents.

| ID | EARS statement |
| --- | --- |
| R-7.1 | THE SYSTEM SHALL provide `commands/uncle-dev-pre-mortem.md` as a thin wrapper that loads the `uncle-dev-pre-mortem` skill, enabling `/uncle-dev-pre-mortem` to be invoked as a mandatory lid-ears Step 4.5. |
| R-7.2 | THE SYSTEM SHALL provide `commands/uncle-dev-feature-map.md` as a thin wrapper that loads the `uncle-dev-feature-map` skill, enabling `/uncle-dev-feature-map` to be invoked before brownfield analysis. |
| R-7.3 | THE SYSTEM SHALL contain zero slash-command references to `/uncle-dev-documentation-and-adrs`, `/uncle-dev-using-agent-skills`, or `/uncle-dev-grill` in `commands/` or `skills/`; each SHALL be replaced with a prose reference to the corresponding skill. |
| R-7.4 | THE SYSTEM SHALL contain zero references to a `plan-reviewer` agent in `agents/`, `skills/`, or `commands/` unless a file `agents/uncle-dev-ag-plan-reviewer.md` exists and is registered in `.claude-plugin/`. |
| R-7.5 | WHEN a skill spawns a subagent via `subagent_type=`, THE SYSTEM SHALL use a name that matches the `name:` frontmatter field of an agent file registered in the plugin. |
| R-7.6 | WHEN `agents/uncle-dev-ag-graph-analyst.md` is invoked and `graphify-out/graph.json` does not exist, THE SYSTEM SHALL return `GRAPH UNAVAILABLE` immediately without attempting to read the graph report. |
| R-7.7 | THE SYSTEM SHALL NOT reference `~/coding-projects/project-map.yaml`, `.ai/shared-memory/`, or a "Dev Manager" agent in any file under `agents/`. |
| R-7.8 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL verify that the `commands` count declared in `.claude-plugin/marketplace.json` matches the actual number of `*.md` files in `commands/`; on mismatch it SHALL fail and print the expected versus actual counts. |

---

## Unit 8: Plugin Cache Paths

**Why:** Six places hardcode a nonexistent cache layout (`uncle-dev-agent-skills/uncle-dev-agent-skills/`), the setup install check uses a plugin key that can never match, and a personal filesystem path is embedded in a distributed plugin — so setup always demands reinstall even on healthy machines.

| ID | EARS statement |
| --- | --- |
| R-8.1 | THE SYSTEM SHALL contain zero occurrences of the path segment `uncle-dev-agent-skills/uncle-dev-agent-skills` in any file under `commands/`, `hooks/`, `skills/`, or `scripts/`. |
| R-8.2 | THE SYSTEM SHALL contain zero hardcoded version strings of the form `cache/.*/[0-9]+\.[0-9]+` in any file under `commands/` or `hooks/`. |
| R-8.3 | WHEN a command or hook must resolve the plugin root without `CLAUDE_PLUGIN_ROOT`, THE SYSTEM SHALL fall back to the newest versioned cache directory using `ls -1d ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/*/ | sort -V | tail -1` rather than `find … | head -1`. |
| R-8.4 | WHEN `commands/uncle-dev-setup.md` checks whether the plugin is installed, THE SYSTEM SHALL query for the key `uncle-dev@uncle-dev-agent-skills` (or any key matching `^uncle-dev@`) in `installed_plugins.json`, not `uncle-dev-agent-skills@uncle-dev-agent-skills`. |
| R-8.5 | THE SYSTEM SHALL contain zero occurrences of personal filesystem paths (such as `~/others/ai-agents/`) in any file under `commands/`. |
| R-8.6 | THE SYSTEM SHALL provide YAML frontmatter with a `description:` field in `commands/uncle-dev-setup.md`. |
| R-8.7 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL grep for `uncle-dev-agent-skills/uncle-dev-agent-skills` and for hardcoded version cache paths in `commands/` and `hooks/` and fail if either pattern is found. |

---

## Unit 9: Installer Safety

**Why:** `uninstall-hermes.sh` runs `rm -rf` on the plugin destination with only a y/N prompt and no repo-root guard — the one script that deletes is the only installer missing the guard that every installer has — making it possible to delete checked-in plugin source with a single confirmation.

| ID | EARS statement |
| --- | --- |
| R-9.1 | WHEN `scripts/uninstall-hermes.sh` is invoked and the resolved destination is inside the plugin's own git checkout or equals the tracked `plugins/uncle-dev/` directory, THE SYSTEM SHALL refuse with a clear error message and exit non-zero without deleting anything. |
| R-9.2 | WHEN `scripts/install-antigravity.sh` is invoked and the destination already contains plugin files, THE SYSTEM SHALL refuse to overwrite without a `--force` flag. |
| R-9.3 | WHEN `scripts/install-antigravity.sh` completes successfully, THE SYSTEM SHALL print a success message stating that skills were installed and that commands are not supported on this target. |
| R-9.4 | THE SYSTEM SHALL derive `PLUGIN_VERSION` in `scripts/install-hermes.sh` from `.claude-plugin/plugin.json` using the same `jq` expression as `scripts/install-claude.sh`, with no hardcoded version literal. |
| R-9.5 | THE SYSTEM SHALL NOT define `copy_file` or `copy_dir_contents` as functions inside `scripts/install-hermes.sh`; these SHALL be sourced from `scripts/lib/install-common.sh`. |
| R-9.6 | WHEN `scripts/install.sh` is invoked with the target `hermes` or `antigravity`, THE SYSTEM SHALL route to the corresponding installer rather than printing an unknown-target error. |
| R-9.7 | WHEN `scripts/tests/run-all.sh` runs, THE SYSTEM SHALL execute a test asserting that `scripts/uninstall-hermes.sh` refuses and exits non-zero when the destination resolves inside a git checkout of the plugin repo. |
| R-9.8 | WHEN `scripts/tests/run-all.sh` runs, THE SYSTEM SHALL execute a test asserting that `scripts/install-antigravity.sh` refuses to overwrite an existing installation without `--force`. |

---

## Unit 10: Doc Drift and Hygiene

**Why:** Five diverging copies of the component inventory, 14 dead file references, CLAUDE.md and AGENTS.md coexisting at the root (their own forbidden state), and hooks creating `.devlocal/` directories in every user project cause trust erosion and wasted agent cycles across every session.

| ID | EARS statement |
| --- | --- |
| R-10.1 | THE SYSTEM SHALL provide a generated inventory mechanism (via `scripts/check-manifest.sh` or `scripts/gen-inventory.sh`) that writes the canonical command list and skill phase table into marked blocks in `CLAUDE.md` and `README.md`; `check-manifest.sh` SHALL fail when those blocks are stale. |
| R-10.2 | THE SYSTEM SHALL contain zero occurrences of the dead reference paths `references/security-checklist.md`, `references/performance-checklist.md`, `references/accessibility-checklist.md`, `references/testing-patterns.md`, `docs/skill-anatomy.md`, `docs/cursor-setup.md`, `docs/windsurf-setup.md`, or `docs/copilot-setup.md` in any file under `skills/` or `commands/`. |
| R-10.3 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL verify that every relative `.md` path referenced in `skills/` and `commands/` resolves to an existing file, and fail naming any dead link. |
| R-10.4 | THE SYSTEM SHALL NOT have both `CLAUDE.md` and `AGENTS.md` present at the project root simultaneously. |
| R-10.5 | WHEN `scripts/setup-project.sh` detects that `AGENTS.md` already exists at the target root, THE SYSTEM SHALL NOT create `CLAUDE.md`; it SHALL emit a warning instead. |
| R-10.6 | WHEN a hook in `hooks/session-start.sh`, `hooks/wrap-nudge.sh`, or `hooks/knowledge-capture-nudge.sh` is invoked and `.agents/uncle-dev-setup.yaml` does not exist in the working directory, THE SYSTEM SHALL exit 0 silently (no stdout, no stderr output, no `.devlocal/` directory creation, no uncle-dev context injection) so that the hook is fully transparent in repositories that are not uncle-dev projects. |
| R-10.7 | IF `.uncle-dev/session-mode` exists when `hooks/session-start.sh` runs, THE SYSTEM SHALL clear or apply a TTL to that file so that session strictness is not permanently sticky across unrelated sessions. |
| R-10.8 | THE SYSTEM SHALL provide `docs/README.md` containing a paragraph declaring which of `docs/originals/`, `docs/improved/`, or `docs/v2/` is the canonical documentation tree and the status of the others. |
| R-10.9 | WHEN `scripts/lint-skills.sh --enforce` runs after the nori-lint rule set has been curated to match the agreed conventions, THE SYSTEM SHALL report zero violations for the enforced rules. |
| R-10.10 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL report a generated count of commands consistent with the actual number of files in `commands/` and reject any README or CLAUDE.md that states a different count in a generated block. |
