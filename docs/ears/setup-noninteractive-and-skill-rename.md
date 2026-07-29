# Setup Non-Interactive Mode and Skill Rename — EARS Specifications

> Revision note: Units 4 and 6 were added or redesigned after a technical-lead review. Unit 4's original design (prefer `CLAUDE_PLUGIN_ROOT`) failed its own goal, because that variable is itself the version-pinned path. Unit 6 exists because `--update` is destructive to this repository's own `CLAUDE.md`.
>
> Second revision, after code-context prep: `scripts/uncle-dev-config.sh` already defines an env-override tier in the `UNCLE_DEV_*` namespace with precedence `env → session flag → YAML → default`. The five seeding variables were renamed onto that existing convention (R-1.1); the read-back must clear them or it verifies nothing (R-1.13); and the derivation must handle the hyphen in `tdd-mode` (R-1.14).

## Unit 1: Non-interactive preference resolution

**Why:** An agent that has already collected the user's answers still cannot complete a first-time setup, because the only way to supply preferences is a blocking `read` on a terminal. This unit gives it a path that carries the answers explicitly, and makes silently substituting a default impossible rather than merely discouraged.

| ID | EARS statement |
| --- | --- |
| R-1.1 | WHEN `setup-project.sh` is invoked with `--non-interactive`, THE SYSTEM SHALL source all five workflow preferences from `UNCLE_DEV_PREFERENCES_SDD_MODE`, `UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS`, `UNCLE_DEV_PREFERENCES_TDD_MODE`, `UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE`, and `UNCLE_DEV_PREFERENCES_GRAPHIFY` instead of reading standard input. These names follow the existing override convention documented in `scripts/AGENTS.md:15`, rather than introducing a second `UNCLE_DEV_*` convention. |
| R-1.2 | WHILE `--non-interactive` is in effect, THE SYSTEM SHALL NOT invoke `ask`, `ask_yn`, or `ask_choice`, and SHALL NOT read from standard input. |
| R-1.3 | IF any of the five preference variables is unset or empty, THE SYSTEM SHALL exit non-zero and name every missing variable in a single message. |
| R-1.4 | IF any preference variable holds a value outside its allowed set, THE SYSTEM SHALL exit non-zero and report the offending variable together with its allowed values. The allowed sets are normative here: `sdd_mode` ∈ {`openspec`, `lid-ears`}; `tdd-mode` ∈ {`strict`, `lite`}; `execution_profile` ∈ {`fast`, `balanced`, `strict`}; `spec_annotations` ∈ {`true`, `false`}; `graphify` ∈ {`true`, `false`}. |
| R-1.5 | WHEN preference resolution fails under R-1.3 or R-1.4, THE SYSTEM SHALL exit before creating directories or writing `.agents/uncle-dev-setup.yaml`, leaving the filesystem unchanged. |
| R-1.6 | IF `--non-interactive` is absent, THE SYSTEM SHALL issue the same prompts, write the same preference values, and return the same exit code as it does before this change. |
| R-1.7 | WHEN `--non-interactive` succeeds, THE SYSTEM SHALL write each supplied preference verbatim, including values that differ from the interactive defaults. |
| R-1.8 | WHERE a preference variable is set but `--non-interactive` was not passed, THE SYSTEM SHALL ignore it and prompt as normal, so environment state cannot silently alter an interactive run. |
| R-1.9 | IF `--non-interactive` is passed without `--update` WHILE `.agents/uncle-dev-setup.yaml` already exists, THE SYSTEM SHALL exit non-zero stating that the supplied variables would be ignored, and SHALL name `--update --non-interactive` as the way to change preferences. It SHALL NOT discard the variables silently and SHALL NOT write any file. |
| R-1.10 | WHEN `--update` and `--non-interactive` are passed together, THE SYSTEM SHALL source all five preferences from the environment under the same completeness and validity rules as R-1.3 and R-1.4, and SHALL overwrite the existing preferences with those values. |
| R-1.11 | THE SYSTEM SHALL retain `lid-ears` as the default offered by the interactive `sdd_mode` prompt, and SHALL NOT apply that or any other default in `--non-interactive` mode. |
| R-1.12 | WHEN `--non-interactive` has written the config, THE SYSTEM SHALL read all five preferences back through `scripts/uncle-dev-config.sh` and exit non-zero naming any whose stored value differs from the supplied value. |
| R-1.13 | WHILE performing any post-write verification of a preference — the R-1.12 read-back and the pre-existing `sdd_mode` assertion alike — THE SYSTEM SHALL clear the `UNCLE_DEV_PREFERENCES_*` variables from the environment of each lookup. `uncle-dev-config.sh` resolves `env → session flag → YAML → default`, so leaving them set returns the environment value rather than the stored one. This is a pre-existing defect, reproduced against an unmodified 1.4.1: with `UNCLE_DEV_PREFERENCES_SDD_MODE` set to a differing value the assertion fails spuriously and blames the template's scalar form, and where the value happens to match it would pass despite a failed write. |
| R-1.14 | THE SYSTEM SHALL derive the environment-variable name for a config key by mapping both `.` and `-` to `_` before upper-casing, so that `preferences.tdd-mode` resolves to `UNCLE_DEV_PREFERENCES_TDD_MODE`. The current derivation at `scripts/uncle-dev-config.sh:147` leaves the hyphen in place, producing a name that is not a valid shell identifier and leaving that key unreachable through the override tier. |
| R-1.15 | THE SYSTEM SHALL document `--non-interactive`, the five variables, and their allowed values in its `--help` output. |

## Unit 2: Agent execution branch

**Why:** The reported defect is the skill refusing to run setup in projects where the script provably never prompts. The rule was stated as an unconditional ban instead of a check against the same condition the script branches on.

| ID | EARS statement |
| --- | --- |
| R-2.1 | WHERE `.agents/uncle-dev-setup.yaml` exists in the target project AND `--update` is not being passed, THE SYSTEM SHALL permit the agent to run `setup-project.sh` directly, on the grounds that the script takes the `SKIP_PREFS=1` path and issues no prompts. |
| R-2.2 | WHERE the config file is absent, THE SYSTEM SHALL require the agent to obtain all five preference answers from the user before invoking the script. |
| R-2.3 | WHEN the agent holds all five answers and the config is absent, THE SYSTEM SHALL direct it to complete setup via `--non-interactive` rather than deferring to the user's terminal. |
| R-2.4 | THE SYSTEM SHALL continue to prohibit the agent from hand-writing `.agents/uncle-dev-setup.yaml` or inventing preference values, in every mode. |
| R-2.5 | THE SYSTEM SHALL document that `PROJECT_ROOT` derives from the working directory, so that invoking the script from the wrong directory configures the wrong project. |
| R-2.6 | THE SYSTEM SHALL state the identical execution rule in `skills/uncle-dev-setup-local/SKILL.md`, `commands/uncle-dev-setup.md`, and `plugins/uncle-dev/commands/uncle-dev-setup.md`. |
| R-2.7 | THE SYSTEM SHALL document `--update --non-interactive` as the supported idiom for unattended or repeated provisioning, so that callers do not discover R-1.9 only on a second run. |

## Unit 3: Skill rename and referential integrity

**Why:** The skill configures the local project, and its name should say so. The rename is the riskier half of this change: `uncle-dev-setup` denotes four different things, and only one of them may move.

| ID | EARS statement |
| --- | --- |
| R-3.1 | THE SYSTEM SHALL name the skill directory `skills/uncle-dev-setup-local/` and set the matching `name` field in its frontmatter. |
| R-3.2 | THE SYSTEM SHALL preserve the command name `/uncle-dev-setup` unchanged at every reference. |
| R-3.3 | THE SYSTEM SHALL preserve the config filename `.agents/uncle-dev-setup.yaml` unchanged at every reference, and the template filename `uncle-dev-setup.template.yaml` unchanged within its relocated directory. |
| R-3.4 | WHEN the skill directory is renamed, THE SYSTEM SHALL update **every** site that constructs a path to the skill directory or its template, specifically `scripts/setup-project.sh` and `scripts/uncle-dev-configure.py`, so that both first-time setup and the TUI configurator resolve the template successfully. |
| R-3.5 | THE SYSTEM SHALL update the skill path in `.claude-plugin/marketplace.json`, the skill name and path in both command files, and the skill documentation link in `README.md`. |
| R-3.6 | THE SYSTEM SHALL update the phase assignment in `scripts/gen-inventory.sh` and regenerate the two blocks that script owns, `commands` and `skills-by-phase`. |
| R-3.7 | THE SYSTEM SHALL hand-update the command-to-skill mapping row in the `commands-table` block of `CLAUDE.md`, which bears GENERATED markers but has no generator and is therefore maintained by hand. |
| R-3.8 | THE SYSTEM SHALL NOT provide an alias for the former skill name. |
| R-3.9 | THE SYSTEM SHALL NOT rename, retarget, or delete any existing reference to the command name or the config filename. New references to either, introduced by Units 1 and 2, are expected and permitted. |
| R-3.10 | THE SYSTEM SHALL commit the directory rename separately from any content edit to the renamed files, so that version control reports a rename rather than a deletion and addition. |
| R-3.11 | THE SYSTEM SHALL leave references to the former path in `docs/audit/`, `docs/lld/audit-remediation.md`, and `.uncle-dev/research/` unchanged, as historical record. |

## Unit 4: Global installation path resolution

**Why:** `agent_skills_root` tells every skill, command, and agent where the shared utility scripts live. It is currently derived from the running script's own location, which is wrong whenever the script is invoked from a copy that is not the installation in use. Version pinning is inherent to cache-based installs and is not itself the defect; pointing at the wrong installation is.

| ID | EARS statement |
| --- | --- |
| R-4.1 | WHERE the running script resides inside a complete agent-skills checkout, identified by the presence of sibling `scripts/install-claude.sh` and `skills/`, THE SYSTEM SHALL resolve `agent_skills_root` to that checkout root, in preference to any environment variable. |
| R-4.2 | IF R-4.1 does not apply AND `CLAUDE_PLUGIN_ROOT` is set and non-empty, THE SYSTEM SHALL resolve `agent_skills_root` from it. |
| R-4.3 | IF neither R-4.1 nor R-4.2 applies, THE SYSTEM SHALL fall back to the existing derivation from the running script's parent directory. |
| R-4.4 | WHILE an existing config holds a non-empty `agent_skills_root` AND `--update` was not passed, THE SYSTEM SHALL preserve the stored value rather than rewriting it, so that a no-flag run cannot silently repoint a project from a checkout to a plugin cache. |
| R-4.5 | THE SYSTEM SHALL continue to write `agent_skills_root` as a path to the global installation, and SHALL NOT blank it or point it inside the project. |
| R-4.6 | THE SYSTEM SHALL NOT construct the template path from the resolved `agent_skills_root`; the template SHALL continue to resolve relative to the running script's own directory, so that a newer script cannot look for its template inside an older installation. |

## Unit 5: Release consistency

**Why:** The repository is the source of truth, but the installed plugin is a versioned copy. Without a bump the fix never reaches an install, and a breaking rename without an alias needs a written migration note.

| ID | EARS statement |
| --- | --- |
| R-5.1 | WHEN this change ships, THE SYSTEM SHALL declare version `1.5.0` in `.claude-plugin/plugin.json` and in `plugins/uncle-dev/.codex-plugin/plugin.json`. |
| R-5.2 | THE SYSTEM SHALL keep both version declarations identical. |
| R-5.3 | THE SYSTEM SHALL record in `CHANGELOG.md` the skill rename, the absence of an alias, and the fact that any consuming project keying `skills.overrides` or `skills.companions` to `uncle-dev-setup` must re-key to `uncle-dev-setup-local`, because `uncle-dev-load-skill.sh` fails open on an unknown override and would drop the customization without warning. |

## Unit 6: CLAUDE.md update safety

**Why:** `--update` currently removes everything between `<!-- uncle-dev -->` and `<!-- /uncle-dev -->` and appends a canned block at end of file. In this repository that region spans 96 of 172 lines and contains the `commands-table` GENERATED markers. R-1.10 makes `--update --non-interactive` the supported provisioning idiom, so this destructiveness stops being theoretical.

| ID | EARS statement |
| --- | --- |
| R-6.1 | THE SYSTEM SHALL delimit the content it generates inside the uncle-dev region with its own inner markers, distinct from the outer `<!-- uncle-dev -->` delimiters. |
| R-6.2 | WHEN `--update` rewrites the region, THE SYSTEM SHALL replace only the content between those inner markers, leaving all other content within the region intact. |
| R-6.3 | WHEN `--update` rewrites the region, THE SYSTEM SHALL preserve the region's position in the file rather than removing it and appending at end of file, so that repeated runs are positionally idempotent. |
| R-6.4 | THE SYSTEM SHALL preserve any nested `<!-- BEGIN GENERATED: … -->` / `<!-- END GENERATED: … -->` block found within the region, including its markers and its content. |
| R-6.5 | WHERE a project's region predates the inner markers, THE SYSTEM SHALL insert them around the content it recognises as its own, and SHALL NOT remove content it does not recognise. |

## Unit 7: Verification

**Why:** The template-path coupling in R-3.4 fires only on the first-time path, so a suite that exercises only already-configured projects would report green while every new project is broken. Coverage of `R-x.y` IDs in this repository is a manual check with no scanner, so gaps do not surface on their own.

| ID | EARS statement |
| --- | --- |
| R-7.1 | THE SYSTEM SHALL provide a test that completes a first-time setup in a temporary directory via `--non-interactive` with standard input closed, thereby exercising the renamed template path and proving R-1.2. |
| R-7.2 | THE SYSTEM SHALL provide a test asserting that a supplied non-default value, `execution_profile=fast`, is recorded verbatim, proving values are carried rather than defaulted. |
| R-7.3 | THE SYSTEM SHALL provide tests asserting non-zero exit and an unchanged filesystem when a preference is omitted, and non-zero exit when a preference is invalid. |
| R-7.4 | THE SYSTEM SHALL provide a test asserting that an already-configured project runs to completion with standard input closed and its preference values byte-unchanged. |
| R-7.5 | THE SYSTEM SHALL provide tests asserting `--help` exits zero, documents the new flag, and that an unrecognised flag exits non-zero. |
| R-7.6 | THE SYSTEM SHALL register the new test file in the `TESTS` array of `run-all.sh`, which does not discover tests by globbing. |
| R-7.7 | WHEN the full suite runs, THE SYSTEM SHALL pass the manifest drift guard, confirming the two command files remain byte-identical and the marketplace inventory matches the directories on disk. |
| R-7.8 | THE SYSTEM SHALL stub `HOME` to a temporary directory containing a fake `.claude/plugins` for every test that invokes `setup-project.sh`, so tool detection never depends on the host and cannot abort with "No supported AI tools detected". |
| R-7.9 | THE SYSTEM SHALL provide a test asserting that `--non-interactive` against an existing config exits non-zero, names `--update`, and leaves the config byte-unchanged, including the case where a prior run wrote the config but then failed. |
| R-7.10 | THE SYSTEM SHALL provide a test asserting that `--update --non-interactive` overwrites existing preferences with the supplied values. |
| R-7.11 | WHERE any verification step exercises the script, THE SYSTEM SHALL invoke it by explicit repository path rather than through plugin-cache resolution, because tests must exercise the repository copy and not an installed one. |
| R-7.12 | THE SYSTEM SHALL read preference values in tests through `scripts/uncle-dev-config.sh`, and assert byte-identity with `cmp` or a checksum, and SHALL NOT `grep`, `awk`, or otherwise parse `.agents/uncle-dev-setup.yaml` directly, which would trip the boundary guard in `hook-toggles.test.sh`. |
| R-7.13 | THE SYSTEM SHALL verify Unit 2 by asserting that the execution-branch rule text is present and identical across the three files named in R-2.6. |
| R-7.14 | THE SYSTEM SHALL verify Unit 4 by asserting the resolved `agent_skills_root` for each of the three resolution paths in R-4.1 through R-4.3, and that a no-flag run preserves an existing value per R-4.4. |
| R-7.15 | THE SYSTEM SHALL verify Unit 6 by asserting that an `--update` run against a region containing a nested GENERATED block and unrecognised prose preserves both, and leaves the region in its original file position. |
| R-7.16 | WHEN the rename is complete, THE SYSTEM SHALL confirm that no path reference to `skills/uncle-dev-setup/` remains outside the historical locations named in R-3.11. |
