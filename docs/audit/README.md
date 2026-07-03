# Uncle Dev Ecosystem Audit — 2026-07-02

Full architectural, functional, and performance audit of the uncle-dev platform
(46 skills, 29 commands, 9 agents, 11 wired hooks, 18 scripts). Conducted with
five parallel audit agents covering skills, commands, agents+hooks,
scripts+config, and whole-system integration.

## Verdict

The **static inventory is healthy**: marketplace.json ↔ disk is a perfect
bidirectional match, all frontmatter is valid, all 29 shell scripts pass
`bash -n`, and all 9 test suites pass. But the **runtime enforcement layer is
largely inert** and several workflow handoffs are format-incompatible. The
system's documented guarantees (spec-coherence gating, destructive-command
blocking, parallel-safe task picking) currently do nothing at runtime.

## Fix plans (ordered by priority)

| # | File | Severity | Theme |
|---|------|----------|-------|
| 01 | [01-hook-contract.md](01-hook-contract.md) | P0 | 7 of 11 wired hooks are inert or non-blocking |
| 02 | [02-setup-project-config.md](02-setup-project-config.md) | P0 | setup-project.sh writes broken configs; violates config boundary |
| 03 | [03-plugin-fork-drift.md](03-plugin-fork-drift.md) | P0 | plugins/uncle-dev/commands/ stale fork; drift guard is name-only |
| 04 | [04-skill-loader.md](04-skill-loader.md) | P0 | Silent dead skill load; wrong namespace; no validation |
| 05 | [05-mode-detection.md](05-mode-detection.md) | P1 | Step-0 SDD-mode detection duplicated 8×, with gaps and contradictions |
| 06 | [06-plan-next-task-handoff.md](06-plan-next-task-handoff.md) | P0 | plan → next-task format mismatch; two spec universes never intersect |
| 07 | [07-missing-commands-agents.md](07-missing-commands-agents.md) | P1 | 5 phantom slash commands; phantom plan-reviewer agent; agent name mismatches |
| 08 | [08-plugin-cache-paths.md](08-plugin-cache-paths.md) | P0 | Wrong cache layout hardcoded in 6 places; setup install check never passes |
| 09 | [09-installer-safety.md](09-installer-safety.md) | P1 | uninstall-hermes rm -rf without repo guard; other installer drift |
| 10 | [10-doc-drift-hygiene.md](10-doc-drift-hygiene.md) | P2 | Five diverging inventories, 14 dead skill refs, orphans, own-rule violations |

## What is healthy (do not touch)

- `.claude-plugin/marketplace.json`: all 46 skills + 9 agents declared and present; zero undeclared.
- `scripts/uncle-dev-config.sh`: scalar / `--list` / `--validate` modes all work; env and session tiers work.
- All test suites green: `bash scripts/tests/run-all.sh` (9 suites + drift guard), `hooks/simplify-ignore-test.sh` (21/21).
- 46/46 SKILL.md files: valid YAML frontmatter, `name` matches directory.
- Zero dead cross-skill mentions (every `uncle-dev-*` token resolves).
- Commands have zero direct `.agents/uncle-dev-setup.yaml` reads (boundary held in commands/).
- openspec CLI availability is consistently checked with graceful fallback.

## Suggested execution order

Each numbered file is a self-contained work unit sized for one commit.
Recommended order: 01 → 02 → 03 → 04 (P0 core), then 08 → 06 → 05 → 07,
then 09 → 10. Files 01–04 have no dependencies on each other and can be done
in parallel. File 05 (centralized mode detection) should land before or with
03 (plugin fork sync) so the fork is regenerated from fixed sources.
