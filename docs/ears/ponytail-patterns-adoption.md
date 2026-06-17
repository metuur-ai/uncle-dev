# Ponytail Patterns Adoption — EARS Specifications

Requirements are grouped by pattern, ordered into the four phases from the HLD. Phase N units have no dependency on phase >N.

---

## Phase 1 — Mechanical foundations

### Unit 1: Drift guard (#1)

| ID    | EARS statement |
| ----- | -------------- |
| R-1.1 | THE SYSTEM SHALL treat `scripts/lib/manifest.sh` asset roots as the single source of truth for the skill, agent, and command inventories. |
| R-1.2 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL assert that `.claude-plugin/marketplace.json` skill and agent lists match the canonical roots minus a declared intentional-exclusion allowlist. |
| R-1.3 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL assert that the README skill and command counts match the canonical counts. |
| R-1.4 | WHEN `scripts/check-manifest.sh` runs, THE SYSTEM SHALL assert that the `plugins/uncle-dev/commands/` set matches the canonical command list minus the intentional-exclusion allowlist. |
| R-1.5 | IF any asserted copy diverges from the canonical source, THE SYSTEM SHALL exit non-zero and print a per-divergence message naming the copy and the missing/extra entries. |
| R-1.6 | THE SYSTEM SHALL invoke `check-manifest.sh` from both `scripts/tests/run-all.sh` and `install.sh verify`. |
| R-1.7 | WHEN this change is committed, THE SYSTEM SHALL have reconciled all current drift (marketplace.json, README counts, `plugins/uncle-dev/commands/`) so that `check-manifest.sh` exits zero on a clean checkout. |
| R-1.8 | THE SYSTEM SHALL declare any deliberately-excluded asset in an allowlist co-located with `manifest.sh`, and the guard SHALL print the allowlist it honored so intentional exclusions are visible, not silent. |

### Unit 2: Env-var config override tier (#6)

| ID    | EARS statement |
| ----- | -------------- |
| R-2.1 | WHERE a config value is requested through `scripts/uncle-dev-config.sh`, THE SYSTEM SHALL resolve it as `UNCLE_DEV_<KEY>` env var, then YAML file value, then caller default. |
| R-2.2 | THE SYSTEM SHALL derive `<KEY>` from the dotted config path by uppercasing and replacing dots with underscores. |
| R-2.3 | IF an `UNCLE_DEV_<KEY>` env var is set, THE SYSTEM SHALL use its value without modifying `.agents/uncle-dev-setup.yaml`. |
| R-2.4 | THE SYSTEM SHALL keep `scripts/uncle-dev-config.sh` the only reader of `.agents/uncle-dev-setup.yaml`; the audit grep over `scripts/ .claude/ hooks/` SHALL return only the helper. |

### Unit 3: Install-time mode-branch split (#9)

| ID    | EARS statement |
| ----- | -------------- |
| R-3.1 | WHERE a skill body contains both a `lid-ears` branch and an `openspec` branch delimited by stable section markers, THE SYSTEM SHALL keep both branches in the canonical source file. |
| R-3.2 | WHEN a project is set up or the plugin is installed, THE SYSTEM SHALL select the single-mode variant of each dual-branch skill matching the resolved `sdd_mode` and drop the inactive branch from the installed copy. |
| R-3.3 | WHILE `sdd_mode` is `lid-ears`, THE SYSTEM SHALL ensure the installed copy of each affected skill exposes only the lid-ears branch (and only the openspec branch when `sdd_mode` is `openspec`). |
| R-3.4 | THE SYSTEM SHALL perform the split at install time with no runtime/per-invocation cost. |
| R-3.5 | IF the expected branch section markers are absent or unmatched in a skill source, THE SYSTEM SHALL fail loud and SHALL NOT ship a partially-trimmed copy. |
| R-3.6 | WHILE the split mechanism is not yet proven across all affected skills, THE SYSTEM SHALL default to the verbatim copy and treat the split as opt-in. |
| R-3.7 | THE SYSTEM SHALL provide a test asserting each dual-branch skill source still contains both branch markers, and that splitting yields the active branch. |

---

## Phase 2 — Audit & self-application

### Unit 4: Over-engineering audit skill (#2)

| ID    | EARS statement |
| ----- | -------------- |
| R-4.1 | THE SYSTEM SHALL provide an over-engineering audit capability distinct from clarity-first simplification and 5-axis code review. |
| R-4.2 | WHEN the audit runs, THE SYSTEM SHALL emit one line per finding tagged with exactly one of `delete|stdlib|native|yagni|shrink`. |
| R-4.3 | WHEN the audit emits findings, THE SYSTEM SHALL rank them biggest-cut-first and end with a `net: -N lines, -M deps possible` summary. |
| R-4.4 | THE SYSTEM SHALL support both a diff scope (changed files) and a whole-repo scope, reusing the existing parallel-orchestration and review-synthesizer pattern for whole-repo scale. |
| R-4.5 | THE SYSTEM SHALL NOT modify or remove the existing clarity-first simplify or 5-axis review skills. |
| R-4.6 | THE SYSTEM SHALL define the new skill per `skill-anatomy.md` with Overview, When to Use, Process, Common Rationalizations, Red Flags, and Verification sections. |

### Unit 5: Self-application of the audit (#8)

| ID    | EARS statement |
| ----- | -------------- |
| R-5.1 | WHEN the whole-repo audit is run against uncle-dev's own config and manifest surface, THE SYSTEM SHALL produce a ranked, tagged cut-list artifact. |
| R-5.2 | THE SYSTEM SHALL treat the cut-list as the deliverable; acting on the listed deletions is out of scope for this change. |

---

## Phase 3 — Developer conventions & reach

### Unit 6: `@debt` marker + harvest command (#4)

| ID    | EARS statement |
| ----- | -------------- |
| R-6.1 | THE SYSTEM SHALL define a `// @debt <ceiling>, <upgrade>` in-code convention for a consciously-kept shortcut, distinct in intent from `@spec` and `[D]`, where both `<ceiling>` and `<upgrade>` are mandatory in the grammar. |
| R-6.2 | WHEN `/uncle-dev-debt` runs, THE SYSTEM SHALL gather all `@debt` markers into a ledger showing each marker's location, ceiling, and upgrade path. |
| R-6.3 | IF a `@debt` marker lacks a trigger/upgrade path, THE SYSTEM SHALL flag it as a silent-rot risk. |
| R-6.4 | THE SYSTEM SHALL frame `@debt` as a channel for deliberately-kept shortcuts, not a general TODO deferral mechanism. |

### Unit 7: Session-switchable strictness + statusline (#5, Claude-only)

| ID    | EARS statement |
| ----- | -------------- |
| R-7.1 | WHEN `/uncle-dev-mode <strict\|balanced\|fast>` is invoked, THE SYSTEM SHALL write a session flag recording the chosen profile. |
| R-7.2 | WHILE a session-mode flag is set, THE SYSTEM SHALL have `spec-coherence-guard.sh` and `pre-commit-guard.sh` consult the flag (via the config helper's override tier) instead of the YAML `execution_profile`. |
| R-7.3 | THE SYSTEM SHALL NOT modify `.agents/uncle-dev-setup.yaml` when the session mode changes. |
| R-7.4 | WHERE a statusline is configured, THE SYSTEM SHALL optionally display the active session mode badge (e.g. `[UNCLE-DEV:STRICT]`). |
| R-7.5 | WHERE the host is not Claude Code, THE SYSTEM SHALL NOT install the mode hook or statusline. |

### Unit 8: Full-coverage instruction adapters (#3)

| ID    | EARS statement |
| ----- | -------------- |
| R-8.1 | WHEN `install-plugin.sh` runs for an instruction-only host, THE SYSTEM SHALL write an always-on rule derived from the canonical `AGENTS.md` plus on-demand skill copies. |
| R-8.2 | THE SYSTEM SHALL generate `copilot-instructions.md`, `.clinerules/`, `.kiro/steering/`, and pi adapters in addition to the existing Cursor/Windsurf/Copilot copies. |
| R-8.3 | THE SYSTEM SHALL register every generated adapter with the `check-manifest.sh` drift guard so divergence fails the test suite. |

---

## Phase 4 — Evidence

### Unit 9: Benchmark harness (#7)

| ID    | EARS statement |
| ----- | -------------- |
| R-9.1 | THE SYSTEM SHALL provide a `benchmarks/` harness comparing a no-skill arm against an uncle-dev arm on a representative task set. |
| R-9.2 | THE SYSTEM SHALL include at least one task each for spec-first feature work, refactoring, and review catch-rate (e.g. detecting injected `@spec` orphans or planted bugs). |
| R-9.3 | WHEN the harness runs, THE SYSTEM SHALL emit a reproducible comparison table of the arms across the task set. |
