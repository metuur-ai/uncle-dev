---
description: Capture and manage design-decision notes — openspec/acknowledge/ in openspec mode, docs/decisions/ ADRs in lid-ears mode
---

## Step 0 — Read SDD mode (do this first)

```bash
_cfg="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[[ ! -f "$_cfg" ]] && _cfg=$(find "${HOME}/.claude/plugins" -name "uncle-dev-config.sh" 2>/dev/null | head -1)
SDD_MODE=$(bash "$_cfg" preferences.sdd_mode 2>/dev/null || echo "")
# Auto-detect from filesystem when config doesn't set a mode.
# Prefer lid-ears markers (docs/{hld,lld,ears}) over openspec/, because
# setup-project.sh previously created openspec/ unconditionally — its presence
# alone is not a reliable signal of openspec mode.
if [[ -z "$SDD_MODE" ]]; then
  if [[ -d "docs/ears" || -d "docs/hld" || -d "docs/lld" ]]; then
    SDD_MODE="lid-ears"
  elif [[ -d "openspec" ]]; then
    SDD_MODE="openspec"
  else
    SDD_MODE="lid-ears"
  fi
fi
echo "$SDD_MODE"
```

---

## Path A — `lid-ears` mode

**If sdd_mode is `lid-ears`: follow this path. The `openspec/acknowledge/` gate does not exist in lid-ears mode.**

Design decisions in lid-ears mode are captured as ADRs, not as gating acknowledge notes.

- For a **decision worth a durable record**: invoke `/uncle-dev-documentation-and-adrs` to write `docs/decisions/ADR-NNN-<slug>.md`. The ADR captures context, decision, alternatives, and consequences — it is the equivalent of an acknowledge note but narrative and repo-wide.
- For a **quick inline decision** that doesn't warrant a full ADR: write a comment directly in the relevant `docs/lld/<slug>.md` under a "Key Decisions" section.
- The `/uncle-dev-build` **gate does not apply** in lid-ears mode — there are no pending acknowledgements to block implementation.

Exit after explaining the above. Do NOT invoke the agent-skills:uncle-dev-acknowledge skill or create `openspec/acknowledge/` files.

---

## Path B — `openspec` mode (default)

**If sdd_mode is `openspec` or missing: follow this path.**

Resolve the active skill and honor any project overrides/companions:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-acknowledge
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

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
