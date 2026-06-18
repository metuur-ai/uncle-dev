# Uncle Dev — Agent Skills

**Production-grade engineering skills for AI coding agents.**

Uncle Dev is a Claude Code plugin (also installable for Codex, OpenCode, Gemini, Cursor, Windsurf, and Copilot) that packages the workflows, quality gates, and best practices senior engineers use when building software. The skills encode _process_ — steps, checkpoints, and exit criteria — so AI agents follow the same discipline consistently across every phase of development.

```
  DEFINE            PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────────┐     ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ OpenSpec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  Change  │     │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────────┘     └──────┘      └──────┘      └──────┘      └──────┘
   /uncle-dev-spec           /uncle-dev-plan          /uncle-dev-build        /uncle-dev-test         /uncle-dev-review       /uncle-dev-ship
```

The plugin ships **44 skills**, **28 commands**, and **9 specialist agent personas**, all under the `uncle-dev-` namespace.

---

## Commands

The 28 commands are the lifecycle entry points; each one activates the right skills automatically. The table highlights the main ones.

| What you're doing            | Command                       | Key principle                       |
| ---------------------------- | ----------------------------- | ----------------------------------- |
| Define what to build         | `/uncle-dev-spec`             | OpenSpec change before code         |
| Author HLD/LLD architecture  | `/uncle-dev-design-docs`      | Segments map intent to code         |
| Plan how to build it         | `/uncle-dev-plan`             | Shared stories, private scratchpads |
| Pick the next ready task     | `/uncle-dev-next-task`        | Dependency-ordered work             |
| Build incrementally          | `/uncle-dev-build`            | One slice at a time                 |
| Prove it works               | `/uncle-dev-test`             | Tests are proof                     |
| Validate `@spec` coherence   | `/uncle-dev-spec-scan`        | Code → tests → specs link cleanly   |
| Build the spec graph         | `/uncle-dev-spec-graph`       | HLD → LLD → spec → test → code       |
| Review before merge          | `/uncle-dev-review`           | Improve code health                 |
| Simplify the code            | `/uncle-dev-code-simplify`    | Clarity over cleverness             |
| Detect over-engineering      | `/uncle-dev-overkill-detector`| `review` / `audit` / `debt` scopes  |
| Harvest deliberate debt      | `/uncle-dev-debt`             | `@debt` markers → ledger            |
| Switch strictness mid-session| `/uncle-dev-mode`             | `strict` / `balanced` / `fast`      |
| Operate as a senior peer     | `/uncle-dev-pro`              | Senior-collaborator working habits  |
| Ship to production           | `/uncle-dev-ship`             | Faster is safer                     |
| Surface past learnings       | `/uncle-dev-proactive-memory` | Context injection                   |

Other commands cover the full lifecycle: `/uncle-dev-research`, `/uncle-dev-brownfield`, `/uncle-dev-feature-map`, `/uncle-dev-acknowledge`, `/uncle-dev-spec-annotations`, `/uncle-dev-knowledge-capture`, `/uncle-dev-knowledge-maintenance`, `/uncle-dev-changelog`, `/uncle-dev-wrap`, `/uncle-dev-openspec-sync`, `/uncle-dev-custom-me`, `/uncle-dev-setup`, and `/uncle-senior`.

Skills also activate automatically based on what you're doing — designing an API triggers `api-and-interface-design`, building UI triggers `frontend-ui-engineering`, and so on.

DEFINE and PLAN use OpenSpec as the default shared workflow: `openspec/specs/` holds current project truth, `openspec/changes/<change-id>/` holds shared change truth, and `.devlocal/` is the disposable personal workspace.

### Durable spec graph (optional)

When a repo opts in to the spec graph, durable behavior IDs live in `docs/specs/<segment>-specs.md` (separate from transient OpenSpec changes), and code/tests carry `@spec` annotations that connect them to those IDs. The graph flows `HLD → LLD → EARS specs → tests → code`. Validate with `/uncle-dev-spec-scan`, visualize with `/uncle-dev-spec-graph` (output written to `graphify-out/`), and a `spec-coherence-guard.sh` PreToolUse hook blocks edits/commits that cite undefined IDs. The OpenSpec tracker (`/uncle-dev-openspec-sync`) reports per-change `spec_coverage` when each `proposal.md` declares an `## EARS Specs` block. See [`uncle-dev-spec-annotations`](skills/uncle-dev-spec-annotations/SKILL.md) and [`uncle-dev-design-architecture-docs`](skills/uncle-dev-design-architecture-docs/SKILL.md) for the full model.

---

## Quick Start

<details>
<summary><b>Claude Code (recommended)</b></summary>

**Marketplace install:**

```
/plugin marketplace add addyosmani/agent-skills
/plugin install uncle-dev@uncle-dev-agent-skills
```

> **SSH errors?** The marketplace clones repos via SSH. If you don't have SSH keys set up on GitHub, either [add your SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) or switch to HTTPS for fetches only:
>
> ```bash
> git config --global url."https://github.com/".insteadOf "git@github.com:"
> ```

**Local / development:**

```bash
git clone https://github.com/addyosmani/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

</details>

<details>
<summary><b>Codex</b></summary>

Install Uncle Dev as a native local plugin assembled from the shared `skills/` and `agents/` directories at install time.

**User install:**

```bash
./scripts/install-codex.sh
```

**Project install:**

```bash
./scripts/install-codex.sh --scope local /path/to/your-project
```

This creates `plugins/uncle-dev/` and `.agents/plugins/marketplace.json` in the selected install root. Shared skills and agent personas are copied into the assembled plugin bundle by the installer, not duplicated in source control.

</details>

<details>
<summary><b>Cursor</b></summary>

Copy any `SKILL.md` into `.cursor/rules/`, or reference the full `skills/` directory. See [docs/originals/cursor-setup.md](docs/originals/cursor-setup.md).

</details>

<details>
<summary><b>Gemini CLI</b></summary>

Install as native skills for auto-discovery, or add to `GEMINI.md` for persistent context. See [docs/originals/gemini-cli-setup.md](docs/originals/gemini-cli-setup.md).

**Install from the repo:**

```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

**Install from a local clone:**

```bash
gemini skills install ./agent-skills/skills/
```

</details>

<details>
<summary><b>Windsurf</b></summary>

Add skill contents to your Windsurf rules configuration. See [docs/originals/windsurf-setup.md](docs/originals/windsurf-setup.md).

</details>

<details>
<summary><b>OpenCode</b></summary>

Uses agent-driven skill execution via AGENTS.md and the `skill` tool. See [docs/originals/opencode-setup.md](docs/originals/opencode-setup.md).

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

Use agent definitions from `agents/` as Copilot personas and skill content in `.github/copilot-instructions.md`. See [docs/originals/copilot-setup.md](docs/originals/copilot-setup.md).

</details>

<details>
<summary><b>Other agents</b></summary>

Skills are plain Markdown — they work with any agent that accepts system prompts or instruction files. The multi-host installer (`scripts/install-plugin.sh`) also emits thin, drift-checked instruction adapters for Cline (`.clinerules/`), Kiro (`.kiro/steering/`), pi, and Copilot (`copilot-instructions.md`) from the canonical `AGENTS.md`. See [docs/originals/getting-started.md](docs/originals/getting-started.md).

</details>

---

## All 44 Skills

The commands above are the entry points. Under the hood, they activate these 44 skills — each one a structured workflow with steps, verification gates, and anti-rationalization tables. You can also reference any skill directly.

### Define — Clarify what to build

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [research](skills/uncle-dev-research/SKILL.md) | Parallel subagent exploration of the codebase as-is, synthesized to `.devlocal/research/` | Starting on an unfamiliar codebase or asking "how does X work?" |
| [idea-refine](skills/uncle-dev-idea-refine/SKILL.md) | Structured divergent/convergent thinking to turn vague ideas into concrete proposals | You have a rough concept that needs exploration |
| [verbalized-sampling](skills/uncle-dev-verbalized-sampling/SKILL.md) | Generate diverse candidate approaches before converging, to avoid anchoring on the first idea | You need a spread of options, not one default |
| [grill](skills/uncle-dev-grill/SKILL.md) | Adversarial questioning of a proposal to surface gaps and unstated assumptions | Pressure-testing a plan before committing |
| [ubiquitous-language](skills/uncle-dev-ubiquitous-language/SKILL.md) | Establish a shared domain vocabulary used consistently across specs, code, and docs | Domain terms are ambiguous or used inconsistently |
| [spec-driven-development](skills/uncle-dev-spec-driven-development/SKILL.md) | Create tracked OpenSpec change artifacts (`proposal.md`, `design.md`, `tasks.md`, `execution.md`, `handoff.md`) before any code | Starting a new project, feature, or significant change |
| [design-architecture-docs](skills/uncle-dev-design-architecture-docs/SKILL.md) | Author durable HLD and per-segment LLDs that partition product intent into segments and feed EARS specs | Starting a product, adding a behavior segment, or refactoring boundaries |
| [acknowledge](skills/uncle-dev-acknowledge/SKILL.md) | Capture design-decision notes (OpenSpec `acknowledge/` or `docs/decisions/` ADRs by mode) | Recording a decision made during design |

### Brownfield — Understand existing code

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [feature-map](skills/uncle-dev-feature-map/SKILL.md) | Catalog product features by reading routes, controllers, services, and frontend pages — a user-facing inventory | You need a product-level inventory of an unfamiliar codebase |
| [brownfield](skills/uncle-dev-brownfield/SKILL.md) | 5-agent swarm reverse-engineers LLD + EARS specs from a feature map and anchors `@spec` annotations | Bringing legacy code under the spec graph |

### Plan — Break it down

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [planning-and-task-breakdown](skills/uncle-dev-planning-and-task-breakdown/SKILL.md) | Decompose an OpenSpec change into shared story-level tasks plus execution coordination | You have an approved change and need implementable shared stories |
| [next-task](skills/uncle-dev-next-task/SKILL.md) | Pick the next ready task from `docs/tasks/` (lid-ears) or OpenSpec changes (openspec mode) | Choosing what to work on next |

### Build — Write the code

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [incremental-implementation](skills/uncle-dev-incremental-implementation/SKILL.md) | Thin vertical slices — implement, test, verify, commit. Feature flags, safe defaults, rollback-friendly changes | Any change touching more than one file |
| [test-driven-development](skills/uncle-dev-test-driven-development/SKILL.md) | Red-Green-Refactor, test pyramid (80/15/5), test sizes, DAMP over DRY, Beyoncé Rule | Implementing logic, fixing bugs, or changing behavior |
| [spec-annotations](skills/uncle-dev-spec-annotations/SKILL.md) | `@spec`/`@feature`/`@rule` annotations connect code/tests to durable EARS spec IDs. AST scanner + blocking hook + graph generator | Annotating behavior entry points; running coherence checks |
| [context-engineering](skills/uncle-dev-context-engineering/SKILL.md) | Feed agents the right information at the right time — rules files, context packing, MCP integrations | Starting a session, switching tasks, or when output quality drops |
| [code-context](skills/uncle-dev-code-context/SKILL.md) | Per-directory `AGENTS.md` files that record architecture boundaries and conventions agents must read before editing | Editing in a directory; adding/moving/deleting source directories |
| [source-driven-development](skills/uncle-dev-source-driven-development/SKILL.md) | Ground every framework decision in official documentation — verify, cite sources, flag what's unverified | You want authoritative, source-cited code for any framework |
| [frontend-ui-engineering](skills/uncle-dev-frontend-ui-engineering/SKILL.md) | Component architecture, design systems, state management, responsive design, WCAG 2.1 AA accessibility | Building or modifying user-facing interfaces |
| [api-and-interface-design](skills/uncle-dev-api-and-interface-design/SKILL.md) | Contract-first design, Hyrum's Law, One-Version Rule, error semantics, boundary validation | Designing APIs, module boundaries, or public interfaces |

### Verify — Prove it works

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [browser-testing-with-devtools](skills/uncle-dev-browser-testing-with-devtools/SKILL.md) | Chrome DevTools MCP for live runtime data — DOM, console, network traces, performance profiling | Building or debugging anything that runs in a browser |
| [debug-error](skills/uncle-dev-debug-error/SKILL.md) | Five-step triage: reproduce, localize, reduce, fix, guard. Stop-the-line rule, safe fallbacks | Tests fail, builds break, or behavior is unexpected |
| [mutation-testing](skills/uncle-dev-mutation-testing/SKILL.md) | Measure test-suite strength by injecting faults and checking that tests catch them | You want evidence your tests actually assert behavior |

### Review — Quality gates before merge

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [code-review-and-quality](skills/uncle-dev-code-review-and-quality/SKILL.md) | Five-axis review, change sizing (~100 lines), severity labels (Nit/Optional/FYI), review-speed norms | Before merging any change |
| [dev-code-simplification](skills/uncle-dev-dev-code-simplification/SKILL.md) | Chesterton's Fence, Rule of 500, reduce complexity while preserving exact behavior | Code works but is harder to read than it should be |
| [over-engineering-audit](skills/uncle-dev-over-engineering-audit/SKILL.md) | Ranked, tagged cut-list (`delete`/`stdlib`/`native`/`yagni`/`shrink`) ending in a `net: -N lines, -M deps` summary | Hunting removable bloat — dead code, reinvented stdlib, speculative flexibility |
| [security-and-hardening](skills/uncle-dev-security-and-hardening/SKILL.md) | OWASP Top 10 prevention, auth patterns, secrets management, dependency auditing, three-tier boundary system | Handling user input, auth, data storage, or external integrations |
| [performance-optimization](skills/uncle-dev-performance-optimization/SKILL.md) | Measure-first approach — Core Web Vitals targets, profiling workflows, bundle analysis | Performance requirements exist or you suspect regressions |

### Ship — Deploy with confidence

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [git-workflow-and-versioning](skills/uncle-dev-git-workflow-and-versioning/SKILL.md) | Trunk-based development, atomic commits, change sizing (~100 lines), commit-as-save-point | Making any code change (always) |
| [ci-cd-and-automation](skills/uncle-dev-ci-cd-and-automation/SKILL.md) | Shift Left, Faster is Safer, feature flags, quality-gate pipelines, failure feedback loops | Setting up or modifying build and deploy pipelines |
| [deprecation-and-migration](skills/uncle-dev-deprecation-and-migration/SKILL.md) | Code-as-liability mindset, compulsory vs advisory deprecation, migration patterns, zombie-code removal | Removing old systems, migrating users, or sunsetting features |
| [documentation-and-adrs](skills/uncle-dev-documentation-and-adrs/SKILL.md) | Architecture Decision Records, API docs, inline documentation standards — document the _why_ | Making architectural decisions, changing APIs, or shipping features |
| [changelog](skills/uncle-dev-changelog/SKILL.md) | Generate user-facing changelog entries from merged changes | Preparing a release or summarizing what shipped |
| [speech](skills/uncle-dev-speech/SKILL.md) | Turn a shipped change into a clear spoken/written announcement for stakeholders | Communicating a launch or release |
| [shipping-and-launch](skills/uncle-dev-shipping-and-launch/SKILL.md) | Pre-launch checklists, feature-flag lifecycle, staged rollouts, rollback procedures, monitoring setup | Preparing to deploy to production |

### Capture, Handoff & Maintain

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [knowledge-capture](skills/uncle-dev-knowledge-capture/SKILL.md) | Document a recently solved problem into `.uncle-dev/learns/` while context is fresh | Right after "it's fixed" / "that worked" |
| [wrap](skills/uncle-dev-wrap/SKILL.md) | Compact the conversation into a handoff doc under `.devlocal/handoffs/` so a fresh agent can resume | Ending a session with work in progress |
| [knowledge-maintenance](skills/uncle-dev-knowledge-maintenance/SKILL.md) | Keep captured learnings and docs current; prune stale knowledge | Periodic upkeep of the team knowledge base |
| [custom-me](skills/uncle-dev-custom-me/SKILL.md) | Tailor uncle-dev behavior to personal/team preferences | Adapting the workflow to your team |

### Evaluate, Pre-mortem & Meta

| Skill | What It Does | Use When |
| ----- | ------------ | -------- |
| [uncle-senior](skills/uncle-senior/SKILL.md) | Senior principal engineer in Challenge (verdict) or Duck (rubber-duck) mode | A design feels heavier than the problem, or you're stuck |
| [pre-mortem](skills/uncle-dev-pre-mortem/SKILL.md) | Imagine the plan has failed, then work backward to surface hidden risks and preventions | Before launches, major decisions, or risky initiatives |
| [graphify-aware-analysis](skills/uncle-dev-graphify-aware-analysis/SKILL.md) | Shared protocol for querying the graphify semantic graph (`explain`/`path`/`query`), confidence rules | Referenced automatically by research, spec, planning, debug, review when `graphify-out/graph.json` exists |
| [setup](skills/uncle-dev-setup/SKILL.md) | Wire uncle-dev into a project across Claude Code, Codex, and OpenCode — hooks, dirs, config, rules | Setting up uncle-dev, or when hooks aren't firing |
| [using-agent-skills](skills/uncle-dev-using-agent-skills/SKILL.md) | Meta-skill: how to discover and apply the skills in this pack | Learning the system |

---

## Agent Personas

Pre-configured specialist personas for targeted reviews and decisions. All are **reactive** — they run only when explicitly invoked via a command or at a workflow checkpoint; skills may _recommend_ invoking one when its analysis would be most valuable, but the user always decides.

| Agent | Role | Perspective |
| ----- | ---- | ----------- |
| [code-reviewer](agents/uncle-dev-ag-code-reviewer.md) | Senior Staff Engineer | Five-axis code review with "would a staff engineer approve this?" standard |
| [test-engineer](agents/uncle-dev-ag-test-engineer.md) | QA Specialist | Test strategy, coverage analysis, and the Prove-It pattern |
| [security-auditor](agents/uncle-dev-ag-security-auditor.md) | Security Engineer | Vulnerability detection, threat modeling, OWASP assessment |
| [review-synthesizer](agents/uncle-dev-ag-review-synthesizer.md) | Review Synthesizer | Merges parallel review findings into one verdict, deduped issue list, and PR summary |
| [uncle-lead](agents/uncle-lead.md) | Technical Lead | Architecture decisions, API contracts, migration safety, rollback-aware design reviews |
| [uncle-po](agents/uncle-po.md) | Product Owner | Requirements clarity, proposal quality, scope boundaries, Given/When/Then acceptance criteria |
| [uncle-senior](agents/uncle-senior.md) | Senior Principal Engineer | Challenge/Duck modes for design decisions not yet committed to code |
| [graph-analyst](agents/uncle-dev-ag-graph-analyst.md) | Graph Traversal Specialist | Multi-hop semantic graph analysis — spawned when `graphify-out/graph.json` exists |
| [repo-research-analyst](agents/uncle-dev-ag-repo-research-analyst.md) | Repository Analyst | Structured repo exploration producing a handoff document — spawned by the research skill |

---

## Infrastructure & Quality Gates

Beyond the skills, uncle-dev ships mechanical guardrails that keep the system honest:

- **Drift guard** — `scripts/check-manifest.sh` asserts that `marketplace.json`, the README counts, and the committed `plugins/uncle-dev/commands/` set all match the canonical roots in `scripts/lib/manifest.sh` (minus a declared allowlist). Wired into `scripts/tests/run-all.sh` and `install.sh verify`, so stale copies fail the suite.
- **Session-switchable strictness** — `/uncle-dev-mode <strict|balanced|fast>` writes a session flag the `spec-coherence-guard.sh` and `pre-commit-guard.sh` hooks consult, overriding the project's `execution_profile` for the session without editing `.agents/uncle-dev-setup.yaml`. An optional statusline badge shows the active mode (Claude-only).
- **Env-var config overrides** — any setting resolves `UNCLE_DEV_<KEY>` env → YAML → default, so CI or a one-off run can override a value without touching project config. All config still flows through the single reader `scripts/uncle-dev-config.sh`.
- **Install-time mode-branch split** — dual-mode skills (lid-ears + openspec) carry both branches behind stable markers; `scripts/lib/split-skill-branch.sh` can drop the inactive branch at install time (opt-in via `UNCLE_DEV_SPLIT_SKILLS=1`).
- **`@debt` markers + harvest** — `// @debt <ceiling>, <upgrade>` flags a deliberately-kept shortcut with its limit and upgrade path; `/uncle-dev-debt` greps them into a ledger and sorts untriggered markers to the top as silent-rot risk. Distinct from `@spec` (forward traceability) and `[D]` (unbuilt requirements).
- **Benchmarks** — `benchmarks/` runs a promptfoo harness comparing a no-skill arm vs an uncle-dev arm across spec-first, refactor, and review-catch-rate tasks, emitting a reproducible comparison table.
- **Skill linting** — `bash scripts/lint-skills.sh [path]` runs nori-lint against every `SKILL.md` (report-only; `--enforce` to gate, `--deep` for LLM rules).

---

## How Skills Work

Every skill follows a consistent anatomy:

```
┌─────────────────────────────────────────────┐
│  SKILL.md                                   │
│                                             │
│  ┌─ Frontmatter ─────────────────────────┐  │
│  │ name: lowercase-hyphen-name           │  │
│  │ description: Use when [trigger]       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Overview         → What this skill does    │
│  When to Use      → Triggering conditions   │
│  Process          → Step-by-step workflow   │
│  Rationalizations → Excuses + rebuttals     │
│  Red Flags        → Signs something's wrong │
│  Verification     → Evidence requirements   │
└─────────────────────────────────────────────┘
```

**Key design choices:**

- **Process, not prose.** Skills are workflows agents follow, not reference docs they read. Each has steps, checkpoints, and exit criteria.
- **Anti-rationalization.** Every skill includes a table of common excuses agents use to skip steps (e.g., "I'll add tests later") with documented counter-arguments.
- **Verification is non-negotiable.** Every skill ends with evidence requirements — tests passing, build output, runtime data. "Seems right" is never sufficient.
- **Progressive disclosure.** The `SKILL.md` is the entry point. Supporting references load only when needed, keeping token usage minimal.

---

## Project Structure

```
agent-skills/
├── skills/                 # 44 skills (SKILL.md per directory, colocated references)
├── agents/                 # 9 specialist personas (uncle-dev-ag-*, uncle-lead, uncle-po, uncle-senior)
├── commands/               # 26 slash commands
├── hooks/                  # Session lifecycle hooks (session-start, spec-coherence-guard,
│                           #   pre-commit-guard, statusline-mode)
├── scripts/                # Installers (Claude/Codex/OpenCode + multi-host adapters),
│                           #   check-manifest, uncle-dev-config, lint-skills, lib/
├── benchmarks/             # promptfoo no-skill vs uncle-dev harness
├── plugins/uncle-dev/      # Assembled plugin bundle (commands mirror)
├── docs/                   # Setup guides (docs/originals/), HLD/LLD/EARS, drafts
└── .claude-plugin/         # marketplace.json
```

Supporting reference checklists live **alongside their skill**, not in a separate folder — e.g. [security-checklist.md](skills/uncle-dev-security-and-hardening/security-checklist.md), [performance-checklist.md](skills/uncle-dev-performance-optimization/performance-checklist.md), and [accessibility-checklist.md](skills/uncle-dev-frontend-ui-engineering/accessibility-checklist.md).

---

## Why Uncle Dev?

AI coding agents default to the shortest path — which often means skipping specs, tests, security reviews, and the practices that make software reliable. Uncle Dev gives agents structured workflows that enforce the same discipline senior engineers bring to production code.

Each skill encodes hard-won engineering judgment: _when_ to write a spec, _what_ to test, _how_ to review, and _when_ to ship. These aren't generic prompts — they're opinionated, process-driven workflows that separate production-quality work from prototype-quality work.

Skills bake in best practices from Google's engineering culture — including concepts from [Software Engineering at Google](https://abseil.io/resources/swe-book) and Google's [engineering practices guide](https://google.github.io/eng-practices/). You'll find Hyrum's Law in API design, the Beyoncé Rule and test pyramid in testing, change sizing and review-speed norms in code review, Chesterton's Fence in simplification, trunk-based development in git workflow, Shift Left and feature flags in CI/CD, and a dedicated deprecation skill treating code as a liability. These aren't abstract principles — they're embedded directly into the step-by-step workflows agents follow.

---

## Contributing

Skills should be **specific** (actionable steps, not vague advice), **verifiable** (clear exit criteria with evidence requirements), **battle-tested** (based on real workflows), and **minimal** (only what's needed to guide the agent).

See [docs/originals/skill-anatomy.md](docs/originals/skill-anatomy.md) for the format specification. Run `bash scripts/check-manifest.sh` and `bash scripts/tests/run-all.sh` before opening a PR — both must be green.

---

## License

MIT — use these skills in your projects, teams, and tools.
