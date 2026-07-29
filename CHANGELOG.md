# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Work since `045f983` (2026-06-02): new Define/Brownfield/Review/Ship skills, a phased "ponytail patterns" adoption (drift guard, config tiers, debt markers, session modes, instruction adapters, benchmark harness), plus documentation skills and fixes._

### Added

**New skills**

- **`uncle-dev-grill`** — builds a shared design concept by relentlessly interviewing the user (depth-first design-tree walk, no fixed question cap) and synthesizing the answers into a PRD that feeds `uncle-dev-spec`. (Define)
- **`uncle-dev-ubiquitous-language`** — builds and maintains a DDD-style domain glossary (`docs/ubiquitous-language.md`) via codebase-scan or conversation mode, flagging ambiguities and synonyms; loaded as context during spec and planning. (Define)
- **`uncle-dev-verbalized-sampling`** — generates diverse edge cases for richer spec and test coverage. (Define)
- **`uncle-dev-brownfield`** — reverse-engineers LLD + EARS specs from a `/uncle-dev-feature-map` output via a 5-agent swarm: maps domains to segments, writes specs, drafts LLDs, and anchors `@spec` annotations. (Brownfield)
- **`uncle-dev-over-engineering-audit`** — finds removable bloat; one line per finding tagged exactly one of `delete|stdlib|native|yagni|shrink`, ranked biggest-cut-first, ending `net: -N lines, -M deps possible`. Diff and whole-repo scopes (whole-repo reuses the existing parallel-orchestration + review-synthesizer agent). (Review)
- **`uncle-dev-pre-mortem`** — imagines a plan has already failed and works backward to surface hidden risks before a launch or major decision. (Review)
- **`uncle-dev-speech`** — refines human-facing prose, with phrase, structure, and example references. (Ship)
- **`uncle-dev-changelog`** — generates user-facing changelogs from git history, translating technical commits into clear user-visible outcomes, with tone and example references. (Ship)

**New commands & capabilities**

- **`/uncle-dev-debt`** + the `// @debt <ceiling>, <upgrade>` marker convention (documented in `uncle-dev-spec-annotations`, both fields mandatory) — `harvest-debt.py` gathers markers into a ledger with location/ceiling/upgrade, flags malformed markers as silent-rot risk and sorts them to the top, and exits non-zero on rot risk.
- **`/uncle-dev-overkill-detector [review|audit|debt]`** — single command surfacing all over-engineering scopes: `review` runs the `uncle-dev-over-engineering-audit` skill against the diff for a tagged cut-list, `audit` runs the whole-repo scope (parallel fan-out + `uncle-dev-ag-review-synthesizer`), and `debt` harvests `@debt` markers into the ledger. A thin dispatcher over existing engines — no new orchestration.
- **`/uncle-dev-mode <strict|balanced|fast>`** — session-switchable strictness via a `UserPromptSubmit` hook that writes a session flag (`.uncle-dev/session-mode`, never mutates the YAML); `uncle-dev-config.sh` gains a session-flag tier for `execution_profile` (env → session flag → YAML → default). Rendered as `[UNCLE-DEV:<PROFILE>]` in the statusline without hijacking an existing one (Claude Code only).
- **`/uncle-dev-pro`** — session behavioral mode that has the agent operate as a senior collaborator, enforcing eight working habits for the rest of the session (act don't overplan, lead with the outcome, ground every claim, stop only at real boundaries, assess don't act uninvited, match effort to task, use the reason not just the request, keep lessons and check your own work) plus a one-paragraph "pocket version" fallback. Pure prompt-injection command — no hooks or scripts.
- **Full-coverage instruction adapters** — installer now emits per-tool instruction files: GitHub Copilot (`.github/copilot-instructions.md`), Cline (`.clinerules/`), Kiro (`.kiro/steering/`), and Pi (`.pi/rules/`), each writing the always-on AGENTS.md-derived rule plus curated on-demand skill copies. `check-manifest.sh --adapters <dir>` drift-guards generated adapters so hand-edits fail.
- **Benchmark harness** (`benchmarks/`) — promptfoo-based no-skill vs uncle-dev arms (same pinned model at temp 0) over three tasks (spec-first feature, interface-preserving refactor, review catch-rate with a planted off-by-one bug and an orphaned `@spec` id), with an offline grader and a byte-stable reproducible Markdown report.
- **Drift guard** (`scripts/check-manifest.sh`) — asserts marketplace/manifest skill + agent counts, README skill/command counts, and the plugin command set against the canonical roots minus an allowlist; wired into the test suite and install verify.
- **Env-var config override tier** — `uncle-dev-config.sh` resolves `UNCLE_DEV_<KEY>` env overrides above YAML and defaults, without mutating config.
- **Opt-in install-time skill-branch split** — `UNCLE_DEV_SPLIT_SKILLS=1` drops the inactive `sdd_mode` branch from dual-branch skills at install time (default ships verbatim).
- **nori-lint integration** for linting `SKILL.md` files.
- **Documentation skills** (`.claude/skills/`) — `docs-style`, `howto-docs`, `reference-docs`, `tutorial-docs`, `explanation-docs`, `review-ai-writing`, plus drafting/improvement helpers (`draft-docs`, `ensure-docs`, `improve-doc`, `humanize-beagle`).
- Expanded reference docs — Golden Circle model, FAQ & Troubleshooting, Learning Paths, tool-integration guides, and a prompts-by-skill reference.

**Earlier Unreleased work (from `045f983`)**

- **`request-refactor-plan` reference** (under `uncle-dev-dev-code-simplification`) — interviews the user and breaks a large refactor into a tiny-commit plan.
- **`design-an-interface` reference** (under `uncle-dev-dev-code-simplification`) — "Design It Twice": generates and compares radically different interface shapes by module depth.
- **Module Depth** section in `uncle-dev-api-and-interface-design` — deep vs shallow modules, with an AI-navigability rationale, rationalizations, a red flag, and a verification item.

### Changed

- **Command location** — commands moved from `.claude/commands/` to `commands/` (the `.claude/` prefix is dropped); install scripts and tests updated to match.
- **README** rewritten as accurate uncle-dev documentation.
- **Docs** — task and requirement definitions gained explicit "why" sections for clarity; skill descriptions refreshed across many skills.
- **`uncle-dev-dev-code-simplification`** — added an "Escalating Beyond Inline Simplification" section that routes interface-shape problems to `design-an-interface` (design phase) and too-large refactors to `request-refactor-plan` (build phase).
- **Glossary integration** — `uncle-dev-spec-driven-development` and `uncle-dev-planning-and-task-breakdown` now load the ubiquitous-language glossary and flag off-glossary terms.
- **Cross-phase wiring** — `design-architecture-docs` points to `design-an-interface` for uncertain module boundaries; `incremental-implementation` and `planning-and-task-breakdown` point to `request-refactor-plan` for large refactors.
- **Framing** — named "software entropy" in `dev-code-simplification`; added gray-box risk-tiering (strategic architect / tactical programmer) to `design-architecture-docs`; `idea-refine` now hands off to `grill`.
- **Code review** — added a module-depth check to the Architecture axis of `uncle-dev-code-review-and-quality`.
- **`uncle-senior`** — adopts ponytail's conscious-deferral discipline: the Challenge verdict gains a `DEFERRED:` field that ties off every scope cut with a **ceiling** (the condition that forces revisiting) and an **upgrade path**, so "later" doesn't become "never"; cuts persisting in code route to `// @debt <ceiling>, <upgrade>` (harvestable via `/uncle-dev-overkill-detector debt`); the cut-vocabulary (`yagni`/`stdlib`/`native`) and Duck-mode "what would make you need it later?" question reinforce it. Cross-links `uncle-dev-over-engineering-audit` and `uncle-dev-spec-annotations`.
- **Registration** — new skills and commands added to both marketplace manifests, the relevant phases in `CLAUDE.md`, and `scripts/setup-project.sh`; drift guard kept green throughout.
- **BREAKING — skill renamed** — `uncle-dev-setup` is now `uncle-dev-setup-local`, naming it for what it does: configure the local project, as distinct from the global uncle-dev installation. **The `/uncle-dev-setup` command name is unchanged**, so nothing changes for anyone invoking it that way. There is deliberately no alias for the old skill name. **Migration:** any project keying `skills.overrides` or `skills.companions` to `uncle-dev-setup` in `.agents/uncle-dev-setup.yaml` must re-key to `uncle-dev-setup-local` — `uncle-dev-load-skill.sh` fails open on an unknown override, so a stale key drops the customization silently rather than erroring. The `.agents/uncle-dev-setup.yaml` filename is also unchanged.
- **`setup-project.sh --non-interactive`** — takes the five workflow preferences from `UNCLE_DEV_PREFERENCES_*` instead of prompting, so an agent can complete a first-time setup after asking the user, with no terminal. Fail-closed: any variable unset or holding a disallowed value aborts before anything is written, and no default is ever applied. Reuses the names `uncle-dev-config.sh` already resolves rather than adding a second convention. Refused without `--update` when a config exists, since the variables would otherwise be silently discarded; `--update --non-interactive` is the idiom for repeated or unattended provisioning.
- **`--update` no longer rewrites the whole `CLAUDE.md` uncle-dev region** — it now replaces only an inner marked span, in place. Project prose, nested `BEGIN GENERATED` blocks, and the region's position in the file all survive. Previously the entire region was deleted and a canned block re-appended at end of file, which destroyed anything a project had added there.
- **`agent_skills_root` resolution** — resolved by authority (a checkout containing the running script, then `CLAUDE_PLUGIN_ROOT`, then the script's parent) and preserved on plain re-runs, so a routine setup no longer silently repoints a project from a developer's clone to a plugin cache. The config template still resolves from the script's own directory.

### Fixed

- **Spec scanner monorepo support** — `packages` added to default roots so `@spec` annotations under `packages/*/src/` (yarn workspaces and similar) are detected and the graph builder can establish spec-to-code relationships.
- **Research document paths** corrected from `.uncle-dev/research/` to `.devlocal/research/`.
- **`/uncle-dev-setup` refusing to run in already-configured projects** — the skill claimed the script would read stdin and silently default every answer. That is true only for first-time setup; whenever `.agents/uncle-dev-setup.yaml` exists the script takes the `SKIP_PREFS=1` branch and never calls `read`. The rule now branches on the same condition the script does.
- **`preferences.tdd-mode` was unreachable through the env override tier** — `uncle-dev-config.sh` derived the variable name by mapping dots to underscores but left hyphens intact, producing `UNCLE_DEV_PREFERENCES_TDD-MODE`, which is not a valid shell identifier. Hyphens now map as well.
- **Post-write config verification was defeated by the env override tier** — the assertion read the value back through `uncle-dev-config.sh`, which resolves the environment ahead of the file. With `UNCLE_DEV_PREFERENCES_SDD_MODE` set it failed spuriously and blamed the template's scalar form, and where the value happened to match it would have passed despite a failed write. Verification now clears that namespace and covers all five preferences rather than `sdd_mode` alone.

## [1.4.1] - 2026-05-30

_Commits `276f84b`, `a8c6754`, `6692486`._

### Added

- **`uncle-dev-custom-me` skill** — scaffolds user-authored override and companion skills, printing the YAML registration block for both modes. Includes companion/override templates and the `uncle-dev-load-skill.sh` loader that resolves active skills and companions from user config.
- **Durable-project-rules best practice** — `.uncle-dev/learns/best-practices/durable-rules-go-to-tracked-files-not-memory-2026-05-30.md`, guidance on putting durable rules in tracked files rather than memory.

### Changed

- Removed the "Documentation Index" section from SKILL.md files and refreshed descriptions across multiple skills.
- Bumped version to `1.4.1` across plugin manifests, install scripts, and related paths.

## [1.3.0]

_Baseline preceding `6692486` (overrides/companions support was added on top of this version)._

[Unreleased]: https://github.com/javierhbr/production-grade-agent-skills/compare/276f84b...HEAD
[1.4.1]: https://github.com/javierhbr/production-grade-agent-skills/compare/6692486~1...276f84b
[1.3.0]: https://github.com/javierhbr/production-grade-agent-skills/releases/tag/v1.3.0

this repo https://github.com/javierhbr/production-grade-agent-skills. its a fork from https://github.com/addyosmani/agent-skills .
the remote repo have https://github.com/addyosmani/agent-skills/releases and I want to know that change from version 0.5.0 til the latest version.
