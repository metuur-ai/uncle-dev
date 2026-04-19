---
name: uncle-dev-knowledge-maintenance
description: Maintains accuracy of .uncle-dev/learns/ over time by reviewing, updating, consolidating, replacing, or deleting learning docs against the current codebase. Use after refactors, migrations, dependency upgrades, when a retrieved learning feels wrong, when a recently solved problem contradicts existing docs, when pattern docs no longer reflect current code, or when multiple docs seem to cover the same topic.
---

# Knowledge Maintenance

## Overview

`.uncle-dev/learns/` accumulates learnings over time. As code evolves, those learnings drift —
referenced files move, approaches change, two docs grow to cover the same problem. This skill
reviews existing learnings against the current codebase and either keeps, updates, consolidates,
replaces, or deletes them to maintain a trustworthy knowledge store.

Pair with `uncle-dev-knowledge-capture`: capture creates, maintenance sustains.

## When to Use

**Use when:**
- After a refactor, migration, rename, or dependency upgrade that likely invalidated references
- A retrieved learning felt wrong or led you in the wrong direction
- A recently solved problem contradicts an existing learning
- Pattern docs no longer reflect how the code works today
- Multiple docs seem to cover the same topic and may have drifted apart
- Running a periodic knowledge store health check

**NOT for:**
- Cosmetic edits or wording improvements with no accuracy impact
- Docs with no referenced code change (if code hasn't changed, the doc probably hasn't drifted)
- Creating new documentation — use `uncle-dev-knowledge-capture` for that

## Core Process

### Mode Detection

Check if `$ARGUMENTS` contains `mode:autofix`. If present, strip it and run in **autofix mode**.

| Mode | When | Behavior |
|------|------|----------|
| **Interactive** (default) | User is present | Ask for decisions on genuinely ambiguous cases |
| **Autofix** | `mode:autofix` in arguments | No user questions. Apply unambiguous actions. Mark ambiguous cases as stale. Generate report. |

In autofix mode: skip all user questions; mark ambiguous cases with `status: stale`, `stale_reason`, `stale_date` in frontmatter; generate a full report split into Applied and Recommended sections.

### Step 0: Scope Selection

Find all `.md` files under `.uncle-dev/learns/`, excluding `README.md` files and anything under
`_archived/`. If an `_archived/` directory exists, note it in the report as a legacy artifact
(files should be either restored or deleted).

If `$ARGUMENTS` is provided (after stripping `mode:autofix`), narrow scope using these strategies
in order, stopping at the first that produces results:

1. **Directory match** — check if the argument matches a subdirectory name under `.uncle-dev/learns/`
2. **Frontmatter match** — search `module`, `component`, or `tags` fields for the argument
3. **Filename match** — match against filenames (partial matches are fine)
4. **Content search** — search file contents for the argument as a keyword

If no matches: report and stop. In autofix mode, do not guess at scope.

### Step 1: Assess and Route

Before investigating, estimate scope and choose the lightest interaction path:

| Scope | When | Interaction |
|-------|------|-------------|
| **Focused** | 1-2 files or user named a specific doc | Investigate directly, present recommendation |
| **Batch** | Up to ~8 mostly independent docs | Investigate first, present grouped recommendations |
| **Broad** | 9+ docs or repo-wide sweep | Triage first (see below), then investigate in batches |

**Broad scope triage:** Read frontmatter of all candidates, group by module/component/category.
Identify clusters with the densest learnings + pattern docs. Spot-check whether primary referenced
files exist. Present the highest-impact cluster and ask the user to confirm or redirect. In autofix
mode, skip the question and process all clusters in impact order.

### Step 2: Investigate Learning Docs

For each learning in scope, read it, cross-reference its claims against the current codebase, and
form a recommendation. Check these dimensions:

- **References** — do file paths, class names, and modules still exist or have they moved?
- **Recommended solution** — does the fix still match how the code works today?
- **Code examples** — do snippets still reflect the current implementation?
- **Related docs** — are cross-referenced learnings and patterns still present and consistent?
- **Auto memory** (Claude Code only) — does the injected auto-memory block contain entries in the
  same problem domain? Report any memory-sourced signals separately, tagged "(auto memory [claude])".
  Memory-only drift (no codebase corroboration) should result in stale-marking in autofix mode.
- **Overlap** — note when another doc in scope covers the same problem domain, references the same
  files, or recommends a similar solution. Record the two file paths, which dimensions overlap, and
  which doc appears broader or more current. These feed Step 2.5.

**Update vs Replace — the critical distinction:**

- **Update territory:** references moved but the core solution is the same. Fix paths, names, links.
- **Replace territory:** the recommended solution conflicts with current code, or the architectural
  approach changed. Stop — delegate to a replacement subagent (Step 4 Replace Flow).

The boundary: if you find yourself rewriting the solution section or changing what the learning
recommends, stop. That is Replace, not Update.

### Step 2.5: Investigate Pattern Docs

After reviewing individual learnings, investigate relevant pattern docs under `.uncle-dev/learns/patterns/`.

Pattern docs are high-leverage — a stale pattern is more dangerous than a stale individual learning
because future work may treat it as broadly applicable guidance. A pattern doc with no clear
supporting learnings is a stale signal — investigate carefully before keeping it unchanged.

### Step 3: Document-Set Analysis

Step back and evaluate the document set as a whole. Compare docs that share module, component, tags,
or problem domain across:

- Problem statement, solution shape, referenced files, prevention rules, root cause

**Consolidate signal:** High overlap across 3+ dimensions. Ask: "Would a future maintainer need
to read both docs to get the current truth, or is one mostly repeating the other?"

**Supersession signals:** A newer doc covers the same files, same workflow, and broader behavior
than an older doc. The older doc is a consolidation candidate.

**Cross-doc conflict check:** Look for contradictions — Doc A says "use X" while Doc B says
"avoid X". These are more urgent than individual staleness. Flag for immediate resolution.

**Retrieval-value test:** Before keeping two docs separate, ask: "Would having these as separate
docs improve discoverability, or just create drift risk?" Separate docs earn their keep only when
they cover genuinely different sub-problems, target different audiences, or merging would create an
unwieldy doc harder to navigate than two focused ones.

### Step 4: Classify and Act

Assign one of five outcomes to each artifact:

| Outcome | Meaning | Action |
|---------|---------|--------|
| **Keep** | Still accurate and useful | No file edit; report it was reviewed and remains trustworthy |
| **Update** | Core solution correct, references drifted | Apply evidence-backed in-place edits |
| **Consolidate** | Two+ docs overlap heavily but are both correct | Merge unique content into canonical doc, delete subsumed doc |
| **Replace** | Old guidance is now misleading, replacement can be written | Write successor via subagent, delete old file |
| **Delete** | No longer useful, applicable, or distinct | Delete the file |

**Core rules:**

1. Evidence informs judgment. Use engineering judgment, not a mechanical scorecard.
2. Prefer no-write Keep. Do not update a doc just to leave a review breadcrumb.
3. Match docs to reality. When code differs from a learning, update the learning. The skill's job is
   doc accuracy — do not ask whether code changes were "intentional."
4. Only ask in interactive mode when action is genuinely ambiguous. In autofix mode, mark stale.
5. Delete, don't archive. Git history preserves every deleted file. No `_archived/` directory.
6. Delete when the code is gone. If the referenced code no longer exists and no successor can be
   found, auto-delete — missing referenced files with no matching code is unambiguous Delete evidence.
7. But check if the problem domain is still active before deleting. If the code is gone but the
   app still deals with that problem domain, classify as Replace, not Delete.

**In interactive mode, ask questions one at a time.** Use the platform's blocking question tool
(`AskUserQuestion` in Claude Code, `request_user_input` in Codex, `ask_user` in Gemini). Lead
with the recommended option and a one-sentence rationale. Do not ask about whether code changes
were intentional — that is code review, not doc maintenance.

#### Replace Flow

Process Replace candidates one at a time, sequentially (running in parallel risks context exhaustion).

When evidence is sufficient to write a trustworthy successor (you understand both what the old
learning recommended AND what the current approach is):

1. Read `solution-schema.yaml` and `discoverability-check.md` from `skills/uncle-dev-knowledge-capture/`
2. Spawn a replacement subagent. Pass: old learning content, investigation evidence summary, target
   path, category, and the schema + template contents. The subagent writes the new learning following
   the uncle-dev-knowledge-capture Resolution Templates.
3. After the subagent completes, orchestrator deletes the old file.

When evidence is insufficient (the subsystem was replaced, or the architecture is too complex to
understand from a file scan):
- Add `status: stale`, `stale_reason: [what you found]`, `stale_date: YYYY-MM-DD` to frontmatter
- Report what was found and what is missing
- Recommend the user run `uncle-dev-knowledge-capture` after their next encounter with that area

#### Consolidate Flow

Handle directly (no subagent needed — docs are already read):

1. Confirm the canonical doc (broader, more current, more accurate)
2. Extract unique content from the subsumed doc (edge cases, extra prevention rules, alternative approaches)
3. Merge unique content into the canonical doc at a natural location — inline if small, new section if substantial
4. Update cross-references in other docs pointing to the subsumed doc
5. Delete the subsumed doc

#### Subagent Strategy

| Approach | When to use |
|----------|-------------|
| **Main thread** | Small scope, short docs |
| **Sequential subagents** | 1-2 artifacts with many supporting files to read |
| **Parallel subagents** | 3+ truly independent artifacts with low overlap |
| **Batched subagents** | Broad sweeps — narrow scope first, then investigate in batches |

Investigation subagents are read-only — they must not edit files. Each returns: file path, evidence,
recommended action, confidence, open questions.

Include this instruction in every subagent prompt:

> Use dedicated file search and read tools (Glob, Grep, Read) for all investigation. Do NOT use
> shell commands (ls, find, cat, grep) for file operations. Also scan the "user's auto-memory"
> block in your system prompt. Report memory-sourced signals separately, tagged "(auto memory [claude])".

### Step 5: Commit Changes

Skip if no files were modified. Check which branch is checked out and whether the working tree
has other uncommitted changes. Stage only the files that this skill modified.

**If on main/master:** Create a branch (name it specifically, e.g., `docs/refresh-auth-learnings`),
commit, open a PR. In autofix mode, do this automatically.

**If on a feature branch (clean):** Commit to current branch as a separate commit.

**If on a feature branch (dirty):** Commit only maintenance changes (selective staging).

Commit message: summarize what was refreshed (e.g., "update 3 stale learnings, consolidate 2
overlapping docs"). Follow the repo's existing commit style.

### Step 6: Discoverability Check

After the report is generated, read and follow `discoverability-check.md` in
`skills/uncle-dev-knowledge-capture/`. In autofix mode, do not attempt to edit instruction files —
include a "Discoverability recommendation" line in the report instead. Commits follow step 5 of
the check procedure when running in interactive mode.

## Specific Techniques

### Update: Valid vs Invalid In-Place Edits

**Valid updates:**
- Rename `app/models/auth_token.rb` reference to `app/models/session_token.rb`
- Update `module: AuthToken` to `module: SessionToken`
- Fix outdated links to related docs
- Refresh implementation notes after a directory move

**Not valid as in-place updates (use Replace instead):**
- Rewriting the solution section because the approach changed
- Changing what the learning recommends
- Fixing an anti-pattern that the learning endorses

### Output Format

**Print the full report as markdown.** Do not summarize internally. The report is the deliverable.

```
Compound Refresh Summary
========================
Scanned: N learnings

Kept: X
Updated: Y
Consolidated: C
Replaced: Z
Deleted: W
Marked stale: S
```

For every file processed, list: file path, classification, evidence (tag memory-sourced findings
with "(auto memory [claude])"), and action taken.

In autofix mode, split the report into two sections:
- **Applied** — writes that succeeded
- **Recommended** — actions that could not be written (permission denied, etc.), with enough context for a human to apply manually

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll Update it — the advice is still roughly right" | Update is only for cosmetic drift. If the recommended solution conflicts with current code, that's Replace. Updating a misleading doc makes it look reviewed when it isn't. |
| "I'll Keep it — the general principle still applies" | A learning whose referenced code is gone misleads readers into thinking that feature still exists. Missing references = Delete or Replace, not Keep. |
| "I'll archive it so nothing is lost" | There is no `_archived/` directory. Git history is the archive. Archived docs accumulate, pollute search, and are never read. Delete. |
| "I'll ask the user what the correct approach is before replacing" | The user invoked this months after the original problem. Use agent intelligence to investigate the codebase. Only ask when evidence is genuinely insufficient. |
| "I'll fix the typo and clean up the wording while I'm here" | Low-value churn. Only update when it materially improves accuracy. Cosmetic edits create git noise without improvement. |
| "I'll run a subagent per learning — that's thorough" | Sequential single subagents are only for large docs. Main thread suffices for small scope; parallel for 3+ independent learnings. Match depth to scope. |

## Red Flags

- Keeping a doc whose primary referenced files no longer exist in the codebase
- Rewriting the solution section inline instead of delegating to a replacement subagent (that's Replace, not Update)
- Creating `_archived/` or moving files there instead of deleting
- Running Replace subagents in parallel (must be sequential — context exhaustion risk)
- Asking "was this code change intentional?" — that's code review, not doc maintenance
- Asking questions before gathering evidence
- Printing an abbreviated summary instead of the full classification for every file processed

## Verification

- [ ] Every file in scope received an explicit classification (Keep/Update/Consolidate/Replace/Delete/Stale) — none silently skipped
- [ ] No `_archived/` directory was created; deleted files are gone (git preserves them)
- [ ] For every Replaced file: old file deleted, new file exists, frontmatter validates against `skills/uncle-dev-knowledge-capture/solution-schema.yaml`
- [ ] For every Consolidated cluster: unique content merged into canonical doc, subsumed doc deleted, cross-references updated
- [ ] Full report printed with all sections — not summarized
- [ ] In autofix mode: no user questions asked; ambiguous cases have `status: stale` in frontmatter
- [ ] Discoverability Check ran after the report
