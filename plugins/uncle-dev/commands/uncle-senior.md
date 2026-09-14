---
description: Senior principal engineer — Challenge (structured verdict via the uncle-senior agent) or Duck (rubber duck conversation in this session). Usage: /uncle-senior [--duck | duck]
---

This command routes. It does not analyze — the logic lives in the `uncle-senior` agent and the `uncle-dev-duck` skill.

## Mode Detection

**Duck mode** — activated by any of:
- `/uncle-senior --duck`
- `/uncle-senior duck`
- "think with me", "help me think through", "I'm not sure what I want to build", "talk me through"

**Challenge mode** — everything else (default).

---

## Duck Mode → run in this session

Duck mode is a multi-turn conversation, so it must NOT be delegated to a subagent. Load the skill and run it here:

```bash
_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)
bash "$_loader" uncle-dev-duck
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

---

## Challenge Mode → dispatch to the agent

Spawn the `uncle-senior` agent via the Task tool. It runs in an isolated context and **cannot see this conversation**, so the prompt you send it must be self-contained. Include:

- The proposed approach, in the developer's own words where possible
- The problem it is meant to solve
- Any constraints that were stated, and who stated them
- Relevant file paths (the agent has Read, Grep, Glob, WebSearch — it can look, but only where you point it)

If the developer hasn't described an approach yet, ask "What are you trying to build or solve?" before dispatching — do not send the agent an empty proposal.

Relay the agent's verdict block verbatim. Do not re-litigate it or soften the verdict; if you disagree, say so separately after the block.

End with the concrete next step the agent named — `/uncle-dev-plan` if the verdict is `PROCEED`, or the specific aspect to reconsider.
