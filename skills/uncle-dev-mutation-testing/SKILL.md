> ## Documentation Index
> Fetch the complete documentation index at: https://agentskills.io/llms.txt
> Use this file to discover all available pages before exploring further.

---
name: uncle-dev-mutation-testing
description: Assesses test suite strength by introducing deliberate bugs one at a time and checking whether the test suite catches each one. Use after writing or refactoring tests to verify they would catch real defects. Use when test coverage looks adequate but confidence in the suite is low. Use when preparing to ship or before a major refactor.
---

# Mutation Testing

## Overview

Mutation testing measures whether the test suite would actually catch bugs — not just whether tests exist. It works by applying small, deliberate code changes (mutations) one at a time, running the tests, then reverting. A mutation the tests fail to catch is a gap in the suite. The output is a mutation score (killed/total) and a prioritised list of missing tests.

**Config check — run this first:**
```bash
grep "mutation-testing" .agents/uncle-dev-setup.yaml 2>/dev/null || echo "not set (default: enabled)"
```
If `.agents/uncle-dev-setup.yaml` contains `mutation-testing: false`, stop immediately and tell the user that mutation testing is disabled for this project. Do not proceed.

## When to Use

- After completing a TDD cycle — verify the tests you wrote are strong enough to catch regressions
- Before a major refactor — confirm the test suite is a reliable safety net
- When coverage metrics look good but suite confidence is low
- After a bug slip through code review that tests should have caught
- On pull requests where test adequacy is flagged as a concern
- Periodically on critical modules (auth, billing, data pipelines)

**When NOT to use:**
- On generated or boilerplate code with no meaningful logic (config, accessors, type declarations)
- When `.agents/uncle-dev-setup.yaml` has `mutation-testing: false`
- On test files themselves — only mutate production code
- When the test suite is already failing — fix it first

## Pre-flight

Before mutating anything:

1. **Check the config.** Read `.agents/uncle-dev-setup.yaml`. If `preferences.mutation-testing` is `false`, stop.
2. **Clean working tree.** Run `git status` on the files in scope. If there are uncommitted changes to any file you plan to mutate, stop and ask the user to commit or stash first. Every mutation must be revertable cleanly with `git checkout -- <file>`.
3. **Find the test runner.** Look for `pytest.ini`, `pyproject.toml [tool.pytest]`, `package.json` test script, `Makefile` test target, or a `tests/` directory. Ask the user if uncertain. Confirm the test suite passes on unmodified code before starting — if it doesn't, stop.
4. **Agree on scope.** If no scope was given, look at the project's source layout and ask the user to pick a module. Do not try to mutate everything at once. Prioritise code with meaningful logic (branching, arithmetic, state changes) over config or trivial accessors.

## Process

Work through the files in scope one at a time.

### For each file

**Step 1 — Choose mutations.**
Read the file. Identify 3–8 candidate mutations from the catalogue in `mutation-catalogue.md`. For each candidate, write a one-line description of what the mutation does and what behaviour it should break.

**Step 2 — Apply → test → revert.**

For each mutation:

a. **Apply** using `Edit`. Change as little as possible — usually one line.

b. **Run tests.** Use the test runner identified in pre-flight. If the suite is large, run the relevant subset. Use a timeout — if tests hang, that counts as "killed".

c. **Record the result:**
- **Killed** — a test failed. Note which test. Rate the diagnostic quality:
  - *Clear* — failure message immediately points to the bug. A developer would fix it in minutes.
  - *Indirect* — a test failed but the message describes a symptom, not the cause. A developer would need to investigate.
  - *Cascading* — many tests failed, making root cause hard to locate. Suggests the code lacks focused unit tests of its own.
- **Survived** — no test failed. This is a gap. Note what behaviour is untested.

d. **Revert immediately:** `git checkout -- <file>`. Run `git diff <file>` to confirm the file is clean before moving on. Never stack mutations.

**Step 3 — Never leave a mutation in place.** If something goes wrong and the file state is uncertain, run `git diff <file>` to check, then `git checkout -- <file>` to restore.

Use `TaskCreate` to track progress when there are more than a handful of files.

## Reporting

After completing all mutations for the scope, produce a summary table:

```
| # | File           | Mutation                     | Result   | Diagnostic | Notes               |
|---|----------------|------------------------------|----------|------------|---------------------|
| 1 | pipeline.py    | Negate active check          | Killed   | Clear      | test_inactive_user  |
| 2 | pipeline.py    | Delete cache write           | Survived | —          | No cache test       |
| 3 | scoring.py     | Return 0 instead of score    | Killed   | Indirect   | Assertion on rank   |
```

Then provide:

1. **Mutation score:** killed / total (e.g. 6/8 = 75%).
2. **Uncaught mutations:** each survived mutation with a sentence explaining what behaviour is untested and why it matters.
3. **Diagnostic quality:** note any killed mutations where the failure message was Indirect or Cascading, and suggest how the test could be sharpened.
4. **Recommended tests:** for each survived mutation, describe a test that would catch it. Group by theme when several gaps point to the same missing area.

## Implementing Missing Tests

After presenting the report, ask the user whether they'd like the recommended tests implemented. If yes:

1. **Locate the right test file.** Follow the project's existing test layout. Don't create a new test file when an existing one covers the same module.
2. **Write focused tests.** Each test targets one survived mutation. Name the test after the behaviour it verifies, not the mutation: `test_cache_is_populated_after_first_call`, not `test_mutation_2`.
3. **Verify.** Run the test suite to confirm new tests pass on unmodified code. Then re-apply each corresponding mutation and confirm the new test catches it.
4. **Don't over-test.** If one well-designed test would catch multiple survived mutations, write one test, not several.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Coverage is at 85%, we're fine." | Coverage measures whether lines were executed, not whether tests assert correct behaviour. A line can be covered by a test that would pass even if the logic is wrong. |
| "These tests are too slow to run per-mutation." | Run the relevant subset, not the full suite. A focused test file over the module under test takes seconds. |
| "The code is too complex to mutate meaningfully." | Complex code is exactly where mutation testing is most valuable — that's where subtle logic bugs hide. |
| "We'll do it later before the big release." | The best time is immediately after writing the tests, while the code is still fresh and fixing gaps is cheap. |
| "A mutation score of 75% is good enough." | 75% means 1 in 4 deliberate bugs goes undetected. Whether that's acceptable depends on the criticality of the module. |

## Red Flags

- Mutations survive in code paths that handle authentication, authorisation, billing, or data integrity
- Entire categories of mutations consistently survive (e.g. all guard clause deletions pass) — signals a systematic gap in the test strategy
- Test names describe implementation details (`test_calls_write_cache`) rather than behaviour (`test_result_is_cached_after_first_call`) — the tests are testing the how, not the what, and won't survive refactors
- The mutation score drops significantly from one run to the next without code changes — tests may be non-deterministic or order-dependent
- All surviving mutations are in the same file or module — suggests a skip in the TDD workflow for that area
- Diagnostic quality is consistently Indirect or Cascading — tests lack isolation and will be hard to debug under real failures

## Verification

- [ ] All mutations reverted — `git status` shows a clean working tree
- [ ] Mutation score recorded and reported (killed / total)
- [ ] Every survived mutation has a named behaviour gap and a recommended test
- [ ] New tests (if implemented) pass on unmodified code
- [ ] New tests (if implemented) are confirmed to kill their corresponding mutations
- [ ] No test files were mutated — only production code
- [ ] The test runner was confirmed passing before mutations started

## See Also

- `uncle-dev-test-driven-development` — for writing the tests that mutation testing evaluates
- `mutation-catalogue.md` — the 8-category mutation catalogue with code examples
