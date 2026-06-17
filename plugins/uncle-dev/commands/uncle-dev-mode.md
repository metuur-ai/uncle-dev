---
description: Switch uncle-dev guard strictness for the current session — strict|balanced|fast — without editing .agents/uncle-dev-setup.yaml (Claude Code only)
---

Set the execution strictness for **this session only**. The spec-coherence and pre-commit guards read the chosen profile and adjust whether they block or merely warn — your project's `.agents/uncle-dev-setup.yaml` is never modified.

Usage:

```
/uncle-dev-mode <strict|balanced|fast>
```

The profiles:

- **strict** — guards block on unknown `@spec` IDs in edits and on commit-quality issues.
- **balanced** (the usual default) — block on commit-quality and `@spec` orphans at commit time; warn (don't block) on `@spec` edits.
- **fast** — advisory only; nothing blocks.

How it works:

- A `UserPromptSubmit` hook (`hooks/uncle-dev-mode.sh`) writes the chosen profile to a session flag file at `.uncle-dev/session-mode` (a single line: `strict`, `balanced`, or `fast`).
- `scripts/uncle-dev-config.sh` resolves `preferences.execution_profile` in tier order: `UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE` env var → **session flag** → YAML → default. So the flag overrides the YAML for the session, and an explicit env var still wins over the flag.
- The two guards (`spec-coherence-guard.sh`, `pre-commit-guard.sh`) already read the profile through that helper, so they honor the switch with no further action.

To clear the session mode and fall back to the YAML value, delete the flag:

```
rm .uncle-dev/session-mode
```

**Claude Code only.** The mode hook and the optional statusline badge are not installed for Codex or OpenCode (those hosts do not run uncle-dev hooks).

Optional statusline badge: `hooks/statusline-mode.sh` prints `[UNCLE-DEV:STRICT]` (etc.) from the flag, or nothing when unset. Append it to your existing `statusLine` command in `.claude/settings.json` if you want the active mode visible — it does not replace your statusline.
