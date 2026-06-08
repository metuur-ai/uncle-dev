# Research: Waza vs uncle-dev — Skills / Rules / Commands Gap Analysis

**Date:** 2026-06-07
**Author:** uncle-dev-research
**Question:** Analyze the gap of the skills, rules, and commands at `/Users/javierbenavides/others/ai-agents/Waza-main` against uncle-dev (`/Users/javierbenavides/others/ai-agents/production-grade-agent-skills`).
**Scope:** Documents what each system _is_, then maps the directional gaps in both directions. Factual inventory + gap matrix; not a recommendation set.

---

## 1. Two Different Philosophies (the root of every gap)

| Axis               | Waza (v3.28.0)                                                                                                        | uncle-dev                                                                                           |
| ------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Unit of capability | 8 **fat skills**, hard-capped at 8                                                                                    | ~40 **granular skills**                                                                             |
| Routing            | `skills/RESOLVER.md` + generated `scripts/dispatcher.md` (latent description-match)                                   | `.claude/commands/` (23 explicit slash commands) + `uncle-dev-using-agent-skills` flowchart         |
| Enforcement layer  | Install-time **rules** + dev-time **scripts**; no runtime hooks                                                       | 14 **runtime hooks** (session/pre-tool/post-tool/stop)                                              |
| Workflow model     | Chainable skills, no persisted workflow state                                                                         | Phase pipeline with persisted artifacts (spec→plan→build→review→ship)                               |
| Spec model         | None — `think` emits a plan, then stops                                                                               | HLD → LLD → EARS → `@spec` → tests → code, validated by guards                                      |
| Memory             | **Read-only** durable-context preflight (opt-in, 6 of 8 skills); never writes                                         | **Read+write** memory: `.uncle-dev/learns/`, `research/`, `.devlocal/handoffs/`                     |
| Config             | `VERSION` only; behavior is fixed                                                                                     | `.agents/uncle-dev-setup.yaml` (sdd_mode, tdd_mode, execution_profile, hook toggles, companions)    |
| Languages          | Bilingual (English + Chinese), de-AI prose                                                                            | English only                                                                                        |
| Distribution       | Codegen marketplace, ZIP for Claude Desktop, `npx skills add`, packaging allowlist, 20 smoke tests + pytest, CI gates | Multi-tool installers (Claude Code / Codex / OpenCode), plugin marketplace; lighter self-test suite |
| Content scope      | Includes **non-code** workflows (read URLs, write prose, learn a domain)                                              | Code/SDLC only                                                                                      |

**One-line framing:** Waza is a _lean, public, self-validating, bilingual generalist toolkit_ (incl. reading/writing/learning). uncle-dev is a _deep, enforcement-heavy, spec-driven SDLC pipeline_ with persistent team memory. The gaps fall out of these two stances.

---

## 2. Waza inventory (as-is)

### Skills (8, hard cap — `AGENTS.md:61`, `RESOLVER.md:78`)

| Skill    | Purpose                                 | Notable modes                                                                                                                                                                                  |
| -------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `think`  | Idea → approved, decision-complete plan | Lightweight / Evaluation (Kill·Keep·Pivot) / Triage / Full; validation-before-handoff gate (`think/SKILL.md:111-141`)                                                                          |
| `design` | Distinctive production UI               | Visual Quick-Fix / Screenshot Iteration / Lock-Direction-First; design-tokens, brand presets, data-viz refs                                                                                    |
| `check`  | Review before ship                      | Plan-Execution / Review / Triage / Release-Worthiness / Ship-Follow-through / **Project Audit scorecard**; `audit_signals.py`, reviewer-architecture/security agents (`check/SKILL.md:99-218`) |
| `hunt`   | Root cause before fix                   | Default / **Bisect** / Repeated-Regression / **Scope-Blast** / Native-Freeze / Rendering / IME-Unicode (`hunt/SKILL.md:57-229`)                                                                |
| `learn`  | Domain → published article              | 6-phase Deep Research / Quick Reference / Write-to-Learn / Canonical Article                                                                                                                   |
| `read`   | URL/PDF → summary or Markdown           | Privacy-first `fetch.sh` proxy cascade; Feishu/WeChat/Twitter/GitHub routing (`read/SKILL.md:25-47`)                                                                                           |
| `write`  | De-AI prose, bilingual                  | 8 modes incl. Localization Review, Release-Note Template, Public-Reply, Tweet/Social                                                                                                           |
| `health` | Agent-engineering health audit          | Summary / Deep (3 inspector subagents); MCP live-check, instruction drift, hotspot ownership, verifier-surface audit (`health/SKILL.md`)                                                       |

### Rules (`rules/`) — install-time / always-on

- `anti-patterns.md` — 36 cross-skill AI failure modes (always-on guardrails; self-collapsing catalog, `AGENTS.md:54-55`)
- `english.md` / `chinese.md` — prose-naturalness rules installed into `~/.claude/rules/` or `~/.codex/AGENTS.md` via `setup-rule.sh`
- `waza-routing.md` — dispatch table (validated by `check_routing_drift.py`)
- `durable-context.md` — shared read-only memory-preflight preamble, linked by 6 skills

### Commands

- **None.** No `commands/` directory. Invocation is latent description-match + `/skill-name` aliases; `code-review` is an alias for `check` (`AGENTS.md:63`).

### Machinery

- Codegen: `build_metadata.py` regenerates `marketplace.json`, README URLs, installer `WAZA_REF` from `VERSION` + frontmatter; drift-gated by CI.
- Validation: `verify_skills.py` (50+ checks: frontmatter, outcome contracts, links, trigger overlap, attribution-leak, portable-surface).
- Tests: 20 auto-discovered shell smokes + `tests/python/` pytest; `make test` gate in `test.yml` / `release.yml`.
- Distribution: `packaging.allowlist` (default-deny) → `package-skill.sh` inlines sub-skills into one root `SKILL.md` → `dist/waza.zip`.
- `statusline.sh` — context % + 5h/7d rate-limit display (installed via `setup-statusline.sh`).
- Personas live **inside** `check/agents/` and `health/agents/` only — not separately invocable.

---

## 3. uncle-dev inventory (as-is, condensed)

- **Skills (~40)** across Define / Brownfield / Plan / Build / Verify / Review / Ship / Capture / Handoff / Maintain.
- **Commands (23)** in `.claude/commands/uncle-dev-*.md`, each mode-aware (LID-EARS vs OpenSpec).
- **Hooks (14)** in `hooks/hooks.json`: session-start, check-agents-md, openspec-guard, spec-coherence-guard, pre-commit-guard, destructive-command-guard, knowledge-capture-nudge, wrap-nudge, gate-notify, permission-notify, simplify-ignore.
- **Agents (9)**: ag-code-reviewer, ag-test-engineer, ag-security-auditor, ag-graph-analyst, ag-repo-research-analyst, ag-review-synthesizer, uncle-lead, uncle-po, uncle-senior.
- **Spec chain**: design-architecture-docs → spec-driven-development → spec-annotations → spec-scan → spec-graph; brownfield/feature-map reverse-engineer it.
- **Memory**: `.uncle-dev/learns/` (knowledge-capture/maintenance/proactive-memory), `.uncle-dev/research/`, `.devlocal/handoffs/` (wrap).
- **Config-as-code**: `.agents/uncle-dev-setup.yaml` read only via `scripts/uncle-dev-config.sh`.
- **Graphify** semantic graph integration (`uncle-dev-graphify-aware-analysis` + ag-graph-analyst).

---

## 4. GAP — What Waza HAS that uncle-dev LACKS

These are capabilities present in Waza with no (or only partial) uncle-dev equivalent.

| #   | Waza capability                                                                                                                                                  | uncle-dev status                                                                                                                                                            | Evidence                                      |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| G1  | **`read` — URL/PDF ingestion** with privacy-first proxy cascade (local-first, opt-in proxy, platform routing)                                                    | **Missing.** `source-driven-development` _cites_ docs but has no fetch mechanism.                                                                                           | `Waza skills/read/`, `scripts/fetch.sh`       |
| G2  | **`write` — prose de-AI / bilingual / localization / release-note copy / public-reply / social**                                                                 | **Missing.** `documentation-and-adrs` covers ADRs/API docs, not prose polishing, de-AI, localization, or release-note _copy_.                                               | `Waza skills/write/` (8 modes)                |
| G3  | **`learn` — domain-to-article 6-phase research** (learn unfamiliar field, produce canonical article)                                                             | **Missing.** uncle-dev `research` documents the _codebase_, not external domains-to-publication.                                                                            | `Waza skills/learn/`                          |
| G4  | **`health` — agent-config / instruction-drift / MCP / AI-maintainability audit** (hotspot ownership, verifier-surface drift, memory hygiene, skill supply-chain) | **Partial/Missing.** `context-engineering` _sets up_ context; no audit of config drift, MCP health, or AI-coding rot. (External `token-optimizer` overlaps, not in-system.) | `Waza skills/health/SKILL.md`                 |
| G5  | **`design` aesthetic depth**: screenshot-iteration oracle, design tokens, brand presets, data-viz chart selection, absolute-CSS-ban traps                        | **Partial.** `frontend-ui-engineering` covers components/state/a11y; lighter on visual direction-locking + screenshot polish.                                               | `Waza skills/design/references/*`             |
| G6  | **`hunt` Bisect Mode** (detached-worktree `git bisect` for "used to work")                                                                                       | **Partial.** `debug-error` is 5-step triage; no explicit bisect protocol.                                                                                                   | `hunt/SKILL.md:57-70`                         |
| G7  | **`check` Project-Audit scorecard** (whole-repo Linus-style 4-axis rating)                                                                                       | **Missing.** `review` is PR/diff-scoped, not a whole-project scorecard.                                                                                                     | `check/SKILL.md:163-218`                      |
| G8  | **`check` Triage + Public-Reply** (batch issue/PR triage, maintainer reply templates, GitHub follow-through)                                                     | **Missing.** No issue-triage / public-comment skill.                                                                                                                        | `check/SKILL.md:99-161`, `write` Public-Reply |
| G9  | **Bilingual (Chinese) + de-AI** prose rules always-on                                                                                                            | **Missing.** English-only.                                                                                                                                                  | `rules/chinese.md`, `rules/english.md`        |
| G10 | **Statusline** (context % + rate-limit windows)                                                                                                                  | **Missing in-system** (relies on external status line / token-optimizer).                                                                                                   | `scripts/statusline.sh`                       |
| G11 | **Self-validation + CI rigor for the skill collection itself** (50+ check validator, 20 smokes, pytest, codegen drift gate)                                      | **Lighter.** uncle-dev validates _specs_ (spec-scan/graph) and config schema, but has no comparable test/CI suite over its own skill files.                                 | `verify_skills.py`, `Makefile`, `tests/`      |
| G12 | **`anti-patterns.md` consolidated always-on guardrail catalog** with anti-growth discipline                                                                      | **Partial.** `AGENT_RULES.md` exists but is rules-of-thumb, not a self-collapsing validated catalog.                                                                        | `rules/anti-patterns.md`                      |
| G13 | **Public-distribution model** (codegen marketplace, default-deny packaging, single-VERSION lock-step, `npx skills add`, Claude Desktop ZIP)                      | **Different/Lighter.** uncle-dev ships as a plugin via installers; no codegen lock-step or packaging allowlist.                                                             | `build_metadata.py`, `packaging.allowlist`    |

---

## 5. GAP — What uncle-dev HAS that Waza LACKS

| #   | uncle-dev capability                                                                                                                                                                                    | Waza status                                                                                                                                             | Evidence                                                        |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| U1  | **Spec-driven chain** HLD→LLD→EARS→`@spec`→tests→code                                                                                                                                                   | **None.** `think` emits a plan then stops; no durable spec artifacts.                                                                                   | `uncle-dev-spec-driven-development`, `design-architecture-docs` |
| U2  | **OpenSpec change tracking** (5-artifact changes, validate/archive, global tracker)                                                                                                                     | **None.**                                                                                                                                               | `openspec-guard.sh`, `/uncle-dev-openspec-sync`                 |
| U3  | **`@spec` annotations + coherence guard + spec graph** (traceability, orphan/missing-test detection, cascade impact)                                                                                    | **None.**                                                                                                                                               | `spec-annotations`, `spec-scan`, `spec-graph`                   |
| U4  | **Runtime lifecycle hooks** (session-start injection, pre-commit, destructive guard, spec coherence block, nudges, gate notifications)                                                                  | **None.** Waza enforces only at install-time (rules) + dev-time (scripts); statusline is its only runtime hook.                                         | `hooks/hooks.json`                                              |
| U5  | **Persistent team memory (read+write)**: capture, maintain, proactively recall learnings                                                                                                                | **None.** Waza durable-context is read-only and never persists new learnings (`durable-context.md`).                                                    | `.uncle-dev/learns/`, knowledge-capture                         |
| U6  | **Session handoff** (`/wrap` → resumable `.devlocal/handoffs/`)                                                                                                                                         | **None.**                                                                                                                                               | `uncle-dev-wrap`                                                |
| U7  | **Config-as-code** (sdd_mode, tdd_mode, execution_profile, hook toggles, per-skill overrides, companions)                                                                                               | **None.** Behavior is fixed; only `VERSION` is configurable.                                                                                            | `.agents/uncle-dev-setup.yaml`, `uncle-dev-config.sh`           |
| U8  | **Task system**: planning with story IDs, acceptance criteria, dependency ordering, ready-set, claim/lock, next-task picker                                                                             | **Partial.** `think` produces a handoff plan; no tracked task state or next-task selection.                                                             | `planning-and-task-breakdown`, `/uncle-dev-next-task`           |
| U9  | **TDD red-green-refactor + mutation testing** as explicit skills                                                                                                                                        | **Partial.** `hunt` has a regression-guard rule; no TDD cycle or mutation testing.                                                                      | `test-driven-development`, `mutation-testing`                   |
| U10 | **Brownfield reverse-engineering** (feature-map → 5-agent swarm → specs/LLD/annotations)                                                                                                                | **None.**                                                                                                                                               | `feature-map`, `brownfield`                                     |
| U11 | **Graphify knowledge-graph** integration (graph-first search, blast-radius, ag-graph-analyst)                                                                                                           | **None.**                                                                                                                                               | `graphify-aware-analysis`                                       |
| U12 | **Separately-invocable agent personas** (uncle-lead, uncle-po, uncle-senior, review-synthesizer, etc.)                                                                                                  | **Partial.** Waza personas exist only inside `check`/`health`, not separately addressable.                                                              | `agents/`                                                       |
| U13 | **Dedicated SDLC skills**: api-and-interface-design, ci-cd-and-automation, deprecation-and-migration, shipping-and-launch, performance-optimization, security-and-hardening, incremental-implementation | **Folded/Partial.** Waza folds release/security into `check`; no standalone CI/CD, deprecation, perf, api-design, or incremental-implementation skills. | uncle-dev `skills/`                                             |
| U14 | **Multi-tool deep install with hook injection** (Claude Code + Codex + OpenCode, writes `.claude/settings.json`)                                                                                        | **Partial.** Waza installs skills + rules + statusline across Claude Code/Codex/Pi, but injects no behavioral hooks.                                    | `scripts/install-*.sh`, `setup-project.sh`                      |
| U15 | **Code-context enforcement** (mandatory AGENTS.md per source dir, boundary checks)                                                                                                                      | **None.**                                                                                                                                               | `code-context`, `check-agents-md.sh`                            |

---

## 6. OVERLAP — Both have it, different depth

| Area                   | Waza                                                                         | uncle-dev                                                                      | Net                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| Code review            | `check` (6 modes incl. audit/triage/ship, 2 reviewer agents, 16+ hard stops) | `review` (5-axis, 3 parallel agents + synthesizer, security/perf split)        | uncle-dev deeper on _diff_ review + security/perf; Waza broader (whole-project audit, release, triage) |
| Debugging              | `hunt` (7 modes, bisect, runtime evidence ladder, instrument-first)          | `debug-error` (5-step) + `browser-testing-with-devtools`                       | Waza deeper on diagnostic modes; uncle-dev adds DevTools MCP runtime                                   |
| Planning / evaluation  | `think` (Kill·Keep·Pivot, validation-gate)                                   | `idea-refine` + `grill` + `uncle-senior` + `plan`                              | Comparable; uncle-dev splits across more skills + persists tasks                                       |
| Frontend               | `design` (visual direction, tokens, screenshot oracle)                       | `frontend-ui-engineering` (components, state, a11y)                            | Complementary — Waza=visual taste, uncle-dev=engineering                                               |
| Cross-skill guardrails | `rules/anti-patterns.md` (validated, always-on)                              | `AGENT_RULES.md` (rules-of-thumb)                                              | Waza more rigorous as a catalog                                                                        |
| Git/ship               | `check` Ship/Release-Follow-through                                          | `git-workflow-and-versioning` + `shipping-and-launch` + `ci-cd-and-automation` | uncle-dev more granular; Waza more GitHub-action-oriented                                              |

---

## 7. The biggest gaps, summarized

**uncle-dev's blind spots (Waza fills):**

1. **Non-code knowledge work** — no `read` (fetch URLs/PDFs), no `write` (de-AI prose / release-note copy / localization), no `learn` (domain→article). (G1–G3)
2. **Meta-maintainability auditing** — no `health` equivalent: agent-config drift, MCP health, AI-coding rot, hotspot ownership, verifier-surface drift. (G4)
3. **Self-validation rigor** — no test/CI suite over its own ~40 skills the way Waza has 50+ checks + 20 smokes + pytest. (G11)/cle
4. **Whole-project audit + issue triage + bilingual prose + statusline.** (G5–G10, G12)

**Waza's blind spots (uncle-dev fills):**

1. **Durable spec + traceability** — the entire HLD→EARS→`@spec`→graph chain and OpenSpec tracking. (U1–U3)
2. **Runtime enforcement + persistent memory + handoff** — hooks, learns, wrap. (U4–U6)
3. **Per-project configurability + task tracking + brownfield + graphify.** (U7–U11)
4. **Granular SDLC coverage** (CI/CD, deprecation, perf, api-design, incremental-impl) and code-context boundaries. (U13, U15)

**Structural tension:** Waza's 8-skill hard cap (`AGENTS.md:61`) is a deliberate constraint that makes most "uncle-dev has more skills" gaps _by design_, not oversight. Conversely, uncle-dev's gaps (read/write/learn/health) are out of its stated scope ("code/SDLC only", project `CLAUDE.md`). The real, in-scope gaps for each side are: **uncle-dev ← `health`-style meta-audit + skill self-validation rigor**; **Waza ← durable spec/memory** (but the latter conflicts with Waza's lean, stateless, public-distribution design).

---

## 8. Deep-dive: the four content/meta gaps (read / write / learn / health)

These are the four Waza skills with no real uncle-dev equivalent. Each entry: what Waza actually does (file:line), uncle-dev's nearest surface, the precise delta, and why it matters / whether it's in-scope.

### 8.1 `read` — fetch any URL or PDF, treat as untrusted data

**What Waza does** (`read/SKILL.md`):

- Routing table by source type (`:27-34`): Feishu API, WeChat proxy-then-script, PDF extraction, GitHub raw/`gh`, Twitter via r.jina.ai, everything else via proxy cascade.
- **Privacy-first fetch cascade** (`scripts/fetch.sh`, `:38-47`): default = local extractor only, _URL never leaves the machine_; opt-in `--use-proxy` adds defuddle.md → r.jina.ai. Hard rule: never send authenticated/internal URLs to proxy (`:47`).
- Structured stderr telemetry per tier: `[fetch] tier=<name> status=<ok|fail> reason="..."` (`:45`).
- Intent-aware output: plain "read this" → 3-6 bullet summary; "convert/quote/cite/save/全文" → clean Markdown with frontmatter (`:21-23`, `:49-74`).
- **Prompt-injection defense** (`:111`): fetched content is _data, not instructions_; surfaces "ignore previous instructions"-style lines as warnings instead of obeying.
- Paywall detection (`:117`), save-with-auto-increment (`:89`), parallel image download (`:95-103`).

**uncle-dev's nearest surface:** `source-driven-development` _cites_ official docs and `context7` MCP can fetch library docs, but there is **no general URL/PDF ingestion primitive**. WebFetch exists at the harness level, but no skill owns proxy fallback, paywall detection, platform routing, or injection-hardening.

**Precise delta:** uncle-dev has no skill that (a) reliably fetches arbitrary web/PDF content, (b) handles JS-heavy/paywalled/Chinese-platform pages, (c) treats fetched bytes as untrusted, or (d) normalizes output to summary-vs-Markdown by intent.

**Why it matters:** `read` is the **fetch substrate** the other Waza skills build on (`learn` Phase 1 calls it; `write` reads live release pages through it). uncle-dev's research/spec/review skills are all _repo-internal_ — they never pull external primary sources. Any "ground this decision in the actual upstream changelog / RFC / vendor doc" workflow currently has no home. Adjacent but not overlapping: `source-driven-development` assumes you already have the doc.

---

### 8.2 `write` — strip AI taste from prose

**What Waza does** (`write/SKILL.md`) — 8 modes, all prose:

- **Core stance** (`:22-30`): a _catalog of smells, not a checklist_; over-editing is failure equal to under-editing; author's voice wins; prefer fewer stronger edits.
- **Language detected from the text, not the command** (`:36-41`) → loads `write-zh.md` / `write-en.md` / `write-zh-bilingual.md` / `write-product-localization.md` / `write-zh-release-notes.md`.
- **Hard rule: no em-dash** (`:56`) — called out as "the strongest AI-tone fingerprint."
- **Long-form Article Mode** (`:59-72`): maps structural problems (cross-section repetition, table re-reading, redundant sections) first, proposes cuts as reviewable change-points, _then_ line-level de-AI. Explicitly refuses single-pass rewrite of 40k-char articles.
- **Release Note Template Mode** (`:101-131`): reads the project's existing release as a style oracle, extracts from `git log <last-tag>..HEAD`, groups by user-perceivable feature, one sentence per item, bilingual blocks.
- **Public Reply Mode** (`:132-150`): GitHub issue/PR comment templates — `@reporter` + thanks, cause+impact in one sentence each, exact ship-state, 2-paragraph max, re-read live issue before posting.
- **Product Localization Review** (`:87-99`), **Document Review w/ PII scan** (`:152-163`), **Paragraph Coherence** (`:165-175`), **Tweet/Social** (`:177-190`).

**uncle-dev's nearest surface:** `documentation-and-adrs` (ADRs, API docs, the _why_) and `git-workflow-and-versioning` (commit messages). Neither polishes prose, removes AI tone, writes release-note _copy_, drafts user-facing GitHub replies, or does localization.

**Precise delta:** uncle-dev has **zero prose-quality surface aimed at human readers** — no de-AI pass, no release-note copywriting from git log, no public-comment drafting, no localization/bilingual review, no PII scan on outbound docs.

**Why it matters:** uncle-dev produces lots of _internal_ text (specs, ADRs, handoffs) but nothing for **outbound human-facing communication** — release notes, changelogs-as-narrative, issue replies, launch copy. `shipping-and-launch` covers the _mechanics_ of releasing but not the _words_. This is the cleanest standalone gap: a `write`-style skill would slot into the Ship/Capture phases without touching the spec machinery.

---

### 8.3 `learn` — unfamiliar domain → published reference

**What Waza does** (`learn/SKILL.md`) — a 6-phase external-research workflow:

- Modes (`:33-38`): Deep Research / Quick Reference (stop at digest) / Write-to-Learn (start at outline) / **Canonical Article** ("one article so readers need nothing else", `:42-53`).
- **Phase 1 Collect** (`:55-65`): _primary sources only_ (papers, official blogs, builder repos — not explainers), via `/read`, filed into sub-topic dirs. 5-10 sources for a blog, 15-20 for a survey.
- **Phase 2 Digest** (`:67-90`): cut ~half; 3-question worth-keeping gate; **contradictions noted, never silently resolved** (`:78`). Includes a "Conversation/Review Distillation" path that turns transcripts/scorecards into durable rules with a candidate matrix (`:80-90`).
- **Phases 3-6**: source-tracked outline → section fill (with explicit _stall signals_ that send you back to digest, `:102-108`) → refine + de-AI via `/write` → linear human self-review, two passes, then stop (no auto-publish).

**uncle-dev's nearest surface:** `uncle-dev-research` — but that is **codebase** exploration (parallel scouts → `.uncle-dev/research/` map of _this repo_). It is not external-domain learning, and it produces an internal research note, not a teachable published artifact.

**Precise delta:** uncle-dev cannot take "I need to understand WebRTC / OAuth device flow / a new vendor SDK well enough to design against it" and run a sourced, contradiction-aware, primary-source research loop that ends in a reference document. `research` answers "how does _our code_ work"; `learn` answers "how does _this unfamiliar domain_ work, from primary sources."

**Why it matters:** This is the natural **front-half of the Define phase** when the problem space itself is unfamiliar (new protocol, new compliance regime, new market). Today uncle-dev jumps from `idea-refine`/`grill` straight to spec, assuming domain knowledge already exists. The contradiction-handling and primary-source discipline are the transferable parts; the "publish an article" framing is less relevant to an SDLC tool. Depends on `read` (8.1) for its fetch step.

---

### 8.4 `health` — agent-config + AI-maintainability audit

**What Waza does** (`health/SKILL.md`) — audits the framework: `agent config → instruction surfaces → tools/runtime → verifiers → maintainability`:

- **Two lanes, one report** (`:24-27`): _agent-config health_ (Codex/Claude/Pi instruction drift, permissions, hooks, MCP, skills, memory supply chain) and _AI-maintainability health_ (context surface, verifier wrapper, generated-artifact checks, hotspot ownership, stale docs).
- **Budget-aware tiering** (`:39-47`, `:120-130`): Simple/Standard/Complex; summary pass first, escalate to 3 parallel inspector subagents only on demand, warning about token cost.
- **MCP live-check** (`:84`): one harmless call per server, respects `enabled:false`, never prints keys.
- **Security baseline** (`:91-105`): deny-list floor (SSH/cloud creds, `.env`, pipe-to-shell, outbound shells), env-override attack surface (base-URL redirects, `allowedTools:["*"]`, `--dangerously-skip-permissions`), **memory hygiene** (secrets in memory, rotation after untrusted runs), **skill supply-chain** (third-party skills/MCP pinned to a tag, not tracking `main`).
- **Long-running-agent stop conditions** (`:107-118`): the four hard stops (no progress / repeated failure / budget exceeded / external blocker) must live in _tracked config_, not prompts.
- **Maintainability signals** (`:163-230`): **concentrated fix chains** (`git log | grep fix`, 3+ fixes in one area = missing invariant), **hotspot ownership gaps** (large file with no named owner/boundary/verifier), **missing stable verifier wrapper** (no `make check/test/verify`), **broken doc references** (`@path`, `references/x.md` pointing at missing files — has a dedicated `check-doc-refs.sh`), **stale verifier cache output**.
- Hard non-goals (`:240-244`): never auto-fix, never lint-substitute.

**uncle-dev's nearest surface:** Several _partial, write-side_ pieces but no read-side audit:

- `context-engineering` _sets up_ rules/context (the thing `health` audits), doesn't audit it.
- `check-agents-md.sh` hook _nudges_ to read AGENTS.md; doesn't check for drift/contradiction.
- `destructive-command-guard.sh` enforces a deny-list at _runtime_; `health` audits whether the _settings_ declare one.
- `knowledge-maintenance` refreshes `.uncle-dev/learns/`; doesn't scan for secrets/supply-chain risk.
- External `token-optimizer` plugin overlaps on context-quality, but it's not part of uncle-dev.

**Precise delta:** uncle-dev has **no skill that audits its own installation** — no detection of instruction drift across CLAUDE.md/AGENTS.md/Codex config, no MCP health probe, no skill/MCP supply-chain pinning check, no memory-secret scan, no concentrated-fix-chain or hotspot-ownership analysis, no broken-`@spec`/doc-reference _health_ sweep (spec-scan checks `@spec` coherence specifically, not the broader doc-reference graph), no "is there one stable verifier entrypoint" check.

**Why it matters:** This is the **strongest transferable idea for uncle-dev** because uncle-dev is _far_ more config-heavy than Waza (14 hooks, `setup.yaml`, 9 agents, graphify, multi-tool installs across Claude Code/Codex/OpenCode). The more machinery a framework injects, the more it can silently drift or rot — yet uncle-dev has no self-diagnostic. A `health`-equivalent would answer "is my uncle-dev install actually wired correctly, are my hooks firing, is my config self-consistent, are my docs/spec references alive, where is the codebase rotting?" Notably in-scope: it's about engineering maintainability, which is squarely uncle-dev's charter.

---

### 8.5 Summary of the four

| Gap      | In uncle-dev's stated scope?            | Depends on | Standalone difficulty                             | Strongest transferable piece                         |
| -------- | --------------------------------------- | ---------- | ------------------------------------------------- | ---------------------------------------------------- |
| `read`   | Adjacent (enables source-grounding)     | —          | Medium (needs fetch script + injection hardening) | Untrusted-data + privacy-first fetch substrate       |
| `write`  | Yes (Ship/Capture outbound text)        | —          | Low (pure prose skill, no machinery)              | Release-note-from-git-log + de-AI + public-reply     |
| `learn`  | Front-half of Define when domain is new | `read`     | Medium                                            | Primary-source + contradiction-aware research loop   |
| `health` | **Yes — core charter**                  | —          | Medium-High (needs collector script + checks)     | Self-audit of config drift / supply-chain / code rot |

**Net:** `write` is the lowest-effort, cleanest add. `health` is the highest-value because uncle-dev's own complexity is exactly what `health` is designed to police. `read`+`learn` are a pair (learn needs read) and represent an external-knowledge capability uncle-dev currently lacks entirely.

---

## Key file references

- Waza skills: `/Users/javierbenavides/others/ai-agents/Waza-main/skills/{check,design,health,hunt,learn,read,think,write}/SKILL.md`
- Waza rules: `/Users/javierbenavides/others/ai-agents/Waza-main/rules/{anti-patterns,english,chinese,waza-routing,durable-context}.md`
- Waza routing: `skills/RESOLVER.md`, generated `scripts/dispatcher.md`
- Waza machinery: `scripts/{verify_skills,build_metadata,check_routing_drift}.py`, `Makefile`, `packaging.allowlist`
- uncle-dev skills: `/Users/javierbenavides/others/ai-agents/production-grade-agent-skills/skills/uncle-dev-*/SKILL.md`
- uncle-dev commands: `.claude/commands/uncle-dev-*.md`
- uncle-dev hooks: `hooks/hooks.json` + `hooks/*.sh`
- uncle-dev agents: `agents/*.md`
- uncle-dev config: `.agents/uncle-dev-setup.yaml`, `scripts/uncle-dev-config.sh`
