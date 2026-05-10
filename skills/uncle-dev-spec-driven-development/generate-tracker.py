#!/usr/bin/env python3
"""
OpenSpec Tracker Generator
Auto-generates openspec/tracker/changes.yaml from:
  - openspec/changes/<id>/tasks.yaml  (metadata + system-of-record IDs)
  - openspec/changes/<id>/tasks.md    (checkbox state — source of truth)
  - openspec/changes/<id>/handoff.md  (shipped marker)
  - openspec/changes/<id>/proposal.md (## EARS Specs block — optional)

When `docs/specs/` exists in the repo, each change's `proposal.md` can declare
the EARS spec IDs it touches in an `## EARS Specs` block:

    ## EARS Specs
    - Introduces: FAV-001, FAV-002
    - Modifies: AUTH-005

The tracker invokes the spec coherence scanner and emits a `spec_coverage`
field per change with declared/with_code/with_test/coverage_pct/missing.

Usage:
  python3 generate-tracker.py --project /full/path/to/project/openspec
  python3 generate-tracker.py --project /full/path/to/project/openspec --with-spec-graph
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

# --- Args -------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate openspec/tracker/changes.yaml from tasks.md + tasks.yaml"
    )
    parser.add_argument(
        "--project",
        required=True,
        metavar="PATH",
        help="Absolute path to the project's openspec/ directory",
    )
    parser.add_argument(
        "--with-spec-graph",
        action="store_true",
        help="Also regenerate the spec graph artifacts in docs/arrows/ (requires docs/specs/)",
    )
    return parser.parse_args()

# --- Paths ------------------------------------------------------------------

def resolve_paths(openspec_dir):
    openspec_dir = os.path.abspath(openspec_dir)
    return {
        "changes": os.path.join(openspec_dir, "changes"),
        "tracker": os.path.join(openspec_dir, "tracker"),
        "output":  os.path.join(openspec_dir, "tracker", "changes.yaml"),
    }

# --- Parsers ----------------------------------------------------------------

def count_checkboxes(text):
    """Return (done, total) checkbox counts from markdown text."""
    done = len(re.findall(r"- \[x\]", text, re.IGNORECASE))
    pending = len(re.findall(r"- \[ \]", text))
    return done, done + pending


def derive_status(criteria_done, criteria_total, handoff_text):
    handoff_lower = handoff_text.lower()
    if "status: complete" in handoff_lower or "status: shipped" in handoff_lower:
        return "shipped"
    if criteria_done == 0:
        return "not_started"
    if criteria_done >= criteria_total:
        return "done"
    return "in_progress"


def derive_phase(criteria_done, criteria_total, handoff_text):
    handoff_lower = handoff_text.lower()
    if "status: complete" in handoff_lower or "status: shipped" in handoff_lower:
        return "ship"
    if any(x in handoff_lower for x in ["ready for deployment", "pending qa", "qa verified", "implementation complete"]):
        return "verify"
    if criteria_done > 0:
        return "build"
    return "planning"


def parse_tasks_yaml(path):
    """Parse tasks.yaml — no PyYAML dependency."""
    data = {"change_id": "", "title": "", "owner": "", "created_at": "", "records": {}, "stories": []}
    if not os.path.exists(path):
        return data

    record_keys = {"jira", "github", "linear", "trello", "monday", "notion", "custom"}
    in_records = in_stories = False
    current_story = None

    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    for line in lines:
        stripped = line.rstrip()
        indent = len(line) - len(line.lstrip())

        for field in ("change_id", "title", "owner", "created_at"):
            m = re.match(rf"^{field}:\s*(.+)", stripped)
            if m:
                val = m.group(1).strip().strip('"').strip("'")
                if val not in ("~", "null", ""):
                    data[field] = val
                in_records = in_stories = False

        if re.match(r"^records:", stripped):
            in_records, in_stories = True, False
            continue
        if re.match(r"^stories:", stripped):
            in_stories, in_records = True, False
            if current_story:
                data["stories"].append(current_story)
                current_story = None
            continue

        if in_records and indent >= 2:
            for key in record_keys:
                m = re.match(rf"^\s+{key}:\s*(.+)", stripped)
                if m:
                    val = m.group(1).strip().strip('"').strip("'")
                    if val not in ("~", "null", ""):
                        data["records"][key] = val

        if in_stories:
            if re.match(r"^\s+- id:", stripped):
                if current_story:
                    data["stories"].append(current_story)
                m = re.match(r"^\s+- id:\s*(.+)", stripped)
                current_story = {"id": m.group(1).strip() if m else "", "title": ""}
            elif current_story and re.match(r"^\s+title:", stripped):
                m = re.match(r"^\s+title:\s*(.+)", stripped)
                if m:
                    current_story["title"] = m.group(1).strip().strip('"').strip("'")

    if current_story:
        data["stories"].append(current_story)

    return data


def read_file(path):
    if not os.path.exists(path):
        return ""
    with open(path, encoding="utf-8") as f:
        return f.read()


# --- Spec coverage integration --------------------------------------------

# Matches lines like "- Introduces: FAV-001, FAV-002" or "- Modifies: AUTH-005"
_EARS_BLOCK_HEADING_RE = re.compile(r"^##\s+EARS\s+Specs\s*$", re.IGNORECASE)
_EARS_LINE_RE = re.compile(
    r"^\s*-\s*(Introduces|Modifies)\s*:\s*(.+?)\s*$", re.IGNORECASE
)
_SPEC_ID_RE = re.compile(r"\b[A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*-\d+\b")


def parse_proposal_ears_block(proposal_path):
    """Extract declared spec IDs from the `## EARS Specs` block in a proposal.

    Returns a list of unique IDs (Introduces + Modifies), preserving order.
    Returns [] if the file or block is absent.
    """
    if not os.path.exists(proposal_path):
        return []
    declared = []
    seen = set()
    in_block = False
    with open(proposal_path, encoding="utf-8") as f:
        for line in f:
            stripped = line.rstrip("\n")
            if _EARS_BLOCK_HEADING_RE.match(stripped):
                in_block = True
                continue
            if in_block and stripped.startswith("## "):
                break
            if not in_block:
                continue
            m = _EARS_LINE_RE.match(stripped)
            if not m:
                continue
            for sid in _SPEC_ID_RE.findall(m.group(2)):
                if sid not in seen:
                    seen.add(sid)
                    declared.append(sid)
    return declared


def find_sibling_script(name):
    """Locate a sibling script in skills/uncle-dev-spec-annotations/."""
    here = os.path.dirname(os.path.abspath(__file__))
    sibling = os.path.normpath(os.path.join(here, "..", "uncle-dev-spec-annotations", name))
    if os.path.isfile(sibling):
        return sibling
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if plugin_root:
        candidate = os.path.join(plugin_root, "skills", "uncle-dev-spec-annotations", name)
        if os.path.isfile(candidate):
            return candidate
    return None


def run_scanner(repo_root):
    """Invoke scan-spec-coherence.py and return parsed JSON, or None if unavailable."""
    scanner = find_sibling_script("scan-spec-coherence.py")
    if not scanner:
        return None
    if not os.path.isdir(os.path.join(repo_root, "docs", "specs")):
        return None
    try:
        result = subprocess.run(
            ["python3", scanner, "--root", repo_root, "--format", "json"],
            capture_output=True, text=True, check=False, cwd=repo_root,
        )
    except OSError as exc:
        print(f"[tracker] WARN: scanner invocation failed: {exc}", file=sys.stderr)
        return None
    if not result.stdout.strip():
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        print(f"[tracker] WARN: scanner JSON parse failed: {exc}", file=sys.stderr)
        return None


def compute_spec_coverage(declared, scanner_report):
    """Build the spec_coverage block for one change.

    Returns a dict shaped per the schema:
      {declared, with_code, with_test, coverage_pct, missing}
    or None if there's nothing to compute (no declared IDs, or no scanner).
    """
    if not declared:
        return None
    if scanner_report is None:
        return None
    specs = scanner_report.get("specs", {}) or {}
    with_code = []
    with_test = []
    missing = {}
    for sid in declared:
        rec = specs.get(sid)
        if rec is None:
            # Declared but the spec catalog doesn't define it — record as a gap
            missing[sid] = ["spec_definition", "code", "test"]
            continue
        has_code = bool(rec.get("code_citations"))
        has_test = bool(rec.get("test_citations"))
        if has_code:
            with_code.append(sid)
        if has_test:
            with_test.append(sid)
        gaps = []
        if not has_code:
            gaps.append("code")
        if not has_test:
            gaps.append("test")
        if gaps:
            missing[sid] = gaps
    total_slots = len(declared) * 2  # each ID gets a code slot + test slot
    filled_slots = len(with_code) + len(with_test)
    coverage_pct = round(filled_slots / total_slots * 100) if total_slots else 0
    return {
        "declared": declared,
        "with_code": with_code,
        "with_test": with_test,
        "coverage_pct": coverage_pct,
        "missing": missing,
    }


# --- YAML writer ------------------------------------------------------------

def yaml_str(value):
    if not value:
        return '""'
    needs_quote = any(c in value for c in ':#{},&*?|<>=!%@`"\'[]\\-')
    if needs_quote:
        return f'"{value.replace(chr(34), chr(92) + chr(34))}"'
    return value


def build_yaml(entries):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    lines = [
        "# AUTO-GENERATED — do not edit.",
        f"# Run: python3 <plugin>/generate-tracker.py --project /path/to/openspec",
        f"# Last generated: {now}",
        "",
        "changes:",
    ]

    for change_id in sorted(entries.keys()):
        e = entries[change_id]
        lines.append(f"  {change_id}:")
        lines.append(f"    title: {yaml_str(e['title'] or change_id)}")
        lines.append(f"    status: {e['status']}")
        lines.append(f"    phase: {e['phase']}")
        if e["owner"]:
            lines.append(f"    owner: {yaml_str(e['owner'])}")
        lines.append(f"    criteria_done: {e['criteria_done']}")
        lines.append(f"    criteria_total: {e['criteria_total']}")
        if e["records"]:
            lines.append("    records:")
            for k, v in e["records"].items():
                lines.append(f"      {k}: {yaml_str(v)}")
        if e["created_at"]:
            lines.append(f"    created_at: {yaml_str(e['created_at'])}")
        lines.append(f"    updated_at: {today}")
        cov = e.get("spec_coverage")
        if cov is None:
            lines.append("    spec_coverage: null")
        else:
            lines.append("    spec_coverage:")
            lines.append(f"      declared: [{', '.join(cov['declared'])}]")
            lines.append(f"      with_code: [{', '.join(cov['with_code'])}]")
            lines.append(f"      with_test: [{', '.join(cov['with_test'])}]")
            lines.append(f"      coverage_pct: {cov['coverage_pct']}")
            if cov["missing"]:
                lines.append("      missing:")
                for sid, gaps in sorted(cov["missing"].items()):
                    lines.append(f"        {sid}: [{', '.join(gaps)}]")
            else:
                lines.append("      missing: {}")
        lines.append("")

    return "\n".join(lines)


# --- Main -------------------------------------------------------------------

def main():
    args = parse_args()
    paths = resolve_paths(args.project)

    if not os.path.isdir(paths["changes"]):
        print(f"[tracker] ERROR: changes dir not found: {paths['changes']}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(paths["tracker"], exist_ok=True)

    # Scanner runs once for the whole repo; result is reused per-change.
    repo_root = os.path.dirname(os.path.abspath(args.project).rstrip(os.sep))
    scanner_report = run_scanner(repo_root)

    change_dirs = sorted(
        d for d in os.listdir(paths["changes"])
        if os.path.isdir(os.path.join(paths["changes"], d))
    )

    entries = {}
    counts = {"not_started": 0, "in_progress": 0, "done": 0, "shipped": 0}

    for change_id in change_dirs:
        change_path = os.path.join(paths["changes"], change_id)
        meta = parse_tasks_yaml(os.path.join(change_path, "tasks.yaml"))
        tasks_text = read_file(os.path.join(change_path, "tasks.md"))
        handoff_text = read_file(os.path.join(change_path, "handoff.md"))
        declared = parse_proposal_ears_block(os.path.join(change_path, "proposal.md"))

        criteria_done, criteria_total = count_checkboxes(tasks_text)
        status = derive_status(criteria_done, criteria_total, handoff_text)
        phase = derive_phase(criteria_done, criteria_total, handoff_text)
        coverage = compute_spec_coverage(declared, scanner_report)

        entries[change_id] = {
            "title": meta["title"],
            "status": status,
            "phase": phase,
            "owner": meta["owner"],
            "criteria_done": criteria_done,
            "criteria_total": criteria_total,
            "records": meta["records"],
            "created_at": meta["created_at"],
            "spec_coverage": coverage,
        }
        counts[status] = counts.get(status, 0) + 1

    yaml_content = build_yaml(entries)

    with open(paths["output"], "w", encoding="utf-8") as f:
        f.write(yaml_content)

    total = len(entries)
    coverage_count = sum(1 for e in entries.values() if e["spec_coverage"] is not None)
    print(
        f"[tracker] Regenerated: {total} changes — "
        f"{counts['shipped']} shipped, "
        f"{counts['done']} done, "
        f"{counts['in_progress']} in_progress, "
        f"{counts['not_started']} not_started"
    )
    if scanner_report is not None:
        print(f"[tracker] Spec coverage computed for {coverage_count}/{total} changes")
    print(f"[tracker] Output: {paths['output']}")

    if args.with_spec_graph:
        builder = find_sibling_script("build-spec-graph.py")
        if builder is None:
            print("[tracker] WARN: --with-spec-graph requested but build-spec-graph.py not found", file=sys.stderr)
        elif not os.path.isdir(os.path.join(repo_root, "docs")):
            print("[tracker] --with-spec-graph: skipped (no docs/ directory)")
        else:
            try:
                subprocess.run(
                    ["python3", builder, "--root", repo_root],
                    check=False, cwd=repo_root,
                )
            except OSError as exc:
                print(f"[tracker] WARN: graph builder failed: {exc}", file=sys.stderr)


if __name__ == "__main__":
    main()
