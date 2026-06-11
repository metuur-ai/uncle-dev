---
description: Build the spec graph from HLD + LLDs + EARS specs + @spec annotations and write JSON, Mermaid, HTML, and a human report into graphify-out/
---

Generate the `@spec` graph artifacts and present the report.

The generator script is `build-spec-graph.py` in the `uncle-dev-spec-annotations` skill. It fuses the canonical inputs into one queryable graph:

```
docs/high-level-design.md   ──┐
docs/arrows/index.yaml      ──┤
docs/arrows/<segment>.md    ──┼──▶ build-spec-graph.py ──▶ graphify-out/spec-graph.json
docs/llds/<segment>.md      ──┤                            graphify-out/spec-graph.mmd
docs/specs/<segment>-specs ──┤                            graphify-out/spec-graph.html
scan-spec-coherence.py JSON ──┘                            graphify-out/SPEC_GRAPH_REPORT.md
```

1. Locate the script. Search in this order:
   - `${CLAUDE_PLUGIN_ROOT}/skills/uncle-dev-spec-annotations/build-spec-graph.py`
   - The agent-skills repo if cloned locally

2. Run it from the project root. Default writes all four artifacts into `graphify-out/`:

```bash
python3 <path-to-build-spec-graph.py> --root "$(pwd)"
```

   To regenerate only one format:

```bash
python3 <path-to-build-spec-graph.py> --root "$(pwd)" --format json
python3 <path-to-build-spec-graph.py> --root "$(pwd)" --format mermaid
python3 <path-to-build-spec-graph.py> --root "$(pwd)" --format report
python3 <path-to-build-spec-graph.py> --root "$(pwd)" --format html
```

   To write to a custom directory:

```bash
python3 <path-to-build-spec-graph.py> --root "$(pwd)" --out path/to/dir
```

3. Read `graphify-out/SPEC_GRAPH_REPORT.md` and present its contents to the user — segment summary, cascade impact, orphan list, and the embedded Mermaid diagram. Point them at:
   - `graphify-out/spec-graph.json` — canonical machine-readable graph
   - `graphify-out/spec-graph.mmd` — Mermaid source (renderable in VS Code preview, GitHub markdown, mmdc)
   - `graphify-out/spec-graph.html` — interactive vis.js graph (same style as graphify's graph.html): dark theme, force-directed layout, click-to-inspect sidebar, search, node-type filter legend. Open in any browser.
   - `graphify-out/SPEC_GRAPH_REPORT.md` — human report

4. The generator also writes `graphify-out/spec-edges.json` alongside these files — a projection so the graphify CLI can traverse `@spec` edges.

5. **Skip silently** if `docs/` does not exist — repo has not adopted the spec graph (graceful no-op). `graphify-out/` is created automatically if it does not exist yet.

**When to regenerate:**
- After adding/removing an EARS spec
- After adding/removing a `@spec` annotation on code or test
- After editing `docs/arrows/index.yaml` (segment registry changed)
- After finishing an OpenSpec change that touched specs or annotations
- Before requesting code review on a change that affected the graph

**When NOT to regenerate:**
- Routine code edits with no spec impact (the scanner via the Edit/Write hook already validates IDs in real time)

For algorithm details, see `skills/uncle-dev-spec-annotations/build-spec-graph.py` and the conceptual model in `skills/uncle-dev-spec-annotations/SKILL.md`.

If the script is not found, tell the user: "build-spec-graph.py not found. Run `install-claude.sh` from the agent-skills repo, or clone the repo locally."
