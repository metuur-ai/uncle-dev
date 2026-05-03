---
name: uncle-dev-code-review-and-quality
description: Conducts multi-axis code review. Use before merging any change. Use when reviewing code written by yourself, another agent, or a human. Use when you need to assess code quality across multiple dimensions before it enters the main branch.
---

# Code Review and Quality

## Overview

Multi-dimensional code review with quality gates. Every change gets reviewed before merge — no exceptions. Review covers five axes: correctness, readability, architecture, security, and performance.

**The approval standard:** Approve a change when it definitely improves overall code health, even if it isn't perfect. Perfect code doesn't exist — the goal is continuous improvement. Don't block a change because it isn't exactly how you would have written it. If it improves the codebase and follows the project's conventions, approve it.

## When to Use

- Before merging any PR or change
- After completing a feature implementation
- When another agent or model produced code you need to evaluate
- When refactoring existing code
- After any bug fix (review both the fix and the regression test)

**Graphify availability check** — run once before the review process:
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF — using standard search"
```
If OFF, skip all graphify sections below and proceed with the standard process.

## The Five-Axis Review

Every review evaluates code across these dimensions:

### 1. Correctness

Does the code do what it claims to do?

- Does it match the spec or task requirements?
- Are edge cases handled (null, empty, boundary values)?
- Are error paths handled (not just the happy path)?
- Does it pass all tests? Are the tests actually testing the right things?
- Are there off-by-one errors, race conditions, or state inconsistencies?

### 2. Readability & Simplicity

Can another engineer (or agent) understand this code without the author explaining it?

- Are names descriptive and consistent with project conventions? (No `temp`, `data`, `result` without context)
- Is the control flow straightforward (avoid nested ternaries, deep callbacks)?
- Is the code organized logically (related code grouped, clear module boundaries)?
- Are there any "clever" tricks that should be simplified?
- **Could this be done in fewer lines?** (1000 lines where 100 suffice is a failure)
- **Are abstractions earning their complexity?** (Don't generalize until the third use case)
- Would comments help clarify non-obvious intent? (But don't comment obvious code.)
- Are there dead code artifacts: no-op variables (`_unused`), backwards-compat shims, or `// removed` comments?

### 3. Architecture

Does the change fit the system's design?

- Does it follow existing patterns or introduce a new one? If new, is it justified?
- Does it maintain clean module boundaries?
- Is there code duplication that should be shared?
- Are dependencies flowing in the right direction (no circular dependencies)?
- Is the abstraction level appropriate (not over-engineered, not too coupled)?

**Graph-informed architecture checks** (if graphify is ON):

```bash
# Detect boundary violations — find if changed module can reach a module it shouldn't:
graphify path "<changed-module>" "<a-module-it-should-NOT-reach>"
# A short path where none should exist = boundary violation

# Detect abstraction duplication:
graphify query "concepts similar to <new-abstraction-name>"
```

- Does the change affect a **god node**? (Check GRAPH_REPORT.md — high betweenness = unintended ripple risk)
- Does the change create a new **cross-community edge**? (Graph cluster violation = wrong-layer coupling)
- Does the new abstraction duplicate an already-graphed concept? (`semantically_similar_to` edges at EXTRACTED or high INFERRED confidence)

### 4. Security

For detailed security guidance, see `security-and-hardening`. Does the change introduce vulnerabilities?

- Is user input validated and sanitized?
- Are secrets kept out of code, logs, and version control?
- Is authentication/authorization checked where needed?
- Are SQL queries parameterized (no string concatenation)?
- Are outputs encoded to prevent XSS?
- Are dependencies from trusted sources with no known vulnerabilities?
- Is data from external sources (APIs, logs, user content, config files) treated as untrusted?
- Are external data flows validated at system boundaries before use in logic or rendering?

### 5. Performance

For detailed profiling and optimization, see `performance-optimization`. Does the change introduce performance problems?

- Any N+1 query patterns?
- Any unbounded loops or unconstrained data fetching?
- Any synchronous operations that should be async?
- Any unnecessary re-renders in UI components?
- Any missing pagination on list endpoints?
- Any large objects created in hot paths?

## Change Sizing

Small, focused changes are easier to review, faster to merge, and safer to deploy. Target these sizes:

```
~100 lines changed   → Good. Reviewable in one sitting.
~300 lines changed   → Acceptable if it's a single logical change.
~1000 lines changed  → Too large. Split it.
```

**What counts as "one change":** A single self-contained modification that addresses one thing, includes related tests, and keeps the system functional after submission. One part of a feature — not the whole feature.

**Splitting strategies when a change is too large:**

| Strategy | How | When |
|----------|-----|------|
| **Stack** | Submit a small change, start the next one based on it | Sequential dependencies |
| **By file group** | Separate changes for groups needing different reviewers | Cross-cutting concerns |
| **Horizontal** | Create shared code/stubs first, then consumers | Layered architecture |
| **Vertical** | Break into smaller full-stack slices of the feature | Feature work |

**When large changes are acceptable:** Complete file deletions and automated refactoring where the reviewer only needs to verify intent, not every line.

**Separate refactoring from feature work.** A change that refactors existing code and adds new behavior is two changes — submit them separately. Small cleanups (variable renaming) can be included at reviewer discretion.

## Change Descriptions

Every change needs a description that stands alone in version control history.

**First line:** Short, imperative, standalone. "Delete the FizzBuzz RPC" not "Deleting the FizzBuzz RPC." Must be informative enough that someone searching history can understand the change without reading the diff.

**Body:** What is changing and why. Include context, decisions, and reasoning not visible in the code itself. Link to bug numbers, benchmark results, or design docs where relevant. Acknowledge approach shortcomings when they exist.

**Anti-patterns:** "Fix bug," "Fix build," "Add patch," "Moving code from A to B," "Phase 1," "Add convenience functions."

## Review Process

### Step 1: Understand the Context

Before looking at code, understand the intent:

```
- What is this change trying to accomplish?
- What spec or task does it implement?
- What is the expected behavior change?
```

**Graph-augmented context** (if graphify is ON):

```bash
# Check GRAPH_REPORT.md for god nodes — if the change touches a god node, flag it early
# Read graphify-out/GRAPH_REPORT.md

# Understand the structural neighborhood of the primary changed module:
graphify explain "<primary changed module>"

# If the change touches multiple modules in different domains:
graphify query "what is the relationship between <module-A> and <module-B>"
```

Surface before reviewing code:
- Whether any changed module is a **god node** → if yes, use Full parallel review mode regardless of line count
- Any **community crossings** the change introduces → feeds directly into Axis 3 (Architecture)
- Surprising connections from GRAPH_REPORT.md → potential hidden blast radius the author may not know about

See `uncle-dev-graphify-aware-analysis` for command syntax and confidence interpretation.

### Step 2: Review the Tests First

Tests reveal intent and coverage:

```
- Do tests exist for the change?
- Do they test behavior (not implementation details)?
- Are edge cases covered?
- Do tests have descriptive names?
- Would the tests catch a regression if the code changed?
```

### Step 3: Review the Implementation

Walk through the code with the five axes in mind:

```
For each file changed:
1. Correctness: Does this code do what the test says it should?
2. Readability: Can I understand this without help?
3. Architecture: Does this fit the system?
4. Security: Any vulnerabilities?
5. Performance: Any bottlenecks?
```

### Step 4: Categorize Findings

Label every comment with its severity so the author knows what's required vs optional:

| Prefix | Meaning | Author Action |
|--------|---------|---------------|
| *(no prefix)* | Required change | Must address before merge |
| **Critical:** | Blocks merge | Security vulnerability, data loss, broken functionality |
| **Nit:** | Minor, optional | Author may ignore — formatting, style preferences |
| **Optional:** / **Consider:** | Suggestion | Worth considering but not required |
| **FYI** | Informational only | No action needed — context for future reference |

This prevents authors from treating all feedback as mandatory and wasting time on optional suggestions.

### Step 5: Verify the Verification

Check the author's verification story:

```
- What tests were run?
- Did the build pass?
- Was the change tested manually?
- Are there screenshots for UI changes?
- Is there a before/after comparison?
```

## Multi-Model Review Pattern

Use different models for different review perspectives:

```
Model A writes the code
    │
    ▼
Model B reviews for correctness and architecture
    │
    ▼
Model A addresses the feedback
    │
    ▼
Human makes the final call
```

This catches issues that a single model might miss — different models have different blind spots.

**Example prompt for a review agent:**
```
Review this code change for correctness, security, and adherence to
our project conventions. The spec says [X]. The change should [Y].
Flag any issues as Critical, Important, or Suggestion.
```

## Parallel Orchestration Mode

For significant changes, run three specialized subagents in parallel then synthesize. Use this when the change is large (>300 lines), touches security-sensitive paths, or requires architectural judgment beyond a quick check.

```
         ┌──────────────────────┐
         │ uncle-dev-ag-        │ ─┐
         │ code-reviewer        │  │
         └──────────────────────┘  │
                                   │     ┌────────────────────────┐
         ┌──────────────────────┐  ├────▶│ uncle-dev-ag-          │
         │ plan-reviewer        │  │     │ review-synthesizer      │
         │ (architecture)       │  │     └────────────────────────┘
         └──────────────────────┘  │
                                   │
         ┌──────────────────────┐  │
         │ plan-reviewer        │ ─┘
         │ (change impact)      │
         └──────────────────────┘

         Parallel                        Sequential
         (background)                    synthesis
```

### When to Use Parallel Mode

- Change exceeds ~300 lines or touches multiple subsystems
- Security-sensitive paths (auth, data access, payment flows)
- Architectural decisions need a second opinion
- PR review against a feature branch with a known implementation plan

### Agent Roles

| Agent | Focus | Five-Axis Coverage |
|---|---|---|
| `uncle-dev-ag-code-reviewer` | Code quality, correctness, readability | Correctness, Readability, Performance |
| `plan-reviewer` (architecture) | Pattern adherence, system fit, module boundaries | Architecture |
| `plan-reviewer` (change impact) | Risk, backward compatibility, regressions, security implications | Security, risk |
| `uncle-dev-ag-graph-analyst` | Structural blast radius via semantic graph | Architecture (graph-layer) — conditional |

**When to spawn `uncle-dev-ag-graph-analyst`:** Only when graphify is ON AND the change exceeds ~300 lines OR touches a god node identified in GRAPH_REPORT.md. Pass it: the primary changed module names and the question `"what is the structural blast radius of changes to [modules]?"`. Run it in background alongside the existing parallel agents; its findings feed the architecture reviewer.

For `--security` mode, add `uncle-dev-ag-security-auditor` to the parallel phase.

### Phase 1: Parallel Reviews (run all in background)

```
Task(
  subagent_type="uncle-dev-ag-code-reviewer",
  prompt="Review code quality for: [SCOPE]. Evaluate correctness, readability, performance. Output: issues with severity (critical/major/minor).",
  run_in_background=true
)

Task(
  subagent_type="general-purpose",
  prompt="Review architecture alignment for: [SCOPE]. Check: follows established patterns, consistent with system design, no architectural violations. Output: alignment assessment with concerns.",
  run_in_background=true
)

Task(
  subagent_type="general-purpose",
  prompt="Review change impact for: [SCOPE]. Assess: risk level, affected systems, backward compatibility, potential regressions, security implications. Output: risk assessment.",
  run_in_background=true
)

# Wait for all three before proceeding
```

### Phase 2: Synthesis

Pass all three outputs to `uncle-dev-ag-review-synthesizer`:

```
Task(
  subagent_type="uncle-dev-ag-review-synthesizer",
  prompt="""
  Synthesize reviews for: [SCOPE]

  Code quality review: [output from agent 1]
  Architecture review: [output from agent 2]
  Change impact review: [output from agent 3]
  """
)
```

The synthesizer deduplicates overlapping findings, classifies each as blocking or non-blocking, issues a verdict (APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION), and writes a PR summary paragraph.

### Review Modes

| Mode | Signal | Agents Used |
|---|---|---|
| Full | `/uncle-dev-review` | All three parallel + synthesis |
| Quick | `/uncle-dev-review --quick` | `uncle-dev-ag-code-reviewer` only |
| Security | `/uncle-dev-review --security` | All three + `uncle-dev-ag-security-auditor` in parallel phase |
| PR | `/uncle-dev-review PR #NNN` | Fetch diff first, then full mode |

## Dead Code Hygiene

After any refactoring or implementation change, check for orphaned code:

1. Identify code that is now unreachable or unused
2. List it explicitly
3. **Ask before deleting:** "Should I remove these now-unused elements: [list]?"

Don't leave dead code lying around — it confuses future readers and agents. But don't silently delete things you're not sure about. When in doubt, ask.

```
DEAD CODE IDENTIFIED:
- formatLegacyDate() in src/utils/date.ts — replaced by formatDate()
- OldTaskCard component in src/components/ — replaced by TaskCard
- LEGACY_API_URL constant in src/config.ts — no remaining references
→ Safe to remove these?
```

## Review Speed

Slow reviews block entire teams. The cost of context-switching to review is less than the waiting cost imposed on others.

- **Respond within one business day** — this is the maximum, not the target
- **Ideal cadence:** Respond shortly after a review request arrives, unless deep in focused coding. A typical change should complete multiple review rounds in a single day
- **Prioritize fast individual responses** over quick final approval. Quick feedback reduces frustration even if multiple rounds are needed
- **Large changes:** Ask the author to split them rather than reviewing one massive changeset

## Handling Disagreements

When resolving review disputes, apply this hierarchy:

1. **Technical facts and data** override opinions and preferences
2. **Style guides** are the absolute authority on style matters
3. **Software design** must be evaluated on engineering principles, not personal preference
4. **Codebase consistency** is acceptable if it doesn't degrade overall health

**Don't accept "I'll clean it up later."** Experience shows deferred cleanup rarely happens. Require cleanup before submission unless it's a genuine emergency. If surrounding issues can't be addressed in this change, require filing a bug with self-assignment.

## Honesty in Review

When reviewing code — whether written by you, another agent, or a human:

- **Don't rubber-stamp.** "LGTM" without evidence of review helps no one.
- **Don't soften real issues.** "This might be a minor concern" when it's a bug that will hit production is dishonest.
- **Quantify problems when possible.** "This N+1 query will add ~50ms per item in the list" is better than "this could be slow."
- **Push back on approaches with clear problems.** Sycophancy is a failure mode in reviews. If the implementation has issues, say so directly and propose alternatives.
- **Accept override gracefully.** If the author has full context and disagrees, defer to their judgment. Comment on code, not people — reframe personal critiques to focus on the code itself.

## Dependency Discipline

Part of code review is dependency review:

**Before adding any dependency:**
1. Does the existing stack solve this? (Often it does.)
2. How large is the dependency? (Check bundle impact.)
3. Is it actively maintained? (Check last commit, open issues.)
4. Does it have known vulnerabilities? (`npm audit`)
5. What's the license? (Must be compatible with the project.)

**Rule:** Prefer standard library and existing utilities over new dependencies. Every dependency is a liability.

## The Review Checklist

```markdown
## Review: [PR/Change title]

### Context
- [ ] I understand what this change does and why

### Correctness
- [ ] Change matches spec/task requirements
- [ ] Edge cases handled
- [ ] Error paths handled
- [ ] Tests cover the change adequately

### Readability
- [ ] Names are clear and consistent
- [ ] Logic is straightforward
- [ ] No unnecessary complexity

### Architecture
- [ ] Follows existing patterns
- [ ] No unnecessary coupling or dependencies
- [ ] Appropriate abstraction level

### Security
- [ ] No secrets in code
- [ ] Input validated at boundaries
- [ ] No injection vulnerabilities
- [ ] Auth checks in place
- [ ] External data sources treated as untrusted

### Performance
- [ ] No N+1 patterns
- [ ] No unbounded operations
- [ ] Pagination on list endpoints

### Verification
- [ ] Tests pass
- [ ] Build succeeds
- [ ] Manual verification done (if applicable)

### Verdict
- [ ] **Approve** — Ready to merge
- [ ] **Request changes** — Issues must be addressed
```
## See Also

- For detailed security review guidance, see `references/security-checklist.md`
- For performance review checks, see `references/performance-checklist.md`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It works, that's good enough" | Working code that's unreadable, insecure, or architecturally wrong creates debt that compounds. |
| "I wrote it, so I know it's correct" | Authors are blind to their own assumptions. Every change benefits from another set of eyes. |
| "We'll clean it up later" | Later never comes. The review is the quality gate — use it. Require cleanup before merge, not after. |
| "AI-generated code is probably fine" | AI code needs more scrutiny, not less. It's confident and plausible, even when wrong. |
| "The tests pass, so it's good" | Tests are necessary but not sufficient. They don't catch architecture problems, security issues, or readability concerns. |

## Red Flags

- PRs merged without any review
- Review that only checks if tests pass (ignoring other axes)
- "LGTM" without evidence of actual review
- Security-sensitive changes without security-focused review
- Large PRs that are "too big to review properly" (split them)
- No regression tests with bug fix PRs
- Review comments without severity labels — makes it unclear what's required vs optional
- Accepting "I'll fix it later" — it never happens

## Verification

After review is complete:

- [ ] All Critical issues are resolved
- [ ] All Important issues are resolved or explicitly deferred with justification
- [ ] Tests pass
- [ ] Build succeeds
- [ ] The verification story is documented (what changed, how it was verified)
