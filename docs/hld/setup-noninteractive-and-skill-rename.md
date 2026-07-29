# Setup Non-Interactive Mode and Skill Rename — High-Level Design

## Overview

`/uncle-dev-setup` refuses to run in projects that are already configured. The agent reports that the script reads answers from stdin and that every prompt would hit EOF and silently take a default, then hands the work back to the user's terminal.

That claim is false whenever `.agents/uncle-dev-setup.yaml` already exists. `setup-project.sh` branches on that file and sets `SKIP_PREFS=1`, which skips every `read` call. The script documents this itself: *"(no flag) First-time setup. Skips preference questions if config exists."* The skill states the prohibition unconditionally and never checks the condition the script branches on, so it misfires on configured projects while firing correctly on fresh ones.

The underlying rule is sound. Preferences must never be silently defaulted. The problem is that the skill enforces it with a blanket ban on execution rather than a check, and the script offers no way to supply answers without a terminal. So even after the agent has asked the user every question, it still cannot complete a first-time setup.

This change replaces the blanket ban with an explicit branch, adds a non-interactive mode that makes silent defaulting structurally impossible, and renames the skill to `uncle-dev-setup-local` to name it for what it does: configure the local project.

## Stakeholders & Impact

**AI agents running `/uncle-dev-setup`** are the primary consumer. Today they refuse work that is provably safe, and cannot finish first-time setup at all. After this change they run setup directly when it asks nothing, and complete first-time setup once answers are collected.

**Developers onboarding a project** currently get bounced to a terminal to paste a command and answer five prompts. After this change the agent asks the questions in-conversation and completes the setup.

**Downstream tooling** binds to the skill directory name and must move with it: `.claude-plugin/marketplace.json`, `scripts/gen-inventory.sh`, `scripts/check-manifest.sh`, and — most critically — `setup-project.sh` itself, which locates its config template through that path.

**Existing installs** are unaffected in their command surface. Users type `/uncle-dev-setup`, and that name does not change.

## Goals

- An agent may run `setup-project.sh` directly when the script will not prompt, and knows how to tell.
- An agent can complete a genuine first-time setup after collecting the user's answers, with no terminal required.
- Silent defaulting is impossible in the non-interactive path: a missing preference is an error, never a fallback.
- The skill is named `uncle-dev-setup-local`, reflecting that it configures the local project rather than the global installation.
- `agent_skills_root` resolves to the installation actually in use, rather than to wherever the running copy of the script happens to sit, and a routine re-run never silently repoints it.
- `--update` stops destroying project-authored content inside the uncle-dev region of `CLAUDE.md`.
- The published plugin version reflects the change, so the fix reaches installs, and the breaking rename is recorded with a migration note.

## Non-Goals

- **The command name does not change.** `/uncle-dev-setup` stays, across all 211 references.
- **The config filename does not change.** `.agents/uncle-dev-setup.yaml` stays, across all 147 references.
- **The interactive path does not change.** Running the script with no flags in a terminal behaves exactly as before.
- **No backward-compatibility alias.** The old skill name stops resolving; this is a hard rename.
- **No global counterpart skill.** `-local` describes what this skill does; it does not reserve space for a paired global skill.
- **`agent_skills_root` is not blanked and does not point into the project.** It names the global installation where shared scripts live, which is outside any project.
- **Version pinning is not removed.** Cache installs live under a versioned directory by construction; the goal is to point at the right installation, not at an unversioned one.
- **`commands-table` does not gain a generator.** It carries GENERATED markers with nothing behind them; this change updates it by hand and records the gap as debt.

## Success Criteria

- In an already-configured project, the agent runs setup without asking permission and without prompting, and the config's preference values are byte-unchanged.
- In an unconfigured project, the agent asks the five preference questions, then completes setup with those exact values recorded — including values that differ from the script's defaults.
- Omitting any preference in non-interactive mode fails, names every missing variable, and writes no config.
- A first-time setup succeeds after the rename, proving the template path still resolves — through `setup-project.sh` and through the `uncle-dev-configure` TUI, which carries its own copy of that path.
- Every supplied preference is read back from the written config and confirmed, so a substitution that silently stopped matching fails loudly instead of reporting success.
- No path reference to the old skill directory survives outside the audit and research documents kept as historical record.
- An `--update` run preserves project-authored prose and any nested generated block inside the uncle-dev region, and leaves that region where it was in the file.
- No existing reference to the command name or the config filename is renamed, retargeted, or deleted.
- The full test suite passes, including the manifest drift guard.
