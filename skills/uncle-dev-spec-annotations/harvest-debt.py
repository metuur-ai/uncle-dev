#!/usr/bin/env python3
"""Debt harvester — gathers `@debt <ceiling>, <upgrade>` markers into a ledger.

`@debt` marks a consciously-kept shortcut with its limit (ceiling) and its
escape hatch (upgrade). This script walks the repo, finds every `@debt` marker
in any comment style, parses the two mandatory fields, and emits a ledger
showing each marker's location, ceiling, and upgrade path.

A marker missing its ceiling or upgrade is a SILENT-ROT RISK: a shortcut with
no recorded limit or exit. Those are flagged and sorted to the TOP of the
ledger so they cannot hide among well-formed entries.

Grammar (see uncle-dev-spec-annotations/SKILL.md):
  @debt <ceiling>, <upgrade>
Both fields mandatory, split on the FIRST comma; either side empty is invalid.

Exit codes:
  0   No silent-rot-risk markers (clean, or only well-formed debt).
  1   At least one silent-rot-risk marker (malformed: missing ceiling/upgrade).
  2   Internal error (file I/O, malformed input).

Usage:
  python3 harvest-debt.py --root /path/to/repo
  python3 harvest-debt.py --root . --format json
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from typing import List

# Locate `@debt` and capture everything after it on the line, stripping a
# trailing comment closer (e.g. `-->`, `*/`) if present. Works for //, #,
# <!-- -->, /* */, --, ; and bare comment styles.
DEBT_RE = re.compile(r"@debt\b[ \t]*(?P<body>.*)$")
# Trailing comment terminators to peel off the body (HTML/CSS/block comments).
TRAILING_CLOSER_RE = re.compile(r"\s*(?:-->|\*/|\})\s*$")


# --- File walking -----------------------------------------------------------

EXCLUDE_DIRS = {
    "node_modules", ".git", "dist", "build", ".venv", "venv", "__pycache__",
    "target", "vendor", ".next", "coverage", ".tox", ".mypy_cache",
    ".pytest_cache", ".turbo", ".cache", "out",
}
# Binary / non-source extensions we never scan.
SKIP_EXTS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".svg",
    ".pdf", ".zip", ".gz", ".tar", ".woff", ".woff2", ".ttf", ".eot",
    ".lock", ".min.js", ".map",
}


def walk_files(root: str) -> List[str]:
    """Yield repo-relative paths to candidate text files under root."""
    paths: List[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext in SKIP_EXTS:
                continue
            full = os.path.join(dirpath, fname)
            paths.append(os.path.relpath(full, root))
    return paths


# --- Parsing ----------------------------------------------------------------

def parse_debt_body(body: str) -> dict:
    """Parse the text after `@debt` into ceiling + upgrade.

    Splits on the FIRST comma. Both sides must be non-empty after stripping.
    Returns {ceiling, upgrade, rot_risk, reason}.
    """
    text = body.strip()
    text = TRAILING_CLOSER_RE.sub("", text).strip()

    if "," not in text:
        return {
            "ceiling": text,
            "upgrade": "",
            "rot_risk": True,
            "reason": "no comma — missing upgrade path"
            if text else "empty marker — missing ceiling and upgrade",
        }

    ceiling, upgrade = text.split(",", 1)
    ceiling = ceiling.strip()
    upgrade = upgrade.strip()

    missing = []
    if not ceiling:
        missing.append("ceiling")
    if not upgrade:
        missing.append("upgrade")

    if missing:
        return {
            "ceiling": ceiling,
            "upgrade": upgrade,
            "rot_risk": True,
            "reason": "missing " + " and ".join(missing),
        }

    return {
        "ceiling": ceiling,
        "upgrade": upgrade,
        "rot_risk": False,
        "reason": "",
    }


def harvest(root: str) -> List[dict]:
    """Walk root, return a list of marker records."""
    markers: List[dict] = []
    self_path = os.path.relpath(os.path.abspath(__file__), root) \
        if os.path.abspath(__file__).startswith(os.path.abspath(root)) else None

    for rel_path in walk_files(root):
        # Don't harvest this script's own grammar examples / regex.
        if self_path is not None and rel_path == self_path:
            continue
        full = os.path.join(root, rel_path)
        try:
            with open(full, encoding="utf-8", errors="replace") as f:
                content = f.read()
        except OSError as exc:
            print(f"[harvest] WARN: could not read {rel_path}: {exc}",
                  file=sys.stderr)
            continue
        if "@debt" not in content:
            continue
        for line_no, line in enumerate(content.splitlines(), start=1):
            m = DEBT_RE.search(line)
            if not m:
                continue
            parsed = parse_debt_body(m.group("body"))
            markers.append({
                "file": rel_path,
                "line": line_no,
                **parsed,
            })
    return markers


# --- Reporting --------------------------------------------------------------

def build_report(root: str, markers: List[dict]) -> dict:
    rot = [m for m in markers if m["rot_risk"]]
    ok = [m for m in markers if not m["rot_risk"]]
    rot.sort(key=lambda m: (m["file"], m["line"]))
    ok.sort(key=lambda m: (m["file"], m["line"]))
    # Rot-risk markers sorted to the TOP (R-6.3).
    ledger = rot + ok
    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "root": root,
        "summary": {
            "total": len(markers),
            "rot_risk": len(rot),
            "well_formed": len(ok),
        },
        "ledger": ledger,
    }


def format_text(report: dict) -> str:
    s = report["summary"]
    lines = [
        f"@debt ledger (root: {report['root']})",
        "",
        f"  {s['total']} marker(s): {s['well_formed']} well-formed, "
        f"{s['rot_risk']} silent-rot risk",
        "",
    ]
    if not report["ledger"]:
        lines.append("  No @debt markers found.")
        lines.append("")
        return "\n".join(lines)

    for m in report["ledger"]:
        loc = f"{m['file']}:{m['line']}"
        if m["rot_risk"]:
            lines.append(
                f"  ✗ SILENT-ROT RISK: {loc} — {m['reason']}"
            )
            lines.append(
                f"      ceiling: {m['ceiling'] or '(none)'}"
                f"  upgrade: {m['upgrade'] or '(none)'}"
            )
        else:
            lines.append(f"  ✓ {loc}")
            lines.append(f"      ceiling: {m['ceiling']}")
            lines.append(f"      upgrade: {m['upgrade']}")
    lines.append("")
    lines.append(
        f"Summary: {s['total']} marker(s), {s['rot_risk']} silent-rot risk "
        f"(sorted to top)."
    )
    return "\n".join(lines)


# --- CLI --------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Harvest @debt markers into a ledger."
    )
    p.add_argument("--root", default=os.getcwd(),
                   help="Repo root to scan (default: cwd)")
    p.add_argument("--format", choices=["text", "json"], default="text",
                   help="Output format")
    p.add_argument("--quiet", action="store_true",
                   help="Suppress non-error text output")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = os.path.abspath(args.root)

    markers = harvest(root)
    report = build_report(root, markers)

    if args.format == "json":
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        if not args.quiet:
            print(format_text(report))

    return 1 if report["summary"]["rot_risk"] > 0 else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:  # noqa: BLE001 — top-level guard
        print(f"[harvest] ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
