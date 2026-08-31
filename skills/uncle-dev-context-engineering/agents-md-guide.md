# AGENTS.md Authoring Guide

Reference for creating and maintaining Intent Layer nodes. Read this after deciding *where* a node belongs — that placement rule lives in `SKILL.md`, Mode A Step 3, and is not repeated here.

---

## Child Node Template

```markdown
# {Area Name}

## Purpose
[1-2 sentences: what this area owns. What it explicitly does NOT do.]

## Entry Points
- `main_api.ts` — primary API surface
- `cli.ts` — CLI commands

## Contracts & Invariants
- All DB calls go through `./db/client.ts` — no direct driver access
- This area is imported by `../api/` only; it imports nothing from `../api/`

## Patterns
To add a new [typical task]:
1. Create handler in `./handlers/`
2. Register in `./routes.ts`
3. Add types to `./types.ts`

## Anti-patterns
- Never call external APIs directly; use `./clients/`
- Don't bypass the validation layer

## Related Context
- Database layer: `./db/AGENTS.md`
- Shared utilities: `../shared/AGENTS.md`
```

---

## Root Context Addition

Add to the root CLAUDE.md or AGENTS.md when child nodes exist:

```markdown
## Intent Layer

**Before modifying code in a subdirectory, read its AGENTS.md first.**

- **[Area 1]**: `path/to/AGENTS.md` — brief description
- **[Area 2]**: `path/to/AGENTS.md` — brief description

### Global Invariants
- [Invariant that applies across all areas]
```

---

## Measurement Scripts

```bash
# Check current Intent Layer state (none / partial / complete)
bash skills/uncle-dev-context-engineering/scripts/detect_state.sh [path]

# Triggers 1-2: boundary candidates (dirs >9 non-test files, package files, existing nodes)
bash skills/uncle-dev-context-engineering/scripts/analyze_structure.sh [path]

# Triggers 3-4: small load-bearing dirs (fan-in density, singletons, invariants,
# sole registration points). Run this as a PEER of the size scan, not after it —
# a size scan cannot see these, and they cluster in the smallest directories.
bash skills/uncle-dev-context-engineering/scripts/analyze_structure.sh --criticality [path]

# Trigger 1 only: token count for a specific directory.
# A "NOT MET" here is not a verdict that the directory needs no node.
bash skills/uncle-dev-context-engineering/scripts/estimate_tokens.sh <dir>

# Raw source bytes for a subtree — the threshold measurement itself.
# Also sourceable, which is how the code-context hook consumes it.
bash skills/uncle-dev-context-engineering/scripts/subtree_source_bytes.sh <dir>
```

---

## Quality Checklist

Before finalizing any node:

- [ ] ≤ 60 lines — hard cap for child nodes. Over it, reword until it fits; never raise the limit. The root file is exempt
- [ ] The directory actually earns a node (SKILL.md, Mode A Step 3)
- [ ] Purpose statement in first 2 lines
- [ ] Contracts are explicit, not vague ("always use X", not "handle carefully")
- [ ] No file inventories — every line survives a rename
- [ ] Anti-patterns come from real experience, not hypothetical scenarios
- [ ] Related Context uses relative paths
- [ ] No content duplicated from an ancestor node

---

## SME Capture Questions

Use these when extracting knowledge from an engineer into a new node.

**Purpose & Scope**
- "In one sentence, what does this area own?"
- "What is explicitly NOT this area's responsibility?"

**Entry Points**
- "Where does code execution typically start here?"
- "What are the main APIs/interfaces other code uses?"

**Contracts & Invariants**
- "What must always be true here? What would break if violated?"
- "What are the implicit rules that aren't visible in the code?"

**Patterns**
- "How do you add a new [common task] in this area?"
- "What's the canonical way to do [common operation]?"

**Anti-patterns & Pitfalls**
- "What mistakes do new engineers typically make here?"
- "What should never be done, even though the code allows it?"
- "What looks deprecated but actually isn't?"

**Capture order:** work leaf-first (utilities → domain modules → integration layers → complex/legacy → root).

---

## Compression Example

Verbose nodes lose their value — agents spend attention processing prose instead of understanding intent. This is the move to reach for when a draft exceeds the 60-line cap.

**Before — prose and a tech-stack inventory, on track for 60+ lines:**
```markdown
# User Service

## Overview
The User Service is a microservice that is responsible for managing user accounts
in our platform. It handles user registration, authentication, profile management,
and user preferences. This service is built using TypeScript and Express.js, and
it uses PostgreSQL as its database through Prisma ORM.

## Technologies Used
- TypeScript 5.0
- Express.js 4.x
- PostgreSQL 15
...
```

**After — 16 lines, and it says more:**
```markdown
# User Service

Manages user accounts, auth, and preferences. Express + Prisma + PostgreSQL.

## Entry Points
- `src/routes/` — REST API
- `src/jobs/` — Background sync tasks

## Contracts
- Auth tokens from `packages/auth/`
- User events published to `events.users.*`

## Anti-patterns
- Never store passwords — use `packages/auth/hash.ts`
- Don't query the users table from other services — use events
```

**Principles:** purpose before structure; contracts explicit; anti-patterns from experience; assume the agent is smart; use downlinks for depth, not duplication.
