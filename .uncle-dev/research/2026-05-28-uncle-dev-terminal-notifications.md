---
date: 2026-05-28T20:24:16-05:00
git_commit: ce3f9740aab9cbf79341b1aabf4cc53f2e86fff0
branch: loca-dev
repository: production-grade-agent-skills
topic: "how uncle dev can trigger terminal notification when need a action from the user?"
tags: [research, hooks, notifications, claude-code, gates]
status: complete
---

# Research: Triggering Terminal Notifications from uncle-dev When User Action Is Required

**Date**: 2026-05-28
**Git Commit**: ce3f9740aab9cbf79341b1aabf4cc53f2e86fff0
**Branch**: loca-dev

## Research Question

How can uncle-dev trigger a terminal notification when it needs an action from the user?

## Summary

Claude Code (the harness uncle-dev runs inside) exposes two independent notification surfaces:

1. **Built-in `preferredNotifChannel` setting** (top-level `settings.json` key) — emits a terminal bell or desktop notification via supported terminals (iTerm2, Ghostty, Kitty). No script needed.
2. **`Stop` and `Notification` hook events** — fire when Claude is idle awaiting input or on system-level events. A hook command (shell, MCP tool, HTTP, agent, or prompt) can dispatch a custom notification (`osascript`, `notify-send`, `terminal-notifier`, `printf '\a'`).

The uncle-dev plugin currently ships **seven hooks** in `hooks/hooks.json` covering `SessionStart`, `PreToolUse` (Edit|Write|Bash), and `PostToolUse` (Bash). **None of them use the `Stop` or `Notification` events**, so no notification fires today when uncle-dev hits a HARD GATE and stops to wait for the user. The plugin auto-installs its hooks via `.claude-plugin/hooks.json` (no project-level wiring required), and `setup-project.sh:216-229` actively *strips* `${CLAUDE_PLUGIN_ROOT}` hook entries from any project's `.claude/settings.json`.

There are **8 wait points** across the uncle-dev skill set where the assistant explicitly stops for user input. Any of them would benefit from a notification, but the spec-lock and plan-review gates are the highest-value targets because they sit at the front of the workflow where the user is most likely to context-switch away while the assistant is generating.

## Detailed Findings

### Component 1 — Claude Code notification surfaces

**Built-in setting (no hook required):**
- `~/.claude/settings.json` top-level key `preferredNotifChannel`
- Values: `auto` (default — desktop notif in iTerm2/Ghostty/Kitty, silent elsewhere), `terminal_bell` (universal BEL), `iterm2`, `iterm2_with_bell`, `kitty`, `ghostty`, `notifications_disabled`
- Source: https://code.claude.com/docs/en/settings.md
- This is the lowest-friction option for the user — single key, works without scripts.

**Hook events relevant to "waiting":**
- `Stop` — fires when Claude finishes responding and is idle. Non-blocking. Fires exactly once per turn. Best proxy for "I am waiting for the user" because Claude Code has no event that specifically marks "this is a HARD GATE turn".
- `Notification` — fires on system events (e.g., permission prompts, auth success). Matchers like `permission_prompt`, `auth_success`.
- `UserPromptSubmit` — fires before Claude processes a user prompt. Useful for "user replied" acknowledgement.
- Source: https://code.claude.com/docs/en/hooks.md, https://code.claude.com/docs/en/hooks-guide.md

**Hook command shape (settings.json):**
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/notify-idle.sh",
            "async": true,
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Cross-platform notify script patterns:**
- macOS desktop: `osascript -e 'display notification "..." with title "Claude Code"'`
- macOS with sound: `terminal-notifier -title "Claude Code" -message "..." -sound "Glass"`
- Linux desktop: `notify-send "Claude Code" "..." --urgency=normal`
- Universal bell: `printf '\a'` or `tput bel`

### Component 2 — Existing uncle-dev hook layout

**Registered in `hooks/hooks.json`:**

| Event | Matcher | Scripts |
|---|---|---|
| `SessionStart` | (none) | `session-start.sh` |
| `PreToolUse` | `Edit\|Write` | `check-agents-md.sh` → `openspec-guard.sh` → `spec-coherence-guard.sh` |
| `PreToolUse` | `Bash` | `pre-commit-guard.sh` → `destructive-command-guard.sh` → `spec-coherence-guard.sh` |
| `PostToolUse` | `Bash` | `knowledge-capture-nudge.sh` |

(Source: `hooks/hooks.json:1-61`)

**Per-script behavior (no notification side-effects in any of them):**
- `session-start.sh:1-47` — injects uncle-dev meta-skill into the session as a JSON message
- `check-agents-md.sh:1-23` — reminds about sibling `AGENTS.md` before edits
- `openspec-guard.sh:1-40+` — validates openspec change ID + artifacts
- `spec-coherence-guard.sh:1-40+` — validates `@spec` IDs against `docs/specs/`
- `pre-commit-guard.sh:1-40+` — validates commit messages, blocks debug artifacts
- `destructive-command-guard.sh:1-80+` — allowlist for safe commands, blocks `rm`, hard resets, DROP TABLE, etc.
- `knowledge-capture-nudge.sh:1-47` — nudges `/uncle-dev-knowledge-capture` after successful test/build runs (60-min cooldown)

**Installation path:**
- `scripts/install-claude.sh:114-115` — copies `hooks/` into the plugin cache
- `scripts/install-claude.sh:131` — copies `hooks/hooks.json` to `${CACHE_PATH}/.claude-plugin/hooks.json` for auto-discovery
- `scripts/setup-project.sh:202-206` — comment: "Plugin hooks…are defined in the plugin's own hooks/hooks.json and fire automatically when the plugin is installed."
- `scripts/setup-project.sh:216-229` — actively *removes* any pre-existing `${CLAUDE_PLUGIN_ROOT}` hooks from a project's `.claude/settings.json`

**Notification-event status: not used.** No hook currently wires `Stop` or `Notification`.

### Component 3 — uncle-dev wait points (where a notification would fire)

| Phase | Skill/Command | file:line | Tag | What the assistant asks |
|---|---|---|---|---|
| Define | `uncle-dev-spec` (lid-ears) | `.claude/commands/uncle-dev-spec.md:145` | `spec-lock` | "Do these specs look correct? Reply YES to lock them, or tell me what to change." |
| Define | `uncle-dev-spec` (openspec) | `.claude/commands/uncle-dev-spec.md:184` | `spec-validate` | Confirmation after `openspec validate <id>` |
| Define | `uncle-dev-knowledge-capture` | `.claude/commands/uncle-dev-knowledge-capture.md:16` | `mode-select` | Full vs Lightweight mode + session-history search choice |
| Plan | `uncle-dev-plan` (lid-ears) | `.claude/commands/uncle-dev-plan.md:78` | `plan-review` | "Present the plan for human review" |
| Plan | `uncle-dev-plan` (openspec) | `.claude/commands/uncle-dev-plan.md:106` | `plan-review` | "Present the plan for human review" |
| Build | `uncle-dev-next-task` | `.claude/commands/uncle-dev-next-task.md:120` | `ack-gate` | Halt with `BLOCKED:` block on pending acknowledgements |
| Build | `uncle-dev-build` | `.claude/commands/uncle-dev-build.md:98` | `ack-gate-enforcement` | Print `BLOCKED:` verbatim, do not proceed |
| Ship | `uncle-dev-ship` | `.claude/commands/uncle-dev-ship.md:62`, `:91` | `rollback-confirm` | "Define the rollback plan before proceeding" |
| Research | `uncle-dev-research` | `skills/uncle-dev-research/SKILL.md:18` | `research-question` | "I'm ready to research the codebase. What would you like me to investigate?" |

All wait points use the "wait silently" instruction pattern — once the question is asked, the assistant does not re-prompt. There is currently no mechanism (built-in or hook-based) that signals the user that the assistant is parked at one of these gates.

## Code References

- `hooks/hooks.json:1-61` — full hook registration table
- `hooks/session-start.sh:1-47` — SessionStart injector
- `hooks/knowledge-capture-nudge.sh:1-47` — PostToolUse nudge with cooldown
- `scripts/install-claude.sh:114-131` — how `hooks.json` reaches the plugin auto-discovery path
- `scripts/setup-project.sh:202-232` — explicit policy of not wiring plugin hooks into project settings
- `.claude/commands/uncle-dev-spec.md:144-147` — canonical HARD GATE wording: `Do these specs look correct? Reply YES…`
- `.claude/commands/uncle-dev-plan.md:78`, `.claude/commands/uncle-dev-plan.md:106` — plan review gates (both modes)
- `.claude/commands/uncle-dev-build.md:98` — non-bypassable `BLOCKED:` ack gate
- `.claude/commands/uncle-dev-ship.md:62`, `.claude/commands/uncle-dev-ship.md:91` — rollback confirmation gates

## Architecture Documentation

**Two layers exist independently:**

1. **Harness layer (Claude Code)** — owns `preferredNotifChannel` and the `Stop`/`Notification`/`UserPromptSubmit` event surface. This is the only layer that knows when the assistant is idle.

2. **Plugin layer (uncle-dev)** — owns the workflow skills/commands. Each gate is enforced by the assistant text ("STOP. Wait silently.") rather than by a tool boundary. The assistant itself decides to stop generating; from Claude Code's perspective this is indistinguishable from any other turn end.

Consequence: notifications must be implemented at the harness layer (via setting or hook), because the plugin has no API to emit a notification mid-turn. A `Stop` hook fires for *every* turn end, not only HARD-GATE turns — there is no event payload field that distinguishes "waiting on a hard gate" from "just finished talking".

**Auto-install path for hooks** is `${CACHE_PATH}/.claude-plugin/hooks.json` (via `install-claude.sh:131`), not the user's `~/.claude/settings.json`. Adding a `Stop` hook to the plugin would affect every project that has the plugin installed, not just one.

## Historical Context

`.uncle-dev/learns/` is empty (`ls .uncle-dev/learns/` returned no files). No prior captured knowledge on notification design exists.

`.uncle-dev/research/` contains two prior research documents (`2026-05-17-companion-modes-extended-exploration.md`, `2026-05-17-uncle-domain-companion-exploration.md`), neither of which covers notifications based on filename and topic.

## Open Questions

- Whether the `Notification` hook event has a matcher that fires specifically when the assistant is awaiting user input (vs. system permission prompts). The claude-code-guide scout described it as a "system event" channel — actual matcher list beyond `permission_prompt`/`auth_success` was not enumerated.
- Whether `Stop` hook payload carries any field (e.g., `last_assistant_message`) that a script could regex for "Reply YES to lock" to fire notifications *only* at HARD GATEs, instead of on every turn end.
- Whether the plugin auto-install path supports an opt-in flag, so notification hooks could be off by default and enabled per-project.
