# 02 — Fix setup-project.sh config writes and the config boundary (P0)

## Problem

`scripts/setup-project.sh` has two confirmed logic bugs, both rooted in the
two-line `sdd_mode:` form in the template, and it reads the config YAML
directly in violation of the project's own single-reader boundary rule.

### Finding A — sdd_mode is never written (sed cannot match)

`skills/uncle-dev-setup/uncle-dev-setup.template.yaml:89-90` splits key and
value across two lines:

```yaml
  sdd_mode:
    "lid-ears" # ...
```

`scripts/setup-project.sh:226` runs a sed that replaces the single-line form
`sdd_mode: "lid-ears"` — verified by simulation: **output unchanged**.

Consequence: a user who answers `openspec` gets a config that still says
`lid-ears`, while the script (using its in-memory `SDD_MODE=openspec`)
creates `openspec/` dirs and writes the openspec CLAUDE.md block. Config and
scaffolding permanently disagree; every downstream
`uncle-dev-config.sh preferences.sdd_mode` read returns the wrong mode.

### Finding B — re-run reads sdd_mode as empty string → pollutes lid-ears projects

`scripts/setup-project.sh:182`:

```bash
grep 'sdd_mode:' "${CONFIG_FILE}" | awk -F'"' '{print $2}'
```

matches the bare `  sdd_mode:` key line (value on next line) and yields
`SDD_MODE=""`. The `|| echo "lid-ears"` fallback only fires when grep
*fails*, not on empty output. Then `[[ "$SDD_MODE" == "lid-ears" ]]` at
line 197 is false, so a lid-ears project gets `openspec/specs` +
`openspec/changes` created — exactly the auto-detection pollution the comment
at lines 194-196 warns against — and the openspec CLAUDE.md block is written.

### Finding C — config boundary bypass

CLAUDE.md Boundaries: *"No script, command, hook, or helper may open
`.agents/uncle-dev-setup.yaml` directly"* — all reads must go through
`scripts/uncle-dev-config.sh`.

- `scripts/setup-project.sh:178-186` greps the YAML directly (`sdd_mode:`,
  `spec_annotations:`, `tdd-mode:`, `execution_profile:`, `graphify:`). The
  official audit guard
  (`grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' …`)
  misses it because the path is behind `${CONFIG_FILE}` and the verb is
  `grep`. This ad-hoc parsing is what produced Finding B — the exact failure
  mode the single-reader rule exists to prevent.
- `skills/uncle-dev-setup/SKILL.md:220,228` — prose instructs the agent to
  read the YAML directly ("read it first and preserve fields", "Read
  `.agents/uncle-dev-setup.yaml` `hooks.*` toggles").
- `hooks/wrap-nudge.sh:14` — dead `CONFIG_FILE` variable pointing at the YAML
  (handled in audit file 01, listed here for the boundary sweep).
- Note also `hooks/wrap-nudge.sh` calls the helper without `cd`-ing to
  `PROJECT_DIR` while the helper resolves `.agents/...` relative to cwd —
  wrong config is read if cwd differs from the project root.

### Finding D — config surface wider than its runtime (schema/usage drift)

- **6 of 7 `hooks.*` toggles are never read** (`hooks.session_start`,
  `hooks.pre_commit`, `hooks.spec_coherence`, `hooks.openspec_guard`,
  `hooks.destructive_command_guard`, `hooks.knowledge_capture_nudge`) — those
  hooks fire unconditionally from `hooks/hooks.json`. Only
  `hooks.wrap_nudge` is honored (`hooks/wrap-nudge.sh:26`). The template
  comment "Set to false to disable a specific guard" is false for 6 of 7.
- Schema-required keys with zero runtime readers: `preferences.level`,
  `preferences.sdd_required`, `preferences.spec_annotations`,
  `preferences.knowledge_capture`, `preferences.destructive_guard`,
  `openspec.change_id_format`, `openspec.required_artifacts`, `project.*`,
  `tool.*`, `version`.
- Hyphenated keys (`preferences.tdd-mode`, `preferences.mutation-testing`)
  work for YAML lookup but their derived env-override names contain `-` and
  are therefore **un-settable via the env tier** (silent limitation).
- `scripts/uncle-dev-config.sh:179-209`: if python3 / PyYAML / jsonschema is
  missing, validation fails and the helper **silently returns the default for
  every key** — the whole config layer evaporates with no warning. No
  `command -v python3` or import check exists.

## Change instructions

1. **Normalize the template** (`uncle-dev-setup.template.yaml:89-90`) to
   single-line `sdd_mode: "lid-ears"  # lid-ears | openspec`. Audit the rest
   of the template for other two-line scalars.
2. **Fix the write** (`setup-project.sh:226`): after normalizing, the sed
   matches; better, replace sed with a small `uncle-dev-config.sh --set
   preferences.sdd_mode <value>` mode added to the helper (writes stay inside
   the single owner). If adding `--set` is too large a step now, keep sed but
   add a post-write assertion:
   `[[ "$(bash scripts/uncle-dev-config.sh preferences.sdd_mode)" == "$SDD_MODE" ]] || die`.
3. **Fix the read** (`setup-project.sh:178-186`): replace all direct greps
   with `bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.sdd_mode` etc.
   Treat empty output as "use default" explicitly:
   `SDD_MODE="${SDD_MODE:-lid-ears}"`.
4. **Widen the audit guard** in CLAUDE.md Boundaries to also catch grep and
   variable-path access, e.g.:
   `grep -rn 'setup\.yaml' scripts/ hooks/ commands/ | grep -v uncle-dev-config.sh | grep -v '^\s*#'`
   (allow the template/schema files explicitly). Update the guard text.
5. **Fix the setup skill prose** (`skills/uncle-dev-setup/SKILL.md:220,228`):
   instruct reading via `uncle-dev-config.sh --list hooks` / scalar calls,
   never the YAML file.
6. **Make wrap-nudge cwd-safe**: pass the project dir to the helper or
   `cd "$PROJECT_DIR"` before calling it (coordinate with audit file 01).
7. **Close the schema/runtime gap** (choose per key):
   - Honor the six `hooks.*` toggles: at the top of each corresponding hook
     script add
     `[[ "$(uncle-dev-config.sh hooks.<name>)" == "false" ]] && exit 0`
     (same pattern as `wrap-nudge.sh:26`), **or** delete the toggles from the
     schema/template and the "set to false to disable" comment.
   - Delete (or mark optional + document as reserved) schema keys nobody
     reads.
   - Document that hyphenated keys have no env-override, or normalize key
     names to underscores in a schema migration.
8. **Guard the python dependency** in `uncle-dev-config.sh`: check
   `command -v python3` and `python3 -c 'import yaml'` once; on failure print
   a one-line warning to stderr (still return defaults, but never silently).

## Expected result after

- Fresh setup with `openspec` answer produces a config whose
  `preferences.sdd_mode` reads back `openspec`; scaffolding and config agree.
- Re-running setup on a lid-ears project does **not** create `openspec/`
  directories.
- The widened audit-guard grep returns empty (only the helper, template, and
  schema mention the YAML path).
- Setting `hooks.pre_commit: false` (etc.) in a project config actually
  disables that hook.
- On a machine without PyYAML, users see one clear stderr warning instead of
  silently losing all configuration.

## Verification

```bash
# fresh setup, openspec answer, in a temp dir
tmp=$(mktemp -d) && (cd "$tmp" && bash /path/to/scripts/setup-project.sh <<< "openspec")
bash scripts/uncle-dev-config.sh preferences.sdd_mode   # run in $tmp → "openspec"
# re-run idempotence on lid-ears project
ls "$tmp_lidears/openspec" 2>/dev/null                  # expect: No such file or directory
# boundary sweep
grep -rn 'setup\.yaml' scripts/ hooks/ commands/ | grep -v uncle-dev-config.sh   # expect: template/schema/docs only
bash scripts/tests/run-all.sh                           # all green
```
