# benchmarks

promptfoo harness comparing a `no-skill` arm against an `uncle-dev` arm on a
small representative task set, emitting a reproducible comparison table.
Evidence for Unit 9 (EARS R-9.1..R-9.3). Does NOT score uncle-dev's full value —
narrow and honest by design.

## Purpose
Measure whether injecting uncle-dev skill text into the system prompt changes a
model's behavior on three task shapes: spec-first feature work, refactoring, and
review catch-rate. NOT a general-purpose eval framework; only these three tasks.

## Entry Points
- `promptfooconfig.yaml` — the eval: two prompt arms (`no-skill`, `uncle-dev`),
  one pinned provider, the task set as `tests`.
- `run.sh` — runs `npx promptfoo eval`, writes `results/latest.json`, renders the table.
- `report.py` — turns a promptfoo JSON output into a stable arms × tasks Markdown table.
- `grader.py` — the review-task grader logic, callable offline for validation.
- `tasks/` — one `<category>.md` per task (human-readable spec of the prompt + assertions).
- `fixtures/` — the planted-bug code, the buggy answer, the good answer (auditable).
- `prompts/` — the two arm prompt templates (`no-skill.txt`, `uncle-dev.txt`).
- `samples/` — a checked-in promptfoo JSON output for the deterministic report test.

## Contracts & Invariants
- The promptfoo version is PINNED in `package.json`; the model id is PINNED in
  `promptfooconfig.yaml`. Two runs over the same pinned inputs emit the same table.
- The two arms differ ONLY by system prompt (`prompts/no-skill.txt` vs
  `prompts/uncle-dev.txt`); same provider, same task vars.
- `report.py` sorts rows (tasks) and columns (arms) deterministically so output
  is stable regardless of promptfoo's internal ordering.
- `grader.py` has NO network/LLM dependency — it is pure string logic so the
  "does the grader catch the planted bug" check runs offline.
- Live evals require `ANTHROPIC_API_KEY`; `run.sh` fails loud with a clear
  message when it is absent. The repo's own test (`scripts/tests/benchmarks.test.sh`)
  never calls the API.

## Patterns
To add a task:
1. Add a `tasks/<category>.md` describing the prompt and the deterministic assertion.
2. Add a `tests:` entry in `promptfooconfig.yaml` with `vars` + `assert`.
3. If it needs a fixture, put the auditable artifact under `fixtures/`.

## Anti-patterns
- Never read `ANTHROPIC_API_KEY` into a committed file or log it.
- Don't make the grader depend on a live model — keep it pure-string and testable.
- Don't add tasks whose pass/fail can't be decided by a deterministic assertion.
- Don't unpin the model or promptfoo version — reproducibility depends on both.

## Related Context
- Test suite: `../scripts/tests/AGENTS.md` (the offline test lives there as `benchmarks.test.sh`)
- EARS source of truth: `../docs/ears/ponytail-patterns-adoption.md` (Unit 9)
- LLD: `../docs/lld/ponytail-patterns-adoption.md` (#7)
