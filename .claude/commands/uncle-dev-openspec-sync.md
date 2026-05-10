---
description: Regenerate the OpenSpec global change tracker
---

Regenerate `openspec/tracker/changes.yaml` from current task state.

The generator script is `generate-tracker.py` in the `uncle-dev-spec-driven-development` skill.

1. Locate the script. Search in this order:
   - `~/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/*/skills/uncle-dev-spec-driven-development/generate-tracker.py`
   - The agent-skills repo if cloned locally

2. Run it with the project's openspec path:

```bash
python3 <path-to-generate-tracker.py> --project "$(pwd)/openspec"
```

   To regenerate the spec graph in the same step (when the repo uses `docs/specs/`):

```bash
python3 <path-to-generate-tracker.py> --project "$(pwd)/openspec" --with-spec-graph
```

3. Show the user the contents of `openspec/tracker/changes.yaml` formatted as a status table with columns: Change, Status, Phase, Criteria (done/total), Spec Coverage, Records. The Spec Coverage column shows `coverage_pct%` (or `—` when `spec_coverage: null`).

## Spec Coverage in the Tracker

When the repo has `docs/specs/`, the tracker emits a `spec_coverage` field per change derived from the `## EARS Specs` block in each `proposal.md`:

```markdown
## EARS Specs
- Introduces: FAV-001, FAV-002
- Modifies: AUTH-005
```

The output looks like:

```yaml
002-favorites:
  spec_coverage:
    declared: [FAV-001, FAV-002, AUTH-005]
    with_code: [FAV-001, FAV-002, AUTH-005]
    with_test: [FAV-001, AUTH-005]
    coverage_pct: 83
    missing:
      FAV-002: [test]
```

If `docs/specs/` does not exist, or a `proposal.md` has no `## EARS Specs` block, the field is `spec_coverage: null` (graceful no-op — does not crash). See `uncle-dev-spec-annotations` for the EARS Specs proposal block convention.

If the script is not found, tell the user: "generate-tracker.py not found. Run `install-claude.sh` from the agent-skills repo."
