---
description: Detect over-engineering and harvest deferred shortcuts. Three modes — review (diff cut-list), audit (whole-repo cut-list), debt (@debt ledger). Usage: /uncle-dev-overkill-detector [review | audit | debt]
argument-hint: "[review | audit | debt]"
---

## Working Principles

1. **Think Before Coding** — This command emits reports; it mutates nothing. Confirm a `delete` candidate is truly unreferenced before flagging it.
2. **Simplicity First** — Reuse the existing engines. The audit skill already defines both scopes and the synthesizer; the harvester already produces the ledger. Do not invent a new fan-out or a new parser.
3. **Surgical Changes** — Report only. Deleting code or completing a `@debt` marker is a separate, normally-reviewed change.
4. **Goal-Driven Execution** — review/audit end in a `net: -N lines, -M deps possible` line; debt ends in a complete ledger with silent-rot risks surfaced at the top.

---

Resolve the active skill and honor any project overrides/companions (review and audit modes):

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-over-engineering-audit
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

## Mode Detection

Detect the mode from `$ARGUMENTS`:

- **`audit`** / `repo` / `whole-repo` → whole-repo over-engineering audit.
- **`debt`** / `ledger` → harvest `@debt` markers into a ledger (skip the skill loader above; run the harvester instead).
- **`review`** / `diff` / *(empty — default)* → diff over-engineering audit.

---

## Review Mode — diff cut-list (default)

Run `uncle-dev-over-engineering-audit` in **Scope 1 — Diff**.

1. `git diff --name-only` (staged or PR diff if present) for changed files.
2. Scan each for the five tag patterns — `delete | stdlib | native | yagni | shrink`. Use graphify first when `graphify-out/graph.json` exists (e.g. confirm a `delete` candidate is unreferenced) before falling back to grep.
3. Emit one tagged line per finding, ranked biggest-cut-first:
   `[tag] path:line — what & why — (-K lines[, -1 dep])`
4. End with exactly: `net: -N lines, -M deps possible`.

This is the delete-list — a cut-list only, no rewrites and no merge verdict.

---

## Audit Mode — whole-repo cut-list

Run `uncle-dev-over-engineering-audit` in **Scope 2 — Whole-repo**. Reuse the existing orchestration — do **not** build a new fan-out.

1. **Fan out (parallel, background).** Partition by subsystem (use `graphify-out/GRAPH_REPORT.md` community structure if present; otherwise top-level dirs). Spawn one background audit subagent per partition with this skill's output contract and the partition's file list. Each returns tagged, ranked lines plus a partial `net:`.
2. **Synthesize.** Pass every partition's findings to the `uncle-dev-ag-review-synthesizer` agent. It deduplicates overlapping findings, re-ranks the merged list biggest-cut-first, and sums the partial deltas into one final `net: -N lines, -M deps possible`. The synthesizer consolidates only — it introduces no new findings.

---

## Debt Mode — @debt ledger

Harvest `@debt` markers. `@debt <ceiling>, <upgrade>` marks a consciously-kept shortcut with its limit and escape hatch — distinct from `@spec` and `[D]`. See `skills/uncle-dev-spec-annotations/SKILL.md` for the grammar.

1. Locate `harvest-debt.py`, in this order:
   - `${CLAUDE_PLUGIN_ROOT}/skills/uncle-dev-spec-annotations/harvest-debt.py`
   - `~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/skills/uncle-dev-spec-annotations/harvest-debt.py`
   - The agent-skills repo if cloned locally
2. Run it from the project root:

   ```bash
   python3 <path-to-harvest-debt.py> --root "$(pwd)"
   ```

3. Present the ledger. Silent-rot-risk markers (missing a ceiling or upgrade) sort to the **top** — a shortcut with no recorded limit or exit is debt that rots silently. If the harvester exits non-zero, surface each and recommend the author either complete the marker or remove the shortcut. A `@debt` marker is not a TODO dump.
4. If the script is not found, tell the user: "harvest-debt.py not found. Run `install-claude.sh` from the agent-skills repo, or clone the repo locally."

---

## Verification

- **review / audit:** every finding carries exactly one of `delete|stdlib|native|yagni|shrink`; each `stdlib`/`native` names the built-in that replaces it; findings ranked biggest-cut-first; output ends with `net: -N lines, -M deps possible` and the totals equal the sum of per-finding deltas; audit mode reused the parallel-orchestration pattern and `uncle-dev-ag-review-synthesizer` (no new engine).
- **debt:** silent-rot-risk markers appear first; every well-formed entry shows both ceiling and upgrade.
- No files were modified by this command (`git diff --stat` is unchanged).

$ARGUMENTS
