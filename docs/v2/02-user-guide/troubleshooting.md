---
sidebar_position: 9
---

# Troubleshooting

Fixes for the problems you are most likely to hit. Each entry lists the symptom, the usual cause, and the fix. For quick conceptual answers, see the [FAQ](../01-getting-started/faq.md).

## The agent ignores the skills

**Symptom:** You installed Uncle Dev, but the agent still writes code without following any workflow.

**Cause:** The skill is not loaded into the agent's context. Installing the pack makes the files available; it does not force the agent to read them.

**Fix:**

1. Load the relevant `SKILL.md` into your rules file (`CLAUDE.md`, `.cursor/rules/`, `.windsurfrules`, or the equivalent for your tool).
2. Also load the `using-agent-skills` meta-skill so the agent can pick the right skill per task.
3. Confirm an `AGENTS.md` or `CLAUDE.md` exists at the project root with the Uncle Dev rules.

## Claude Code starts without the Skill Discovery flowchart

**Symptom:** A new Claude Code session does not load the skill-discovery flowchart, and hooks do not run.

**Cause:** The `SessionStart` hook is not wired into the project. The global install scripts copy plugin files but do not configure a project.

**Fix:** Run `/uncle-dev-setup` (or `scripts/setup-project.sh`) in the project. It injects the hooks into `.claude/settings.json`, scaffolds directories, writes the config, and adds the rules. Re-open the session afterward.

## Hooks do not fire

**Symptom:** Guards such as the pre-commit or spec-coherence checks never run.

**Cause:** The hook commands are missing from `.claude/settings.json`, or the hook is disabled in config.

**Fix:**

1. Run `/uncle-dev-setup` to merge the hook commands into `.claude/settings.json`.
2. Check the `hooks.*` toggles in `.agents/uncle-dev-setup.yaml` — only hooks toggled `true` are wired.
3. Confirm `.claude/settings.json` references the hook scripts (for example, `hooks/session-start.sh`, `hooks/pre-commit-guard.sh`).

## Commands or the plugin are missing after install

**Symptom:** `/uncle-dev-*` commands do not exist, or the plugin does not appear.

**Cause:** A global install (`install-claude.sh`, `install-codex.sh`, `install-opencode.sh`) copies files but does not configure the current project.

**Fix:**

1. Run `/uncle-dev-setup` inside the project.
2. In Claude Code, run `/plugin` and confirm `uncle-dev` appears in the installed list.

## Slash commands do not work in Cursor, Copilot, or Windsurf

**Symptom:** `/uncle-dev-spec` and similar commands are not recognized.

**Cause:** Slash commands ship for Claude Code. Other tools do not have them.

**Fix:** Invoke the skill by name instead — for example, "Use the `uncle-dev-spec-driven-development` skill" — or load its `SKILL.md` into that tool's rules file. See the [commands and skills reference](../05-reference/commands-and-skills.md).

## Graph-first search is not used (`graphify: OFF`)

**Symptom:** Skills fall back to grep instead of semantic graph traversal.

**Cause:** No `graphify-out/graph.json` exists in the project.

**Fix:**

1. Build the graph from the project root: `graphify .`
2. Keep it current after changes: `graphify update src/`

Skills detect `graphify-out/graph.json` at startup and switch to graph-first search automatically.

## `pip install graphifyy` fails

**Symptom:** The Graphify install command returns a "package not found" error.

**Cause:** The documented command uses the package name `graphifyy` exactly as written in this repository.

**Fix:** Confirm the correct package name for your environment before installing. Graphify is optional — skip this step if you do not need semantic graph search.

## Config changes are ignored

**Symptom:** You edited `.agents/uncle-dev-setup.yaml`, but the behavior did not change.

**Cause:** The file is read only through `scripts/uncle-dev-config.sh`, and an invalid value is rejected rather than applied.

**Fix:**

1. Validate the file against `scripts/uncle-dev-setup.schema.json`.
2. Fix any reported error, then re-run `/uncle-dev-setup` validation.
3. Start a new session so hooks and rules reload.

## `/uncle-dev-spec-scan` reports ORPHAN or MISSING TEST

**Symptom:** The spec-coherence scan exits non-zero with `✗ ORPHAN` or `✗ MISSING TEST`.

**Cause:**

- `✗ ORPHAN` — code or a test cites a `@spec` ID that does not exist in `docs/specs/`. This blocks (non-zero exit).
- `✗ MISSING TEST` — a spec has code but no test citation.
- `⚠ MISSING CODE` — a spec has a test but no code citation.

**Fix:** Correct the annotation, or add the missing spec, test, or code. Do not invent a spec ID to silence an ORPHAN — define it in `docs/specs/` first. See [Implement spec annotations](../04-customization/implement-spec-annotations.md).

## A commit is blocked by a guard

**Symptom:** A commit or command is stopped by a pre-commit, spec-coherence, or destructive-command guard.

**Cause:** A guard hook intercepted the action and reported a problem.

**Fix:** Read the guard's message — it names the issue. Resolve it (for example, fix the coherence error or confirm the destructive command), then retry. The guards are feedback, not a wall; they exist to catch mistakes before they land.
