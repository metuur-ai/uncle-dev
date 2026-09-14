#!/usr/bin/env python3
"""Spec coherence scanner — validates @spec annotations against docs/specs/.

Walks the repo, extracts @spec annotations from code/tests using per-language
AST adapters, and validates each ID resolves to a defined spec. Reports
ORPHANS, MISSING TEST/CODE, HELPER ANNOTATIONs, and MALFORMED IDs.

Exit codes:
  0   Clean (no orphans). Warnings allowed.
  1   At least one ORPHAN. In --strict mode, also any MISSING/HELPER/MALFORMED.
  2   Internal error (file I/O, malformed input).

Usage:
  python3 scan-spec-coherence.py --root /path/to/repo
  python3 scan-spec-coherence.py --strict --format json
  python3 scan-spec-coherence.py --no-tree-sitter
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from typing import Dict, List, Tuple

# Ensure the scanner package is importable when this script is run directly.
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

from scanner.extract import extract_annotations, is_test_path
from scanner.types import Annotation, SpecDef


# --- Spec parsing -----------------------------------------------------------

# **AUTH-UI-001**: When a user submits valid credentials...
SPEC_DEF_RE = re.compile(
    r"^\s*-\s*\[(?P<status>[xX D])\]\s*\*\*(?P<id>[A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*-\d+)\*\*\s*:\s*(?P<title>.+?)\s*$"
)


def parse_specs(specs_dir: str, repo_root: str) -> Dict[str, SpecDef]:
    """Parse all spec files under docs/specs/. Returns {id: SpecDef}."""
    specs: Dict[str, SpecDef] = {}
    if not os.path.isdir(specs_dir):
        return specs

    for root, _dirs, files in os.walk(specs_dir):
        for fname in files:
            if not fname.endswith(".md"):
                continue
            path = os.path.join(root, fname)
            rel = os.path.relpath(path, start=repo_root)
            try:
                with open(path, encoding="utf-8") as f:
                    for line_no, line in enumerate(f, start=1):
                        m = SPEC_DEF_RE.match(line)
                        if not m:
                            continue
                        sid = m.group("id")
                        status_char = m.group("status").strip()
                        if status_char.lower() == "x":
                            status = "implemented"
                        elif status_char.upper() == "D":
                            status = "deferred"
                        else:
                            status = "gap"
                        specs[sid] = SpecDef(
                            id=sid,
                            status=status,
                            title=m.group("title"),
                            source_file=rel,
                            source_line=line_no,
                        )
            except OSError as exc:
                print(f"[scanner] WARN: could not read {rel}: {exc}", file=sys.stderr)

    return specs


# --- File walking -----------------------------------------------------------

DEFAULT_ROOTS = ["src", "tests", "test", "app", "lib", "pkg", "cmd", "internal", "templates", "packages"]
EXCLUDE_DIRS = {
    "node_modules", ".git", "dist", "build", ".venv", "venv", "__pycache__",
    "target", "vendor", ".next", "coverage", ".tox", ".mypy_cache", ".pytest_cache",
    ".turbo", ".cache", "out",
}
SUPPORTED_EXTS = {
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".py", ".go", ".rs", ".java", ".kt", ".swift",
    ".html", ".htm", ".vue", ".svelte",
    ".rb", ".cs", ".scala", ".c", ".h", ".cpp", ".hpp",
}


def walk_files(root: str) -> List[str]:
    """Yield repo-relative paths to all source files under any DEFAULT_ROOTS."""
    paths: List[str] = []
    for sub in DEFAULT_ROOTS:
        base = os.path.join(root, sub)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
            for fname in filenames:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in SUPPORTED_EXTS:
                    continue
                full = os.path.join(dirpath, fname)
                paths.append(os.path.relpath(full, root))
    return paths


# --- Reporting --------------------------------------------------------------

def build_report(
    specs: Dict[str, SpecDef], annotations: List[Annotation]
) -> dict:
    """Aggregate annotations + specs into a structured report."""
    spec_records: Dict[str, dict] = {}
    for sid, sdef in specs.items():
        spec_records[sid] = {
            "status": sdef.status,
            "title": sdef.title,
            "source": f"{sdef.source_file}:{sdef.source_line}",
            "code_citations": [],
            "test_citations": [],
        }

    orphans: List[dict] = []
    malformed: List[dict] = []
    helpers: List[dict] = []

    for ann in annotations:
        for raw_id in ann.ids:
            if raw_id.startswith("!MALFORMED:"):
                malformed.append({
                    "raw_id": raw_id.split(":", 1)[1],
                    "file": ann.file,
                    "line": ann.line,
                })
                continue
            entry = {
                "file": ann.file,
                "line": ann.line,
                "owner_kind": ann.owner_kind,
                "owner_name": ann.owner_name,
            }
            if raw_id not in spec_records:
                orphans.append({**entry, "id": raw_id})
                continue
            if ann.is_test_file:
                spec_records[raw_id]["test_citations"].append(entry)
            else:
                spec_records[raw_id]["code_citations"].append(entry)
        if ann.owner_kind == "none" and any(
            i for i in ann.ids if not i.startswith("!MALFORMED:") and i in spec_records
        ):
            # owner_kind == "unknown" means classification was unavailable (regex
            # fallback) — don't report those as helpers since we have no signal.
            helpers.append({
                "file": ann.file,
                "line": ann.line,
                "ids": [i for i in ann.ids if not i.startswith("!MALFORMED:")],
                "owner_kind": ann.owner_kind,
                "owner_name": ann.owner_name,
            })

    missing_tests: List[str] = []
    missing_code: List[str] = []
    for sid, rec in spec_records.items():
        if rec["status"] != "implemented":
            continue
        if rec["code_citations"] and not rec["test_citations"]:
            missing_tests.append(sid)
        if rec["test_citations"] and not rec["code_citations"]:
            missing_code.append(sid)

    specs_with_code = sum(1 for r in spec_records.values() if r["code_citations"])
    specs_with_test = sum(1 for r in spec_records.values() if r["test_citations"])

    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "summary": {
            "specs_defined": len(spec_records),
            "specs_with_code": specs_with_code,
            "specs_with_test": specs_with_test,
            "orphans": len(orphans),
            "missing_tests": len(missing_tests),
            "missing_code": len(missing_code),
            "helper_annotations": len(helpers),
            "malformed_ids": len(malformed),
        },
        "specs": spec_records,
        "orphans": orphans,
        "missing_tests": sorted(missing_tests),
        "missing_code": sorted(missing_code),
        "helper_annotations": helpers,
        "malformed_ids": malformed,
    }


def format_text(report: dict, root: str) -> str:
    s = report["summary"]
    lines = [
        f"Spec coherence report (root: {root})",
        "",
        f"  ✓ {s['specs_defined']} specs defined in docs/specs/",
        f"  ✓ {s['specs_with_code']} specs with code annotations",
        f"  ✓ {s['specs_with_test']} specs with test annotations",
        "",
    ]
    for o in report["orphans"]:
        lines.append(
            f"  ✗ ORPHAN: {o['file']}:{o['line']} cites @spec {o['id']} (not in docs/specs/)"
        )
    for sid in report["missing_tests"]:
        cites = report["specs"][sid]["code_citations"]
        first = cites[0] if cites else None
        loc = f" ({first['file']}:{first['line']})" if first else ""
        lines.append(f"  ✗ MISSING TEST: {sid} has code{loc} but no test citation")
    for sid in report["missing_code"]:
        cites = report["specs"][sid]["test_citations"]
        first = cites[0] if cites else None
        loc = f" ({first['file']}:{first['line']})" if first else ""
        lines.append(f"  ⚠ MISSING CODE: {sid} has test{loc} but no code citation")
    for h in report["helper_annotations"]:
        ids_str = ", ".join(h["ids"])
        lines.append(
            f"  ⚠ HELPER ANNOTATION: {h['file']}:{h['line']} @spec {ids_str} on owner_kind={h['owner_kind']} — annotation belongs on entry point, not helper"
        )
    for m in report["malformed_ids"]:
        lines.append(
            f"  ⚠ MALFORMED ID: {m['file']}:{m['line']} @spec {m['raw_id']} — does not match SEG-AREA-NNN format"
        )

    if not (report["orphans"] or report["missing_tests"] or report["missing_code"] or report["helper_annotations"] or report["malformed_ids"]):
        lines.append("  ✓ No issues detected.")
        lines.append("")

    lines.append("")
    lines.append(
        f"Summary: {s['orphans']} orphan(s), {s['missing_tests']} missing test(s), "
        f"{s['missing_code']} missing code, {s['helper_annotations']} helper annotation(s), "
        f"{s['malformed_ids']} malformed id(s)"
    )
    return "\n".join(lines)


# --- CLI --------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Validate @spec annotations against docs/specs/.")
    p.add_argument("--root", default=os.getcwd(), help="Repo root (default: cwd)")
    p.add_argument("--strict", action="store_true", help="Fail on missing/helper/malformed warnings, not just orphans")
    p.add_argument("--no-tree-sitter", action="store_true", help="Force regex+stdlib fallback (skip tree-sitter)")
    p.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    p.add_argument("--quiet", action="store_true", help="Suppress non-error output")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = os.path.abspath(args.root)
    specs_dir = os.path.join(root, "docs", "specs")

    specs = parse_specs(specs_dir, root)

    annotations: List[Annotation] = []
    for rel_path in walk_files(root):
        full = os.path.join(root, rel_path)
        try:
            with open(full, encoding="utf-8", errors="replace") as f:
                source = f.read()
        except OSError as exc:
            print(f"[scanner] WARN: could not read {rel_path}: {exc}", file=sys.stderr)
            continue
        if "@spec" not in source:
            continue
        try:
            file_anns = extract_annotations(rel_path, source, force_regex=args.no_tree_sitter)
        except Exception as exc:
            print(f"[scanner] WARN: extraction failed for {rel_path}: {exc}", file=sys.stderr)
            continue
        annotations.extend(file_anns)

    report = build_report(specs, annotations)
    report["root"] = root

    if args.format == "json":
        # JSON output is the data — --quiet should not suppress it, only the
        # human-readable text format.
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        if not args.quiet:
            print(format_text(report, root))

    s = report["summary"]
    if s["orphans"] > 0:
        return 1
    if args.strict and (s["missing_tests"] or s["missing_code"] or s["helper_annotations"] or s["malformed_ids"]):
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:  # noqa: BLE001 — top-level guard
        print(f"[scanner] ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
