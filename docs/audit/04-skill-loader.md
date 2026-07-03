# 04 — Fix the skill loader: validation, namespace, dead skill name (P0)

## Problem

`scripts/uncle-dev-load-skill.sh` is fail-open with no validation, emits the
wrong plugin namespace, and one command loads a skill that doesn't exist —
silently.

### Finding A — `/uncle-dev-code-simplify` loads a nonexistent skill

`commands/uncle-dev-code-simplify.md:19`:

```bash
bash "$_loader" uncle-dev-code-simplification
```

The actual skill directory is `skills/uncle-dev-dev-code-simplification/`
(double "dev"). `skills/uncle-dev-code-simplification` does not exist. The
loader emits `SKILL: agent-skills:uncle-dev-code-simplification` and exits 0
— the command runs without its skill and nobody notices.

### Finding B — loader never validates the base skill exists

`scripts/uncle-dev-load-skill.sh` resolves overrides/companions via
`uncle-dev-config.sh` (correct) but never checks that the base skill name
maps to a real `skills/<name>/` directory in the plugin. Fail-open is
reasonable for missing *config*; it is what let Finding A ship undetected.

### Finding C — wrong namespace in emitted skill refs

`scripts/uncle-dev-load-skill.sh:63,70` emits `SKILL: agent-skills:<base>`,
and `commands/uncle-dev-next-task.md:33` says "the
agent-skills:uncle-dev-next-task skill" — but the plugin is named
`uncle-dev` (`.claude-plugin/plugin.json`), so installed skills resolve as
`uncle-dev:<name>`. The `agent-skills:` namespace doesn't exist.

### Finding D — the "skill-loading directive" the commands rely on is not installed

Every command says to honor `SKILL:` lines "per the skill-loading directive
in your project CLAUDE.md" — but that directive only exists inside the setup
skill's template (`skills/uncle-dev-setup/SKILL.md:353-355`).
`scripts/setup-project.sh:328-351` injects a CLAUDE.md block **without** the
Skill loading section, and this repo's own CLAUDE.md lacks it too.

### Finding E — loader boilerplate duplicated with three fallback conventions

The 2-line `_loader=` resolution is copy-pasted ~24× across commands with
three different script-location fallback conventions
(CLAUDE_PLUGIN_ROOT→find; cache-literal→repo-clone; version-glob). The
`find ~/.claude/plugins -name uncle-dev-config.sh | head -1` variant can pick
a **stale versioned cache copy nondeterministically**. (Cache-path literals
themselves are covered in audit file 08.)

## Change instructions

1. **Fix the typo**: `commands/uncle-dev-code-simplify.md:19` →
   `uncle-dev-dev-code-simplification`. (Longer term, consider renaming the
   skill dir to `uncle-dev-code-simplification` — but that touches
   marketplace.json, CLAUDE.md lists, and installers; do it separately if at
   all.)
2. **Add base-skill validation** to `uncle-dev-load-skill.sh`: resolve the
   plugin root (CLAUDE_PLUGIN_ROOT or script's own dir/..), check
   `[[ -d "$plugin_root/skills/$base" ]]`; on failure print
   `ERROR: unknown skill '<base>'` to stderr and exit 1 (fail-closed for
   unknown names; stay fail-open only for missing config/overrides).
3. **Fix the namespace**: emit `SKILL: uncle-dev:<base>` at lines 63,70 (and
   the fallback at the bottom). Update `commands/uncle-dev-next-task.md:33`
   and any other `agent-skills:` prose references
   (`grep -rn 'agent-skills:' commands/ skills/ scripts/`).
4. **Install the directive**: add the Skill-loading directive block to the
   CLAUDE.md snippet that `setup-project.sh:328-351` injects (copy from
   `skills/uncle-dev-setup/SKILL.md:353-355`), and add it to this repo's own
   CLAUDE.md uncle-dev section.
5. **Deduplicate loader resolution**: pick the CLAUDE_PLUGIN_ROOT-first
   convention as canonical; where a `find` fallback is needed, sort version
   dirs and take the newest (`ls -1 …/uncle-dev/ | sort -V | tail -1`)
   instead of `head -1` over unordered find output. Update all ~24 sites (a
   scripted sed is fine since the block is verbatim-identical); regenerate
   the plugin fork afterwards (audit file 03).
6. **Add a test** in `scripts/tests/`: loader with a known-good name exits 0
   and emits `SKILL: uncle-dev:<name>`; with a bogus name exits non-zero.
   Also add a repo-lint loop: every `bash "$_loader" <name>` argument in
   `commands/` must have a matching `skills/<name>/` dir (this would have
   caught Finding A).

## Expected result after

- `/uncle-dev-code-simplify` actually loads the code-simplification skill.
- A future typo in any command's loader call fails loudly (loader stderr +
  the new test), instead of silently degrading.
- Emitted `SKILL:` refs resolve in installed plugins
  (`uncle-dev:<name>`).
- Projects set up by `setup-project.sh` contain the directive that gives
  `SKILL:` lines meaning.

## Verification

```bash
bash scripts/uncle-dev-load-skill.sh uncle-dev-dev-code-simplification; echo $?   # 0, SKILL: uncle-dev:...
bash scripts/uncle-dev-load-skill.sh not-a-skill; echo $?                          # non-zero, ERROR on stderr
grep -rn 'agent-skills:' commands/ scripts/ skills/                               # expect: no matches
# every loader arg has a skill dir
grep -rhoE 'uncle-dev-load-skill\.sh"? ([a-z-]+)' commands/ | awk '{print $NF}' \
  | sort -u | while read s; do [ -d "skills/$s" ] || echo "MISSING: $s"; done      # expect: no output
bash scripts/tests/run-all.sh                                                      # all green
```
