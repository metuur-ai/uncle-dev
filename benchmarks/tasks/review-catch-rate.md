# Task (c): review catch-rate (VALIDATED)

**Prompt var (`task`):** review `cartTotal(items)` for defects, given the list of
known valid spec ids. The snippet is `fixtures/review-snippet.js`.

## Planted defects (auditable)

1. **Off-by-one bug** — the loop condition is `i <= items.length`, so on the last
   iteration it reads `items[items.length]` (undefined) and adds `NaN` to the
   total. Correct condition: `i < items.length`.

2. **Orphaned `@spec`** — the annotation is `@spec CART-TOTAL-999`. `CART-TOTAL-999`
   is NOT in the known valid spec ids (`fixtures/known-spec-ids.txt`:
   `CART-TOTAL-001`, `CART-ADD-001`, `CART-REMOVE-001`). The real id is
   `CART-TOTAL-001`, so `999` is an orphaned forward reference.

A passing review must flag BOTH defects.

## Grader (offline-validated)

`grader.py` is a pure-string grader (no LLM/network). promptfoo calls it as a
`python` assertion. It is independently validated WITHOUT the API in
`scripts/tests/benchmarks.test.sh`:

- `fixtures/review-answer-buggy.txt` (generic "ship it" praise, catches nothing)
  → grader returns **fail**.
- `fixtures/review-answer-good.txt` (names both defects) → grader returns **pass**.

This proves the grader actually detects the known planted bug + orphan before any
live model is involved.
