---
name: uncle-dev-wrap
description: Compacts the current conversation into a handoff document so a fresh agent or session can continue the work without context loss. Writes the doc to `.devlocal/handoffs/handoff-<UTC-timestamp>.md` (gitignored personal scratchpad), references existing artifacts by path/URL instead of duplicating them, redacts sensitive data, and lists suggested skills for the next session to invoke. Use when the user says "wrap this up", "hand this off", "context is getting full", "summarize for the next session", or runs /uncle-dev-wrap.
---
## Overview

Conversations end. Context resets. The next agent or session needs a tight, accurate handoff to pick up where the last one left off — without re-reading the entire transcript, and without losing the live state in a developer's head. This skill writes one structured Markdown document under `.devlocal/handoffs/` that another agent can read in seconds and continue the work.

The handoff lives in the gitignored personal scratchpad (`.devlocal/`), not in shared project artifacts. It references durable artifacts (PRDs, plans, ADRs, OpenSpec changes, issues, commits, diffs) by path or URL rather than copying them.

## Core Process

### Step 1: Determine the output path

Write to the project's gitignored handoff directory:

```bash
HANDOFF_DIR=".devlocal/handoffs"
mkdir -p "$HANDOFF_DIR"
SLUG=$(date -u +%Y%m%d-%H%M%S)
HANDOFF_FILE="${HANDOFF_DIR}/handoff-${SLUG}.md"
echo "$HANDOFF_FILE"
```

- The path is relative to the project root — always run from the workspace root.
- Confirm `.devlocal/` is gitignored before writing (it is, project-wide, per `.gitignore`).
- Do not write to `$TMPDIR`/`/tmp` — those are wiped by the OS and invisible to teammates pulling the branch.
- Do not write to a shared/tracked directory — handoffs are personal scratchpad, not artifacts.

### Step 2: Read the next-session focus

- If the user passed arguments (`/uncle-dev-wrap <text>`), treat them verbatim as Next Session Focus. This shapes the entire doc — sections that don't serve that focus should be terse.
- If no arguments were passed, ask the user one blocking question: "What will the next session focus on?" Use the platform's blocking question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex, `ask_user` in Gemini).
- If the user declines to specify, default the focus to "Continue current work" and proceed.

### Step 3: Survey existing artifacts (DO NOT duplicate them)

Before drafting prose, list the durable artifacts that already exist. Reference these by path or URL. Never paste their content into the handoff.

Check, in order:

| Artifact | Where to look |
|---|---|
| OpenSpec change | `openspec/changes/<id>/{proposal,design,tasks,execution,handoff}.md` |
| LID-EARS specs | `docs/{hld,lld,ears}/`, `docs/decisions/ADR-*.md` |
| Plan / task list | `openspec/changes/<id>/tasks.md`, `docs/tasks/`, or the in-conversation TodoWrite/TaskList |
| Acknowledge notes | `openspec/acknowledge/<scope>.md` |
| Recent learnings | `.uncle-dev/learns/<category>/` |
| Git state | `git status`, `git log --oneline -10`, `git diff --stat`, current branch |
| Open PR / issue | `gh pr view`, `gh issue view` (only if the conversation referenced one) |

For each relevant artifact, record the path or URL — not the content.

### Step 4: Draft the handoff using the template

Use the template in Specific Techniques → Handoff Template. Fill only the sections that have real content. Empty sections should be removed, not left with placeholders.

Key rules:
- Tight bullets, not narrative paragraphs. The next agent skims this; it does not read it cover-to-cover.
- Reference, don't restate. "See `openspec/changes/auth-rework/design.md` § Token storage" beats pasting the design rationale.
- Pin the live state that isn't in any artifact: in-flight diffs not yet committed, failing test output, the exact command that was about to run, the hypothesis being tested, what was just ruled out.
- No commentary on the conversation itself. The handoff is for the next agent's work, not a session retrospective.

### Step 5: Redact sensitive data

Before writing the file, scan the draft for:

- API keys, tokens, secrets (anything matching `sk-`, `xoxb-`, `ghp_`, `AKIA`, `BEGIN PRIVATE KEY`, JWT-shaped strings, `Bearer <token>`, `Authorization:` headers, `password=`, `passwd=`)
- `.env`-style assignments: `<NAME>=<value>` where the name contains `SECRET`, `TOKEN`, `KEY`, `PASSWORD`, `PWD`, `CREDENTIAL`
- Database connection strings with embedded credentials (`postgres://user:pass@`, `mongodb+srv://user:pass@`)
- Personally identifiable information: full emails (other than the project's `git config user.email`), phone numbers, addresses, names tied to private contact info

Replace each match with `[REDACTED:<type>]`, e.g. `[REDACTED:api-key]`, `[REDACTED:db-password]`. If you redact anything, add a top-level note: `> Some values redacted — see original conversation for full context.`

If the user is in a CTF, security-research, or pentest authorization context that the conversation makes clear, you may keep test credentials verbatim. When in doubt, redact.

### Step 6: Pick suggested skills for the next session

Pick 2–6 skills from the agent-skills catalog that the next session should invoke first. Be specific — list both the skill name and why it applies to the focus from Step 2.

Common picks by focus:

| Focus | Suggested skills |
|---|---|
| Continue implementation | `uncle-dev-next-task`, `uncle-dev-incremental-implementation`, `uncle-dev-test-driven-development` |
| Resume debugging | `uncle-dev-debug-error`, `uncle-dev-browser-testing-with-devtools` |
| Resume spec work | `uncle-dev-spec-driven-development`, `uncle-dev-planning-and-task-breakdown` |
| Resume review | `uncle-dev-code-review-and-quality`, `uncle-dev-security-and-hardening` |
| Ship / deploy | `uncle-dev-shipping-and-launch`, `uncle-dev-ci-cd-and-automation` |
| Capture what just worked | `uncle-dev-knowledge-capture` |

Do not invent skill names. Only list skills that exist under `skills/` in this repo (or known platform skills like `graphify`, `openspec`).

### Step 7: Write the file and report (with next-session bootstrap)

1. Write the final Markdown to `$HANDOFF_FILE` (Step 1 path) using the Write tool.
2. Print to the user, in this order:
   - The relative path to the handoff doc (e.g. `.devlocal/handoffs/handoff-20260528-223300.md`)
   - A one-line summary of the Next Session Focus
   - The list of suggested skills as a single line: `Suggested: skill-a, skill-b, skill-c`
   - Any redaction notice from Step 5
   - A copy-paste bootstrap line for the next session, exactly:
     ```
     Next session, paste this:
     Read .devlocal/handoffs/handoff-<UTC-timestamp>.md and resume from "Next Session Focus".
     ```

Do not print the full handoff body back to the user — the file is the artifact, not the chat.

### How the next session picks up the handoff

There are three ways the next session finds and loads the handoff:

1. Automatic via SessionStart hook (ships with the agent-skills plugin). The plugin's `hooks/session-start.sh` already scans `.devlocal/handoffs/`, picks the newest `handoff-*.md` by mtime, and injects two lines into the session-start system message:
   ```
   Recent handoff from /uncle-dev-wrap: .devlocal/handoffs/handoff-<ts>.md
   To resume, run: Read .devlocal/handoffs/handoff-<ts>.md and continue from "Next Session Focus".
   ```
   Any user with the plugin installed gets this for free — no `settings.json` editing required. The agent loads the file on demand via `Read`; the body is never pasted into the session prompt.
2. Manual bootstrap (always works, no plugin needed). User pastes the bootstrap line printed in Step 7 above. The new agent runs `Read .devlocal/handoffs/handoff-<ts>.md` and follows the Next Session Focus.
3. Latest-handoff shortcut (no timestamp needed). User pastes: `Read the most recent file in .devlocal/handoffs/ and resume from "Next Session Focus".` The agent runs `ls -t .devlocal/handoffs/ | head -1` and reads it.

Note: even when option 1 is active, still print the Step 7 bootstrap line — it's the user-facing confirmation that the handoff was written, and it works across runtimes (Codex, Gemini) where the SessionStart hook isn't loaded.

## Specific Techniques

### Handoff Template

```markdown
# Session Handoff — <YYYY-MM-DD HH:MM UTC>

> Ephemeral handoff doc. Not checked into the repo. Reference artifacts by path/URL — do not duplicate them here.

## Next Session Focus
<one or two sentences — what the next agent should accomplish first>

## State of the World
- **Repo:** <project name and working directory>
- **Branch:** <current git branch>
- **Last commit:** <short sha> — <message>
- **Working tree:** <clean | dirty: N modified, M untracked> (run `git status` to see)
- **Open PR / issue:** <#number and URL, if any>

## What's Done (this session)
- <terse bullet — e.g. "Added auth middleware at src/server/auth.ts:42">
- <terse bullet>

## What's In Flight
- <thing that is half-done — file path, line range, what's incomplete>
- <uncommitted diff hunks of interest — reference `git diff` rather than paste>

## What's Next (concrete steps)
1. <next action, with file:line if applicable>
2. <next action>
3. <next action>

## Key Decisions Made (with rationale)
- <decision> — see `docs/decisions/ADR-NNN-*.md` or `openspec/acknowledge/<scope>.md` (do not paste content)

## Open Questions / Blockers
- <question the next session needs to answer or escalate>

## Relevant Artifacts (read these, don't re-derive)
- Spec/Design: <paths>
- Plan/Tasks: <paths>
- ADRs/Acknowledges: <paths>
- Recent learnings: <paths under `.uncle-dev/learns/`>
- External tickets: <URLs>

## Suggested Skills for Next Session
- `uncle-dev-<skill>` — <why this skill, tied to Next Session Focus>
- `uncle-dev-<skill>` — <why>

## Notes
<anything else the next agent must know that isn't in an artifact — e.g. "tests fail intermittently on CI, locally green", "the user prefers terse responses">
```

### Length budget

Aim for 60–200 lines total. If the draft exceeds 250 lines, you are restating artifacts instead of referencing them — go back to Step 3 and replace prose with paths.

### What belongs only in the handoff (not in artifacts)

- Hypotheses currently being tested
- Failed approaches just tried in this session (so the next agent doesn't repeat them)
- The exact command/test that was about to run
- The mental model the user holds right now ("the user thinks the bug is in middleware, but we haven't confirmed")
- Conversational preferences the user expressed this session ("don't refactor", "keep PRs small")

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll paste the full plan into the handoff so the next agent doesn't have to open it" | Duplication rots. The plan changes; the handoff doesn't. Reference the plan by path. |
| "I'll save the handoff outside the project so it doesn't pollute the repo" | `.devlocal/` is gitignored — handoffs there are local-only and invisible to teammates. Keeping them in-tree lets the next session bootstrap with a relative path. OS temp dirs get wiped between reboots and break across worktrees. |
| "I'll commit the handoff so my team can see what I was working on" | `.devlocal/` is in `.gitignore` for a reason — handoffs are personal scratchpad, not shared artifacts. Use ADRs, OpenSpec, or a PR description for team-visible state. |
| "Redacting takes too long, I'll skip it" | One leaked API key in a handoff that ends up in another agent's context (or a paste buffer) is a real incident. Redact. |
| "I don't need to ask about focus; the conversation makes it obvious" | Sessions often have two or three threads. One sentence of confirmation prevents writing the handoff for the wrong thread. |
| "Suggested skills are nice-to-have, I'll skip them" | Without them, the next session re-derives which workflow to use. With them, it starts working in seconds. |
| "The next agent can re-read the conversation" | The next agent often cannot — context was compacted, or it's a different runtime. Handoffs exist precisely because re-reading isn't an option. |

## Red Flags

- Handoff written anywhere other than `.devlocal/handoffs/` (e.g. `/tmp`, repo root, `docs/`, `openspec/`)
- Handoff committed to git (it must remain in the gitignored `.devlocal/` tree)
- Final user-facing output omits the "Next session, paste this:" bootstrap line
- Handoff over 250 lines (you are duplicating artifacts)
- Plan, design, or ADR content pasted verbatim instead of referenced by path
- No "Next Session Focus" section, or the focus is vague ("continue work")
- API keys, tokens, passwords, or DB URLs with credentials present in the file
- Suggested skills include skills that don't exist in `skills/` or are vendor-specific to a different toolchain
- The handoff describes the conversation itself ("Claude said X, then the user said Y") instead of the work state

## Verification

- [ ] File written to `.devlocal/handoffs/handoff-<UTC-timestamp>.md` (relative to project root)
- [ ] `.devlocal/` is gitignored (sanity-check: `git check-ignore .devlocal/handoffs/` exits 0)
- [ ] Filename timestamp is UTC and unique
- [ ] Next Session Focus section is one or two specific sentences (or the user-supplied argument)
- [ ] At least one artifact reference (spec, plan, ADR, learning, PR, commit) is listed by path or URL — none of their content is pasted
- [ ] Suggested Skills section lists 2–6 real skills with one-line "why this skill applies" notes
- [ ] Redaction scan ran; any matches replaced with `[REDACTED:<type>]`
- [ ] Final user-facing output is: the file path, the focus, the suggested skills line, any redaction notice, and the "Next session, paste this:" bootstrap line — not the full handoff body
- [ ] Handoff length is between 60 and 250 lines
