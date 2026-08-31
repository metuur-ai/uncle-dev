#!/usr/bin/env python3
"""Rank directories by graph centrality — Step 3 triggers 3-4, graph-backed.

Usage:
    graph_criticality.py <graph.json> [--root DIR] [--target SUBPATH] [--top N]

Two signals the filesystem scan cannot produce:

  in-degree density   incoming cross-directory edges per 1k tokens. A directory
                      many modules depend on but that is itself tiny is holding
                      a constraint, not doing work. Unlike basename matching,
                      graph edges do not conflate same-named directories.

  cross-community %   share of a directory's edges that cross a community
                      boundary. This is the detector for trigger 3
                      (responsibility shifts) — where the rules above a
                      directory stop applying below it.

COVERAGE GATE: a graph that omits most of the source tree returns an empty
result that reads exactly like "no problems found". That silent-blind-spot
failure is worse than having no graph, so coverage is measured first and the
output is refused below the threshold rather than printed with a caveat.
"""

import json
import os
import sys
import collections

CODE_EXT = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".py", ".go",
            ".rs", ".java", ".rb", ".kt", ".swift", ".c", ".cpp", ".h", ".cs"}
# Vendored and generated trees must be excluded from the coverage DENOMINATOR.
# Leaving them in (e.g. ios/Pods framework headers) tanks the ratio and makes
# the gate refuse on a perfectly healthy graph — a false alarm that trains
# people to ignore the gate.
SKIP_DIR = {"node_modules", ".git", "dist", "build", ".next", "__pycache__",
            "vendor", "coverage", ".venv", "venv", "site-packages",
            "Pods", "Carthage", "DerivedData", ".gradle", "target",
            ".expo", ".dart_tool", "third_party", "bower_components",
            ".terraform", "out", ".output", "generated", "__generated__"}
COVERAGE_FLOOR = 0.60


def is_test(path):
    base = os.path.basename(path)
    return (".test." in base or ".spec." in base or base.startswith("test_")
            or base.endswith("_test.py") or "__tests__" in path
            or "/tests/" in f"/{path}")


def is_code(path):
    return bool(path) and os.path.splitext(path)[1] in CODE_EXT


def disk_code_files(root, target):
    out = set()
    base = os.path.join(root, target) if target else root
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR]
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root)
            if is_code(rel) and not is_test(rel):
                out.add(rel)
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    graph_path = sys.argv[1]
    root, target, top = ".", "", 20
    args = sys.argv[2:]
    for i, a in enumerate(args):
        if a == "--root" and i + 1 < len(args):
            root = args[i + 1]
        elif a == "--target" and i + 1 < len(args):
            target = args[i + 1].strip("/")
        elif a == "--top" and i + 1 < len(args):
            top = int(args[i + 1])

    try:
        with open(graph_path) as fh:
            g = json.load(fh)
    except Exception as exc:  # unreadable / not JSON
        print(f"graph unreadable ({exc}) — using filesystem signals only")
        return 1

    nodes = {n["id"]: n for n in g.get("nodes", []) if "id" in n}

    def src(n):
        return n.get("source_file") or ""

    def in_target(p):
        return (not target) or p.startswith(target + "/") or p == target

    graph_files = {src(n) for n in nodes.values()
                   if is_code(src(n)) and not is_test(src(n)) and in_target(src(n))}

    # ---- coverage gate -----------------------------------------------------
    on_disk = disk_code_files(root, target)
    if not on_disk:
        print(f"no code files on disk under '{target or root}' — nothing to compare")
        return 1
    covered = len(graph_files & on_disk)
    coverage = covered / len(on_disk)
    scope = target or "."
    print(f"Graph coverage of {scope}: {covered}/{len(on_disk)} code files "
          f"({coverage:.0%})")

    if coverage < COVERAGE_FLOOR:
        missing = sorted({os.path.dirname(p) or "." for p in (on_disk - graph_files)})
        print()
        print(f"REFUSING to rank: coverage below {COVERAGE_FLOOR:.0%}.")
        print("An under-covered graph returns an empty list that looks like a clean")
        print("bill of health. Falling back to filesystem signals only.")
        print()
        print("Directories absent or thin in the graph:")
        for d in missing[:15]:
            print(f"  - {d}")
        if len(missing) > 15:
            print(f"  ... and {len(missing) - 15} more")
        print()
        print("Fix coverage (check .graphifyignore, then `graphify update .`)")
        print("and re-run to get graph-backed ranking.")
        return 1

    # ---- directory roll-up -------------------------------------------------
    def dir_of(nid):
        n = nodes.get(nid)
        if not n:
            return None
        p = src(n)
        if not is_code(p) or is_test(p) or not in_target(p):
            return None
        return os.path.dirname(p) or "."

    indeg = collections.Counter()
    total = collections.Counter()
    xcomm = collections.Counter()
    sources = collections.defaultdict(set)

    for link in g.get("links", []):
        s, t = link.get("source"), link.get("target")
        ds, dt = dir_of(s), dir_of(t)
        if ds and dt and ds != dt:
            indeg[dt] += 1
            sources[dt].add(ds)
        cs = nodes.get(s, {}).get("community")
        ct = nodes.get(t, {}).get("community")
        crosses = cs is not None and ct is not None and cs != ct
        for d in {ds, dt} - {None}:
            total[d] += 1
            if crosses:
                xcomm[d] += 1

    size = collections.Counter()
    for p in graph_files:
        full = os.path.join(root, p)
        if os.path.exists(full):
            size[os.path.dirname(p) or "."] += os.path.getsize(full)

    rows = []
    for d, n_in in indeg.items():
        tokens = size.get(d, 0) // 4
        if tokens < 50:
            continue
        rows.append((n_in * 1000.0 / tokens, d, tokens, n_in,
                     len(sources[d]),
                     (100 * xcomm[d] // total[d]) if total[d] else 0))
    rows.sort(reverse=True)

    print()
    print("## Graph centrality (triggers 3-4)")
    print("dens   = incoming cross-dir edges per 1k tokens (constraint density)")
    print("xcomm% = share of edges crossing a community boundary (responsibility shift)")
    print()
    print(f"{'DIRECTORY':<44}{'~tok':>7}{'in':>5}{'from':>6}{'dens':>7}{'xcomm%':>8}")
    for dens, d, tokens, n_in, fan, xc in rows[:top]:
        print(f"{d:<44}{tokens:>7}{n_in:>5}{fan:>6}{dens:>7.1f}{xc:>8}")

    print()
    print("Read the top of `dens` for trigger 4 (small, load-bearing, hidden")
    print("invariants) and the top of `xcomm%` for trigger 3 (responsibility")
    print("shifts). High on both is the strongest node candidate there is.")
    print("Still hints: confirm by reading, and skip anything an ancestor states.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
