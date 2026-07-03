# 09 — Installer safety and drift (P1)

## Problem

One uninstaller can delete checked-in plugin source, one installer overwrites
without any guard, one duplicates the shared library with a hardcoded
version, and the umbrella dispatcher can't reach several installers.

### Finding A — `uninstall-hermes.sh` missing the repo-root delete guard (highest risk)

`scripts/uninstall-hermes.sh:98` runs `rm -rf "${PLUGIN_DEST}"` behind only a
y/N confirm — **no `WORKSPACE != REPO_ROOT` guard**. Run from this repo as
`uninstall-hermes.sh --scope local .`, a single "y" deletes the checked-in
`plugins/uncle-dev/`. Every installer has the guard
(`install-hermes.sh:200`, `install-codex.sh:203`, `install-opencode.sh:91`,
`install-plugin.sh:463`); the one script that deletes is the only one
missing it.

### Finding B — `install-antigravity.sh` has no overwrite protection

`scripts/install-antigravity.sh:21` — bare `cp -r` with no `--force` flag, no
cmp-skip, no confirmation (every other installer refuses to overwrite without
`--force`). Also:

- its success message promises "commands like /uncle-dev-spec" while it
  installs **skills only**
- destination `~/.gemini/antigravity/skills` is hardcoded

### Finding C — `install-hermes.sh` drift

- Line 8: `PLUGIN_VERSION="1.4.0"` hardcoded (matches plugin.json today;
  silently drifts on the next bump — `install-claude.sh:27` derives the
  version from the manifest precisely to avoid this).
- Lines 47-75: duplicates `copy_file`/`copy_dir_contents` instead of sourcing
  `scripts/lib/install-common.sh`.

### Finding D — `install.sh` dispatcher incomplete

`scripts/install.sh` only knows `claude|codex|opencode`. hermes, antigravity,
and the `install-plugin.sh` targets (copilot/cline/kiro/pi/cursor/gemini/
windsurf/getting-started) are unreachable from the umbrella entry point, and
its `verify` mode doesn't exercise them.

## Change instructions

1. **Add the repo-root guard to `uninstall-hermes.sh`** before line 98 —
   copy the exact guard pattern from `install-hermes.sh:200`
   (refuse when the resolved destination is inside the plugin repo checkout,
   or equals the tracked `plugins/uncle-dev/`).
2. **Bring `install-antigravity.sh` up to the house pattern**: source
   `lib/install-common.sh`, use its guarded copy helpers, add `--force`
   semantics consistent with the other installers, fix the success message
   ("skills installed; commands are not supported on this target"), and
   accept a `--dest` override for the hardcoded path.
3. **Fix `install-hermes.sh`**: derive `PLUGIN_VERSION` from
   `.claude-plugin/plugin.json` (same jq as `install-claude.sh:27`); delete
   the duplicated `copy_file`/`copy_dir_contents` and source
   `lib/install-common.sh`.
4. **Complete the dispatcher**: add `hermes` and `antigravity` cases to
   `scripts/install.sh` and route the adapter targets through
   `install-plugin.sh`; extend `verify` to cover them (or print which targets
   verify does not cover).
5. **Extend tests**: `scripts/tests/` already sandboxes installers into fake
   HOMEs — add a case asserting `uninstall-hermes.sh` **refuses** when the
   destination resolves inside a git checkout of the plugin repo, and an
   antigravity install/overwrite-refusal case.

## Expected result after

- It is impossible to delete the tracked `plugins/uncle-dev/` via the
  uninstaller — it refuses with a clear message.
- Re-running the antigravity installer never clobbers user modifications
  without `--force`, and its output no longer promises commands it didn't
  install.
- A version bump in plugin.json propagates to hermes installs with zero
  manual edits.
- `bash scripts/install.sh <any documented target>` works for every target
  the README mentions.

## Verification

```bash
# guard present
grep -n 'REPO_ROOT\|repo.*guard\|refus' scripts/uninstall-hermes.sh    # expect: guard before the rm -rf
# refusal live test (from repo root)
bash scripts/uninstall-hermes.sh --scope local . <<< "y"; echo $?      # expect: refusal, non-destructive
ls plugins/uncle-dev/ | head -1                                        # still present
# version derivation
grep -n 'PLUGIN_VERSION=' scripts/install-hermes.sh                    # expect: jq from plugin.json, no literal
# no duplicated lib
grep -n 'copy_dir_contents()' scripts/install-hermes.sh                # expect: none (sourced from lib)
bash scripts/tests/run-all.sh                                          # all green incl. new cases
```
