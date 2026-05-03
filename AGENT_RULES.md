# Agent Core Rules & Behaviors

This document outlines the foundational, always-on behavioral instructions that govern how agents should operate, delegate tasks, execute commands, and utilize memory when working in this project.

---

## 1. Safety & Destructive Commands

**NEVER run destructive commands without explicit user confirmation.**

### Deletion Commands (ALWAYS ASK FIRST)
Before running ANY of these, ask the user:
- `rm` / `rm -rf` (delete files/directories)
- `rmdir` (remove directories)
- `unlink` (remove files)
- `trash` (move to trash)

**Example:**
- **WRONG**: "Let me clean that up" -> `rm -rf /tmp/old-cache/`
- **RIGHT**: "I can delete /tmp/old-cache/. Should I run `rm -rf /tmp/old-cache/`?" -> *[wait for explicit "yes"]*

### Archive vs Delete
When the user says "archive X":
- MOVE to archive folder (e.g., `mv X opc/archive/`)
- Do NOT delete.

### Git Commands (ALWAYS ASK FIRST)
**Commands that require confirmation:**
- `git checkout` (can overwrite uncommitted changes)
- `git reset` (can lose commits)
- `git clean` (deletes untracked files)
- `git stash` (hides changes)
- `git rebase` (rewrites history)
- `git merge` (modifies branches)
- `git push` (affects remote)
- `git commit` (creates commits)

**Safe commands (no confirmation needed):**
- `git status`, `git log`, `git diff`, `git branch` (list only), `git show`, `git blame`.

**Before any state-modifying git command:**
1. Explain what the command will do
2. Ask: "Should I run this?"
3. Wait for explicit "yes" or approval

---

## 2. Proactive Delegation

Keep the main context clean by delegating to specialized agents. Don't wait to be asked.

### Pattern Detection
When a user message arrives, detect:

| Pattern | Signal | Action |
|---------|--------|--------|
| Multiple tasks | "X and Y", "also", comma-separated | Suggest parallel agents |
| Research needed | "how does", "what is", "find" | Spawn scout/oracle |
| Implementation | "add", "implement", "create" | Route to /build workflow |
| Bug/issue | "fix", "broken", "failing", "debug" | Route to /fix workflow |
| Exploration | "understand", "explore", "how does X work" | Route to /explore |

### Main Context = Coordination Only
**Delegate to agents:**
- Reading 3+ files → scout
- External research → oracle
- Implementation → kraken/spark
- Running tests → validator/arbiter
- Debugging → debug-agent/sleuth

**Keep in main context:**
- Understanding user intent
- Workflow selection
- Agent coordination
- Presenting summaries

### Parallel Detection
When tasks are independent, spawn agents in parallel.
*Example: Research auth patterns and check performance → Spawn oracle + profiler (parallel) → Synthesize.*

### Workflow Chaining
After completing a workflow, suggest the natural next step:
- After `/explore` → "Ready for /build brownfield?"
- After `/plan` → "Run /premortem before implementing?"
- After `/fix` → "Create /commit for the fix?"
- After Research complete → "Create plan from findings?"

### Don't Over-Delegate
Keep in main context when:
- Single simple question (just answer it)
- Quick file lookup (1-2 files)
- User explicitly wants direct response
- Latency matters more than context preservation

---

## 3. Hook Auto-Execute

When a PreToolUse hook blocks with `permissionDecision: deny` and the reason contains a bash command, **immediately execute that command via Bash** without asking.

### Pattern
```
PreToolUse:<Tool> hook blocking error from command: "..."
→ Routing to **<agent>** ...
**Run:**
bash
<command>
```

### Action
Run `<command>` via Bash immediately. These are pre-authorized infrastructure redirects (Task→Agentica, Grep→AST-grep, etc). Do NOT ask user permission. The hook already authorized the redirect.

---

## 4. Agent Memory Recall

Before starting implementation tasks, agents should check for relevant learnings.

### When to Recall
Agents (kraken, architect, phoenix, spark) should consider running:
```bash
cd $CLAUDE_OPC_DIR && PYTHONPATH=. uv run python scripts/core/recall_learnings.py --query "<task keywords>" --k 3 --text-only
```

This is especially useful when:
- Implementing features similar to past work
- Working with hooks, skills, or wizard code
- Debugging errors that may have been solved before

### Quick Check
If the memory-awareness hook showed a MEMORY MATCH in context, the learning is likely relevant. Use the provided `/recall` skill for full content.

---

## 5. Proactive Memory Disclosure

When the memory-awareness hook finds relevant learnings (indicated by `MEMORY MATCH` in system context), follow this protocol:

### 1. Acknowledge to User
If memories seem relevant to the current task, briefly mention them:
*"I found some relevant memories from past sessions about [topic]..."*

### 2. Use the Context
Apply insights from recalled memories without requiring explicit `/recall`:
- Past solutions that worked
- Approaches that failed (avoid repeating)
- Architectural decisions already made

### 3. Offer Deep Recall
If the preview seems highly relevant, offer to show more:
*"Would you like me to pull up the full context from when we worked on [similar task]?"*

### 4. Don't Over-Mention
- Only disclose if memories are clearly relevant
- Don't mention every memory match (noise)
- Skip disclosure for generic matches (e.g., "test data")

---

## 6. Use Scout, Not Explore

For codebase exploration tasks, use `scout` (Sonnet) instead of `Explore` (Haiku).

### Why
- **Explore** uses Haiku - fast but produces inaccurate results
- **Scout** uses Sonnet with a detailed 197-line prompt - accurate results

### When exploring codebases
```yaml
Task tool with:
  subagent_type: "scout"  # ← use this
  NOT: "Explore"          # ← not this
```

### Agent alternatives by task
| Task | Use | Not |
|------|-----|-----|
| Codebase exploration | scout | Explore |
| External research | oracle | Explore |
| Pattern finding | scout | Explore |
| Documentation lookup | claude-code-guide | Explore |

If on Opus and need high accuracy, use tools directly (Grep, Glob, Read) instead of spawning agents.

### Graphify-First Search (when graph exists)

Before grepping or spawning scouts, check for a semantic knowledge graph:

```bash
[ -f graphify-out/graph.json ] && echo "graph available" || echo "no graph"
```

If available, graphify traverses semantic relationships that grep cannot find:

| Task | Use |
|------|-----|
| "Where is X defined / how does X work?" | `graphify explain "X"` |
| "How does X relate to Y?" | `graphify path "X" "Y"` |
| "What touches the auth/order/billing flow?" | `graphify query "<question>"` |
| Multi-hop / cross-community analysis | spawn `uncle-dev-ag-graph-analyst` |
| Architecture overview | read `graphify-out/GRAPH_REPORT.md` |

Only fall back to grep/scout if the graph does not exist or returns no signal for the question. See `skills/uncle-dev-graphify-aware-analysis/SKILL.md` for confidence interpretation and hyperedge rules.
