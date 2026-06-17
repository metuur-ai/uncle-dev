# Ponytail Patterns Adoption — Low-Level Design

## Architecture

The change spans four subsystems of the repo. Each pattern is implemented where its evidence points (see Key file references in the research doc).

### Phase 1 — Mechanical foundations

**#1 Drift-guard — `scripts/check-manifest.sh`**
- Single source of truth already exists: `scripts/lib/manifest.sh` (`ASSET_SKILLS_ROOT`, agent/command roots).
- New script reads the canonical roots and asserts equality against the hand-maintained copies:
  - `.claude-plugin/marketplace.json` skill + agent lists.
  - README skill/command counts.
  - `plugins/uncle-dev/commands/` set vs canonical command list.
  - (After Phase 3) the generated instruction-host adapters.
- Wired into `scripts/tests/run-all.sh` and `install.sh verify`. Non-zero exit + per-divergence message on drift.
- **Also fixes current drift** so the guard passes on first commit: reconcile marketplace.json (add `uncle-dev-speech`, `uncle-dev-verbalized-sampling`, `uncle-dev-brownfield`, `uncle-dev-custom-me`, …), README counts, and `plugins/uncle-dev/commands/`.

**#6 Env-var override tier — `scripts/uncle-dev-config.sh`**
- Today resolution is: file value → caller default. Add a tier ahead of the file: `UNCLE_DEV_<KEY>` (key derived from the dotted config path, uppercased, dots→underscores) → file value → caller default.
- Must remain the *only* reader of the YAML (project rule). All env resolution lives inside the helper.

**#9 Install-time mode-branch split**
- Constraint: skills are static `.md` the host loads verbatim; there is no "on skill read" hook. So filtering at runtime (ponytail's `filterSkillBodyForMode`) cannot be ported directly.
- Chosen mechanism (research option **a**, the lazy choice): at **install time**, `setup-project.sh`/`install-plugin.sh` selects a single-mode variant of each dual-branch skill based on resolved `sdd_mode`, dropping the inactive `## …-LID` / `## …OpenSpec` section before the file lands in the project.
- Affected skills: `uncle-dev-spec-driven-development`, `uncle-dev-next-task`, `uncle-dev-planning-and-task-breakdown`, `uncle-dev-acknowledge`, and the dual-mode references in `uncle-dev-{wrap,knowledge-capture,shipping-and-launch}`.
- Canonical sources keep both branches (delimited by stable section markers the splitter keys on); only the installed copy is trimmed.

### Phase 2 — Audit & self-application

**#2 Over-engineering audit skill — `skills/uncle-dev-over-engineering-audit/`**
- New skill (or `--audit` mode on code-simplify); follows skill-anatomy.md.
- Output contract: one line per finding, tagged `delete|stdlib|native|yagni|shrink`, ranked biggest-cut-first, ending `net: -N lines, -M deps possible`.
- Two scopes: diff (changed files) and whole-repo. Reuses uncle-dev's existing parallel-orchestration + review-synthesizer pattern for whole-repo scale.
- Explicitly complements (does not replace) clarity-first `uncle-dev-dev-code-simplification` and 5-axis `uncle-dev-code-review-and-quality`.

**#8 Run the audit on uncle-dev itself**
- Apply #2's whole-repo audit to uncle-dev's own config/manifest surface (11-required-key `preferences`, 112-line YAML, 211-line config reader, stale counts). Produces a concrete cut-list artifact; acting on it is downstream, not part of this spec's done-ness.

### Phase 3 — Developer conventions & reach

**#4 `@debt` marker + harvest — `skills/uncle-dev-spec-annotations/` + new `/uncle-dev-debt`**
- Convention: `// @debt <ceiling>, <upgrade>` marks a consciously-kept shortcut with its limit and upgrade path. Distinct from `@spec` (forward traceability) and `[D]` (unbuilt requirement status).
- Harvest command greps markers into a ledger (modeled on `scan-spec-coherence.py` grep-to-report machinery) and flags any marker lacking a trigger/upgrade path as silent-rot risk.
- Framed as conscious debt, not a TODO dump (stays consistent with "fix now" culture).

**#5 Session-switchable strictness + statusline (Claude-only)**
- New `/uncle-dev-mode <strict|balanced|fast>` UserPromptSubmit hook writes a session flag file. Existing guards (`spec-coherence-guard.sh`, `pre-commit-guard.sh`, which already read `execution_profile`) consult the flag, overriding YAML for that session.
- Builds on #6: the flag is read through `uncle-dev-config.sh`'s override tier.
- Optional statusline badge (e.g. `[UNCLE-DEV:STRICT]`). uncle-dev currently has no statusline and no UserPromptSubmit hook — both are new, Claude-only.

**#3 Full-coverage instruction adapters — `scripts/install-plugin.sh`**
- Use the canonical `AGENTS.md` (~9 KB) as the always-on rule for instruction-only hosts, plus on-demand skill copies.
- Add targets: `copilot-instructions.md`, `.clinerules/`, `.kiro/steering/`, pi — in addition to existing partial Cursor/Windsurf/Copilot copies.
- New copies are registered with #1's drift guard from day one.

### Phase 4 — Evidence

**#7 Benchmark harness — `benchmarks/`**
- promptfoo-based harness comparing no-skill vs uncle-dev on a few representative tasks (spec-first feature, refactor, review-catch-rate; e.g. does `@spec` coherence catch injected orphans? does review catch planted bugs?).
- Emits a reproducible comparison table. Narrow by design — uncle-dev's value is harder to score than lines-of-code.

## Constraints

- **YAML access:** only `scripts/uncle-dev-config.sh` may read `.agents/uncle-dev-setup.yaml`. The env tier (#6) and session flag (#5) must route through it. Audit guard: `grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/ .claude/ hooks/` returns only the helper.
- **Hooks are Claude-only.** #5's UserPromptSubmit hook and statusline apply to Claude Code only (`install-codex.sh:28`, `install-opencode.sh:27`).
- **No "on skill read" hook exists.** #9 must be install-time, not runtime.
- **Skill format:** new skills follow `skill-anatomy.md` (Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification); supporting files only when content exceeds 100 lines.
- **No content duplication** between skills — reference, don't copy.
- **Single source of truth preserved:** `manifest.sh` stays canonical; the guard enforces copies, it does not introduce a second source.

## Key Decisions

- **All 9, phased (user-chosen).** One spec, four dependency-ordered phases; each phase ships independently. Rejected: speccing only a bundle (loses the roadmap) and one big undifferentiated unit (untestable).
- **#9 via install-time split, not runtime filter.** Rejected runtime filtering (no hook in skill-load path) and a build step emitting variants (more machinery); install-time selection fits uncle-dev's existing install-time host-gating with no runtime cost.
- **#2 complements, not replaces.** Keeps clarity-first simplify and 5-axis review intact; the audit answers a different question ("what can we delete?").
- **#4 framed as conscious debt.** Avoids tensioning with "fix now" culture by scoping the marker to deliberately-kept shortcuts with a ceiling.
- **Drift fixed in the same change as the guard.** A guard that fails on first run is useless; reconciling current drift is part of #1.

## Out of Scope

- Acting on the cut-list #8 produces (the audit is the deliverable; the deletions are a separate change).
- Per-turn always-on ruleset injection.
- Config schema reduction to a single mode string.
- Hooks/statusline for non-Claude hosts.
- Expanding the benchmark beyond the initial representative task set.
