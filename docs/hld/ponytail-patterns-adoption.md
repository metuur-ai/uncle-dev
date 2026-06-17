# Ponytail Patterns Adoption — High-Level Design

## Overview

uncle-dev and ponytail are sibling agent-skill repos that solved overlapping problems differently. A research pass (`.devlocal/research/2026-06-16-improving-uncle-dev-with-ponytail-patterns.md`) identified 9 patterns ponytail uses that uncle-dev lacks, each grounded in file:line evidence. This change adopts all 9 — phased by dependency and effort — to close concrete gaps: silent drift between uncle-dev's canonical asset list and its hand-maintained copies, the absence of a whole-repo bloat audit, partial multi-host coverage, no in-code debt channel, set-once-only strictness, no env config layer, no benchmarks, and skills that load both `sdd_mode` branches when only one is ever active.

The work is delivered as four phases. Earlier phases are mechanical foundations that later phases depend on; nothing in a later phase is required for an earlier phase to ship and provide value.

## Stakeholders & Impact

- **uncle-dev maintainers** — today must hand-sync `marketplace.json`, README counts, and `plugins/uncle-dev/commands/` against `manifest.sh`; this drift is already present (43 skill dirs on disk vs 39 in marketplace.json vs "20" in README; 7 of 24 commands committed). After this ships, a guard fails the test suite on drift, so adding an asset is one edit.
- **Developers using uncle-dev in a project** — gain a whole-repo over-engineering audit, a `// @debt` shortcut channel with a harvest command, session-switchable strictness without editing project config, and an env-var override tier for per-run/CI control.
- **Agents/subagents working in the repo** — multi-branch skills load only the active `sdd_mode` branch, reducing context bloat per invocation.
- **Adopters on non-Claude hosts** (Cursor, Windsurf, Copilot, Cline, Kiro, pi) — get fuller, drift-guarded instruction coverage from the canonical `AGENTS.md`.
- **Evaluators / prospective adopters** — a benchmark harness gives reproducible evidence the skills change outcomes.

## Goals

- A drift guard fails CI/tests when any hand-maintained copy diverges from the canonical `manifest.sh` asset roots, and the **current** drift is fixed so the guard passes on first run.
- `uncle-dev-config.sh` resolves an env-var override tier ahead of the YAML, routed through the existing helper (nothing else reads the YAML).
- Each dual-branch skill exposes only the active `sdd_mode` branch at use time, without a runtime cost.
- A dedicated over-engineering audit produces a ranked, tagged, quantified cut-list, distinct from the existing clarity-first simplify and 5-axis review — and is demonstrated against uncle-dev's own config/manifest surface.
- A `// @debt <ceiling>, <upgrade>` convention plus a harvest command surface deliberately-kept shortcuts into a ledger, framed as conscious debt (not a TODO dump).
- Strictness (`execution_profile`/`tdd-mode`/`level`) is switchable mid-session via a hook-written flag the existing guards consult, with an optional statusline badge — Claude-only.
- Instruction-only hosts get always-on `AGENTS.md`-derived coverage plus on-demand skill copies, with new Cline/Kiro/pi/`copilot-instructions.md` targets, all drift-guarded.
- A benchmark harness compares no-skill vs uncle-dev on a small set of representative tasks with reproducible output.

## Non-Goals

- **No per-turn full-ruleset injection.** uncle-dev deliberately injects only a routing slice at SessionStart because its corpus is large; copying ponytail's always-on injection would bloat context. The mode-*filtering* technique transfers; the always-on injection does not.
- **No collapse of uncle-dev's config schema** to a single mode string. uncle-dev legitimately encodes project type, SDD mode, execution profile, and per-hook toggles. The lift is the env-override tier, not schema reduction.
- **No removal of the existing clarity-first simplify or 5-axis review.** The audit complements them; it does not replace either.
- **No change to the "fix now / file a bug" culture.** The `@debt` marker is for consciously-kept shortcuts with a ceiling and upgrade path, not a deferral dumping ground.
- **No hooks for non-Claude hosts.** uncle-dev hooks are Claude-only by design; session-switch strictness and statusline remain Claude-only.

## Success Criteria

- Running the test suite on a clean checkout passes, and intentionally drifting any copy (e.g. removing a skill from `marketplace.json`) makes it fail with a clear message.
- `UNCLE_DEV_<KEY>=...` overrides the corresponding YAML value for that run, verified through `uncle-dev-config.sh` only.
- Invoking a dual-branch skill in a `lid-ears` project surfaces only the lid-ears branch (and vice-versa for openspec).
- The audit emits one line per finding, tagged and ranked biggest-cut-first, ending with a `net: -N lines, -M deps` summary; running it on uncle-dev yields a concrete cut-list.
- `/uncle-dev-debt` lists every `// @debt` marker with its ceiling/upgrade path and flags markers lacking a trigger.
- `/uncle-dev-mode <strict|balanced|fast>` changes guard strictness for the session without editing `.agents/uncle-dev-setup.yaml`.
- `install-plugin.sh` writes `copilot-instructions.md`/`.clinerules`/`.kiro/steering` (and pi) adapters from `AGENTS.md`, and the drift guard covers them.
- The benchmark harness runs and emits a comparison table for the chosen tasks.

## Phasing (dependency-ordered)

- **Phase 1 — Mechanical foundations:** #1 drift-guard, #6 env-var override tier, #9 install-time mode-branch split. Low effort, no dependencies, enables later phases.
- **Phase 2 — Audit & self-application:** #2 over-engineering audit skill, #8 run the audit on uncle-dev itself. #8 depends on #2.
- **Phase 3 — Developer conventions & reach:** #4 `@debt` marker + harvest, #5 session-switchable strictness + statusline (depends on #6), #3 full-coverage instruction adapters (depends on #1's guard).
- **Phase 4 — Evidence:** #7 benchmark harness. Highest effort, no downstream dependents.
