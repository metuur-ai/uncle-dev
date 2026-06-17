#!/usr/bin/env python3
"""Review-catch-rate grader for the Unit 9 benchmark harness.

Pure-string logic, NO network / LLM dependency, so the "does this grader catch
the known planted bug" validation runs fully offline (see
scripts/tests/benchmarks.test.sh).

It decides whether a code-review answer caught BOTH planted defects in
fixtures/review-snippet.js:

  1. The off-by-one bug  (loop reads one past the end -> NaN).
  2. The orphaned @spec   (@spec CART-TOTAL-999, which is not a known spec id).

A passing answer must flag BOTH. The grader is intentionally lenient on wording
but strict on substance: it looks for evidence the reviewer identified each
specific defect, not just generic praise.

promptfoo entry point: `grade(output, context)` returns a GradingResult-shaped
dict ({"pass": bool, "score": float, "reason": str}). promptfoo's `python`
assertion calls this with the model output as the first argument.
"""
from __future__ import annotations

import re
import sys


def _caught_off_by_one(text: str) -> bool:
    """True if the answer identifies the off-by-one / out-of-bounds loop defect."""
    t = text.lower()
    # Must reference the loop boundary problem in some recognizable form.
    boundary_signals = [
        "off-by-one",
        "off by one",
        "<=",                       # quoting the buggy condition
        "i < items.length",         # stating the fix
        "out of bounds",
        "out-of-bounds",
        "one past",
        "items.length]",            # indexing items[items.length]
    ]
    consequence_signals = ["nan", "undefined", "last iteration", "final iteration", "extra iteration"]
    return any(s in t for s in boundary_signals) and (
        any(s in t for s in consequence_signals) or "<=" in t or "i < items.length" in t
    )


def _caught_orphan_spec(text: str) -> bool:
    """True if the answer flags the orphaned @spec reference (CART-TOTAL-999)."""
    t = text.lower()
    mentions_id = "cart-total-999" in t or "999" in t
    mentions_orphan = any(
        s in t for s in ["orphan", "does not exist", "doesn't exist", "not exist", "no such spec", "unknown spec", "missing spec", "invalid spec"]
    )
    return mentions_id and mentions_orphan


def evaluate(output: str) -> dict:
    """Core grading logic. Returns a GradingResult-shaped dict."""
    text = output or ""
    off_by_one = _caught_off_by_one(text)
    orphan = _caught_orphan_spec(text)
    passed = off_by_one and orphan

    caught = []
    missed = []
    (caught if off_by_one else missed).append("off-by-one loop bug")
    (caught if orphan else missed).append("orphaned @spec CART-TOTAL-999")

    if passed:
        reason = "caught both planted defects: " + ", ".join(caught)
    else:
        reason = "missed: " + ", ".join(missed) + (
            ("; caught: " + ", ".join(caught)) if caught and missed else ""
        )

    return {"pass": passed, "score": 1.0 if passed else 0.0, "reason": reason}


# ── promptfoo python-assertion entry point ───────────────────────────────────
def grade(output, context=None):  # noqa: ARG001 (context unused, kept for promptfoo signature)
    return evaluate(output if isinstance(output, str) else str(output))


# Some promptfoo versions look for a function literally named get_assert.
get_assert = grade


if __name__ == "__main__":
    # CLI: read an answer from a file arg (or stdin) and print the verdict.
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r", encoding="utf-8") as fh:
            data = fh.read()
    else:
        data = sys.stdin.read()
    result = evaluate(data)
    print(f"pass={result['pass']} score={result['score']} reason={result['reason']}")
    sys.exit(0 if result["pass"] else 1)
