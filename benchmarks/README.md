# uncle-dev benchmark harness

A narrow, reproducible [promptfoo](https://promptfoo.dev) harness that compares
two arms on three representative tasks, to provide evidence for uncle-dev's
effect on model behavior. Evidence for Unit 9 (EARS R-9.1..R-9.3).

> Honest scope: uncle-dev's full value is hard to score. This harness measures a
> few objective, deterministic signals — not a complete quality judgment.

## The two arms

Both arms use the **same pinned model** and the **same task inputs**; they differ
only by system prompt:

| Arm | System prompt | File |
| --- | --- | --- |
| `no-skill` | bare "helpful engineer" instruction | `prompts/no-skill.txt` |
| `uncle-dev` | uncle-dev rules injected (spec-first, surgical refactor, review rigor) | `prompts/uncle-dev.txt` |

## Pinned versions (reproducibility)

- **Model:** `anthropic:messages:claude-sonnet-4-6` (pinned in `promptfooconfig.yaml`,
  `temperature: 0`). One model for the whole benchmark, chosen for cost.
- **promptfoo:** `0.121.17` (pinned in `package.json`).

## The three tasks (`tasks/`)

| Task | Category | Deterministic check |
| --- | --- | --- |
| `spec-first-feature` | spec-first feature work | regex for EARS / acceptance-criteria phrasing |
| `refactor` | refactoring | `formatName` (public interface) survives the refactor |
| `review-catch-rate` | review catch-rate | `grader.py` confirms BOTH planted defects are flagged |

The review task plants two auditable defects (off-by-one bug + orphaned
`@spec CART-TOTAL-999`); see `tasks/review-catch-rate.md` and `fixtures/`.

## Running it

Requires an Anthropic API key (live model calls):

```bash
export ANTHROPIC_API_KEY=sk-ant-...
cd benchmarks
npm install          # installs the pinned promptfoo
./run.sh             # runs the eval -> results/latest.json -> prints the table
```

Or with npm scripts:

```bash
npm run bench        # promptfoo eval -> results/latest.json
npm run report       # render the table from results/latest.json
```

Re-render the table from the last results without calling the API:

```bash
./run.sh --report
```

If `ANTHROPIC_API_KEY` is unset, `run.sh` fails with a clear message and exits
non-zero — it never silently produces an empty table.

## The comparison table (R-9.3)

`report.py` turns the promptfoo JSON output into a **stable** arms × tasks
Markdown table: rows (tasks) and columns (arms) are sorted, columns are fixed,
and each cell is `PASS`/`FAIL`/`-`. Two runs over the same pinned inputs produce
a byte-identical table. Example (from `samples/expected-table.md`):

```
| task | no-skill | uncle-dev |
| --- | --- | --- |
| refactor | PASS | PASS |
| review-catch-rate | FAIL | PASS |
| spec-first-feature | FAIL | PASS |
| **PASS total** | 1/3 | 3/3 |
```

## Offline test

`../scripts/tests/benchmarks.test.sh` validates the harness with **no API key**:
config well-formedness, pinned model + promptfoo version present, the three task
categories, the grader catching the planted bug (buggy fixture fails, good fixture
passes), and the report formatter producing the stable table from the checked-in
sample JSON.
