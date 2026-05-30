---
description: Compact the current conversation into a handoff document under .devlocal/handoffs/ so a fresh agent can pick up the work (gitignored, personal scratchpad).
argument-hint: "What will the next session focus on?"
---

## Working Principles

1. **Think Before Coding** — Confirm what the next session will focus on before drafting. If the user didn't pass an argument, ask once and wait.
2. **Simplicity First** — One handoff file at `.devlocal/handoffs/handoff-<UTC-timestamp>.md`. No intermediate drafts, no per-section files, no duplicates elsewhere.
3. **Surgical Changes** — Reference durable artifacts (PRDs, plans, ADRs, OpenSpec changes, issues, commits, diffs) by path or URL. Do not paste their content into the handoff.
4. **Goal-Driven Execution** — Success means another agent (or you, after `/clear`) can read one file and resume the work without re-reading the transcript.

---

Invoke the agent-skills:uncle-dev-wrap skill.

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to `.devlocal/handoffs/handoff-<UTC-timestamp>.md` (relative to the project root). `.devlocal/` is gitignored — handoffs are personal scratchpad, not shared artifacts.

After writing, validate the output path strictly:
- It **must** match `.devlocal/handoffs/handoff-*.md` (relative path)
- It **must not** be in `/tmp`, `$TMPDIR`, repo root, `docs/`, or `openspec/`
- If written elsewhere, immediately rewrite to the correct `.devlocal/handoffs/` path and report only the corrected path

If the user passed arguments, treat them as the description of what the next session will focus on and shape the handoff around that focus. If no arguments were passed, ask the user one blocking question to capture the focus before drafting.

The handoff MUST include a **Suggested Skills** section listing 2–6 real skills from `skills/` (with one-line "why this skill applies" notes) that the next session should invoke.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, OpenSpec changes, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information — API keys, tokens, passwords, database connection strings with credentials, and personally identifiable information. Replace each match with `[REDACTED:<type>]` and note the redaction at the top of the doc.

After writing the file, report only: the relative file path, the Next Session Focus, the suggested skills as a single line, any redaction notice, **and the "Next session, paste this:" bootstrap line** so the user can hand off in one paste. Do not echo the full handoff body back to the chat.
