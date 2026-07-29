# Setup Non-Interactive Mode and Skill Rename — Tasks

Source specs: `docs/hld/`, `docs/lld/`, `docs/ears/setup-noninteractive-and-skill-rename.md`.

Stories 1.1–1.6 and 4.1–4.3 and 6.1–6.2 all edit `scripts/setup-project.sh` (except 1.1) and carry `mutex: setup-script`.

## Unit 1: Non-interactive preference resolution

- [ ] 1.1 Map `-` to `_` in the config env-key derivation (est: ~15m)
  - why: reusing the existing override convention forces this — `preferences.tdd-mode` currently derives `UNCLE_DEV_PREFERENCES_TDD-MODE`, not a valid shell identifier, so that one key cannot be seeded or overridden at all. Pre-existing bug, blocking everything downstream.
  - acceptance: R-1.14 — THE SYSTEM SHALL derive the environment-variable name by mapping both `.` and `-` to `_` before upper-casing.
  - verify: `UNCLE_DEV_PREFERENCES_TDD_MODE=strict bash scripts/uncle-dev-config.sh preferences.tdd-mode` returns `strict`; `bash scripts/tests/config-env-override.test.sh` green.

- [ ] 1.2 Add `--non-interactive` and source the five preferences from the environment (deps: 1.1, est: ~45m, mutex: setup-script)
  - why: an agent that has already asked the user every question still cannot finish a first-time setup, because the only input path is a blocking `read` on a terminal.
  - acceptance: R-1.1, R-1.2, R-1.3, R-1.4, R-1.5, R-1.7, R-1.8, R-1.11.
  - verify: all five set → exit 0 with values written verbatim; one unset → exit non-zero naming it and nothing written; value outside its set → exit non-zero naming the variable and its allowed values; variables set without the flag → prompts still appear.
  - note: `set -euo pipefail` is at `:20`, so every read must use `${VAR:-}` or the first missing variable aborts with `unbound variable` and defeats the collect-all behaviour R-1.3 requires.

- [ ] 1.3 Preserve the interactive path unchanged (deps: 1.2, est: ~10m, mutex: setup-script)
  - why: the flag must be strictly additive; any behaviour change to the existing path would break every current caller.
  - acceptance: R-1.6 — IF `--non-interactive` is absent, THE SYSTEM SHALL issue the same prompts, write the same values, and return the same exit code as before this change.
  - verify: a scripted interactive run with piped answers produces a config byte-identical to one produced before the change.

- [ ] 1.4 Reject `--non-interactive` against an existing config; support `--update --non-interactive` (deps: 1.3, est: ~30m, mutex: setup-script)
  - why: `SKIP_PREFS=1` wins whenever a config exists, so the flag alone would accept five variables, discard all of them, and exit 0 — the exact silent-discard failure this change exists to remove.
  - acceptance: R-1.9, R-1.10.
  - verify: flag without `--update` against an existing config → exit non-zero naming `--update`, config byte-unchanged; with `--update` → preferences overwritten with the supplied values.

- [ ] 1.5 Read back all five preferences and fail on mismatch (deps: 1.4, est: ~30m, mutex: setup-script)
  - why: only `sdd_mode` is asserted post-write today (`:240-246`), and that assertion exists because a `sed` silently stopped matching. The other four could take template defaults and still print `✓`.
  - acceptance: R-1.12, R-1.13.
  - verify: temporarily break one `sed` pattern → the run fails naming that preference. Confirm each lookup runs under `env -u` for all five names, since `uncle-dev-config.sh` resolves env before YAML and would otherwise echo back the supplied value.

- [ ] 1.6 Document the flag and variables in `--help` (deps: 1.5, est: ~10m, mutex: setup-script)
  - why: a fail-closed flag is unusable if the caller cannot discover which five variables it demands.
  - acceptance: R-1.15.
  - verify: `bash scripts/setup-project.sh --help` exits 0 and names the flag, all five variables, and their allowed values.

## Unit 2: Agent execution branch

- [ ] 2.1 Replace the blanket prohibition with the config-exists branch (deps: 1.6, est: ~30m)
  - why: this is the reported defect. The skill bans execution unconditionally instead of checking the same condition the script branches on, so it refuses work that is provably safe.
  - acceptance: R-2.1, R-2.2, R-2.3, R-2.4, R-2.5.
  - verify: the skill states all four situations; `--update` is explicitly excluded from the "agent may run directly" case, since it re-enters the prompting path.

- [ ] 2.2 State the identical rule in both command files (deps: 2.1, est: ~15m)
  - why: `commands/uncle-dev-setup.md` and its `plugins/` mirror restate the rule; drift between them fails the manifest guard.
  - acceptance: R-2.6.
  - verify: `cmp commands/uncle-dev-setup.md plugins/uncle-dev/commands/uncle-dev-setup.md` is clean; `bash scripts/check-manifest.sh` passes.

- [ ] 2.3 Document `--update --non-interactive` as the provisioning idiom (deps: 2.2, est: ~10m)
  - why: a pipeline running plain `--non-interactive` every build succeeds once and then fails forever under R-1.9. That should be documented, not discovered on the second run.
  - acceptance: R-2.7.
  - verify: the idiom appears in the skill and both command files.

## Unit 3: Skill rename and referential integrity

- [ ] 3.1 Rename the directory, and nothing else, in its own commit (deps: 2.3, est: ~10m)
  - why: git infers renames by similarity rather than recording them; bundling content edits into the same commit makes it report a delete plus an add and loses the history link.
  - acceptance: R-3.10.
  - verify: `git show --stat` on that commit reports a rename with no other files touched.

- [ ] 3.2 Update every path site and the frontmatter name (deps: 3.1, est: ~30m)
  - why: five separate files construct a path into the skill directory. `setup-project.sh:224` and `uncle-dev-configure.py:44-46` both resolve the config template, and both fire only on the first-time path — so missing either leaves configured projects working while every new project dies.
  - acceptance: R-3.1, R-3.4, R-3.5.
  - verify: `setup-project.sh:224`, `uncle-dev-configure.py:44-46`, both command files `:5`, `.claude-plugin/marketplace.json:51`, `README.md:249` all updated; frontmatter `name` is `uncle-dev-setup-local`.
  - note: never run an unscoped substitution — 358 references to the command name and the config filename must not move.

- [ ] 3.3 Update the phase assignment and regenerate the two generated blocks (deps: 3.2, est: ~10m)
  - why: `CLAUDE.md` advertises the skill roster to every agent; a stale entry points at a directory that no longer exists.
  - acceptance: R-3.6.
  - verify: `gen-inventory.sh:93` reads `uncle-dev-setup-local Support`; running the script refreshes `commands` and `skills-by-phase`.

- [ ] 3.4 Hand-update the `commands-table` mapping row (deps: 3.3, est: ~5m)
  - why: `commands-table` carries GENERATED markers but has no generator — `gen-inventory.sh` replaces only two blocks. Treating it as generated would leave `CLAUDE.md:162` dangling while forbidding the edit that fixes it.
  - acceptance: R-3.7.
  - verify: `CLAUDE.md:162` maps `/uncle-dev-setup` to `uncle-dev-setup-local`.

- [ ] 3.5 Confirm no alias, no collateral, historical references intact (deps: 3.4, est: ~10m)
  - why: the rename's whole risk is collateral damage to the three meanings of `uncle-dev-setup` that must not move.
  - acceptance: R-3.2, R-3.3, R-3.8, R-3.9, R-3.11.
  - verify: the command name `/uncle-dev-setup` is unchanged at all 211 references; the config filename `.agents/uncle-dev-setup.yaml` is unchanged at all 147, and `uncle-dev-setup.template.yaml` keeps its filename inside the relocated directory; no alias resolves the old skill name; no existing reference was renamed or deleted; references under `docs/audit/`, `docs/lld/audit-remediation.md`, and `.uncle-dev/research/` are untouched.

## Unit 4: Global installation path resolution

- [ ] 4.1 Resolve `agent_skills_root` by authority (deps: 3.5, est: ~30m, mutex: setup-script)
  - why: the value is derived from where the running script sits, which is wrong whenever that copy is not the installation in use. An explicit checkout is a stronger signal of intent than an ambient environment variable.
  - acceptance: R-4.1, R-4.2, R-4.3, R-4.5.
  - verify: script inside a checkout → checkout root wins even with `CLAUDE_PLUGIN_ROOT` set; outside a checkout with the variable set → resolves from it; neither → falls back to the parent of `SCRIPT_DIR`. Value is never blank and never inside the project.

- [ ] 4.2 Preserve an existing value on no-flag runs (deps: 4.1, est: ~15m, mutex: setup-script)
  - why: `:252` rewrites this field on every `SKIP_PREFS` run, so a plain re-run would silently repoint a project from a developer's checkout to a plugin cache — contradicting R-1.6's promise that the no-flag path is unchanged.
  - acceptance: R-4.4.
  - verify: a no-flag run against a config holding a non-empty value leaves it byte-identical.

- [ ] 4.3 Keep `TEMPLATE` anchored to the script's own directory (deps: 4.2, est: ~10m, mutex: setup-script)
  - why: deriving the template from the resolved root would let a newer script look for `skills/uncle-dev-setup-local/` inside an un-upgraded cache that still has `skills/uncle-dev-setup/`, failing on every new project.
  - acceptance: R-4.6.
  - verify: `TEMPLATE` derives from `SCRIPT_DIR`, not from `agent_skills_root`; a first-time setup succeeds with `CLAUDE_PLUGIN_ROOT` pointed at an older cache.

## Unit 5: Release consistency

- [ ] 5.1 Bump both version declarations to 1.5.0 (deps: 6.2, est: ~5m)
  - why: the repository is the source of truth but installs are versioned copies; without a bump the fix reaches nobody, and a drift between the two manifests sends Codex to a different build.
  - acceptance: R-5.1, R-5.2.
  - verify: `.claude-plugin/plugin.json:4` and `plugins/uncle-dev/.codex-plugin/plugin.json:3` both read `1.5.0`.

- [ ] 5.2 Record the rename and the override-key migration in CHANGELOG (deps: 5.1, est: ~15m)
  - why: `uncle-dev-load-skill.sh` fails open on an unknown override, so a consuming project keying `skills.overrides` to the old name loses its customisation with no warning at all.
  - acceptance: R-5.3.
  - verify: the entry names the rename, the absence of an alias, and the required re-key to `uncle-dev-setup-local`.

## Unit 6: CLAUDE.md update safety

- [ ] 6.1 Give generated content inner markers and replace in place (deps: 4.3, est: ~45m, mutex: setup-script)
  - why: `--update` removes the entire uncle-dev region and appends a canned block at end of file. In this repository that region is `CLAUDE.md:77-172` — 96 of 172 lines — and R-1.10 makes `--update --non-interactive` the recommended idiom, so the destructiveness stops being theoretical.
  - acceptance: R-6.1, R-6.2, R-6.3.
  - verify: `--update` against a fixture whose region sits mid-file leaves it in place and rewrites only the inner span.

- [ ] 6.2 Preserve nested generated blocks and unrecognised content (deps: 6.1, est: ~30m, mutex: setup-script)
  - why: the region here contains the `commands-table` markers at `:137` plus the Code Context rules and the slash-command table, none of which the script authored.
  - acceptance: R-6.4, R-6.5.
  - verify: a fixture containing a nested `BEGIN GENERATED` block and custom prose retains both, markers included; a region predating the inner markers gains them without losing unrecognised content.

## Unit 7: Verification

- [ ] 7.1 Write the test file and register it (deps: 5.2, est: ~60m)
  - why: the template coupling fires only on the first-time path, so a suite exercising only configured projects reports green while every new project is broken.
  - acceptance: R-7.1 through R-7.12.
  - verify: `scripts/tests/setup-noninteractive.test.sh` exists and appears in the `TESTS=()` array in `run-all.sh`, which does not glob. `HOME` is stubbed to a temp dir with a fake `.claude/plugins`, or tool detection aborts the run. Values are read via `uncle-dev-config.sh` and compared with `cmp` — never grepped from the YAML, since the boundary guard scans `scripts/`, which contains `scripts/tests/`.

- [ ] 7.2 Cover Units 2, 4, and 6 (deps: 7.1, est: ~45m)
  - why: `R-x.y` coverage here is a manual check with no scanner, so a gap in these three units would never surface on its own.
  - acceptance: R-7.13, R-7.14, R-7.15.
  - verify: the execution-branch rule text is asserted identical across the three files; all three `agent_skills_root` resolution paths plus the preserve case are asserted; an `--update` run preserves a nested generated block, custom prose, and file position.

- [ ] 7.3 Sweep for surviving old paths and run the full suite (deps: 7.2, est: ~20m)
  - why: the rename's failure mode is a reference nobody looked at, and the repo copy is currently md5-identical to the installed 1.4.1 cache, so a cache-resolved invocation proves nothing.
  - acceptance: R-7.16.
  - verify: no `skills/uncle-dev-setup/` outside the historical locations; `bash scripts/tests/run-all.sh` green including `check-manifest.sh`; end-to-end first-time setup invoked by explicit repository path per R-7.11; `uncle-dev-configure` opens against the renamed template.
