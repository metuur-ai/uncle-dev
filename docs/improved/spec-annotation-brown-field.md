# How to Apply @spec Annotations to a Brownfield Codebase

This guide shows you how to use uncle-dev to analyze existing source code and `.md` spec files, identify and classify LID feature labels, and apply `@spec` annotations in documentation and source code.

## Prerequisites

Before you begin, ensure you have:

- uncle-dev installed with the `/uncle-dev-spec-annotations`, `/uncle-dev-spec-scan`, and `/uncle-dev-spec-graph` commands available
- An existing codebase with source files and, ideally, a `docs/specs/` directory
- `python3` available, if you plan to run the coherence scanner directly

---

## What is LID?

**LID (Linked Intent & Development)** is the system connecting durable product intent to implementation. The chain flows in one direction but is walkable in both:

```
HLD → LLD → EARS spec (feature label ID) → Tests → Code
                        ↑_________________________↓
                           @spec annotations link back
```

A **feature label** is a stable EARS spec ID like `AUTH-UI-001`. It:

- Survives renames and refactors
- Describes product behavior (not implementation details)
- Follows format: `SEGMENT-SUBSEGMENT-NNN`

---

## Prompts to Use

### 1. Analyze & annotate new code

```
/uncle-dev-spec-annotations

I just wrote [function name] that [what it does].
I need @spec IDs for these behaviors and guidance on where to place annotations.
```

### 2. Audit existing code for broken links (coherence check)

```
/uncle-dev-spec-scan
```

Or in strict mode (also catches missing tests, helper annotations):

```
/uncle-dev-spec-scan

Run in strict mode.
```

### 3. Design a new feature — define spec IDs first

```
I'm adding a new [segment name] segment. Can you:
1. Create docs/specs/[segment]-specs.md with EARS format
2. Define the first N spec IDs ([SEGMENT]-API-001, etc.)
3. Register it in docs/arrows/index.yaml
4. Create the segment crosslink in docs/arrows/[segment].md
```

### 4. Build the queryable spec graph

```
/uncle-dev-spec-graph
```

Run after adding/removing specs or annotations. Generates:

- `docs/arrows/spec-graph.json` — machine-readable
- `docs/arrows/spec-graph.mmd` — Mermaid diagram
- `docs/arrows/SPEC_GRAPH_REPORT.md` — human-readable report

### 5. Decide if code needs @spec

```
I have a function [name] in [path]. Should it have @spec?
```

Rule: annotate **entry points** that implement product behavior. Skip helpers, utilities, config, migrations.

---

## @spec Annotation Rules

| Language              | Syntax                        |
| --------------------- | ----------------------------- |
| TypeScript/JavaScript | `// @spec AUTH-UI-001`        |
| Python                | `# @spec AUTH-UI-001`         |
| Go                    | `// @spec AUTH-UI-001`        |
| Rust                  | `// @spec AUTH-UI-001`        |
| Java                  | `// @spec AUTH-UI-001`        |
| HTML                  | `<!-- @spec MKT-SITE-045 -->` |

**Placement:** The comment goes directly before the **topmost function** that owns the behavior — not on every helper it calls.

**Multiple IDs:** `// @spec AUTH-UI-001, AUTH-UI-002`

---

## Steps: Analyze Source and Spec Files to Identify Labels

1. **Read the source file.** Identify public or exported functions that implement user-facing behaviors.
2. **Check `docs/specs/`.** Look for existing EARS IDs that match those behaviors.
3. **If IDs exist, annotate.** Add `@spec` to code entry points and matching tests.
4. **If IDs are missing, create them first.** Add them to `docs/specs/<segment>-specs.md`, then annotate.
5. **Run the scanner.** Verify with `python3 scan-spec-coherence.py --root "$(pwd)"`.
6. **Regenerate the graph.** Run `/uncle-dev-spec-graph` if the graph is in use.

---

## EARS Spec Format (in `docs/specs/<segment>-specs.md`)

```markdown
- [x] **AUTH-UI-001**: When a user submits valid credentials, the system SHALL return a session scoped to that user.
- [x] **AUTH-UI-002**: When a user submits invalid credentials, the system SHALL return a user-safe error.
- [ ] **AUTH-UI-003**: When a session expires, the system SHALL redirect to login. (active gap)
```

Status markers: `[x]` implemented · `[ ]` active gap · `[D]` deferred

---

## Scanner Output Reference

```
✓ N specs defined in docs/specs/
✓ N specs with code annotations
✓ N specs with test annotations

✗ ORPHAN: <file>:<line> cites @spec <ID> not in docs/specs/    ← blocking
✗ MISSING TEST: <ID> has code but no test citation             ← blocking
⚠ MISSING CODE: <ID> has test but no code citation
⚠ HELPER ANNOTATION: @spec on non-entry-point
⚠ MALFORMED ID: @spec token doesn't match SEG-AREA-NNN
```

Exit code 0 = clean. Exit code 1 = broken links.

---

## Key Reference Files

| File                                                                                                                                     | Purpose                               |
| ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| [skills/uncle-dev-spec-annotations/SKILL.md](skills/uncle-dev-spec-annotations/SKILL.md)                                                 | Full @spec annotation reference       |
| [skills/uncle-dev-spec-annotations/resources/annotation-examples.md](skills/uncle-dev-spec-annotations/resources/annotation-examples.md) | Per-language syntax examples          |
| [skills/uncle-dev-spec-driven-development/SKILL.md](skills/uncle-dev-spec-driven-development/SKILL.md)                                   | Full spec-driven development workflow |
| [docs/lid-spec-annotation-simple-explanation.md](docs/lid-spec-annotation-simple-explanation.md)                                         | Simplified LID explanation            |
| [docs/2026-05-09-implementing-spec-annotations-guide.md](docs/2026-05-09-implementing-spec-annotations-guide.md)                         | Step-by-step implementation guide     |

---

---

## Swarm: 5 Parallel Agents to Analyze a .md File for LID Labels

Dispatch all five at once. Each is self-contained — they share only the target file path.
Replace `<YOUR_MD_FILE>` with the actual path (e.g., `docs/llds/auth.md`).

---

### Agent 1 — ID Auditor

_What EARS IDs already exist in the file? Are they well-formed?_

```
You are auditing a markdown file for existing LID feature labels.

Target file: <YOUR_MD_FILE>

Tasks:
1. Read the file.
2. Extract every string that looks like an EARS spec ID — format is SEGMENT-AREA-NNN (e.g., AUTH-UI-001, BILLING-API-003). Also flag any bold+colon patterns like **SOMETHING-001**: that might be spec IDs.
3. For each ID found, check if it exists in docs/specs/**/*.md. Report:
   - ✓ ID exists and matches
   - ✗ ORPHAN — ID cited in the .md but missing from docs/specs/
   - ⚠ MALFORMED — does not match SEGMENT-AREA-NNN pattern
4. List the segment prefixes you found (AUTH, BILLING, etc.) and whether they are registered in docs/arrows/index.yaml.

Output: a table of all IDs found, their status (✓ / ✗ / ⚠), and the file+line where each appears.
```

---

### Agent 2 — Behavior Miner

_What behaviors are described in the file but have no ID yet?_

```
You are mining a markdown file for unlabeled product behaviors.

Target file: <YOUR_MD_FILE>

Tasks:
1. Read the file.
2. Find every sentence or bullet that describes a durable product behavior — look for:
   - "When X, the system shall Y" (EARS pattern)
   - "must", "should", "will", "returns", "displays", "prevents", "validates"
   - Any behavior description without a bold ID (e.g., **AUTH-001**) nearby
3. For each candidate behavior, determine:
   - Is it product-facing (something a user or external system observes)?
   - Is it testable (can a test prove it exists)?
   - Does it already have an EARS ID assigned?
4. Output a numbered list of unlabeled behaviors that qualify for an ID, with:
   - The original text from the file
   - Why it qualifies (product-facing + testable)
   - Suggested segment prefix (AUTH, BILLING, MKT-SITE, etc.)

Skip: internal plumbing, helper functions, formatting, one-shot tasks, config notes.
```

---

### Agent 3 — Segment Classifier + ID Proposer

_For each unlabeled behavior, propose a stable EARS ID._

```
You are classifying behaviors and proposing stable EARS spec IDs.

Target file: <YOUR_MD_FILE>

Tasks:
1. Read the file.
2. Check docs/arrows/index.yaml for registered segments and their prefix conventions.
3. Check docs/specs/**/*.md to find the highest existing ID number per segment (so you don't collide).
4. For each behavior in the file that lacks an EARS ID:
   a. Classify it into a segment (AUTH, BILLING, MKT-SITE, etc.) based on product intent — not file location.
   b. Assign the next available ID for that segment: SEGMENT-AREA-NNN.
   c. Write a one-sentence EARS statement: "When [trigger], the system SHALL [outcome]."
5. Format output as ready-to-paste markdown for docs/specs/<segment>-specs.md:

- [ ] **SEGMENT-AREA-NNN**: When [trigger], the system SHALL [outcome].

Flag any behaviors that cross segment boundaries (auth + billing in one behavior = boundary crossing, needs review).
```

---

### Agent 4 — Source Anchor

_Find the code entry points that implement the behaviors in the .md file._

```
You are locating source code entry points that implement behaviors described in a markdown file.

Target file: <YOUR_MD_FILE>

Tasks:
1. Read the file and list the behaviors it describes (with any existing EARS IDs if present).
2. For each behavior, search the source tree (src/, app/, lib/, pkg/) for the function, class, method, route, or component that is the entry point owning that behavior. An entry point is:
   - An exported/public function or method
   - A route handler
   - A React/Vue/Svelte component
   - NOT a helper or internal utility
3. For each entry point found, report:
   - File path + line number
   - Function/class name
   - Whether it already has a @spec annotation
   - If it has @spec, whether the ID matches what's in the .md file

Output: a two-column mapping — behavior description → source entry point (file:line, function name, has @spec yes/no).
If an entry point cannot be found, say "NOT FOUND — may not be implemented yet."
```

---

### Agent 5 — Annotation Generator

_Produce ready-to-paste @spec comment lines for code and tests._

```
You are generating @spec annotations for source code and tests.

Target file: <YOUR_MD_FILE>

Tasks:
1. Read the file and extract all EARS spec IDs (format: SEGMENT-AREA-NNN).
2. For each ID, find:
   a. The source entry point that implements it (search src/, app/, lib/).
   b. The test that proves it (search tests/, __tests__/, *.test.ts, *.spec.ts, test_*.py).
3. For each pair, generate the exact annotation comment in the correct language:
   - TypeScript/JavaScript/Go/Rust/Java: // @spec <ID>
   - Python: # @spec <ID>
   - HTML: <!-- @spec <ID> -->
4. Format output as a diff-ready patch showing:
   - The file path
   - The line BEFORE the entry point / test where the annotation should go
   - The annotation comment to insert

If an entry point already has @spec pointing to the correct ID, mark it ✓ (no change needed).
If an entry point has @spec pointing to a DIFFERENT ID, flag it ⚠ (needs review before changing).
If no entry point is found, mark it ✗ NOT FOUND.

Do NOT write any files — output only. The user will review before applying.
```

---

### How to dispatch the swarm

In a single Claude Code message, call the Agent tool five times in parallel:

```
Agent 1 → ID Auditor       (reads .md + docs/specs/)
Agent 2 → Behavior Miner   (reads .md)
Agent 3 → ID Proposer      (reads .md + docs/specs/ + docs/arrows/)
Agent 4 → Source Anchor    (reads .md + src/)
Agent 5 → Annotation Gen   (reads .md + src/ + tests/)
```

After all five return, review their outputs and run `/uncle-dev-spec-scan` to validate.

---

## Verify it worked

Confirm your annotations are coherent:

1. Run `/uncle-dev-spec-scan` (or `python3 scan-spec-coherence.py --root "$(pwd)"`) on a project with `docs/specs/`. A clean run exits with code 0 and reports no ORPHAN or MISSING TEST lines.
2. Open [skills/uncle-dev-spec-annotations/SKILL.md](skills/uncle-dev-spec-annotations/SKILL.md) and confirm your annotations match the canonical reference.
3. Check [docs/lid-spec-annotation-simple-explanation.md](docs/lid-spec-annotation-simple-explanation.md) for a beginner-friendly walkthrough.
