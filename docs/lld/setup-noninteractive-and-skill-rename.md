# Setup Non-Interactive Mode and Skill Rename — Low-Level Design

> Revision note: revised after a technical-lead review. Four corrections were material — a fourth hardcoded template path, `commands-table` having no generator, the `agent_skills_root` design failing its own goal, and the absence of a rollback plan.

## Architecture

### Non-interactive preference resolution

`setup-project.sh` currently has two paths. When `.agents/uncle-dev-setup.yaml` exists it sets `SKIP_PREFS=1` and reads prior values through `uncle-dev-config.sh`; otherwise it calls `ask_choice` / `ask_yn`, each of which blocks on a bare `read -r`.

A third path is added, selected by `--non-interactive`, sourcing all five preferences from the environment:

| Variable | Feeds | Allowed values |
|---|---|---|
| `UNCLE_DEV_PREFERENCES_SDD_MODE` | `sdd_mode` | `openspec` \| `lid-ears` |
| `UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS` | `spec_annotations` | `true` \| `false` |
| `UNCLE_DEV_PREFERENCES_TDD_MODE` | `tdd-mode` | `strict` \| `lite` |
| `UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE` | `execution_profile` | `fast` \| `balanced` \| `strict` |
| `UNCLE_DEV_PREFERENCES_GRAPHIFY` | `graphify` | `true` \| `false` |

These names are not new. `scripts/uncle-dev-config.sh:147` already derives an override variable per config key (`ENV_KEY="UNCLE_DEV_$(… tr '.a-z' '_A-Z')"`) with precedence `env → session flag → YAML → default`, documented at `scripts/AGENTS.md:15`. Inventing a parallel short-form namespace would leave two similar `UNCLE_DEV_*` conventions for the same five settings, so the seeding variables reuse the existing one.

Two consequences follow, both mandatory:

- **The read-back must clear the namespace.** R-1.12 verifies the write by reading through `uncle-dev-config.sh`, but the env tier is consulted *first*. With the seeding variables still exported, every lookup returns the value just supplied rather than the value actually stored, and the assertion passes even when the write silently failed. Each lookup runs under `env -u` for all five names (R-1.13).
- **The derivation must handle the hyphen.** The config key is `tdd-mode`, and `tr '.a-z' '_A-Z'` leaves the hyphen, yielding `UNCLE_DEV_PREFERENCES_TDD-MODE` — not a valid shell identifier, so that key is unreachable through the override tier today. Mapping `-` to `_` alongside `.` fixes a pre-existing bug that reusing this convention forces into scope (R-1.14).

These sets are normative in R-1.4. They are *not* derived from the interactive prompts: `ask_choice` does enforce the three multi-valued sets, but `ask_yn` (`setup-project.sh:59-70`) validates nothing at all — any input other than `y` becomes `false`. Non-interactive mode is deliberately stricter than the prompt it replaces.

Resolution is fail-closed. Every unset variable is collected and reported together, then the script exits through the existing `fail()` before any filesystem write. Because `set -euo pipefail` is active (`setup-project.sh:20`), all five reads must use the `${VAR:-}` form; a bare `${VAR}` aborts on the first missing variable with `unbound variable` and makes the collect-all behaviour of R-1.3 impossible. No default is ever applied in this mode; `lid-ears` remains the default only for the interactive `sdd_mode` prompt.

The flag also participates in branch selection, not just in the branch body. Because `SKIP_PREFS=1` would otherwise win whenever a config exists, `--non-interactive` without `--update` against an existing config would accept five variables, ignore all of them, and exit 0. That is the same silent-discard hazard this change exists to remove, so the combination is rejected explicitly (R-1.9) with a message naming `--update --non-interactive` as the supported way to change preferences. Paired with `--update`, the flag re-enters the ask path and sources from the environment under the same completeness rules (R-1.10).

Writing is followed by a read-back (R-1.12). The script already asserts one preference post-write (`setup-project.sh:240-246`), because the two-line scalar form silently defeated exactly that `sed`. The other four have no such guard, so a `sed` pattern that stops matching would write the template default, print `✓`, and exit 0 — reintroducing silent defaulting inside the mode built to eliminate it. The read-back extends the existing `WRITTEN_MODE` pattern to all five and goes through `uncle-dev-config.sh`, preserving the boundary rule.

### Skill rename and its couplings

The rename is `skills/uncle-dev-setup/` → `skills/uncle-dev-setup-local/`, carried out with `git mv` so history follows. The colocated `uncle-dev-setup.template.yaml` moves with the directory; its own filename does not change, because it templates the config file, whose name is fixed.

`uncle-dev-setup` currently denotes four distinct things. Only the third renames:

| Meaning | References | Action |
|---|---|---|
| Command `/uncle-dev-setup` | 211 | unchanged |
| Config file `.agents/uncle-dev-setup.yaml` | 147 | unchanged |
| Skill directory `skills/uncle-dev-setup` | 27 | renames |
| Template `uncle-dev-setup.template.yaml` | 27 | filename unchanged, moves with directory |

Every edit is therefore path-scoped. A repo-wide substitution would corrupt 358 correct references.

Sites that construct a path into the skill directory:

- **`scripts/setup-project.sh:224`** — `TEMPLATE="${REPO_ROOT}/skills/uncle-dev-setup/uncle-dev-setup.template.yaml"`. Reached only on the first-time path, so a miss leaves every already-configured project working while every new project dies with "Template not found".
- **`scripts/uncle-dev-configure.py:44-46`** — the same template path, in the TUI configurator that commit `db0c97a` symlinked onto `PATH` as `uncle-dev-configure`. Same failure class, separate binary.
- **`commands/uncle-dev-setup.md:5`** and its byte-identical mirror `plugins/uncle-dev/commands/uncle-dev-setup.md`.
- **`.claude-plugin/marketplace.json:51`** — `"./skills/uncle-dev-setup"`.
- **`README.md:249`** — the documentation link. `check-manifest.sh` validates README *counts* only (`readme_count()`), never link targets, so nothing would catch this.

`scripts/gen-inventory.sh:93` carries a `uncle-dev-setup Support` phase assignment.

`CLAUDE.md` holds three blocks bearing GENERATED markers, but `gen-inventory.sh` replaces only two of them — `commands` and `skills-by-phase` (`:219-220`). **`commands-table` has markers and no generator**, so its command-to-skill mapping row at `CLAUDE.md:162` must be updated by hand. Treating all three as generated would leave a dangling reference to a directory that no longer exists while forbidding the edit that fixes it.

Runtime skill resolution is unaffected by the rename. `uncle-dev-load-skill.sh` is keyed by base skill name, but nothing passes `uncle-dev-setup` to it — the command file invokes `setup-project.sh` directly. The one behavioural consequence is downstream: a consuming project with `skills.overrides.uncle-dev-setup` or a companion keyed to that name loses the customisation silently, because the loader fails open on an unknown override. That needs a CHANGELOG migration note (R-5.3), not a code change.

### CLAUDE.md update safety

`--update` currently removes everything between `<!-- uncle-dev -->` and `<!-- /uncle-dev -->` (`setup-project.sh:306-319`) and appends a canned block at end of file (`:341-368`). Two problems follow.

First, it is destructive to anything a project has added inside that region. In this repository the region spans `CLAUDE.md:77-172` — 96 of 172 lines — and contains the Code Context rules, the OpenCode integration section, the slash-command table, and the `commands-table` GENERATED markers at `:137`. An `--update` here would delete all of it.

Second, remove-then-append is not positionally idempotent: in any project where the block sits mid-file, every `--update` migrates it to the end.

The fix is to give the script's own generated content inner markers nested inside the outer delimiters, and to replace only that inner span, in place. Content the script does not recognise stays where it is; nested `BEGIN GENERATED` blocks survive with their markers intact; the region keeps its position. Projects whose region predates the inner markers get them inserted around the recognised canned content, with unrecognised content left alone.

### `agent_skills_root` resolution

The field names the global installation where shared scripts, skills, and commands live. It necessarily points outside the project, so blanking it would break shared-script lookup.

The original framing of this unit was wrong. It treated the version segment in `.../uncle-dev/1.4.1` as the defect and proposed preferring `${CLAUDE_PLUGIN_ROOT}` as the cure — but that variable *is* the versioned cache path, so the proposal could not have achieved its stated goal. Version pinning is intrinsic to cache-based installs and is not fixable here.

The actual defect is that the value is derived from where the running script happens to live, which is wrong whenever that copy is not the installation in use. Resolution is therefore reordered by *authority* rather than by convenience:

1. If the running script sits inside a complete agent-skills checkout — detected by sibling `scripts/install-claude.sh` and `skills/` — that checkout wins. An explicit clone is a stronger signal of intent than an ambient environment variable.
2. Otherwise, `CLAUDE_PLUGIN_ROOT` when set and non-empty. It is populated for plugin-provided commands and hooks in Claude Code, and unset in a plain shell.
3. Otherwise, the existing parent-of-`SCRIPT_DIR` derivation.

Separately, `setup-project.sh:252` currently rewrites this field on *every* `SKIP_PREFS` run, including the no-flag path. That would let a plain re-run silently repoint a project from a developer's checkout to a plugin cache, contradicting R-1.6's promise that the no-flag path is unchanged. An existing non-empty value is therefore preserved unless `--update` is passed (R-4.4).

One constraint follows and must not be violated during cleanup: the template path is **not** derived from the resolved `agent_skills_root` (R-4.6). A newer script resolving its template through a `CLAUDE_PLUGIN_ROOT` that points at an un-upgraded cache would look for `skills/uncle-dev-setup-local/` inside an installation that still has `skills/uncle-dev-setup/`, failing on every new project. `TEMPLATE` stays anchored to the running script's own directory.

### Version bump

Both `.claude-plugin/plugin.json:4` and `plugins/uncle-dev/.codex-plugin/plugin.json:3` declare `1.4.1` and move together to `1.5.0` — a minor bump, since the change adds a flag and renames a public skill without altering the command surface. `marketplace.json` carries no version key, so these two files are the complete set.

## Constraints

- Bash only, no new runtime dependencies. `jq` is already required by the script's settings-cleanup step.
- `set -euo pipefail` is active. All environment reads in the new path must use `${VAR:-}`.
- `scripts/tests/hook-toggles.test.sh` asserts (R-2.3) that `setup-project.sh` never reads `.agents/uncle-dev-setup.yaml` directly; all config reads go through `uncle-dev-config.sh`. The same test `bash -n` syntax-checks the script. An `[[ -f ]]` existence check is explicitly not a read.
- The boundary guard scans `scripts/`, which **contains** `scripts/tests/`. A new test that asserts a written value by grepping the YAML will fail the suite, and the failure will point at the boundary rule rather than at the test. Tests must read values via `uncle-dev-config.sh` and assert byte-identity with `cmp` or a checksum.
- Tests are plain bash with `PASS:`/`FAIL:` output and a non-zero exit on failure. `run-all.sh` holds an explicit `TESTS=()` array and does not glob, so a new file must be registered there.
- Per `scripts/tests/AGENTS.md`: self-contained files, paths resolved from `${BASH_SOURCE[0]}`, `mktemp -d` plus `trap` for any writes, no mutation of tracked files, and no dependence on the real `$HOME`. Tool detection reads `~/.claude/plugins` and aborts the whole run when nothing is found, so `HOME` must be stubbed.
- `commands/uncle-dev-setup.md` and its `plugins/` mirror must stay byte-identical or `check-manifest.sh` fails.
- `lint-skills.sh` is report-only in CI and pre-commit. `--fix` must never be run: it strips `**bold**` and deletes the "When to Use" sections this repo's skill anatomy requires.
- `setup-project.sh` is currently md5-identical to the installed 1.4.1 cache, which makes "did I test the repo or the install?" invisible. Verification must invoke the repository copy by explicit path.
- `R-x.y` IDs in `docs/ears/` are a manual coverage check with no scanner. `setup-project.sh` already carries `(R-2.1)` and `(R-2.3)` comments referring to a *different* spec (`docs/ears/audit-remediation.md`); new annotations should name their spec slug to stay unambiguous.

## Key Decisions

**Fail on missing preferences rather than defaulting.** The entire purpose of the original rule is that preferences are never chosen on the user's behalf. A non-interactive mode that fell back to defaults would reintroduce exactly the hazard the rule exists to prevent, while removing the prompt that made it visible.

**Environment variables rather than piped stdin.** Piping answers into the existing `read` calls works today and needs no script change, but it is positional: any future reordering of the questions would silently misassign answers. Named variables are order-independent and validate individually.

**Hard rename with no alias.** Users interact through `/uncle-dev-setup`, which is unchanged, and no runtime path resolves this skill by name. The cost is confined to downstream `skills.overrides` keys, which a CHANGELOG note covers.

**Report all missing variables at once.** Failing on the first would force five round-trips to discover a fully-specified invocation.

**Reject `--non-interactive` against an existing config rather than warning or overwriting.** A warning still exits 0, so any caller checking only the exit status treats a discarded set of preferences as success. Overwriting makes a single flag destructive. Rejecting keeps the failure impossible to miss and costs the caller one extra flag. The corollary is that unattended provisioning must use `--update --non-interactive`, which is documented rather than left to be discovered on a second run.

**Verify the write, do not trust it.** The one existing post-write assertion exists because a `sed` silently stopped matching. Extending it to all five converts R-1.7 from advisory to mechanical for ~8 lines.

**Resolve `agent_skills_root` by authority, not convenience.** An explicit checkout outranks an ambient environment variable, because the environment describes what invoked the script while the checkout describes what the developer is working on.

**Give generated CLAUDE.md content its own inner markers.** The alternative — teaching `--update` to diff the canned block against arbitrary user prose — is unbounded. Inner markers make ownership explicit and reduce the rule to "replace only what you own."

## Rollback

The two halves are independently revertible; they touch disjoint file sets. The `--non-interactive` flag lives entirely inside `setup-project.sh`, its test, and prose. The rename touches the skill directory, five path references, `gen-inventory.sh`, and `CLAUDE.md`.

No config written by 1.5.0 is unreadable by 1.4.1: the change adds no new config keys, and `agent_skills_root` remains a plain string. A project set up under 1.5.0 therefore continues to work if the plugin is rolled back — with one exception, that a project whose `skills.overrides` were re-keyed to `uncle-dev-setup-local` per R-5.3 would need those keys reverted too.

Rollback is forward-only: publish a new patch version rather than republishing `1.4.1`. Installed caches are keyed by version directory, so re-publishing an existing version leaves users on whichever copy they already resolved and makes the two divergent under one identifier.

Because an un-upgraded 1.4.1 cache is internally consistent, a repo-only revert cannot break an installed user. Sequencing between the rename and the version bump is therefore unconstrained, provided both land before publication.

## Out of Scope

- Any change to the `/uncle-dev-setup` command name or the `.agents/uncle-dev-setup.yaml` filename.
- A compatibility alias for the old skill name.
- A global counterpart to the `-local` skill.
- Removing version pinning from cache-based installs, which is intrinsic to how the plugin cache is laid out.
- The uncommitted two-line diff currently sitting in this repo's own `.agents/uncle-dev-setup.yaml`, which needs a separate restore-or-keep decision.
- `SKILL.md:457`, which verifies a `session-start.sh` SessionStart hook while step 4 of the script strips `${CLAUDE_PLUGIN_ROOT}` hooks. Pre-existing inconsistency.
- Supplying a generator for the `commands-table` block. This change updates it by hand and records the missing generator as follow-up debt.
- Publishing or distributing the bumped version.
