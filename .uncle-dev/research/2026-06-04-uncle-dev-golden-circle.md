# Research: The Golden Circle of uncle-dev (Why / How / What)

**Date:** 2026-06-04
**Ticket:** none
**Question:** Answer the Why, How, and What of uncle-dev using Simon Sinek's Golden Circle model.
**Scope:** The uncle-dev / agent-skills repo as it exists today. Documentation of what IS — no recommendations.

> Sinek's Golden Circle: **WHY** (core purpose/belief — *not* the product), **HOW** (the distinctive processes/values/USP that realize the belief), **WHAT** (the tangible products/services). Most organizations communicate from the outside in (WHAT → HOW → WHY); the model argues for the inside out (WHY → HOW → WHAT). This document maps uncle-dev onto those three rings, grounded in repo evidence.

---

## WHY — The Core (purpose, cause, belief)

**uncle-dev exists because AI coding agents, left to their defaults, take the shortest path — skipping the discipline that makes software reliable. Its belief: agents can and must be made to work like senior engineers, consistently, on every change.**

The purpose is stated most directly in the README's "Why Agent Skills?" section and operationalized as cross-cutting behavior in the meta-skill.

- The problem it counters: *"AI coding agents default to the shortest path - which often means skipping specs, tests, security reviews, and the practices that make software reliable."* — `README.md:322`
- The belief / cure: *"Agent Skills gives agents structured workflows that enforce the same discipline senior engineers bring to production code."* — `README.md:322`
- Why anyone should care: *"…opinionated, process-driven workflows that separate production-quality work from prototype-quality work."* — `README.md:324`
- One-line purpose (tagline): *"Production-grade engineering skills for AI coding agents."* — `README.md:3`, expanded `README.md:5`
- The belief that "seems right" is not done: *"Verification is non-negotiable… 'Seems right' is never sufficient."* — `README.md:271` (echoed `skills/uncle-dev-using-agent-skills/SKILL.md:109`)
- The belief that agents rationalize skipping steps: *"Every skill includes a table of common excuses agents use to skip steps… with documented counter-arguments."* — `README.md:270`
- The belief that an agent's nature must be actively resisted: *"Your natural tendency is to overcomplicate. Actively resist it… If you build 1000 lines and 100 would suffice, you have failed."* — `skills/uncle-dev-using-agent-skills/SKILL.md:84-92`
- The most common failure it targets: *"The most common failure mode is making wrong assumptions and running with them unchecked. Surface uncertainty early."* — `skills/uncle-dev-using-agent-skills/SKILL.md:58`
- Anti-sycophancy belief: *"You are not a yes-machine… Honest technical disagreement is more valuable than false agreement."* — `skills/uncle-dev-using-agent-skills/SKILL.md:73-81`
- Spec-first belief: *"code without a spec is guessing"* / *"When in doubt, start with a spec."* — spec-driven-development description; `skills/uncle-dev-using-agent-skills/SKILL.md:134`
- Code/tests as asset vs liability: *"A codebase with good tests is an AI agent's superpower; a codebase without tests is a liability."* — `skills/uncle-dev-test-driven-development/SKILL.md:14`

**WHY in one sentence:** *We believe production-quality software comes from disciplined engineering judgment — so we encode that discipline into agents so "seems right" never passes for "verified."*

> Note: the WHY lives almost entirely in `README.md` and the `using-agent-skills` meta-skill. `CLAUDE.md`, `AGENTS.md`, and `AGENT_RULES.md` are operational/config documents, not purpose statements. README lines 343-391 contain appended brainstorm notes (Uncle Domain / Uncle Framework / Product Mode) that extend the WHY toward keeping *expected product behavior, current implementation, and platform reality in sync* — exploratory, not yet the established core.

---

## HOW — The Middle (distinctive methodology / USP)

**How uncle-dev realizes the belief: it turns engineering discipline into enforced, step-by-step skill workflows — each with anti-rationalization rebuttals and non-negotiable verification — wired into a Define→Ship lifecycle and backed by a spec-traceability graph and mechanical hooks.**

### USP 1 — The skill anatomy: "Process, not prose"
Every skill follows a mandatory 6-section structure (Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification). — `README.md:249-265`; `docs/originals/skill-anatomy.md:38-78`
- *"Skills are workflows, not reference docs. Steps, not facts."* — `docs/originals/skill-anatomy.md:138`
- *"Specific over general — 'Run `npm test`' beats 'verify the tests.'"* — `docs/originals/skill-anatomy.md:91-92`

### USP 2 — Anti-rationalization tables (the most distinctive mechanism)
*"The most distinctive feature… excuses agents use to skip important steps, paired with rebuttals. They prevent the agent from rationalizing its way out of following the process."* — `docs/originals/skill-anatomy.md:99-102`
- Example: *"I'll write tests after the code works" → "You won't. And tests written after the fact test implementation, not behavior."* — `skills/uncle-dev-test-driven-development/SKILL.md:385-394`

### USP 3 — Verification is non-negotiable (evidence over assumption)
*"Every verification checkbox requires proof."* — `docs/originals/skill-anatomy.md:141`; realized as literal command-evidence checklists — `skills/uncle-dev-test-driven-development/SKILL.md:435-446`. Every state-mutating skill closes with a `validate → fix → re-validate` loop anchored on a deterministic command — `docs/originals/skill-anatomy.md:148`.

### USP 4 — Progressive disclosure (token-conscious)
SKILL.md stays under ~500 lines / 5,000 tokens; spillover goes to colocated references that *must say when to load them*. — `docs/originals/skill-anatomy.md:110-124`

### USP 5 — The lifecycle: Define → Plan → Build → Verify → Review → Ship
Phase-tagged commands and skills map to the development lifecycle, each command auto-activating the right skills. — `README.md:8-14`, `156-204`, `281-302`

### USP 6 — Architecture intent flow: HLD → LLD → EARS specs → tests → code
*"HLD (product intent — written first) → segment selection → LLD per segment → EARS prefix → EARS specs → Tests with @spec → Code with @spec."* — `skills/uncle-dev-design-architecture-docs/SKILL.md:34-54`. `@spec` is *"one edge in a graph that connects durable product intent to the code that implements it."* — `skills/uncle-dev-spec-annotations/SKILL.md:9-12`

### USP 7 — Mechanical enforcement via hooks
Hook wiring (SessionStart, PreToolUse, PostToolUse, Stop) — `hooks/hooks.json:1-86`. **spec-coherence-guard** blocks edits/commits citing undefined spec IDs (exit 2), but *"skips silently when docs/specs/ does not exist"* — graceful adoption, escalating by `execution_profile`. — `hooks/spec-coherence-guard.sh:1-21,115-119`

### USP 8 — Single source of truth for config
`scripts/uncle-dev-config.sh` is the *only* reader of `.agents/uncle-dev-setup.yaml` (scalar / `--list` / `--validate`); skills branch on config at runtime (e.g. TDD reads `preferences.tdd-mode`). — `scripts/uncle-dev-config.sh:1-21`; `skills/uncle-dev-test-driven-development/SKILL.md:16-20`; enforced as a project rule with an audit guard — `CLAUDE.md:47`

### USP 9 — OpenSpec workflow + layered workspaces
*"`openspec/specs/` holds current project truth, `openspec/changes/<change-id>/` holds shared change truth, and `.devlocal/` is the disposable personal workspace."* — `README.md:38`. Team knowledge accrues in `.uncle-dev/learns/` and `.uncle-dev/research/`.

### USP 10 — Embedded Google engineering practices (not abstract principles)
*"…embedded directly into the step-by-step workflows agents follow."* — `README.md:326`
- Hyrum's Law — `skills/uncle-dev-api-and-interface-design/SKILL.md:22-31`
- Beyonce Rule + Test Pyramid (80/15/5) — `skills/uncle-dev-test-driven-development/SKILL.md:166-195`
- Chesterton's Fence — `skills/uncle-dev-dev-code-simplification/SKILL.md:111-113`
- Trunk-Based Development — `skills/uncle-dev-git-workflow-and-versioning/SKILL.md:18-20`
- Shift Left / Faster is Safer — `skills/uncle-dev-ci-cd-and-automation/SKILL.md:12-14`

**HOW in one sentence:** *Encode senior-engineer judgment as opinionated skill workflows — process-first, anti-rationalized, verification-gated — chained across a Define→Ship lifecycle and enforced by a spec graph, hooks, and a single config source.*

---

## WHAT — The Outer Ring (tangible products)

The visible, concrete outputs. *(Counts verified against the filesystem; the README is stale in places — noted below.)*

- **Skills — 39 directories** in `skills/`, each a `SKILL.md` workflow. (README says "21" at `README.md:152` — stale; the canonical set has grown to 39, e.g. acknowledge, feature-map, grill, knowledge-capture, mutation-testing, next-task, pre-mortem, research, setup, ubiquitous-language, wrap, uncle-senior, …)
- **Agent personas — 9 files** in `agents/`: code-reviewer, test-engineer, security-auditor, uncle-lead (Technical Lead), uncle-po (Product Owner), uncle-senior (Challenge/Duck), graph-analyst, repo-research-analyst, review-synthesizer. (Last three are subagents, not user-invoked.)
- **Slash commands — 22 files** in `.claude/commands/`: spec, design-docs, plan, build, test, spec-scan, spec-graph, review, code-simplify, ship, research, acknowledge, knowledge-capture, knowledge-maintenance, next-task, openspec-sync, proactive-memory, setup, spec-annotations, wrap, custom-me, uncle-senior. (README says "7" at `README.md:314` — stale.)
- **Hooks — 14 files** in `hooks/`: session-start, check-agents-md, openspec-guard, spec-coherence-guard, pre-commit-guard, destructive-command-guard, knowledge-capture-nudge, gate-notify, wrap-nudge, permission-notify, simplify-ignore(+test), `hooks.json`, `SIMPLIFY-IGNORE.md`.
- **Scripts** in `scripts/`: installers (`install-claude.sh`, `install-codex.sh`, `install-opencode.sh`, `install-plugin.sh`, `install-antigravity.sh`, `install-hermes.sh`, `install.sh`), config helpers (`uncle-dev-config.sh`, `uncle-dev-setup.schema.json`, `setup-project.sh`, `uncle-dev-load-skill.sh`), plus `lib/` and `tests/`.
- **Docs** in `docs/`: per-tool setup guides (cursor, gemini-cli, opencode, windsurf, copilot) plus `originals/`, `improved/`, `v2/`, `reference/`, `drafts/`.
- **Plugin packaging**: `.claude-plugin/plugin.json` (`uncle-dev` v1.4.0, MIT) + `marketplace.json` (`uncle-dev-agent-skills`, lists 43 skills incl. 4 vendored OpenSpec skills under `.claude/skills/`); Codex bundle at `plugins/uncle-dev/`.
- **Reference checklists**: README references a top-level `references/` (`README.md:236-242`) that **does not exist** on disk; reference content actually lives under `docs/reference/` and colocated inside each skill directory.
- **Supported install targets**: Claude Code (recommended), Cursor, Gemini CLI, Windsurf, OpenCode, GitHub Copilot, Codex — plus undocumented-in-README Antigravity and Hermes installers.

**WHAT in one sentence:** *A cross-tool plugin of 39 skill workflows, 9 specialist agent personas, 22 slash commands, 14 lifecycle hooks, and per-tool installers — usable from Claude Code, Cursor, Gemini, Windsurf, OpenCode, Copilot, and Codex.*

---

## The Golden Circle, condensed

| Ring | uncle-dev |
|------|-----------|
| **WHY** | Believe production-quality software requires senior-engineer discipline; AI agents default to skipping it. Make agents that don't cut corners. (`README.md:322-324`) |
| **HOW** | Process-not-prose skill workflows with anti-rationalization tables + non-negotiable verification, chained across Define→Ship, traced by HLD→LLD→EARS→tests→code, enforced by hooks and a single config source. (`docs/originals/skill-anatomy.md`, `hooks/`, `scripts/uncle-dev-config.sh`) |
| **WHAT** | 39 skills, 9 agents, 22 commands, 14 hooks, multi-tool installers — a portable plugin. (`skills/`, `agents/`, `.claude/commands/`, `hooks/`) |

---

## Evidence gaps / notes for future researchers
- README counts (21 skills, 7 commands, `references/` dir) are out of sync with the filesystem (39 skills, 22 commands, no `references/`). The Golden Circle WHY/HOW framing is unaffected; only WHAT counts differ.
- The deepest WHY/USP source is `docs/originals/skill-anatomy.md`, not the README — worth reading in full for the design philosophy.
- The README appendix (lines 343-391) and `.uncle-dev/research/2026-05-17-*companion*` docs sketch an evolving WHY (product/domain alignment) beyond pure code authoring.
