---
name: uncle-dev-subagent-model-routing
description: Shared protocol for routing subagent work to cheaper model tiers without losing analytic power. Not invoked directly — referenced by research, spec, build, and review skills whenever they spawn subagents. Defines the tier table, the four accuracy controls, and the write-safety rule.
---

## Overview

Cheap models do not fail by reasoning shallowly. They fail by producing confident, imprecise, or fabricated *citations* — a path that does not exist, a line number that is off, a summary of a file that was never opened. That is a retrieval failure, not an analysis failure, and it is detectable.

This gives a clean split. Retrieval and mechanical transformation move down a tier. Judgment, synthesis, and every decision that changes the repository stay on the session model. Applied this way, tiering cuts cost on the bulk of subagent tokens without touching the reasoning that determines the outcome.

## When to Use

Reference this protocol from any skill or command at the moment it spawns a subagent. Do not invoke it directly as a standalone task.

## The tier table

Route by the judgment the task actually requires, not by the importance of the surrounding work.

| Spawn shape | Model | Why |
|---|---|---|
| Bounded retrieval ("find every call site of X", "list the routes in `src/api/`") | `haiku` | Mechanical — the output is a list of locations |
| Keyword sweep over a small, known directory (`.uncle-dev/learns/`, `docs/ears/`) | `haiku` | Search, not interpretation |
| Mechanical transformation with a fixed output shape (extract a table, reformat findings into a template) | `haiku` | The schema is the reasoning |
| Templated document production against a rigid scaffold | `sonnet` | The template carries the structure; the agent fills it |
| Narrow, rule-driven interpretation (confidence thresholds, classification against stated criteria) | `sonnet` | Real judgment, but the rules are written down |
| Reproduction tests, scoped test authoring from a written spec | `sonnet` | Bounded by an existing description of the behavior |
| Open-ended questions ("why is it structured this way", "what are the tradeoffs") | inherit | Not retrieval — leave on the session model |
| Any synthesis that feeds a decision, spec, or design | inherit | This is the analysis; do not delegate it |

Pass the tier via the `model` parameter when spawning. Named agents that pin `model:` in their own frontmatter need no override — do not fight their pin from the call site.

## The four accuracy controls

A cheap tier is only safe when all four are in force. Dropping any one of them is where tiering starts costing accuracy.

1. **One question per subagent.** Split compound asks ("map auth and session handling") into separate spawns. Smaller models degrade on compound prompts far faster than on hard ones.
2. **Hard output contract.** Require a rigid schema — `path:line — one-line description` rows and nothing else. A tight schema leaves no ambiguity for the model to fill with plausible prose.
3. **Ban inference explicitly.** State it in the prompt: "Report only what you read. If you did not open the file, do not describe it. If you found nothing, say NOT FOUND." This converts a hallucination into an honest gap you can re-scout.
4. **Verify, don't trust.** Before the results enter synthesis, spot-check cited paths (`grep -c`, or Read the claimed line). Cheap to run, and it catches a bad subagent before its claims propagate into a document or a decision.

If a control cannot be applied — the question genuinely resists a fixed output shape, or there is no cheap way to verify the result — the task is not a retrieval task. Leave it on the session model.

## The write-safety rule

**Tiered subagents are read-only.** A `haiku` or `sonnet` spawn may use Glob, Grep, Read, and graph queries. It must not use Edit, Write, or destructive Bash.

The reason is asymmetry of cost. A bad retrieval result is caught by control 4 and re-run for pennies. A bad edit lands in the working tree, may be committed, and the orchestrator has no cheap way to notice it happened. Verification is what makes tiering safe, and there is no equivalent of `grep -c` for "was this the right change to make?"

The one exception is a scoped, tested artifact the orchestrator immediately verifies by running it — a reproduction test that must fail, for example. The orchestrator runs the test and sees red before proceeding. If the artifact cannot be verified by execution in the same turn, it does not qualify.

## Red Flags

- Passing `model: haiku` to a subagent that will Edit or Write
- A subagent prompt with "and" in the question — that is two spawns
- Delegating "figure out how X works and recommend an approach" to a cheap tier — the recommendation is the analysis
- Accepting cited paths into a spec or research document without spot-checking them
- Overriding a named agent's pinned `model:` from the call site
- Tiering down because the session is expensive, rather than because the task is mechanical

## Verification

- Every tiered spawn has a single question and a stated output schema
- Every tiered spawn's prompt contains the ban-inference sentence
- Cited paths were spot-checked before entering synthesis
- No tiered spawn was given write tools, except a repro test the orchestrator ran and watched fail
