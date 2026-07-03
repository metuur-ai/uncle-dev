# 03 — Eliminate the plugins/uncle-dev/commands/ content fork (P0)

## Problem

`plugins/uncle-dev/commands/` is a stale content fork of the canonical
`commands/` directory, and the CI drift guard cannot see it.

### Finding A — 7 command files content-diverged

Verified with `diff -rq commands/ plugins/uncle-dev/commands/`:

| File | Canonical | Plugin copy |
|------|-----------|-------------|
| uncle-dev-build.md | 6.9K (Step-0 config resolution, per-mode paths, locks) | 2.1K (old) |
| uncle-dev-plan.md | current | stale |
| uncle-dev-spec.md | current | stale |
| uncle-dev-test.md | current | stale |
| uncle-dev-review.md | current | stale |
| uncle-dev-ship.md | current | stale |
| uncle-dev-code-simplify.md | current | stale |

Canonical copies gained the Step-0 config-resolution bash blocks and
`uncle-dev-load-skill.sh` integration at commit `f8ed690`; plugin copies were
last synced at `a8c6754`. The stale copies also lost the
`uncle-dev-load-skill.sh` reference entirely.

### Finding B — the drift guard compares names only

`scripts/check-manifest.sh:154-160,220` compares **filename sets**
(`compare_sets` on basenames). Content drift passes green forever. R-1.4 as
written checks the "command file set", not bytes.

### Finding C — the fork ships to users

`scripts/install-hermes.sh:24` copies `plugins/uncle-dev/` — Codex/Hermes
users get 7 outdated core workflow commands (no mode detection, no loader).

## Change instructions

Pick ONE strategy (recommendation: **Generate**, keeps one source of truth):

### Strategy 1 — Generate (recommended)

1. Add `scripts/sync-plugin.sh` that regenerates `plugins/uncle-dev/commands/`
   (and any other mirrored assets) from canonical `commands/` — a plain copy,
   or copy+transform if the plugin variant legitimately differs (if so, the
   transform IS the documentation of the difference).
2. Run it now to sync the 7 stale files.
3. Extend `scripts/check-manifest.sh` to compare **content hashes**
   (`sha256sum`) between `commands/*.md` and
   `plugins/uncle-dev/commands/*.md`, failing with a "run
   scripts/sync-plugin.sh" message on mismatch.
4. Wire the hash check into `scripts/tests/run-all.sh` (it already runs
   check-manifest as the drift guard).

### Strategy 2 — Delete the fork

1. Remove `plugins/uncle-dev/commands/` and point
   `install-hermes.sh`/`install-codex.sh` at canonical `commands/` directly.
2. Keep `plugins/uncle-dev/.codex-plugin/plugin.json` and other
   plugin-specific metadata in place.
3. Add a check-manifest rule asserting the directory does not reappear.

Either way:

5. **Sequencing:** land audit files 05 (centralized mode detection) and 04
   (loader fixes) first or together, so the regenerated plugin copies inherit
   the fixed sources rather than freezing today's bugs.

## Expected result after

- `diff -rq commands/ plugins/uncle-dev/commands/` → no differences (or the
  directory no longer exists under Strategy 2).
- Editing a canonical command without syncing turns
  `bash scripts/check-manifest.sh` red with an actionable message.
- Codex/Hermes installs receive the same workflow commands (Step-0 mode
  detection, skill loader) as Claude Code installs.

## Verification

```bash
diff -rq commands/ plugins/uncle-dev/commands/            # expect: empty (Strategy 1)
bash scripts/check-manifest.sh                            # green
sed -i '' 's/incrementally/incrementally!/' commands/uncle-dev-build.md
bash scripts/check-manifest.sh                            # expect: FAIL naming uncle-dev-build.md
git checkout commands/uncle-dev-build.md
bash scripts/tests/run-all.sh                             # all green
```
