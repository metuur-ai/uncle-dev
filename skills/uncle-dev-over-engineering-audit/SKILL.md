---
name: uncle-dev-over-engineering-audit
description: Audits code for removable bloat and emits a ranked, tagged cut-list answering "what can we delete?". Use when you suspect a change or a codebase carries dead code, reinvented standard-library behavior, hand-rolled runtime primitives, speculative flexibility, or oversized constructs. Use before a refactor to decide what to cut, when a module feels heavier than its job, or when asked to "find what we can remove". Not for clarity rewrites (use uncle-dev-dev-code-simplification) or correctness/quality review (use uncle-dev-code-review-and-quality).
---

## Overview

This skill answers one question: **what can we delete?** It produces a ranked, tagged cut-list — not a rewrite, not a verdict. It is deliberately narrow and deliberately distinct from its two siblings:

| Skill | Question it answers | Output |
|---|---|---|
| `uncle-dev-dev-code-simplification` | "How do we make this clearer?" | Clarity-first rewrites that **preserve behavior** |
| `uncle-dev-code-review-and-quality` | "Is this correct and healthy?" | Five-axis findings + APPROVE / REQUEST_CHANGES verdict |
| **`uncle-dev-over-engineering-audit`** (this skill) | **"What can we delete?"** | **A ranked, tagged cut-list ending in a `net:` line** |

Simplification rewrites code that stays. Review judges whether code is good. This audit hunts for code that should not exist at all — and quantifies the cut so the gain is visible before anyone touches the diff.

It **complements** the other two and never replaces them. It does not modify, wrap, or supersede `skills/uncle-dev-dev-code-simplification/` or `skills/uncle-dev-code-review-and-quality/`. If a finding is "this stays but could read better," that belongs to simplification, not here.

## When to Use

- Before a refactor, to decide what is worth cutting before investing in rewrites.
- A module, file, or dependency feels heavier than the job it does.
- A diff adds abstraction, config, or dependencies that may not pull their weight.
- You are asked to "find what we can remove," "trim this," or "audit for over-engineering."
- Periodic whole-repo bloat sweep (e.g. self-application against the project's own config/manifest surface).

When NOT to use:

- The code stays but reads poorly → `uncle-dev-dev-code-simplification`.
- You need a correctness/security/architecture verdict before merge → `uncle-dev-code-review-and-quality`.
- You want to *act* on cuts. This skill produces the cut-list; deleting is a separate, normal change reviewed through the usual gates.

## Process

### The output contract (the heart of this skill)

Every audit emits **one line per finding**. Each line is tagged with **exactly one** of these five tags — never zero, never two:

| Tag | Means | Example |
|---|---|---|
| `delete` | Dead or unused — unreachable branch, unused export, commented-out block, a dependency nothing imports | A `formatLegacyDate()` with no callers |
| `stdlib` | Reimplements standard-library behavior the language already ships | A hand-written `groupBy` where `Object.groupBy` / `itertools.groupby` exists |
| `native` | Hand-rolls what the language/runtime/platform already provides natively | A custom debounce when the framework ships one; a manual UUID v4 where `crypto.randomUUID()` exists |
| `yagni` | Speculative flexibility never exercised — config, hooks, or generics with a single concrete use | A strategy interface with one implementation; an `options` object where every caller passes the same value |
| `shrink` | Real and used, but far over-sized for its single use — collapse, don't delete | A 4-file factory producing one object; a 120-line class used as a bag of two functions |

Choosing between tags: if removing the code entirely loses nothing → `delete`. If a built-in replaces it → `stdlib` (language library) or `native` (runtime/framework/platform). If it exists only for a future that never came → `yagni`. If it must stay but is bloated → `shrink`. Pick the single tag that best names *why* the cut is possible.

### Ranking and the net line

1. **Rank findings biggest-cut-first** — by lines removed (a dependency drop or a `delete` of a whole module outranks a 3-line `shrink`). Largest cut at the top.
2. **End with exactly one summary line**, this format verbatim:

   ```
   net: -N lines, -M deps possible
   ```

   `N` = total lines removable across all findings. `M` = total dependencies droppable (0 if none). The word `possible` is literal — the audit asserts what *can* be cut, not what was cut.

Each finding line carries: the tag, the location (`path:line` or `path`), a one-clause description, and the line/dep delta. Format:

```
[tag] path:line — what & why — (-K lines[, -1 dep])
```

### Scope 1 — Diff (changed files)

Default scope. Audit only what changed.

1. `git diff --name-only` (or the staged/PR diff) to get changed files.
2. For each changed file, scan for the five tag patterns above. Use `graphify` first if the project has `graphify-out/graph.json` (e.g. `graphify query "what imports the symbol"` to confirm a `delete` candidate is truly unreferenced) before falling back to grep.
3. Emit one tagged line per finding, ranked biggest-cut-first.
4. Emit the `net:` line.

### Scope 2 — Whole-repo (reuse existing orchestration — do NOT invent a new engine)

For repo-scale audits, **reuse the parallel-orchestration + synthesis pattern already documented in `uncle-dev-code-review-and-quality` → "Parallel Orchestration Mode"**. Do not build a new fan-out mechanism.

1. **Fan out (parallel, background).** Partition the repo by subsystem/domain (use `graphify-out/GRAPH_REPORT.md` community structure if present; otherwise top-level dirs). Spawn one audit subagent per partition, in the same `Task(..., run_in_background=true)` style that skill uses for its parallel reviewers. Give each subagent this skill's output contract and its partition's file list. Each returns its own tagged, ranked finding lines plus a partial `net:`.
2. **Synthesize.** Pass every partition's findings to `agents/uncle-dev-ag-review-synthesizer.md` (the same `uncle-dev-ag-review-synthesizer` used by the five-axis review). It deduplicates overlapping findings (e.g. the same reinvented helper flagged in two partitions → one `stdlib` line) and concatenates the rest. Instruct it to preserve this skill's contract: one tag per line, re-rank the merged list biggest-cut-first, and sum the partial deltas into a single final `net: -N lines, -M deps possible`. The synthesizer consolidates only — it introduces no findings the partition agents did not report.

This is the only orchestration this skill defines: a thin re-use of the review skill's fan-out and the existing synthesizer agent.

### Worked example (output)

Diff-scope audit of a small change:

```
[delete] src/utils/legacy.ts:1-44 — formatLegacyDate has no callers since formatDate landed — (-44 lines)
[yagni]  src/notify/Notifier.ts:12 — Strategy interface with one impl (EmailStrategy); inline it — (-31 lines)
[stdlib] src/utils/group.ts:5 — hand-rolled groupBy; replace with Object.groupBy — (-18 lines)
[native] src/auth/id.ts:9 — manual uuid v4 generator; use crypto.randomUUID() — (-12 lines, -1 dep)
[shrink] src/config/Loader.ts:1-60 — 60-line loader class wraps one fs.readFileSync; collapse to a function — (-40 lines)
net: -145 lines, -1 deps possible
```

Findings are ranked largest cut first; each has exactly one tag; the run ends with the `net:` line.

### Validation loop

This skill emits a report; it mutates nothing. Before declaring the audit done, run the Verification checklist below as the validate step — if any check fails (a finding with zero or two tags, an unranked list, a missing or malformed `net:` line), fix the report and re-check.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is just simplification, I'll do a clarity rewrite instead." | Simplification keeps the code and rewrites it. This audit asks whether the code should exist. If the answer is "no," a clarity rewrite is wasted effort on something destined for deletion. |
| "I'll just run the five-axis review." | Review judges what stays; it issues a verdict, not a cut-list. It will not produce a ranked, tagged, quantified deletion plan. Different question, different output. |
| "I'll tag it as both `stdlib` and `shrink` to be safe." | The contract is exactly one tag per line. Two tags hide which cut is actually being claimed and break the count. Pick the single reason the cut is possible. |
| "Ranking doesn't matter, the findings are what counts." | Biggest-cut-first is the point — it tells the reader where the leverage is. An unranked list buries a 200-line deletion under three 2-line shrinks. |
| "I'll skip the net line, the findings imply it." | The `net:` line is the deliverable's headline — it makes the total gain visible before anyone reads a single finding. Omitting it defeats the purpose. |
| "Whole-repo is big, I'll write a custom fan-out for it." | The parallel-orchestration + synthesizer pattern already exists in `uncle-dev-code-review-and-quality`. Reuse it. A second orchestration engine is exactly the over-engineering this skill exists to flag. |
| "It might be needed later, so I won't flag the yagni." | Speculative flexibility with no current use is the textbook `yagni` finding. Flag it; re-add when a real second use arrives. The audit lists it — it does not force the deletion. |

## Red Flags

- A finding line with no tag, or with more than one tag.
- A tag used loosely — `delete` on code that has callers, or `stdlib`/`native` without naming the built-in that replaces it.
- Findings listed in file order or discovery order instead of biggest-cut-first.
- Missing `net:` line, or a `net:` line not matching `net: -N lines, -M deps possible` exactly.
- `net:` totals that don't equal the sum of the per-finding deltas.
- Producing rewrites or a merge verdict — that's the sibling skills' job, not this one's.
- Inventing a new parallel-orchestration mechanism for whole-repo scope instead of reusing the review skill's pattern + `uncle-dev-ag-review-synthesizer`.
- Editing `skills/uncle-dev-dev-code-simplification/` or `skills/uncle-dev-code-review-and-quality/` while running this skill.

## Verification

After the audit, confirm:

- [ ] Every finding line carries **exactly one** of `delete|stdlib|native|yagni|shrink` (none has zero or two tags).
- [ ] Each `stdlib`/`native` finding names the specific built-in that replaces the code.
- [ ] Findings are ordered **biggest-cut-first** (largest line/dep delta at the top).
- [ ] The output **ends with** a line matching `net: -N lines, -M deps possible` exactly.
- [ ] The `net:` totals equal the sum of the per-finding deltas.
- [ ] Scope is explicit (diff or whole-repo); whole-repo runs reused the `uncle-dev-code-review-and-quality` parallel-orchestration pattern and the `uncle-dev-ag-review-synthesizer` agent — no new orchestration engine was written.
- [ ] No edits were made to `skills/uncle-dev-dev-code-simplification/` or `skills/uncle-dev-code-review-and-quality/` (`git diff --stat` shows neither path).
