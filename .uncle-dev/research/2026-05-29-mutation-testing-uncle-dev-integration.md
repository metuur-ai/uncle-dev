# Research: Integrating Mutation Testing into Uncle-Dev

**Date:** 2026-05-29
**Question:** How can the mutation-testing skill in `tmp/mutation-testing.md` improve uncle-dev?
**Source file:** `tmp/mutation-testing.md`

---

## 1. What the Source Skill Is

`tmp/mutation-testing.md` is a complete mutation-testing workflow document formatted as a **slash command** (not a SKILL.md). Evidence:

- Has frontmatter fields `argument-hint` and `disable-model-invocation: true` — these are slash command fields, not valid SKILL.md fields
- Has a `$ARGUMENTS` placeholder (slash command variable injection)
- Does NOT have the required SKILL.md sections: Common Rationalizations, Red Flags, Verification

The document defines a seven-step mutation-testing process:
1. Pre-flight (clean working tree, find test runner, confirm baseline passes)
2. Choose 3–8 mutations per file from an 8-category catalogue
3. Apply → run tests → revert cycle (one mutation at a time)
4. Classify results: Killed / Survived
5. Rate diagnostic quality: Clear / Indirect / Cascading
6. Report (summary table + mutation score + recommended tests)
7. Optionally implement the missing tests

**Mutation catalogue categories (8):**
1. Delete or skip a side effect
2. Negate or invert a condition
3. Change a boundary or comparison
4. Swap or hardcode a return value
5. Delete an early return or guard clause
6. Change an operator
7. Modify a default argument or constant
8. Swap the order of arguments or operands

---

## 2. What Uncle-Dev Currently Has for Testing

### Skills
| Skill | Phase | What it covers |
|---|---|---|
| `uncle-dev-test-driven-development` | Build | Writing tests (TDD cycle, Prove-It pattern, test pyramid, anti-patterns) |
| `uncle-dev-browser-testing-with-devtools` | Verify | UI/runtime testing in real browsers via Chrome DevTools MCP |
| `uncle-dev-code-review-and-quality` | Review | Five-axis review; asks "do tests cover the change?" but does not measure test strength |
| `uncle-dev-shipping-and-launch` | Ship | Checks EARS requirement-to-test traceability |
| `uncle-dev-ci-cd-and-automation` | Ship | Runs `npm test --coverage` in CI pipeline |

### Slash Commands
- `/uncle-dev-test` — invokes TDD skill
- `/uncle-dev-build` — includes testing in incremental implementation
- `/uncle-dev-review` — five-axis review with parallel agents

### No existing skill covers:
- Mutation testing
- Test strength / adequacy scoring
- Coverage gap identification beyond requirement traceability
- Retrospective test quality assessment (all current test skills are prospective — they guide writing new tests)

---

## 3. The Gap Mutation Testing Fills

**Lifecycle gap:** Uncle-dev can write tests (TDD) but cannot assess whether existing tests would catch bugs.

- TDD skill (`uncle-dev-test-driven-development`) produces tests for new code
- Code review skill asks "do tests exist?" but not "are these tests strong enough to catch a real bug?"
- The Verify phase (`uncle-dev-browser-testing-with-devtools`, `uncle-dev-debug-error`) covers browser UI and error debugging — no general code-level test quality check

**Conceptual gap:** There is no skill that distinguishes between:
- A test suite that *exists* (covered by TDD + coverage flags)
- A test suite that would *detect real defects* (mutation testing territory)

**Phase fit:** Mutation testing would slot into the **Verify** or **Review** phase. Currently:
- Verify: browser-testing-with-devtools, debug-error
- Review: code-review-and-quality, dev-code-simplification, security-and-hardening, performance-optimization

---

## 4. Format Gap Between Source File and SKILL.md Convention

The `tmp/mutation-testing.md` file needs these changes to become a valid uncle-dev skill:

### Frontmatter
Current (slash command format):
```yaml
---
name: mutation-testing
description: Perform mutation testing on the codebase...
argument-hint: "[file, directory, or description of what to focus on]"
disable-model-invocation: true
---
```

Required SKILL.md format:
```yaml
---
name: uncle-dev-mutation-testing
description: Assesses test suite strength by introducing deliberate bugs...
---
```

Rules:
- Name must use `uncle-dev-` prefix (convention for this project's skills)
- Remove `argument-hint` and `disable-model-invocation` fields
- Description: third-person verb phrase + "Use when..." trigger conditions
- Max 1024 characters

### Missing Required Sections
| Required Section | Present in tmp file? |
|---|---|
| Overview | No (has intro paragraph but not an `## Overview` section) |
| When to Use | No |
| Process | Yes (detailed, under "## Workflow") |
| Common Rationalizations | No |
| Red Flags | No |
| Verification | No |

### Existing Sections (keepable with renaming)
| tmp Section | Maps to |
|---|---|
| Pre-flight | Part of Process |
| Workflow | Process |
| Mutation Catalogue | Keep as-is (exceeds 100 lines — candidate for supporting file) |
| Assessing test failures | Part of Process |
| Reporting | Part of Process |
| Implementing missing tests | Part of Process |
| Critical Rules | Partial overlap with Red Flags |

### Supporting File Threshold
The Mutation Catalogue section is ~130 lines — exceeds the 100-line threshold for a supporting reference file. Convention: extract to `skills/uncle-dev-mutation-testing/mutation-catalogue.md`.

---

## 5. Historical Context

`.uncle-dev/learns/` is empty — no prior team learnings on this topic.

---

## 6. File Locations

| Item | Path |
|---|---|
| Source skill draft | `tmp/mutation-testing.md` |
| Closest existing skill | `skills/uncle-dev-test-driven-development/SKILL.md` |
| Skill anatomy reference | `docs/skill-anatomy.md` |
| Test patterns reference | `skills/uncle-dev-test-driven-development/testing-patterns.md` |
| Phase registry | `CLAUDE.md` (Skills by Phase section) |
| Slash commands dir | `.claude/commands/` |
| New skill target dir | `skills/uncle-dev-mutation-testing/` (does not exist yet) |

---

## 7. Scope Note

Adjacent areas observed but not investigated:
- Whether a `/uncle-dev-mutation-testing` slash command should be created alongside the skill
- Whether the skill should be in Verify or Review phase
- Whether `uncle-dev-test-driven-development` should reference this skill in its See Also section
