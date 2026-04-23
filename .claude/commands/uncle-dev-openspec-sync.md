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

3. Show the user the contents of `openspec/tracker/changes.yaml` formatted as a status table with columns: Change, Status, Phase, Criteria (done/total), Records.

If the script is not found, tell the user: "generate-tracker.py not found. Run `install-claude.sh` from the agent-skills repo."
