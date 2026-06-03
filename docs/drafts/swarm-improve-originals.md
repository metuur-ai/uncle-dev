# Swarm Prompt — Improve `docs/originals/` with the Documentation Skills

Paste the block below into Claude Code to launch a multi-agent swarm that improves every file in `docs/originals/` using the ten documentation skills. The swarm fans out one agent per Diataxis batch, runs them in parallel, then funnels everything through a shared editorial pass and a final coverage gate.

> **How to run it:** Paste the prompt as-is. To run the deterministic multi-agent version instead, prefix your message with the word **workflow** and Claude will orchestrate it via the Workflow tool.

---

## THE SWARM PROMPT (copy everything below)

```text
ROLE: You are the orchestrator of a documentation-improvement swarm for the
uncle-dev project. Improve every file in docs/originals/ using the ten
documentation skills. Work in waves, fan out parallel sub-agents per batch,
and keep me in the loop at each gate.

NON-NEGOTIABLE RULES
- Every doc must be exactly ONE Diataxis type (Tutorial, How-To, Reference, or
  Explanation). Flag and split any file that mixes types.
- docs-style is the baseline for all edits: second person ("you"), active voice,
  concise wording, descriptive headings, one term per concept, complete runnable
  code examples, no colloquialisms ("dive in", "game-changer", "powerful").
- Sub-agents that don't auto-load a skill must read it first:
  .claude/skills/<skill>/SKILL.md. State which skills you loaded before editing.
- Work on COPIES: operate in docs/improved/ (mirror the filenames). Never touch
  docs/originals/ — it is the pristine source of truth.
- Graphify-first: this repo has graphify-out/graph.json. For any "how does X
  work / relate to Y" question, query graphify before grep/Read.
- No silent truncation. If an agent skips a file or section, it must say so.

FILE → DIATAXIS TYPE → SKILL MAP
- EXPLANATION (load explanation-docs + docs-style):
  01-what-is-uncle-dev.md, 03-sdd-and-openspec.md, 04-devlocal-directory.md,
  lid-spec-annotation-simple-explanation.md, uncle-dev-acknowledge-summary.md,
  uncle-dev-next-task-summary.md
- HOW-TO (load howto-docs + docs-style):
  02-installation-guide.md, 05-idea-to-deploy-flow.md, copilot-setup.md,
  cursor-setup.md, gemini-cli-setup.md, opencode-setup.md, windsurf-setup.md,
  2026-05-09-implementing-spec-annotations-guide.md, spec-annotation-brown-field.md
- REFERENCE (load reference-docs + docs-style):
  06-prompts-by-phase.md, 07-prompts-by-skill.md, skill-anatomy.md
- TUTORIAL (load tutorial-docs + docs-style):
  getting-started.md
- MIXED — STRUCTURAL REVIEW ONLY (do not rewrite; propose a split plan):
  uncle-dev-full-documentation.md, uncle-dev-guide.md

WAVE 0 — SETUP (you, the orchestrator)
1. Run: mkdir -p docs/improved && cp docs/originals/*.md docs/improved/
2. Confirm graphify: [ -f graphify-out/graph.json ] && echo "graphify: ON".
3. Print the batch plan and the agent count, then proceed to Wave 1.

WAVE 1 — PARALLEL REFINEMENT (5 sub-agents, run concurrently)
Spawn ONE sub-agent per batch above. Each agent's brief:
  - Load docs-style + your batch's type skill (read the SKILL.md files).
  - For each file in your batch (in docs/improved/):
      a. Classify every section by Diataxis type.
      b. Flag sections that drift from the file's declared type.
      c. Apply docs-style fixes: voice, structure, headings, terminology,
         code-example completeness, prerequisites, verification sections.
      d. For HOW-TO files: ensure Prerequisites + single-action numbered steps
         + a "Verify it worked" section exist.
      e. For REFERENCE files: ensure parameter/skill tables are complete and
         scannable, examples runnable.
      f. For EXPLANATION files: ensure Problem → Context → How it works →
         Trade-offs flow; no step-by-step creep.
      g. For TUTORIAL files: one clear path, a visible result after every step.
  - Return a per-file report: type, issues found, edits applied, anything skipped.
The MIXED agent does NOT edit — it returns a split proposal for each mixed file
(which sections become which new single-type doc).

GATE 1: Show me the consolidated Wave-1 report (table: file | type | #issues |
#edits | skipped). Wait for my "go" before Wave 2.

WAVE 2 — EDITORIAL PASS (sequential, whole folder)
1. Invoke review-ai-writing on docs/improved/. Flag inflated language, filler,
   tautological docstrings, robotic tone. Write .beagle/ai-writing-review.json.
2. Show me the findings summary grouped by category and severity.
GATE 2: Wait for "go".
3. Invoke humanize-beagle --dry-run — preview every fix.
GATE 3: Wait for "go".
4. Invoke humanize-beagle — apply safe fixes; list risky ones for my approval.

WAVE 3 — VERIFICATION (you, the orchestrator)
1. Invoke ensure-docs --report-only — report any uncle-dev skill/command still
   lacking docs after the pass.
2. Run a final docs-style checklist sweep over docs/improved/ and report
   residual violations.
3. Produce a FINAL REPORT:
   - Files improved (count + list)
   - Diataxis type assigned to each
   - Mixed files + recommended split
   - AI-writing fixes applied (safe vs risky)
   - Remaining coverage gaps
   - Suggested next step (publish via draft-docs --publish, or split mixed docs)

OUTPUT DISCIPLINE
- At each GATE, stop and wait. Do not auto-advance through gates.
- Keep edits surgical — change only what the skill/type requires.
- Report faithfully: if a sub-agent failed or skipped a file, say so explicitly.
```

---

## Notes on running this

- **Plain paste** → Claude reads the prompt and spawns the five Wave-1 agents with the `Agent` tool, then walks the gates with you. Good when you want to review at each step.
- **Prefix with `workflow`** → Claude can encode Wave 1 as a `parallel()`/`pipeline()` fan-out and the editorial pass as sequential stages, with the same gate reports. Higher token cost, more determinism.
- **Adjust the batches** if you add or remove files in `docs/originals/` — the type map is the only thing the swarm relies on.
- **Why copies (`docs/improved/`)?** It keeps `docs/originals/` pristine so you can diff before/after and roll back any wave. When satisfied, publish finished files with `draft-docs --publish`.
- **Gates exist on purpose.** `humanize-beagle` and `ensure-docs` can change or generate files; the `--dry-run` / `--report-only` previews plus the manual "go" keep destructive steps under your control.
