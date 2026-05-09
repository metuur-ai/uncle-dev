---
description: Capture and manage design-decision notes under openspec/acknowledge/. Notes are pending by default and gate /uncle-dev-build until acknowledged.
---

Invoke the agent-skills:uncle-dev-acknowledge skill.

## Arguments

- `(no args)` — paste mode. Prompt the user for note text, parse it into discrete decisions, infer scopes per `inference-rules.md`, allocate D-ids via `_meta.yaml`, write/update each scope file, then print a routing summary.
- `<file-path>` — extract mode. Read the given file (typically `openspec/changes/<id>/design.md`), pull every row in **Technical Decisions** ending with `→ ack`, and capture them. Sets `related_change` from the change-id in the path.
- `ack <ids>` — flip status `pending` → `acknowledged` for each id (comma-separated). Stamps `ack_by` from `git config user.email` and `ack_at` (UTC ISO-8601). Propagates to every scope file containing each id.
- `reject <ids> --reason <r>` — flip status to `rejected` with the supplied reason. Rejected notes still satisfy the gate (the decision was made — to NOT do it).
- `supersede <old> --by <new>` — mark `<old>` as `superseded`, set `supersedes: <old>` on the new section, set `superseded_by: <new>` on the old. Both stay readable. The new id must already exist (capture it first if needed).
- `list [--scope <s>] [--status <s>]` — read-only summary. Used by humans browsing and by the gate when reporting blockers. Filters are independent and AND together.

## Process

1. Pick the mode from arguments.
2. **Capture** (paste / extract): follow the Capture mode in `skills/uncle-dev-acknowledge/SKILL.md`.
3. **Workflow** (`ack` / `reject` / `supersede` / `list`): follow `skills/uncle-dev-acknowledge/acknowledge-workflow.md` exactly — including the `_meta.yaml` lock and the rule that workflow operations never touch prose bodies.
4. After any write, print the routing summary or the workflow output as defined in the skill files.

## Output

- Capture: routing table (one line per decision: `D<N> → [scopes] (signals: <matched>)`).
- Workflow: per-id action summary (acked/rejected/superseded/skipped) with the files touched.
- `list`: a table of `D<N>` | scope | status | title | related_change.

## Failure Modes

- `git config user.email` empty → refuse `ack` / `reject`; print the fix command.
- `_meta.yaml` lock not acquirable within 30s → exit non-zero with the inspect command; do not force the lock.
- Unknown id passed to `ack` / `reject` / `supersede` → report and skip; partial success is allowed.
- `supersede --by <new>` where `<new>` doesn't exist → refuse; instruct the user to capture `<new>` first.
- File on disk that the inference rules can't classify into any scope → fall back to `general.md` (per the rule table); never lose a note.
