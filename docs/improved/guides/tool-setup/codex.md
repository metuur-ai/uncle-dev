---
title: Codex installation
description: Install and verify Uncle Dev commands, skills, agents, project rules, and hook compatibility in Codex.
---

# Install and verify Uncle Dev in Codex

This guide describes the Codex installer in this repository, including the
command and agent adapters. Hook compatibility was reviewed on 8 September 2026
against Codex CLI 0.153.4 and current official documentation. **Uncle Dev hooks
are not activated by this installer.** The hook section records what must be
adapted before that can change.

## Install, activate, then configure the project

From a checkout of this repository, install for your user:

```bash
bash scripts/install-codex.sh
codex plugin add uncle-dev@uncle-dev
```

Use `--force` when intentionally replacing an older installation. Use the
marketplace name printed by the installer if an existing marketplace has a
different name. The personal marketplace is discovered automatically.

For another project's local installation:

```bash
bash scripts/install-codex.sh --scope local /path/to/project
codex plugin marketplace add /path/to/project
codex plugin add uncle-dev@uncle-dev
```

Do not target the installer repository itself. Register the explicit project
marketplace only if it is not already registered. Open a new Codex task after
activation or an update; file installation does not refresh an existing task.

In the target project, invoke `$command-uncle-dev-setup` to run the complete
setup workflow. Existing preferences are preserved; first-time preferences
must be supplied through the setup workflow. It uses `setup-project.sh` to
configure the project. Check its actual output rather than assuming every
component below has become active.

## Component contract

Paths below are relative to the selected installation root: the user's home
for user scope, or the target workspace for local scope.

| Component | Installed form | How it becomes usable |
|---|---|---|
| Plugin | `plugins/uncle-dev/.codex-plugin/plugin.json` | Activate through `codex plugin add` |
| Marketplace | `.agents/plugins/marketplace.json` | Personal discovery or explicit project registration |
| Complete commands | `plugins/uncle-dev/command-templates/*.md` | Read by the matching command entry; preserve every original step |
| Command entries | `plugins/uncle-dev/skills/command-*/SKILL.md` | Explicit invocation, such as `$command-uncle-dev-spec` |
| Ordinary skills | `plugins/uncle-dev/skills/<skill>/SKILL.md` | Invoke the specific skill or let Codex select it |
| Skill display metadata | Skill-local `agents/openai.yaml` | Labels and invocation prompts; not an independent agent |
| Agent source personas | `plugins/uncle-dev/agents/*.md` | Canonical source for native agent generation |
| Native agents | `.codex/agents/*.toml` | Independent named subagents loaded in the selected scope |
| Runtime helpers | `plugins/uncle-dev/scripts/` and `CODEX.md` | Resolve config and routed skills from the active plugin |
| Project preferences | Target `.agents/uncle-dev-setup.yaml` | Read through `uncle-dev-config.sh`, never directly |
| Project instructions | Target `AGENTS.md` and its referenced root instructions | Must be loaded separately from the plugin's reference files |
| Hooks | No Uncle Dev Codex registration yet | Require the adaptation and activation checks below |

The current canonical inventory is 31 commands, 47 ordinary skills, and nine
agents. The generated plugin has 78 skill entries because it exposes each
complete command separately. Counts come from the canonical source directories
declared in `scripts/lib/manifest.sh`, not a second hand-maintained inventory.

### Commands are not their backing skills

```text
$command-uncle-dev-spec Specify invitations for new team members.
```

The display label is `/uncle-dev-spec (command)`. This is an explicit skill
entry point for the **entire command**, not a new built-in slash command. It
loads `command-templates/uncle-dev-spec.md` and follows all routed skills and
companions. It must not substitute `uncle-dev-spec-driven-development` or the
independent `uncle-po` persona. The generated `COMMANDS.md` lists every mapping.

The adapter avoids Codex's automatic command migration, which rejects rendered
command skills above 4,000 bytes and some source-host template features.
The original spec command exceeds that limit. Templates remain byte-identical
to their canonical sources. [Codex migration implementation](https://github.com/openai/codex/blob/main/codex-rs/core-plugins/src/command_migration/plugin.rs).

### Agents and project rules

Ask Codex to delegate a bounded task to `uncle-po`, `uncle-lead`, or
`uncle-dev-ag-code-reviewer`, for example. Native names match the source
filenames. Claude model aliases are not installed as Codex model settings;
the generated agents inherit the session settings. [Native agent configuration](https://learn.chatgpt.com/docs/agent-configuration/subagents).

Bundling `AGENTS.md`, `CLAUDE.md`, and `AGENT_RULES.md` inside a plugin does not
activate them as project instructions. `setup-project.sh` currently injects
the rules block only when Claude Code is detected. **Codex-only project rule
wiring remains a setup gap:** verify the target `AGENTS.md` chain and report
missing instructions instead of claiming the project is fully configured.

## Hook review: configured is not active

The reviewed workstation had a personal Codex `PreToolUse/Bash` Graphify hook.
No Uncle Dev entry was present in the inspected personal hook file, and this
repository had no project `.codex/hooks.json`. Its `.claude/settings.json` was
empty. The enabled Claude plugin owns its own lifecycle manifest; an empty
project settings file does not by itself mean Claude hooks are missing.

All eight Uncle Dev hook toggles resolved to `true` through the config helper.
That records policy, not registration, trust, execution, or enforcement.

The setup skill previously instructed users to inject plugin-root hooks into
project settings. That contradicted `setup-project.sh`, which removes those
entries. The skill now describes the manifest as a reference and preserves
plugin ownership. It also no longer claims Codex has no hook system.

### Canonical hook inventory and required Codex adaptation

The manifest contains 13 handlers across six event groups, referencing 12
distinct scripts. `spec-coherence-guard.sh` has both edit and shell matchers.

| Hook | Claude event / purpose | Codex review result |
|---|---|---|
| `session-start.sh` | SessionStart; load discovery instructions and handoff | Adapt plugin/project path resolution and context output; current `{priority,message}` is not Codex's documented context shape |
| `uncle-dev-mode.sh` | UserPromptSubmit; set session strictness | Validate prompt input and project scope; translate feedback output |
| `check-agents-md.sh` | PreToolUse Edit/Write; context boundary advice | Parse all affected paths from Codex patch input; the shared parser currently expects `file_path` |
| `openspec-guard.sh` | PreToolUse Edit/Write; advise on change naming and artifacts | Same patch-path adaptation; retain advisory behaviour |
| `spec-coherence-guard.sh` | PreToolUse edits and Bash commits; validate spec references | Adapt patch content and multi-file handling; shell branch needs runtime-path and blocking tests |
| `pre-commit-guard.sh` | PreToolUse Bash; check commit message and staged debug artifacts | Command input and exit-2 blocking are compatible candidates; validate config paths, profiles, and shell wrappers |
| `destructive-command-guard.sh` | PreToolUse Bash; detect destructive shell commands | Same shell/runtime validation; preserve enabled/disabled and strictness semantics |
| `knowledge-capture-nudge.sh` | PostToolUse Bash; suggest capturing a solved problem | Validate Codex command response extraction and emit recognised advisory context |
| `test-resource-guard.sh` | PostToolUse Bash; advise on orphaned runtimes | Validate response/project scope and advisory output; must remain advice-only, never kill processes |
| `permission-notify.sh` | Notification permission_prompt; desktop notice | No direct event match in Codex's documented set; `PermissionRequest` needs a deliberate adapter, not a blind rename |
| `gate-notify.sh` | Stop; detect a pending decision in assistant text | Reads Claude transcript structure; adapt to Codex's assistant-message payload or verified transcript format |
| `wrap-nudge.sh` | Stop; advise when context/token thresholds are reached | Usage fields are not established by the documented Stop input; do not claim threshold detection works without a verified source |

`statusline-mode.sh` and `simplify-ignore.sh` exist in `hooks/` but are not
registered in `hooks/hooks.json`. File presence is not automatic execution.
Spec coherence scans `docs/specs/` IDs; it does not validate LID+EARS `R-x.y`
coverage in `docs/ears/`.

### Required Codex hook installation contract — not implemented yet

Codex supports user/project hook files and plugin hooks. `Bash` matches shell
execution; `Edit|Write` can match `apply_patch`, but its input still contains a
patch command rather than Claude's individual file fields. The adapter must
normalise input, working directory, paths, and event-specific JSON output.
Use the supported blocking contract and preserve the distinction between advice
and denial. [Official hook contracts](https://learn.chatgpt.com/docs/hooks).

Before enabling an Uncle Dev hook port:

1. Choose one owner: plugin registration or project `.codex/hooks.json`.
   Preserve unrelated hooks and avoid duplicate user/project/plugin handlers.
2. Package every script dependency, including `hooks/lib/`, runtime scripts,
   and scanner resources. Resolve paths from the installed bundle, not a
   developer's checkout or another product's cache.
3. Read project toggles through the config helper. Keep unrelated projects
   unaffected. Do not assume an enabled toggle creates a hook registration.
4. Test real Codex-shaped inputs, including multi-file patches, allowed and
   blocked commands, disabled toggles, and missing optional metrics.
5. Inspect `/hooks` in Codex CLI. Review and trust new or changed definitions
   through Codex's supported flow; do not write trust hashes in the installer.
6. Verify actual event execution and results. Existing Claude-shaped shell
   tests alone are not evidence of Codex integration.

## Verify updates and diagnose missing components

The installer stages the bundle before publishing it, refuses conflicting
edits without `--force`, and adds a reproducible content hash to the installed
version. This invalidates stale caches without changing the release version.
The archive contains `plugins/`, `.agents/`, and `.codex/` directly. Repeat the
activation step and open a new task after updating.

| Symptom | Check |
|---|---|
| Spec command missing | Activate the updated plugin; search for `command-uncle-dev-spec`, not its backing skill |
| Skill appears as Uncle PO | Old skill display metadata is still cached; refresh the plugin |
| Persona cannot be found | Check the selected scope's `.codex/agents/*.toml`, not skill UI metadata |
| Hooks do not run | Uncle Dev hook port is not implemented; inspect actual sources and trust in `/hooks` |
| Toggles are true but guards do nothing | Toggles do not register hooks; confirm input/output compatibility and execution |
| Rules are not followed | Check the project's `AGENTS.md` chain separately from plugin files |

Repository checks:

```bash
bash scripts/tests/install-codex.test.sh
bash scripts/tests/hook-block-drift.test.sh
bash scripts/tests/hook-contract.test.sh
bash scripts/tests/hook-toggles.test.sh
bash scripts/check-manifest.sh
```

The hook tests validate the existing source-host contract and toggles. They
must not be reported as a successful live Codex hook integration test.
