# 08 — Correct plugin-cache paths and the setup install check (P0)

## Problem

The real Claude Code plugin cache layout is:

```
~/.claude/plugins/cache/<marketplace-id>/<plugin-name>/<version>/
= ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/1.4.1/
```

(confirmed on disk; derivation in `scripts/install-claude.sh:32`;
`.claude-plugin/plugin.json` has `name: "uncle-dev"`, the marketplace is
`uncle-dev-agent-skills`). Six places hardcode a nonexistent layout
`…/uncle-dev-agent-skills/uncle-dev-agent-skills/…`, and the setup command's
install check uses a plugin key that can never match.

### Finding A — wrong cache paths (fallbacks that never resolve)

- `commands/uncle-dev-debt.md:13`
- `commands/uncle-dev-spec-scan.md:11`
- `commands/uncle-dev-overkill-detector.md:64` (also missing the version
  segment)
- `commands/uncle-dev-openspec-sync.md:38` (version glob, wrong plugin dir)
- `commands/uncle-dev-setup.md:15` (wrong dir name AND hardcoded version
  `1.4.1` — breaks on every version bump)
- `hooks/spec-coherence-guard.sh` scanner fallback (same wrong layout; the
  spec-scan fallback in `commands/uncle-dev-spec-scan.md` matches)

Where `${CLAUDE_PLUGIN_ROOT}` is first in the chain, the bug is mitigated;
`setup.md` has no such mitigation — its only other fallback is a hardcoded
personal path (Finding C).

### Finding B — install check can never pass

`commands/uncle-dev-setup.md:45-46`:

```bash
jq '.plugins | has("uncle-dev-agent-skills@uncle-dev-agent-skills")'
```

The actual installed key is `uncle-dev@uncle-dev-agent-skills`
(`<plugin-name>@<marketplace-id>`). The check always returns false → setup
always instructs reinstall + restart, even on healthy installs.

### Finding C — personal path in a distributed plugin

`commands/uncle-dev-setup.md:17` — fallback search list hardcodes
`~/others/ai-agents/production-grade-agent-skills` (the author's personal
checkout) in a publicly distributed plugin.

### Finding D — no frontmatter on setup.md

`commands/uncle-dev-setup.md:1` — the only command (of 29) with no YAML
frontmatter; no `description` → no /help text.

### Finding E — nondeterministic `find` fallback

Several commands use
`find ~/.claude/plugins -name uncle-dev-config.sh | head -1`, which can pick
a **stale versioned cache copy** nondeterministically when multiple versions
are cached (also noted in audit file 04).

## Change instructions

1. **Define one canonical resolution snippet** (documented in
   `scripts/README.md`), in priority order:
   1. `${CLAUDE_PLUGIN_ROOT}` (set by Claude Code for plugin content)
   2. Repo-local `./scripts/…` (running inside a checkout)
   3. Newest cache version:
      `ls -1d ~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/*/ 2>/dev/null | sort -V | tail -1`
      No personal paths, no hardcoded versions, no `uncle-dev-agent-skills`
      doubled segment.
2. **Apply it** to the 5 command files and
   `hooks/spec-coherence-guard.sh` listed in Finding A; replace `head -1`
   find fallbacks with the sort -V form (Finding E).
3. **Fix the install check** (`uncle-dev-setup.md:45-46`): key is
   `uncle-dev@uncle-dev-agent-skills`. Consider also accepting any key
   matching `^uncle-dev@` to survive a marketplace rename:
   `jq '.plugins | keys[]' | grep -q '^"uncle-dev@'`.
4. **Remove the personal path** (`uncle-dev-setup.md:17`); the canonical
   snippet's three tiers cover all legitimate cases.
5. **Add frontmatter** to `commands/uncle-dev-setup.md` (`description:
"Wire uncle-dev into this project — plugin check, scaffolding, config,
hooks"`).
6. **Guard against recurrence**: add a check to `scripts/check-manifest.sh`:
   `grep -rn 'uncle-dev-agent-skills/uncle-dev-agent-skills' commands/ hooks/ skills/`
   must return empty, and
   `grep -rn 'cache/.*/1\.[0-9]' commands/ hooks/` (no hardcoded versions)
   must return empty.
7. **Regenerate the plugin fork** (audit file 03) after edits.

## Expected result after

- On an installed plugin without `CLAUDE_PLUGIN_ROOT` (e.g. a hook running in
  an odd context), fallbacks resolve to the real newest cache dir instead of
  a path that has never existed.
- `/uncle-dev-setup` correctly detects an existing healthy install instead of
  always demanding a reinstall; setup works on machines that are not yours.
- Version bumps don't silently break setup.md.
- check-manifest turns red if the broken layout string ever reappears.

## Verification

```bash
grep -rn 'uncle-dev-agent-skills/uncle-dev-agent-skills' commands/ hooks/ skills/ scripts/  # expect: none
grep -rn 'others/ai-agents' commands/                                                        # expect: none
grep -rn '1\.4\.0' commands/                                                                 # expect: none
head -5 commands/uncle-dev-setup.md                                                          # expect: YAML frontmatter with description
jq '.plugins | keys' ~/.claude/plugins/installed_plugins.json 2>/dev/null                    # confirm real key format used in the check
bash scripts/check-manifest.sh                                                               # green, incl. new greps
```
