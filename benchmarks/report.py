#!/usr/bin/env python3
"""Render a promptfoo eval JSON output as a STABLE arms x tasks Markdown table.

Reproducibility (EARS R-9.3): rows (tasks) and columns (arms) are sorted
deterministically, columns are fixed, and the cell format is fixed, so two runs
over the same pinned inputs produce a byte-identical table. promptfoo's internal
result ordering does not affect the output.

Input: a promptfoo `eval -o results.json` file. Output: Markdown to stdout.

The promptfoo JSON shape used here (stable across the pinned version):
  {
    "results": {
      "results": [
        {
          "promptId"|"prompt": {...,"label": "<arm>"},
          "testCase"|"vars": {"description": "<task>"} | {...},
          "success": true|false,
          "score": 1.0
        }, ...
      ]
    }
  }
We read each cell as PASS/FAIL by `success`. Unknown combinations render `-`.
"""
from __future__ import annotations

import json
import sys


def _arm_of(row: dict) -> str:
    """Extract the arm (prompt label) from a result row, tolerant of shape."""
    prompt = row.get("prompt") or row.get("promptId") or {}
    if isinstance(prompt, dict):
        label = prompt.get("label") or prompt.get("id") or prompt.get("raw")
        if label:
            return str(label)
    if isinstance(prompt, str):
        return prompt
    # Fallback: a top-level provider/prompt label some versions attach.
    return str(row.get("promptLabel") or "unknown-arm")


def _task_of(row: dict) -> str:
    """Extract the task (test description) from a result row, tolerant of shape."""
    tc = row.get("testCase") or {}
    if isinstance(tc, dict):
        desc = tc.get("description")
        if desc:
            return str(desc)
        meta = tc.get("metadata") or {}
        if isinstance(meta, dict) and meta.get("description"):
            return str(meta["description"])
    if row.get("description"):
        return str(row["description"])
    vars_ = row.get("vars") or (tc.get("vars") if isinstance(tc, dict) else None) or {}
    if isinstance(vars_, dict) and vars_.get("description"):
        return str(vars_["description"])
    return "unknown-task"


def _passed(row: dict) -> bool | None:
    if "success" in row:
        return bool(row["success"])
    if "pass" in row:
        return bool(row["pass"])
    grading = row.get("gradingResult") or {}
    if isinstance(grading, dict) and "pass" in grading:
        return bool(grading["pass"])
    return None


def _rows(data: dict) -> list[dict]:
    results = data.get("results")
    if isinstance(results, dict):
        inner = results.get("results")
        if isinstance(inner, list):
            return inner
    if isinstance(results, list):
        return results
    if isinstance(data.get("results", {}), list):
        return data["results"]
    return []


def build_table(data: dict) -> str:
    rows = _rows(data)
    cells: dict[tuple[str, str], bool | None] = {}
    arms: set[str] = set()
    tasks: set[str] = set()
    for row in rows:
        arm = _arm_of(row)
        task = _task_of(row)
        arms.add(arm)
        tasks.add(task)
        cells[(task, arm)] = _passed(row)

    arm_list = sorted(arms)
    task_list = sorted(tasks)

    header = "| task | " + " | ".join(arm_list) + " |"
    sep = "| --- | " + " | ".join(["---"] * len(arm_list)) + " |"
    lines = [header, sep]
    for task in task_list:
        cell_strs = []
        for arm in arm_list:
            v = cells.get((task, arm))
            cell_strs.append("PASS" if v is True else "FAIL" if v is False else "-")
        lines.append(f"| {task} | " + " | ".join(cell_strs) + " |")

    # Per-arm totals row (deterministic): count of PASS over total tasks.
    totals = []
    for arm in arm_list:
        p = sum(1 for task in task_list if cells.get((task, arm)) is True)
        totals.append(f"{p}/{len(task_list)}")
    lines.append("| **PASS total** | " + " | ".join(totals) + " |")

    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: report.py <promptfoo-output.json>\n")
        return 2
    with open(argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)
    sys.stdout.write(build_table(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
