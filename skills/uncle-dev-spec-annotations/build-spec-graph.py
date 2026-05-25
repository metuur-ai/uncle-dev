#!/usr/bin/env python3
"""Spec graph generator — fuses scanner output + arrow files + LLD/HLD into a graph.

Inputs:
  - docs/high-level-design.md     → HLD nodes (one per top-level ## section)
  - docs/arrows/index.yaml        → segment registry
  - docs/arrows/<segment>.md      → per-segment crosslinks (HLD/LLD/EARS/Tests/Code)
  - docs/llds/<segment>.md        → LLD nodes
  - docs/specs/<segment>-specs.md → EARS spec nodes (parsed by scanner)
  - Scanner JSON (scan-spec-coherence.py --format json --quiet)
                                  → @spec annotations + AST owner classifications

Outputs (all written to docs/arrows/, idempotent):
  - spec-graph.json     canonical machine-readable graph
  - spec-graph.mmd      Mermaid source
  - SPEC_GRAPH_REPORT.md  human report (segment summaries + embedded Mermaid)

Optional:
  - graphify-out/spec-edges.json (only if graphify-out/ already exists)

Usage:
  python3 build-spec-graph.py [--root .] [--format json|mermaid|report|all] [--out docs/arrows/]
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SCANNER_PATH = os.path.join(_SCRIPT_DIR, "scan-spec-coherence.py")

# --- Parsers ----------------------------------------------------------------

H2_RE = re.compile(r"^##\s+(.+?)\s*$")
SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(text: str) -> str:
    return SLUG_RE.sub("-", text.lower()).strip("-")


def parse_hld(path: str) -> List[Dict[str, str]]:
    """Each top-level `##` heading becomes one HLD topic node."""
    if not os.path.isfile(path):
        return []
    nodes: List[Dict[str, str]] = []
    with open(path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            m = H2_RE.match(line)
            if not m:
                continue
            title = m.group(1).strip()
            anchor = slugify(title)
            nodes.append({
                "id": f"hld:{anchor}",
                "type": "hld",
                "title": title,
                "source": f"{path}#{anchor}",
                "anchor": anchor,
                "line": line_no,
            })
    return nodes


def parse_arrows_index(path: str) -> Dict[str, Dict[str, Any]]:
    """Minimal YAML reader for docs/arrows/index.yaml — returns {segment: meta}.

    No PyYAML dependency. Supports the schema documented in the template:
      arrows:
        <segment>:
          status: ...
          prefix: ...
          detail: ...
          ...
    """
    if not os.path.isfile(path):
        return {}
    segments: Dict[str, Dict[str, Any]] = {}
    current_seg: Optional[str] = None
    in_arrows = False

    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    for raw in lines:
        line = raw.rstrip("\n")
        # Skip blank + comment lines
        if not line.strip() or line.strip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())

        if indent == 0 and line.startswith("arrows:"):
            in_arrows = True
            continue
        if not in_arrows:
            continue

        if indent == 2 and line.endswith(":"):
            current_seg = line.strip().rstrip(":")
            segments[current_seg] = {"_indent": 2}
            continue
        if current_seg and indent >= 4:
            m = re.match(r"^(\s+)([a-zA-Z_][a-zA-Z0-9_]*):\s*(.*)$", line)
            if m:
                key = m.group(2)
                val = m.group(3).strip().strip('"').strip("'")
                if val in ("~", "null", ""):
                    val = None
                segments[current_seg][key] = val

    for s in segments.values():
        s.pop("_indent", None)
    return segments


# Each ### heading becomes a section; bullet lines under it become refs.
ARROW_SECTION_RE = re.compile(r"^###\s+(.+?)\s*$")
ARROW_BULLET_RE = re.compile(r"^\s*-\s+(.+?)\s*$")


def parse_arrow_segment_doc(path: str) -> Dict[str, List[str]]:
    """Parse docs/arrows/<segment>.md into a {section_title: [bullet_text...]} map.

    The segment doc format from the template:
      ### HLD
      - docs/high-level-design.md#section
      ### LLD
      - docs/llds/foo.md
      ### EARS
      - docs/specs/foo-specs.md
      ### Tests
      - src/foo/foo.test.ts
      ### Code
      - src/foo/foo.ts
    """
    sections: Dict[str, List[str]] = {}
    if not os.path.isfile(path):
        return sections
    current: Optional[str] = None
    with open(path, encoding="utf-8") as f:
        for line in f:
            sm = ARROW_SECTION_RE.match(line)
            if sm:
                current = sm.group(1).strip()
                sections.setdefault(current, [])
                continue
            if current is None:
                continue
            bm = ARROW_BULLET_RE.match(line)
            if bm:
                sections[current].append(bm.group(1).strip())
    return sections


def run_scanner(root: str) -> Dict[str, Any]:
    """Invoke the spec scanner in JSON mode and return the parsed report.

    Runs the scanner with cwd=root so its os.path.relpath() output is stable
    regardless of where build-spec-graph.py was launched from.
    """
    if not os.path.isfile(SCANNER_PATH):
        return {"specs": {}, "orphans": [], "summary": {}}
    try:
        result = subprocess.run(
            ["python3", SCANNER_PATH, "--root", root, "--format", "json"],
            capture_output=True, text=True, check=False, cwd=root,
        )
    except OSError as exc:
        print(f"[graph] WARN: scanner invocation failed: {exc}", file=sys.stderr)
        return {"specs": {}, "orphans": [], "summary": {}}
    if result.stdout.strip():
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            print(f"[graph] WARN: scanner JSON parse failed: {exc}", file=sys.stderr)
    return {"specs": {}, "orphans": [], "summary": {}}


# --- Graph construction -----------------------------------------------------

def build_graph(root: str) -> Dict[str, Any]:
    """Assemble nodes + edges from all input sources."""
    docs = os.path.join(root, "docs")
    hld_path = os.path.join(docs, "high-level-design.md")
    arrows_index_path = os.path.join(docs, "arrows", "index.yaml")
    arrows_dir = os.path.join(docs, "arrows")
    llds_dir = os.path.join(docs, "llds")

    nodes: List[Dict[str, Any]] = []
    edges: List[Dict[str, Any]] = []

    # 1. HLD nodes
    hld_nodes = parse_hld(hld_path)
    nodes.extend(hld_nodes)

    # 2. Segments from arrows/index.yaml
    segments = parse_arrows_index(arrows_index_path)

    # 3. LLD nodes (one per registered segment)
    for seg_name, seg_meta in segments.items():
        lld_path = os.path.join(llds_dir, f"{seg_name}.md")
        if os.path.isfile(lld_path):
            nodes.append({
                "id": f"lld:{seg_name}",
                "type": "lld",
                "segment": seg_name,
                "title": f"LLD: {seg_name}",
                "source": os.path.relpath(lld_path, root),
                "prefix": seg_meta.get("prefix") or seg_name.upper() + "-",
            })

    # 4. Edges from arrow segment docs (HLD → LLD)
    for seg_name, seg_meta in segments.items():
        detail = seg_meta.get("detail") or f"{seg_name}.md"
        seg_doc_path = os.path.join(arrows_dir, detail)
        if not os.path.isfile(seg_doc_path):
            continue
        sections = parse_arrow_segment_doc(seg_doc_path)
        # HLD references in this segment doc → decomposes_to edges
        for hld_ref in sections.get("HLD", []):
            anchor = hld_ref.split("#", 1)[1] if "#" in hld_ref else None
            target_hld = next(
                (n for n in hld_nodes if anchor and n["anchor"] == anchor.lower()),
                None,
            )
            if target_hld and any(n["id"] == f"lld:{seg_name}" for n in nodes):
                edges.append({
                    "from": target_hld["id"],
                    "to": f"lld:{seg_name}",
                    "type": "decomposes_to",
                })

    # 5. Spec nodes + verified_by/implemented_by edges from scanner
    scanner_report = run_scanner(root)
    spec_records = scanner_report.get("specs", {}) or {}

    # Map prefix → segment for `specifies` edges
    prefix_to_segment: List[Tuple[str, str]] = []
    for seg_name, seg_meta in segments.items():
        prefix = seg_meta.get("prefix")
        if prefix:
            prefix_to_segment.append((prefix.rstrip("*").rstrip("-"), seg_name))

    def find_segment_for_id(spec_id: str) -> Optional[str]:
        # Match longest prefix first (e.g. AUTH-UI- before AUTH-)
        candidates = sorted(
            [(p, s) for p, s in prefix_to_segment if spec_id.startswith(p + "-")],
            key=lambda x: -len(x[0]),
        )
        return candidates[0][1] if candidates else None

    spec_node_ids: List[str] = []
    for spec_id, rec in spec_records.items():
        segment = find_segment_for_id(spec_id)
        gaps = []
        if rec["status"] == "implemented":
            if not rec["test_citations"]:
                gaps.append("test")
            if not rec["code_citations"]:
                gaps.append("code")
        node = {
            "id": f"spec:{spec_id}",
            "type": "spec",
            "segment": segment,
            "title": rec.get("title", spec_id),
            "status": rec.get("status", "gap"),
            "source": rec.get("source", ""),
        }
        if gaps:
            node["gaps"] = gaps
        nodes.append(node)
        spec_node_ids.append(node["id"])

        # specifies: LLD → spec
        if segment and any(n["id"] == f"lld:{segment}" for n in nodes):
            edges.append({
                "from": f"lld:{segment}",
                "to": f"spec:{spec_id}",
                "type": "specifies",
            })

        # verified_by + implemented_by from scanner
        for cite in rec.get("test_citations", []):
            test_id = f"test:{cite['file']}:{cite['line']}"
            nodes.append({
                "id": test_id,
                "type": "test",
                "source": f"{cite['file']}:{cite['line']}",
                "owner_kind": cite.get("owner_kind", ""),
                "owner_name": cite.get("owner_name", ""),
            })
            edges.append({
                "from": f"spec:{spec_id}",
                "to": test_id,
                "type": "verified_by",
            })
        for cite in rec.get("code_citations", []):
            code_id = f"code:{cite['file']}:{cite['line']}"
            nodes.append({
                "id": code_id,
                "type": "code",
                "source": f"{cite['file']}:{cite['line']}",
                "owner_kind": cite.get("owner_kind", ""),
                "owner_name": cite.get("owner_name", ""),
            })
            edges.append({
                "from": f"spec:{spec_id}",
                "to": code_id,
                "type": "implemented_by",
            })

    # 6. Deduplicate nodes by id (test/code may repeat across specs)
    seen_ids = set()
    unique_nodes = []
    for n in nodes:
        if n["id"] in seen_ids:
            continue
        seen_ids.add(n["id"])
        unique_nodes.append(n)

    orphans = scanner_report.get("orphans", [])
    summary = scanner_report.get("summary", {})

    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "nodes": unique_nodes,
        "edges": edges,
        "metadata": {
            "segment_count": len(segments),
            "spec_count": len(spec_records),
            "hld_topic_count": len(hld_nodes),
            "orphan_count": len(orphans),
            "scanner_summary": summary,
        },
        "orphans": orphans,
        "segments": segments,
    }


# --- Mermaid renderer -------------------------------------------------------

def _mmd_id(node_id: str) -> str:
    """Mermaid-safe identifier: alphanumerics + underscore."""
    return re.sub(r"[^a-zA-Z0-9_]", "_", node_id)


def _mmd_label(text: str) -> str:
    return text.replace('"', "'").replace("\n", " ")[:80]


def render_mermaid(graph: Dict[str, Any]) -> str:
    """Emit a Mermaid `graph TD` representation."""
    lines = ["graph TD"]

    # Group nodes by type for class assignment
    type_classes = {
        "hld": "hldNode",
        "lld": "lldNode",
        "spec": "specNode",
        "test": "testNode",
        "code": "codeNode",
    }

    for node in graph["nodes"]:
        nid = _mmd_id(node["id"])
        ntype = node.get("type", "")
        if ntype == "hld":
            label = f"HLD: {_mmd_label(node['title'])}"
            lines.append(f'  {nid}["{label}"]')
        elif ntype == "lld":
            label = f"LLD: {_mmd_label(node['segment'])}"
            lines.append(f'  {nid}["{label}"]')
        elif ntype == "spec":
            status = node.get("status", "")
            marker = {"implemented": "✓", "gap": "○", "deferred": "◌"}.get(status, "?")
            sid = node["id"].split(":", 1)[1]
            label = f"{marker} {sid}"
            if node.get("gaps"):
                label += f" (gap: {','.join(node['gaps'])})"
            lines.append(f'  {nid}["{label}"]')
        elif ntype == "test":
            label = _mmd_label(node["source"])
            lines.append(f'  {nid}[/"test: {label}"/]')
        elif ntype == "code":
            owner = node.get("owner_name", "") or node["source"]
            label = _mmd_label(owner)
            lines.append(f'  {nid}["code: {label}"]')

    edge_arrow = {
        "decomposes_to": "-->",
        "specifies": "-->",
        "verified_by": "-.->",
        "implemented_by": "==>",
    }
    for edge in graph["edges"]:
        f = _mmd_id(edge["from"])
        t = _mmd_id(edge["to"])
        arrow = edge_arrow.get(edge["type"], "-->")
        label = edge["type"]
        lines.append(f"  {f} {arrow}|{label}| {t}")

    # Class definitions for visual distinction
    lines.append("")
    lines.append("  classDef hldNode fill:#dbeafe,stroke:#1e40af,color:#1e3a8a")
    lines.append("  classDef lldNode fill:#dcfce7,stroke:#15803d,color:#14532d")
    lines.append("  classDef specNode fill:#fef3c7,stroke:#b45309,color:#78350f")
    lines.append("  classDef testNode fill:#f3e8ff,stroke:#7c3aed,color:#581c87")
    lines.append("  classDef codeNode fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d")

    for ntype, cls in type_classes.items():
        ids = [_mmd_id(n["id"]) for n in graph["nodes"] if n.get("type") == ntype]
        if ids:
            lines.append(f"  class {','.join(ids)} {cls}")

    return "\n".join(lines) + "\n"


# --- Report renderer --------------------------------------------------------

def render_report(graph: Dict[str, Any], mermaid: str) -> str:
    md = ["# Spec Graph Report", ""]
    md.append(f"_Generated: {graph['generated_at']}_")
    md.append("")

    meta = graph["metadata"]
    md.append("## Summary")
    md.append("")
    md.append(f"- Segments: **{meta['segment_count']}**")
    md.append(f"- HLD topics: **{meta['hld_topic_count']}**")
    md.append(f"- EARS specs: **{meta['spec_count']}**")
    md.append(f"- Orphan @spec citations: **{meta['orphan_count']}**")
    sscan = meta.get("scanner_summary") or {}
    if sscan:
        md.append(f"- Specs with code annotations: **{sscan.get('specs_with_code', 0)}** / {sscan.get('specs_defined', 0)}")
        md.append(f"- Specs with test annotations: **{sscan.get('specs_with_test', 0)}** / {sscan.get('specs_defined', 0)}")
    md.append("")

    # Per-segment breakdown
    segments = graph.get("segments", {}) or {}
    if segments:
        md.append("## Segments")
        md.append("")
        for seg_name in sorted(segments.keys()):
            seg = segments[seg_name]
            seg_specs = [n for n in graph["nodes"] if n.get("type") == "spec" and n.get("segment") == seg_name]
            implemented = sum(1 for s in seg_specs if s.get("status") == "implemented")
            gaps = sum(1 for s in seg_specs if s.get("status") == "gap")
            deferred = sum(1 for s in seg_specs if s.get("status") == "deferred")
            with_code = sum(1 for s in seg_specs if not (s.get("gaps") and "code" in s["gaps"]) and s.get("status") == "implemented")
            with_test = sum(1 for s in seg_specs if not (s.get("gaps") and "test" in s["gaps"]) and s.get("status") == "implemented")
            md.append(f"### `{seg_name}` — prefix `{seg.get('prefix', '?')}`")
            md.append("")
            md.append(f"- Status: `{seg.get('status', '?')}`")
            md.append(f"- Specs: {len(seg_specs)} total ({implemented} implemented, {gaps} gap, {deferred} deferred)")
            md.append(f"- Coverage: {with_code} with code, {with_test} with test")
            if seg.get("next"):
                md.append(f"- Next: {seg['next']}")
            md.append("")

    # Cascade impact (which specs each LLD owns)
    lld_to_specs = {}
    for node in graph["nodes"]:
        if node.get("type") == "spec" and node.get("segment"):
            lld_to_specs.setdefault(node["segment"], []).append(node["id"].split(":", 1)[1])
    if lld_to_specs:
        md.append("## Cascade Impact")
        md.append("")
        md.append("If an LLD changes, every listed spec downstream may need to change too.")
        md.append("")
        for seg, specs in sorted(lld_to_specs.items()):
            md.append(f"- **`{seg}` LLD** → {len(specs)} spec(s): {', '.join(sorted(specs))}")
        md.append("")

    # Orphans
    if graph.get("orphans"):
        md.append("## Orphans")
        md.append("")
        md.append("`@spec` citations in code/tests that point to undefined spec IDs:")
        md.append("")
        for o in graph["orphans"]:
            md.append(f"- `{o['file']}:{o['line']}` → `{o['id']}` (not in `docs/specs/`)")
        md.append("")

    # Embedded Mermaid
    md.append("## Graph")
    md.append("")
    md.append("```mermaid")
    md.append(mermaid.rstrip("\n"))
    md.append("```")
    md.append("")
    md.append("_Edge legend: HLD→LLD `decomposes_to` (solid), LLD→spec `specifies` (solid), spec→test `verified_by` (dotted), spec→code `implemented_by` (thick)._")
    md.append("")

    return "\n".join(md)


# --- HTML renderer ----------------------------------------------------------

import html as _html

_TYPE_COLORS = {
    "hld":  "#4E79A7",
    "lld":  "#59A14F",
    "spec": "#EDC948",
    "test": "#B07AA1",
    "code": "#E15759",
}

_TYPE_LABELS = {
    "hld":  "HLD Topics",
    "lld":  "LLD Segments",
    "spec": "EARS Specs",
    "test": "Test Citations",
    "code": "Code Citations",
}

_EDGE_STYLES = {
    "decomposes_to": {"dashes": False, "width": 2},
    "specifies":     {"dashes": False, "width": 2},
    "verified_by":   {"dashes": True,  "width": 1},
    "implemented_by":{"dashes": False, "width": 4},
}


def _js_safe(obj: Any) -> str:
    return json.dumps(obj).replace("</", "<\\/")


def render_html(graph: Dict[str, Any]) -> str:
    nodes = graph["nodes"]
    edges = graph["edges"]
    meta = graph.get("metadata", {})

    # Compute degree map
    degree: Dict[str, int] = {n["id"]: 0 for n in nodes}
    for e in edges:
        degree[e["from"]] = degree.get(e["from"], 0) + 1
        degree[e["to"]] = degree.get(e["to"], 0) + 1
    max_deg = max(degree.values(), default=1) or 1

    # Build vis.js node list
    vis_nodes = []
    for n in nodes:
        ntype = n.get("type", "code")
        color = _TYPE_COLORS.get(ntype, "#BAB0AC")
        deg = degree.get(n["id"], 1)
        size = 10 + 28 * (deg / max_deg)
        font_size = 12 if deg >= max_deg * 0.15 else 0

        # Human-readable label
        if ntype == "hld":
            label = n.get("title", n["id"])
        elif ntype == "lld":
            label = f"LLD: {n.get('segment', n['id'])}"
        elif ntype == "spec":
            sid = n["id"].split(":", 1)[1]
            status = n.get("status", "")
            marker = {"implemented": "✓", "gap": "○", "deferred": "◌"}.get(status, "?")
            label = f"{marker} {sid}"
        elif ntype == "test":
            label = n.get("source", n["id"])
        else:  # code
            label = n.get("owner_name") or n.get("source", n["id"])

        # Tooltip (shown on hover)
        lines = [f"<b>{_html.escape(label)}</b>", f"Type: {ntype}"]
        if n.get("status"):
            lines.append(f"Status: {n['status']}")
        if n.get("segment"):
            lines.append(f"Segment: {n['segment']}")
        if n.get("source"):
            lines.append(f"Source: {n['source']}")
        if n.get("gaps"):
            lines.append(f"Gaps: {', '.join(n['gaps'])}")
        title = "<br>".join(lines)

        vis_nodes.append({
            "id": n["id"],
            "label": label,
            "color": {
                "background": color, "border": color,
                "highlight": {"background": "#ffffff", "border": color},
            },
            "size": round(size, 1),
            "font": {"size": font_size, "color": "#ffffff"},
            "title": title,
            "_type": ntype,
            "_source": n.get("source", ""),
            "_status": n.get("status", ""),
            "_segment": n.get("segment", ""),
            "_degree": deg,
        })

    # Build vis.js edge list
    vis_edges = []
    for e in edges:
        etype = e.get("type", "")
        style = _EDGE_STYLES.get(etype, {"dashes": False, "width": 1})
        vis_edges.append({
            "from": e["from"],
            "to": e["to"],
            "title": _html.escape(etype),
            "dashes": style["dashes"],
            "width": style["width"],
            "color": {"opacity": 0.7},
            "arrows": {"to": {"enabled": True, "scaleFactor": 0.5}},
        })

    # Legend: one entry per node type that actually appears
    type_counts: Dict[str, int] = {}
    for n in nodes:
        t = n.get("type", "code")
        type_counts[t] = type_counts.get(t, 0) + 1
    legend_data = [
        {"tid": t, "color": _TYPE_COLORS.get(t, "#BAB0AC"),
         "label": _TYPE_LABELS.get(t, t), "count": type_counts[t]}
        for t in ("hld", "lld", "spec", "test", "code")
        if t in type_counts
    ]

    nodes_json = _js_safe(vis_nodes)
    edges_json = _js_safe(vis_edges)
    legend_json = _js_safe(legend_data)
    n_nodes = len(nodes)
    n_edges = len(edges)
    n_types = len(type_counts)
    stats = f"{n_nodes} nodes &middot; {n_edges} edges &middot; {n_types} types"

    styles = """<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #0f0f1a; color: #e0e0e0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; display: flex; height: 100vh; overflow: hidden; }
  #graph { flex: 1; }
  #sidebar { width: 280px; background: #1a1a2e; border-left: 1px solid #2a2a4e; display: flex; flex-direction: column; overflow: hidden; }
  #search-wrap { padding: 12px; border-bottom: 1px solid #2a2a4e; }
  #search { width: 100%; background: #0f0f1a; border: 1px solid #3a3a5e; color: #e0e0e0; padding: 7px 10px; border-radius: 6px; font-size: 13px; outline: none; }
  #search:focus { border-color: #4E79A7; }
  #search-results { max-height: 140px; overflow-y: auto; padding: 4px 12px; border-bottom: 1px solid #2a2a4e; display: none; }
  .search-item { padding: 4px 6px; cursor: pointer; border-radius: 4px; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .search-item:hover { background: #2a2a4e; }
  #info-panel { padding: 14px; border-bottom: 1px solid #2a2a4e; min-height: 140px; }
  #info-panel h3 { font-size: 13px; color: #aaa; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.05em; }
  #info-content { font-size: 13px; color: #ccc; line-height: 1.6; }
  #info-content .field { margin-bottom: 5px; }
  #info-content .field b { color: #e0e0e0; }
  #info-content .empty { color: #555; font-style: italic; }
  .neighbor-link { display: block; padding: 2px 6px; margin: 2px 0; border-radius: 3px; cursor: pointer; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; border-left: 3px solid #333; }
  .neighbor-link:hover { background: #2a2a4e; }
  #neighbors-list { max-height: 160px; overflow-y: auto; margin-top: 4px; }
  #legend-wrap { flex: 1; overflow-y: auto; padding: 12px; }
  #legend-wrap h3 { font-size: 13px; color: #aaa; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .legend-item { display: flex; align-items: center; gap: 8px; padding: 4px 0; cursor: pointer; border-radius: 4px; font-size: 12px; }
  .legend-item:hover { background: #2a2a4e; padding-left: 4px; }
  .legend-item.dimmed { opacity: 0.35; }
  .legend-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }
  .legend-label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .legend-count { color: #666; font-size: 11px; }
  #stats { padding: 10px 14px; border-top: 1px solid #2a2a4e; font-size: 11px; color: #555; }
  #legend-controls { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; padding: 4px 0; }
  #legend-controls label { display: flex; align-items: center; gap: 6px; cursor: pointer; font-size: 12px; color: #aaa; user-select: none; }
  .legend-cb, #select-all-cb { appearance: none; -webkit-appearance: none; width: 14px; height: 14px; border: 1.5px solid #3a3a5e; border-radius: 3px; background: #0f0f1a; cursor: pointer; position: relative; flex-shrink: 0; }
  .legend-cb:checked, #select-all-cb:checked { background: #4E79A7; border-color: #4E79A7; }
  .legend-cb:checked::after, #select-all-cb:checked::after { content: ''; position: absolute; left: 3.5px; top: 1px; width: 4px; height: 7px; border: solid #fff; border-width: 0 2px 2px 0; transform: rotate(45deg); }
  #select-all-cb:indeterminate { background: #4E79A7; border-color: #4E79A7; }
  #select-all-cb:indeterminate::after { content: ''; position: absolute; left: 2px; top: 5px; width: 8px; height: 2px; background: #fff; border: none; transform: none; }
  #edge-legend { padding: 8px 14px; border-top: 1px solid #2a2a4e; font-size: 11px; color: #666; }
  #edge-legend div { margin-bottom: 3px; display: flex; align-items: center; gap: 6px; }
  .edge-line { display: inline-block; width: 24px; height: 2px; background: #888; }
  .edge-line.dashed { background: repeating-linear-gradient(90deg,#888 0,#888 4px,transparent 4px,transparent 8px); }
  .edge-line.thick { height: 4px; background: #888; }
</style>"""

    script = f"""<script>
const RAW_NODES = {nodes_json};
const RAW_EDGES = {edges_json};
const LEGEND = {legend_json};

function esc(s) {{
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}}

const nodesDS = new vis.DataSet(RAW_NODES.map(n => ({{
  id: n.id, label: n.label, color: n.color, size: n.size,
  font: n.font, title: n.title,
  _type: n._type, _source: n._source, _status: n._status,
  _segment: n._segment, _degree: n._degree,
}})));

const edgesDS = new vis.DataSet(RAW_EDGES.map((e, i) => ({{
  id: i, from: e.from, to: e.to,
  title: e.title, dashes: e.dashes, width: e.width,
  color: e.color, arrows: e.arrows,
}})));

const container = document.getElementById('graph');
const network = new vis.Network(container, {{ nodes: nodesDS, edges: edgesDS }}, {{
  physics: {{
    enabled: true,
    solver: 'forceAtlas2Based',
    forceAtlas2Based: {{
      gravitationalConstant: -60,
      centralGravity: 0.005,
      springLength: 120,
      springConstant: 0.08,
      damping: 0.4,
      avoidOverlap: 0.8,
    }},
    stabilization: {{ iterations: 200, fit: true }},
  }},
  interaction: {{ hover: true, tooltipDelay: 100, hideEdgesOnDrag: true }},
  nodes: {{ shape: 'dot', borderWidth: 1.5 }},
  edges: {{ smooth: {{ type: 'continuous', roundness: 0.2 }}, selectionWidth: 3 }},
}});

network.once('stabilizationIterationsDone', () => {{
  network.setOptions({{ physics: {{ enabled: false }} }});
}});

function showInfo(nodeId) {{
  const n = nodesDS.get(nodeId);
  if (!n) return;
  const neighborIds = network.getConnectedNodes(nodeId);
  const neighborItems = neighborIds.map(nid => {{
    const nb = nodesDS.get(nid);
    const color = nb ? nb.color.background : '#555';
    return `<span class="neighbor-link" style="border-left-color:${{esc(color)}}" onclick="focusNode(${{JSON.stringify(nid)}})">${{esc(nb ? nb.label : nid)}}</span>`;
  }}).join('');
  document.getElementById('info-content').innerHTML = `
    <div class="field"><b>${{esc(n.label)}}</b></div>
    <div class="field">Type: ${{esc(n._type)}}</div>
    ${{n._status ? `<div class="field">Status: ${{esc(n._status)}}</div>` : ''}}
    ${{n._segment ? `<div class="field">Segment: ${{esc(n._segment)}}</div>` : ''}}
    ${{n._source ? `<div class="field">Source: ${{esc(n._source)}}</div>` : ''}}
    <div class="field">Degree: ${{n._degree}}</div>
    ${{neighborIds.length ? `<div class="field" style="margin-top:8px;color:#aaa;font-size:11px">Neighbors (${{neighborIds.length}})</div><div id="neighbors-list">${{neighborItems}}</div>` : ''}}
  `;
}}

function focusNode(nodeId) {{
  network.focus(nodeId, {{ scale: 1.4, animation: true }});
  network.selectNodes([nodeId]);
  showInfo(nodeId);
}}

let hoveredNodeId = null;
network.on('hoverNode', params => {{ hoveredNodeId = params.node; container.style.cursor = 'pointer'; }});
network.on('blurNode', () => {{ hoveredNodeId = null; container.style.cursor = 'default'; }});
container.addEventListener('click', () => {{
  if (hoveredNodeId !== null) {{ showInfo(hoveredNodeId); network.selectNodes([hoveredNodeId]); }}
}});
network.on('click', params => {{
  if (params.nodes.length > 0) {{ showInfo(params.nodes[0]); }}
  else if (hoveredNodeId === null) {{
    document.getElementById('info-content').innerHTML = '<span class="empty">Click a node to inspect it</span>';
  }}
}});

const searchInput = document.getElementById('search');
const searchResults = document.getElementById('search-results');
searchInput.addEventListener('input', () => {{
  const q = searchInput.value.toLowerCase().trim();
  searchResults.innerHTML = '';
  if (!q) {{ searchResults.style.display = 'none'; return; }}
  const matches = RAW_NODES.filter(n => n.label.toLowerCase().includes(q)).slice(0, 20);
  if (!matches.length) {{ searchResults.style.display = 'none'; return; }}
  searchResults.style.display = 'block';
  matches.forEach(n => {{
    const el = document.createElement('div');
    el.className = 'search-item';
    el.textContent = n.label;
    el.style.borderLeft = `3px solid ${{n.color.background}}`;
    el.style.paddingLeft = '8px';
    el.onclick = () => {{
      network.focus(n.id, {{ scale: 1.5, animation: true }});
      network.selectNodes([n.id]);
      showInfo(n.id);
      searchResults.style.display = 'none';
      searchInput.value = '';
    }};
    searchResults.appendChild(el);
  }});
}});
document.addEventListener('click', e => {{
  if (!searchResults.contains(e.target) && e.target !== searchInput)
    searchResults.style.display = 'none';
}});

const hiddenTypes = new Set();
const selectAllCb = document.getElementById('select-all-cb');

function updateSelectAllState() {{
  const total = LEGEND.length;
  const hidden = hiddenTypes.size;
  selectAllCb.checked = hidden === 0;
  selectAllCb.indeterminate = hidden > 0 && hidden < total;
}}

function toggleAll(hide) {{
  document.querySelectorAll('.legend-item').forEach(item => hide ? item.classList.add('dimmed') : item.classList.remove('dimmed'));
  document.querySelectorAll('.legend-cb').forEach(cb => {{ cb.checked = !hide; }});
  LEGEND.forEach(c => {{ if (hide) hiddenTypes.add(c.tid); else hiddenTypes.delete(c.tid); }});
  nodesDS.update(RAW_NODES.map(n => ({{ id: n.id, hidden: hide }})));
  updateSelectAllState();
}}

const legendEl = document.getElementById('legend');
LEGEND.forEach(c => {{
  const item = document.createElement('div');
  item.className = 'legend-item';
  const cb = document.createElement('input');
  cb.type = 'checkbox'; cb.className = 'legend-cb'; cb.checked = true;
  cb.addEventListener('change', (e) => {{
    e.stopPropagation();
    if (cb.checked) {{ hiddenTypes.delete(c.tid); item.classList.remove('dimmed'); }}
    else {{ hiddenTypes.add(c.tid); item.classList.add('dimmed'); }}
    nodesDS.update(RAW_NODES.filter(n => n._type === c.tid).map(n => ({{ id: n.id, hidden: !cb.checked }})));
    updateSelectAllState();
  }});
  item.innerHTML = `<div class="legend-dot" style="background:${{c.color}}"></div>
    <span class="legend-label">${{c.label}}</span>
    <span class="legend-count">${{c.count}}</span>`;
  item.prepend(cb);
  item.onclick = (e) => {{ if (e.target === cb) return; cb.checked = !cb.checked; cb.dispatchEvent(new Event('change')); }};
  legendEl.appendChild(item);
}});
</script>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Spec Graph</title>
<script src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
{styles}
</head>
<body>
<div id="graph"></div>
<div id="sidebar">
  <div id="search-wrap">
    <input id="search" type="text" placeholder="Search nodes..." autocomplete="off">
    <div id="search-results"></div>
  </div>
  <div id="info-panel">
    <h3>Node Info</h3>
    <div id="info-content"><span class="empty">Click a node to inspect it</span></div>
  </div>
  <div id="legend-wrap">
    <h3>Node Types</h3>
    <div id="legend-controls">
      <label><input type="checkbox" id="select-all-cb" checked onchange="toggleAll(!this.checked)">Select All</label>
    </div>
    <div id="legend"></div>
  </div>
  <div id="edge-legend">
    <div><span class="edge-line"></span> decomposes_to / specifies</div>
    <div><span class="edge-line dashed"></span> verified_by</div>
    <div><span class="edge-line thick"></span> implemented_by</div>
  </div>
  <div id="stats">{stats}</div>
</div>
{script}
</body>
</html>"""


# --- Outputs ----------------------------------------------------------------

def write_outputs(graph: Dict[str, Any], out_dir: str, formats: List[str]) -> List[str]:
    os.makedirs(out_dir, exist_ok=True)
    written: List[str] = []

    if "json" in formats or "all" in formats:
        path = os.path.join(out_dir, "spec-graph.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(graph, f, indent=2, sort_keys=True)
            f.write("\n")
        written.append(path)

    mermaid = render_mermaid(graph)
    if "mermaid" in formats or "all" in formats:
        path = os.path.join(out_dir, "spec-graph.mmd")
        with open(path, "w", encoding="utf-8") as f:
            f.write(mermaid)
        written.append(path)

    if "report" in formats or "all" in formats:
        report = render_report(graph, mermaid)
        path = os.path.join(out_dir, "SPEC_GRAPH_REPORT.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(report)
        written.append(path)

    if "html" in formats or "all" in formats:
        path = os.path.join(out_dir, "spec-graph.html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(render_html(graph))
        written.append(path)

    return written


def write_graphify_projection(graph: Dict[str, Any], root: str) -> Optional[str]:
    """If graphify-out/ already exists, write a projection of spec edges into it."""
    g_dir = os.path.join(root, "graphify-out")
    if not os.path.isdir(g_dir):
        return None
    projection = {
        "schema_version": 1,
        "generated_at": graph["generated_at"],
        "source": "uncle-dev-spec-annotations",
        "nodes": graph["nodes"],
        "edges": graph["edges"],
    }
    path = os.path.join(g_dir, "spec-edges.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(projection, f, indent=2, sort_keys=True)
        f.write("\n")
    return path


# --- CLI --------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Generate the @spec graph artifacts.")
    p.add_argument("--root", default=os.getcwd(), help="Repo root (default: cwd)")
    p.add_argument("--format", choices=["json", "mermaid", "report", "html", "all"], default="all", help="Which artifact(s) to write")
    p.add_argument("--out", default=None, help="Output dir (default: <root>/docs/arrows)")
    p.add_argument("--quiet", action="store_true", help="Suppress non-error output")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = os.path.abspath(args.root)
    out_dir = args.out or os.path.join(root, "graphify-out")

    docs = os.path.join(root, "docs")
    if not os.path.isdir(docs):
        if not args.quiet:
            print(f"[graph] no docs/ directory at {docs} — nothing to do.", file=sys.stderr)
        return 0

    graph = build_graph(root)
    written = write_outputs(graph, out_dir, [args.format])
    proj_path = write_graphify_projection(graph, root)

    if not args.quiet:
        meta = graph["metadata"]
        print(
            f"[graph] {meta['hld_topic_count']} HLD topics, "
            f"{meta['segment_count']} segments, "
            f"{meta['spec_count']} specs, "
            f"{len(graph['edges'])} edges, "
            f"{meta['orphan_count']} orphans"
        )
        for p in written:
            print(f"[graph] wrote {p}")
        if proj_path:
            print(f"[graph] wrote graphify projection: {proj_path}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:  # noqa: BLE001
        print(f"[graph] ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
