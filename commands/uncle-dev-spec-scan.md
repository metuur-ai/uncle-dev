---
description: Validate @spec annotations against docs/specs/ and report orphans / missing tests / missing code
---

Run the spec coherence scanner and present its report.

The scanner script is `scan-spec-coherence.py` in the `uncle-dev-spec-annotations` skill.

1. Locate the script. Search in this order:
   - `${CLAUDE_PLUGIN_ROOT}/skills/uncle-dev-spec-annotations/scan-spec-coherence.py`
   - `~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/skills/uncle-dev-spec-annotations/scan-spec-coherence.py`
   - The agent-skills repo if cloned locally

2. Run the scanner from the project root. Default mode (text output, fail on orphans only):

```bash
python3 <path-to-scan-spec-coherence.py> --root "$(pwd)"
```

   Strict mode (also fail on missing test/code, helper annotations, and malformed IDs):

```bash
python3 <path-to-scan-spec-coherence.py> --root "$(pwd)" --strict
```

   Fallback mode for environments without tree-sitter (CI containers, minimal Python):

```bash
python3 <path-to-scan-spec-coherence.py> --root "$(pwd)" --no-tree-sitter
```

3. Show the user the scanner report. The report format is:

   ```
   Spec coherence report (root: ...)

     ✓ N specs defined in docs/specs/
     ✓ N specs with code annotations
     ✓ N specs with test annotations

     ✗ ORPHAN: <file>:<line> cites @spec <ID> (not in docs/specs/)
     ✗ MISSING TEST: <ID> has code (...) but no test citation
     ⚠ MISSING CODE: <ID> has test (...) but no code citation
     ⚠ HELPER ANNOTATION: <file>:<line> @spec on owner_kind=none — annotation belongs on entry point, not helper
     ⚠ MALFORMED ID: <file>:<line> @spec <token> — does not match SEG-AREA-NNN format

   Summary: ...
   ```

4. **If orphans are present:**
   - Read the spec catalog at `docs/specs/` and the cited file
   - Suggest one of: (a) add the missing ID to the appropriate spec file, (b) correct the citation to a real ID, (c) remove the annotation if the code does not implement product behavior
   - Do not auto-fix — let the human decide; orphans usually mean either the spec file is stale or the annotation is a typo

5. **If only warnings (missing test/code, helpers):**
   - Surface them but do not block the workflow unless the user invoked `--strict`
   - For MISSING TEST on `[x]` implemented specs: the spec was promised but never tested — flag it
   - For HELPER ANNOTATION: the annotation is on a non-entry-point. Either move it up to the owner or remove it

6. **Skip silently** if `docs/specs/` does not exist — this repo has not adopted EARS specs yet (graceful no-op).

If the script is not found, tell the user: "scan-spec-coherence.py not found. Run `install-claude.sh` from the agent-skills repo, or clone the repo locally."

For the algorithm details, see `skills/uncle-dev-spec-annotations/resources/scanner-design.md`.
