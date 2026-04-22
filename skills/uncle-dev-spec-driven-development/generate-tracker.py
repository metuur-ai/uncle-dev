#!/usr/bin/env python3
"""
OpenSpec Tracker Generator
Auto-generates openspec/tracker/changes.yaml from:
  - openspec/changes/<id>/tasks.yaml  (metadata + system-of-record IDs)
  - openspec/changes/<id>/tasks.md    (checkbox state — source of truth)
  - openspec/changes/<id>/handoff.md  (shipped marker)

Usage:
  python3 generate-tracker.py --project /full/path/to/project/openspec
"""

import argparse
import os
import re
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

        criteria_done, criteria_total = count_checkboxes(tasks_text)
        status = derive_status(criteria_done, criteria_total, handoff_text)
        phase = derive_phase(criteria_done, criteria_total, handoff_text)

        entries[change_id] = {
            "title": meta["title"],
            "status": status,
            "phase": phase,
            "owner": meta["owner"],
            "criteria_done": criteria_done,
            "criteria_total": criteria_total,
            "records": meta["records"],
            "created_at": meta["created_at"],
        }
        counts[status] = counts.get(status, 0) + 1

    yaml_content = build_yaml(entries)

    with open(paths["output"], "w", encoding="utf-8") as f:
        f.write(yaml_content)

    total = len(entries)
    print(
        f"[tracker] Regenerated: {total} changes — "
        f"{counts['shipped']} shipped, "
        f"{counts['done']} done, "
        f"{counts['in_progress']} in_progress, "
        f"{counts['not_started']} not_started"
    )
    print(f"[tracker] Output: {paths['output']}")


if __name__ == "__main__":
    main()
