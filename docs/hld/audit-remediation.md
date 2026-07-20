# Audit Remediation — High-Level Design

## Overview

The uncle-dev Claude plugin (distributable; fixes affect every installer: Claude Code, Codex/Hermes, OpenCode, Copilot, antigravity) completed a full ecosystem audit in July 2026 exposing a gap between its documented guarantees and its runtime behavior. The static inventory is healthy, but the runtime enforcement layer is largely inert: 7 of 11 hooks never fire (wrong input convention or wrong exit code), the plan→next-task workflow handoff is format-incompatible so parallel-safe task scheduling silently degrades, the plugin fork for Codex/Hermes installs contains 7 stale command files that lack all mode-detection and skill-loader logic, the plugin cache paths hardcoded in 6 places point to a layout that has never existed, and setup-project.sh writes a config whose `sdd_mode` key is never actually set. This initiative applies all 10 audit fix plans in the recommended order to close every gap between what the system says it does and what it does at runtime.

## Stakeholders & Impact

**Plugin end-users (Claude Code installs):** Today the spec-coherence commit gate, AGENTS.md guard, and openspec guard are inert — violations are never caught. The `/uncle-dev-setup` install-check always reports a broken install even on a healthy machine. After remediation, guards fire on real tool calls, commits that violate spec-coherence are blocked, and setup correctly detects existing installs.

**Codex/Hermes/OpenCode/Copilot/antigravity installer users:** Hermes installs receive 7 stale command files missing Step-0 mode detection and the skill loader — commands run in the wrong mode or load nonexistent skills silently. The uninstaller for Hermes can delete the checked-in plugin source without warning. After remediation, all installs receive command parity with Claude Code, and the uninstaller gains a repo-root safety guard.

**Contributors to this repo:** Five diverging component inventories in CLAUDE.md, AGENTS.md, README.md, and setup-project.sh accumulate silently. The repo violates two of its own boundary rules (CLAUDE.md and AGENTS.md coexist at root; graphify instruction references a directory that does not exist). After remediation, inventories are generated from disk and drift turns CI red; boundary violations are resolved.

**Spawned subagents and orchestrators:** Every agent spawned in this repo burns a failed graphify check because the graph directory does not exist, and skill refs emitted as `agent-skills:<name>` do not resolve in installed plugins (correct namespace is `uncle-dev:<name>`). After remediation, agents see accurate graphify instructions and resolvable skill refs.

**CI/test suite:** `check-manifest.sh` currently detects only filename-level drift in the plugin fork — content drift passes green. After remediation, sha256 content-hash drift detection is added, dead-link checking runs, the broken cache-path string is guarded, and all 10 new test suites are wired into `scripts/tests/run-all.sh`.

## Goals

These are true when the initiative ships:

- All 11 wired hooks fire on real tool calls; blocking hooks exit 2 with a message on stderr; the spec-coherence guard, AGENTS.md guard, and openspec guard are active in practice.
- A `git commit` violating a pre-commit gate is actually blocked; a destructive command including chained forms (`x && rm -rf y`) is actually blocked.
- The six `hooks.*` config toggles (`hooks.pre_commit`, `hooks.spec_coherence`, `hooks.openspec_guard`, `hooks.destructive_command_guard`, `hooks.knowledge_capture_nudge`, `hooks.session_start`) honor their values — setting one to `false` disables that hook.
- `setup-project.sh` with an `openspec` answer produces a config whose `preferences.sdd_mode` reads back `openspec`; re-running on a lid-ears project does not create `openspec/` directories.
- `diff -rq commands/ plugins/uncle-dev/commands/` returns empty; editing a canonical command without syncing turns `check-manifest.sh` red with an actionable message.
- The skill loader emits `uncle-dev:<name>` (not `agent-skills:<name>`); loading a nonexistent skill name exits non-zero with an error instead of silently succeeding.
- `/uncle-dev-code-simplify` loads the correct skill (`uncle-dev-dev-code-simplification`).
- SDD-mode detection lives in one script (`scripts/uncle-dev-detect-mode.sh`); the 8-copy inline block is replaced by a single call; a brownfield repo with only `docs/llds`/`docs/specs` correctly resolves to `lid-ears`.
- A plan produced by `/uncle-dev-plan` is directly parseable by `/uncle-dev-next-task`; parallel-safe ready sets compute from story annotations instead of degrading to document order.
- Ship's EARS coverage requirement is either mechanically checkable or explicitly marked manual — no phantom guarantee.
- Missing workflow-critical commands (`/uncle-dev-pre-mortem`, `/uncle-dev-feature-map`) exist as command files; phantom references to five non-existent slash commands are removed or rerouted.
- Agent `subagent_type` spawn strings resolve to real plugin agent names; `plan-reviewer` references are rerouted to an existing agent.
- Plugin cache path resolution uses the canonical three-tier order (CLAUDE_PLUGIN_ROOT → repo-local → newest versioned cache via `sort -V`); the doubled `uncle-dev-agent-skills/uncle-dev-agent-skills` segment is gone; no hardcoded version strings remain in commands or hooks.
- `/uncle-dev-setup` correctly detects an existing healthy install; personal machine paths are removed from the distributed plugin.
- `uninstall-hermes.sh` refuses to delete `plugins/uncle-dev/` when run from inside the repo checkout.
- Component inventories in CLAUDE.md and README.md are generated from disk; `check-manifest.sh` fails when they are stale.
- No skill or command references a file path that does not exist; a dead link fails `check-manifest.sh`.
- Hooks scope themselves to uncle-dev projects (presence of `.agents/uncle-dev-setup.yaml`); opening an unrelated project does not create `.devlocal/` directories or inject uncle-dev context.

## Non-Goals

The following must NOT change as part of this initiative:

**Healthy components (audit README "do not touch"):**
- `.claude-plugin/marketplace.json` — the 46-skill / 9-agent declaration is a perfect bidirectional match; do not alter skill counts or frontmatter.
- `scripts/uncle-dev-config.sh` — scalar, `--list`, and `--validate` modes all work; env and session tiers work; extend only as needed by audit 02.
- All passing test suites — `bash scripts/tests/run-all.sh` must remain green after every commit; `hooks/simplify-ignore-test.sh` (21/21) must not regress.
- 46/46 SKILL.md valid YAML frontmatter — do not rename, restructure, or reformat SKILL.md files outside the specific edits called for by the 10 fix plans.
- Zero dead cross-skill `uncle-dev-*` token references — the cross-reference graph is clean; do not introduce new ones.
- Commands boundary on `.agents/uncle-dev-setup.yaml` — `commands/` has zero direct YAML reads; maintain this.
- openspec CLI graceful fallback — the existing availability check pattern must be preserved.

**Explicitly out of scope:**
- No scanner bridge for `R-x.y` IDs (EARS spec IDs): the "Separate" decision locks the two spec tracks (EARS reviewed manually; `SEG-AREA-NNN` scanner-enforced). The `@spec` scanner is not extended to load `docs/ears/*.md` or parse `R-\d+\.\d+` IDs.
- No skill-directory renames: the skill directory `uncle-dev-dev-code-simplification` is not renamed to `uncle-dev-code-simplification` (audit 04 explicitly flags this as separate work requiring marketplace.json, CLAUDE.md, and installer coordination).
- No new `plan-reviewer` agent: the phantom reference is rerouted to an existing agent; no new agent file is created.
- No redesign of the `uncle-dev-acknowledge` lid-ears gap beyond the minimum viable fix (surface proposed ADRs in next-task Path A, or document the asymmetry explicitly).
- No changes to the `.claude-plugin/marketplace.json` skill/agent count unless a command file is added (audit 07 creates two command files; counts must be updated accordingly).

## Success Criteria

The initiative is done when all of the following pass in CI and on a clean
install. **Single-command definition of done:** `bash scripts/tests/run-all.sh`
must pass green, including the new suites (hook-contract, loader validation,
detect-mode, plan→next-task round-trip, installer refusal tests) and the
manifest drift check. Individual unit claims of "complete" are not accepted
until the full suite passes.

```bash
# 01 — hooks
grep -rn 'CLAUDE_TOOL_INPUT' hooks/*.sh                   # no matches
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}' \
  | bash hooks/destructive-command-guard.sh; echo "exit=$?"   # exit=2
echo '{"tool_name":"Bash","tool_input":{"command":"ls; rm -rf /tmp/x"}}' \
  | bash hooks/destructive-command-guard.sh; echo "exit=$?"   # exit=2

# 02 — config
# (in a fresh temp dir after setup with openspec answer)
bash scripts/uncle-dev-config.sh preferences.sdd_mode     # "openspec"
grep -rn 'setup\.yaml' scripts/ hooks/ commands/ | grep -v uncle-dev-config.sh   # template/schema/docs only

# 03 — plugin fork
diff -rq commands/ plugins/uncle-dev/commands/            # empty

# 04 — skill loader
bash scripts/uncle-dev-load-skill.sh uncle-dev-dev-code-simplification; echo $?  # 0, "SKILL: uncle-dev:..."
bash scripts/uncle-dev-load-skill.sh not-a-skill; echo $?                         # non-zero
grep -rn 'agent-skills:' commands/ scripts/ skills/                               # no matches

# 05 — mode detection
grep -rhoE 'sdd_mode detection' commands/                 # no inline blocks (all call detect-mode.sh)

# 06 — plan/next-task round-trip
grep -n '## Story STORY-' skills/uncle-dev-planning-and-task-breakdown/SKILL.md  # no matches
grep -n 'Annotations:' skills/uncle-dev-planning-and-task-breakdown/SKILL.md     # present in template

# 07 — commands and agents
for c in pre-mortem feature-map; do [ -f "commands/uncle-dev-$c.md" ] && echo "OK $c"; done
grep -rn 'plan-reviewer' agents/ skills/ commands/        # no matches

# 08 — cache paths
grep -rn 'uncle-dev-agent-skills/uncle-dev-agent-skills' commands/ hooks/ skills/ scripts/  # no matches
grep -rn 'others/ai-agents' commands/                                                        # no matches

# 09 — installer safety
bash scripts/uninstall-hermes.sh --scope local . <<< "y"; echo $?  # refusal, non-destructive
ls plugins/uncle-dev/ | head -1                                     # still present

# 10 — doc hygiene
bash scripts/check-manifest.sh                            # green, incl. inventory + link checks

# full suite
bash scripts/tests/run-all.sh                             # all suites green
```
