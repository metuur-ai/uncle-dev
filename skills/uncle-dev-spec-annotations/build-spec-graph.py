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
    p.add_argument("--format", choices=["json", "mermaid", "report", "all"], default="all", help="Which artifact(s) to write")
    p.add_argument("--out", default=None, help="Output dir (default: <root>/docs/arrows)")
    p.add_argument("--quiet", action="store_true", help="Suppress non-error output")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = os.path.abspath(args.root)
    out_dir = args.out or os.path.join(root, "docs", "arrows")

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
