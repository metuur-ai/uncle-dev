#!/usr/bin/env python3
"""Interactive TUI to configure .agents/uncle-dev-setup.yaml.

A curses-based, schema-driven editor for the uncle-dev project config. It walks
every item defined in scripts/uncle-dev-setup.schema.json, offers the right
input for each type (enum picker, boolean toggle, text, integer, multi-select,
list/map editors), and validates the whole document before saving.

Boundary rule: this program never reads or writes the YAML config file directly.
It loads the current config through `uncle-dev-config-write.sh --dump` and saves
through `uncle-dev-config-write.sh --write-doc` — a dedicated I/O helper kept
separate from the shared read helper (uncle-dev-config.sh) that every
skill/command/hook depends on.

Usage:
    python3 scripts/uncle-dev-configure.py
    python3 scripts/uncle-dev-configure.py --self-test   # non-interactive plumbing check

Dependencies: python3 + PyYAML + jsonschema (already required by the config
helper) and the stdlib `curses` module. No new dependencies.
"""

from __future__ import annotations

import copy
import datetime
import glob
import json
import os
import subprocess
import sys

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
HELPER = os.path.join(SCRIPT_DIR, "uncle-dev-config-write.sh")
SCHEMA_FILE = os.path.join(SCRIPT_DIR, "uncle-dev-setup.schema.json")
TEMPLATE_FILE = os.path.join(
    PROJECT_ROOT, "skills", "uncle-dev-setup", "uncle-dev-setup.template.yaml"
)

# uncle-dev lifecycle phases (the v2 per-phase companion form keys on these).
PHASES = [
    "define", "plan", "build", "verify",
    "review", "ship", "capture", "maintain",
]

_SKILLS_CACHE = None
_COMMANDS_CACHE = None


def _candidate_roots():
    """Directories that may hold a `skills/` and `commands/` tree: this repo, an
    explicit plugin root, and installed plugin locations. Lets the picker list
    real uncle-dev skills whether run from the repo or an installed plugin."""
    roots = [PROJECT_ROOT]
    env_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env_root:
        roots.append(env_root)
    home_plugins = os.path.expanduser("~/.claude/plugins")
    roots.extend(glob.glob(os.path.join(home_plugins, "*")))
    roots.extend(glob.glob(os.path.join(home_plugins, "*", "*")))
    return roots


def uncle_dev_skills():
    """All bundled uncle-dev skill names (dirs with a SKILL.md). Cached."""
    global _SKILLS_CACHE
    if _SKILLS_CACHE is None:
        found = set()
        for root in _candidate_roots():
            for md in glob.glob(os.path.join(root, "skills", "uncle-dev-*", "SKILL.md")):
                found.add(os.path.basename(os.path.dirname(md)))
        _SKILLS_CACHE = sorted(found)
    return _SKILLS_CACHE


def uncle_dev_commands():
    """All uncle-dev slash-command names (without .md). Cached."""
    global _COMMANDS_CACHE
    if _COMMANDS_CACHE is None:
        found = set()
        for root in _candidate_roots():
            for md in glob.glob(os.path.join(root, "commands", "uncle-dev-*.md")):
                found.add(os.path.basename(md)[:-3])
        _COMMANDS_CACHE = sorted(found)
    return _COMMANDS_CACHE


# Declarative section/field tree. Structure is stable (mirrors the schema's
# required lists); volatile details (enum options, integer bounds) are read
# live from the loaded schema via schema_node(), so the TUI stays in sync when
# the schema changes. Each field: (label, key-path, kind).
SECTIONS = [
    ("Project metadata", [
        ("name", ["project", "name"], "string"),
        ("setup_date", ["project", "setup_date"], "string"),
        ("type", ["project", "type"], "enum"),
        ("language", ["project", "language"], "string"),
        ("framework", ["project", "framework"], "string"),
    ]),
    ("Tool configuration", [
        ("active", ["tool", "active"], "array_enum"),
        ("agent_skills_root", ["tool", "agent_skills_root"], "string"),
    ]),
    ("Skill overrides & companions", [
        ("overrides", ["skills", "overrides"], "map_override"),
        ("companions", ["skills", "companions"], "map_companion"),
    ]),
    ("Workflow preferences", [
        ("level", ["preferences", "level"], "enum"),
        ("execution_profile", ["preferences", "execution_profile"], "enum"),
        ("sdd_required", ["preferences", "sdd_required"], "bool"),
        ("sdd_mode", ["preferences", "sdd_mode"], "enum"),
        ("tdd-mode", ["preferences", "tdd-mode"], "enum"),
        ("spec_annotations", ["preferences", "spec_annotations"], "bool"),
        ("graphify", ["preferences", "graphify"], "bool"),
        ("knowledge_capture", ["preferences", "knowledge_capture"], "bool"),
        ("destructive_guard", ["preferences", "destructive_guard"], "bool"),
        ("mutation-testing", ["preferences", "mutation-testing"], "bool"),
        ("wrap_trigger", ["preferences", "wrap_trigger"], "object"),
    ]),
    ("Hook toggles", [
        ("session_start", ["hooks", "session_start"], "bool"),
        ("pre_commit", ["hooks", "pre_commit"], "bool"),
        ("spec_coherence", ["hooks", "spec_coherence"], "bool"),
        ("openspec_guard", ["hooks", "openspec_guard"], "bool"),
        ("destructive_command_guard", ["hooks", "destructive_command_guard"], "bool"),
        ("knowledge_capture_nudge", ["hooks", "knowledge_capture_nudge"], "bool"),
        ("wrap_nudge", ["hooks", "wrap_nudge"], "bool"),
    ]),
    ("OpenSpec conventions", [
        ("change_id_format", ["openspec", "change_id_format"], "string"),
        ("required_artifacts", ["openspec", "required_artifacts"], "array_string"),
    ]),
]

# Subfields for the one nested object (preferences.wrap_trigger).
WRAP_TRIGGER_FIELDS = [
    ("enabled", ["preferences", "wrap_trigger", "enabled"], "bool"),
    ("context_window_percent", ["preferences", "wrap_trigger", "context_window_percent"], "int"),
    ("total_tokens", ["preferences", "wrap_trigger", "total_tokens"], "int"),
]


# --------------------------------------------------------------------------- #
# Config + schema helpers (no curses)
# --------------------------------------------------------------------------- #
def run_helper(args, input_text=None):
    """Invoke uncle-dev-config-write.sh from the project root; return CompletedProcess."""
    return subprocess.run(
        ["bash", HELPER, *args],
        input=input_text,
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )


def load_schema():
    with open(SCHEMA_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def schema_node(schema, path):
    """Resolve a schema node for a dotted key path, walking `properties`."""
    node = schema
    for key in path:
        node = node["properties"][key]
    return node


def load_current():
    """Return (config_dict, is_new). Empty file -> template defaults, is_new=True."""
    result = run_helper(["--dump"])
    data = {}
    if result.returncode == 0 and result.stdout.strip():
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError:
            data = {}
    if data:
        return data, False
    return template_defaults(), True


def template_defaults():
    """Seed a fresh config from the template, resolving placeholder tokens."""
    try:
        with open(TEMPLATE_FILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except OSError:
        data = {}
    proj = data.setdefault("project", {})
    if proj.get("name") in (None, "", "__PROJECT_NAME__"):
        proj["name"] = os.path.basename(PROJECT_ROOT)
    if proj.get("setup_date") in (None, "", "__SETUP_DATE__"):
        proj["setup_date"] = datetime.date.today().isoformat()
    return data


def cfg_get(cfg, path):
    node = cfg
    for key in path:
        if isinstance(node, dict) and key in node:
            node = node[key]
        else:
            return None
    return node


def cfg_set(cfg, path, value):
    node = cfg
    for key in path[:-1]:
        nxt = node.get(key)
        if not isinstance(nxt, dict):
            nxt = {}
            node[key] = nxt
        node = nxt
    node[path[-1]] = value


def value_summary(kind, value):
    """One-line display of a field's current value."""
    if kind == "bool":
        return "true" if value else "false"
    if kind == "array_enum":
        return ", ".join(value) if value else "(none)"
    if kind == "array_string":
        return f"{len(value)} item(s)" if value else "(empty)"
    if kind == "map_override":
        return f"{len(value)} override(s)" if value else "(none)"
    if kind == "map_companion":
        total = sum(len(v) for v in value.values()) if value else 0
        return f"{len(value or {})} skill(s), {total} companion(s)"
    if kind == "object":
        return "…"
    if value in (None, ""):
        return "(blank)"
    return str(value)


def save(cfg):
    """Validate + write via the helper. Return (ok, message)."""
    payload = json.dumps(cfg)
    result = run_helper(["--write-doc"], input_text=payload)
    if result.returncode == 0:
        return True, result.stdout.strip() or "written"
    return False, (result.stderr.strip() or "write failed")


# --------------------------------------------------------------------------- #
# Curses UI primitives
# --------------------------------------------------------------------------- #
def _addstr(win, y, x, text, attr=0):
    """Bounded addstr that never raises at the screen edge."""
    max_y, max_x = win.getmaxyx()
    if y < 0 or y >= max_y or x >= max_x:
        return
    win.addstr(y, x, text[: max_x - x - 1], attr)


class UI:
    def __init__(self, stdscr):
        import curses

        self.curses = curses
        self.stdscr = stdscr
        curses.curs_set(0)
        try:
            curses.set_escdelay(25)  # make ESC-to-cancel feel instant
        except (AttributeError, curses.error):
            pass
        curses.use_default_colors()
        try:
            curses.init_pair(1, curses.COLOR_CYAN, -1)
            curses.init_pair(2, curses.COLOR_GREEN, -1)
            curses.init_pair(3, curses.COLOR_RED, -1)
            curses.init_pair(4, curses.COLOR_YELLOW, -1)
        except curses.error:
            pass

    def color(self, n):
        return self.curses.color_pair(n)

    def menu(self, title, items, footer="↑/↓ move · Enter select · q back", subtitle=None):
        """Generic scrollable menu. items: list of (label, value_str). Returns index or None."""
        curses = self.curses
        idx = 0
        top = 0
        while True:
            self.stdscr.erase()
            max_y, max_x = self.stdscr.getmaxyx()
            _addstr(self.stdscr, 0, 2, title, self.color(1) | curses.A_BOLD)
            header_lines = 2
            if subtitle:
                _addstr(self.stdscr, 1, 2, subtitle, curses.A_DIM)
                header_lines = 3
            body_h = max_y - header_lines - 1
            if idx < top:
                top = idx
            elif idx >= top + body_h:
                top = idx - body_h + 1
            for row, i in enumerate(range(top, min(len(items), top + body_h))):
                label, val = items[i]
                y = header_lines + row
                attr = curses.A_REVERSE if i == idx else 0
                line = label if val is None else f"{label:<34}{val}"
                _addstr(self.stdscr, y, 2, "  " + line, attr)
            _addstr(self.stdscr, max_y - 1, 2, footer, curses.A_DIM)
            self.stdscr.refresh()

            key = self.stdscr.getch()
            if key in (curses.KEY_UP, ord("k")):
                idx = (idx - 1) % len(items) if items else 0
            elif key in (curses.KEY_DOWN, ord("j")):
                idx = (idx + 1) % len(items) if items else 0
            elif key in (curses.KEY_ENTER, 10, 13):
                return idx if items else None
            elif key in (ord("q"), 27):  # q or ESC
                return None

    def pick(self, title, options, subtitle=None):
        """Searchable single-choice picker. Type to filter, ↑/↓ to move,
        Enter to select, ESC to cancel. Returns the chosen string or None."""
        curses = self.curses
        flt = ""
        idx = 0
        top = 0
        footer = "type to filter · ↑/↓ move · Enter select · ESC cancel"
        while True:
            filtered = [o for o in options if flt.lower() in o.lower()]
            if idx >= len(filtered):
                idx = max(0, len(filtered) - 1)
            self.stdscr.erase()
            max_y, max_x = self.stdscr.getmaxyx()
            _addstr(self.stdscr, 0, 2, title, self.color(1) | curses.A_BOLD)
            hl = 2
            if subtitle:
                _addstr(self.stdscr, 1, 2, subtitle, curses.A_DIM)
                hl = 3
            _addstr(self.stdscr, hl, 2, f"filter: {flt}▏", self.color(4))
            list_top = hl + 1
            body_h = max_y - list_top - 1
            if idx < top:
                top = idx
            elif idx >= top + body_h:
                top = idx - body_h + 1
            if not filtered:
                _addstr(self.stdscr, list_top, 2, "  (no match)", curses.A_DIM)
            for row, i in enumerate(range(top, min(len(filtered), top + body_h))):
                attr = curses.A_REVERSE if i == idx else 0
                _addstr(self.stdscr, list_top + row, 2, "  " + filtered[i], attr)
            _addstr(self.stdscr, max_y - 1, 2, footer, curses.A_DIM)
            self.stdscr.refresh()

            key = self.stdscr.getch()
            if key == curses.KEY_UP:
                idx = max(0, idx - 1)
            elif key == curses.KEY_DOWN:
                idx = min(len(filtered) - 1, idx + 1) if filtered else 0
            elif key in (curses.KEY_ENTER, 10, 13):
                if filtered:
                    return filtered[idx]
            elif key == 27:  # ESC cancels
                return None
            elif key in (curses.KEY_BACKSPACE, 127, 8):
                flt = flt[:-1]
                idx = 0
            elif 32 <= key <= 126:
                flt += chr(key)
                idx = 0

    def prompt_text(self, prompt, initial=""):
        """Single-line text editor at the bottom. Enter=confirm, ESC=cancel(None)."""
        curses = self.curses
        buf = list(str(initial) if initial is not None else "")
        curses.curs_set(1)
        try:
            while True:
                max_y, max_x = self.stdscr.getmaxyx()
                _addstr(self.stdscr, max_y - 2, 2, " " * (max_x - 4))
                _addstr(self.stdscr, max_y - 1, 2, " " * (max_x - 4))
                _addstr(self.stdscr, max_y - 2, 2, prompt, self.color(4) | curses.A_BOLD)
                shown = "".join(buf)
                _addstr(self.stdscr, max_y - 1, 2, "> " + shown)
                self.stdscr.move(max_y - 1, min(4 + len(shown), max_x - 2))
                self.stdscr.refresh()
                key = self.stdscr.getch()
                if key in (curses.KEY_ENTER, 10, 13):
                    return "".join(buf)
                if key == 27:  # ESC
                    return None
                if key in (curses.KEY_BACKSPACE, 127, 8):
                    if buf:
                        buf.pop()
                elif 32 <= key <= 126:
                    buf.append(chr(key))
        finally:
            curses.curs_set(0)

    def message(self, lines, color=0):
        """Blocking message box; any key dismisses."""
        curses = self.curses
        self.stdscr.erase()
        for i, line in enumerate(lines):
            _addstr(self.stdscr, 2 + i, 4, line, self.color(color) if color else 0)
        max_y, _ = self.stdscr.getmaxyx()
        _addstr(self.stdscr, max_y - 1, 2, "press any key", curses.A_DIM)
        self.stdscr.refresh()
        self.stdscr.getch()

    def confirm(self, question):
        curses = self.curses
        while True:
            max_y, max_x = self.stdscr.getmaxyx()
            _addstr(self.stdscr, max_y - 1, 2, " " * (max_x - 4))
            _addstr(self.stdscr, max_y - 1, 2, question + " [y/n]", self.color(4))
            self.stdscr.refresh()
            key = self.stdscr.getch()
            if key in (ord("y"), ord("Y")):
                return True
            if key in (ord("n"), ord("N"), 27):
                return False


# --------------------------------------------------------------------------- #
# Field editors
# --------------------------------------------------------------------------- #
def edit_field(ui, schema, cfg, label, path, kind):
    """Dispatch to the editor for a field kind; mutate cfg in place."""
    current = cfg_get(cfg, path)
    if kind == "bool":
        cfg_set(cfg, path, not bool(current))
    elif kind == "enum":
        options = schema_node(schema, path)["enum"]
        items = [(o + ("  ← current" if o == current else ""), None) for o in options]
        sel = ui.menu(f"{label}", items, subtitle="pick one value")
        if sel is not None:
            cfg_set(cfg, path, options[sel])
    elif kind == "string":
        val = ui.prompt_text(f"{label}:", current or "")
        if val is not None:
            cfg_set(cfg, path, val)
    elif kind == "int":
        node = schema_node(schema, path)
        lo, hi = node.get("minimum"), node.get("maximum")
        hint = f"{label} (integer" + (f", {lo}..{hi}" if lo is not None else "") + "):"
        val = ui.prompt_text(hint, current if current is not None else "")
        if val is not None:
            try:
                num = int(val.strip())
            except ValueError:
                ui.message([f"'{val}' is not an integer."], color=3)
                return
            if lo is not None and num < lo or hi is not None and num > hi:
                ui.message([f"Value must be between {lo} and {hi}."], color=3)
                return
            cfg_set(cfg, path, num)
    elif kind == "array_enum":
        edit_array_enum(ui, schema, cfg, label, path)
    elif kind == "array_string":
        edit_array_string(ui, cfg, label, path)
    elif kind == "object":  # wrap_trigger
        edit_object(ui, schema, cfg, label, WRAP_TRIGGER_FIELDS)
    elif kind == "map_override":
        edit_map_override(ui, cfg, path)
    elif kind == "map_companion":
        edit_map_companion(ui, cfg, path)


def edit_array_enum(ui, schema, cfg, label, path):
    curses = ui.curses
    options = schema_node(schema, path)["items"]["enum"]
    selected = set(cfg_get(cfg, path) or [])
    idx = 0
    while True:
        ui.stdscr.erase()
        _addstr(ui.stdscr, 0, 2, f"{label} — space toggles", ui.color(1) | curses.A_BOLD)
        for i, opt in enumerate(options):
            mark = "[x]" if opt in selected else "[ ]"
            attr = curses.A_REVERSE if i == idx else 0
            _addstr(ui.stdscr, 2 + i, 2, f"  {mark} {opt}", attr)
        max_y, _ = ui.stdscr.getmaxyx()
        _addstr(ui.stdscr, max_y - 1, 2, "space toggle · Enter save · q cancel", curses.A_DIM)
        ui.stdscr.refresh()
        key = ui.stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(options)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(options)
        elif key == ord(" "):
            opt = options[idx]
            selected.discard(opt) if opt in selected else selected.add(opt)
        elif key in (curses.KEY_ENTER, 10, 13):
            cfg_set(cfg, path, [o for o in options if o in selected])
            return
        elif key in (ord("q"), 27):
            return


def edit_array_string(ui, cfg, label, path):
    # Custom loop rather than ui.menu() because we need a/d keys for add/delete.
    items_list = list(cfg_get(cfg, path) or [])
    curses = ui.curses
    idx = 0
    while True:
        ui.stdscr.erase()
        _addstr(ui.stdscr, 0, 2, label, ui.color(1) | curses.A_BOLD)
        _addstr(ui.stdscr, 1, 2, "Enter edit · a add · d delete · q done", curses.A_DIM)
        rows = items_list + ["[+ add item]"]
        for i, s in enumerate(rows):
            attr = curses.A_REVERSE if i == idx else 0
            _addstr(ui.stdscr, 3 + i, 2, f"  {s}", attr)
        ui.stdscr.refresh()
        key = ui.stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(rows)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(rows)
        elif key in (ord("a"),) or (key in (curses.KEY_ENTER, 10, 13) and idx == len(items_list)):
            val = ui.prompt_text("new item:", "")
            if val:
                items_list.append(val)
                idx = len(items_list) - 1
        elif key in (curses.KEY_ENTER, 10, 13):
            val = ui.prompt_text("edit item:", items_list[idx])
            if val is not None and val != "":
                items_list[idx] = val
        elif key == ord("d") and idx < len(items_list):
            items_list.pop(idx)
            idx = max(0, idx - 1)
        elif key in (ord("q"), 27):
            cfg_set(cfg, path, items_list)
            return


def edit_object(ui, schema, cfg, label, subfields):
    while True:
        items = []
        for slabel, spath, skind in subfields:
            items.append((slabel, value_summary(skind, cfg_get(cfg, spath))))
        items.append(("← done", None))
        sel = ui.menu(label, items, subtitle="nested object")
        if sel is None or sel == len(subfields):
            return
        slabel, spath, skind = subfields[sel]
        edit_field(ui, schema, cfg, slabel, spath, skind)


def pick_target(ui, categories, allow_manual=True):
    """Pick a base target from one or more categories of options.

    categories: ordered dict-like {label: [names]}. With a single category and
    no manual entry, goes straight to the picker. Otherwise shows a category
    chooser first. ESC/cancel at the top level returns None (aborts). ESC inside
    an item picker steps back to the category chooser. Returns the chosen string
    or None.
    """
    cats = [(lbl, items) for lbl, items in categories.items() if items]
    if len(cats) == 1 and not allow_manual:
        return ui.pick(cats[0][0], cats[0][1], subtitle="type to filter")
    while True:
        menu_items = [(f"{lbl}", f"{len(items)}") for lbl, items in cats]
        if allow_manual:
            menu_items.append(("✎ type manually…", None))
        menu_items.append(("← cancel", None))
        sel = ui.menu("Choose base — pick a category", menu_items,
                      subtitle="skills are loaded by the runtime; commands/phases are advisory")
        if sel is None or sel == len(menu_items) - 1:
            return None
        if allow_manual and sel == len(cats):
            val = ui.prompt_text("base name (manual):", "")
            if val:
                return val
            continue
        lbl, items = cats[sel]
        chosen = ui.pick(f"Choose from {lbl}", items, subtitle="type to filter · ESC back")
        if chosen is not None:
            return chosen


def _prompt_path_name(ui, path_initial="", name_initial=""):
    """Shared prompt for override/companion entries. Returns dict or None."""
    p = ui.prompt_text(
        "path to SKILL.md, e.g. .agents/skills/team-tdd-rules/SKILL.md:",
        path_initial,
    )
    if not p:
        return None
    n = ui.prompt_text("short name (optional), e.g. team-tdd-rules:", name_initial)
    entry = {"path": p}
    if n:
        entry["name"] = n
    return entry


def edit_map_override(ui, cfg, path):
    """skills.overrides — map of base-skill -> {path, name}."""
    mapping = dict(cfg_get(cfg, path) or {})
    curses = ui.curses
    idx = 0
    while True:
        keys = list(mapping.keys())
        rows = [f"{k}  →  {mapping[k].get('path', '')}" for k in keys] + ["[+ add override]"]
        ui.stdscr.erase()
        _addstr(ui.stdscr, 0, 2, "skills.overrides", ui.color(1) | curses.A_BOLD)
        _addstr(ui.stdscr, 1, 2, "Enter edit · a add · d delete · q done", curses.A_DIM)
        for i, r in enumerate(rows):
            attr = curses.A_REVERSE if i == idx else 0
            _addstr(ui.stdscr, 3 + i, 2, f"  {r}", attr)
        ui.stdscr.refresh()
        key = ui.stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(rows)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(rows)
        elif key == ord("a") or (key in (curses.KEY_ENTER, 10, 13) and idx == len(keys)):
            base = pick_target(ui, {"Skills": uncle_dev_skills()}, allow_manual=True)
            if base:
                entry = _prompt_path_name(ui)
                if entry:
                    mapping[base] = entry
                    idx = len(mapping) - 1
        elif key in (curses.KEY_ENTER, 10, 13):
            k = keys[idx]
            entry = _prompt_path_name(ui, mapping[k].get("path", ""), mapping[k].get("name", ""))
            if entry:
                mapping[k] = entry
        elif key == ord("d") and idx < len(keys):
            del mapping[keys[idx]]
            idx = max(0, idx - 1)
        elif key in (ord("q"), 27):
            cfg_set(cfg, path, mapping)
            return


def edit_map_companion(ui, cfg, path):
    """skills.companions — map of base-skill -> [ {path, name}, ... ]."""
    mapping = {k: list(v) for k, v in (cfg_get(cfg, path) or {}).items()}
    curses = ui.curses
    idx = 0
    while True:
        keys = list(mapping.keys())
        rows = [f"{k}  ({len(mapping[k])} companion)" for k in keys] + ["[+ add base skill]"]
        ui.stdscr.erase()
        _addstr(ui.stdscr, 0, 2, "skills.companions", ui.color(1) | curses.A_BOLD)
        _addstr(ui.stdscr, 1, 2, "Enter open · a add skill · d delete · q done", curses.A_DIM)
        for i, r in enumerate(rows):
            attr = curses.A_REVERSE if i == idx else 0
            _addstr(ui.stdscr, 3 + i, 2, f"  {r}", attr)
        ui.stdscr.refresh()
        key = ui.stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(rows)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(rows)
        elif key == ord("a") or (key in (curses.KEY_ENTER, 10, 13) and idx == len(keys)):
            base = pick_target(ui, {
                "Skills": uncle_dev_skills(),
                "Commands": uncle_dev_commands(),
                "Phases": PHASES,
            }, allow_manual=True)
            if base and base not in mapping:
                mapping[base] = []
                idx = len(mapping) - 1
        elif key in (curses.KEY_ENTER, 10, 13):
            k = keys[idx]
            _edit_companion_entries(ui, mapping[k], k)
            if not mapping[k]:  # drop empty keys
                del mapping[k]
                idx = max(0, idx - 1)
        elif key == ord("d") and idx < len(keys):
            del mapping[keys[idx]]
            idx = max(0, idx - 1)
        elif key in (ord("q"), 27):
            cfg_set(cfg, path, mapping)
            return


def _edit_companion_entries(ui, entries, base):
    """Edit the list of {path,name} companions for one base skill, in place."""
    curses = ui.curses
    idx = 0
    while True:
        rows = [f"{e.get('name') or '(no name)'}  →  {e.get('path', '')}" for e in entries]
        rows.append("[+ add companion]")
        ui.stdscr.erase()
        _addstr(ui.stdscr, 0, 2, f"companions for {base}", ui.color(1) | curses.A_BOLD)
        _addstr(ui.stdscr, 1, 2, "Enter edit · a add · d delete · q back", curses.A_DIM)
        for i, r in enumerate(rows):
            attr = curses.A_REVERSE if i == idx else 0
            _addstr(ui.stdscr, 3 + i, 2, f"  {r}", attr)
        ui.stdscr.refresh()
        key = ui.stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(rows)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(rows)
        elif key == ord("a") or (key in (curses.KEY_ENTER, 10, 13) and idx == len(entries)):
            entry = _prompt_path_name(ui)
            if entry:
                entries.append(entry)
                idx = len(entries) - 1
        elif key in (curses.KEY_ENTER, 10, 13):
            e = entries[idx]
            entry = _prompt_path_name(ui, e.get("path", ""), e.get("name", ""))
            if entry:
                entries[idx] = entry
        elif key == ord("d") and idx < len(entries):
            entries.pop(idx)
            idx = max(0, idx - 1)
        elif key in (ord("q"), 27):
            return


# --------------------------------------------------------------------------- #
# Top-level screens
# --------------------------------------------------------------------------- #
def section_screen(ui, schema, cfg, title, fields):
    while True:
        items = [(label, value_summary(kind, cfg_get(cfg, path))) for label, path, kind in fields]
        items.append(("← back", None))
        sel = ui.menu(title, items, subtitle="Enter to edit a field")
        if sel is None or sel == len(fields):
            return
        label, path, kind = fields[sel]
        edit_field(ui, schema, cfg, label, path, kind)


def main_tui(stdscr, schema, cfg, is_new):
    ui = UI(stdscr)
    saved_snapshot = copy.deepcopy(cfg)
    while True:
        dirty = cfg != saved_snapshot
        state = "NEW config (unsaved)" if is_new else ("modified" if dirty else "saved")
        items = [(name, f"{len(fields)} items") for name, fields in SECTIONS]
        items.append(("💾  Save & validate", None))
        items.append(("✗  Quit", None))
        sel = ui.menu(
            "uncle-dev setup configurator",
            items,
            subtitle=f".agents/uncle-dev-setup.yaml — {state}",
        )
        if sel is None:  # ESC/q at top level = quit path
            sel = len(SECTIONS) + 1
        if sel < len(SECTIONS):
            name, fields = SECTIONS[sel]
            section_screen(ui, schema, cfg, name, fields)
        elif sel == len(SECTIONS):  # save
            ok, msg = save(cfg)
            if ok:
                saved_snapshot = copy.deepcopy(cfg)
                is_new = False
                ui.message(["Saved to .agents/uncle-dev-setup.yaml", f"({msg})"], color=2)
            else:
                ui.message(["Validation failed — not saved:", "", msg], color=3)
        else:  # quit
            if cfg != saved_snapshot:
                if not ui.confirm("Discard unsaved changes?"):
                    continue
            return


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #
def self_test():
    """Non-interactive plumbing check: schema loads, tree resolves, round-trip works."""
    schema = load_schema()
    # Every field path must resolve in the schema (except additionalProperties maps).
    for _name, fields in SECTIONS:
        for label, path, kind in fields:
            if kind in ("map_override", "map_companion"):
                continue
            schema_node(schema, path)  # raises KeyError if the tree drifts
    for _l, spath, _k in WRAP_TRIGGER_FIELDS:
        schema_node(schema, spath)
    cfg, is_new = load_current()
    assert isinstance(cfg, dict) and cfg, "loaded config is empty"
    ok, msg = save(cfg)
    assert ok, f"round-trip save failed: {msg}"
    print(f"self-test OK (is_new={is_new}, save={msg}, sections={len(SECTIONS)})")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if "-h" in argv or "--help" in argv:
        print(__doc__)
        return 0
    if not os.path.exists(SCHEMA_FILE):
        print(f"error: schema not found at {SCHEMA_FILE}", file=sys.stderr)
        return 1
    if not sys.stdout.isatty() or not sys.stdin.isatty():
        print("error: this is an interactive TUI; run it in a terminal "
              "(or use --self-test).", file=sys.stderr)
        return 1

    import curses

    schema = load_schema()
    cfg, is_new = load_current()
    try:
        curses.wrapper(main_tui, schema, cfg, is_new)
    except KeyboardInterrupt:
        # curses.wrapper() already restored the terminal; report cleanly.
        print("Cancelled — nothing saved (use Save & validate to persist).",
              file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
